#!/usr/bin/env python3
"""
End-to-end simulation runner.

For every scenario in tests/sim/scenarios, builds a fresh Luau program that
contains the headless Roblox runtime (tests/sim/runtime.luau), registers every
script/module from src/ into a simulated DataModel exactly where Rojo would
put it, then runs the scenario (which boots the real server and/or client
scripts and drives gameplay).

Usage:  python3 tests/sim/run.py [path/to/luau] [scenario-name-filter]
"""
import os
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SIM = os.path.join(ROOT, "tests", "sim")

MOUNTS = [
    ("src/ReplicatedStorage/Shared", "ReplicatedStorage/Shared"),
    ("src/ServerScriptService", "ServerScriptService"),
    ("src/StarterPlayer/StarterPlayerScripts", "StarterPlayer/StarterPlayerScripts"),
    ("src/ReplicatedFirst", "ReplicatedFirst"),
]

# Scenarios marked "--@installer" start from the real installer model: Rojo
# builds installer.project.json (the same tree as build/StealPokemon_Installer.rbxm)
# to XML, and every instance, script source and saved property in it is
# recreated under Workspace, exactly as Studio would insert it.
PLACE_SETUP = """
Sim.createProjectInstances(game:GetService("ReplicatedStorage"))
"""

INSTALLER_SETUP = """
-- Every real place has a StarterPlayerScripts container
Sim.newInstance("StarterPlayerScripts", "StarterPlayerScripts").Parent = game:GetService("StarterPlayer")
"""

SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}
# Saved properties Studio actually loads from a model file. BaseScript.Enabled
# is NOT one of them (it doesn't serialize; Rojo's binary .rbxm drops it), so
# a script is only disabled in the file through the legacy Disabled property.
LOADED_BOOL_PROPERTIES = {"Disabled"}


def find_rojo(luau):
    candidates = [os.environ.get("ROJO"), os.path.join(os.path.dirname(os.path.abspath(luau)), "rojo"), shutil.which("rojo")]
    for c in candidates:
        if c and os.path.isfile(c):
            return c
    sys.exit("rojo not found (set ROJO=/path/to/rojo); needed for installer scenarios")


def installer_model_code(rojo, out_dir):
    xml_path = os.path.join(out_dir, "installer_model.rbxmx")
    subprocess.run([rojo, "build", os.path.join(ROOT, "installer.project.json"), "-o", xml_path],
                   check=True, stdout=subprocess.DEVNULL)
    lines = []

    def props_of(item):
        out = {}
        for p in item.find("Properties"):
            out[(p.tag, p.get("name"))] = p.text or ""
        return out

    def walk(item, parent_path):
        props = props_of(item)
        cls = item.get("class")
        name = props[("string", "Name")]
        path = parent_path + "/" + name
        if cls in SCRIPT_CLASSES:
            lines.append("do local inst = Sim.register(%r, %r, %s)" % (path, cls, long_string(props.get(("string", "Source"), ""))))
        else:
            lines.append("do local inst = Sim.newInstance(%r, %r) inst.Parent = Sim.find(%r)" % (cls, name, parent_path))
        for (tag, pname), value in props.items():
            if tag == "bool" and pname in LOADED_BOOL_PROPERTIES:
                lines.append("inst[%r] = %s" % (pname, "true" if value == "true" else "false"))
        lines.append("end")
        for child in item.findall("Item"):
            walk(child, path)

    for top in ET.parse(xml_path).getroot().findall("Item"):
        walk(top, "Workspace")
    return "\n".join(lines) + "\n"


def long_string(s):
    level = 1
    while ("]" + "=" * level + "]") in s:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + s + "]" + eq + "]"


def collect(mounts):
    entries = []
    for fs_root, dm_root in mounts:
        base = os.path.join(ROOT, fs_root)
        for dirpath, _, files in os.walk(base):
            for f in sorted(files):
                if not f.endswith(".luau"):
                    continue
                full = os.path.join(dirpath, f)
                rel = os.path.relpath(full, base).replace(os.sep, "/")
                if f.endswith(".server.luau"):
                    cls, name = "Script", rel[: -len(".server.luau")]
                elif f.endswith(".client.luau"):
                    cls, name = "LocalScript", rel[: -len(".client.luau")]
                else:
                    cls, name = "ModuleScript", rel[: -len(".luau")]
                entries.append((dm_root + "/" + name, cls, open(full, encoding="utf-8").read()))
    return entries


PRELUDE = r'''
Sim.sources = {}
local requireCache = {}
local requiring = {}
function Sim.register(path, className, source)
	local segments = string.split(path, "/")
	local parent = game:GetService(segments[1])
	for i = 2, #segments - 1 do
		local child = parent:FindFirstChild(segments[i])
		if not child then
			child = Sim.newInstance("Folder", segments[i])
			child.Parent = parent
		end
		parent = child
	end
	local inst = Sim.newInstance(className, segments[#segments])
	inst.Parent = parent
	Sim.sources[inst] = source
	return inst
end
function require(target)
	if requireCache[target] ~= nil then
		return requireCache[target]
	end
	local source = Sim.sources[target]
	if not source then
		error("Attempted to require a non-ModuleScript: " .. tostring(target))
	end
	if requiring[target] then
		error("Requested module was required recursively: " .. target:GetFullName())
	end
	requiring[target] = true
	local chunk, err = loadstring("local script = ...\n" .. source, "=" .. target:GetFullName())
	if not chunk then
		error("Compile error: " .. tostring(err))
	end
	local result = chunk(target)
	requiring[target] = nil
	if result == nil then
		error("Module " .. target:GetFullName() .. " did not return a value")
	end
	requireCache[target] = result
	return result
end
function Sim.RunScript(inst)
	local chunk, err = loadstring("local script = ...\n" .. Sim.sources[inst], "=" .. inst:GetFullName())
	if not chunk then
		error("Compile error: " .. tostring(err))
	end
	task.spawn(chunk, inst)
end
function Sim.find(path)
	local segments = string.split(path, "/")
	local node = game:GetService(segments[1])
	for i = 2, #segments do
		node = node:FindFirstChild(segments[i])
		if not node then
			return nil
		end
	end
	return node
end
-- Project instances Rojo creates from default.project.json / installer.project.json
function Sim.createProjectInstances(rs)
	local remotes = Sim.newInstance("Folder", "Remotes")
	remotes.Parent = rs
	Sim.newInstance("RemoteFunction", "Request").Parent = remotes
	Sim.newInstance("RemoteEvent", "Event").Parent = remotes
	Sim.newInstance("RemoteEvent", "Sync").Parent = remotes
	local assets = Sim.newInstance("Folder", "Assets")
	assets.Parent = rs
	for _, n in { "Creatures", "Sounds", "Images" } do
		Sim.newInstance("Folder", n).Parent = assets
	end
end
game:GetService("Players").CharacterAutoLoads = false

function Sim.BootServer()
	Sim.RunScript(Sim.find("ServerScriptService/ServerMain"))
	Sim.Run(1)
end

function Sim.BootClient()
	Sim.RunScript(Sim.find("ReplicatedFirst/LoadingScreen"))
	Sim.RunScript(Sim.find("StarterPlayer/StarterPlayerScripts/ClientMain"))
	Sim.Run(1)
end

function Sim.assert(cond, msg)
	if not cond then
		error("ASSERTION FAILED: " .. tostring(msg), 2)
	end
end

function Sim.registry()
	return require(Sim.find("ServerScriptService/Modules/Registry"))
end

function Sim.lastEvents(player, name)
	local out = {}
	for _, e in Sim.clientEvents[player] or {} do
		if e.Args[1] == name then
			table.insert(out, e.Args)
		end
	end
	return out
end
'''

FINISH = r'''
if Sim.warnings and #Sim.warnings > 0 then
	print(string.format("-- %d warning(s); first ones:", #Sim.warnings))
	for i = 1, math.min(15, #Sim.warnings) do
		print("   " .. Sim.warnings[i])
	end
end
local unexpected = {}
for _, e in Sim.errors do
	table.insert(unexpected, e)
end
-- Errors that game code catches and logs are still failures (except the ones
-- deliberately provoked by the integration tests).
local CRITICAL = { "%[WindowManager%]", "%[Reveal%]", "%[ActionBus%]", "%]%[ERROR%]" }
local EXPECTED = { "FakePlayer" }
for _, w in Sim.warnings or {} do
	local critical = false
	for _, pattern in CRITICAL do
		if string.find(w, pattern) then
			critical = true
		end
	end
	for _, pattern in EXPECTED do
		if string.find(w, pattern) then
			critical = false
		end
	end
	if critical then
		table.insert(unexpected, "logged error: " .. w)
		print("[UNEXPECTED] " .. w)
	end
end
if #unexpected > 0 then
	print(string.format("SCENARIO FAILED with %d runtime error(s)", #unexpected))
	error("runtime errors")
end
print("SCENARIO PASSED (" .. string.format("%.1f", Sim.clock) .. "s simulated)")
'''


def main():
    luau = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("LUAU", "luau")
    name_filter = sys.argv[2] if len(sys.argv) > 2 else ""
    runtime = open(os.path.join(SIM, "runtime.luau"), encoding="utf-8").read()
    place_entries = collect(MOUNTS)
    installer_code = None
    scen_dir = os.path.join(SIM, "scenarios")
    out_dir = os.path.join(ROOT, "tests", ".build")
    os.makedirs(out_dir, exist_ok=True)
    failures = 0
    for scen in sorted(os.listdir(scen_dir)):
        if not scen.endswith(".luau") or name_filter not in scen:
            continue
        scenario_src = open(os.path.join(scen_dir, scen), encoding="utf-8").read()
        installer_mode = "--@installer" in scenario_src
        parts = [runtime, PRELUDE]
        if installer_mode:
            if installer_code is None:
                installer_code = installer_model_code(find_rojo(luau), out_dir)
            parts.append(installer_code)
            parts.append(INSTALLER_SETUP)
        else:
            for path, cls, src in place_entries:
                parts.append("Sim.register(%r, %r, %s)\n" % (path, cls, long_string(src)))
            parts.append(PLACE_SETUP)
        parts.append("local __ok, __err = pcall(function()\n" + scenario_src + "\nend)\n")
        parts.append('if not __ok then print("SCENARIO ERROR: " .. tostring(__err)) table.insert(Sim.errors, tostring(__err)) end\n')
        parts.append(FINISH)
        bundle_path = os.path.join(out_dir, "sim_" + scen)
        with open(bundle_path, "w", encoding="utf-8") as fh:
            fh.write("".join(parts))
        print("=== " + scen)
        result = subprocess.run([luau, bundle_path])
        if result.returncode != 0:
            failures += 1
    if failures:
        print("%d scenario(s) failed" % failures)
        sys.exit(1)
    print("All scenarios passed")


if __name__ == "__main__":
    main()

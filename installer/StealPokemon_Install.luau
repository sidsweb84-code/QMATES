--[[
	STEAL A CRITTER ("Steal Pokémon" framework) — one-step installer

	This ModuleScript ships inside StealPokemon_Installer.rbxm next to the
	game's scripts. It moves everything into the right services, applies the
	place settings, and removes itself.

	HOW TO INSTALL (Roblox Studio, Edit mode — not while playing):
	  1. Open the place you want to install into. A new "Baseplate" place is ideal.
	  2. Drag StealPokemon_Installer.rbxm into the 3D view
	     (or right-click Workspace → "Insert from File…").
	  3. View → Command Bar, paste this line and press Enter:

	       require(workspace.StealPokemon_Installer.StealPokemon_Install)()

	  4. Read the Output window, then press Play.

	What it changes:
	  • ReplicatedStorage    ← Shared, Remotes, Assets
	  • ReplicatedFirst      ← LoadingScreen
	  • ServerScriptService  ← ServerMain, Modules, Services, Tests
	  • StarterPlayerScripts ← ClientMain, Controllers, UI
	  • Players / StarterPlayer / Workspace / Lighting / SoundService settings
	  • The template's Baseplate and SpawnLocation (they overlap the generated
	    map) and any older copy of these scripts are MOVED (never deleted) to
	    ServerStorage.StealPokemon_Backup_<time>.
	If anything fails, the whole install is undone when Studio allows it;
	otherwise press Ctrl+Z / Cmd+Z.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")

local PREFIX = "[StealPokemon Installer]"
local ROOT = script.Parent

-- Payload folder (inside the installer) -> destination container.
local function destinations(): { { Source: string, Target: Instance } }
	-- Every place has one (it can't be created from a script).
	local starterPlayerScripts = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts")
	if not starterPlayerScripts then
		error(PREFIX .. " StarterPlayer.StarterPlayerScripts is missing from this place. Open the prebuilt StealPokemon.rbxl instead.", 0)
	end
	return {
		{ Source = "ReplicatedStorage", Target = ReplicatedStorage },
		{ Source = "ReplicatedFirst", Target = ReplicatedFirst },
		{ Source = "ServerScriptService", Target = ServerScriptService },
		{ Source = "StarterPlayerScripts", Target = starterPlayerScripts :: Instance },
	}
end

-- Same values as default.project.json (the prebuilt .rbxl already has them).
local SETTINGS: { { any } } = {
	{ Players, "CharacterAutoLoads", false },
	{ Players, "RespawnTime", 3 },
	{ StarterPlayer, "CameraMaxZoomDistance", 90 },
	{ StarterPlayer, "CharacterWalkSpeed", 16 },
	{ StarterPlayer, "CharacterUseJumpPower", true },
	{ StarterPlayer, "CharacterJumpPower", 50 },
	{ workspace, "Gravity", 196.2 },
	{ workspace, "FallenPartsDestroyHeight", -100 },
	-- The client expects the whole (small) map to be loaded; newer places
	-- default to streaming, which would hide far-away bases and conveyors.
	{ workspace, "StreamingEnabled", false },
	{ Lighting, "Ambient", Color3.new(0.43, 0.43, 0.5) },
	{ Lighting, "OutdoorAmbient", Color3.new(0.55, 0.55, 0.62) },
	{ Lighting, "Brightness", 2.4 },
	{ Lighting, "ClockTime", 14.5 },
	{ Lighting, "GeographicLatitude", 24 },
	{ Lighting, "GlobalShadows", true },
	{ Lighting, "EnvironmentDiffuseScale", 0.6 },
	{ Lighting, "EnvironmentSpecularScale", 0.6 },
	{ SoundService, "RespectFilteringEnabled", true },
}

-- Template parts that sit exactly where the generated map's ground goes.
local TEMPLATE_PARTS = { "Baseplate", "SpawnLocation" }

-- Must exist after installing (checked at the end).
local REQUIRED = {
	"ReplicatedStorage/Shared/Net",
	"ReplicatedStorage/Shared/Config/GameConfig",
	"ReplicatedStorage/Remotes/Request",
	"ReplicatedStorage/Remotes/Event",
	"ReplicatedStorage/Remotes/Sync",
	"ReplicatedStorage/Assets/Creatures",
	"ReplicatedFirst/LoadingScreen",
	"ServerScriptService/ServerMain",
	"ServerScriptService/Services/DataService",
	"ServerScriptService/Modules/Registry",
	"StarterPlayerScripts/ClientMain",
	"StarterPlayerScripts/Controllers/State",
	"StarterPlayerScripts/UI/HUD",
}

local function findPath(path: string): Instance?
	local segments = string.split(path, "/")
	local node: Instance?
	if segments[1] == "StarterPlayerScripts" then
		node = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts")
	else
		node = game:GetService(segments[1])
	end
	for i = 2, #segments do
		if not node then
			return nil
		end
		node = node:FindFirstChild(segments[i])
	end
	return node
end

local function setScriptEnabled(target: Instance, enabled: boolean)
	-- `Enabled` is the current property; `Disabled` is its legacy name.
	local ok = pcall(function()
		(target :: any).Enabled = enabled
	end)
	if not ok then
		pcall(function()
			(target :: any).Disabled = not enabled
		end)
	end
end

local function isScriptEnabled(target: Instance): boolean
	local ok, enabled = pcall(function()
		return (target :: any).Enabled
	end)
	if ok and type(enabled) == "boolean" then
		return enabled
	end
	local ok2, disabled = pcall(function()
		return (target :: any).Disabled
	end)
	return not (ok2 and disabled == true)
end

type Report = {
	Installed: { string },
	BackedUp: { string },
	Merged: { string },
	SettingsApplied: number,
	SettingsSkipped: { string },
	Warnings: { string },
	Backup: Folder?,
}

local function install(report: Report)
	local backup: Folder? = nil
	local function stash(inst: Instance, container: string)
		if not backup then
			local folder = Instance.new("Folder")
			folder.Name = "StealPokemon_Backup_" .. os.date("%Y%m%d_%H%M%S")
			folder.Parent = ServerStorage
			backup = folder
			report.Backup = folder
		end
		local sub = (backup :: Folder):FindFirstChild(container)
		if not sub then
			sub = Instance.new("Folder")
			sub.Name = container
			sub.Parent = backup
		end
		inst.Parent = sub
		table.insert(report.BackedUp, container .. "." .. inst.Name)
	end

	-- 1. Scripts and folders
	for _, route in destinations() do
		local source = ROOT:FindFirstChild(route.Source)
		if not source then
			error(string.format("%s The installer is incomplete: missing folder '%s'. Re-download StealPokemon_Installer.rbxm.", PREFIX, route.Source), 0)
		end
		for _, child in source:GetChildren() do
			local existing = route.Target:FindFirstChild(child.Name)
			if existing and route.Source == "ReplicatedStorage" and child.Name == "Assets" then
				-- Keep the developer's own (licensed) assets; only add missing sub-folders.
				for _, sub in child:GetChildren() do
					if not existing:FindFirstChild(sub.Name) then
						sub.Parent = existing
						table.insert(report.Merged, "ReplicatedStorage.Assets." .. sub.Name)
					end
				end
				child:Destroy()
				continue
			end
			while existing do
				stash(existing, route.Source)
				existing = route.Target:FindFirstChild(child.Name)
			end
			child.Parent = route.Target
			table.insert(report.Installed, route.Source .. "." .. child.Name)
		end
	end

	-- 2. The server entry script ships disabled so it can't run from the
	--    installer model if someone presses Play before installing.
	local main = ServerScriptService:FindFirstChild("ServerMain")
	if main then
		setScriptEnabled(main, true)
	end

	-- 3. Place settings
	for _, setting in SETTINGS do
		local target, property, value = setting[1], setting[2], setting[3]
		local ok = pcall(function()
			target[property] = value
		end)
		if ok then
			report.SettingsApplied += 1
		else
			table.insert(report.SettingsSkipped, target.Name .. "." .. property)
		end
	end

	local okStreaming, streaming = pcall(function()
		return workspace.StreamingEnabled
	end)
	if okStreaming and streaming == true then
		table.insert(report.Warnings, "Workspace.StreamingEnabled is still ON. Select Workspace in the Explorer and untick StreamingEnabled in Properties, otherwise far-away bases and conveyor items may not appear.")
	end

	-- 4. Template parts that would overlap the generated map
	for _, name in TEMPLATE_PARTS do
		local part = workspace:FindFirstChild(name)
		while part and part:IsA("BasePart") do
			stash(part, "Workspace")
			part = workspace:FindFirstChild(name)
		end
	end
	local okTerrain, cells = pcall(function()
		return workspace.Terrain:CountCells()
	end)
	if okTerrain and type(cells) == "number" and cells > 0 then
		table.insert(report.Warnings, "This place has Terrain, which may overlap the generated map (ground at Y = 0). Remove it with Terrain Editor → Clear if it gets in the way.")
	end
	if workspace:FindFirstChild("World") then
		table.insert(report.Warnings, "Workspace already has an object named 'World'. The game rebuilds Workspace.World when the server starts, so anything inside it will be replaced.")
	end

	-- 5. Verify
	local missing = {}
	for _, path in REQUIRED do
		if not findPath(path) then
			table.insert(missing, path)
		end
	end
	if #missing > 0 then
		error(PREFIX .. " Install check failed, missing: " .. table.concat(missing, ", "), 0)
	end
	if main and not isScriptEnabled(main) then
		error(PREFIX .. " Could not enable ServerScriptService.ServerMain. Select it and tick 'Enabled' in Properties.", 0)
	end

	-- 6. Remove the (now empty) installer
	ROOT:Destroy()
end

return function(options: { AllowWhileRunning: boolean?, Quiet: boolean? }?): Report
	local opts = options or {}
	if ROOT == nil or ROOT.Parent == nil then
		error(PREFIX .. " Already installed (or the installer folder was removed).", 0)
	end
	if RunService:IsRunning() and not opts.AllowWhileRunning then
		error(PREFIX .. " Stop the game first: install in Edit mode, otherwise the changes disappear when you stop playing.", 0)
	end

	local report: Report = {
		Installed = {},
		BackedUp = {},
		Merged = {},
		SettingsApplied = 0,
		SettingsSkipped = {},
		Warnings = {},
		Backup = nil,
	}

	local recording: string? = nil
	pcall(function()
		recording = ChangeHistoryService:TryBeginRecording("Install STEAL A CRITTER")
	end)
	local ok, err = pcall(install, report)
	if recording then
		pcall(function()
			ChangeHistoryService:FinishRecording(
				recording,
				if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
			)
		end)
	end
	if not ok then
		local undo = if recording
			then "All changes were rolled back."
			else "Press Ctrl+Z / Cmd+Z to undo any partial changes."
		error(tostring(err) .. "\n" .. undo, 0)
	end

	if not opts.Quiet then
		print(string.format("%s ✅ Installed %d items.", PREFIX, #report.Installed))
		print(string.format("%s Applied %d place settings.", PREFIX, report.SettingsApplied))
		if #report.SettingsSkipped > 0 then
			warn(PREFIX .. " Could not set (optional): " .. table.concat(report.SettingsSkipped, ", "))
		end
		if #report.Merged > 0 then
			print(PREFIX .. " Kept your existing ReplicatedStorage.Assets; added: " .. table.concat(report.Merged, ", "))
		end
		if report.Backup then
			print(string.format("%s Moved (not deleted) to ServerStorage.%s: %s", PREFIX, report.Backup.Name, table.concat(report.BackedUp, ", ")))
		end
		for _, w in report.Warnings do
			warn(PREFIX .. " " .. w)
		end
		print(PREFIX .. " Next steps:")
		print("   1. Press Play (or Test → Clients and Servers → 2 players to try stealing).")
		print("   2. To save progress in Studio: Home → Game Settings → Security → Enable Studio Access to API Services.")
		print("   3. Before publishing: set Max Players to 8 and follow docs/SETUP.md (Robux IDs, admins, audio).")
	end
	return report
end

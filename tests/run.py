#!/usr/bin/env python3
"""
Offline test runner for the pure-logic Luau modules.

Bundles the project's ModuleScripts into a single Luau program with a minimal
mock of the Roblox runtime (Color3, Vector3, CFrame, Random, Enum, task, game)
and runs every spec in tests/specs with the standalone `luau` CLI.

Usage:  python3 tests/run.py [path/to/luau]
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Filesystem roots -> DataModel paths (mirrors default.project.json)
MOUNTS = [
    ("src/ReplicatedStorage/Shared", "ReplicatedStorage/Shared"),
    ("src/ServerScriptService", "ServerScriptService"),
]


def collect_modules():
    modules = {}
    for fs_root, dm_root in MOUNTS:
        base = os.path.join(ROOT, fs_root)
        for dirpath, _, files in os.walk(base):
            for f in files:
                if not f.endswith(".luau"):
                    continue
                if f.endswith(".server.luau") or f.endswith(".client.luau"):
                    continue
                full = os.path.join(dirpath, f)
                rel = os.path.relpath(full, base).replace(os.sep, "/")
                name = rel[: -len(".luau")]
                if name.endswith("/init"):
                    name = name[: -len("/init")]
                modules[dm_root + "/" + name] = open(full, encoding="utf-8").read()
    return modules


def long_string(s):
    level = 1
    while ("]" + "=" * level + "]") in s:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + s + "]" + eq + "]"


def main():
    luau = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("LUAU", "luau")
    modules = collect_modules()
    prelude = open(os.path.join(ROOT, "tests", "mock_roblox.luau"), encoding="utf-8").read()
    framework = open(os.path.join(ROOT, "tests", "framework.luau"), encoding="utf-8").read()

    parts = [prelude, "\n-- MODULE SOURCES\n"]
    for path, src in sorted(modules.items()):
        parts.append("__registerModule(%r, %s)\n" % (path, long_string(src)))
    parts.append(framework)

    specs_dir = os.path.join(ROOT, "tests", "specs")
    for f in sorted(os.listdir(specs_dir)):
        if f.endswith(".luau"):
            src = open(os.path.join(specs_dir, f), encoding="utf-8").read()
            parts.append("__runSpec(%r, %s)\n" % (f, long_string(src)))
    parts.append("__finish()\n")

    bundle = "".join(parts)
    out_dir = os.path.join(ROOT, "tests", ".build")
    os.makedirs(out_dir, exist_ok=True)
    bundle_path = os.path.join(out_dir, "bundle.luau")
    with open(bundle_path, "w", encoding="utf-8") as fh:
        fh.write(bundle)
    result = subprocess.run([luau, bundle_path])
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()

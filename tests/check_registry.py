#!/usr/bin/env python3
"""
Static check for cross-service calls made through the server Registry.
Services reference each other as `Registry.SomeService:Method(...)`, which the
type checker sees as `any`. This verifies every referenced service and method
actually exists, catching typos before they become runtime errors.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SERVICES = os.path.join(ROOT, "src", "ServerScriptService", "Services")
SEARCH = [os.path.join(ROOT, "src", "ServerScriptService")]

defined = {}
for f in os.listdir(SERVICES):
    if not f.endswith(".luau"):
        continue
    name = f[:-5]
    src = open(os.path.join(SERVICES, f), encoding="utf-8").read()
    members = set(re.findall(r"function\s+%s[:.](\w+)" % name, src))
    members |= set(re.findall(r"^%s\.(\w+)\s*=" % name, src, re.M))
    defined[name] = members

errors = []
for base in SEARCH:
    for dirpath, _, files in os.walk(base):
        for f in files:
            if not f.endswith(".luau"):
                continue
            path = os.path.join(dirpath, f)
            for lineno, line in enumerate(open(path, encoding="utf-8"), 1):
                for svc, sep, member in re.findall(r"Registry\.(\w+)([:.])(\w+)", line):
                    if svc not in defined:
                        errors.append(f"{path}:{lineno}: unknown service Registry.{svc}")
                    elif member not in defined[svc]:
                        errors.append(f"{path}:{lineno}: {svc} has no member '{member}'")

if errors:
    print("\n".join(errors))
    sys.exit(1)
print(f"Registry check OK ({sum(len(v) for v in defined.values())} members across {len(defined)} services)")

#!/usr/bin/env bash
# Runs every automated check:
#   1. type-check against the Roblox API (luau-lsp)
#   2. registry cross-reference check (service method names)
#   3. offline unit tests (pure game logic)
#   4. end-to-end simulation (real server + client scripts in a headless runtime)
#   5. build artifacts: build/*.rbxl/.rbxm up to date, installer model saved correctly
set -euo pipefail
cd "$(dirname "$0")/.."
TOOLS="${TOOLS:-tools}"
echo "== Type check"
CHECK_OUT="$(mktemp)"
TOOLS="$TOOLS" ./scripts/check.sh > "$CHECK_OUT" 2>&1 || true
PROBLEMS="$(grep -v "^\[INFO\]\|^\[WARN\] client\|Created sourcemap" "$CHECK_OUT" || true)"
rm -f "$CHECK_OUT"
if [ -n "$PROBLEMS" ]; then echo "$PROBLEMS"; echo "Type check reported problems"; exit 1; fi
echo "clean"
echo "== Registry check"
python3 tests/check_registry.py
echo "== Unit tests"
python3 tests/run.py "$TOOLS/luau"
echo "== Simulation"
python3 tests/sim/run.py "$TOOLS/luau"
echo "== Build artifacts"
python3 tests/check_artifacts.py "$TOOLS/rojo"
echo "All checks passed"

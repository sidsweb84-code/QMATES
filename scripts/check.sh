#!/usr/bin/env bash
# Type-checks every Luau file against the Roblox API definitions.
# Requires: rojo, luau-lsp and globalTypes.d.luau (run scripts/setup-tools.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
TOOLS="${TOOLS:-tools}"
ROJO="${ROJO:-$TOOLS/rojo}"
LUAU_LSP="${LUAU_LSP:-$TOOLS/luau-lsp}"
DEFS="${DEFS:-$TOOLS/globalTypes.d.luau}"
"$ROJO" sourcemap default.project.json -o sourcemap.json
"$LUAU_LSP" analyze --platform=roblox --definitions=@roblox="$DEFS" --sourcemap=sourcemap.json \
	--base-luaurc=.luaurc src installer "$@"

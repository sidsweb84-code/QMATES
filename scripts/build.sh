#!/usr/bin/env bash
# Builds build/StealPokemon.rbxl from source (open it directly in Roblox Studio).
set -euo pipefail
cd "$(dirname "$0")/.."
ROJO="${ROJO:-tools/rojo}"
mkdir -p build
"$ROJO" build default.project.json -o build/StealPokemon.rbxl
echo "Built build/StealPokemon.rbxl"

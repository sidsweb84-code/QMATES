#!/usr/bin/env bash
# Builds the two Studio-ready files from source:
#   build/StealPokemon.rbxl            complete place: File > Open from File
#   build/StealPokemon_Installer.rbxm  model for an existing place: insert it,
#                                      then run the command-bar line it prints
set -euo pipefail
cd "$(dirname "$0")/.."
ROJO="${ROJO:-tools/rojo}"
mkdir -p build
"$ROJO" build default.project.json -o build/StealPokemon.rbxl
"$ROJO" build installer.project.json -o build/StealPokemon_Installer.rbxm
echo "Built build/StealPokemon.rbxl and build/StealPokemon_Installer.rbxm"
echo "Model install (Studio command bar):"
echo "  require(workspace.StealPokemon_Installer.StealPokemon_Install)()"

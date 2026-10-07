#!/usr/bin/env bash
# Downloads the command-line tools used by the test / build scripts into ./tools
#   rojo        builds the .rbxl place file from source
#   luau        runs the offline unit tests and simulation
#   luau-lsp    type-checks everything against the Roblox API definitions
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tools
cd tools
ROJO_VERSION="${ROJO_VERSION:-7.6.1}"
case "$(uname -s)" in
	Linux) ROJO_OS=linux-x86_64; LUAU_OS=ubuntu; LSP_OS=linux-x86_64 ;;
	Darwin) ROJO_OS=macos-aarch64; LUAU_OS=macos; LSP_OS=macos ;;
	*) echo "Unsupported OS: use Windows binaries from the GitHub releases manually"; exit 1 ;;
esac
curl -sSL -o rojo.zip "https://github.com/rojo-rbx/rojo/releases/download/v${ROJO_VERSION}/rojo-${ROJO_VERSION}-${ROJO_OS}.zip"
curl -sSL -o luau.zip "https://github.com/luau-lang/luau/releases/latest/download/luau-${LUAU_OS}.zip"
curl -sSL -o luau-lsp.zip "https://github.com/JohnnyMorganz/luau-lsp/releases/latest/download/luau-lsp-${LSP_OS}.zip"
curl -sSL -o globalTypes.d.luau "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
for z in rojo.zip luau.zip luau-lsp.zip; do unzip -o -q "$z"; rm "$z"; done
chmod +x rojo luau luau-analyze luau-lsp 2>/dev/null || true
echo "Tools installed in ./tools"

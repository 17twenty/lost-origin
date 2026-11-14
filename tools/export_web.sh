#!/usr/bin/env bash
# Exports the Web (WebGL2 / Compatibility) build to build/web/ and enforces the
# size budget: .pck <= 80 MB, .wasm <= 50 MB (uncompressed).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
TPL="$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable"
[[ -f "$TPL/web_nothreads_release.zip" ]] || { echo "missing Web export templates in $TPL"; exit 1; }
t() { local secs=$1; shift; perl -e 'alarm shift; exec @ARGV' "$secs" "$@"; }
rm -rf build/web && mkdir -p build/web
t 600 "$GODOT" --headless --export-release "Web" build/web/index.html >/tmp/lo_export.log 2>&1 || { tail -40 /tmp/lo_export.log; echo "export failed"; exit 1; }
if grep -E "SCRIPT ERROR|ERROR: .*(export|Export)" /tmp/lo_export.log; then echo "export reported errors"; exit 1; fi
ls -la build/web
pck=$(stat -f%z build/web/index.pck)
wasm=$(stat -f%z build/web/index.wasm)
printf "SIZE pck=%.1fMB wasm=%.1fMB\n" "$(echo "$pck/1048576" | bc -l)" "$(echo "$wasm/1048576" | bc -l)"
(( pck <= 80*1024*1024 )) || { echo "pck over budget"; exit 1; }
(( wasm <= 50*1024*1024 )) || { echo "wasm over budget"; exit 1; }
echo "EXPORT_WEB_OK"

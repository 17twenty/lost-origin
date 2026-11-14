#!/usr/bin/env bash
# Full pipeline: rebuild generated scenes, import, run tests. Pass --shots to also capture screenshots.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
"$GODOT" --headless --import --quit >/tmp/lo_import.log 2>&1 || { cat /tmp/lo_import.log; exit 1; }
"$GODOT" --headless -s tools/build_level.gd
"$GODOT" --headless --import --quit >/tmp/lo_import.log 2>&1 || { cat /tmp/lo_import.log; exit 1; }
if grep -E "ERROR|SCRIPT ERROR" /tmp/lo_import.log; then echo "import errors"; exit 1; fi
"$GODOT" --headless -s tests/run_tests.gd -- "$@"
if [[ "${SHOTS:-0}" == "1" ]]; then "$GODOT" -s tools/capture_screenshot.gd; fi

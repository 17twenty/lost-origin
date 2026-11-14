#!/usr/bin/env bash
# Full pipeline: rebuild generated scenes, import, run tests. Pass --shots to also capture screenshots.
set -euo pipefail
cd "$(dirname "$0")/.."
BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
if [[ "${REBUILD_ASSETS:-0}" == "1" ]]; then "$BLENDER" -b -P tools/blender/build_character.py | grep BUILD_CHARACTER_OK; fi
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
"$GODOT" --headless --import --quit >/tmp/lo_import.log 2>&1 || { cat /tmp/lo_import.log; exit 1; }
"$GODOT" --headless -s tools/build_player.gd
"$GODOT" --headless -s tools/build_level.gd
"$GODOT" --headless --import --quit >/tmp/lo_import.log 2>&1 || { cat /tmp/lo_import.log; exit 1; }
if grep -E "ERROR|SCRIPT ERROR" /tmp/lo_import.log; then echo "import errors"; exit 1; fi
"$GODOT" --headless -s tests/run_tests.gd -- "$@"
if [[ "${SHOTS:-0}" == "1" ]]; then "$GODOT" -s tools/capture_screenshot.gd; fi

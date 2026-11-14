#!/usr/bin/env bash
# Full pipeline: rebuild generated scenes, import, run tests. Pass --shots to also capture screenshots.
set -euo pipefail
cd "$(dirname "$0")/.."
BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
if [[ "${REBUILD_ASSETS:-0}" == "1" ]]; then "$BLENDER" -b -P tools/blender/build_character.py | grep BUILD_CHARACTER_OK; fi
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
# macOS has no `timeout`; a GDScript parse error leaves a SceneTree script running forever.
t() { local secs=$1; shift; perl -e 'alarm shift; exec @ARGV' "$secs" "$@"; }
t 300 "$GODOT" --headless --import --quit >/tmp/lo_import.log 2>&1 || { cat /tmp/lo_import.log; exit 1; }
t 120 "$GODOT" --headless -s tools/build_player.gd
t 300 "$GODOT" --headless -s tools/build_level.gd 2>&1 | tee /tmp/lo_build.log | grep -E "build_level|SCRIPT ERROR" || true
if grep -q "SCRIPT ERROR" /tmp/lo_build.log || ! grep -q "build_level: saved" /tmp/lo_build.log; then echo "build_level failed"; exit 1; fi
t 300 "$GODOT" --headless --import --quit >/tmp/lo_import.log 2>&1 || { cat /tmp/lo_import.log; exit 1; }
if grep -E "SCRIPT ERROR|Parse Error|Failed loading resource" /tmp/lo_import.log; then echo "import errors"; exit 1; fi
t 600 "$GODOT" --headless -s tests/run_tests.gd -- "$@"
if [[ "${SHOTS:-0}" == "1" ]]; then t 300 "$GODOT" -s tools/capture_screenshot.gd; fi

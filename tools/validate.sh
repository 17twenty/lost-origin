#!/usr/bin/env bash
# Full pipeline: rebuild generated scenes, import, run tests. Pass --shots to also capture screenshots.
set -euo pipefail
cd "$(dirname "$0")/.."
BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
if [[ "${REBUILD_ASSETS:-0}" == "1" ]]; then
  for b in wicker:WICKER plants:PLANTS tree:TREE vines:VINES totem:TOTEM; do
    "$BLENDER" -b -P "tools/blender/build_${b%%:*}.py" | grep "BUILD_${b##*:}_OK" || { echo "blender build_${b%%:*} failed"; exit 1; }
  done
fi
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
# macOS has no `timeout`; a GDScript parse error leaves a SceneTree script running forever.
t() { local secs=$1; shift; perl -e 'alarm shift; exec @ARGV' "$secs" "$@"; }
t 300 "$GODOT" --headless --import --quit >/tmp/lo_import.log 2>&1 || { cat /tmp/lo_import.log; exit 1; }
t 120 "$GODOT" --headless -s tools/build_player.gd
t 120 "$GODOT" --headless -s tools/build_title.gd
t 300 "$GODOT" --headless -s tools/build_level.gd 2>&1 | tee /tmp/lo_build.log | grep -E "build_level|SCRIPT ERROR" || true
if grep -q "SCRIPT ERROR" /tmp/lo_build.log || ! grep -q "build_level: saved" /tmp/lo_build.log; then echo "build_level failed"; exit 1; fi
t 300 "$GODOT" --headless --import --quit >/tmp/lo_import.log 2>&1 || { cat /tmp/lo_import.log; exit 1; }
if grep -E "SCRIPT ERROR|Parse Error|Failed loading resource" /tmp/lo_import.log; then echo "import errors"; exit 1; fi
set +e
t 900 "$GODOT" --headless -s tests/run_tests.gd -- "$@" 2>&1 | tee /tmp/lo_tests.log
rc=${PIPESTATUS[0]}
set -e
# A runtime error inside a test aborts that test but the runner still prints PASS:
# treat any SCRIPT/SHADER error in the log as a failure.
if grep -qE "SCRIPT ERROR|SHADER ERROR" /tmp/lo_tests.log; then echo "VALIDATE: script/shader errors in test log"; grep -E "SCRIPT ERROR|SHADER ERROR" /tmp/lo_tests.log | sort | uniq -c | head; exit 1; fi
[[ $rc -eq 0 ]] || exit $rc
if [[ "${SHOTS:-0}" == "1" ]]; then t 300 "$GODOT" -s tools/capture_screenshot.gd; fi

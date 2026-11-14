#!/usr/bin/env bash
# Renders every Shot_Ref_* camera and writes art/compare/<name>.png:
# video reference (left) | in-game render (right), same height, labelled.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
perl -e 'alarm shift; exec @ARGV' 300 "$GODOT" -s tools/capture_screenshot.gd -- Shot_Ref_ | grep -E "captured|shots"
mkdir -p art/compare
n=0
for ref in art/reference/*.jpg; do
	name=$(basename "$ref" .jpg)
	shot="art/screens/ref_${name}.png"
	[[ -f "$shot" ]] || { echo "missing render for $name"; exit 1; }
	ffmpeg -loglevel error -y -i "$ref" -i "$shot" -filter_complex \
		"[0]scale=-1:720,drawtext=text='video  ${name}':x=12:y=12:fontsize=28:fontcolor=white:box=1:boxcolor=black@0.5[a];[1]scale=-1:720,drawtext=text='game  ${name}':x=12:y=12:fontsize=28:fontcolor=white:box=1:boxcolor=black@0.5[b];[a][b]hstack" \
		"art/compare/${name}.png"
	n=$((n + 1))
done
echo "compare_shots: ${n} pairs in art/compare/"

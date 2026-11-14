# Lost Origin

A playable Godot 4.7 proof of concept in the spirit of *Halo: CE meets Sonic Adventure*, built from `inspiration.mp4`. A tropical island of mossy totems and a striding aqueduct gives way to an open-air waterfall grotto and a Forerunner-style undersea facility.

You play **the Wicker Man**, an original woven protector summoned by the island's totems as its last, lost guardian. He weaves himself into existence, then sets out to find what high-tech infestation has taken root beneath the island.

**Play in the browser:** https://lost-origin.curiola.com

## The level
One seamless scene with seven compositions taken from the video:
- **Grotto** – open to the sky, with a waterfall plunge pool and a teleporter pad.
- **Lagoon** – totems standing in it.
- **Aqueduct** – mossy piers in turquoise shallows.
- **Garden room** – a mossy tree, skylight waterfalls and an octagonal pool.
- **Aquarium corridor** – fish schools and octagonal pools.
- **Atrium** – a water column, a ring walkway and a glass ceiling.
- **Control room** – a glass panorama onto the ocean.

There is also a secret: a lever in the control room plays a reveal cutscene and opens a hidden relic chamber. Water is never lethal; you wade in the shallows and swim in deep water.

## Controls (keyboard only; the mouse is optional)
| Key | Action |
|---|---|
| W A S D | Move (camera-relative) |
| Shift | Sprint |
| Space | Jump / swim stroke |
| Arrow keys | Orbit / pitch camera (the mouse also works) |
| R | Recenter camera |
| E | Interact (teleporter pads, the lever) |
| F1 | Toggle help |
| Esc | Pause menu |

In menus, W/S or the arrow keys move between items, and Enter or Space selects. The camera recenters itself behind you as you move.

## Running
Requires **Godot 4.7.2** (`/Applications/Godot.app`). Open `project.godot` in the editor and press Play; the main scene is the title screen `scenes/title.tscn`. Alternatively:
```sh
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## Building and testing
Every scene is generated; do not hand-edit the `.tscn` files under `scenes/`.

```sh
./tools/validate.sh               # import, regenerate player/title/level scenes, run all tests headless
SHOTS=1 ./tools/validate.sh       # ...and capture per-zone screenshots to art/screens/
REBUILD_ASSETS=1 ./tools/validate.sh   # ...and first rebuild the Blender GLBs (needs Blender.app)
```
- **Generators:**
  - `tools/build_player.gd` builds `scenes/player.tscn`.
  - `tools/build_title.gd` builds `scenes/title.tscn`.
  - `tools/build_level.gd` builds `scenes/main.tscn`, using the zone builders in `tools/level/`.
- **Blender assets:** in `tools/blender/build_*.py`, exported to `assets/characters/` and `assets/props/`. Run one headless with `Blender -b -P tools/blender/build_wicker.py`, or through the Blender MCP with `exec(open(path).read(), {'__name__': '__main__'})`. The conventions are in `.klaudia/skills/blender_glb_pipeline.md`: Z-up, front = −Y, `export_apply=False`, and actions pushed to NLA.
- **Tests:** `tests/test_*.gd`, run by `tests/run_tests.gd`. These are headless and cover routes, water, teleporters, the secret, the camera, menus and more. Pass a name filter after `--` to run a subset.
- **Real play-through:** `Godot -s tools/playthrough.gd` (not headless). It starts at the title screen and drives the whole route with keyboard input only, never warping the character. It logs camera glitches and saves a screenshot at each waypoint to `art/screens/play/`. Add `-- quick` for a shorter run.
- **Fidelity comparisons:** `./tools/compare_shots.sh` writes side-by-side pairs of render and video frame to `art/compare/`; set `WEB=1` to include Compatibility-renderer pairs. Notes are in `art/compare/NOTES.md`.
- **Benchmark:** `Godot -s tools/benchmark.gd | grep BENCH`. Close the editor first, or the numbers are invalid.

## Web export and deploy
```sh
./tools/export_web.sh                                   # -> build/web/ (budget: pck ≤ 80 MB, wasm ≤ 50 MB)
./tools/web_smoke.sh http://127.0.0.1:8765              # local headless-Chrome smoke test
./tools/web_smoke.sh https://lost-origin.curiola.com    # live smoke test
```
The export uses the Compatibility renderer and needs the 4.7.2 export templates. The live site is the local Caddy (`~/Sites/Caddyfile`, behind Cloudflare) serving `build/web/` directly, so running `export_web.sh` again *is* the deploy.

## Layout
```
scenes/        generated scenes (title, main level, player)
scripts/       runtime: player controller + camera, water, teleporters, secret/cutscene, summon intro, UI
shaders/       wicker weave, straw, water, ocean, foliage, facility metal, light shafts...
tools/         scene generators, level builders (tools/level/), Blender scripts (tools/blender/), validate/export/compare/playthrough
tests/         headless test suite
assets/        our GLBs (characters/, props/) and CC0 third-party packs (third_party/)
art/           reference frames, screenshots, comparisons, concepts
wicker-inspo/  Wicker Man turnaround (design) + weave/material reference
.klaudia/      GOAL.md (spec, acceptance criteria, progress notes) and skills
```

## Credits
See [CREDITS.md](CREDITS.md). Everything is original work or CC0.

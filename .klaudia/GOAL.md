# Goal: Lost Origin — playable proof-of-concept level

## Objective
Build a small playable Godot 4.7 (`/Applications/Godot.app`) proof of concept based on `inspiration.mp4`, which shows a tropical island with mossy totem ruins mixed with a Halo-CE-style undersea facility, with a hint of Sonic Adventure. The player controls an original armoured-explorer character in third person with an over-the-shoulder camera. Movement should feel Halo-weighted: run, sprint and jump, with real momentum. The level is one cohesive scene. Outside there is a lagoon beach, totem pillars, a ruined aqueduct bridge, and a jungle waterfall grotto with a glowing teleporter pad. Inside there is an undersea facility: a hex-tiled corridor with aquarium windows and octagonal pools, an atrium with a central water column and a ring walkway, and a control room. You can walk seamlessly from the grotto into the facility. A teleporter pair also links the control room and the grotto pad in both directions. Geometry is a mix of our own procedural or Blender meshes and CC0 assets (Kenney, Quaternius, Poly Haven). The mood should match the video: saturated blue sky and water, bloom, glowing cyan trim, and caustic-like water.

## Acceptance criteria
- [ ] The Godot project is in the repo root (`project.godot`) and imports headless with no errors.
- [ ] The character is our own rigged Blender model, exported as GLB using the `blender_glb_pipeline` rules (Z-up, `export_apply=False`). It has at least the `idle`, `run`, `sprint` and `jump` clips, and the in-game AnimationTree switches between them according to movement state.
- [ ] Third-person controller: WASD and mouse-look over-the-shoulder camera, sprint (Shift), and jump (Space) with acceleration and deceleration. The camera handles collisions, so it doesn't clip through walls in corridors.
- [ ] Outdoor zones exist and have collision: beach/lagoon (shader water), totem pillars, aqueduct bridge you can walk across, and waterfall grotto with the teleporter pad.
- [ ] Indoor zones exist and have collision: aquarium corridor (windows looking out on an underwater backdrop, plus octagonal pools), atrium (water column plus a ring walkway you can reach), and control room (consoles).
- [ ] There is a seamless path from the grotto to the facility (doorway, then a ramp or lift) with no loading screen.
- [ ] The teleporter pair (grotto pad ↔ control room pad) moves the player both ways, with a visual effect.
- [ ] The look: WorldEnvironment with glow/bloom, a bright sky, fog or volumetrics, emissive cyan trim indoors, and an animated water shader.
- [ ] CC0 assets are stored under `assets/third_party/`, with `CREDITS.md` listing each source URL and its licence.
- [ ] Scenes are built by re-runnable generator scripts in `tools/`, not by hand-splicing `.tscn` files.
- [ ] Automated tests in `tests/` pass headless. They cover: the player spawns on the ground, scripted input moves the player from the beach across the bridge into the grotto, the player walks down into the atrium through the seamless path, both teleporter directions work, and the player can't fall out of the world in any zone.
- [ ] `tools/capture_screenshot.gd` renders one in-game screenshot per zone (at least 6) to `art/screens/`. I'll review them against the video frames.

## Verify
```sh
cd /Users/nickglynn/Projects/lost-origin && \
GODOT=/Applications/Godot.app/Contents/MacOS/Godot && \
$GODOT --headless --import --quit && \
$GODOT --headless -s tests/run_tests.gd && \
$GODOT -s tools/capture_screenshot.gd && ls art/screens/*.png | wc -l
```
All tests report PASS (exit code 0) and there are at least 6 screenshots.

## Progress
- [x] Phase 1 — Project scaffold: Godot project, `tools/validate.sh`, test harness, screenshot tool, MCP availability check (gsol/grt/blender)
- [ ] Phase 2 — Character: Blender model + rig + clips → GLB; third-person controller + camera
- [ ] Phase 3 — Outdoor island: beach/lagoon, totems, aqueduct bridge, waterfall grotto w/ CC0 foliage
- [ ] Phase 4 — Indoor facility: aquarium corridor, atrium w/ water column + ring walkway, control room
- [ ] Phase 5 — Connections: seamless grotto→facility path + bidirectional teleporters
- [ ] Phase 6 — Look & polish: environment/bloom, water/caustic shaders, emissive trim, screenshots, credits

### Notes (resume here)
- **Done (Phase 1):** `project.godot` (Forward+, autoload `InputSetup` registers WASD/Space/Shift/E in code). `tools/build_level.gd` generates `scenes/main.tscn` (helpers in `tools/scene_util.gd`: `box_body`, `mat`, `marker`, `save`). Convention: `Main/Markers/Spawn`, `Main/Shots/Shot_*` markers (optional meta `player_pos`) → `tools/capture_screenshot.gd` writes `art/screens/<snake_name>.png` (needs non-headless; PNGs gitignored). Tests: `tests/test_*.gd` extend `TestCase` (`tests/test_case.gd`: `load_main`, `seconds`, `ground_below`, `check`); runner exits with failure count; filter via `-- <substr>`. `./tools/validate.sh` = import → build → import → tests (`SHOTS=1` to also capture).
- **Tooling status:** Blender MCP tools load but addon socket :9877 is not connected → use headless Blender 5.2.2 (`/Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/<script>.py`) with scripts committed in `tools/blender/`. Godot MCPs (grt/gsol) did not surface in-session; headless CLI is sufficient.
- **Remaining:** Phases 2–6. Placeholder ground is a 60×60 sand slab; sky currently overexposed (tune in Phase 6).
- **Next step:** Phase 2 — write `tools/blender/build_character.py` (armoured explorer, ~1.8 m, armature + idle/run/sprint/jump actions, export `assets/characters/explorer.glb` per blender_glb_pipeline), then `scripts/player.gd` (CharacterBody3D, Halo-weighted accel, SpringArm3D camera) instanced as `Main/Player` at Spawn, plus `tests/test_player.gd` (spawns grounded, scripted forward input moves it, jump leaves ground, anim state switches).

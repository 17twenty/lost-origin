# Fidelity notes — game vs `inspiration.mp4`

Pairs: `./tools/compare_shots.sh` → `art/compare/<name>.png` (video left, game right).

## Asset families (Phase 11 pass)

### Vegetation — done
- **Before:** Kenney Nature Kit low-poly palms/bushes/grass in pale pastel greens with pink/brown trunks; read as toy-like next to the video's lush, saturated jungle.
- **After:** our own Blender leaf-card plants (`tools/blender/build_plants.py`): curved ringed coconut palms with drooping pinnate fronds and coconuts, a bent palm, short palms, tree ferns, arching fern clumps, monstera with split broad leaves, grass tufts. Procedural frond/leaf/grass textures, alpha-cut + wind sway (`foliage.gdshader`). Routed through `LevelPlants.SUBSTITUTE` so every scatter call upgraded at once, sized to the Kenney model it replaces.
- **Deliberate difference:** still stylised (cards, flat-ish shading) rather than the video's dense painterly foliage; density is lower to protect the web frame budget.

### Rocks — done
- **Before:** Kenney rocks partly pastel tan/brown.
- **After:** every rock/stone surface uses the mossy rock shader (grey stone, moss on top faces).

### Totems — done
- **Before:** squat 4.35 m carved block with a finned crown; read as a stocky idol, not the video's tall shoreline monoliths.
- **After:** 7.6 m slender monolith (`build_totem.py`): tapered shaft with a carved band and glowing glyph channel, a heavy-browed carved head high up with glowing eye/mouth slits, a cap stone and crest; mossy weathered stone shader and hanging vines from the crown. Scales 0.75–1.15 so the shoreline row varies like the video.
### Garden tree — done (Phase 8b)
- **Before:** green blob canopy hiding the trunk. **After:** tall leaning mossy trunk with roots, high canopy, willow strands; reads left of the pool like f08.

### Facility kit — done
- **Before:** dark navy panels, near-black hex floor with many glowing seams, plain box corridor, raised pool tubs, flat box consoles, very hot cyan trim bloom.
- **After:** lighter blue-grey panelling (`facility_metal` base 0.55/0.62/0.72), pale reflective hex floor with rare glow seams, chamfered octagonal **arch frames** down the corridor with alternating cyan/violet light strips (f11–13), low flush-rim octagonal pools with a glowing bed and caustic water just under the lip (f12), round **console pods** with angled tops and holo screens in a row facing the panorama, **floor grates** either side of the pad (f20–23), softer trim emission (6 → 3.5).
- **Deliberate differences:** the control-room glass is a large flat panel rather than the video's curved full-height wall; ceilings keep the panel grid rather than the video's deep coffers.

### Water bodies — done
- Lagoon sun glints + caustic shimmer (Phase 10), turquoise shallow inlet, bluer waterfalls (darker blue body, white streaks), glowing sunken pools (grotto, garden, corridor).

### Lighting per composition — done
- Grotto: open sky + mesh sun shafts, toned-down haze; garden: skylight shafts; facility: lighter materials so rooms read bright like the video; ocean views: bluer gradient with distance haze.
- **Still different:** the video is more saturated and contrasty overall (painterly bloom); we keep a cleaner look to stay readable and web-friendly.

## Composition review (after the asset pass)
- **Grotto (f02):** open basin, waterfall from the lip, stepped glowing pad, jungle — matches; the pool is partly hidden by the pad from this camera.
- **Lagoon (f05):** tall mossy monolith row on a curved beach with sparkling turquoise shallows and gulls — matches; the beach is wider/flatter than the video's.
- **Garden (f08):** tree left, twin falls from the hex skylight, glowing octagonal pool — matches.
- **Corridor (f12):** octagonal arch frames with cyan/violet strips, windows with fish/kelp, sunken pools — matches.
- **Aqueduct (f15):** a long row of arched piers striding through shallow turquoise water with vines — matches; the piers are squarer and darker than the video's mossy round ones.
- **Atrium (f18):** glass column with fish, portholes onto the sea, glass ceiling, tube rail on the ring — matches; the column base glow is still hot.
- **Control (f21):** glass panorama onto kelp/coral/fish, a row of console pods, floor grates — matches.


## Quality-gap pass (Phase 13b)

### Wicker Man — part 1 done
- **Before:** tubular skin-modifier body, small head, mane rendered as a dark flat disc/fan, flat-lit weave, rigid straw, no body language.
- **After:**
  - **Anatomy:** a muscle displacement pass (pecs, delts, biceps/triceps, lats, traps, quads, teardrop, glutes, calves, six-pack, spine groove, V-taper) on thicker limbs and hands.
  - **Face:** head ×1.12 with a heavier brow, nose and woven cheekbones.
  - **Mane:** a round, fluffy ball of light straw (no disc).
  - **Boots:** woven (tighter Band weave below the ankle band).
  - **Weave shader:** a front-midline chevron on the chest and limbs, fibre grain, waxy strand sheen, warm backlight through the rattan, and a rim.
  - **Straw:** lighter tones, translucency, rim, and an emission lift so inner cards don't go black.
  - **Motion:** `mane`/`beard` spring bones driven by `WickerMotion` (a SkeletonModifier3D: lag behind head acceleration plus an idle breeze), chest breathing, the body leaning into acceleration and banking into turns, and a landing squash.
- **Still different:** muscle definition is softer than the sculpted turnaround (a skin-modifier base can't reach that detail without a sculpt/normal bake); legs are straighter; the weave pattern is larger in scale than the design's.

### Environment gaps — part 2 done
- **Aqueduct:**
  - **Before:** square, dark blue-grey piers in shade, with a deep-blue inlet.
  - **After:** round 16-sided piers with flared footings and capitals in a moss-stained stone material (whole aqueduct), 6 vines wrapped around each pier, and a turquoise shallow inlet with reduced sparkle. `Shot_Ref_Aqueduct` now views the sunlit west face like f15.
  - **Still different:** the arch openings read dark against the shaded east bank.
- **Atrium column:**
  - **Before:** blown-out cyan base and cap glow.
  - **After:** soft trim on the caps, the column light 4.0 → 2.2, and the water-column shader darkened toward its ends.
- **Control glass:**
  - **Before:** a flat panel.
  - **After:** a curved 6-panel glass bay bulging out of the east wall, with mullions, glowing rails, a bay floor and ceiling (walkable), and the ocean box moved out. The facility pad is now machined metal instead of mossy stone. `Shot_Ref_Control` moved closer.

### Worst offenders — part 3 done
- **Grotto (f02):**
  - **Before:** the pad sat between the camera and the pool, hiding it.
  - **After:** the pad moved front-right of the pool (4, -73) like f01–02; the pool water is a glowing blue (own water material, brighter bed); the light shaft is softer; and `Shot_Ref_Grotto` is elevated, looking down at the pool and pad.
  - **Still different:** the floor is a flat bright turf rather than the video's dense fern carpet.
- **Aqueduct (f15):**
  - **Before:** the arch openings were low and read dark.
  - **After:** the deck was raised to 4.3 m (`DECK_Y`), so the tall piers show sky and sea under the arches.
- **Lagoon (f05):**
  - **Before:** viewed from the sand with a wide flat beach in the foreground.
  - **After:** `Shot_Ref_Lagoon` stands in the sparkling shallows with the totem row receding along the curving beach.

## Final fidelity review (Phase 20) — desktop (Forward+) and web (WebGL2 / Compatibility)

Pairs: `art/compare/<name>.png` (desktop) and `art/compare/web_<name>.png` (web), via `WEB=1 ./tools/compare_shots.sh`.

| Composition | Matches the video | Deliberate / known differences | Web vs desktop |
|---|---|---|---|
| **Grotto (f01–03)** | Open basin under the sky, waterfall off the cliff lip, glowing blue pool, stepped pad with halo, jungle and vines, slanting sun shafts | Floor is mossy turf, not the video's dense fern carpet; cliffs are lighter grey-green | No volumetric haze; mesh shafts carry the look (toned ×0.45); a little brighter |
| **Lagoon (f04–06)** | Tall mossy monolith row receding along a curved white beach, sparkling turquoise shallows, gulls, saturated sky | Beach is wider and flatter; the island hill is closer and bigger | Very close (depth-NDC fix keeps the turquoise gradient) |
| **Garden (f07–10)** | Mossy tree left of twin falls from the hex skylight, glowing octagonal pool, ferns, light shafts | Panelling is plainer than the video's detailed bulkheads; one large hex skylight rather than a lattice of panes | Close; skylight shafts read stronger |
| **Corridor (f11–13)** | Octagonal cyan/violet arch frames, aquarium windows with fish/kelp/coral, sunken glowing pools, pale hex floor | Window frames are rectangular rather than the video's rounded octagonal portals | Close |
| **Aqueduct (f14–16)** | Long row of round, moss-stained piers with hanging vines striding through shallow turquoise water | Far side of the arches reads dark against the shaded bank; no white sandbars | Close; slightly less sparkle |
| **Atrium (f17–19)** | Glass water column with fish, portholes onto the sea, glass ceiling, tube-rail ring walkway | Column base glow still stronger than the video; portholes are wide octagons rather than rounded rectangles | Column toned ×0.6 on web (it clipped to white) |
| **Control (f20–23)** | Curved multi-panel glass bay onto kelp/coral/fish, row of console pods, floor grates | Glass bay is narrower than the video's full-height wraparound; ceiling coffers simpler | Close |

**Cross-cutting:**
- **Style:** the video's look is painterly and very saturated with heavy bloom. We stay cleaner and stylised (CC0/own low-poly + procedural shaders) so it stays readable and runs on WebGL2.
- **Player character:** the Wicker Man (an original design, not in the video).
- **Performance (desktop, uncontended):** `tools/benchmark.gd` avg 98–101 / min 94 FPS on every `Shot_Ref_*`.
- **Performance (web):** headless Chrome on the M2 (ANGLE Metal) avg 47–57 / min 35 FPS while playing.

## Wicker Man fidelity round 2 (post-launch)
- **Found via the play-through:** chest "breathing" multiplied the bone scale every frame (the clips don't key scale), so the Wicker Man grew without limit during long sessions (giant in the control room). Now absolute + regression test `test_breathing_does_not_grow_the_body`.
- **Model:**
  - Braided bands (3 twisted strands) at the wrists/knees/ankles/belt, a woven band round the ribcage, a sternum ridge, and woven boot rims.
  - Layered leaf-shaped lames + a ridge on the pauldrons.
  - Jaw, nose bridge and eye-socket rims on the face; a fuller beard (260 cards).
  - Extra anatomy blobs (knee caps, quad sweep, inner-thigh gap, diamond calves, serratus, shoulder caps).
  - Triangle budget kept at 23k (diamond-section braid strands).
- **Shader:** finer weave (density 64 / bands 90); muted khaki rattan like the turnaround (was orange); less backlight.
- **Turnaround shots:** moved to neutral beach daylight (the ring's warm light was tinting him).
- **Still different:** arm silhouette is more tubular than the sculpted design; the mane reads as a spiky crown rather than a full round halo; the back view sits in shade.

## Wicker Man round 3 (detube + spiky hair)
- **Body:** a CC0 anatomical base (Quaternius superhero) on our rig, so limbs now taper deltoid→elbow→wrist and thigh→knee→calf→ankle. The proportions are closer to the turnaround: longer legs, V-taper torso.
- **Hair:** stiff tapered quills in clumps over the whole scalp, swept back and windblown, longer at the crown and back, with lighter tips. It reads as spiky woven hair, not a crown or fan. The beard is coarse, short and hanging.
- **Remaining gaps vs the sheet:**
  - The face is the generic base face under weave: no strong brow.
  - The torso weave still shows block patches at panel borders.
  - The body tone is lighter than the sheet under neutral studio light.

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
### Facility kit (arches, panels, consoles, grates) — to do
### Water bodies — partly (glints/caustics done in Phase 10; sunken corridor pools to do)

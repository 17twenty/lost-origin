extends TestCase
## Mechanical checks for the "look" acceptance criterion.

func test_environment_has_bloom_sky_and_fog() -> void:
	await load_main()
	var env: Environment = (scene.get_node("WorldEnvironment") as WorldEnvironment).environment
	check(env.glow_enabled, "glow/bloom enabled")
	check(env.background_mode == Environment.BG_SKY and env.sky.sky_material is ShaderMaterial, "custom sky shader")
	check(env.fog_enabled, "depth fog enabled")
	check(env.volumetric_fog_enabled, "volumetric fog enabled")
	check(scene.find_children("*", "FogVolume", true, false).size() >= 3, "fog volumes in grotto/corridor/atrium (Forward+)")
	var spots := 0
	for n in scene.find_children("*", "Node3D", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("fog_spot.gd"):
			spots += 1
	check(spots >= 3, "fog spots defined (web build skips their FogVolumes)")

func test_animated_water_shaders_in_use() -> void:
	await load_main()
	var used := {}
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var m: Material = mi.material_override
		if m == null and mi.mesh and mi.mesh.get_surface_count() > 0:
			m = mi.mesh.surface_get_material(0)
		if m is ShaderMaterial and m.shader:
			used[m.shader.resource_path.get_file()] = true
	for sh in ["water.gdshader", "waterfall.gdshader", "water_column.gdshader", "underwater.gdshader"]:
		check(used.has(sh), "%s used in level" % sh)
		if used.has(sh):
			check(load("res://shaders/" + sh).code.contains("TIME"), "%s is animated" % sh)

func test_indoor_cyan_trim_is_emissive() -> void:
	await load_main()
	var trims := 0
	for mi: MeshInstance3D in scene.get_node("Level/Facility").find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is BoxMesh:
			var m := (mi.mesh as BoxMesh).material as StandardMaterial3D
			if m and m.emission_enabled and m.emission.b > 0.8 and m.emission.r < 0.4:
				trims += 1
	check(trims >= 20, "cyan emissive trim strips indoors (%d)" % trims)

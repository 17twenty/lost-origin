extends TestCase
## Phase 10 fidelity: vines, light shafts, open grotto.

func test_at_least_40_hanging_vines() -> void:
	await load_main()
	var n := 0
	for v in tree.get_nodes_in_group("vines"):
		n += (v.transforms as Array).size()
		var mesh: Mesh = v.mesh
		var m := mesh.surface_get_material(0) as ShaderMaterial
		check(m != null and m.shader.resource_path.ends_with("vine.gdshader"), "%s uses the sway shader" % v.name)
	check(n >= 40, "vine instances %d >= 40" % n)

func test_grotto_open_to_sky_with_light_shafts() -> void:
	await load_main()
	var space := (scene as Node3D).get_world_3d().direct_space_state
	for p in [Vector3(0, 1.0, -71), Vector3(0, 1.0, -81)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.UP * 60.0))
		check(hit.is_empty(), "open sky above %s (hit %s)" % [p, hit.get("collider")])
	var shafts := scene.get_node("Level/Outdoor/Grotto").find_children("LightShaft*", "MeshInstance3D", false, false)
	check(shafts.size() >= 2, "visible light shafts in the grotto (%d)" % shafts.size())
	check(scene.get_node_or_null("Level/Outdoor/Grotto/TeleporterGrotto/Halo") != null, "stepped pad has its raised halo ring")

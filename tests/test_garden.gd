extends TestCase
## Garden room: content checks + it's on the walking route.

func test_garden_has_tree_falls_skylight_pool() -> void:
	await load_main()
	var g: Node3D = scene.get_node("Level/Garden")
	check(g.get_node_or_null("Tree") != null, "mossy tree present")
	var tree_mesh: MeshInstance3D = g.get_node("Tree/Mesh")
	var shaders := {}
	for i in tree_mesh.mesh.get_surface_count():
		var m := tree_mesh.mesh.surface_get_material(i)
		if m is ShaderMaterial:
			shaders[m.shader.resource_path.get_file()] = true
	check(shaders.has("foliage.gdshader") and shaders.has("mossy_stone.gdshader"), "tree uses foliage + mossy bark shaders (%s)" % [shaders.keys()])
	var falls := 0
	for c in g.get_children():
		if String(c.name).begins_with("Fall"):
			falls += 1
	check(falls >= 2, "twin waterfalls (%d)" % falls)
	check(g.get_node_or_null("Skylight/SeaAbove") != null, "sea visible above the hex skylight")
	check(g.find_children("*", "FogVolume", true, false).size() >= 1 and g.find_children("*", "SpotLight3D", true, false).size() >= 1, "light shaft (spot + haze)")

func test_pool_rim_and_tree_collide() -> void:
	await load_main()
	var space := (scene as Node3D).get_world_3d().direct_space_state
	var pool: Node3D = scene.get_node("Level/Garden/OctPool")
	var from := pool.global_position + Vector3(0, 0.3, 6.0)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, pool.global_position + Vector3(0, 0.3, 0)))
	check(not hit.is_empty(), "octagonal pool rim has collision")
	var tree: Node3D = scene.get_node("Level/Garden/Tree")
	var th := space.intersect_ray(PhysicsRayQueryParameters3D.create(tree.global_position + Vector3(-3, 1, 0), tree.global_position + Vector3(0, 1, 0)))
	check(not th.is_empty(), "tree trunk has collision")

func test_walk_tunnel_through_garden_to_corridor() -> void:
	await load_main()
	var p := get_player()
	p.warp_to((scene.get_node("Markers/Zone_TunnelBottom") as Node3D).global_transform)
	await seconds(0.3)
	for z in ["Zone_GardenEntry", "Zone_Garden", "Zone_GardenExit", "Zone_CorridorSouthDoor", "Zone_Corridor"]:
		var ok := await walk_to(marker_pos(z), 12.0, false, 0.7)
		if not check(ok, "reached %s (stuck at %s)" % [z, p.global_position]):
			return
	check(p.is_on_floor(), "standing in the corridor")

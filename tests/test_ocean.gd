extends TestCase
## Sea life and ocean views.

func _fish_total() -> int:
	var n := 0
	for f in tree.get_nodes_in_group("fish"):
		n += int(f.count)
	return n

func test_at_least_30_fish_and_they_swim() -> void:
	await load_main()
	check(_fish_total() >= 30, "fish total %d >= 30" % _fish_total())
	var schools := tree.get_nodes_in_group("fish")
	var before := []
	for s: MultiMeshInstance3D in schools:
		before.append(s.positions[0])
	await seconds(1.0)
	var moved := 0
	for i in schools.size():
		var s: MultiMeshInstance3D = schools[i]
		if s.positions[0].distance_to(before[i]) > 0.05:
			moved += 1
	check(moved == schools.size(), "every school moved (%d/%d)" % [moved, schools.size()])

func test_fish_in_each_viewing_area() -> void:
	await load_main()
	var where := {}
	for f: Node in tree.get_nodes_in_group("fish"):
		var p := String(f.get_path())
		for area in ["AquariumCorridor", "WaterColumn", "ControlRoom"]:
			if p.contains(area):
				where[area] = true
	for area in ["AquariumCorridor", "WaterColumn", "ControlRoom"]:
		check(where.has(area), "fish visible from %s" % area)

func test_kelp_and_coral_on_sea_floor() -> void:
	await load_main()
	var kelp := 0
	for mmi: MultiMeshInstance3D in scene.find_children("Kelp", "MultiMeshInstance3D", true, false):
		var m := mmi.material_override as ShaderMaterial
		if m and m.shader.resource_path.ends_with("kelp.gdshader"):
			kelp += mmi.transforms.size()
	check(kelp >= 40, "swaying kelp instances (%d)" % kelp)
	check(scene.find_children("Coral*", "Node3D", true, false).size() >= 10, "coral clusters")

func test_control_panorama_glass_is_solid() -> void:
	await load_main()
	var p := get_player()
	p.warp_to((scene.get_node("Markers/Zone_Control") as Node3D).global_transform)
	p.global_position = Vector3(73.0, -2.45, -84.8)
	await walk_to(Vector3(95, -2.5, -84.8), 3.0)
	check(p.global_position.x < 77.9 and p.global_position.x > 74.5, "curved glass bay: walk into the bay, glass stops you (x=%.2f)" % p.global_position.x)
	check(scene.find_children("Panorama*", "StaticBody3D", true, false).size() >= 5, "multi-panel curved glass")

func test_atrium_portholes_and_ceiling_glass() -> void:
	await load_main()
	var space := (scene as Node3D).get_world_3d().direct_space_state
	var hits := 0
	for gl: Node3D in scene.get_node("Level/Facility/Atrium/Portholes").get_children():
		if not String(gl.name).begins_with("PortholeGlass"):
			continue
		var c := Vector3(50, gl.global_position.y, -88)
		var dir := (gl.global_position - c)
		dir.y = 0
		var from := c + dir.normalized() * 8.0
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, gl.global_position + dir.normalized() * 0.5))
		if not hit.is_empty() and hit.collider == gl:
			hits += 1
	check(hits >= 12, "porthole glass collides (%d/12)" % hits)
	var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(54.5, -2.0, -88), Vector3(54.5, 12.0, -88)))
	check(not up.is_empty() and String((up.collider as Node).get_path()).contains("CeilingGlass"), "glass ceiling above the atrium")
	check(scene.get_node_or_null("Level/Facility/Atrium/OceanAbove") != null, "sea visible above the ceiling")

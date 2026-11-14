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
	check(p.global_position.x < 74.2, "panorama glass stops the player (x=%.2f)" % p.global_position.x)

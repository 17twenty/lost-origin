extends TestCase

func test_main_scene_loads() -> void:
	await load_main()
	check(scene != null, "main scene instantiates")
	check(scene.get_node_or_null("WorldEnvironment") != null, "has WorldEnvironment")

func test_spawn_has_ground() -> void:
	await load_main()
	var spawn: Node3D = scene.get_node_or_null("Markers/Spawn")
	if not check(spawn != null, "Spawn marker exists"):
		return
	var hit := ground_below(spawn.global_position + Vector3.UP * 0.5)
	check(not hit.is_empty(), "collision ground below Spawn")

func test_input_actions_registered() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint"]:
		check(InputMap.has_action(a), "input action %s" % a)

extends TestCase
## Water is never lethal: wading, swimming, buoyancy, kick, climbing out.

func test_deep_inlet_swims_with_head_above_water() -> void:
	await load_main()
	var p := get_player()
	p.global_position = Vector3(10.0, -1.0, -18.0)
	await seconds(3.0)
	check_eq(p.water_state, "swim", "deep channel -> swimming")
	check_eq(p.anim_state, "swim", "swim clip plays")
	var surface: float = p.water_surface
	check(p.global_position.y + 2.0 > surface + 0.25, "head above the surface (head %.2f vs %.2f)" % [p.global_position.y + 2.0, surface])
	check(p.global_position.y < surface, "body in the water (feet %.2f)" % p.global_position.y)

func test_space_kicks_up_while_swimming() -> void:
	await load_main()
	var p := get_player()
	p.global_position = Vector3(10.0, -1.0, -18.0)
	await seconds(2.0)
	Input.action_press("jump")
	var max_vy := 0.0
	for i in 10:
		await tree.physics_frame
		max_vy = maxf(max_vy, p.velocity.y)
	Input.action_release("jump")
	check(max_vy > 3.0, "kick up (vy %.2f)" % max_vy)

func test_wading_is_slower_than_running() -> void:
	await load_main()
	var p := get_player()
	p.global_position = Vector3(18.0, 0.0, -55.0)  # plunge pool, about 1.3 m deep
	await seconds(1.0)
	check_eq(p.water_state, "wade", "plunge pool -> wading")
	p.cam_yaw.rotation.y = PI / 2.0  # face -X across the pool
	Input.action_press("move_forward")
	var vmax := 0.0
	for i in 60:
		await tree.physics_frame
		if p.water_state == "wade":
			vmax = maxf(vmax, Vector2(p.velocity.x, p.velocity.z).length())
	Input.action_release("move_forward")
	check(vmax > 1.0 and vmax < p.run_speed * 0.75, "wading speed %.2f < run %.2f" % [vmax, p.run_speed])

func test_every_pool_is_water() -> void:
	await load_main()
	var names := []
	for w in tree.get_nodes_in_group("water"):
		names.append(String(w.name))
	for n in ["InletWater", "LagoonWater", "PlungePoolWater", "GrottoPoolWater", "GardenPoolWater"]:
		check(names.has(n), "%s is a water volume" % n)
	check(scene.find_children("ChasmKill", "", true, false).is_empty(), "no chasm kill zone")

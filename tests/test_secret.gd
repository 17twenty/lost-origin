extends TestCase
## Secret switch, reveal cutscene and relic chamber.

func _lever() -> Node3D:
	return scene.get_node("Level/Facility/ControlRoom/SecretLever")

func _reveal() -> Node:
	return scene.get_node("Level/Facility/ControlRoom/RevealCutscene")

func _stand_at_lever(p: CharacterBody3D) -> void:
	p.warp_to((scene.get_node("Markers/Zone_LeverFront") as Node3D).global_transform)
	p.global_position = marker_pos("Zone_LeverFront")
	p.model.rotation.y = PI   # face the lever on the north wall (-Z)
	await seconds(0.4)

func _press_e() -> void:
	Input.action_press("interact")
	await physics_frames(2)
	Input.action_release("interact")
	await physics_frames(1)

func test_e_out_of_range_does_nothing() -> void:
	await load_main()
	var p := get_player()
	p.warp_to((scene.get_node("Markers/Zone_Control") as Node3D).global_transform)
	p.global_position = Vector3(67.0, -2.45, -85.0)
	await seconds(0.4)
	check(not _lever().prompt.visible, "no prompt out of range")
	await _press_e()
	check(not _lever().used and _reveal().state == "idle", "E out of range does nothing")

func test_pull_reveal_and_enter() -> void:
	await load_main()
	var p := get_player()
	await _stand_at_lever(p)
	check(_lever().prompt.visible, "E-Pull prompt in range and facing")
	var door_col := scene.get_node("Level/Facility/ControlRoom/SecretDoor/Col") as CollisionShape3D
	check(not door_col.disabled, "door sealed before the pull")
	await _press_e()
	check(_lever().used, "lever pulled")
	check_eq(_reveal().state, "playing", "cutscene started")
	check(p.input_locked, "movement input ignored during the cutscene")
	await seconds(1.0)
	check(_reveal().cam != null and _reveal().cam.current, "cutscene camera is current")
	var start := p.global_position
	Input.action_press("move_forward")
	await seconds(0.5)
	Input.action_release("move_forward")
	check(p.global_position.distance_to(start) < 0.1, "player can't move during the reveal")
	var t := 1.5
	while _reveal().state != "done" and t < 6.0:
		await seconds(0.25)
		t += 0.25
	check(_reveal().state == "done" and t <= 6.0, "camera back on the player within 6 s (t=%.2f)" % t)
	check(p.camera.current and not p.input_locked, "player camera + control restored")
	check(door_col.disabled, "door collision removed once open")
	# Second press: nothing.
	await _stand_at_lever(p)
	await _press_e()
	check(_reveal().state == "done" and not p.input_locked, "second E does nothing")
	# Walk into the relic chamber.
	for z in ["Zone_SecretDoor", "Zone_Secret"]:
		var ok := await walk_to(marker_pos(z), 10.0, false, 0.6)
		check(ok, "reached %s (at %s)" % [z, p.global_position])
	check(p.global_position.z < -93.0, "inside the secret room")

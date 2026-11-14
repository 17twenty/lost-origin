extends TestCase
## Seamless grotto -> facility walk and the two-way teleporter pair.

const DESCENT := ["Zone_GrottoDoor", "Zone_TunnelTop", "Zone_RampMid", "Zone_TunnelBottom", "Zone_GardenEntry", "Zone_Garden", "Zone_GardenExit", "Zone_CorridorSouthDoor", "Zone_Corridor", "Zone_CorridorEnd", "Zone_Atrium"]

func test_ground_under_tunnel() -> void:
	await load_main()
	for z in DESCENT:
		var hit := ground_below(marker_pos(z) + Vector3.UP * 0.8, 3.0)
		check(not hit.is_empty() and abs(hit.position.y - marker_pos(z).y) < 0.4, "floor under %s" % z)

func test_walk_from_beach_down_into_atrium() -> void:
	await load_main()
	var p := get_player()
	await seconds(0.3)
	var route := ["Zone_BridgeSouth", "Zone_BridgeMid", "Zone_BridgeNorth", "Zone_Plateau", "Zone_GrottoEntrance", "Zone_GrottoDoor"]
	route.append_array(DESCENT.slice(1))
	for z in route:
		var ok := await walk_to(marker_pos(z), 25.0, true, 0.9)
		if not check(ok, "reached %s (stuck at %s)" % [z, p.global_position]):
			return
	await seconds(0.3)
	check(p.is_on_floor(), "on the atrium floor")
	check(abs(p.global_position.y - marker_pos("Zone_Atrium").y) < 0.3, "at facility floor level (y=%.2f)" % p.global_position.y)
	check(min_y_seen > -7.0, "never fell out of the world (min y=%.2f)" % min_y_seen)

func _pad(path: String) -> Node3D:
	return scene.get_node(path)

func _press_e() -> void:
	Input.action_press("interact")
	await physics_frames(2)
	Input.action_release("interact")
	await seconds(0.3)

func test_teleport_grotto_to_facility_and_back() -> void:
	await load_main()
	var p := get_player()
	var gpad := _pad("Level/Outdoor/Grotto/TeleporterGrotto")
	var fpad := _pad("Level/Facility/ControlRoom/TeleporterFacility")
	var g_trig := gpad.get_node("Trigger")
	var f_trig := fpad.get_node("Trigger")
	var f_arrival: Vector3 = fpad.get_node("Arrival").global_position
	var g_arrival: Vector3 = gpad.get_node("Arrival").global_position
	# Grotto -> facility: start at the grotto marker, walk onto the pad.
	p.warp_to((scene.get_node("Markers/Zone_GrottoEntrance") as Node3D).global_transform)
	await seconds(0.3)
	await walk_to(gpad.global_position, 15.0, false, 0.3)
	await seconds(0.5)
	check(p.global_position.distance_to(f_arrival) > 10.0, "standing on a pad does not teleport by itself")
	check(g_trig.prompt.visible, "E — Teleport prompt on the pad")
	await _press_e()
	check(p.global_position.distance_to(f_arrival) < 1.5, "arrived in control room (pos=%s, expected %s)" % [p.global_position, f_arrival])
	check(g_trig.flash_count >= 1 and f_trig.flash_count >= 1, "flash effect at both pads (%d/%d)" % [g_trig.flash_count, f_trig.flash_count])
	check((fpad.get_node("Beam") as Node3D).visible, "arrival beam visible right after teleport")
	await seconds(1.0)
	check(p.is_on_floor(), "standing in the control room")
	check(p.global_position.distance_to(f_arrival) < 1.5, "no ping-pong back to the grotto")
	# Facility -> grotto: step back onto the facility pad.
	await walk_to(fpad.global_position, 10.0, false, 0.3)
	await seconds(0.5)
	await _press_e()
	check(p.global_position.distance_to(g_arrival) < 1.5, "arrived back in the grotto (pos=%s, expected %s)" % [p.global_position, g_arrival])
	await seconds(1.0)
	check(p.is_on_floor(), "standing in the grotto")

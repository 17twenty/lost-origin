extends TestCase
## Outdoor island: route walk, collision under every zone, kill zones, bounds.

const ROUTE := ["Zone_BridgeSouth", "Zone_BridgeMid", "Zone_BridgeNorth", "Zone_Plateau", "Zone_GrottoEntrance", "Zone_GrottoInside"]
const ZONES := ["Spawn", "Zone_Beach", "Zone_BridgeSouth", "Zone_BridgeMid", "Zone_BridgeNorth", "Zone_Plateau", "Zone_GrottoEntrance", "Zone_GrottoPad"]

func test_player_spawns_on_beach_ground() -> void:
	await load_main()
	await seconds(1.0)
	var p := get_player()
	check(p.is_on_floor(), "player grounded at spawn")
	check(p.global_position.distance_to(marker_pos("Spawn")) < 0.5, "player still at spawn (pos=%s)" % p.global_position)

func test_ground_under_every_zone() -> void:
	await load_main()
	for z in ZONES:
		var hit := ground_below(marker_pos(z) + Vector3.UP * 1.0, 5.0)
		check(not hit.is_empty(), "collision ground under %s" % z)

func test_walk_beach_across_bridge_into_grotto() -> void:
	await load_main()
	await seconds(0.3)
	var p := get_player()
	for z in ROUTE:
		var ok := await walk_to(marker_pos(z), 25.0, true)
		if not check(ok, "reached %s (stuck at %s)" % [z, p.global_position]):
			return
	check(min_y_seen > -1.0, "never fell below the path (min y=%.2f)" % min_y_seen)
	await seconds(0.5)
	check(p.is_on_floor(), "standing in the grotto")

func test_jump_off_aqueduct_lands_in_shallows_no_respawn() -> void:
	await load_main()
	var p := get_player()
	p.global_position = Vector3(6.0, 4.0, -18.0)  # beside the deck, above the inlet
	await seconds(2.0)
	check(p.global_position.y < -0.2 and p.global_position.y > -2.6, "standing in the inlet shallows (y=%.2f)" % p.global_position.y)
	check(abs(p.global_position.z + 18.0) < 1.5 and abs(p.global_position.x - 6.0) < 1.5, "not warped to a checkpoint (pos=%s)" % p.global_position)
	check(p.is_on_floor(), "on the inlet floor")

func test_can_climb_out_of_inlet() -> void:
	await load_main()
	var p := get_player()
	p.global_position = marker_pos("Zone_Inlet") + Vector3(0, 0.3, 0)
	await seconds(0.5)
	var ok := await walk_to(Vector3(7.0, 0, 2.0), 15.0)
	check(ok and p.global_position.y > 0.0, "walked up the bank onto the beach (pos=%s)" % p.global_position)

func test_aqueduct_has_piers_in_water() -> void:
	await load_main()
	var space := (scene as Node3D).get_world_3d().direct_space_state
	var piers := 0
	for k in 8:
		var z := -6.5 - k * (23.0 / 7.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(5, -0.5, z), Vector3(0, -0.5, z)))
		if not hit.is_empty() and String((hit.collider as Node).get_path()).contains("AqueductBridge"):
			piers += 1
	check(piers >= 8, "piers standing in the water (%d)" % piers)

func test_world_kill_floor_catches_falls() -> void:
	await load_main()
	var p := get_player()
	p.global_position = Vector3(0, -50, 0)
	await seconds(2.5)
	check(p.global_position.y > -1.0, "caught by world kill floor (y=%.2f)" % p.global_position.y)

func test_cannot_wade_out_to_sea() -> void:
	await load_main()
	var p := get_player()
	await walk_to(Vector3(0, 0, 60), 10.0, true)
	check(p.global_position.z < 30.0, "lagoon boundary holds (z=%.2f)" % p.global_position.z)
	check(p.global_position.y > -2.0, "still standing in the shallows (y=%.2f)" % p.global_position.y)

func test_cannot_leave_through_side_hills() -> void:
	await load_main()
	var p := get_player()
	p.global_position = marker_pos("Zone_Plateau")
	await walk_to(Vector3(80, 0, -44), 12.0, true)
	check(p.global_position.x < 52.0, "east boundary holds (x=%.2f)" % p.global_position.x)

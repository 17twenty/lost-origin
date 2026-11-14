extends TestCase
## Outdoor island: route walk, collision under every zone, kill zones, bounds.

const ROUTE := ["Zone_BridgeSouth", "Zone_BridgeMid", "Zone_BridgeNorth", "Zone_Plateau", "Zone_GrottoEntrance", "Zone_GrottoPad"]
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

func test_chasm_fall_respawns_at_checkpoint() -> void:
	await load_main()
	var p := get_player()
	p.global_position = Vector3(10, -2, -18)  # mid-air over the river
	await seconds(2.0)
	check(p.global_position.y > -1.0, "respawned above ground (y=%.2f)" % p.global_position.y)
	var nearest := INF
	for cp in tree.get_nodes_in_group("checkpoint"):
		nearest = min(nearest, cp.global_position.distance_to(p.global_position))
	check(nearest < 1.0, "respawned at a checkpoint (dist=%.2f)" % nearest)

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

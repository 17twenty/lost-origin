extends TestCase
## Undersea facility: collision under every indoor zone and a walk from the
## corridor, through the atrium, up the ramp, round the ring into control.

const ZONES := ["Zone_Vestibule", "Zone_Corridor", "Zone_CorridorEnd", "Zone_Atrium", "Zone_RampBottom", "Zone_RampTop", "Zone_AtriumRing", "Zone_RingSE", "Zone_RingEast", "Zone_Control"]
const ROUTE := ["Zone_CorridorEnd", "Zone_Atrium", "Zone_RampBottom", "Zone_RampTop", "Zone_AtriumRing", "Zone_RingSE", "Zone_RingEast", "Zone_Control"]

func test_ground_under_every_indoor_zone() -> void:
	await load_main()
	for z in ZONES:
		var hit := ground_below(marker_pos(z) + Vector3.UP * 0.8, 3.0)
		if check(not hit.is_empty(), "collision floor under %s" % z):
			check(abs(hit.position.y - marker_pos(z).y) < 0.4, "%s floor at expected height (hit %.2f vs %.2f)" % [z, hit.position.y, marker_pos(z).y])

func test_ceiling_clearance_on_route() -> void:
	await load_main()
	var space := (scene as Node3D).get_world_3d().direct_space_state
	for z in ZONES:
		var p := marker_pos(z) + Vector3.UP * 0.2
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.UP * 2.2))
		check(hit.is_empty(), "head room above %s (hit %s)" % [z, hit.get("collider")])

func test_walk_corridor_atrium_ring_control() -> void:
	await load_main()
	var p := get_player()
	p.warp_to((scene.get_node("Markers/Zone_Corridor") as Node3D).global_transform)
	await seconds(0.3)
	for z in ROUTE:
		var ok := await walk_to(marker_pos(z), 15.0, false, 0.8)
		if not check(ok, "reached %s (stuck at %s)" % [z, p.global_position]):
			return
	await seconds(0.3)
	check(p.is_on_floor(), "standing in control room")
	check(abs(p.global_position.y - marker_pos("Zone_Control").y) < 0.3, "at ring level in control (y=%.2f)" % p.global_position.y)

func test_windows_are_solid() -> void:
	await load_main()
	var p := get_player()
	p.warp_to((scene.get_node("Markers/Zone_Corridor") as Node3D).global_transform)
	p.global_position = Vector3(30, -5.95, -88)
	await walk_to(Vector3(30, -6, -110), 3.0)
	check(p.global_position.z > -92.2, "glass stops the player (z=%.2f)" % p.global_position.z)

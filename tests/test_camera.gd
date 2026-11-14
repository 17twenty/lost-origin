extends TestCase
## Assisted camera, playable without a mouse.

var player: CharacterBody3D

func _fixture() -> void:
	scene = Node3D.new()
	tree.root.add_child(scene)
	scene.add_child(SceneUtil.box_body(Vector3(200, 1, 200), Vector3(0, -0.5, 0), null, "Floor"))
	player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	scene.add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	player.snap_camera()
	await seconds(0.5)

func test_camera_height_steady_through_jump() -> void:
	await _fixture()
	var y0: float = player.cam_yaw.global_position.y
	Input.action_press("jump")
	var dev := 0.0
	for i in 70:
		await tree.physics_frame
		dev = maxf(dev, absf(player.cam_yaw.global_position.y - y0))
	Input.action_release("jump")
	check(dev < 0.15, "camera pivot steady during a jump (max dev %.3f)" % dev)

func test_arrow_keys_orbit() -> void:
	await _fixture()
	var y0: float = player.cam_yaw.rotation.y
	Input.action_press("cam_left")
	await seconds(0.5)
	Input.action_release("cam_left")
	check(absf(wrapf(player.cam_yaw.rotation.y - y0, -PI, PI)) > 0.6, "arrow keys turn the camera")
	var p0: float = player.cam_pitch.rotation.x
	Input.action_press("cam_up")
	await seconds(0.3)
	Input.action_release("cam_up")
	check(absf(player.cam_pitch.rotation.x - p0) > 0.2, "arrow keys tilt the camera")

func test_recenter_waits_then_follows_motion() -> void:
	await _fixture()
	var y0: float = player.cam_yaw.rotation.y
	Input.action_press("move_left")
	await seconds(0.45)
	check(absf(wrapf(player.cam_yaw.rotation.y - y0, -PI, PI)) < 0.05, "no recenter before the delay")
	await seconds(1.9)
	var hv := Vector2(player.velocity.x, player.velocity.z)
	var fwd: Vector3 = -player.cam_yaw.global_basis.z
	var off: float = absf(Vector2(fwd.x, fwd.z).angle_to(hv))
	Input.action_release("move_left")
	check(off < 0.4, "camera swung behind the motion (off %.2f rad)" % off)

func test_no_recenter_while_backpedalling() -> void:
	await _fixture()
	var y0: float = player.cam_yaw.rotation.y
	Input.action_press("move_back")
	await seconds(2.5)
	Input.action_release("move_back")
	check(absf(wrapf(player.cam_yaw.rotation.y - y0, -PI, PI)) < 0.1, "camera holds while walking toward it")

func test_recenter_key() -> void:
	await _fixture()
	Input.action_press("cam_left")
	await seconds(0.6)
	Input.action_release("cam_left")
	var ev := InputEventAction.new()
	ev.action = "cam_recenter"
	ev.pressed = true
	Input.parse_input_event(ev)
	await seconds(0.8)
	var behind: float = player.model.rotation.y + PI
	check(absf(wrapf(player.cam_yaw.rotation.y - behind, -PI, PI)) < 0.1, "R snaps the camera behind the character")

func test_arm_eases_out_after_doorway() -> void:
	await _fixture()
	scene.add_child(SceneUtil.box_body(Vector3(20, 6, 0.5), Vector3(0, 3, 1.5), null, "Wall"))
	await seconds(0.6)
	var short_len: float = player.camera.position.z
	check(short_len < 1.8, "arm pulled in by the wall (%.2f)" % short_len)
	scene.get_node("Wall").free()
	await physics_frames(6)
	var mid: float = player.camera.position.z
	check(mid < 3.0, "arm eases out, not instant (%.2f after 0.1 s)" % mid)
	await seconds(2.5)
	check(player.camera.position.z > 3.6, "arm back to full length (%.2f)" % player.camera.position.z)

func test_zone_hints_change_arm() -> void:
	await load_main()
	var p := get_player()
	p.warp_to((scene.get_node("Markers/Zone_Corridor") as Node3D).global_transform)
	await seconds(2.5)
	check(p._arm_target < 3.5, "corridor zone shortens the arm (%.2f)" % p._arm_target)
	p.warp_to((scene.get_node("Markers/Zone_Atrium") as Node3D).global_transform)
	await seconds(0.5)
	check(p._arm_target > 4.5, "atrium zone widens the arm (%.2f)" % p._arm_target)

func test_help_overlay_toggles() -> void:
	await _fixture()
	var ev := InputEventAction.new()
	ev.action = "toggle_help"
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frames(3)
	check(player._help.visible, "F1 shows the controls overlay")

func test_keyboard_only_route_beach_to_atrium() -> void:
	await load_main()
	var p := get_player()
	await seconds(0.3)
	var route := ["Zone_BridgeSouth", "Zone_BridgeMid", "Zone_BridgeNorth", "Zone_Plateau", "Zone_GrottoEntrance", "Zone_GrottoDoor", "Zone_TunnelTop", "Zone_RampMid", "Zone_TunnelBottom", "Zone_GardenEntry", "Zone_Garden", "Zone_GardenExit", "Zone_CorridorSouthDoor", "Zone_Corridor", "Zone_CorridorEnd", "Zone_Atrium"]
	for z in route:
		var ok := await walk_to_keys(marker_pos(z), 30.0, 1.0)
		if not check(ok, "keys-only reached %s (stuck at %s)" % [z, p.global_position]):
			return
	check(absf(p.global_position.y - marker_pos("Zone_Atrium").y) < 0.4, "arrived on the atrium floor")

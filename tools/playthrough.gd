extends SceneTree
## Real play-through (non-headless, real renderer): starts at the TITLE screen,
## presses Enter, lets the summoning intro play, then drives the Wicker Man with
## keyboard actions only (WASD relative to the camera, E to interact; never
## warps, never touches the camera) along the whole adventure:
##   beach -> aqueduct -> plateau -> grotto -> teleporter -> control room ->
##   lever -> secret room -> ring -> atrium -> corridor -> garden -> tunnel -> grotto
## Logs camera "glitch" events and saves a screenshot at every waypoint to
## art/screens/play/. Usage: Godot -s tools/playthrough.gd [-- quick]

const OUT := "res://art/screens/play"
const LEG_TIMEOUT := 30.0

var player: CharacterBody3D
var main: Node
var log_lines: PackedStringArray = []
var glitches := {}
var shot_i := 0
var stuck_at := ""
var _prev_cam := Transform3D()
var _prev_yaw := 0.0
var _have_prev := false

func _initialize() -> void:
	_run()

func _say(s: String) -> void:
	print("PLAY ", s)
	log_lines.append(s)

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for f in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + "/" + f))
	GameSettings.ensure_loaded()
	GameSettings.skip_intro = false
	change_scene_to_file("res://scenes/title.tscn")
	await _frames(90)
	await _shot("title")
	_tap_key(KEY_ENTER)
	for i in 300:
		await process_frame
		if current_scene and current_scene.name == "Main":
			break
	main = current_scene
	player = main.get_node("Player")
	_say("level loaded; intro state=%s" % main.get_node("SummonIntro").state)
	await _seconds(2.5)
	await _shot("intro_mid")
	var t := 0.0
	while main.get_node("SummonIntro").state != "done" and t < 10.0:
		await _seconds(0.25)
		t += 0.25
	_say("intro finished after ~%.1f s more; input_locked=%s" % [t, player.input_locked])
	await _seconds(0.5)
	await _shot("spawn")

	var legs := [
		["Zone_BridgeSouth", "aqueduct south ramp"],
		["Zone_BridgeMid", "on the aqueduct deck"],
		["Zone_BridgeNorth", "aqueduct north ramp"],
		["Zone_Plateau", "plateau"],
		["Zone_GrottoEntrance", "grotto mouth"],
		["Zone_GrottoInside", "inside the grotto"],
		["@TeleporterGrotto", "onto the grotto teleporter"],
	]
	if not await _route(legs):
		await _finish()
		return
	# On the pad: the prompt shows; press E to teleport.
	await _seconds(0.5)
	_say("on grotto pad; prompt visible=%s" % main.find_child("TeleporterGrotto", true, false).get_node("Trigger").prompt.visible)
	await _shot("grotto_pad_prompt")
	_tap_action("interact")
	await _seconds(1.5)
	var in_control := player.global_position.x > 60.0 and player.global_position.y < 0.0
	_say("after pad: pos=%s in_control_room=%s" % [player.global_position, in_control])
	await _shot("arrived_control_room")
	if not in_control:
		stuck_at = "teleporter did not take us to the control room"
		await _finish()
		return
	if not await _route([["Zone_LeverFront", "lever"]]):
		await _finish()
		return
	# A player walks up to the lever and presses E as soon as the prompt shows.
	await _seconds(0.3)
	await _shot("lever_prompt")
	var lever := main.get_node("Level/Facility/ControlRoom/SecretLever")
	_say("lever prompt visible=%s in_range=%s lever=%s player=%s model_yaw=%.2f locked=%s grp=%s" % [lever.prompt.visible, lever.in_range, lever.global_position, player.global_position, player.model.rotation.y, player.input_locked, root.get_tree().get_first_node_in_group("player")])
	_tap_action("interact")
	await _seconds(1.5)
	await _shot("reveal_cutscene")
	await _seconds(4.0)
	_say("reveal state=%s door open=%s" % [main.get_node("Level/Facility/ControlRoom/RevealCutscene").state, main.get_node("Level/Facility/ControlRoom/RevealCutscene").door_open])
	var back := [
		["Zone_SecretDoor", "secret door"],
		["Zone_Secret", "relic chamber"],
		["Zone_SecretDoor", "back out"],
		["Zone_Control", "control room (walking past the pad must not teleport)"],
		["Zone_RingEast", "ring walkway east"],
		["Zone_RingSE", "ring SE"],
		["Zone_AtriumRing", "ring above the ramp"],
		["Zone_RampTop", "ramp top"],
		["Zone_RampBottom", "ramp bottom"],
		["Zone_Atrium", "atrium floor"],
		["Zone_CorridorEnd", "corridor east"],
		["Zone_Corridor", "corridor west"],
		["Zone_CorridorSouthDoor", "garden door"],
		["Zone_GardenExit", "garden"],
		["Zone_Garden", "garden pool"],
		["Zone_GardenEntry", "garden west"],
		["Zone_TunnelBottom", "tunnel bottom"],
		["Zone_RampMid", "tunnel ramp"],
		["Zone_TunnelTop", "tunnel top"],
		["Zone_GrottoDoor", "back in the grotto"],
	]
	await _route(back)
	await _finish()

# ------------------------------------------------------------------ driving
func _route(legs: Array) -> bool:
	for leg in legs:
		var target: Vector3
		if String(leg[0]).begins_with("@"):
			target = (main.find_child(String(leg[0]).substr(1), true, false) as Node3D).global_position
		else:
			target = (main.get_node("Markers/" + String(leg[0])) as Node3D).global_position
		var ok := await _walk(target, 0.9)
		_say("%s %s (%s) pos=%s" % ["reached" if ok else "STUCK going to", leg[0], leg[1], player.global_position])
		await _shot(String(leg[0]).replace("@", "").replace("Zone_", "").to_snake_case())
		if not ok:
			stuck_at = "%s (%s)" % [leg[0], leg[1]]
			return false
	return true

func _walk(target: Vector3, reach: float) -> bool:
	var start := player.global_position
	var frames := int(LEG_TIMEOUT * 60)
	var last_progress := player.global_position
	var since_progress := 0
	var prev := player.global_position
	for i in frames:
		if player.global_position.distance_to(prev) > 4.0:
			_release_all()   # teleported mid-leg
			return true
		prev = player.global_position
		var d := target - player.global_position
		d.y = 0.0
		if d.length() < reach:
			_release_all()
			return true
		if player.global_position.distance_to(last_progress) > 0.6:
			last_progress = player.global_position
			since_progress = 0
		else:
			since_progress += 1
		var fwd: Vector3 = -player.cam_yaw.global_basis.z
		var a: float = Vector2(fwd.x, fwd.z).angle_to(Vector2(d.x, d.z))
		_release_all()
		if absf(a) < 1.2:
			Input.action_press("move_forward")
		elif absf(a) > 2.2:
			Input.action_press("move_back")
			a = 0.0
		if a > 0.3:
			Input.action_press("move_right")
		elif a < -0.3:
			Input.action_press("move_left")
		# Unstick: hop if no progress for 1.5 s.
		if since_progress == 90 or since_progress == 180:
			Input.action_press("jump")
		await physics_frame
		_watch_camera()
		Input.action_release("jump")
	_release_all()
	return false


func _face(p: Vector3) -> void:
	for i in 40:
		var d := p - player.global_position
		var fwd: Vector3 = -player.cam_yaw.global_basis.z
		var a: float = Vector2(fwd.x, fwd.z).angle_to(Vector2(d.x, d.z))
		_release_all()
		Input.action_press("move_forward")
		if a > 0.2:
			Input.action_press("move_right")
		elif a < -0.2:
			Input.action_press("move_left")
		await physics_frame
	_release_all()
	await _seconds(0.3)

func _release_all() -> void:
	for act in ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump"]:
		Input.action_release(act)

func _tap_action(act: String) -> void:
	Input.action_press(act)
	await physics_frame
	await physics_frame
	Input.action_release(act)

func _tap_key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)

# ------------------------------------------------------------------ camera watch
func _watch_camera() -> void:
	var cam := root.get_viewport().get_camera_3d()
	if cam == null or player == null:
		return
	if cam != player.camera:
		_have_prev = false   # cutscene / intro camera
		return
	var xf := cam.global_transform
	var yaw: float = player.cam_yaw.rotation.y
	var where := _zone_name()
	if _have_prev:
		var jump := xf.origin.distance_to(_prev_cam.origin)
		var dyaw := absf(wrapf(yaw - _prev_yaw, -PI, PI))
		var moved := player.velocity.length() * (1.0 / 60.0)
		if jump > maxf(0.5, moved * 4.0):
			_glitch(where, "camera position jump %.2f m in one frame" % jump)
		if dyaw > 0.07:
			_glitch(where, "camera yaw snap %.0f deg in one frame" % rad_to_deg(dyaw))
	var head := player.global_position + Vector3(0, 1.7, 0)
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(head, xf.origin, 1 | 4, [player.get_rid()])
	var bh := space.intersect_ray(q)
	if not bh.is_empty():
		_glitch(where, "view to the character blocked by geometry (%s)" % (bh.collider as Node).name)
	if xf.origin.distance_to(head) < 0.6:
		_glitch(where, "camera inside/too close to the character")
	_prev_cam = xf
	_prev_yaw = yaw
	_have_prev = true

func _zone_name() -> String:
	var p := player.global_position
	if p.y < -1.0 and p.x > 10.0 and p.z < -80.0:
		if p.x > 60.0:
			return "control/secret"
		if p.x > 39.0:
			return "atrium"
		if p.z < -92.5:
			return "garden"
		if p.x > 17.0:
			return "corridor"
		return "tunnel"
	if p.z < -59.0:
		return "grotto" if absf(p.x) < 11.0 else "tunnel"
	if p.z < -38.0:
		return "plateau"
	if p.z < 1.0:
		return "aqueduct"
	return "beach"

func _glitch(where: String, what: String) -> void:
	var key := where + ": " + what.get_slice(" ", 0) + " " + what.get_slice(" ", 1) + " " + what.get_slice(" ", 2) + (" " + what.get_slice("(", 1) if what.contains("(") else "")
	if not glitches.has(key):
		glitches[key] = {"count": 0, "example": what, "pos": player.global_position}
	glitches[key].count += 1

# ------------------------------------------------------------------ util
func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _seconds(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		await physics_frame
		_watch_camera()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [OUT, shot_i, name])
	shot_i += 1

func _finish() -> void:
	_say("---- camera glitch summary (frames) ----")
	var keys := glitches.keys()
	keys.sort_custom(func(a, b): return glitches[a].count > glitches[b].count)
	for k in keys:
		_say("%5d  %s   e.g. %s at %s" % [glitches[k].count, k, glitches[k].example, glitches[k].pos.snapped(Vector3.ONE * 0.1)])
	_say("RESULT %s" % ("STUCK at " + stuck_at if stuck_at != "" else "completed the full route"))
	var f := FileAccess.open(OUT + "/log.txt", FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	quit()

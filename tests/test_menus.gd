extends TestCase
## Start page, pause menu, settings persistence.

func _load_title() -> Node:
	var t: Node = load("res://scenes/title.tscn").instantiate()
	tree.root.add_child(t)
	tree.current_scene = t
	scene = t
	await physics_frames(4)
	return t

func _accept() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frames(2)
	var up := InputEventAction.new()
	up.action = "ui_accept"
	up.pressed = false
	Input.parse_input_event(up)

func test_title_loads_with_start_focused() -> void:
	var t := await _load_title()
	check(t.get_node_or_null("World/Player") != null, "live level behind the title")
	check(t.cam.current, "fly-through camera current")
	var focused := t.get_viewport().gui_get_focus_owner()
	check(focused != null and focused.name == "Start", "Start has keyboard focus (%s)" % [focused.name if focused else "none"])
	var logo := t.find_child("Logo", true, false) as Label
	check(logo != null and logo.text == "LOST ORIGIN", "logo")

func test_enter_starts_the_level() -> void:
	GameSettings.skip_intro = true
	await _load_title()
	await _accept()
	for i in 90:
		await tree.process_frame
		if tree.current_scene and tree.current_scene.name == "Main":
			break
	scene = tree.current_scene
	check(scene != null and scene.name == "Main", "level loaded after Enter (current=%s)" % [scene.name if scene else "null"])
	await physics_frames(10)
	var p := scene.get_node_or_null("Player") as CharacterBody3D
	check(p != null and p.is_inside_tree(), "player spawned")
	GameSettings.skip_intro = false

func test_esc_pauses_and_resumes() -> void:
	await load_main()
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	await tree.process_frame
	await tree.process_frame
	check(tree.paused, "Esc pauses")
	check(scene.get_node("PauseMenu").panel.visible, "pause menu shown")
	var ev2 := InputEventAction.new()
	ev2.action = "pause"
	ev2.pressed = true
	Input.parse_input_event(ev2)
	await tree.process_frame
	await tree.process_frame
	check(not tree.paused, "Esc again resumes")
	tree.paused = false

func test_quit_to_title() -> void:
	await load_main()
	tree.current_scene = scene
	scene.get_node("PauseMenu").pause()
	scene.get_node("PauseMenu").quit_to_title()
	for i in 60:
		await tree.process_frame
		if tree.current_scene and tree.current_scene.name == "Title":
			break
	scene = tree.current_scene
	check(not tree.paused, "unpaused")
	check(scene != null and scene.name == "Title", "back on the title screen")

func test_settings_round_trip() -> void:
	GameSettings.ensure_loaded()
	var old := [CameraSettings.auto_recenter, CameraSettings.invert_y, CameraSettings.sensitivity, GameSettings.quality, GameSettings.skip_intro]
	CameraSettings.auto_recenter = false
	CameraSettings.invert_y = true
	CameraSettings.sensitivity = 1.7
	GameSettings.quality = "low"
	GameSettings.skip_intro = true
	GameSettings.save()
	CameraSettings.auto_recenter = true
	CameraSettings.invert_y = false
	CameraSettings.sensitivity = 1.0
	GameSettings.quality = "high"
	GameSettings.skip_intro = false
	CameraSettings._loaded = false
	GameSettings._loaded = false
	GameSettings.ensure_loaded()
	check(not CameraSettings.auto_recenter and CameraSettings.invert_y and is_equal_approx(CameraSettings.sensitivity, 1.7), "camera settings persisted")
	check(GameSettings.quality == "low" and GameSettings.skip_intro, "game settings persisted")
	CameraSettings.auto_recenter = old[0]
	CameraSettings.invert_y = old[1]
	CameraSettings.sensitivity = old[2]
	GameSettings.quality = old[3]
	GameSettings.skip_intro = old[4]
	GameSettings.save()

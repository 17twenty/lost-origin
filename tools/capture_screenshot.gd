extends SceneTree
## Renders one PNG per Marker3D under Main/Shots to res://art/screens/.
## Must run WITHOUT --headless (needs a real renderer).
## Usage: Godot -s tools/capture_screenshot.gd [-- Shot_Name]

const OUT_DIR := "res://art/screens"

func _initialize() -> void:
	_run()

func _run() -> void:
	var only := ""
	if OS.get_cmdline_user_args().size() > 0:
		only = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	# Freeze gameplay so the player doesn't steal the camera.
	var player := scene.get_node_or_null("Player")
	var cam := Camera3D.new()
	cam.fov = 70
	cam.far = 1500
	scene.add_child(cam)
	cam.make_current()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var count := 0
	for m in scene.get_node("Shots").get_children():
		if only != "" and m.name != only:
			continue
		cam.global_transform = m.global_transform
		if player and m.has_meta("player_pos"):
			player.global_position = m.get_meta("player_pos")
		for i in 30:
			await process_frame
		var img := root.get_texture().get_image()
		var path := "%s/%s.png" % [OUT_DIR, String(m.name).trim_prefix("Shot_").to_snake_case()]
		img.save_png(path)
		print("captured ", path)
		count += 1
	print("capture_screenshot: %d shots" % count)
	quit(0 if count > 0 else 1)

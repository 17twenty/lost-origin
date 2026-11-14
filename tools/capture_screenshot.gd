extends SceneTree
## Renders one PNG per Marker3D under Main/Shots to res://art/screens/.
## Must run WITHOUT --headless (needs a real renderer).
## Usage: Godot -s tools/capture_screenshot.gd [-- <name prefix, e.g. Shot_Ref_>]
## Marker metadata: player_pos (Vector3), hide_player (bool), square (bool), fov (float).
## Shot_Ref_<Name> markers are saved as ref_<name>.png.

const OUT_DIR := "res://art/screens"

func _initialize() -> void:
	_run()

func _run() -> void:
	var only := ""
	if OS.get_cmdline_user_args().size() > 0:
		only = OS.get_cmdline_user_args()[0]
	Engine.set_meta("skip_intro", true)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var player: Node3D = scene.get_node_or_null("Player")
	var cam := Camera3D.new()
	cam.far = 1500
	scene.add_child(cam)
	cam.make_current()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var count := 0
	for m: Node3D in scene.get_node("Shots").get_children():
		if only != "" and not String(m.name).begins_with(only):
			continue
		var square: bool = m.get_meta("square", false)
		var size := Vector2i(900, 900) if square else Vector2i(1280, 720)
		DisplayServer.window_set_size(size)
		root.size = size
		cam.fov = m.get_meta("fov", 70.0)
		cam.global_transform = m.global_transform
		if player:
			player.visible = not m.get_meta("hide_player", false)
			if m.has_meta("player_pos"):
				player.global_position = m.get_meta("player_pos")
			player.set_weave(m.get_meta("weave", 1.0))
		for i in 40:
			await process_frame
		await RenderingServer.frame_post_draw  # grab a frame drawn with this camera
		var img := root.get_texture().get_image()
		var file := String(m.name).trim_prefix("Shot_").to_snake_case()
		if m.has_meta("ref"):
			file = "ref_" + String(m.get_meta("ref"))
		var path := "%s/%s.png" % [OUT_DIR, file]
		img.save_png(path)
		print("captured ", path, " ", img.get_size())
		count += 1
	print("capture_screenshot: %d shots" % count)
	quit(0 if count > 0 else 1)

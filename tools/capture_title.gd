extends SceneTree
## Renders the start page (and its Settings panel) to art/screens/title*.png (non-headless).
func _initialize() -> void:
	_run()

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	var t: Node = load("res://scenes/title.tscn").instantiate()
	root.add_child(t)
	current_scene = t
	for i in 60:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/screens/title.png")
	t._show_settings()
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/screens/title_settings.png")
	print("captured title")
	quit()

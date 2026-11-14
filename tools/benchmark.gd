extends SceneTree
## Frame-rate benchmark (non-headless, vsync off, 1280x720): holds each
## Shot_Ref_* camera for a warm-up then a sample window and reports FPS.
## Usage: Godot -s tools/benchmark.gd   -> prints "BENCH avg_fps=<n> min_fps=<n>"

const WARMUP := 0.75
const SAMPLE := 2.0

func _initialize() -> void:
	_run()

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var cam := Camera3D.new()
	cam.far = 1500
	scene.add_child(cam)
	cam.make_current()
	var player: Node3D = scene.get_node_or_null("Player")
	var results := []
	for m: Node3D in scene.get_node("Shots").get_children():
		if not String(m.name).begins_with("Shot_Ref_"):
			continue
		cam.global_transform = m.global_transform
		cam.fov = m.get_meta("fov", 70.0)
		if player:
			player.visible = false
		var t0 := Time.get_ticks_usec()
		while Time.get_ticks_usec() - t0 < WARMUP * 1e6:
			await process_frame
		var frames := 0
		t0 = Time.get_ticks_usec()
		while Time.get_ticks_usec() - t0 < SAMPLE * 1e6:
			await process_frame
			frames += 1
		var fps := frames / ((Time.get_ticks_usec() - t0) / 1e6)
		results.append(fps)
		print("BENCH shot=%s fps=%.1f" % [m.name, fps])
	var total := 0.0
	var lo := INF
	for f in results:
		total += f
		lo = min(lo, f)
	var avg: float = total / maxi(results.size(), 1)
	print("BENCH avg_fps=%.1f min_fps=%.1f shots=%d" % [avg, lo, results.size()])
	quit(0 if results.size() > 0 else 1)

extends SceneTree
## Wicker Man turnaround under neutral studio light, next to the design sheet.
##   Godot --path . -s tools/turnaround.gd            (not headless: it renders)
## Writes art/compare/wicker_turnaround.png (reference | front, side, back, 3/4)
## and art/compare/wicker_head.png (head close-ups).

const MODEL := "res://assets/characters/wicker.glb"
const REF := "res://wicker-inspo/turn-around-final.png"
const W := 420
const H := 640

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.93, 0.93, 0.92)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.environment.ambient_light_energy = 0.3
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	for spec in [[Vector3(-35, -30, 0), 1.0, true], [Vector3(-20, 150, 0), 0.45, false], [Vector3(-60, 60, 0), 0.25, false]]:
		var l := DirectionalLight3D.new()
		l.rotation_degrees = spec[0]
		l.light_energy = spec[1]
		l.shadow_enabled = spec[2]
		world.add_child(l)
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	world.add_child(model)
	WickerSkin.apply(model)
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation("idle"):
		ap.play("idle")
		ap.seek(0.0, true)
		ap.pause()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(cam)
	cam.current = true
	var shots: Array[Image] = []
	var heads: Array[Image] = []
	for yaw in [0.0, 90.0, 180.0, 35.0]:
		for close in [false, true]:
			# Model faces +Z in Godot (Blender -Y front); orbit the camera around it.
			var a := deg_to_rad(yaw)
			var target := Vector3(0, 1.97, 0) if close else Vector3(0, 1.15, 0)
			cam.size = 0.8 if close else 2.45
			cam.position = target + Vector3(sin(a), 0, cos(a)) * 6.0
			cam.look_at(target)
			for i in 6:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			(heads if close else shots).append(img)
	var ref := Image.load_from_file(ProjectSettings.globalize_path(REF))
	ref.convert(Image.FORMAT_RGB8)
	ref.resize(int(ref.get_width() * float(H) / ref.get_height()), H, Image.INTERPOLATE_LANCZOS)
	_save([ref] + shots, "res://art/compare/wicker_turnaround.png")
	_save(heads, "res://art/compare/wicker_head.png")
	print("TURNAROUND_OK")
	quit()

func _save(imgs: Array, path: String) -> void:
	var w := 0
	for im: Image in imgs:
		w += im.get_width()
	var out := Image.create(w, H, false, Image.FORMAT_RGB8)
	var x := 0
	for im: Image in imgs:
		out.blit_rect(im, Rect2i(0, 0, im.get_width(), H), Vector2i(x, 0))
		x += im.get_width()
	out.save_png(ProjectSettings.globalize_path(path))

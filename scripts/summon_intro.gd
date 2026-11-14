extends Node
## Summoning intro ("weave-in"): the beach totems call, the Wicker Man weaves
## himself into being inside the summoning ring (feet -> crown), fibres spiral
## in, the camera orbits and pushes in, a lore card fades up, then control is
## handed over. Any key / click skips. Skipped when Engine meta "skip_intro".

signal finished

@export var duration := 5.5
const LORE := "The old stones called, and something answered.\nWoven from the island itself, its last guardian wakes —\nto find the deep places humming with a light that is not its own."
const TOTEM_GLOW := "res://scenes/generated/totem_glow.tres"

var state := "idle"     # idle -> playing -> handing -> done
var progress := 0.0
var player: CharacterBody3D
var cam: Camera3D
var _time := 0.0
var _tweens: Array[Tween] = []
var _lore: CanvasLayer
var _label: Label
var _fibres: GPUParticles3D
var _glyph: ShaderMaterial
var _totem_glow: StandardMaterial3D
var _totem_base := 5.0


func _ready() -> void:
	if Engine.has_meta("skip_intro") and Engine.get_meta("skip_intro"):
		state = "done"
		return
	start.call_deferred()


func start() -> void:
	player = get_parent().get_node("Player")
	state = "playing"
	_time = 0.0
	player.input_locked = true
	_set_progress(0.0)
	cam = Camera3D.new()
	cam.name = "IntroCamera"
	cam.fov = 60
	cam.far = 1500
	get_parent().add_child(cam)
	cam.make_current()
	_orbit(0.0)
	player.play_oneshot("summon")
	_build_fibres()
	_build_lore()
	var ring := get_parent().get_node_or_null("Level/Outdoor/SummoningRing/Glyphs") as MeshInstance3D
	if ring:
		_glyph = (ring.mesh as PlaneMesh).material as ShaderMaterial
	if ResourceLoader.exists(TOTEM_GLOW):
		_totem_glow = load(TOTEM_GLOW)
		_totem_base = _totem_glow.emission_energy_multiplier
	var tw := create_tween()
	tw.tween_method(_set_progress, 0.0, 1.0, duration * 0.82).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens.append(tw)
	var fx := create_tween().set_parallel(true)
	if _totem_glow:
		fx.tween_property(_totem_glow, "emission_energy_multiplier", _totem_base * 4.0, 1.2)
		fx.chain().tween_property(_totem_glow, "emission_energy_multiplier", _totem_base, duration - 1.2)
	if _glyph:
		_glyph.set_shader_parameter("power", 2.5)
	_tweens.append(fx)
	var lt := create_tween()
	lt.tween_interval(1.2)
	lt.tween_property(_label, "modulate:a", 1.0, 1.0)
	_tweens.append(lt)


func _process(delta: float) -> void:
	if state != "playing":
		return
	_time += delta
	if _time < duration:
		_orbit(_time / duration)
	else:
		_handover()


func _unhandled_input(event: InputEvent) -> void:
	if state != "playing" and state != "handing":
		return
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed()
	if pressed:
		get_viewport().set_input_as_handled()
		skip()


func skip() -> void:
	for t in _tweens:
		if t and t.is_valid():
			t.kill()
	_tweens.clear()
	_finish()


func _set_progress(p: float) -> void:
	progress = p
	if player:
		player.set_weave(p)


func _orbit(u: float) -> void:
	var c := player.global_position
	var a := lerpf(-1.1, 0.35, u)
	var r := lerpf(7.5, 4.0, u)
	var h := lerpf(3.8, 2.0, u)
	cam.global_position = c + Vector3(sin(a) * r, h, cos(a) * r)
	cam.look_at(c + Vector3(0, lerpf(0.6, 1.4, u), 0), Vector3.UP)


func _handover() -> void:
	state = "handing"
	var tw := create_tween()
	tw.tween_property(cam, "global_transform", player.camera.global_transform, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_finish)
	_tweens.append(tw)


func _finish() -> void:
	if state == "done":
		return
	state = "done"
	_set_progress(1.0)
	player.camera.make_current()
	player.input_locked = false
	if cam:
		cam.queue_free()
	if _fibres:
		_fibres.emitting = false
	if _totem_glow:
		_totem_glow.emission_energy_multiplier = _totem_base
	if _glyph:
		_glyph.set_shader_parameter("power", 0.6)
	if _label:
		var lt := create_tween()
		lt.tween_interval(2.0)
		lt.tween_property(_label, "modulate:a", 0.0, 1.5)
	finished.emit()


func _build_fibres() -> void:
	_fibres = GPUParticles3D.new()
	_fibres.name = "WeaveFibres"
	_fibres.amount = 260
	_fibres.lifetime = 1.6
	_fibres.preprocess = 0.5
	_fibres.visibility_aabb = AABB(Vector3(-5, -1, -5), Vector3(10, 6, 10))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 3.2
	pm.emission_ring_inner_radius = 2.4
	pm.emission_ring_height = 0.4
	pm.direction = Vector3.UP
	pm.spread = 20.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 2.2
	pm.radial_accel_min = -4.5     # pulled in toward the body
	pm.radial_accel_max = -3.0
	pm.tangential_accel_min = 2.0  # swirl
	pm.tangential_accel_max = 3.5
	pm.gravity = Vector3(0, 0.6, 0)
	pm.damping_min = 0.5
	pm.damping_max = 1.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1.0))
	sc.add_point(Vector2(1, 0.1))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	_fibres.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.28)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(1.0, 0.8, 0.45)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.2)
	m.emission_energy_multiplier = 2.0
	q.material = m
	_fibres.draw_pass_1 = q
	player.add_child(_fibres)
	_fibres.position = Vector3(0, 0.3, 0)
	_fibres.emitting = true


func _build_lore() -> void:
	_lore = CanvasLayer.new()
	_lore.name = "LoreCard"
	_lore.layer = 10
	add_child(_lore)
	_label = Label.new()
	_label.text = LORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.anchor_top = 0.62
	_label.anchor_bottom = 0.9
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.modulate.a = 0.0
	_lore.add_child(_label)

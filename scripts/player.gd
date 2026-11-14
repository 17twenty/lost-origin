extends CharacterBody3D
## Wicker Man third-person controller: Halo-weighted movement (momentum, sprint,
## buffered jump with coyote time) and an over-the-shoulder SpringArm camera.

@export var run_speed := 5.5
@export var sprint_speed := 8.5
@export var ground_accel := 22.0
@export var ground_decel := 28.0
@export var air_accel := 6.0
@export var jump_velocity := 7.8
@export var gravity := 22.0
@export var mouse_sensitivity := 0.0025
@export var turn_speed := 12.0
@export var pitch_min := -1.2
@export var pitch_max := 0.7
@export var wade_factor := 0.7    # speed multiplier while wading
@export var swim_speed := 3.0
@export var swim_kick := 4.5

const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12
const LOOPING := ["idle", "walk", "run", "sprint", "fall", "swim", "look_around"]
const WALK_MAX := 3.2          # below this ground speed the walk cycle plays
const LOOK_AROUND_AFTER := 8.0 # seconds of idling before the curious look-around
const LAND_TIME := 0.28

@onready var model: Node3D = $Model
@onready var cam_yaw: Node3D = $CameraYaw
@onready var cam_pitch: Node3D = $CameraYaw/CameraPitch
@onready var spring_arm: SpringArm3D = $CameraYaw/CameraPitch/SpringArm3D
@onready var camera: Camera3D = $CameraYaw/CameraPitch/Camera3D
@onready var anim_tree: AnimationTree = $AnimationTree

var anim_state := "idle"
## One-shot clip (interact, summon) that owns the AnimationTree until it ends.
var oneshot := ""
var _oneshot_left := 0.0
var _idle_time := 0.0
var _air_time := 0.0
var _land_left := 0.0
## Set while in deep water (Phase 14 drives this).
var swimming := false
## "none" / "wade" / "swim", from the deepest WaterVolume around the feet.
var water_state := "none"
var water_surface := 0.0
const SWIM_DEPTH := 1.45       # feet this far under the surface -> swim (chest-deep on a 2.1 m body)
const UNSWIM_DEPTH := 1.25     # hysteresis back to wading
const SWIM_FLOAT := 1.55       # feet held this far below the surface (head stays above)
var _splash: GPUParticles3D

# --- Assisted camera -------------------------------------------------------
const PIVOT_H := 1.85
const DEFAULT_ARM := 4.0
const DEFAULT_PITCH := -0.18
const KEY_YAW_RATE := 2.2        # rad/s with the arrow keys
const KEY_PITCH_RATE := 1.4
const RECENTER_DELAY_KEYS := 0.6 # s after keyboard camera input (or none)
const RECENTER_DELAY_MOUSE := 2.5
const RECENTER_RATE := 2.4       # exponential rate when auto-recentering
const LOOK_AHEAD := 2.5
var camera_focus := Vector3.ZERO
var _grounded_y := 0.0
var _look_ahead := Vector3.ZERO
var _arm_len := DEFAULT_ARM
var _arm_target := DEFAULT_ARM
var _pitch_target := DEFAULT_PITCH
var _since_manual := 0.0
var _manual_was_mouse := false
var _recenter_now := false
var _cam_yaw_written := 0.0
## Movement basis: follows the camera except while the auto-camera swings, so a
## held direction keeps going the same way in the world while the view catches up.
var _move_yaw := 0.0
var _last_input := Vector2.ZERO
var _since_dir := 0.0   # time the current movement direction has been held
var _help: CanvasLayer
var _shoulder := 0.6           # current over-the-shoulder offset (shrinks next to walls)
var _cramped := 0.0            # 0..1: how squeezed the camera is (drives lift + fade)
var _cramped_time := 0.0
var _model_fade := 0.0
## Locked during cutscenes (summoning intro, secret reveal): movement/look input ignored.
var input_locked := false
## Weave-in materials (per-instance copies so weave_progress is ours alone).
var weave_mats: Array[ShaderMaterial] = []
var weave := 1.0
var _weave_tween: Tween
var motion: WickerMotion
## Body language: lean into acceleration/turns, squash on landing.
var _lean := Vector2.ZERO
var _squash := 0.0
var _prev_hvel := Vector3.ZERO
var _prev_yaw := 0.0
var sprinting := false
var _coyote := 0.0
var _jump_buffer := 0.0
var _jump_was_held := false
## Set by tests/cutscenes to steer the camera without a mouse.
var look_input := Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	WickerSkin.apply(model)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i)
			if m is ShaderMaterial:
				var d: ShaderMaterial = m.duplicate()
				mi.set_surface_override_material(i, d)
				weave_mats.append(d)
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.size() > 0:
		motion = WickerMotion.new()
		motion.name = "WickerMotion"
		motion.body = self
		sks[0].add_child(motion)
	spring_arm.add_excluded_object(get_rid())
	var ap: AnimationPlayer = anim_tree.get_node(anim_tree.anim_player)
	for n in LOOPING:
		if ap.has_animation(n):
			ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	anim_tree.active = true
	camera.make_current()
	CameraSettings.ensure_loaded()
	snap_camera()
	_build_help()


func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_input += event.relative * mouse_sensitivity * CameraSettings.sensitivity * Vector2(1.0, -1.0 if CameraSettings.invert_y else 1.0)
		_manual(true)
	elif event.is_action_pressed("cam_recenter"):
		_recenter_now = true
	elif event.is_action_pressed("toggle_help") and _help:
		_help.visible = not _help.visible


func _physics_process(delta: float) -> void:
	_apply_look()
	var input := Vector2.ZERO if input_locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_update_move_basis(input)
	var dir := (Basis(Vector3.UP, _move_yaw) * Vector3(input.x, 0.0, input.y))
	dir.y = 0.0
	dir = dir.normalized() * min(input.length(), 1.0)
	sprinting = not input_locked and Input.is_action_pressed("sprint") and input.y < -0.3 and is_on_floor()

	_update_water()
	var on_floor := is_on_floor()
	var speed := sprint_speed if sprinting else run_speed
	if water_state == "wade":
		speed *= wade_factor
	elif water_state == "swim":
		speed = swim_speed
		sprinting = false
	var target := dir * speed
	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	var rate: float
	if on_floor:
		rate = ground_accel if dir.length() > 0.01 else ground_decel
	else:
		rate = air_accel
	hvel = hvel.move_toward(target, rate * delta)

	# Jump: buffered press + coyote time so edges feel fair.
	var held := Input.is_action_pressed("jump") and not input_locked
	if held and not _jump_was_held:
		_jump_buffer = JUMP_BUFFER
	_jump_was_held = held
	_coyote = COYOTE_TIME if on_floor else max(_coyote - delta, 0.0)
	_jump_buffer = max(_jump_buffer - delta, 0.0)

	var vy := velocity.y
	if water_state == "swim":
		# Buoyancy: hold the feet SWIM_FLOAT below the surface; Space kicks up (to climb banks).
		hvel = Vector3(velocity.x, 0.0, velocity.z).move_toward(target, 8.0 * delta)
		var target_y := water_surface - SWIM_FLOAT
		vy = lerpf(vy, clampf((target_y - global_position.y) * 3.5, -3.0, 3.0), clampf(6.0 * delta, 0.0, 1.0))
		if _jump_buffer > 0.0:
			vy = swim_kick
			_jump_buffer = 0.0
		velocity = Vector3(hvel.x, vy, hvel.z)
		move_and_slide()
		_after_move(dir, delta)
		return
	if on_floor and vy < 0.0:
		vy = 0.0
	vy -= gravity * delta
	if _jump_buffer > 0.0 and _coyote > 0.0:
		vy = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
	# Short hop when jump is released early.
	if not held and vy > 0.0 and not on_floor:
		vy -= gravity * 0.8 * delta

	velocity = Vector3(hvel.x, vy, hvel.z)
	move_and_slide()
	_after_move(dir, delta)


func _after_move(dir: Vector3, delta: float) -> void:
	if dir.length() > 0.05:
		var target_yaw := atan2(dir.x, dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, clamp(turn_speed * delta, 0.0, 1.0))
	var was_air := _air_time > 0.35
	_update_anim()
	if was_air and is_on_floor():
		_squash = 0.12
	_body_language(delta)
	_update_camera(delta)


# ---------------------------------------------------------------- camera
func _manual(mouse: bool) -> void:
	_since_manual = 0.0
	_manual_was_mouse = mouse
	_move_yaw = cam_yaw.rotation.y


func _update_move_basis(input: Vector2) -> void:
	# Someone else (mouse, tests, cutscenes) moved the camera: treat as manual.
	if absf(wrapf(cam_yaw.rotation.y - _cam_yaw_written, -PI, PI)) > 0.0005:
		_manual(false)
		_since_manual = RECENTER_DELAY_KEYS * 0.5
	# New direction held (or released): re-base movement on the current view.
	if input.length() < 0.1 or input.distance_to(_last_input) > 0.3:
		_move_yaw = cam_yaw.rotation.y
		_since_dir = 0.0
	_last_input = input


## Jump the camera rig to its resting place (spawn, teleport, respawn).
func snap_camera() -> void:
	_grounded_y = global_position.y
	_look_ahead = Vector3.ZERO
	camera_focus = global_position + Vector3(0, PIVOT_H, 0)
	cam_yaw.global_position = camera_focus
	_arm_len = _arm_target
	_cam_yaw_written = cam_yaw.rotation.y
	_move_yaw = cam_yaw.rotation.y


func _update_camera(delta: float) -> void:
	var k_pos := 1.0 - exp(-10.0 * delta)
	var k_y := 1.0 - exp(-6.0 * delta)
	_since_manual += delta
	_since_dir += delta
	# --- keyboard orbit / pitch
	if not input_locked:
		var ky := Input.get_axis("cam_right", "cam_left")
		var kp := Input.get_axis("cam_down", "cam_up") * (-1.0 if CameraSettings.invert_y else 1.0)
		if absf(ky) > 0.01 or absf(kp) > 0.01:
			cam_yaw.rotation.y += ky * KEY_YAW_RATE * CameraSettings.sensitivity * delta
			cam_pitch.rotation.x = clampf(cam_pitch.rotation.x + kp * KEY_PITCH_RATE * CameraSettings.sensitivity * delta, pitch_min, pitch_max)
			_manual(false)
	# --- zone hints
	_arm_target = DEFAULT_ARM
	_pitch_target = DEFAULT_PITCH
	var hint_dir := Vector3.ZERO
	for z in get_tree().get_nodes_in_group("camera_zone"):
		if z.contains(global_position + Vector3(0, 1.0, 0)):
			_arm_target = z.arm_length
			_pitch_target = z.pitch
			if z.has_hint:
				hint_dir = z.hint - global_position
	# --- focus: grounded height (ignore normal jumps) + look-ahead
	var on_floor := is_on_floor()
	if on_floor or swimming:
		_grounded_y = lerpf(_grounded_y, global_position.y, k_y)
	elif global_position.y < _grounded_y - 2.0:
		_grounded_y = global_position.y + 2.0   # real falls: follow, 2 m behind
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var la_target := Vector3.ZERO
	if hv.length() > 0.5:
		# Less look-ahead in tight rooms (short zone arm), none when the view is blocked.
		var la_scale := clampf(_arm_target / DEFAULT_ARM, 0.35, 1.0)
		la_target = hv.normalized() * LOOK_AHEAD * la_scale * clampf(hv.length() / sprint_speed, 0.0, 1.0)
	_look_ahead = _look_ahead.lerp(la_target, 1.0 - exp(-3.0 * delta))
	camera_focus = Vector3(global_position.x, _grounded_y + PIVOT_H, global_position.z) + _look_ahead
	var cur := cam_yaw.global_position
	var pivot := Vector3(lerpf(cur.x, camera_focus.x, k_pos), lerpf(cur.y, camera_focus.y, k_y), lerpf(cur.z, camera_focus.z, k_pos))
	# Never let the pivot sit inside walls: the spring arm can only protect the
	# camera if it starts in open space (look-ahead + lag used to push it through).
	var space := get_world_3d().direct_space_state
	var head := Vector3(global_position.x, pivot.y, global_position.z)   # player's column at pivot height
	pivot = _clear_point(space, head, pivot, 0.35)
	cam_yaw.global_position = pivot
	# --- auto-recenter behind the motion (never while backpedalling toward the camera)
	var behind := model.rotation.y + PI
	if hv.length() > 1.0:
		behind = atan2(-hv.x, -hv.z)
	# Zone hint: lean the view toward a point of interest, but only when we're
	# heading roughly toward it (never drag the camera off the way we're going).
	if hint_dir.length() > 0.5 and (hv.length() < 1.0 or Vector2(hv.x, hv.z).normalized().dot(Vector2(hint_dir.x, hint_dir.z).normalized()) > 0.3):
		behind = lerp_angle(behind, atan2(-hint_dir.x, -hint_dir.z), 0.3)
	var cam_fwd := -cam_yaw.global_basis.z
	var backpedal := hv.length() > 0.5 and Vector2(cam_fwd.x, cam_fwd.z).normalized().dot(Vector2(hv.x, hv.z).normalized()) < -0.5
	var delay := RECENTER_DELAY_MOUSE if _manual_was_mouse else RECENTER_DELAY_KEYS
	var k_rc := 1.0 - exp(-RECENTER_RATE * delta)
	if _recenter_now:
		k_rc = 1.0 - exp(-12.0 * delta)
		if absf(wrapf(cam_yaw.rotation.y - behind, -PI, PI)) < 0.02:
			_recenter_now = false
	var settled := _since_manual > delay and _since_dir > 0.5   # wait out manual input AND fresh direction changes
	if not input_locked and (_recenter_now or (CameraSettings.auto_recenter and settled and hv.length() > 1.0 and not backpedal)):
		cam_yaw.rotation.y = lerp_angle(cam_yaw.rotation.y, behind, k_rc)
		cam_pitch.rotation.x = lerpf(cam_pitch.rotation.x, _pitch_target, k_rc)
	# --- corner escape: if the arm has been squeezed for a moment, swing toward
	# the most open direction (probe a fan of yaws behind the character).
	if _cramped > 0.5:
		_cramped_time += delta
	else:
		_cramped_time = 0.0
	if not input_locked and _cramped_time > 0.25 and _since_manual > 0.6:
		var best_yaw := cam_yaw.rotation.y
		var best_len := -1.0
		var cur_len := -1.0
		for off in [-1.4, -1.0, -0.6, -0.3, 0.0, 0.3, 0.6, 1.0, 1.4]:
			var y: float = cam_yaw.rotation.y + off
			var back := Basis(Vector3.UP, y) * Vector3(0, 0, 1)
			var pq := PhysicsRayQueryParameters3D.create(cam_yaw.global_position, cam_yaw.global_position + back * _arm_target, spring_arm.collision_mask, [get_rid()])
			var ph := space.intersect_ray(pq)
			var free_len := _arm_target if ph.is_empty() else cam_yaw.global_position.distance_to(ph.position)
			if off == 0.0:
				cur_len = free_len
			free_len -= absf(off) * 0.4   # prefer small swings
			if free_len > best_len:
				best_len = free_len
				best_yaw = y
		# Only swing for a real gain (in a narrow shaft every direction is tight:
		# turning there just fights the player's steering).
		if best_len > cur_len + 1.0:
			cam_yaw.rotation.y = lerp_angle(cam_yaw.rotation.y, best_yaw, 1.0 - exp(-3.0 * delta))
	# --- whiskers: swing away from a wall on ONE side before it blocks the view
	# (both sides blocked = a corridor: leave the yaw alone, the arm handles it).
	var hits := []
	for side in [-1.0, 1.0]:
		var d: Vector3 = (Basis(Vector3.UP, side * 0.6) * cam_yaw.global_basis.z).normalized()
		var q := PhysicsRayQueryParameters3D.create(cam_yaw.global_position, cam_yaw.global_position + d * 2.2, spring_arm.collision_mask, [get_rid()])
		hits.append(not space.intersect_ray(q).is_empty())
	if not input_locked and hits[0] != hits[1]:
		cam_yaw.rotation.y += (-1.0 if hits[0] else 1.0) * 0.6 * delta
	cam_yaw.rotation.y = wrapf(cam_yaw.rotation.y, -PI, PI)
	_cam_yaw_written = cam_yaw.rotation.y
	# --- shoulder offset shrinks next to a wall on the right
	var right: Vector3 = cam_yaw.global_basis.x
	var sq := PhysicsRayQueryParameters3D.create(cam_yaw.global_position, cam_yaw.global_position + right * 0.9, spring_arm.collision_mask, [get_rid()])
	var sh := space.intersect_ray(sq)
	var shoulder_t := 0.6 if sh.is_empty() else clampf(cam_yaw.global_position.distance_to(sh.position) - 0.35, 0.0, 0.6)
	_shoulder = lerpf(_shoulder, shoulder_t, 1.0 - exp(-12.0 * delta))
	spring_arm.position.x = _shoulder
	# --- arm: collide in fast, ease out slowly; zone length
	spring_arm.spring_length = _arm_target
	var hit := spring_arm.get_hit_length()
	var target_len := minf(hit, _arm_target)
	var k_arm := 1.0 - exp(-(25.0 if target_len < _arm_len else 2.5) * delta)
	_arm_len = lerpf(_arm_len, target_len, k_arm)
	# Cramped (arm squeezed): lift the camera up and look down over the head
	# instead of jamming it into the back of the character.
	_cramped = lerpf(_cramped, clampf(1.0 - _arm_len / maxf(_arm_target * 0.6, 0.1), 0.0, 1.0), 1.0 - exp(-8.0 * delta))
	var lift := _cramped * 0.9
	var lq := PhysicsRayQueryParameters3D.create(cam_yaw.global_position, cam_yaw.global_position + Vector3.UP * (lift + 0.4), spring_arm.collision_mask, [get_rid()])
	var lh := space.intersect_ray(lq)
	if not lh.is_empty():
		lift = minf(lift, maxf(cam_yaw.global_position.distance_to(lh.position) - 0.4, 0.0))
	camera.position = Vector3(spring_arm.position.x * (1.0 - _cramped), 0.0, _arm_len) + cam_pitch.global_basis.inverse() * Vector3.UP * lift
	camera.rotation.x = -_cramped * 0.35
	# Fade the character out when the camera is right on top of it.
	var cam_dist := camera.global_position.distance_to(global_position + Vector3(0, 1.5, 0))
	var fade_t := clampf((1.4 - cam_dist) / 0.7, 0.0, 1.0)
	if absf(fade_t - _model_fade) > 0.01:
		_model_fade = lerpf(_model_fade, fade_t, 1.0 - exp(-12.0 * delta))
		for gi in model.find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).transparency = _model_fade * 0.85


## Point on the segment from -> to, pulled back `margin` from the first hit.
func _clear_point(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, margin: float) -> Vector3:
	var d := to - from
	if d.length() < 0.01:
		return to
	var q := PhysicsRayQueryParameters3D.create(from, to + d.normalized() * margin, spring_arm.collision_mask, [get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return to
	return from + d.normalized() * maxf(from.distance_to(hit.position) - margin, 0.0)


func _build_help() -> void:
	_help = CanvasLayer.new()
	_help.name = "ControlsHelp"
	_help.layer = 20
	_help.visible = false
	add_child(_help)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	_help.add_child(panel)
	var l := Label.new()
	l.text = "CONTROLS (F1 to hide)\n\nMove ............ W A S D\nCamera .......... Arrow keys (or mouse)\nRecenter camera . R\nSprint .......... Shift\nJump / swim up .. Space\nInteract ........ E\nMouse look ...... click to capture, Esc to release"
	l.add_theme_font_size_override("font_size", 18)
	panel.add_child(l)


func _update_water() -> void:
	var feet := global_position
	var best := -1.0
	for w in get_tree().get_nodes_in_group("water"):
		if w.contains(feet):
			var d: float = w.surface_y - feet.y
			if d > best:
				best = d
				water_surface = w.surface_y
	if best < 0.12:
		water_state = "none"
	elif water_state == "swim":
		water_state = "swim" if best > UNSWIM_DEPTH else "wade"
	else:
		water_state = "swim" if best > SWIM_DEPTH else "wade"
	swimming = water_state == "swim"
	_update_splash()


func _update_splash() -> void:
	if _splash == null:
		_splash = GPUParticles3D.new()
		_splash.name = "Splash"
		_splash.amount = 40
		_splash.lifetime = 0.6
		_splash.local_coords = false
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = 0.45
		pm.emission_ring_inner_radius = 0.3
		pm.emission_ring_height = 0.05
		pm.direction = Vector3.UP
		pm.spread = 35.0
		pm.initial_velocity_min = 1.2
		pm.initial_velocity_max = 2.6
		pm.gravity = Vector3(0, -9.0, 0)
		pm.scale_min = 0.5
		pm.scale_max = 1.0
		_splash.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.12, 0.12)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.9, 0.98, 1.0, 0.8)
		q.material = m
		_splash.draw_pass_1 = q
		add_child(_splash)
	var moving := Vector2(velocity.x, velocity.z).length() > 0.8
	_splash.emitting = water_state != "none" and moving
	if water_state != "none":
		_splash.position = Vector3(0, water_surface - global_position.y, 0)


func _apply_look() -> void:
	if input_locked:
		look_input = Vector2.ZERO
		return
	if look_input == Vector2.ZERO:
		return
	cam_yaw.rotation.y -= look_input.x
	cam_pitch.rotation.x = clamp(cam_pitch.rotation.x - look_input.y, pitch_min, pitch_max)
	look_input = Vector2.ZERO
	_cam_yaw_written = cam_yaw.rotation.y
	_since_manual = 0.0
	_move_yaw = cam_yaw.rotation.y


func _update_anim() -> void:
	var dt := get_physics_process_delta_time()
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var on_floor := is_on_floor()
	var next := "idle"
	if oneshot != "":
		_oneshot_left -= dt
		if _oneshot_left > 0.0:
			_set_anim(oneshot)
			return
		oneshot = ""
	if swimming:
		next = "swim"
	elif not on_floor:
		_air_time += dt
		next = "fall" if velocity.y < -2.0 and _air_time > 0.15 else "jump"
	else:
		if _air_time > 0.35:
			_land_left = LAND_TIME
		_air_time = 0.0
		if _land_left > 0.0 and hspeed < 1.0:
			_land_left -= dt
			next = "land"
		elif hspeed > run_speed + 0.5:
			next = "sprint"
		elif hspeed > WALK_MAX:
			next = "run"
		elif hspeed > 0.4:
			next = "walk"
		else:
			_idle_time += dt
			next = "look_around" if _idle_time > LOOK_AROUND_AFTER else "idle"
	if next != "idle" and next != "look_around":
		_idle_time = 0.0
	_set_anim(next)


func _body_language(delta: float) -> void:
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var accel := (hv - Vector3(_prev_hvel.x, 0.0, _prev_hvel.z)) / maxf(delta, 0.0001)
	_prev_hvel = velocity
	var fwd := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	var yaw_rate := wrapf(model.rotation.y - _prev_yaw, -PI, PI) / maxf(delta, 0.0001)
	_prev_yaw = model.rotation.y
	var speed_k := clampf(hv.length() / sprint_speed, 0.0, 1.0)
	var target := Vector2(
		clampf(accel.dot(fwd) * 0.012 + speed_k * 0.06, -0.15, 0.2),   # pitch: lean into acceleration/speed
		clampf(-yaw_rate * speed_k * 0.09, -0.22, 0.22))                 # roll: bank into turns
	if swimming:
		target = Vector2(0.55, 0.0)   # body stretched out forward in the water
	elif not is_on_floor():
		target = Vector2.ZERO
	_lean = _lean.lerp(target, clampf(8.0 * delta, 0.0, 1.0))
	model.rotation.x = _lean.x
	model.rotation.z = _lean.y
	_squash = move_toward(_squash, 0.0, delta * 0.6)
	var sq := sin(clampf(_squash / 0.12, 0.0, 1.0) * PI * 0.5) * _squash
	model.scale = Vector3(1.0 + sq * 0.5, 1.0 - sq, 1.0 + sq * 0.5)


func _set_anim(next: String) -> void:
	if next != anim_state:
		anim_state = next
		var pb: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
		pb.travel(next)


## Play a one-shot clip (e.g. "interact", "summon") over the locomotion states.
func play_oneshot(clip: String) -> void:
	var ap: AnimationPlayer = anim_tree.get_node(anim_tree.anim_player)
	oneshot = clip
	_oneshot_left = ap.get_animation(clip).length if ap.has_animation(clip) else 0.5
	_set_anim(clip)


## Teleport helper used by teleporters and tests.
func warp_to(xform: Transform3D) -> void:
	global_position = xform.origin
	velocity = Vector3.ZERO
	var fwd := -xform.basis.z
	cam_yaw.rotation.y = atan2(-fwd.x, -fwd.z)
	model.rotation.y = atan2(fwd.x, fwd.z)
	reset_physics_interpolation()
	snap_camera()
	if not input_locked:
		reweave(0.9)


## Weave-in progress for the summoning shader (0 = unwoven, 1 = whole).
func set_weave(p: float) -> void:
	weave = p
	for m in weave_mats:
		m.set_shader_parameter("weave_progress", p)


## Quick re-weave (respawn / teleport arrival).
func reweave(duration := 0.9) -> void:
	if _weave_tween and _weave_tween.is_valid():
		_weave_tween.kill()
	set_weave(0.0)
	_weave_tween = create_tween()
	_weave_tween.tween_method(set_weave, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

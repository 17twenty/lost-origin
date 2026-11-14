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
@onready var camera: Camera3D = $CameraYaw/CameraPitch/SpringArm3D/Camera3D
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
var sprinting := false
var _coyote := 0.0
var _jump_buffer := 0.0
var _jump_was_held := false
## Set by tests/cutscenes to steer the camera without a mouse.
var look_input := Vector2.ZERO


func _ready() -> void:
	WickerSkin.apply(model)
	spring_arm.add_excluded_object(get_rid())
	var ap: AnimationPlayer = anim_tree.get_node(anim_tree.anim_player)
	for n in LOOPING:
		if ap.has_animation(n):
			ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	anim_tree.active = true
	camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_input += event.relative * mouse_sensitivity


func _physics_process(delta: float) -> void:
	_apply_look()
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (cam_yaw.global_basis * Vector3(input.x, 0.0, input.y))
	dir.y = 0.0
	dir = dir.normalized() * min(input.length(), 1.0)
	sprinting = Input.is_action_pressed("sprint") and input.y < -0.3 and is_on_floor()

	var on_floor := is_on_floor()
	var speed := sprint_speed if sprinting else run_speed
	var target := dir * speed
	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	var rate: float
	if on_floor:
		rate = ground_accel if dir.length() > 0.01 else ground_decel
	else:
		rate = air_accel
	hvel = hvel.move_toward(target, rate * delta)

	# Jump: buffered press + coyote time so edges feel fair.
	var held := Input.is_action_pressed("jump")
	if held and not _jump_was_held:
		_jump_buffer = JUMP_BUFFER
	_jump_was_held = held
	_coyote = COYOTE_TIME if on_floor else max(_coyote - delta, 0.0)
	_jump_buffer = max(_jump_buffer - delta, 0.0)

	var vy := velocity.y
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

	if dir.length() > 0.05:
		var target_yaw := atan2(dir.x, dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, clamp(turn_speed * delta, 0.0, 1.0))
	_update_anim()


func _apply_look() -> void:
	if look_input == Vector2.ZERO:
		return
	cam_yaw.rotation.y -= look_input.x
	cam_pitch.rotation.x = clamp(cam_pitch.rotation.x - look_input.y, pitch_min, pitch_max)
	look_input = Vector2.ZERO


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

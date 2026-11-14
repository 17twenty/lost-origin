class_name WickerMotion
extends SkeletonModifier3D
## Procedural secondary motion layered on top of the AnimationTree:
##  - spring-damped straw mane and beard that lag behind head motion/acceleration
##  - idle breathing in the chest
## Added under the Skeleton3D at runtime by player.gd.

@export var stiffness := 60.0
@export var damping := 9.0
@export var max_angle := 0.55

var body: CharacterBody3D
var _mane := -1
var _beard := -1
var _chest := -1
var _prev_head := Vector3.ZERO
var _prev_vel := Vector3.ZERO
var _offset := Vector2.ZERO      # (pitch, roll) spring state in head space
var _offset_vel := Vector2.ZERO
var _t := 0.0
## Exposed for tests: latest mane spring offset (radians).
var spring := Vector2.ZERO


func _ready() -> void:
	var sk := get_skeleton()
	if sk:
		_mane = sk.find_bone("mane")
		_beard = sk.find_bone("beard")
		_chest = sk.find_bone("chest")


func _process_modification_with_delta(delta: float) -> void:
	_step(delta)


func _step(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or delta <= 0.0:
		return
	_t += delta
	var head_pos := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("head"))).origin
	var vel := (head_pos - _prev_head) / delta if _prev_head != Vector3.ZERO else Vector3.ZERO
	var acc := (vel - _prev_vel) / delta
	_prev_head = head_pos
	_prev_vel = vel
	# Express the acceleration in the model's frame: forward (+Z) / right (+X) / up.
	var basis := sk.global_transform.basis.orthonormalized()
	var a_local := basis.inverse() * acc
	# Spring: straw is pushed opposite to the head's acceleration, gravity-ish bias.
	var target := Vector2(clampf(a_local.z * 0.02 - a_local.y * 0.01, -max_angle, max_angle), clampf(-a_local.x * 0.02, -max_angle, max_angle))
	var force := (target - _offset) * stiffness - _offset_vel * damping
	_offset_vel += force * delta
	_offset += _offset_vel * delta
	_offset = _offset.clamp(Vector2(-max_angle, -max_angle), Vector2(max_angle, max_angle))
	spring = _offset
	# Idle breeze so the straw is never frozen.
	var breeze := Vector2(sin(_t * 1.7) * 0.03, sin(_t * 1.1 + 1.0) * 0.04)
	var rot := Quaternion.from_euler(Vector3(_offset.x + breeze.x, 0.0, _offset.y + breeze.y))
	if _mane >= 0:
		sk.set_bone_pose_rotation(_mane, sk.get_bone_pose_rotation(_mane) * rot)
	if _beard >= 0:
		sk.set_bone_pose_rotation(_beard, sk.get_bone_pose_rotation(_beard) * Quaternion.from_euler(Vector3(_offset.x * 0.6, 0.0, _offset.y * 0.6)))
	# Breathing: a slow chest swell, strongest when standing still.
	if _chest >= 0 and body:
		var calm := 1.0 - clampf(Vector2(body.velocity.x, body.velocity.z).length() / 4.0, 0.0, 1.0)
		var b := sin(_t * 1.6) * 0.5 + 0.5
		sk.set_bone_pose_scale(_chest, sk.get_bone_pose_scale(_chest) * Vector3(1.0 + 0.012 * b * calm, 1.0 + 0.02 * b * calm, 1.0 + 0.025 * b * calm))

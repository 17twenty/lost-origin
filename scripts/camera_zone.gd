class_name CameraZone
extends Area3D
## Camera framing hint volume (group "camera_zone"): arm length / pitch for
## the room, and an optional look-at point the auto-camera leans toward.
## Box CollisionShape3D child "Col" defines the extent; queried by the player.

@export var arm_length := 4.0
@export var pitch := -0.18
@export var has_hint := false
@export var hint := Vector3.ZERO

func _ready() -> void:
	add_to_group("camera_zone")

func contains(p: Vector3) -> bool:
	var cs := get_node_or_null("Col") as CollisionShape3D
	if cs == null or not (cs.shape is BoxShape3D):
		return false
	var local := cs.global_transform.affine_inverse() * p
	var half := (cs.shape as BoxShape3D).size * 0.5
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z

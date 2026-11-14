class_name WaterVolume
extends Area3D
## A body of water the player can wade or swim in (group "water"). The box
## CollisionShape3D child defines the extent; `surface_y` is the world height
## of the water surface. The player queries volumes directly (no signals), so
## this also works for teleports/respawns into water.

@export var surface_y := 0.0

func _ready() -> void:
	add_to_group("water")

## True if `p` (world) is inside the volume's footprint and not above the surface.
func contains(p: Vector3) -> bool:
	if p.y > surface_y + 0.05:
		return false
	var cs := get_node_or_null("Col") as CollisionShape3D
	if cs == null or not (cs.shape is BoxShape3D):
		return false
	var local := cs.global_transform.affine_inverse() * p
	var half := (cs.shape as BoxShape3D).size * 0.5
	return absf(local.x) <= half.x and absf(local.z) <= half.z and local.y >= -half.y

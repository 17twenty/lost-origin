extends Area3D
## Heightfields can't have tunnels. Where a tunnel pierces the terrain sheet
## (hidden inside walls), bodies inside this area stop colliding with the
## terrain layer (3) — player body and camera spring arm both.

const TERRAIN_LAYER := 3

func _ready() -> void:
	body_entered.connect(_set_terrain.bind(false))
	body_exited.connect(_set_terrain.bind(true))

func _set_terrain(body: Node3D, on: bool) -> void:
	if body is CollisionObject3D:
		(body as CollisionObject3D).set_collision_mask_value(TERRAIN_LAYER, on)
	var arm = body.get("spring_arm")
	if arm is SpringArm3D:
		var bit := 1 << (TERRAIN_LAYER - 1)
		arm.collision_mask = (arm.collision_mask | bit) if on else (arm.collision_mask & ~bit)

extends Area3D
## Respawns anything with warp_to() at the nearest "checkpoint" marker.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("warp_to"):
		return
	var best: Node3D = null
	var best_d := INF
	for cp in get_tree().get_nodes_in_group("checkpoint"):
		var d: float = cp.global_position.distance_squared_to(body.global_position)
		if d < best_d:
			best_d = d
			best = cp
	if best:
		body.warp_to(best.global_transform)

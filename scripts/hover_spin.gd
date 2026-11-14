extends Node3D
## Slow spin + bob (relic artefact).
var _t := 0.0
@onready var _base_y := position.y

func _process(delta: float) -> void:
	_t += delta
	rotation.y += delta * 0.8
	position.y = _base_y + sin(_t * 1.6) * 0.06

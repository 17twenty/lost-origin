class_name LevelReferenceShots
## Shot_Ref_<name> cameras framed to match each composition of inspiration.mp4
## (reference frames in art/reference/<name>.jpg). Rendered square (like the
## video) with the player hidden. Update these when a zone is re-laid out.

const FAC := preload("res://tools/level/facility.gd")

## name: [camera position, look-at target, vertical fov]
static func refs() -> Dictionary:
	var F := FAC.F
	var R := FAC.RING_Y
	return {
		"grotto": [Vector3(6.0, 2.6, -64.5), Vector3(-3.0, 4.0, -83.0), 80.0],
		"lagoon": [Vector3(-1.0, 1.0, 27.5), Vector3(28.0, 3.0, 17.0), 70.0],
		"garden": [Vector3(25.2, F + 2.3, -94.4), Vector3(18.6, F + 3.4, -102.5), 78.0],
		"corridor": [Vector3(19.2, F + 1.9, -87.0), Vector3(36.0, F + 1.0, -89.5), 75.0],
		"aqueduct": [Vector3(13.0, 0.2, -6.5), Vector3(-1.0, 2.2, -25.0), 72.0],
		"atrium": [Vector3(52.5, R + 2.4, -79.6), Vector3(50.0, F + 3.6, -97.5), 84.0],
		"control": [Vector3(63.8, R + 2.3, -88.0), Vector3(80.0, R + 1.0, -88.0), 80.0],
	}

static func build(shots: Node3D) -> void:
	var r := refs()
	for n in r:
		var v: Array = r[n]
		var m := SceneUtil.marker(shots, "Shot_Ref_" + String(n).capitalize(), v[0], v[1])
		m.set_meta("hide_player", true)
		m.set_meta("square", true)
		m.set_meta("fov", v[2])
		m.set_meta("ref", n)

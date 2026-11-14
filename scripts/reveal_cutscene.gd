extends Node3D
## Secret reveal: camera cuts to the sealed door, the panels slide apart with
## flickering lights, sparks and a flood of light, then the camera glides back
## to the player (< 6 s). Door collision is removed once it's open.

signal finished

@export var door_path: NodePath
@export var view_from := Vector3.ZERO
@export var view_at := Vector3.ZERO

var state := "idle"   # idle -> playing -> done
var cam: Camera3D
var player: CharacterBody3D
var door_open := false


func play(p: CharacterBody3D) -> void:
	if state != "idle":
		return
	player = p
	state = "playing"
	player.input_locked = true
	var door := get_node(door_path) as Node3D
	var left := door.get_node("PanelL") as Node3D
	var right := door.get_node("PanelR") as Node3D
	var col := door.get_node("Col") as CollisionShape3D
	var lights := door.get_node("Inside") as OmniLight3D
	var flood := door.get_node("Flood") as SpotLight3D
	var sparks := door.get_node("Sparks") as GPUParticles3D
	cam = Camera3D.new()
	cam.name = "RevealCamera"
	cam.fov = 60
	add_child(cam)
	cam.global_position = view_from
	cam.look_at(view_at, Vector3.UP)
	var tw := create_tween()
	tw.tween_interval(0.9)  # let the lever throw land, then cut
	tw.tween_callback(cam.make_current)
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		sparks.emitting = true
		lights.visible = true)
	# Lights flicker on inside.
	for k in 6:
		tw.tween_property(lights, "light_energy", 2.5 if k % 2 == 0 else 0.2, 0.08)
	tw.tween_property(lights, "light_energy", 3.0, 0.2)
	# Panels part; the light floods out.
	tw.tween_property(left, "position:x", left.position.x - 1.25, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(right, "position:x", right.position.x + 1.25, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(flood, "light_energy", 9.0, 1.4)
	tw.tween_callback(func() -> void:
		col.disabled = true
		door_open = true)
	tw.tween_interval(0.6)
	tw.tween_callback(_return_camera)


func _return_camera() -> void:
	var tw := create_tween()
	tw.tween_property(cam, "global_transform", player.camera.global_transform, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_finish)


func _finish() -> void:
	player.camera.make_current()
	player.input_locked = false
	cam.queue_free()
	state = "done"
	finished.emit()

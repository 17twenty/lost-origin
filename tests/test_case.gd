class_name TestCase
extends Object
## Base class for tests. Provides scene loading, physics stepping, input sim.

var tree: SceneTree
var errors: Array[String] = []
var scene: Node

func setup() -> void:
	pass

func teardown() -> void:
	for a in InputMap.get_actions():
		Input.action_release(a)
	if scene and is_instance_valid(scene):
		scene.queue_free()
		await tree.process_frame

func load_main() -> Node:
	scene = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(scene)
	await physics_frames(2)
	return scene

func physics_frames(n: int) -> void:
	for i in n:
		await tree.physics_frame

func seconds(s: float) -> void:
	await physics_frames(int(ceil(s * Engine.physics_ticks_per_second)))

func check(cond: bool, msg: String) -> bool:
	if not cond:
		errors.append(msg)
	return cond

func check_eq(a, b, msg: String) -> bool:
	return check(a == b, "%s (got %s, expected %s)" % [msg, a, b])

## Raycast straight down from pos; returns hit dictionary or {}.
func ground_below(from: Vector3, depth: float = 200.0) -> Dictionary:
	var space := (scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * depth)
	return space.intersect_ray(q)

func get_player() -> CharacterBody3D:
	return scene.get_node("Player")

## Steer the player toward `target` (XZ) by aiming the camera yaw and holding
## forward. Returns true if reached within `timeout` seconds. Records the
## lowest Y seen in `min_y_seen` so tests can assert nobody fell.
var min_y_seen := INF
func walk_to(target: Vector3, timeout := 20.0, sprint := false, reach := 1.0) -> bool:
	var p := get_player()
	Input.action_press("move_forward")
	if sprint:
		Input.action_press("sprint")
	var frames := int(timeout * Engine.physics_ticks_per_second)
	var ok := false
	for i in frames:
		var d := target - p.global_position
		d.y = 0
		if d.length() < reach:
			ok = true
			break
		p.cam_yaw.rotation.y = atan2(-d.x, -d.z)
		min_y_seen = min(min_y_seen, p.global_position.y)
		await tree.physics_frame
	Input.action_release("move_forward")
	Input.action_release("sprint")
	return ok

func marker_pos(name: String) -> Vector3:
	return (scene.get_node("Markers/" + name) as Node3D).global_position

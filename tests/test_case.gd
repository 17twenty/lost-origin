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

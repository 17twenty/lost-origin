extends Node3D
## Wall lever: within ~2 m and facing it, shows "E — Pull". Pulling it (once)
## plays the interact clip, throws the handle and starts the reveal cutscene.

signal pulled

@export var reveal_path: NodePath
@export var range := 2.8

var used := false
var in_range := false
@onready var handle: Node3D = $Pivot
@onready var prompt: Label3D = $Prompt


func _ready() -> void:
	prompt.visible = false


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null:
		return
	var to := global_position - player.global_position
	to.y = 0.0
	var facing := Vector3(sin(player.model.rotation.y), 0.0, cos(player.model.rotation.y))
	var view: Vector3 = -player.cam_yaw.global_basis.z
	view.y = 0.0
	# "Facing it" = the character OR the camera is turned toward the lever (players
	# stop at all angles in third person; what matters is that it's in front of them).
	var facing_ok := facing.dot(to.normalized()) > 0.2 or view.normalized().dot(to.normalized()) > 0.3
	in_range = not used and to.length() < range and facing_ok and not player.input_locked
	prompt.visible = in_range
	if in_range and Input.is_action_just_pressed("interact"):
		pull(player)


func pull(player: CharacterBody3D) -> void:
	if used:
		return
	used = true
	prompt.visible = false
	player.play_oneshot("interact")
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(handle, "rotation:x", deg_to_rad(70.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulled.emit()
	var reveal := get_node_or_null(reveal_path)
	if reveal:
		reveal.play(player)

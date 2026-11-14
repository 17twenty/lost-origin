extends SceneTree
## Generator: builds res://scenes/player.tscn (Wicker Man controller + rig + camera).
## Usage: Godot --headless -s tools/build_player.gd

const OUT := "res://scenes/player.tscn"
const MODEL := "res://assets/characters/wicker.glb"
const STATES := ["idle", "run", "sprint", "jump"]

func _initialize() -> void:
	var p := CharacterBody3D.new()
	p.name = "Player"
	p.set_script(load("res://scripts/player.gd"))
	p.collision_layer = 2
	p.collision_mask = 1 | (1 << 2)  # world + terrain
	p.floor_max_angle = deg_to_rad(50)
	p.floor_snap_length = 0.3

	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 2.1
	col.shape = cap
	col.position.y = 1.05
	p.add_child(col)

	var model := Node3D.new()
	model.name = "Model"
	p.add_child(model)
	var glb: Node3D = (load(MODEL) as PackedScene).instantiate()
	glb.name = "Wicker"
	model.add_child(glb)
	WickerSkin.build()

	var tree := AnimationTree.new()
	tree.name = "AnimationTree"
	p.add_child(tree)
	tree.anim_player = NodePath("../Model/Wicker/AnimationPlayer")
	var sm := AnimationNodeStateMachine.new()
	var x := 0
	for s in STATES:
		var an := AnimationNodeAnimation.new()
		an.animation = s
		sm.add_node(s, an, Vector2(200 * x, 100))
		x += 1
	for a in STATES:
		for b in STATES:
			if a != b:
				var t := AnimationNodeStateMachineTransition.new()
				t.xfade_time = 0.12 if b == "jump" else 0.2
				sm.add_transition(a, b, t)
	var start := AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition("Start", "idle", start)
	tree.tree_root = sm

	var yaw := Node3D.new()
	yaw.name = "CameraYaw"
	yaw.position.y = 1.85
	p.add_child(yaw)
	var pitch := Node3D.new()
	pitch.name = "CameraPitch"
	pitch.rotation.x = -0.18
	yaw.add_child(pitch)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.spring_length = 4.0
	arm.margin = 0.15
	arm.collision_mask = 1 | (1 << 2)
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	arm.shape = sphere
	arm.position.x = 0.6  # over the right shoulder
	pitch.add_child(arm)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 70
	cam.far = 1500
	arm.add_child(cam)

	var err := SceneUtil.save(p, OUT)
	p.free()
	print("build_player: saved %s (err=%d)" % [OUT, err])
	quit(err)

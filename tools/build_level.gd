extends SceneTree
## Generator: builds res://scenes/main.tscn from code. Re-runnable.
## Usage: Godot --headless -s tools/build_level.gd

const OUT := "res://scenes/main.tscn"

func _initialize() -> void:
	var root := Node3D.new()
	root.name = "Main"
	_build_environment(root)
	var level := SceneUtil.add(root, Node3D.new(), "Level")
	_build_placeholder_ground(level)
	var markers := SceneUtil.add(root, Node3D.new(), "Markers")
	SceneUtil.marker(markers, "Spawn", Vector3(0, 1, 0))
	var shots := SceneUtil.add(root, Node3D.new(), "Shots")
	SceneUtil.marker(shots, "Shot_Overview", Vector3(12, 8, 12), Vector3.ZERO)
	var err := SceneUtil.save(root, OUT)
	root.free()
	print("build_level: saved %s (err=%d)" % [OUT, err])
	quit(err)

func _build_environment(root: Node3D) -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.18, 0.45, 0.95)
	sm.sky_horizon_color = Color(0.65, 0.85, 1.0)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -35, 0)
	root.add_child(sun)

func _build_placeholder_ground(level: Node3D) -> void:
	var sand := SceneUtil.mat(Color(0.93, 0.88, 0.72))
	level.add_child(SceneUtil.box_body(Vector3(60, 1, 60), Vector3(0, -0.5, 0), sand, "Ground"))

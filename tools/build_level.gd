extends SceneTree
## Generator: builds res://scenes/main.tscn from code. Re-runnable.
## Usage: Godot --headless -s tools/build_level.gd

const OUT := "res://scenes/main.tscn"

func _initialize() -> void:
	var root := Node3D.new()
	root.name = "Main"
	_build_environment(root)
	var level := SceneUtil.add(root, Node3D.new(), "Level")
	var markers := SceneUtil.add(root, Node3D.new(), "Markers")
	var shots := SceneUtil.add(root, Node3D.new(), "Shots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/generated"))
	LevelOutdoor.build(level, markers, shots)
	LevelFacility.build(level, markers, shots)
	var spawn_pos := LevelOutdoor.ground(0, 10, 0.05)
	SceneUtil.marker(markers, "Spawn", spawn_pos)
	var player: Node3D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.name = "Player"
	root.add_child(player)
	player.position = spawn_pos
	var ch := SceneUtil.marker(shots, "Shot_Character", spawn_pos + Vector3(2.2, 1.6, 3.2), spawn_pos + Vector3(0, 1.0, 0))
	ch.set_meta("player_pos", spawn_pos)
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
	env.ambient_light_sky_contribution = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.95
	env.ssao_enabled = true
	env.glow_enabled = true
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.directional_shadow_max_distance = 120.0
	root.add_child(sun)

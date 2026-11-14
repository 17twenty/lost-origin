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
	LevelConnector.build(level, markers, shots)
	LevelGarden.build(level, markers, shots)
	LevelVines.build(level)
	LevelReferenceShots.build(shots)
	var spawn_pos := LevelOutdoor.ground(0, 10, 0.05)
	SceneUtil.marker(markers, "Spawn", spawn_pos)
	var player: Node3D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.name = "Player"
	root.add_child(player)
	player.position = spawn_pos
	var ch := SceneUtil.marker(shots, "Shot_Character", spawn_pos + Vector3(2.2, 1.6, 3.2), spawn_pos + Vector3(0, 1.0, 0))
	ch.set_meta("player_pos", spawn_pos)
	# Turnaround of the player character (compare with wicker-inspo/turn-around-final.png).
	for view in [["Front", Vector3(0, 1.15, 3.4)], ["Back", Vector3(0, 1.15, -3.4)], ["Side", Vector3(3.4, 1.15, 0)]]:
		var m := SceneUtil.marker(shots, "Shot_Turn" + view[0], spawn_pos + view[1], spawn_pos + Vector3(0, 1.08, 0))
		m.set_meta("player_pos", spawn_pos)
		m.set_meta("fov", 40.0)
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
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky.gdshader")
	var clouds := NoiseTexture2D.new()
	clouds.seamless = true
	clouds.width = 512
	clouds.height = 512
	var cn := FastNoiseLite.new()
	cn.frequency = 0.008
	cn.fractal_octaves = 5
	cn.seed = 21
	clouds.noise = cn
	sm.set_shader_parameter("cloud_noise", clouds)
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.ssao_enabled = true
	env.ssao_intensity = 1.5
	# Bloom: only genuinely bright things (trim, pads, sun glints) glow.
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	# Aerial perspective: distant hills/sea fade into the horizon colour.
	env.fog_enabled = true
	env.fog_light_color = Color(0.45, 0.72, 1.0)
	env.fog_density = 0.0015
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.0
	# Volumetric haze: light shafts in the grotto, halos round facility lights.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo = Color(0.85, 0.93, 1.0)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 96.0
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.05
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_volumetric_fog_energy = 0.6
	sun.directional_shadow_max_distance = 140.0
	root.add_child(sun)

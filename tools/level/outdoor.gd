class_name LevelOutdoor
## Builds the outdoor island: terrain, lagoon, totems, aqueduct bridge,
## jungle plateau, outdoor waterfall and the waterfall grotto with teleporter pad.

const T := preload("res://tools/level/terrain.gd")
const GEN := "res://scenes/generated"
const KENNEY := "res://assets/third_party/kenney_nature_kit/"
const TOTEM_GLB := "res://assets/props/totem.glb"

static var noise_tex: NoiseTexture2D
static var stone_mat: ShaderMaterial
static var rock_mat: ShaderMaterial
static var water_mat: ShaderMaterial
static var fall_mat: ShaderMaterial
static var glow_mat: StandardMaterial3D
static var rng := RandomNumberGenerator.new()
static var _kenney_cache := {}

static func h(x: float, z: float) -> float:
	return T.height(x, z)

static func ground(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, h(x, z) + lift, z)

# ------------------------------------------------------------------ materials
static func _materials() -> void:
	noise_tex = NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.width = 256
	noise_tex.height = 256
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	fn.fractal_octaves = 4
	noise_tex.noise = fn

	stone_mat = ShaderMaterial.new()
	stone_mat.shader = load("res://shaders/mossy_stone.gdshader")
	stone_mat.set_shader_parameter("noise_tex", noise_tex)

	rock_mat = ShaderMaterial.new()
	rock_mat.shader = stone_mat.shader
	rock_mat.set_shader_parameter("noise_tex", noise_tex)
	rock_mat.set_shader_parameter("stone_color", Color(0.48, 0.46, 0.42))
	rock_mat.set_shader_parameter("stone_dark", Color(0.26, 0.26, 0.25))
	rock_mat.set_shader_parameter("moss_amount", 0.4)

	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	water_mat.set_shader_parameter("noise_tex", noise_tex)
	for p in ["normal_a", "normal_b"]:
		var nt := NoiseTexture2D.new()
		nt.seamless = true
		nt.as_normal_map = true
		nt.bump_strength = 4.0
		nt.width = 512
		nt.height = 512
		var nn := FastNoiseLite.new()
		nn.frequency = 0.012 if p == "normal_a" else 0.02
		nn.seed = 3 if p == "normal_a" else 11
		nt.noise = nn
		water_mat.set_shader_parameter(p, nt)

	fall_mat = ShaderMaterial.new()
	fall_mat.shader = load("res://shaders/waterfall.gdshader")
	fall_mat.set_shader_parameter("noise_tex", noise_tex)

	glow_mat = SceneUtil.mat(Color(0.2, 0.95, 1.0), 0.2, 0.0, Color(0.2, 0.95, 1.0), 5.0)

# ---------------------------------------------------------------------- build
static func build(level: Node3D, markers: Node3D, shots: Node3D) -> void:
	rng.seed = 1234
	_materials()
	var out := SceneUtil.add(level, Node3D.new(), "Outdoor")

	var tmat := ShaderMaterial.new()
	tmat.shader = load("res://shaders/terrain.gdshader")
	tmat.set_shader_parameter("noise_tex", noise_tex)
	T.build(out, GEN, tmat)

	_water(out)
	_bridge(out)
	_totems(out)
	_grotto(out)
	_outdoor_waterfall(out)
	_foliage(out)
	_horizon(out)
	_bounds(out)
	_markers(markers, shots)

# ---------------------------------------------------------------------- water
static func _water_plane(parent: Node3D, name: String, size: Vector2, pos: Vector3, subdiv := 0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = subdiv
	pm.subdivide_depth = subdiv
	pm.material = water_mat
	mi.mesh = pm
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _water(out: Node3D) -> void:
	var w := SceneUtil.add(out, Node3D.new(), "Water")
	# One sea plane from the beach southwards (stays clear of the chasm).
	_water_plane(w, "Ocean", Vector2(3000, 3000), Vector3(0, T.WATER_Y, 1520), 0)
	_water_plane(w, "ChasmRiver", Vector2(160, 16), Vector3(0, T.CHASM_WATER_Y, T.CHASM_Z), 40)
	_water_plane(w, "PlungePool", Vector2(11, 11), Vector3(T.POOL_POS.x, -0.1, T.POOL_POS.y))
	# Falling into the chasm respawns you at the nearest checkpoint.
	_kill_zone(w, "ChasmKill", Vector3(200, 6, 15), Vector3(0, T.CHASM_WATER_Y - 2.5, T.CHASM_Z))

static func _kill_zone(parent: Node3D, name: String, size: Vector3, pos: Vector3) -> Area3D:
	var a := Area3D.new()
	a.name = name
	a.set_script(load("res://scripts/kill_zone.gd"))
	a.collision_layer = 0
	a.collision_mask = 2
	a.position = pos
	var cs := CollisionShape3D.new()
	cs.name = "Col"
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	a.add_child(cs)
	parent.add_child(a)
	return a

# --------------------------------------------------------------------- bridge
static func _csg_box(parent: Node, size: Vector3, pos: Vector3, op := CSGShape3D.OPERATION_UNION) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.operation = op
	b.material = stone_mat
	parent.add_child(b)
	return b

static func _csg_arch(parent: Node, radius: float, length: float, pos: Vector3, axis_x := true) -> void:
	var c := CSGCylinder3D.new()
	c.radius = radius
	c.height = length
	c.sides = 20
	c.operation = CSGShape3D.OPERATION_SUBTRACTION
	c.material = stone_mat
	c.rotation_degrees = Vector3(0, 0, 90) if axis_x else Vector3(90, 0, 0)
	c.position = pos
	parent.add_child(c)

static func _bridge(out: Node3D) -> void:
	var aq := CSGCombiner3D.new()
	aq.name = "AqueductBridge"
	aq.use_collision = true
	out.add_child(aq)
	var top := T.PATH_Y
	var z0 := -7.5
	var z1 := -28.5
	var zc := (z0 + z1) * 0.5
	var length := z0 - z1
	_csg_box(aq, Vector3(4.6, 11.0, length), Vector3(0, top - 5.5, zc))
	# Lower tier: three big arches over the river.
	for az in [-13.0, -18.0, -23.0]:
		_csg_arch(aq, 2.0, 5.0, Vector3(0, -4.5, az))
		_csg_box(aq, Vector3(5.0, 7.0, 4.0), Vector3(0, -8.0, az), CSGShape3D.OPERATION_SUBTRACTION)
	# Upper tier: small arcade openings.
	var z := -11.25
	while z > -25.0:
		_csg_arch(aq, 0.75, 5.0, Vector3(0, -1.9, z))
		_csg_box(aq, Vector3(5.0, 1.0, 1.5), Vector3(0, -2.4, z), CSGShape3D.OPERATION_SUBTRACTION)
		z -= 2.5
	# Parapets with ruined gaps.
	for sx in [-1.0, 1.0]:
		_csg_box(aq, Vector3(0.4, 0.8, length), Vector3(sx * 2.1, top + 0.4, zc))
	_csg_box(aq, Vector3(0.6, 1.0, 2.6), Vector3(2.1, top + 0.55, -15.5), CSGShape3D.OPERATION_SUBTRACTION)
	_csg_box(aq, Vector3(0.6, 0.5, 1.6), Vector3(-2.1, top + 0.65, -22.0), CSGShape3D.OPERATION_SUBTRACTION)
	_csg_box(aq, Vector3(0.6, 1.0, 1.2), Vector3(-2.1, top + 0.55, -12.0), CSGShape3D.OPERATION_SUBTRACTION)
	# Broken corner bite out of the deck edge (ruin), not on the walk line.
	_csg_box(aq, Vector3(1.2, 1.4, 1.8), Vector3(2.6, top - 0.2, -19.5), CSGShape3D.OPERATION_SUBTRACTION)
	# Fallen chunks in the river.
	var rubble := SceneUtil.add(out, Node3D.new(), "BridgeRubble")
	for p in [Vector3(4.5, T.CHASM_WATER_Y - 0.3, -19.0), Vector3(-5.0, T.CHASM_WATER_Y - 0.5, -14.0)]:
		var b := SceneUtil.box_body(Vector3(1.4, 1.2, 1.8), p, stone_mat, "Chunk")
		b.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
		rubble.add_child(b)

# --------------------------------------------------------------------- totems
static func _totem_mesh() -> Mesh:
	var path := GEN + "/totem_mesh.res"
	var src: Node = (load(TOTEM_GLB) as PackedScene).instantiate()
	var mi: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: ArrayMesh = mi.mesh.duplicate()
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m and m.resource_name == "Glow":
			mesh.surface_set_material(i, glow_mat)
		else:
			mesh.surface_set_material(i, stone_mat)
	src.free()
	ResourceSaver.save(mesh, path)
	return load(path)

static func _totem(parent: Node3D, mesh: Mesh, x: float, z: float, face: Vector2, s := 1.0) -> void:
	var body := StaticBody3D.new()
	body.name = "Totem"
	body.position = ground(x, z, -0.15)
	body.rotation.y = atan2(face.x - x, face.y - z)
	body.scale = Vector3.ONE * s
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.name = "Col"
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, 4.4, 1.6)
	cs.shape = bs
	cs.position.y = 2.2
	body.add_child(cs)
	parent.add_child(body)

static func _totems(out: Node3D) -> void:
	var mesh := _totem_mesh()
	var g := SceneUtil.add(out, Node3D.new(), "Totems")
	var centre := Vector2(0, 6)
	# Beach crescent facing the spawn.
	for p in [Vector2(-13, 3), Vector2(13, 1), Vector2(-19, 11), Vector2(20, 9), Vector2(-9, -3), Vector2(10, -4)]:
		_totem(g, mesh, p.x, p.y, centre, rng.randf_range(1.0, 1.3))
	# Shoreline row standing in the shallows, gazing out to sea (as in the video).
	for p in [Vector2(9, 22.5), Vector2(14, 24.0), Vector2(19.5, 23.0), Vector2(25, 21.5), Vector2(-12, 23.0), Vector2(-18, 21.5)]:
		_totem(g, mesh, p.x, p.y, Vector2(p.x * 1.2, 200), rng.randf_range(1.1, 1.5))
	# Gateways: bridge head and grotto entrance.
	for sx in [-1.0, 1.0]:
		_totem(g, mesh, sx * 4.2, -5.5, Vector2(sx * 4.2, 10), 1.15)
		_totem(g, mesh, sx * 4.2, -30.5, Vector2(sx * 4.2, -50), 1.0)
		_totem(g, mesh, sx * 6.5, -57.0, Vector2(sx * 6.5, -40), 1.35)

# --------------------------------------------------------------------- grotto
static func _grotto(out: Node3D) -> void:
	var g := SceneUtil.add(out, Node3D.new(), "Grotto")
	var floor_y := T.PATH_Y + 0.02
	# Floor slab running out of the entrance to meet the path.
	g.add_child(SceneUtil.box_body(Vector3(20, 1, 28), Vector3(0, floor_y - 0.5, -72), rock_mat, "Floor"))
	# Shell: walls + roof cap with a skylight above the waterfall pool.
	var shell := CSGCombiner3D.new()
	shell.name = "Shell"
	shell.use_collision = true
	g.add_child(shell)
	for b in [
		[Vector3(3, 12, 28), Vector3(-11.5, 5.5, -73)],    # west wall
		[Vector3(3, 12, 28), Vector3(11.5, 5.5, -73)],     # east wall (Phase 5: facility door)
		[Vector3(26, 12, 3), Vector3(0, 5.5, -86.5)],      # back wall
		[Vector3(9.5, 12, 2.5), Vector3(-8.25, 5.5, -60.5)],  # front wall west
		[Vector3(9.5, 12, 2.5), Vector3(8.25, 5.5, -60.5)],   # front wall east
		[Vector3(7, 6, 2.5), Vector3(0, 8.5, -60.5)],      # lintel
		[Vector3(26, 14, 29), Vector3(0, 17.0, -73)],      # roof cap (top below cliff crest)
	]:
		var cb := _csg_box(shell, b[0], b[1])
		cb.material = rock_mat
	# Rough arch for the entrance and the skylight shaft.
	var arch := _csg_box(shell, Vector3(7, 7, 4), Vector3(0, floor_y + 2.0, -60.5), CSGShape3D.OPERATION_SUBTRACTION)
	arch.material = rock_mat
	var sky := CSGCylinder3D.new()
	sky.radius = 2.2
	sky.height = 30
	sky.sides = 12
	sky.operation = CSGShape3D.OPERATION_SUBTRACTION
	sky.material = rock_mat
	sky.position = Vector3(0, 20, -81)
	shell.add_child(sky)
	# Waterfall pool against the back wall.
	var pool := SceneUtil.add(g, Node3D.new(), "Pool")
	for r in [
		[Vector3(10, 0.6, 0.6), Vector3(0, floor_y + 0.3, -77.2)],
		[Vector3(0.6, 0.6, 7.6), Vector3(-5.0, floor_y + 0.3, -81.0)],
		[Vector3(0.6, 0.6, 7.6), Vector3(5.0, floor_y + 0.3, -81.0)],
	]:
		pool.add_child(SceneUtil.box_body(r[0], r[1], stone_mat, "Rim"))
	_water_plane(pool, "PoolWater", Vector2(9.4, 7.4), Vector3(0, floor_y + 0.45, -81.0))
	_fall(g, "GrottoFall", Vector3(0, 10.5, -81.5), Vector3(0, floor_y + 0.4, -81.5), 3.2)
	# Teleporter pad (Phase 5 wires up the Area3D).
	var pad := _pad(g, "TeleporterGrotto", Vector3(0, floor_y, -71))
	pad.set_meta("zone", "grotto")
	# Lights: cool pad glow + warm shaft from the skylight.
	var shaft := SpotLight3D.new()
	shaft.name = "SkylightShaft"
	shaft.position = Vector3(0, 12, -79)
	shaft.rotation_degrees = Vector3(-80, 0, 0)
	shaft.spot_range = 20
	shaft.spot_angle = 30
	shaft.light_energy = 10
	shaft.light_volumetric_fog_energy = 4.0
	shaft.light_color = Color(1.0, 0.94, 0.78)
	shaft.shadow_enabled = true
	g.add_child(shaft)
	var fill := OmniLight3D.new()
	fill.name = "CaveFill"
	fill.position = Vector3(0, 6, -66)
	fill.omni_range = 20
	fill.light_energy = 3.0
	fill.light_color = Color(0.85, 1.0, 0.85)
	g.add_child(fill)
	var fill2 := OmniLight3D.new()
	fill2.name = "CaveFillBack"
	fill2.position = Vector3(0, 5, -78)
	fill2.omni_range = 14
	fill2.light_energy = 2.2
	fill2.light_color = Color(1.0, 0.92, 0.8)
	g.add_child(fill2)
	_fog_volume(g, "CaveHaze", Vector3(19, 9, 25), Vector3(0, 4.8, -73), 0.035, Color(0.9, 0.97, 1.0))
	_mist(g, "PoolMist", Vector3(0, floor_y + 0.6, -81.2), 3.0)
	# Rocky facade so the entrance reads as a cave mouth, not a wall.
	for r in [[Vector3(-7.5, 0, -58.8), 6.0], [Vector3(7.8, 0, -58.6), 6.5], [Vector3(-11.5, 4, -59.2), 8.0],
			[Vector3(11.5, 4, -59.0), 8.0], [Vector3(-4.5, 9.5, -59.5), 6.0], [Vector3(4.0, 10.0, -59.4), 6.5], [Vector3(0, 11.5, -59.8), 5.0]]:
		var rp: Vector3 = r[0]
		_kenney(g, ["rock_tallA", "rock_tallB", "rock_largeD", "rock_largeF"][rng.randi() % 4], rp + Vector3(0, floor_y, 0), r[1], false)
	for i in 8:
		_kenney(g, ["plant_bushDetailed", "grass_leafsLarge", "plant_flatTall"][rng.randi() % 3], Vector3(rng.randf_range(-12, 12), rng.randf_range(6, 12), -59.0), rng.randf_range(4, 7), false)
	# Lush cave floor: ferns, grass and flowers, clear of the pad, pool and east door.
	var keep_clear := [Vector2(0, -71), Vector2(0, -81), Vector2(0, -66), Vector2(9, -66)]
	for i in 70:
		var gx := rng.randf_range(-9.2, 9.2)
		var gz := rng.randf_range(-84.5, -62.5)
		if not _clear_of(Vector2(gx, gz), keep_clear, 3.2) or abs(gx) < 2.0:
			continue
		_kenney(g, ["grass_large", "grass_leafsLarge", "plant_flatTall", "plant_bushDetailed", "flower_yellowA", "grass_leafs"][rng.randi() % 6], Vector3(gx, floor_y, gz), rng.randf_range(3.0, 5.5), false)
	# Mossy rocks and ferns along the walls.
	for i in 14:
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := rng.randf_range(-84, -63)
		if side > 0.0 and z > -71.0:
			z -= 9.0  # keep the east door (z -64..-68) clear
		var x := side * rng.randf_range(7.5, 9.5)
		_kenney(g, ["rock_tallA", "rock_tallB", "rock_largeD", "rock_largeF"][rng.randi() % 4], Vector3(x, floor_y, z), rng.randf_range(2.0, 3.5), false)
		_kenney(g, ["plant_bushDetailed", "plant_flatTall", "grass_leafsLarge"][rng.randi() % 3], Vector3(x - side * 1.5, floor_y, z + 1), rng.randf_range(3, 5), false)

static func _pad(parent: Node3D, name: String, pos: Vector3) -> Node3D:
	var pad := Node3D.new()
	pad.name = name
	pad.position = pos
	parent.add_child(pad)
	var base := SceneUtil.box_body(Vector3(1, 1, 1), Vector3.ZERO, null, "Base")
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.7
	cyl.bottom_radius = 2.1
	cyl.height = 0.16
	cyl.radial_segments = 8
	cyl.material = stone_mat
	(base.get_node("Mesh") as MeshInstance3D).mesh = cyl
	# Convex hull keeps the bevelled rim walkable (no hard step).
	(base.get_node("Col") as CollisionShape3D).shape = cyl.create_convex_shape()
	base.position.y = 0.08
	pad.add_child(base)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var tm := TorusMesh.new()
	tm.inner_radius = 1.25
	tm.outer_radius = 1.45
	tm.rings = 32
	tm.ring_segments = 6
	tm.material = glow_mat
	ring.mesh = tm
	ring.position.y = 0.17
	ring.scale = Vector3(1, 0.3, 1)
	pad.add_child(ring)
	var core := MeshInstance3D.new()
	core.name = "Core"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.6
	disc.bottom_radius = 0.6
	disc.height = 0.02
	disc.material = glow_mat
	core.mesh = disc
	core.position.y = 0.17
	pad.add_child(core)
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.position.y = 1.0
	light.omni_range = 7
	light.light_energy = 2.0
	light.light_color = Color(0.3, 0.9, 1.0)
	pad.add_child(light)
	var trig := Area3D.new()
	trig.name = "Trigger"
	trig.set_script(load("res://scripts/teleporter.gd"))
	trig.collision_layer = 0
	trig.collision_mask = 2
	var tcs := CollisionShape3D.new()
	tcs.name = "Col"
	var tshape := CylinderShape3D.new()
	tshape.radius = 1.1
	tshape.height = 2.0
	tcs.shape = tshape
	tcs.position.y = 1.0
	trig.add_child(tcs)
	pad.add_child(trig)
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	var bm := CylinderMesh.new()
	bm.top_radius = 1.0
	bm.bottom_radius = 1.4
	bm.height = 5.0
	bm.cap_top = false
	bm.cap_bottom = false
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bmat.albedo_color = Color(0.3, 0.95, 1.0, 0.8)
	bm.material = bmat
	beam.mesh = bm
	beam.position.y = 2.5
	beam.visible = false
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pad.add_child(beam)
	var burst := GPUParticles3D.new()
	burst.name = "Burst"
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 80
	burst.lifetime = 1.2
	burst.explosiveness = 0.85
	burst.position.y = 0.2
	var ppm := ParticleProcessMaterial.new()
	ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	ppm.emission_ring_radius = 1.3
	ppm.emission_ring_inner_radius = 1.1
	ppm.emission_ring_height = 0.1
	ppm.emission_ring_axis = Vector3.UP
	ppm.direction = Vector3.UP
	ppm.spread = 8.0
	ppm.initial_velocity_min = 2.5
	ppm.initial_velocity_max = 5.0
	ppm.gravity = Vector3(0, -0.5, 0)
	ppm.scale_min = 0.6
	ppm.scale_max = 1.2
	burst.process_material = ppm
	var spark := SphereMesh.new()
	spark.radius = 0.05
	spark.height = 0.1
	spark.radial_segments = 6
	spark.rings = 3
	spark.material = glow_mat
	burst.draw_pass_1 = spark
	pad.add_child(burst)
	var arrival := SceneUtil.marker(pad, "Arrival", Vector3(0, 0.25, 2.6))
	arrival.rotation.y = PI  # face away from the pad
	return pad

static func _fall(parent: Node3D, name: String, top: Vector3, bottom: Vector3, width: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var q := QuadMesh.new()
	var length := top.distance_to(bottom)
	q.size = Vector2(width, length)
	q.material = fall_mat
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mid := (top + bottom) * 0.5
	var down := (bottom - top).normalized()
	var right := Vector3.RIGHT
	var normal := right.cross(-down).normalized()
	mi.transform = Transform3D(Basis(right, -down, normal), mid)
	parent.add_child(mi)
	return mi

static func _outdoor_waterfall(out: Node3D) -> void:
	var g := SceneUtil.add(out, Node3D.new(), "Waterfall")
	var x := T.POOL_POS.x
	_fall(g, "Fall", Vector3(x, h(x, -66.5) + 0.5, -66.5), Vector3(x, -0.1, T.POOL_POS.y - 2.5), 4.5)
	_fall(g, "FallThin", Vector3(x + 2.8, h(x + 2.8, -65.5) + 0.3, -65.5), Vector3(x + 2.8, -0.1, T.POOL_POS.y - 2.0), 1.5)
	_mist(g, "Mist", Vector3(x + 0.8, 0.2, T.POOL_POS.y - 1.8), 5.0)

static func _fog_volume(parent: Node3D, name: String, size: Vector3, pos: Vector3, density: float, albedo: Color) -> FogVolume:
	var fv := FogVolume.new()
	fv.name = name
	fv.size = size
	fv.position = pos
	var fm := FogMaterial.new()
	fm.density = density
	fm.albedo = albedo
	fm.edge_fade = 0.3
	fv.material = fm
	parent.add_child(fv)
	return fv

static func _mist(parent: Node3D, name: String, pos: Vector3, width: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = name
	p.position = pos
	p.amount = 40
	p.lifetime = 2.5
	p.preprocess = 2.5
	p.visibility_aabb = AABB(Vector3(-width * 2, -1, -width * 2), Vector3(width * 4, 6, width * 4))
	var ppm := ParticleProcessMaterial.new()
	ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ppm.emission_box_extents = Vector3(width * 0.5, 0.2, 0.6)
	ppm.direction = Vector3(0, 1, 0.4)
	ppm.spread = 50.0
	ppm.initial_velocity_min = 0.4
	ppm.initial_velocity_max = 1.2
	ppm.gravity = Vector3(0, 0.15, 0)
	ppm.scale_min = 1.5
	ppm.scale_max = 3.0
	var sc := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.0))
	sc.curve = curve
	ppm.scale_curve = sc
	var ramp := GradientTexture1D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	grad.add_point(0.25, Color(1, 1, 1, 0.35))
	ramp.gradient = grad
	ppm.color_ramp = ramp
	p.process_material = ppm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.92, 0.97, 1.0)
	var puff := GradientTexture2D.new()
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(0.5, 0.0)
	var pg := Gradient.new()
	pg.set_color(0, Color(1, 1, 1, 1))
	pg.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = pg
	m.albedo_texture = puff
	q.material = m
	p.draw_pass_1 = q
	parent.add_child(p)
	return p

static func _horizon(out: Node3D) -> void:
	# Sea stacks hide the terrain edges from the lagoon; far islets dress the horizon.
	var h := SceneUtil.add(out, Node3D.new(), "Horizon")
	for st in [[Vector3(-78, -3, 22), 22.0], [Vector3(-90, -3, 45), 30.0], [Vector3(79, -3, 25), 24.0], [Vector3(92, -3, 50), 28.0],
			[Vector3(-70, -3, 62), 14.0], [Vector3(66, -3, 66), 12.0]]:
		_kenney(h, ["rock_tallA", "rock_tallB", "rock_tallC", "rock_tallD"][rng.randi() % 4], st[0], st[1], false)
	for isl in [[Vector3(-260, -6, 380), 60.0], [Vector3(180, -6, 520), 80.0], [Vector3(420, -6, 300), 50.0], [Vector3(-520, -6, 640), 90.0]]:
		_kenney(h, ["rock_largeA", "rock_largeC", "rock_largeE"][rng.randi() % 3], isl[0], isl[1], false)
		for k in 4:
			var ip: Vector3 = isl[0] + Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-10, 10)) * (isl[1] / 60.0)
			_kenney(h, "tree_palmTall", ip + Vector3(0, isl[1] * 0.25, 0), isl[1] * 0.25, false)

# -------------------------------------------------------------------- foliage
## Kenney's palette is pastel; remap by material name to the lush video palette.
const PALETTE := {
	"grass": Color(0.24, 0.58, 0.14), "leafsGreen": Color(0.20, 0.56, 0.13),
	"leafsDark": Color(0.10, 0.38, 0.09), "woodBark": Color(0.45, 0.32, 0.20),
	"woodInner": Color(0.78, 0.64, 0.44), "dirt": Color(0.46, 0.34, 0.21),
	"colorTan": Color(0.86, 0.72, 0.52), "colorRed": Color(0.88, 0.18, 0.14),
	"colorYellow": Color(0.98, 0.80, 0.18), "colorPurple": Color(0.58, 0.32, 0.88),
}

static func _kenney_mesh(model: String) -> Mesh:
	if _kenney_cache.has(model):
		return _kenney_cache[model]
	var path := GEN + "/kenney/" + model + ".res"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GEN + "/kenney"))
	var src: Node3D = (load(KENNEY + model + ".glb") as PackedScene).instantiate()
	var out := ArrayMesh.new()
	var mats := {}
	for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var n: Node = mi
		while n != src:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for i in mi.mesh.get_surface_count():
			var st := SurfaceTool.new()
			st.append_from(mi.mesh, i, xf)
			var m: Material = mi.mesh.surface_get_material(i)
			var key := m.resource_name if m else "_default"
			if not mats.has(key):
				if key == "stone":
					mats[key] = rock_mat
				elif PALETTE.has(key):
					var sm := StandardMaterial3D.new()
					sm.albedo_color = PALETTE[key]
					sm.roughness = 0.85
					sm.cull_mode = BaseMaterial3D.CULL_DISABLED if key.begins_with("leafs") or key == "grass" else BaseMaterial3D.CULL_BACK
					mats[key] = sm
				else:
					mats[key] = m
			st.set_material(mats[key])
			st.commit(out)
	src.free()
	ResourceSaver.save(out, path)
	_kenney_cache[model] = load(path)
	return _kenney_cache[model]

static func _kenney(parent: Node3D, model: String, pos: Vector3, s: float, collide: bool, collider_radius := 0.35, collider_h := 5.0) -> Node3D:
	var inst := MeshInstance3D.new()
	inst.mesh = _kenney_mesh(model)
	inst.name = model
	inst.position = pos
	inst.rotation.y = rng.randf() * TAU
	inst.scale = Vector3.ONE * s
	parent.add_child(inst)
	if collide:
		var body := StaticBody3D.new()
		body.name = model + "_col"
		body.position = pos
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = collider_radius
		cyl.height = collider_h
		cs.shape = cyl
		cs.position.y = collider_h * 0.5
		body.add_child(cs)
		parent.add_child(body)
	return inst

static func _clear_of(p: Vector2, avoid: Array, r: float) -> bool:
	for a in avoid:
		if p.distance_to(a) < r:
			return false
	return true

static func _scatter(parent: Node3D, count: int, rect: Rect2, models: Array, s_range: Vector2, path_clear: float, avoid: Array, collide := false, max_slope := 0.35, min_y := -0.2) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 30:
		tries += 1
		var x := rng.randf_range(rect.position.x, rect.end.x)
		var z := rng.randf_range(rect.position.y, rect.end.y)
		if abs(x) < path_clear:
			continue
		if not _clear_of(Vector2(x, z), avoid, 3.0):
			continue
		var y := h(x, z)
		if y < min_y:
			continue
		var slope: float = abs(h(x + 1, z) - h(x - 1, z)) * 0.5 + abs(h(x, z + 1) - h(x, z - 1)) * 0.5
		if slope > max_slope:
			continue
		var s := rng.randf_range(s_range.x, s_range.y)
		_kenney(parent, models[rng.randi() % models.size()], Vector3(x, y - 0.05, z), s, collide, 0.35 * s / 6.0, 5.0 * s / 6.0)
		placed += 1

static func _foliage(out: Node3D) -> void:
	var f := SceneUtil.add(out, Node3D.new(), "Foliage")
	var totems := [Vector2(-13, 3), Vector2(13, 1), Vector2(-19, 11), Vector2(20, 9), Vector2(-9, -3), Vector2(10, -4), Vector2(0, 8)]
	var palms := ["tree_palmTall", "tree_palmBend", "tree_palmDetailedTall", "tree_palm"]
	# Beach.
	_scatter(f, 22, Rect2(-34, -8, 68, 26), palms, Vector2(5.0, 7.5), 7.0, totems, true, 0.3, 0.0)
	_scatter(f, 30, Rect2(-34, -8, 68, 24), ["grass_large", "grass_leafsLarge", "plant_flatShort"], Vector2(3, 5), 5.0, [], false, 0.4, 0.1)
	_scatter(f, 14, Rect2(-40, -9, 80, 34), ["rock_largeA", "rock_largeC", "rock_largeE", "rock_smallA"], Vector2(2.5, 5), 6.0, totems, false, 0.6, -2.5)
	# Jungle plateau.
	var plateau := Rect2(-30, -58, 60, 30)
	var keep := [Vector2(T.POOL_POS.x, T.POOL_POS.y), Vector2(0, -57)]
	_scatter(f, 18, plateau, ["tree_palmDetailedTall", "tree_palmTall", "tree_palmDetailedShort"], Vector2(6.0, 9.0), 6.0, keep, true, 0.45)
	_scatter(f, 50, plateau, ["plant_bushLarge", "plant_bushDetailed", "plant_bush", "plant_flatTall"], Vector2(4, 7), 4.0, keep, false, 0.6)
	_scatter(f, 70, plateau, ["grass_large", "grass_leafsLarge", "grass_leafs"], Vector2(4, 6), 3.0, [], false, 0.7)
	_scatter(f, 24, plateau, ["flower_yellowA", "flower_redA", "flower_purpleA", "mushroom_redGroup"], Vector2(4, 6), 3.0, [], false, 0.6)
	_scatter(f, 14, plateau, ["rock_tallA", "rock_tallC", "rock_largeD", "stone_tallA"], Vector2(3, 6), 6.0, keep, false, 0.8)
	# Hillsides.
	_scatter(f, 30, Rect2(-70, -90, 140, 100), ["rock_tallB", "rock_tallD", "rock_largeB", "rock_largeF"], Vector2(5, 10), 30.0, [], false, 3.0, 2.0)
	_scatter(f, 30, Rect2(-70, -90, 140, 100), ["tree_palmDetailedTall", "tree_palmBend"], Vector2(6, 9), 32.0, [], false, 1.2, 2.0)

# --------------------------------------------------------------------- bounds
static func _bounds(out: Node3D) -> void:
	var b := SceneUtil.add(out, Node3D.new(), "Bounds")
	for w in [
		[Vector3(120, 30, 1), Vector3(0, 10, 30)],     # lagoon (knee-deep limit)
		[Vector3(1, 80, 170), Vector3(-52, 20, -15)],
		[Vector3(1, 80, 108), Vector3(52, 20, -8)],      # east, outdoor stretch
		[Vector3(1, 60, 40), Vector3(52, 40, -81)],      # east above the buried facility
		[Vector3(120, 60, 1), Vector3(0, 40, -99)],      # south, above the buried facility/garden
	]:
		var body := StaticBody3D.new()
		body.name = "Wall"
		body.position = w[1]
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = w[0]
		cs.shape = bs
		body.add_child(cs)
		b.add_child(body)
	_kill_zone(b, "WorldKill", Vector3(600, 10, 600), Vector3(0, -65, 0))

# -------------------------------------------------------------------- markers
static func _markers(markers: Node3D, shots: Node3D) -> void:
	var zones := {
		"Zone_Beach": Vector2(0, 8),
		"Zone_BridgeSouth": Vector2(0, -6.5),
		"Zone_BridgeMid": Vector2(0, -18),
		"Zone_BridgeNorth": Vector2(0, -30),
		"Zone_Plateau": Vector2(0, -44),
		"Zone_GrottoEntrance": Vector2(0, -57),
		"Zone_GrottoPad": Vector2(0, -71),
		"Zone_GrottoInside": Vector2(0, -66),
	}
	for n in zones:
		var p: Vector2 = zones[n]
		var y := T.PATH_Y if abs(p.y + 18) < 10 or p.y < -58 else h(p.x, p.y)
		SceneUtil.marker(markers, n, Vector3(p.x, y + 0.05, p.y))
	var cps := {"CP_Beach": Vector2(0, 8), "CP_BridgeSouth": Vector2(0, -6), "CP_BridgeNorth": Vector2(0, -30), "CP_Grotto": Vector2(0, -57)}
	for cp_name in cps:
		var cp: Vector2 = cps[cp_name]
		var m := SceneUtil.marker(markers, cp_name, Vector3(cp.x, h(cp.x, cp.y) + 0.1, cp.y))
		m.rotation.y = 0.0  # face north (-Z) along the route
		m.add_to_group("checkpoint", true)
	var beach := SceneUtil.marker(shots, "Shot_Beach", Vector3(-6, 3.2, 20), Vector3(2, 1.5, -2))
	beach.set_meta("player_pos", ground(-2, 12, 0.05))
	var bridge := SceneUtil.marker(shots, "Shot_Bridge", Vector3(16, 4.5, -8.5), Vector3(0, -2.0, -19))
	bridge.set_meta("player_pos", Vector3(0, T.PATH_Y + 0.05, -16))
	var plateau := SceneUtil.marker(shots, "Shot_Plateau", Vector3(-6, 3.0, -36), Vector3(10, 4, -60))
	plateau.set_meta("player_pos", ground(-1, -44, 0.05))
	var lagoon := SceneUtil.marker(shots, "Shot_Lagoon", Vector3(-2.5, 2.3, 13), Vector3(12, 1.2, 30))
	lagoon.set_meta("player_pos", ground(1.5, 17, 0.05))
	var grotto := SceneUtil.marker(shots, "Shot_Grotto", Vector3(3.5, 2.6, -63.5), Vector3(-0.5, 1.5, -78))
	grotto.set_meta("player_pos", Vector3(0.8, T.PATH_Y + 0.1, -67.5))

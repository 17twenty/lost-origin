class_name LevelFacility
## Undersea facility, buried under the back cliff east of the grotto.
##
##   Floor F = -6.
##   West vestibule  x 17..20   (Phase 5: ramp up to the grotto east door)
##   Aquarium corridor x 20..40, z -84..-92, windows N+S onto ocean backdrops,
##                   three octagonal pools along the centre line.
##   Atrium          octagon centred (50, -88), inner apothem 10, height 12,
##                   glass water column, ramp on the inner south side up to an
##                   octagonal ring walkway at RING_Y.
##   Control room    x 60.8..74, z -84..-92 at RING_Y, consoles + teleporter pad.

const O := preload("res://tools/level/outdoor.gd")
const F := -6.0
const RING_Y := -2.5
const ATRIUM := Vector3(50, F, -88)
const APOTHEM := 10.0
const WALL := 0.8
const RING_IN := 7.4
const RAMP_X := 2.0  # ramp centre offset from atrium centre (spans -2..6, top at the west end)

static var metal: ShaderMaterial
static var metal_dark: ShaderMaterial
static var hex_mat: ShaderMaterial
static var glass: StandardMaterial3D
static var trim: StandardMaterial3D
static var pool_mat: StandardMaterial3D

static func _materials() -> void:
	metal = ShaderMaterial.new()
	metal.shader = load("res://shaders/facility_metal.gdshader")
	metal.set_shader_parameter("noise_tex", O.noise_tex)
	metal_dark = metal.duplicate()
	metal_dark.set_shader_parameter("base_color", Color(0.17, 0.2, 0.25))
	metal_dark.set_shader_parameter("panel_size", Vector2(1.0, 0.5))
	hex_mat = ShaderMaterial.new()
	hex_mat.shader = load("res://shaders/hex_floor.gdshader")
	glass = StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.55, 0.85, 1.0, 0.12)
	glass.roughness = 0.03
	glass.metallic_specular = 0.9
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	trim = SceneUtil.mat(Color(0.2, 0.95, 1.0), 0.2, 0.0, Color(0.2, 0.95, 1.0), 6.0)
	pool_mat = SceneUtil.mat(Color(0.1, 0.75, 0.95), 0.05, 0.0, Color(0.1, 0.7, 1.0), 2.5)
	pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_mat.albedo_color.a = 0.75

static func circumradius(apothem: float) -> float:
	return apothem / cos(PI / 8.0)

# --------------------------------------------------------------------- helpers
static func _box(parent: Node, size: Vector3, pos: Vector3, mat: Material, op := CSGShape3D.OPERATION_UNION) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.operation = op
	b.material = mat
	parent.add_child(b)
	return b

static func _oct(parent: Node, apothem: float, height: float, pos: Vector3, mat: Material, op := CSGShape3D.OPERATION_UNION) -> CSGCylinder3D:
	var c := CSGCylinder3D.new()
	c.radius = circumradius(apothem)
	c.height = height
	c.sides = 8
	c.position = pos
	c.rotation.y = PI / 8.0  # flat faces toward the axes
	c.operation = op
	c.material = mat
	parent.add_child(c)
	return c

static func _strip(parent: Node3D, size: Vector3, pos: Vector3, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat if mat else trim
	mi.mesh = bm
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _hex_floor(parent: Node3D, size: Vector2, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "HexFloor"
	var pm := PlaneMesh.new()
	pm.size = size
	pm.material = hex_mat
	mi.mesh = pm
	mi.position = pos + Vector3(0, 0.01, 0)
	parent.add_child(mi)

static func _light(parent: Node3D, pos: Vector3, color: Color, energy: float, rng_: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_
	parent.add_child(l)
	return l

# ----------------------------------------------------------------------- build
static func build(level: Node3D, markers: Node3D, shots: Node3D) -> void:
	_materials()
	var fac := SceneUtil.add(level, Node3D.new(), "Facility")
	_corridor(fac)
	_atrium(fac)
	_control(fac)
	_markers(markers, shots)

# -------------------------------------------------------------------- corridor
static func _corridor(fac: Node3D) -> void:
	var c := SceneUtil.add(fac, Node3D.new(), "AquariumCorridor")
	var shell := CSGCombiner3D.new()
	shell.name = "Shell"
	shell.use_collision = true
	c.add_child(shell)
	var x0 := 17.0
	var x1 := 40.0
	var xc := (x0 + x1) * 0.5
	# Outer shell stops inside the atrium wall (x <= 39.6); inner cut runs through it.
	_box(shell, Vector3(39.6 - (x0 - 0.6), 6.2, 9.2), Vector3((39.6 + x0 - 0.6) * 0.5, F + 2.5, -88), metal)
	_box(shell, Vector3(40.2 - (x0 + 0.2), 5.0, 8.0), Vector3((40.2 + x0 + 0.2) * 0.5, F + 2.5, -88), metal_dark, CSGShape3D.OPERATION_SUBTRACTION)
	# West doorway (sealed until Phase 5 adds the ramp).
	var windows_x := [24.0, 30.0, 36.0]
	for wx in windows_x:
		for wz in [-83.7, -92.3]:
			if wx == 24.0 and wz < -90.0:
				continue  # garden door goes here (see garden.gd)
			_box(shell, Vector3(4.2, 2.8, 1.4), Vector3(wx, F + 2.6, wz), metal, CSGShape3D.OPERATION_SUBTRACTION)
	# Glass panes (collision so nobody walks into the sea).
	for wx in windows_x:
		for wz in [-83.9, -92.1]:
			if wx == 24.0 and wz < -90.0:
				continue
			var pane := SceneUtil.box_body(Vector3(4.2, 2.8, 0.06), Vector3(wx, F + 2.6, wz), glass, "Glass")
			c.add_child(pane)
			# Glowing frame.
			_strip(c, Vector3(4.4, 0.08, 0.12), Vector3(wx, F + 4.04, wz))
			_strip(c, Vector3(4.4, 0.08, 0.12), Vector3(wx, F + 1.16, wz))
	_hex_floor(c, Vector2(x1 - x0, 8.0), Vector3(xc, F, -88))
	# Trim lines along the floor and ceiling edges.
	for z in [-84.05, -91.95]:
		_strip(c, Vector3(x1 - x0, 0.06, 0.08), Vector3(xc, F + 0.05, z))
		_strip(c, Vector3(x1 - x0, 0.06, 0.08), Vector3(xc, F + 4.9, z))
	_strip(c, Vector3(x1 - x0, 0.04, 0.5), Vector3(xc, F + 4.97, -88))
	# Octagonal pools down the centre line.
	for i in 3:
		_pool(c, Vector3(25.0 + i * 5.5, F, -88))
	for x in [22.0, 30.0, 38.0]:
		_light(c, Vector3(x, F + 4.2, -88), Color(0.75, 0.9, 1.0), 1.2, 9.0)
	O._fog_volume(c, "CorridorHaze", Vector3(22, 5, 8), Vector3(28.5, F + 2.5, -88), 0.012, Color(0.7, 0.92, 1.0))
	# Ocean backdrops behind both window rows.
	# South box runs past the terrain edge (hidden behind the cliff from outdoors).
	_ocean(c, "OceanSouth", Vector3(34.0, F + 4, -111.0), Vector3(12, 22, 37))  # x 28..40, clear of the garden
	_ocean(c, "OceanNorth", Vector3(30.5, F + 4, -75.0), Vector3(19, 22, 17))

static func _pool(parent: Node3D, pos: Vector3) -> void:
	var p := Node3D.new()
	p.name = "OctPool"
	p.position = pos
	parent.add_child(p)
	var rim := CSGCombiner3D.new()
	rim.name = "Rim"
	rim.use_collision = true
	p.add_child(rim)
	_oct(rim, 1.75, 0.5, Vector3(0, 0.25, 0), metal)
	_oct(rim, 1.45, 0.6, Vector3(0, 0.4, 0), metal_dark, CSGShape3D.OPERATION_SUBTRACTION)
	var water := MeshInstance3D.new()
	water.name = "Water"
	var cm := CylinderMesh.new()
	cm.radial_segments = 8
	cm.top_radius = circumradius(1.45)
	cm.bottom_radius = cm.top_radius
	cm.height = 0.02
	cm.material = pool_mat
	water.mesh = cm
	water.rotation.y = PI / 8.0
	water.position.y = 0.35
	p.add_child(water)
	_strip(p, Vector3(0.08, 0.04, 2.4), Vector3(1.62, 0.52, 0))
	_strip(p, Vector3(0.08, 0.04, 2.4), Vector3(-1.62, 0.52, 0))
	_light(p, Vector3(0, 0.9, 0), Color(0.2, 0.85, 1.0), 1.5, 4.0)

static func _ocean(parent: Node3D, name: String, pos: Vector3, size: Vector3) -> void:
	var o := Node3D.new()
	o.name = name
	parent.add_child(o)
	var mi := MeshInstance3D.new()
	mi.name = "Backdrop"
	var bm := BoxMesh.new()
	bm.size = size
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/underwater.gdshader")
	m.set_shader_parameter("noise_tex", O.noise_tex)
	m.set_shader_parameter("top_y", pos.y + size.y * 0.5)
	m.set_shader_parameter("bottom_y", pos.y - size.y * 0.5)
	bm.material = m
	mi.mesh = bm
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o.add_child(mi)
	# Sea floor with rocks and weed, lit cold blue.
	var floor_y := F - 1.5
	var sand := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x, size.z)
	pm.material = SceneUtil.mat(Color(0.25, 0.45, 0.5), 1.0)
	sand.mesh = pm
	sand.position = Vector3(pos.x, floor_y, pos.z)
	o.add_child(sand)
	for i in int(size.z):
		var rp := Vector3(pos.x + O.rng.randf_range(-size.x * 0.45, size.x * 0.45), floor_y, pos.z + O.rng.randf_range(-size.z * 0.45, size.z * 0.45))
		O._kenney(o, ["rock_tallA", "rock_tallC", "rock_largeB", "plant_flatTall", "grass_leafsLarge"][O.rng.randi() % 5], rp, O.rng.randf_range(3, 7), false)
	O._fog_volume(o, "WaterHaze", size - Vector3(0.5, 0.5, 0.5), pos, 0.06, Color(0.2, 0.6, 0.9))
	var l := _light(o, Vector3(pos.x, pos.y + 4, pos.z), Color(0.3, 0.7, 1.0), 2.5, 30.0)
	l.shadow_enabled = false

# ---------------------------------------------------------------------- atrium
static func _atrium(fac: Node3D) -> void:
	var a := SceneUtil.add(fac, Node3D.new(), "Atrium")
	var shell := CSGCombiner3D.new()
	shell.name = "Shell"
	shell.use_collision = true
	a.add_child(shell)
	var h := 12.0
	_oct(shell, APOTHEM + WALL, h + 0.6, ATRIUM + Vector3(0, h * 0.5, 0), metal)
	_oct(shell, APOTHEM, h, ATRIUM + Vector3(0, h * 0.5, 0), metal_dark, CSGShape3D.OPERATION_SUBTRACTION)
	# West door (floor level, from the corridor), east door (ring level, to control).
	_box(shell, Vector3(2.4, 3.6, 4.0), Vector3(ATRIUM.x - APOTHEM - 0.4, F + 1.8, ATRIUM.z), metal, CSGShape3D.OPERATION_SUBTRACTION)
	_box(shell, Vector3(2.4, 3.2, 4.0), Vector3(ATRIUM.x + APOTHEM + 0.4, RING_Y + 1.6, ATRIUM.z), metal, CSGShape3D.OPERATION_SUBTRACTION)
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "HexFloor"
	var fm := CylinderMesh.new()
	fm.radial_segments = 8
	fm.top_radius = circumradius(APOTHEM)
	fm.bottom_radius = fm.top_radius
	fm.height = 0.02
	fm.material = hex_mat
	floor_mi.mesh = fm
	floor_mi.rotation.y = PI / 8.0
	floor_mi.position = ATRIUM + Vector3(0, 0.01, 0)
	a.add_child(floor_mi)

	# Ring walkway + inner railing (gap on the south side where the ramp arrives).
	var ring := CSGCombiner3D.new()
	ring.name = "RingWalkway"
	ring.use_collision = true
	a.add_child(ring)
	var ry := RING_Y - ATRIUM.y
	_oct(ring, APOTHEM + 0.1, 0.3, ATRIUM + Vector3(0, ry - 0.15, 0), metal)
	_oct(ring, RING_IN, 0.4, ATRIUM + Vector3(0, ry - 0.15, 0), metal, CSGShape3D.OPERATION_SUBTRACTION)
	_oct(ring, RING_IN + 0.15, 1.0, ATRIUM + Vector3(0, ry + 0.5, 0), metal_dark)
	_oct(ring, RING_IN, 1.2, ATRIUM + Vector3(0, ry + 0.5, 0), metal_dark, CSGShape3D.OPERATION_SUBTRACTION)
	_box(ring, Vector3(3.0, 1.4, 1.0), Vector3(ATRIUM.x + RAMP_X - 4.4, RING_Y + 0.5, ATRIUM.z + RING_IN), metal, CSGShape3D.OPERATION_SUBTRACTION)
	# Glowing edge on the ring.
	var glow_ring := CSGCombiner3D.new()
	glow_ring.name = "RingGlow"
	a.add_child(glow_ring)
	_oct(glow_ring, RING_IN + 0.17, 0.06, ATRIUM + Vector3(0, ry + 1.0, 0), trim)
	_oct(glow_ring, RING_IN - 0.02, 0.1, ATRIUM + Vector3(0, ry + 1.0, 0), trim, CSGShape3D.OPERATION_SUBTRACTION)
	_oct(glow_ring, APOTHEM - 0.02, 0.08, ATRIUM + Vector3(0, 0.05, 0), trim)
	_oct(glow_ring, APOTHEM - 0.14, 0.1, ATRIUM + Vector3(0, 0.05, 0), trim, CSGShape3D.OPERATION_SUBTRACTION)
	_oct(glow_ring, APOTHEM - 0.02, 0.08, ATRIUM + Vector3(0, h - 0.1, 0), trim)
	_oct(glow_ring, APOTHEM - 0.3, 0.1, ATRIUM + Vector3(0, h - 0.1, 0), trim, CSGShape3D.OPERATION_SUBTRACTION)

	# Ramp: inner south side, rising westward from the floor to the ring.
	var rise := RING_Y - F
	var run := 8.0
	var ang := atan2(rise, run)
	var slope_len := sqrt(rise * rise + run * run)
	var ramp_z := ATRIUM.z + RING_IN - 1.25
	var ramp := SceneUtil.box_body(Vector3(slope_len, 0.3, 2.5), Vector3(ATRIUM.x + RAMP_X, F + rise * 0.5 - 0.15 / cos(ang), ramp_z), metal, "Ramp")
	ramp.rotation.z = -ang
	a.add_child(ramp)
	# Flat landing at ring height so stepping off the ramp onto the ring is level.
	a.add_child(SceneUtil.box_body(Vector3(1.4, 0.3, 2.5), Vector3(ATRIUM.x + RAMP_X - 4.7, RING_Y - 0.15, ramp_z), metal, "Landing"))
	var rail := SceneUtil.box_body(Vector3(slope_len, 1.0, 0.15), Vector3(ATRIUM.x + RAMP_X, F + rise * 0.5 + 0.5, ramp_z - 1.2), metal_dark, "RampRail")
	rail.rotation.z = -ang
	a.add_child(rail)
	var rail_glow := _strip(a, Vector3(slope_len, 0.05, 0.18), Vector3(ATRIUM.x + RAMP_X, F + rise * 0.5 + 1.0, ramp_z - 1.2))
	rail_glow.rotation.z = -ang

	# Central water column.
	var col := Node3D.new()
	col.name = "WaterColumn"
	col.position = ATRIUM
	a.add_child(col)
	var cyl := MeshInstance3D.new()
	cyl.name = "Water"
	var cm := CylinderMesh.new()
	cm.top_radius = 2.3
	cm.bottom_radius = 2.3
	cm.height = h - 1.0
	cm.radial_segments = 32
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water_column.gdshader")
	wm.set_shader_parameter("noise_tex", O.noise_tex)
	cm.material = wm
	cyl.mesh = cm
	cyl.position.y = (h - 1.0) * 0.5 + 0.5
	cyl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	col.add_child(cyl)
	var glass_body := StaticBody3D.new()
	glass_body.name = "Glass"
	var gcs := CollisionShape3D.new()
	var gshape := CylinderShape3D.new()
	gshape.radius = 2.5
	gshape.height = h
	gcs.shape = gshape
	gcs.position.y = h * 0.5
	glass_body.add_child(gcs)
	col.add_child(glass_body)
	var caps := CSGCombiner3D.new()
	caps.name = "Caps"
	col.add_child(caps)
	_oct(caps, 3.0, 0.5, Vector3(0, 0.25, 0), metal)
	_oct(caps, 3.0, 0.8, Vector3(0, h - 0.4, 0), metal)
	_oct(caps, 3.1, 0.08, Vector3(0, 0.52, 0), trim)
	_oct(caps, 3.1, 0.08, Vector3(0, h - 0.82, 0), trim)
	var cl := _light(col, Vector3(0, 4, 0), Color(0.2, 0.8, 1.0), 4.0, 14.0)
	cl.shadow_enabled = false
	_light(a, ATRIUM + Vector3(0, h - 1.5, 0), Color(0.85, 0.95, 1.0), 2.0, 18.0)
	O._fog_volume(a, "AtriumHaze", Vector3(19, 11, 19), ATRIUM + Vector3(0, 6, 0), 0.02, Color(0.6, 0.9, 1.0))
	for i in 4:
		var ang2 := PI / 4.0 + i * PI / 2.0
		_light(a, ATRIUM + Vector3(cos(ang2) * 8.5, 3.0, sin(ang2) * 8.5), Color(0.4, 0.85, 1.0), 1.0, 7.0)

# --------------------------------------------------------------------- control
static func _control(fac: Node3D) -> void:
	var r := SceneUtil.add(fac, Node3D.new(), "ControlRoom")
	var x0 := ATRIUM.x + APOTHEM + WALL - 0.2
	var x1 := 74.0
	var xc := (x0 + x1) * 0.5
	var shell := CSGCombiner3D.new()
	shell.name = "Shell"
	shell.use_collision = true
	r.add_child(shell)
	_box(shell, Vector3(x1 - x0 + 0.6, 6.6, 9.2), Vector3(xc + 0.3, RING_Y + 3.0, -88), metal)
	_box(shell, Vector3(x1 - x0 + 0.2, 6.0, 8.0), Vector3(xc - 0.1, RING_Y + 3.0, -88), metal_dark, CSGShape3D.OPERATION_SUBTRACTION)
	_hex_floor(r, Vector2(x1 - x0, 8.0), Vector3(xc, RING_Y, -88))
	for z in [-84.05, -91.95]:
		_strip(r, Vector3(x1 - x0, 0.06, 0.08), Vector3(xc, RING_Y + 0.05, z))
		_strip(r, Vector3(x1 - x0, 0.06, 0.08), Vector3(xc, RING_Y + 5.9, z))
	# Consoles along both walls, facing the room centre.
	var i := 0
	for cx in [63.5, 67.0]:
		for side in [-1.0, 1.0]:
			_console(r, Vector3(cx, RING_Y, -88 + side * 3.0), side, i)
			i += 1
	# Teleporter pad at the far end; arrival point faces back into the room.
	var pad := O._pad(r, "TeleporterFacility", Vector3(71.2, RING_Y, -88))
	pad.rotation.y = -PI / 2.0
	pad.set_meta("zone", "facility")
	# Big holo display above the pad.
	var disp := MeshInstance3D.new()
	disp.name = "HoloDisplay"
	var q := QuadMesh.new()
	q.size = Vector2(6.0, 2.6)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/holo_screen.gdshader")
	sm.set_shader_parameter("seed", 3.0)
	q.material = sm
	disp.mesh = q
	disp.position = Vector3(x1 - 0.15, RING_Y + 3.6, -88)
	disp.rotation.y = -PI / 2.0
	r.add_child(disp)
	_light(r, Vector3(xc, RING_Y + 5.0, -88), Color(0.8, 0.92, 1.0), 1.6, 12.0)
	_light(r, Vector3(x1 - 1.5, RING_Y + 3.0, -88), Color(0.3, 0.9, 1.0), 2.0, 8.0)

static func _console(parent: Node3D, pos: Vector3, side: float, idx: int) -> void:
	var c := Node3D.new()
	c.name = "Console%d" % idx
	c.position = pos
	c.rotation.y = 0.0 if side < 0 else PI  # screens face the room centre line
	parent.add_child(c)
	var body := SceneUtil.box_body(Vector3(2.4, 1.0, 0.9), Vector3(0, 0.5, 0), metal, "Desk")
	c.add_child(body)
	var top := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.4, 0.08, 1.0)
	bm.material = metal_dark
	top.mesh = bm
	top.position = Vector3(0, 1.02, 0.05)
	top.rotation.x = deg_to_rad(-15)
	c.add_child(top)
	var screen := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 0.9)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/holo_screen.gdshader")
	sm.set_shader_parameter("seed", float(idx))
	q.material = sm
	screen.mesh = q
	screen.position = Vector3(0, 1.75, -0.2)
	screen.rotation.x = deg_to_rad(-12)
	c.add_child(screen)
	_strip(c, Vector3(2.4, 0.05, 0.05), Vector3(0, 0.05, 0.46))

# --------------------------------------------------------------------- markers
static func _markers(markers: Node3D, shots: Node3D) -> void:
	var ring_mid := (APOTHEM + RING_IN) * 0.5
	var zones := {
		"Zone_Vestibule": Vector3(18.5, F, -88),
		"Zone_Corridor": Vector3(21.5, F, -85.6),  # side walkway, clear of the pools
		"Zone_CorridorEnd": Vector3(38.8, F, -85.6),
		"Zone_Atrium": Vector3(43, F, -88),
		"Zone_RampBottom": Vector3(ATRIUM.x + RAMP_X + 4.8, F, ATRIUM.z + RING_IN - 1.25),
		"Zone_RampTop": Vector3(ATRIUM.x + RAMP_X - 4.6, RING_Y, ATRIUM.z + RING_IN - 1.25),
		"Zone_AtriumRing": Vector3(ATRIUM.x + RAMP_X - 4.4, RING_Y, ATRIUM.z + ring_mid),
		"Zone_RingSE": Vector3(ATRIUM.x + ring_mid * 0.7, RING_Y, ATRIUM.z + ring_mid * 0.7),
		"Zone_RingEast": Vector3(ATRIUM.x + ring_mid, RING_Y, ATRIUM.z),
		"Zone_Control": Vector3(66.0, RING_Y, -88),
	}
	for n in zones:
		SceneUtil.marker(markers, n, zones[n] + Vector3(0, 0.05, 0))
	for cp_name in ["CP_Facility", "CP_Control"]:
		var p: Vector3 = zones["Zone_Corridor" if cp_name == "CP_Facility" else "Zone_Control"]
		var m := SceneUtil.marker(markers, cp_name, p + Vector3(0, 0.1, 0))
		m.rotation.y = -PI / 2.0  # face east, deeper into the facility
		m.add_to_group("checkpoint", true)
	var s1 := SceneUtil.marker(shots, "Shot_Corridor", Vector3(19.5, F + 2.4, -86.2), Vector3(34, F + 1.2, -88.5))
	s1.set_meta("player_pos", Vector3(23.5, F + 0.05, -86.0))
	var s2 := SceneUtil.marker(shots, "Shot_Atrium", Vector3(42.5, F + 2.0, -85.0), Vector3(52, F + 5.0, -89))
	s2.set_meta("player_pos", Vector3(45.0, F + 0.05, -86.5))
	var s3 := SceneUtil.marker(shots, "Shot_Control", Vector3(62.0, RING_Y + 2.4, -86.5), Vector3(72, RING_Y + 1.2, -88.5))
	s3.set_meta("player_pos", Vector3(65.5, RING_Y + 0.05, -87.0))

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
static var trim_soft: StandardMaterial3D
static var trim_violet: StandardMaterial3D
static var grate_mat: ShaderMaterial
static var pool_mat: StandardMaterial3D

static func _materials() -> void:
	metal = ShaderMaterial.new()
	metal.shader = load("res://shaders/facility_metal.gdshader")
	metal.set_shader_parameter("noise_tex", O.noise_tex)
	# Lighter blue-grey panelling like the video (f11-23).
	metal.set_shader_parameter("base_color", Color(0.55, 0.62, 0.72))
	metal.set_shader_parameter("groove_color", Color(0.2, 0.24, 0.3))
	metal_dark = metal.duplicate()
	metal_dark.set_shader_parameter("base_color", Color(0.36, 0.42, 0.52))
	metal_dark.set_shader_parameter("panel_size", Vector2(1.0, 0.5))
	hex_mat = ShaderMaterial.new()
	hex_mat.shader = load("res://shaders/hex_floor.gdshader")
	glass = StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.55, 0.85, 1.0, 0.12)
	glass.roughness = 0.03
	glass.metallic_specular = 0.9
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	trim = SceneUtil.mat(Color(0.2, 0.95, 1.0), 0.2, 0.0, Color(0.2, 0.95, 1.0), 3.5)
	trim_soft = SceneUtil.mat(Color(0.2, 0.85, 1.0), 0.2, 0.0, Color(0.2, 0.85, 1.0), 2.2)
	trim_violet = SceneUtil.mat(Color(0.55, 0.4, 1.0), 0.2, 0.0, Color(0.5, 0.35, 1.0), 2.6)
	grate_mat = ShaderMaterial.new()
	grate_mat.shader = load("res://shaders/grate.gdshader")
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
	_strip(c, Vector3(x1 - x0, 0.04, 0.3), Vector3(xc, F + 4.97, -88), trim_soft)
	# Octagonal arch frames with cyan/violet light strips (video f11-13).
	for i in 4:
		_arch_frame(c, [21.0, 27.0, 33.0, 38.6][i], trim if i % 2 == 0 else trim_violet)
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

## A chamfered octagonal frame standing proud of the corridor walls/ceiling at x.
static func _arch_frame(parent: Node3D, x: float, strip_mat: Material) -> void:
	var fr := CSGCombiner3D.new()
	fr.name = "ArchFrame"
	fr.use_collision = true
	parent.add_child(fr)
	var sub := CSGShape3D.OPERATION_SUBTRACTION
	_box(fr, Vector3(0.55, 5.0, 8.0), Vector3(x, F + 2.5, -88), metal)
	_oct_x(fr, x, 0.8, 4.4, 7.2, metal_dark, sub)
	_box(fr, Vector3(0.8, 1.6, 7.2), Vector3(x, F + 0.8, -88), metal_dark, sub)  # no sill across the floor
	var glow := CSGCombiner3D.new()
	glow.name = "ArchGlow"
	parent.add_child(glow)
	_oct_x(glow, x - 0.29, 0.06, 4.55, 7.35, strip_mat)
	_oct_x(glow, x - 0.29, 0.1, 4.3, 7.1, strip_mat, sub)
	_box(glow, Vector3(0.2, 1.4, 7.6), Vector3(x - 0.29, F + 0.7, -88), strip_mat, sub)
	_oct_x(glow, x + 0.29, 0.06, 4.55, 7.35, strip_mat)
	_oct_x(glow, x + 0.29, 0.1, 4.3, 7.1, strip_mat, sub)
	_box(glow, Vector3(0.2, 1.4, 7.6), Vector3(x + 0.29, F + 0.7, -88), strip_mat, sub)

## Octagonal prism along X, flat sides up/down/left/right, sized to height h x width w.
static func _oct_x(parent: Node, x: float, thickness: float, h: float, w: float, mat: Material, op := CSGShape3D.OPERATION_UNION) -> void:
	var c := CSGCylinder3D.new()
	c.sides = 8
	c.radius = 1.0
	c.height = thickness
	c.operation = op
	c.material = mat
	var ap := cos(PI / 8.0)
	var b := Basis(Vector3(0, 0, 1), PI / 2.0) * Basis.from_scale(Vector3(h * 0.5 / ap, 1.0, w * 0.5 / ap)) * Basis(Vector3.UP, PI / 8.0)
	c.transform = Transform3D(b, Vector3(x, F + h * 0.5 + 0.05, -88))
	parent.add_child(c)

static func _pool(parent: Node3D, pos: Vector3) -> void:
	var p := Node3D.new()
	p.name = "OctPool"
	p.position = pos
	parent.add_child(p)
	var rim := CSGCombiner3D.new()
	rim.name = "Rim"
	rim.use_collision = true
	p.add_child(rim)
	# Low flush rim like the video's sunken pools (f12): water sits just under the lip.
	_oct(rim, 1.9, 0.2, Vector3(0, 0.1, 0), metal)
	_oct(rim, 1.5, 0.3, Vector3(0, 0.2, 0), metal_dark, CSGShape3D.OPERATION_SUBTRACTION)
	var bed := MeshInstance3D.new()
	bed.name = "Bed"
	var bm := CylinderMesh.new()
	bm.radial_segments = 8
	bm.top_radius = circumradius(1.5)
	bm.bottom_radius = bm.top_radius
	bm.height = 0.02
	bm.material = pool_mat
	bed.mesh = bm
	bed.rotation.y = PI / 8.0
	bed.position.y = 0.02
	p.add_child(bed)
	var water := MeshInstance3D.new()
	water.name = "Water"
	var wm := PlaneMesh.new()
	wm.size = Vector2(3.0, 3.0)
	var wmat: ShaderMaterial = O.water_mat.duplicate()
	wmat.set_shader_parameter("shallow_color", Color(0.3, 0.95, 1.0))
	wmat.set_shader_parameter("depth_scale", 0.6)
	wmat.set_shader_parameter("foam_distance", 0.0)
	wm.material = wmat
	water.mesh = wm
	water.position.y = 0.14
	p.add_child(water)
	var glow := CSGCombiner3D.new()
	p.add_child(glow)
	_oct(glow, 1.62, 0.04, Vector3(0, 0.21, 0), trim_soft)
	_oct(glow, 1.52, 0.08, Vector3(0, 0.21, 0), trim_soft, CSGShape3D.OPERATION_SUBTRACTION)
	_light(p, Vector3(0, 0.9, 0), Color(0.2, 0.85, 1.0), 1.5, 4.0)

static func _ocean(parent: Node3D, name: String, pos: Vector3, size: Vector3) -> void:
	LevelOcean.build(parent, name, pos, size, {"floor_y": F + 0.5, "fish": 2, "kelp": int(size.x * 1.2), "coral": int(size.x * 0.5), "rocks": int(size.z * 0.4)})

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
	# Kick plate only; the railing itself is tubes (see _ring_rails).
	_oct(ring, RING_IN + 0.15, 0.25, ATRIUM + Vector3(0, ry + 0.125, 0), metal_dark)
	_oct(ring, RING_IN, 0.4, ATRIUM + Vector3(0, ry + 0.125, 0), metal_dark, CSGShape3D.OPERATION_SUBTRACTION)
	_box(ring, Vector3(3.0, 1.4, 1.0), Vector3(ATRIUM.x + RAMP_X - 4.4, RING_Y + 0.5, ATRIUM.z + RING_IN), metal, CSGShape3D.OPERATION_SUBTRACTION)
	# Glowing edge on the ring.
	var glow_ring := CSGCombiner3D.new()
	glow_ring.name = "RingGlow"
	a.add_child(glow_ring)
	_oct(glow_ring, APOTHEM - 0.02, 0.08, ATRIUM + Vector3(0, 0.05, 0), trim)
	_oct(glow_ring, APOTHEM - 0.14, 0.1, ATRIUM + Vector3(0, 0.05, 0), trim, CSGShape3D.OPERATION_SUBTRACTION)
	_oct(glow_ring, APOTHEM - 0.02, 0.08, ATRIUM + Vector3(0, h - 0.1, 0), trim)
	_oct(glow_ring, APOTHEM - 0.3, 0.1, ATRIUM + Vector3(0, h - 0.1, 0), trim, CSGShape3D.OPERATION_SUBTRACTION)

	_ring_rails(a)
	_portholes(a, shell)
	_glass_ceiling(a, shell, h)

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
	var fs := MultiMeshInstance3D.new()
	fs.name = "ColumnFish"
	fs.set_script(load("res://scripts/fish_school.gd"))
	fs.position = Vector3(0, (h - 1.0) * 0.5 + 0.5, 0)
	fs.set("count", 14)
	fs.set("ring_radius", 1.3)
	fs.set("extents", Vector3(1.4, 3.5, 1.4))
	fs.set("fish_length", 0.42)
	fs.set("spread", 0.6)
	fs.set("speed", 0.08)
	fs.set("colors", PackedColorArray([Color(1.0, 0.8, 0.2), Color(1.0, 0.5, 0.15)]))
	col.add_child(fs)
	var cl := _light(col, Vector3(0, 4, 0), Color(0.2, 0.8, 1.0), 4.0, 14.0)
	cl.shadow_enabled = false
	_light(a, ATRIUM + Vector3(0, h - 1.5, 0), Color(0.85, 0.95, 1.0), 2.0, 18.0)
	O._fog_volume(a, "AtriumHaze", Vector3(19, 11, 19), ATRIUM + Vector3(0, 6, 0), 0.02, Color(0.6, 0.9, 1.0))
	for i in 4:
		var ang2 := PI / 4.0 + i * PI / 2.0
		_light(a, ATRIUM + Vector3(cos(ang2) * 8.5, 3.0, sin(ang2) * 8.5), Color(0.4, 0.85, 1.0), 1.0, 7.0)

## Porthole faces (octagon face angles; E = control door, W = corridor door).
const PORTHOLE_FACES := [45.0, 90.0, 135.0, 225.0, 270.0, 315.0]
const WIDE := 1.35  # portholes are wide octagons (rounded-rect feel, like the video)

static func _face_n(deg: float) -> Vector3:
	return Vector3(cos(deg_to_rad(deg)), 0, sin(deg_to_rad(deg)))

static func _corner(apothem: float, deg: float) -> Vector3:
	var r := apothem / cos(PI / 8.0)
	return ATRIUM + Vector3(cos(deg_to_rad(deg)) * r, 0, sin(deg_to_rad(deg)) * r)

static func _ring_rails(a: Node3D) -> void:
	var rails := SceneUtil.add(a, Node3D.new(), "RingRails")
	var ap := RING_IN + 0.07
	for i in 8:
		var deg := i * 45.0
		var p0 := _corner(ap, deg - 22.5)
		var p1 := _corner(ap, deg + 22.5)
		# Opening where the ramp landing meets the ring (south, x 46.1..49.1).
		if is_equal_approx(deg, 90.0):
			p1 = p1.lerp(p0, (49.1 - p1.x) / (p0.x - p1.x))
		elif is_equal_approx(deg, 135.0):
			p0 = p0.lerp(p1, 0.25)
		_rail_segment(rails, p0 + Vector3(0, RING_Y, 0), p1 + Vector3(0, RING_Y, 0), i)

static func _rail_segment(parent: Node3D, p0: Vector3, p1: Vector3, idx: int) -> void:
	var d := (p1 - p0)
	var length := d.length()
	d = d / length
	var piv := StaticBody3D.new()
	piv.name = "Rail%d" % idx
	piv.transform = Transform3D(Basis(d, Vector3.UP, d.cross(Vector3.UP)), (p0 + p1) * 0.5)
	parent.add_child(piv)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(length, 1.1, 0.12)
	cs.shape = bs
	cs.position.y = 0.55
	piv.add_child(cs)
	for spec in [[1.0, 0.07, metal], [0.55, 0.045, metal], [1.0, 0.055, trim_soft]]:
		var t := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = spec[1]
		cm.bottom_radius = spec[1]
		cm.height = length + 0.1
		cm.radial_segments = 10
		cm.rings = 1
		cm.material = spec[2]
		t.mesh = cm
		t.rotation.z = PI / 2.0
		t.position = Vector3(0, spec[0] + (0.1 if spec[2] == trim_soft else 0.0), 0)
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piv.add_child(t)
	for px in [-length * 0.5, length * 0.5]:
		var post := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.05
		pc.bottom_radius = 0.06
		pc.height = 1.0
		pc.radial_segments = 8
		pc.material = metal
		post.mesh = pc
		post.position = Vector3(px, 0.5, 0)
		piv.add_child(post)

static func _portholes(a: Node3D, shell: CSGCombiner3D) -> void:
	var g := SceneUtil.add(a, Node3D.new(), "Portholes")
	var k := 0
	for deg in PORTHOLE_FACES:
		var n := _face_n(deg)
		var yaw := atan2(n.x, n.z)
		for row in [[RING_Y + 3.0, 1.45], [F + 1.6, 0.95]]:
			var y: float = row[0]
			var r: float = row[1]
			var cut := CSGCylinder3D.new()
			cut.sides = 8
			cut.radius = r
			cut.height = 2.2
			cut.operation = CSGShape3D.OPERATION_SUBTRACTION
			cut.material = metal
			cut.position = ATRIUM + n * (APOTHEM + WALL * 0.5) + Vector3(0, y - F, 0)
			cut.rotation = Vector3(PI / 2.0, yaw, 0)
			cut.scale = Vector3(WIDE, 1, 1)
			shell.add_child(cut)
			var frame := CSGCombiner3D.new()
			frame.name = "Frame%d" % k
			g.add_child(frame)
			var fo := CSGCylinder3D.new()
			fo.sides = 8
			fo.radius = r + 0.1
			fo.height = 0.08
			fo.material = trim_soft
			frame.add_child(fo)
			var fi := CSGCylinder3D.new()
			fi.sides = 8
			fi.radius = r
			fi.height = 0.2
			fi.operation = CSGShape3D.OPERATION_SUBTRACTION
			frame.add_child(fi)
			frame.position = ATRIUM + n * (APOTHEM - 0.03) + Vector3(0, y - F, 0)
			frame.rotation = Vector3(PI / 2.0, yaw, 0)
			frame.scale = Vector3(WIDE, 1, 1)
			var gl := StaticBody3D.new()
			gl.name = "PortholeGlass%d" % k
			gl.position = ATRIUM + n * (APOTHEM + 0.3) + Vector3(0, y - F, 0)
			gl.rotation.y = yaw
			var gm := MeshInstance3D.new()
			var gq := QuadMesh.new()
			gq.size = Vector2(r * 2.0 * WIDE, r * 2.0)
			gq.material = glass
			gm.mesh = gq
			gl.add_child(gm)
			var gcs := CollisionShape3D.new()
			var gb := BoxShape3D.new()
			gb.size = Vector3(r * 2.0 * WIDE, r * 2.0, 0.1)
			gcs.shape = gb
			gl.add_child(gcs)
			g.add_child(gl)
			k += 1
		# Ocean niche behind both portholes on this face.
		LevelOcean.build(a, "OceanPort%d" % int(deg), ATRIUM + n * (APOTHEM + WALL + 4.5) + Vector3(0, 6.0, 0), Vector3(7, 14, 9),
			{"yaw": yaw, "floor_y": F + 0.4, "fish": 1, "fish_count": 8, "kelp": 8, "coral": 3, "rocks": 2, "haze": false})

static func _glass_ceiling(a: Node3D, shell: CSGCombiner3D, h: float) -> void:
	var sub := CSGShape3D.OPERATION_SUBTRACTION
	_oct(shell, 6.5, 1.2, ATRIUM + Vector3(0, h + 0.2, 0), metal, sub)
	var cg := CSGCombiner3D.new()
	cg.name = "CeilingGlass"
	cg.use_collision = true
	a.add_child(cg)
	_oct(cg, 6.5, 0.05, ATRIUM + Vector3(0, h + 0.15, 0), glass)
	var hole := CSGCylinder3D.new()
	hole.radius = 2.9
	hole.height = 0.3
	hole.sides = 16
	hole.operation = sub
	hole.position = ATRIUM + Vector3(0, h + 0.15, 0)
	cg.add_child(hole)
	var fr := CSGCombiner3D.new()
	fr.name = "CeilingFrame"
	a.add_child(fr)
	_oct(fr, 6.7, 0.1, ATRIUM + Vector3(0, h - 0.02, 0), trim)
	_oct(fr, 6.45, 0.2, ATRIUM + Vector3(0, h - 0.02, 0), trim, sub)
	for i in 8:
		var rib := _strip(a, Vector3(3.7, 0.15, 0.15), ATRIUM + _face_n(i * 45.0 + 22.5) * 4.7 + Vector3(0, h + 0.05, 0), metal)
		rib.rotation.y = -deg_to_rad(i * 45.0 + 22.5)
	LevelOcean.build(a, "OceanAbove", ATRIUM + Vector3(0, h + 5.2, 0), Vector3(17, 10, 17),
		{"floor_y": null, "fish": 1, "fish_count": 12, "kelp": 0, "coral": 0, "rocks": 0, "haze": false})

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
	# Full-width glass panorama on the east wall onto the open ocean (video f20-23).
	_box(shell, Vector3(1.4, 5.2, 7.6), Vector3(x1, RING_Y + 2.9, -88), metal, CSGShape3D.OPERATION_SUBTRACTION)
	r.add_child(SceneUtil.box_body(Vector3(0.08, 5.2, 7.6), Vector3(x1 + 0.1, RING_Y + 2.9, -88), glass, "Panorama"))
	for y in [RING_Y + 0.3, RING_Y + 5.5]:
		_strip(r, Vector3(0.15, 0.1, 7.8), Vector3(x1 + 0.05, y, -88))
	for z in [-91.85, -84.15]:
		_strip(r, Vector3(0.15, 5.3, 0.1), Vector3(x1 + 0.05, RING_Y + 2.9, z))
	LevelOcean.build(r, "OceanEast", Vector3(87.5, RING_Y + 3.0, -88), Vector3(26, 16, 34), {"floor_y": RING_Y - 0.3, "fish": 3, "kelp": 40, "coral": 24, "rocks": 10})
	# Row of consoles facing the room, glass beyond (operators' view).
	var i := 0
	for cz in [-91.0, -89.5, -88.0, -86.5, -85.0]:
		_console(r, Vector3(71.6, RING_Y, cz), -PI / 2.0, i)
		i += 1
	# Floor grates either side of the pad (video f20-23).
	for gx in [62.6, 70.0]:
		var gm := MeshInstance3D.new()
		gm.name = "Grate"
		var gp := PlaneMesh.new()
		gp.size = Vector2(2.0, 5.2)
		gp.material = grate_mat
		gm.mesh = gp
		gm.position = Vector3(gx, RING_Y + 0.015, -88)
		r.add_child(gm)
	# Teleporter pad in the middle of the room; arrival point faces back west.
	var pad := O._pad(r, "TeleporterFacility", Vector3(66.8, RING_Y, -88))
	pad.rotation.y = -PI / 2.0
	pad.set_meta("zone", "facility")
	# Small holo display on the north wall.
	var disp := MeshInstance3D.new()
	disp.name = "HoloDisplay"
	var q := QuadMesh.new()
	q.size = Vector2(4.0, 1.8)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/holo_screen.gdshader")
	sm.set_shader_parameter("seed", 3.0)
	q.material = sm
	disp.mesh = q
	disp.position = Vector3(66.8, RING_Y + 3.4, -84.1)
	disp.rotation.y = PI
	r.add_child(disp)
	_light(r, Vector3(xc, RING_Y + 5.0, -88), Color(0.8, 0.92, 1.0), 1.4, 12.0)
	_light(r, Vector3(x1 - 1.5, RING_Y + 3.0, -88), Color(0.3, 0.75, 1.0), 2.0, 9.0)

## Rounded console pod (video f20-23): cylindrical pedestal, angled top, holo screen.
static func _console(parent: Node3D, pos: Vector3, yaw: float, idx: int) -> void:
	var c := StaticBody3D.new()
	c.name = "Console%d" % idx
	c.position = pos
	c.rotation.y = yaw  # local +Z (screen side) points along yaw
	parent.add_child(c)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.55
	cyl.height = 1.1
	cs.shape = cyl
	cs.position.y = 0.55
	c.add_child(cs)
	var ped := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.42
	pm.bottom_radius = 0.55
	pm.height = 0.95
	pm.radial_segments = 16
	pm.material = metal
	ped.mesh = pm
	ped.position.y = 0.475
	c.add_child(ped)
	var top := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.5
	tm.bottom_radius = 0.5
	tm.height = 0.1
	tm.radial_segments = 16
	tm.material = metal_dark
	top.mesh = tm
	top.position = Vector3(0, 1.0, 0.0)
	top.rotation.x = deg_to_rad(-22)
	c.add_child(top)
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.5
	rm.outer_radius = 0.56
	rm.rings = 24
	rm.ring_segments = 6
	rm.material = trim_soft
	ring.mesh = rm
	ring.position.y = 0.08
	c.add_child(ring)
	var screen := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.45)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/holo_screen.gdshader")
	sm.set_shader_parameter("seed", float(idx))
	sm.set_shader_parameter("intensity", 0.9)
	q.material = sm
	screen.mesh = q
	screen.position = Vector3(0, 1.33, -0.12)
	screen.rotation.x = deg_to_rad(-30)
	c.add_child(screen)

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
		"Zone_Control": Vector3(63.2, RING_Y, -86.0),
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
	var s3 := SceneUtil.marker(shots, "Shot_Control", Vector3(62.0, RING_Y + 2.4, -86.0), Vector3(78, RING_Y + 1.5, -88.5))
	s3.set_meta("player_pos", Vector3(69.0, RING_Y + 0.05, -86.0))

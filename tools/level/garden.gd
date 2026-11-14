class_name LevelGarden
## Indoor garden room (video frames 07–10): a mossy tree grows inside the
## facility, two waterfalls pour from a hexagonal glass skylight (sea above)
## into a glowing octagonal pool, ferns everywhere, light shafts.
##
##   Interior x 13..27, z -93.2..-107, floor F, ceiling F + 8 (y = 2).
##   Entered from the tunnel bottom (NW corner, x 13.4..17); exits north into the
##   aquarium corridor through a door at x 21..24.

const O := preload("res://tools/level/outdoor.gd")
const FAC := preload("res://tools/level/facility.gd")
const X0 := 13.0
const X1 := 27.0
const Z0 := -93.2
const Z1 := -107.0
const H := 8.0
const POOL := Vector3(20.5, 0, -100.8)
const POOL_APOTHEM := 3.4
const EXIT_X := 22.5
const TREE_GLB := "res://assets/props/garden_tree.glb"
const GEN := "res://scenes/generated"

static func build(level: Node3D, markers: Node3D, shots: Node3D) -> void:
	var F := FAC.F
	var g := SceneUtil.add(level, Node3D.new(), "Garden")
	var xc := (X0 + X1) * 0.5
	var zc := (Z0 + Z1) * 0.5
	var w := X1 - X0
	var d := Z0 - Z1
	var sub := CSGShape3D.OPERATION_SUBTRACTION

	var shell := CSGCombiner3D.new()
	shell.name = "Shell"
	shell.use_collision = true
	g.add_child(shell)
	FAC._box(shell, Vector3(w + 1.2, H + 1.2, d + 1.2), Vector3(xc, F + H * 0.5, zc), FAC.metal)
	FAC._box(shell, Vector3(w, H, d), Vector3(xc, F + H * 0.5, zc), FAC.metal_dark, sub)
	# Tunnel mouth (NW) and corridor door (N).
	FAC._box(shell, Vector3(3.6, 3.4, 2.0), Vector3(15.2, F + 1.7, Z0 + 0.4), FAC.metal_dark, sub)
	FAC._box(shell, Vector3(3.0, 3.2, 2.2), Vector3(EXIT_X, F + 1.6, Z0 + 0.4), FAC.metal_dark, sub)
	# Matching door through the corridor's south wall.
	var corridor_shell: CSGCombiner3D = level.get_node("Facility/AquariumCorridor/Shell")
	FAC._box(corridor_shell, Vector3(3.0, 3.2, 1.6), Vector3(EXIT_X, F + 1.6, -92.3), FAC.metal_dark, sub)
	# Hexagonal skylight above the pool.
	var hexcut := CSGCylinder3D.new()
	hexcut.sides = 6
	hexcut.radius = 3.3
	hexcut.height = 3.0
	hexcut.operation = sub
	hexcut.material = FAC.metal_dark
	hexcut.position = Vector3(POOL.x, F + H + 0.5, POOL.z)
	shell.add_child(hexcut)
	# Hex lattice ribs across the skylight, glass, and the sea above it.
	var sky := SceneUtil.add(g, Node3D.new(), "Skylight")
	for i in 3:
		var rib := FAC._strip(sky, Vector3(6.6, 0.18, 0.18), Vector3(POOL.x, F + H + 0.05, POOL.z), FAC.metal)
		rib.rotation.y = i * PI / 3.0
	var hexring := CSGCombiner3D.new()
	sky.add_child(hexring)
	var hr := CSGCylinder3D.new()
	hr.sides = 6
	hr.radius = 3.45
	hr.height = 0.12
	hr.material = FAC.trim
	hexring.add_child(hr)
	var hr2 := CSGCylinder3D.new()
	hr2.sides = 6
	hr2.radius = 3.25
	hr2.height = 0.2
	hr2.operation = sub
	hexring.add_child(hr2)
	hexring.position = Vector3(POOL.x, F + H - 0.05, POOL.z)
	var pane := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.radial_segments = 6
	pm.rings = 1
	pm.top_radius = 3.3
	pm.bottom_radius = 3.3
	pm.height = 0.04
	pm.material = FAC.glass
	pane.mesh = pm
	pane.position = Vector3(POOL.x, F + H + 0.2, POOL.z)
	sky.add_child(pane)
	var sea := MeshInstance3D.new()
	sea.name = "SeaAbove"
	var bm := BoxMesh.new()
	bm.size = Vector3(9, 10, 9)
	var um := ShaderMaterial.new()
	um.shader = load("res://shaders/underwater.gdshader")
	um.set_shader_parameter("noise_tex", O.noise_tex)
	um.set_shader_parameter("top_y", F + H + 10.0)
	um.set_shader_parameter("bottom_y", F + H - 6.0)
	um.set_shader_parameter("shallow_color", Color(0.2, 0.75, 0.95))
	bm.material = um
	sea.mesh = bm
	sea.position = Vector3(POOL.x, F + H + 5.2, POOL.z)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.add_child(sea)

	# Floor: hex tiles with a mossy planting bed around the tree.
	FAC._hex_floor(g, Vector2(w, d), Vector3(xc, F, zc))
	var bed := MeshInstance3D.new()
	var bedm := CylinderMesh.new()
	bedm.top_radius = 3.6
	bedm.bottom_radius = 3.9
	bedm.height = 0.18
	bedm.radial_segments = 10
	var moss := O.rock_mat.duplicate()
	moss.set_shader_parameter("moss_amount", 0.95)
	bedm.material = moss
	bed.mesh = bedm
	bed.position = Vector3(15.4, F + 0.05, -100.2)
	g.add_child(bed)

	# Octagonal pool with glowing rim, and twin waterfalls from the skylight.
	var pool := Node3D.new()
	pool.name = "OctPool"
	pool.position = Vector3(POOL.x, F, POOL.z)
	g.add_child(pool)
	var rim := CSGCombiner3D.new()
	rim.name = "Rim"
	rim.use_collision = true
	pool.add_child(rim)
	FAC._oct(rim, POOL_APOTHEM, 0.55, Vector3(0, 0.275, 0), FAC.metal)
	FAC._oct(rim, POOL_APOTHEM - 0.35, 0.7, Vector3(0, 0.45, 0), FAC.metal_dark, sub)
	var glow := CSGCombiner3D.new()
	pool.add_child(glow)
	FAC._oct(glow, POOL_APOTHEM + 0.02, 0.06, Vector3(0, 0.56, 0), FAC.trim)
	FAC._oct(glow, POOL_APOTHEM - 0.12, 0.1, Vector3(0, 0.56, 0), FAC.trim, sub)
	var water := MeshInstance3D.new()
	water.name = "Water"
	var wm := PlaneMesh.new()
	wm.size = Vector2(POOL_APOTHEM * 2.0, POOL_APOTHEM * 2.0)
	wm.material = O.water_mat
	water.mesh = wm
	water.position.y = 0.4
	pool.add_child(water)
	var glowfloor := MeshInstance3D.new()
	var gf := CylinderMesh.new()
	gf.radial_segments = 8
	gf.top_radius = FAC.circumradius(POOL_APOTHEM - 0.35)
	gf.bottom_radius = gf.top_radius
	gf.height = 0.02
	gf.material = FAC.pool_mat
	glowfloor.mesh = gf
	glowfloor.rotation.y = PI / 8.0
	glowfloor.position.y = 0.06
	pool.add_child(glowfloor)
	FAC._light(pool, Vector3(0, 1.0, 0), Color(0.2, 0.85, 1.0), 2.5, 7.0)
	for fx in [-0.75, 0.75]:
		O._fall(g, "FallL" if fx < 0 else "FallR", Vector3(POOL.x + fx, F + H + 0.2, POOL.z - 0.4), Vector3(POOL.x + fx, F + 0.45, POOL.z - 0.4), 0.9)
	O._mist(g, "PoolMist", Vector3(POOL.x, F + 0.6, POOL.z - 0.4), 2.0)

	# The tree: leaning over the pool from the south-west.
	_tree(g, Vector3(15.4, F + 0.1, -100.2), 0.95)

	# Ferns, bushes and mossy rocks (clear of the walk strip z > -96.5 and the pool).
	for i in 60:
		var p := Vector2(O.rng.randf_range(X0 + 0.6, X1 - 0.6), O.rng.randf_range(Z1 + 0.6, -96.8))
		if p.distance_to(Vector2(POOL.x, POOL.z)) < POOL_APOTHEM + 0.9:
			continue
		O._kenney(g, ["plant_bushDetailed", "plant_flatTall", "grass_leafsLarge", "plant_bushLarge", "grass_large"][O.rng.randi() % 5], Vector3(p.x, F, p.y), O.rng.randf_range(3.0, 5.5), false)
	for r in [Vector3(25.5, F, -105.5), Vector3(14.2, F, -105.8), Vector3(25.8, F, -98.0)]:
		O._kenney(g, ["rock_largeD", "rock_tallA", "rock_largeF"][O.rng.randi() % 3], r, O.rng.randf_range(2.0, 3.0), false)

	# Light: shafts through the skylight + green-tinted fill + haze.
	var shaft := SpotLight3D.new()
	shaft.name = "SkylightShaft"
	shaft.position = Vector3(POOL.x - 1.5, F + H + 3.0, POOL.z + 1.0)
	shaft.rotation_degrees = Vector3(-75, -20, 0)
	shaft.spot_range = 16
	shaft.spot_angle = 26
	shaft.light_energy = 9
	shaft.light_volumetric_fog_energy = 4.0
	shaft.light_color = Color(0.75, 0.95, 1.0)
	shaft.shadow_enabled = true
	g.add_child(shaft)
	FAC._light(g, Vector3(xc, F + H - 1.0, zc), Color(0.8, 1.0, 0.85), 2.0, 16.0)
	FAC._light(g, Vector3(15, F + 3, -96), Color(0.5, 0.9, 1.0), 1.0, 8.0)
	O._fog_volume(g, "GardenHaze", Vector3(w - 0.4, H - 0.2, d - 0.4), Vector3(xc, F + H * 0.5, zc), 0.025, Color(0.75, 0.95, 1.0))
	# Wall trim and ceiling light bars like the video.
	for z in [Z0 - 0.05, Z1 + 0.05]:
		FAC._strip(g, Vector3(w, 0.06, 0.08), Vector3(xc, F + 0.05, z))
	for x in [X0 + 0.05, X1 - 0.05]:
		FAC._strip(g, Vector3(0.08, 0.06, d), Vector3(x, F + 0.05, zc))
	for bar in [Vector3(15.5, F + H - 0.05, -96), Vector3(25.5, F + H - 0.05, -96), Vector3(15.5, F + H - 0.05, -105), Vector3(25.5, F + H - 0.05, -105)]:
		FAC._strip(g, Vector3(1.6, 0.06, 0.3), bar)

	var zones := {
		"Zone_GardenEntry": Vector3(15.2, F, -94.6),
		"Zone_Garden": Vector3(18.5, F, -95.4),
		"Zone_GardenExit": Vector3(EXIT_X, F, -94.4),
		"Zone_CorridorSouthDoor": Vector3(EXIT_X - 0.6, F, -90.6),
	}
	for n in zones:
		SceneUtil.marker(markers, n, zones[n] + Vector3(0, 0.05, 0))
	var s := SceneUtil.marker(shots, "Shot_Garden", Vector3(25.5, F + 2.4, -94.2), Vector3(18.5, F + 2.8, -102))
	s.set_meta("player_pos", Vector3(22.5, F + 0.05, -95.2))

static func _tree(parent: Node3D, pos: Vector3, s: float) -> void:
	var src: Node = (load(TREE_GLB) as PackedScene).instantiate()
	var mi: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: ArrayMesh = mi.mesh.duplicate()
	src.free()
	var bark: ShaderMaterial = O.stone_mat.duplicate()
	bark.set_shader_parameter("stone_color", Color(0.42, 0.32, 0.22))
	bark.set_shader_parameter("stone_dark", Color(0.2, 0.15, 0.1))
	bark.set_shader_parameter("moss_amount", 0.8)
	bark.set_shader_parameter("scale", 1.1)
	var leaves := ShaderMaterial.new()
	leaves.shader = load("res://shaders/foliage.gdshader")
	leaves.set_shader_parameter("leaf_tex", _leaf_texture())
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		mesh.surface_set_material(i, leaves if m and m.resource_name == "Leaves" else bark)
	ResourceSaver.save(mesh, GEN + "/garden_tree_mesh.res")
	var body := StaticBody3D.new()
	body.name = "Tree"
	body.position = pos
	body.scale = Vector3.ONE * s
	var t := MeshInstance3D.new()
	t.name = "Mesh"
	t.mesh = load(GEN + "/garden_tree_mesh.res")
	body.add_child(t)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.7
	cyl.height = 3.0
	cs.shape = cyl
	cs.position.y = 1.5
	body.add_child(cs)
	parent.add_child(body)

## Procedural willow-leaf cluster texture (no import step needed).
static func _leaf_texture() -> Texture2D:
	var path := GEN + "/leaf_cluster.res"
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for n in 140:
		var c := Vector2(r.randf_range(20, 236), r.randf_range(10, 246))
		var ang := r.randf_range(-0.6, 0.6) + PI * 0.5
		var length := r.randf_range(26, 46)
		var width := r.randf_range(5, 9)
		var col := Color(0.18, 0.52, 0.12).lerp(Color(0.45, 0.78, 0.22), r.randf())
		var dir := Vector2(cos(ang), sin(ang))
		var nrm := Vector2(-dir.y, dir.x)
		for i in int(length):
			var t := i / length
			var half := width * sin(t * PI)
			var p := c + dir * (t - 0.5) * length
			for j in range(-int(half), int(half) + 1):
				var q := p + nrm * j
				if q.x >= 0 and q.y >= 0 and q.x < 256 and q.y < 256:
					var shade: float = 1.0 - absf(j) / maxf(half, 1.0) * 0.35
					img.set_pixelv(Vector2i(q), Color(col.r * shade, col.g * shade, col.b * shade, 1.0))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	ResourceSaver.save(tex, path)
	return load(path)

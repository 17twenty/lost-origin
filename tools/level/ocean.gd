class_name LevelOcean
## Shared "open ocean" seen through glass: gradient/caustic/ray backdrop box
## (`underwater.gdshader`), sand floor, rocks, coral clusters, swaying kelp
## and fish schools. One look for every window in the facility.

const O := preload("res://tools/level/outdoor.gd")
const GEN := "res://scenes/generated"

static var _kelp_mesh: ArrayMesh

## opts: fish (int schools), kelp (int), coral (int clusters), rocks (int), floor_y (float)
static func build(parent: Node3D, name: String, pos: Vector3, size: Vector3, opts := {}) -> Node3D:
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
	var floor_y: float = opts.get("floor_y", pos.y - size.y * 0.5 + 0.5)
	var sand := MeshInstance3D.new()
	sand.name = "SeaFloor"
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x, size.z)
	pm.material = SceneUtil.mat(Color(0.32, 0.55, 0.6), 1.0)
	sand.mesh = pm
	sand.position = Vector3(pos.x, floor_y, pos.z)
	o.add_child(sand)
	var half := Vector2(size.x * 0.45, size.z * 0.45)
	for i in int(opts.get("rocks", 8)):
		var rp := Vector3(pos.x + O.rng.randf_range(-half.x, half.x), floor_y, pos.z + O.rng.randf_range(-half.y, half.y))
		O._kenney(o, ["rock_tallA", "rock_tallC", "rock_largeB", "rock_largeD"][O.rng.randi() % 4], rp, O.rng.randf_range(2.5, 6), false)
	_coral(o, pos, half, floor_y, int(opts.get("coral", 10)))
	_kelp(o, pos, half, floor_y, int(opts.get("kelp", 24)), size.y)
	var schools := int(opts.get("fish", 2))
	var palette := [
		PackedColorArray([Color(1.0, 0.78, 0.15), Color(1.0, 0.55, 0.1)]),
		PackedColorArray([Color(0.25, 0.65, 1.0), Color(0.9, 0.95, 1.0)]),
		PackedColorArray([Color(0.95, 0.35, 0.55), Color(0.6, 0.4, 1.0)]),
	]
	for k in schools:
		var fs := MultiMeshInstance3D.new()
		fs.name = "FishSchool%d" % k
		fs.set_script(load("res://scripts/fish_school.gd"))
		fs.position = Vector3(pos.x, floor_y + 1.6 + k * 0.9, pos.z)
		fs.set("extents", Vector3(size.x * 0.35, 0.8, size.z * 0.3))
		fs.set("count", 14 + k * 4)
		fs.set("fish_length", 0.45)
		fs.set("seed_value", O.rng.randi())
		fs.set("speed", O.rng.randf_range(0.09, 0.16))
		fs.set("colors", palette[k % palette.size()])
		o.add_child(fs)
	if opts.get("haze", true):
		O._fog_volume(o, "WaterHaze", size - Vector3(0.5, 0.5, 0.5), pos, 0.025, Color(0.05, 0.3, 0.55))
	var l := OmniLight3D.new()
	l.position = Vector3(pos.x, pos.y + size.y * 0.25, pos.z)
	l.light_color = Color(0.3, 0.7, 1.0)
	l.light_energy = 1.6
	l.light_volumetric_fog_energy = 0.0
	l.omni_range = maxf(size.x, size.z) * 0.9
	o.add_child(l)
	return o

static func _kelp(o: Node3D, pos: Vector3, half: Vector2, floor_y: float, n: int, depth: float) -> void:
	if n <= 0:
		return
	if _kelp_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segs := 10
		var verts := []
		for i in segs + 1:
			var v := float(i) / segs
			var w := 0.22 * (1.0 - v * 0.6)
			var tw := v * 2.4
			verts.append([Vector3(-w * cos(tw), v, -w * sin(tw)), Vector2(0, v)])
			verts.append([Vector3(w * cos(tw), v, w * sin(tw)), Vector2(1, v)])
		for i in segs:
			var a: int = i * 2
			for idx in [a, a + 1, a + 2, a + 1, a + 3, a + 2]:
				st.set_uv(verts[idx][1])
				st.add_vertex(verts[idx][0])
		st.generate_normals()
		_kelp_mesh = st.commit()
		ResourceSaver.save(_kelp_mesh, GEN + "/kelp_mesh.res")
		_kelp_mesh = load(GEN + "/kelp_mesh.res")
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Kelp"
	mmi.set_script(load("res://scripts/multimesh_baked.gd"))
	mmi.set("mesh", _kelp_mesh)
	var xforms: Array[Transform3D] = []
	for i in n:
		var p := Vector3(pos.x + O.rng.randf_range(-half.x, half.x), floor_y, pos.z + O.rng.randf_range(-half.y, half.y))
		var hgt := O.rng.randf_range(depth * 0.3, depth * 0.65)
		var b := Basis(Vector3.UP, O.rng.randf() * TAU).scaled(Vector3(O.rng.randf_range(0.8, 1.4), hgt, 1.0))
		xforms.append(Transform3D(b, p))
	mmi.set("transforms", xforms)
	var km := ShaderMaterial.new()
	km.shader = load("res://shaders/kelp.gdshader")
	mmi.material_override = km
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o.add_child(mmi)

static func _coral(o: Node3D, pos: Vector3, half: Vector2, floor_y: float, n: int) -> void:
	var cols := [Color(1.0, 0.45, 0.55), Color(1.0, 0.6, 0.2), Color(0.7, 0.4, 1.0), Color(0.3, 0.9, 0.8), Color(1.0, 0.85, 0.4)]
	for i in n:
		var c := Node3D.new()
		c.name = "Coral%d" % i
		c.position = Vector3(pos.x + O.rng.randf_range(-half.x, half.x), floor_y, pos.z + O.rng.randf_range(-half.y, half.y))
		o.add_child(c)
		var col: Color = cols[O.rng.randi() % cols.size()]
		var mat := SceneUtil.mat(col, 0.6, 0.0, col, 0.35)
		for f in O.rng.randi_range(4, 8):
			var fi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = O.rng.randf_range(0.04, 0.09)
			cm.bottom_radius = cm.top_radius * 1.6
			cm.height = O.rng.randf_range(0.5, 1.4)
			cm.radial_segments = 6
			cm.rings = 1
			cm.material = mat
			fi.mesh = cm
			fi.position = Vector3(O.rng.randf_range(-0.4, 0.4), cm.height * 0.45, O.rng.randf_range(-0.4, 0.4))
			fi.rotation = Vector3(O.rng.randf_range(-0.5, 0.5), 0, O.rng.randf_range(-0.5, 0.5))
			fi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.add_child(fi)
		var dome := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = O.rng.randf_range(0.3, 0.6)
		sm.height = sm.radius * 1.2
		sm.radial_segments = 10
		sm.rings = 5
		sm.material = SceneUtil.mat(cols[(O.rng.randi()) % cols.size()], 0.8)
		dome.mesh = sm
		dome.position = Vector3(O.rng.randf_range(-0.6, 0.6), sm.height * 0.3, O.rng.randf_range(-0.6, 0.6))
		c.add_child(dome)

class_name LevelPlants
## Our own lush leaf-card plants (tools/blender/build_plants.py) standing in
## for the pastel Kenney vegetation. `LevelOutdoor._kenney_mesh()` routes the
## Kenney model names in SUBSTITUTE here, so every scatter call upgrades.

const GLB := "res://assets/props/plants.glb"
const GEN := "res://scenes/generated"
const KENNEY := "res://assets/third_party/kenney_nature_kit/"

## Kenney model -> our plant mesh (scaled to the Kenney model's height).
const SUBSTITUTE := {
	"tree_palmTall": "Palm", "tree_palmDetailedTall": "Palm", "tree_palm": "Palm",
	"tree_palmBend": "PalmBend", "tree_palmShort": "PalmShort", "tree_palmDetailedShort": "TreeFern",
	"plant_bushLarge": "Monstera", "plant_bushDetailed": "Fern", "plant_bush": "Fern",
	"plant_flatTall": "Monstera", "plant_flatShort": "Fern",
	"grass_large": "Grass", "grass_leafsLarge": "Fern", "grass_leafs": "Grass",
}

static var _src: Dictionary = {}
static var _mats: Dictionary = {}

static func has(model: String) -> bool:
	return SUBSTITUTE.has(model)

static func mesh_for(model: String) -> Mesh:
	var plant: String = SUBSTITUTE[model]
	if _src.is_empty():
		_load()
	var src: ArrayMesh = _src[plant]
	# Match the Kenney model's height so existing scatter scales still read right.
	var k: Node3D = (load(KENNEY + model + ".glb") as PackedScene).instantiate()
	var kh := 0.0
	for mi: MeshInstance3D in k.find_children("*", "MeshInstance3D", true, false):
		kh = maxf(kh, (mi.transform * mi.mesh.get_aabb()).end.y)
	k.free()
	var s := kh / maxf(src.get_aabb().end.y, 0.01)
	var out := ArrayMesh.new()
	for i in src.get_surface_count():
		var st := SurfaceTool.new()
		st.append_from(src, i, Transform3D(Basis().scaled(Vector3.ONE * s), Vector3.ZERO))
		st.set_material(src.surface_get_material(i))
		st.commit(out)
	var path := "%s/plants/%s.res" % [GEN, model]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GEN + "/plants"))
	ResourceSaver.save(out, path)
	return load(path)

static func _load() -> void:
	var foliage: Shader = load("res://shaders/foliage.gdshader")
	var frond := ShaderMaterial.new()
	frond.shader = foliage
	frond.set_shader_parameter("leaf_tex", _tex("frond", _frond_image()))
	frond.set_shader_parameter("sway", 0.05)
	frond.set_shader_parameter("anchor_blend", 0.3)
	var broad := ShaderMaterial.new()
	broad.shader = foliage
	broad.set_shader_parameter("leaf_tex", _tex("broad", _broad_image()))
	broad.set_shader_parameter("sway", 0.05)
	broad.set_shader_parameter("anchor_blend", 0.3)
	var grass := ShaderMaterial.new()
	grass.shader = foliage
	grass.set_shader_parameter("leaf_tex", _tex("grass", _grass_image()))
	grass.set_shader_parameter("sway", 0.04)
	grass.set_shader_parameter("anchor_blend", 0.15)
	var trunk := ShaderMaterial.new()
	trunk.shader = load("res://shaders/vine.gdshader")
	trunk.set_shader_parameter("tint", Color(0.45, 0.36, 0.25))
	trunk.set_shader_parameter("sway", 0.03)
	trunk.set_shader_parameter("anchor_blend", 1.5)
	_mats = {"Trunk": trunk, "Frond": frond, "Broad": broad, "Grass": grass}
	var root: Node = (load(GLB) as PackedScene).instantiate()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := ArrayMesh.new()
		for i in mi.mesh.get_surface_count():
			var st := SurfaceTool.new()
			st.append_from(mi.mesh, i, Transform3D())
			var m: Material = mi.mesh.surface_get_material(i)
			st.set_material(_mats.get(m.resource_name if m else "", trunk))
			st.commit(mesh)
		_src[String(mi.name)] = mesh
	root.free()

static func _tex(name: String, img: Image) -> Texture2D:
	img.generate_mipmaps()
	var path := "%s/%s_tex.res" % [GEN, name]
	ResourceSaver.save(ImageTexture.create_from_image(img), path)
	return load(path)

static func _stroke(img: Image, a: Vector2, b: Vector2, w0: float, w1: float, col: Color) -> void:
	var n := int(a.distance_to(b)) + 1
	for i in n:
		var t := float(i) / n
		var p := a.lerp(b, t)
		var w := lerpf(w0, w1, t)
		for dx in range(-int(w), int(w) + 1):
			for dy in range(-int(w), int(w) + 1):
				var q := Vector2i(int(p.x) + dx, int(p.y) + dy)
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height() and Vector2(dx, dy).length() <= w:
					img.set_pixelv(q, col)

## Pinnate palm/fern frond: rib down the middle (U = 0.5), leaflets sweeping to the tip (V = 1).
static func _frond_image() -> Image:
	var img := Image.create(128, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var y := 6
	while y < 250:
		var v := y / 256.0
		var reach := 60.0 * (0.35 + 0.65 * sin(minf(v * 1.1, 1.0) * PI))
		for sx in [-1.0, 1.0]:
			var col := Color(0.16, 0.48, 0.1).lerp(Color(0.38, 0.72, 0.18), r.randf())
			_stroke(img, Vector2(64, y), Vector2(64 + sx * reach, y + reach * 0.55), 2.6, 0.8, col)
		y += 5
	_stroke(img, Vector2(64, 0), Vector2(64, 255), 2.0, 1.0, Color(0.42, 0.5, 0.2))
	return img

## Broad split leaf (monstera-like): ellipse with slits off the midrib.
static func _broad_image() -> Image:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 128:
		for x in 128:
			var u := (x - 64) / 60.0
			var v := (y - 66) / 60.0
			if u * u + v * v > 1.0:
				continue
			var ang: float = atan2(v, absf(u))
			var slit: bool = absf(sin(ang * 4.5)) < 0.12 and absf(u) > 0.3
			if slit:
				continue
			var shade: float = 0.8 + 0.2 * (1.0 - absf(u))
			var vein: float = 1.0 if absf(u) > 0.03 else 0.75
			img.set_pixel(x, y, Color(0.12 * shade, 0.45 * shade * vein, 0.1 * shade, 1.0))
	return img

static func _grass_image() -> Image:
	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := RandomNumberGenerator.new()
	r.seed = 4
	for k in 9:
		var x0 := r.randf_range(8, 56)
		var col := Color(0.22, 0.52, 0.12).lerp(Color(0.5, 0.75, 0.22), r.randf())
		# Base at the top row (UV.y = 0), tip at the bottom.
		_stroke(img, Vector2(x0, 0), Vector2(x0 + r.randf_range(-14, 14), r.randf_range(90, 126)), 3.0, 0.6, col)
	return img

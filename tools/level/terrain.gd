class_name LevelTerrain
## Island heightfield. One height function drives the render mesh, the
## HeightMapShape3D collision and marker placement, so they always agree.
##
## Layout (Y up, -Z = north):
##   z  > 18        lagoon shore sloping under the water (south)
##   z  -10..18     beach (spawn, totems, palms)
##   z  -25.5..-10.5 chasm crossed by the aqueduct bridge (deck top y = PATH_Y)
##   z  -60..-26    jungle plateau
##   z  < -60       back cliff with a slot for the grotto (|x| < 11)
##   |x| > 28       side hills enclosing the island

const X_MIN := -80
const X_MAX := 80
const Z_MIN := -100
const Z_MAX := 70
const PATH_Y := 0.3
const WATER_Y := -0.35
const CHASM_Z := -18.0
const CHASM_FLOOR := -10.0
const CHASM_WATER_Y := -6.0
const CLIFF_Z := -60.0
const SLOT_HALF := 11.0
const POOL_POS := Vector2(20.0, -55.0)

static var _noise: FastNoiseLite

static func noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 7
		_noise.frequency = 0.035
		_noise.fractal_octaves = 3
	return _noise

static func height(x: float, z: float) -> float:
	var n := noise().get_noise_2d(x, z)  # ~[-1, 1]
	var h := 0.3 + n * 0.35
	# Main path (beach -> bridge -> grotto) is kept flat at PATH_Y.
	var on_path := 1.0 - smoothstep(4.0, 8.0, abs(x))
	if z < 16.0:
		h = lerp(h, PATH_Y, on_path)
	# Plateau gets a little more relief.
	if z < -26.0:
		h += n * 0.5 * (1.0 - on_path)
	# Lagoon: shore slopes under the water to the south.
	h = lerp(h, -4.0, smoothstep(16.0, 50.0, z))
	# Chasm.
	var c := 1.0 - smoothstep(5.0, 7.5, abs(z - CHASM_Z))
	h = lerp(h, CHASM_FLOOR + n * 0.5, c)
	# Side hills (open to the sea in the south).
	var side := smoothstep(28.0, 50.0, abs(x)) * (20.0 + n * 6.0)
	side *= 1.0 - smoothstep(18.0, 45.0, z)
	# Back cliff with a slot carved for the grotto.
	var back := (1.0 - smoothstep(CLIFF_Z - 6.0, CLIFF_Z + 1.0, z)) * (28.0 + n * 4.0)
	back *= smoothstep(SLOT_HALF, SLOT_HALF + 2.0, abs(x)) if z < CLIFF_Z + 1.0 else 1.0
	h += max(side, back)
	# Plunge pool below the outdoor waterfall.
	var pd := Vector2(x - POOL_POS.x, z - POOL_POS.y).length()
	h = lerp(h, -1.4, 1.0 - smoothstep(3.0, 5.5, pd))
	# Grotto footprint sits under its own floor slab.
	if abs(x) < SLOT_HALF - 0.5 and z < CLIFF_Z + 1.0:
		h = PATH_Y - 0.6
	return h

static func build(parent: Node3D, out_dir: String, material: Material) -> StaticBody3D:
	var w := X_MAX - X_MIN + 1
	var d := Z_MAX - Z_MIN + 1
	var heights := PackedFloat32Array()
	heights.resize(w * d)
	for j in d:
		for i in w:
			heights[j * w + i] = height(X_MIN + i, Z_MIN + j)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in d:
		for i in w:
			st.set_uv(Vector2(i, j) / 8.0)
			st.add_vertex(Vector3(X_MIN + i, heights[j * w + i], Z_MIN + j))
	for j in d - 1:
		for i in w - 1:
			var a := j * w + i
			var b := a + 1
			var c := a + w
			var e := c + 1
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(e); st.add_index(c)
	st.generate_normals()
	var mesh := st.commit()
	ResourceSaver.save(mesh, out_dir + "/terrain_mesh.res")

	var shape := HeightMapShape3D.new()
	shape.map_width = w
	shape.map_depth = d
	shape.map_data = heights
	ResourceSaver.save(shape, out_dir + "/terrain_shape.res")

	var body := StaticBody3D.new()
	body.name = "Terrain"
	# Own layer (3) so tunnels can opt out of it (see scripts/terrain_passthrough.gd).
	body.collision_layer = 1 << 2
	parent.add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = load(out_dir + "/terrain_mesh.res")
	mi.material_override = material
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.name = "Col"
	cs.shape = load(out_dir + "/terrain_shape.res")
	# HeightMapShape3D is centred on its node.
	cs.position = Vector3((X_MIN + X_MAX) * 0.5, 0.0, (Z_MIN + Z_MAX) * 0.5)
	body.add_child(cs)
	return body

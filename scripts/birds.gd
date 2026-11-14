extends MultiMeshInstance3D
## Flock of gulls circling high over the lagoon (built at runtime). Group "birds".

@export var count := 9
@export var radius_min := 18.0
@export var radius_max := 42.0
@export var height_min := 24.0
@export var height_max := 38.0
@export var bird_size := 1.1
@export var seed_value := 5

var t := 0.0
var positions: PackedVector3Array
var _r: PackedFloat32Array
var _h: PackedFloat32Array
var _w: PackedFloat32Array
var _p: PackedFloat32Array

func _ready() -> void:
	add_to_group("birds")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		_r.append(rng.randf_range(radius_min, radius_max))
		_h.append(rng.randf_range(height_min, height_max))
		_w.append(rng.randf_range(0.12, 0.22) * (1.0 if i % 3 else -1.0))
		_p.append(rng.randf() * TAU)
	positions.resize(count)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _gull()
	mm.instance_count = count
	multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/bird.gdshader")
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-radius_max - 5, 0, -radius_max - 5), Vector3(radius_max * 2 + 10, height_max + 10, radius_max * 2 + 10))
	_update(0.0)

func _process(delta: float) -> void:
	_update(delta)

func _update(delta: float) -> void:
	t += delta
	for i in count:
		var a := _p[i] + t * _w[i]
		var p := Vector3(cos(a) * _r[i], _h[i] + sin(t * 0.4 + _p[i]) * 1.5, sin(a) * _r[i])
		var tangent := Vector3(-sin(a), 0, cos(a)) * signf(_w[i])
		var bank := -0.35 * signf(_w[i])
		var b := Basis.looking_at(-tangent, Vector3.UP).rotated(tangent, bank).scaled(Vector3.ONE * bird_size)
		multimesh.set_instance_transform(i, Transform3D(b, p))
		positions[i] = p

## Gull: body + two swept wings, nose +Z, wingspan along X.
static func _gull() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)
	for sx in [-1.0, 1.0]:
		tri.call(Vector3(0, 0, 0.15), Vector3(sx * 0.55, 0.05, -0.05), Vector3(0, 0, -0.12))
		tri.call(Vector3(sx * 0.55, 0.05, -0.05), Vector3(sx * 1.0, -0.02, -0.25), Vector3(sx * 0.35, 0.02, -0.14))
	tri.call(Vector3(0, 0.03, 0.35), Vector3(0.06, 0, -0.1), Vector3(-0.06, 0, -0.1))
	tri.call(Vector3(0, 0, -0.1), Vector3(0.12, 0, -0.4), Vector3(-0.12, 0, -0.4))  # tail
	st.generate_normals()
	return st.commit()

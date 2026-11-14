extends MultiMeshInstance3D
## A school of fish swimming a looping Lissajous path inside `extents`
## (local box half-size), or a circle of `ring_radius` when > 0 (water column).
## Built at runtime so scenes stay small. In group "fish"; `count` = fish.

@export var count := 14
@export var extents := Vector3(6, 2, 3)
@export var ring_radius := 0.0
@export var fish_length := 0.35
@export var speed := 0.12
@export var spread := 0.9
@export var colors: PackedColorArray = PackedColorArray([Color(1.0, 0.75, 0.15), Color(0.2, 0.6, 1.0)])
@export var seed_value := 1

var t := 0.0
var _off: PackedVector3Array
var _lag: PackedFloat32Array
## Local fish positions (mirrors the MultiMesh; the headless dummy renderer doesn't store instances).
var positions: PackedVector3Array

func _ready() -> void:
	add_to_group("fish")
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	t = r.randf() * 100.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _fish_mesh()
	mm.instance_count = count
	for i in count:
		_off.append(Vector3(r.randf_range(-1, 1), r.randf_range(-0.5, 0.5), r.randf_range(-1, 1)) * spread)
		_lag.append(r.randf() * 0.35)
		var c := colors[i % colors.size()]
		mm.set_instance_custom_data(i, Color(c.r, c.g, c.b, r.randf()))
	multimesh = mm
	positions.resize(count)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fish.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(-extents - Vector3.ONE * 2, (extents + Vector3.ONE * 2) * 2)
	_update(0.0)

func _process(delta: float) -> void:
	_update(delta)

func _path(u: float) -> Vector3:
	if ring_radius > 0.0:
		return Vector3(cos(u * 3.0) * ring_radius, sin(u * 1.3) * extents.y, sin(u * 3.0) * ring_radius)
	return Vector3(sin(u * 1.0) * extents.x, sin(u * 1.7 + 0.6) * extents.y, sin(u * 2.0 + 1.1) * extents.z)

func _update(delta: float) -> void:
	t += delta * speed * 10.0
	var mm := multimesh
	for i in count:
		var u := t * 0.1 - _lag[i]
		var p := _path(u)
		var q := _path(u + 0.01)
		var off := _off[i]
		if ring_radius > 0.0:
			off *= 0.35
		p += off
		q += off
		var dir := (q - p).normalized()
		if dir.length() < 0.5:
			dir = Vector3.FORWARD
		var b := Basis.looking_at(-dir, Vector3.UP).scaled(Vector3.ONE * fish_length)
		mm.set_instance_transform(i, Transform3D(b, p))
		positions[i] = p

## Unit-length fish (nose +Z), lighter belly via vertex colour.
static func _fish_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nose := Vector3(0, 0, 0.5)
	var ring := [Vector3(0.09, 0, 0.1), Vector3(0, 0.16, 0.05), Vector3(-0.09, 0, 0.1), Vector3(0, -0.13, 0.08)]
	var joint := Vector3(0, 0, -0.32)
	var fin_t := Vector3(0, 0.15, -0.5)
	var fin_b := Vector3(0, -0.15, -0.5)
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		for v in [a, b, c]:
			st.set_color(Color(1, 1, 1) if v.y < -0.05 else Color(0.75, 0.75, 0.8))
			st.add_vertex(v)
	for k in 4:
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % 4]
		tri.call(nose, a, b)
		tri.call(a, joint, b)
	tri.call(joint, fin_t, fin_b)
	tri.call(Vector3(0, 0.14, 0.06), Vector3(0, 0.24, -0.1), Vector3(0, 0.1, -0.2))  # dorsal fin
	st.generate_normals()
	return st.commit()

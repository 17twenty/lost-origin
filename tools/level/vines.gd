class_name LevelVines
## Hanging vines and moss strands (Blender: tools/blender/build_vines.py) on
## the totems, aqueduct deck and piers, grotto cliffs and garden walls.
## One MultiMesh per variant across the whole level (multimesh_baked.gd).

const O := preload("res://tools/level/outdoor.gd")
const T := preload("res://tools/level/terrain.gd")
const FAC := preload("res://tools/level/facility.gd")
const GLB := "res://assets/props/vines.glb"
const GEN := "res://scenes/generated"
const VARIANTS := ["Vine_A", "Vine_B", "Vine_C"]

static func build(level: Node3D) -> int:
	var meshes := _meshes()
	var buckets := {}
	for v in VARIANTS:
		buckets[v] = [] as Array[Transform3D]
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var add := func(pos: Vector3, outward: Vector3, scale: float, variant := "") -> void:
		var v: String = variant if variant != "" else VARIANTS[r.randi() % VARIANTS.size()]
		var n := Vector3(outward.x, 0, outward.z).normalized()
		var yaw := atan2(-n.z, n.x) + r.randf_range(-0.4, 0.4)
		var b := Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale * r.randf_range(0.8, 1.25), scale))
		(buckets[v] as Array).append(Transform3D(b, pos))

	# Totems: strands hanging off the crown on all four sides.
	for t: Node3D in level.get_node("Outdoor/Totems").get_children():
		var s := t.scale.x
		for k in 4:
			if r.randf() < 0.25:
				continue
			var dir := t.basis.get_rotation_quaternion() * Vector3(cos(k * PI / 2.0), 0, sin(k * PI / 2.0))
			add.call(t.position + Vector3(0, O.TOTEM_CROWN * s, 0) + dir * 0.63 * s, dir, s * r.randf_range(0.7, 1.0), "Vine_C" if k % 2 == 0 else "Vine_A")

	# Aqueduct: under both deck edges and off each pier's impost.
	var z := -7.0
	while z > -29.0:
		for sx in [-1.0, 1.0]:
			if r.randf() < 0.75:
				add.call(Vector3(sx * 2.35, T.DECK_Y - 0.8, z + r.randf_range(-0.4, 0.4)), Vector3(sx, 0, 0), r.randf_range(0.9, 1.4))
		z -= 1.3
	for k in O.AQ_PIERS:
		var pz := O.AQ_Z0 - k * ((O.AQ_Z0 - O.AQ_Z1) / float(O.AQ_PIERS - 1))
		for sx in [-1.0, 1.0]:
			add.call(Vector3(sx * 1.05, T.DECK_Y - 2.2, pz), Vector3(sx, 0, 0), r.randf_range(0.9, 1.2), "Vine_B")

	# Grotto: curtains over both side rims and the back lip (clear of the falls).
	z = -61.5
	while z > -85.0:
		for sx in [-1.0, 1.0]:
			add.call(Vector3(sx * 9.95, 14.3, z + r.randf_range(-0.5, 0.5)), Vector3(-sx, 0, 0), r.randf_range(1.2, 1.8), "Vine_B" if r.randf() < 0.6 else "Vine_A")
		z -= 1.8
	var x := -9.0
	while x <= 9.0:
		if abs(x) > 2.8:
			add.call(Vector3(x, 15.8, -84.95), Vector3(0, 0, 1), r.randf_range(1.2, 1.8), "Vine_B")
		x += 1.5

	# Garden: strands down the walls from the ceiling edge.
	var F := FAC.F
	for gz in [-95.0, -98.0, -101.0, -104.5]:
		add.call(Vector3(13.05, F + 7.8, gz), Vector3(1, 0, 0), 1.0)
		add.call(Vector3(26.95, F + 7.8, gz), Vector3(-1, 0, 0), 1.0)

	var root := SceneUtil.add(level, Node3D.new(), "Vines")
	var total := 0
	for v in VARIANTS:
		var mmi := MultiMeshInstance3D.new()
		mmi.name = v
		mmi.set_script(load("res://scripts/multimesh_baked.gd"))
		mmi.set("mesh", meshes[v])
		var arr: Array[Transform3D] = []
		arr.assign(buckets[v])
		mmi.set("transforms", arr)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.add_to_group("vines", true)
		root.add_child(mmi)
		total += arr.size()
	return total

static func _meshes() -> Dictionary:
	var stem := ShaderMaterial.new()
	stem.shader = load("res://shaders/vine.gdshader")
	stem.set_shader_parameter("tint", Color(0.16, 0.32, 0.08))
	var leaves := ShaderMaterial.new()
	leaves.shader = stem.shader
	leaves.set_shader_parameter("tex", LevelGarden._leaf_texture())
	leaves.set_shader_parameter("tint", Color(0.95, 1.05, 0.9))
	leaves.set_shader_parameter("alpha_cut", 0.45)
	var src: Node = (load(GLB) as PackedScene).instantiate()
	var out := {}
	for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		var key := String(mi.name)
		for v in VARIANTS:
			if key.begins_with(v):
				var mesh: ArrayMesh = mi.mesh.duplicate()
				for i in mesh.get_surface_count():
					var m := mesh.surface_get_material(i)
					mesh.surface_set_material(i, leaves if m and m.resource_name == "Leaves" else stem)
				var path := "%s/%s.res" % [GEN, v.to_lower()]
				ResourceSaver.save(mesh, path)
				out[v] = load(path)
	src.free()
	return out

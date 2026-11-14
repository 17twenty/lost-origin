extends TestCase
## Regression for "trees sway at the base": the sway weight (vertex colour R)
## must be ~0 where a plant meets the ground / a vine meets its anchor, and
## large at frond/leaf tips and strand ends.

func _weights(mesh: Mesh) -> Array:
	var out := []
	for i in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(i)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var c = arr[Mesh.ARRAY_COLOR]
		if c == null or (c as PackedColorArray).size() != v.size():
			out.append([v, PackedColorArray()])
		else:
			out.append([v, c])
	return out

func _check_rooted(path: String, base_frac: float) -> void:
	if not check(ResourceLoader.exists(path), "%s exists" % path):
		return
	var mesh: Mesh = load(path)
	var aabb := mesh.get_aabb()
	var lo := aabb.position.y
	var hi := aabb.end.y
	var base_max := 0.0
	var tip_max := 0.0
	# "Base" = low AND near the stem axis (drooping frond tips can touch the ground far out).
	var reach := maxf(maxf(absf(aabb.position.x), absf(aabb.end.x)), maxf(absf(aabb.position.z), absf(aabb.end.z)))
	for s in _weights(mesh):
		var v: PackedVector3Array = s[0]
		var c: PackedColorArray = s[1]
		check(c.size() > 0, "%s has a sway-weight colour channel" % path.get_file())
		if c.size() == 0:
			return
		for k in v.size():
			var t := (v[k].y - lo) / maxf(hi - lo, 0.001)
			if t < base_frac and Vector2(v[k].x, v[k].z).length() < reach * 0.15:
				base_max = maxf(base_max, c[k].r)
			tip_max = maxf(tip_max, c[k].r)
	check(base_max < 0.15, "%s base stays still (max weight %.2f)" % [path.get_file(), base_max])
	check(tip_max > 0.5, "%s tips sway (max weight %.2f)" % [path.get_file(), tip_max])

func test_plants_rooted() -> void:
	var n := 0
	for f in DirAccess.get_files_at("res://scenes/generated/plants"):
		if f.ends_with(".res"):
			_check_rooted("res://scenes/generated/plants/" + f, 0.05)
			n += 1
	check(n >= 8, "checked every generated plant mesh (%d)" % n)

func test_garden_tree_rooted() -> void:
	_check_rooted("res://scenes/generated/garden_tree_mesh.res", 0.2)

func test_vines_anchored() -> void:
	for v in ["vine_a", "vine_b", "vine_c"]:
		var mesh: Mesh = load("res://scenes/generated/%s.res" % v)
		var top_max := 0.0
		var bottom_max := 0.0
		var lo := mesh.get_aabb().position.y
		for s in _weights(mesh):
			var verts: PackedVector3Array = s[0]
			var c: PackedColorArray = s[1]
			check(c.size() > 0, "%s has a sway-weight colour channel" % v)
			if c.size() == 0:
				return
			for k in verts.size():
				if verts[k].y > -0.05:
					top_max = maxf(top_max, c[k].r)
				if verts[k].y < lo * 0.8:
					bottom_max = maxf(bottom_max, c[k].r)
		check(top_max < 0.15, "%s anchor stays put (%.2f)" % [v, top_max])
		check(bottom_max > 0.5, "%s strand ends sway (%.2f)" % [v, bottom_max])

func test_shaders_have_anchor_safety_net() -> void:
	for sh in ["foliage", "vine"]:
		check((load("res://shaders/%s.gdshader" % sh) as Shader).code.contains("anchor_blend"), "%s gates sway near the anchor" % sh)

class_name SceneUtil
## Helpers for generator scripts that build and save PackedScenes.

static func add(parent: Node, child: Node, name: String = "") -> Node:
	if name != "":
		child.name = name
	parent.add_child(child)
	return child

## Recursively set owner so PackedScene.pack keeps every node.
static func own(root: Node, node: Node = null) -> void:
	if node == null:
		node = root
	for c in node.get_children():
		c.owner = root
		# Don't descend into instanced sub-scenes; their children belong to them.
		if c.scene_file_path == "":
			own(root, c)

static func save(root: Node, path: String) -> int:
	own(root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed %s" % err)
		return err
	err = ResourceSaver.save(ps, path)
	if err != OK:
		push_error("save failed %s" % err)
	return err

static func box_body(size: Vector3, pos: Vector3, mat: Material = null, name: String = "Box") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var bm := BoxMesh.new()
	bm.size = size
	if mat:
		bm.material = mat
	mi.mesh = bm
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.name = "Col"
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	return body

static func mat(color: Color, rough: float = 0.8, metal: float = 0.0, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	return m

static func marker(parent: Node, name: String, pos: Vector3, look_at_pos = null) -> Marker3D:
	var m := Marker3D.new()
	m.name = name
	parent.add_child(m)
	m.position = pos
	if look_at_pos != null:
		m.transform = m.transform.looking_at(look_at_pos, Vector3.UP)
		m.position = pos
	return m

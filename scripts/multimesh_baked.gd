extends MultiMeshInstance3D
## MultiMesh whose instance transforms are stored as a plain exported array and
## uploaded in _ready. Needed because scenes are generated headless, where the
## dummy renderer drops MultiMesh instance buffers on save.

@export var mesh: Mesh
@export var transforms: Array[Transform3D] = []

func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	multimesh = mm

extends Node3D
## Local volumetric haze. The FogVolume + FogMaterial are created at runtime
## only on renderers that support them (Forward+): the Compatibility/WebGL2
## renderer errors on fog shaders, so the web build never instantiates one.

@export var size := Vector3.ONE
@export var density := 0.02
@export var albedo := Color.WHITE

func _ready() -> void:
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return
	var fv := FogVolume.new()
	fv.name = "Fog"
	fv.size = size
	var fm := FogMaterial.new()
	fm.density = density
	fm.albedo = albedo
	fm.edge_fade = 0.3
	fv.material = fm
	add_child(fv)

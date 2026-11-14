class_name WickerSkin
## Builds (and caches) the Wicker Man materials and applies them by the GLB
## material names: Wicker, Band, Straw, Eye.

const DIR := "res://assets/characters/wicker_mats"

static func materials() -> Dictionary:
	if not ResourceLoader.exists(DIR + "/wicker.tres"):
		build()
	return {
		"Wicker": load(DIR + "/wicker.tres"), "Band": load(DIR + "/band.tres"),
		"Straw": load(DIR + "/straw.tres"), "Eye": load(DIR + "/eye.tres"),
	}

static func build() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var wicker := ShaderMaterial.new()
	wicker.shader = load("res://shaders/wicker.gdshader")
	ResourceSaver.save(wicker, DIR + "/wicker.tres")
	var band := ShaderMaterial.new()
	band.shader = wicker.shader
	band.set_shader_parameter("density", 60.0)
	band.set_shader_parameter("herring", 3.0)
	band.set_shader_parameter("strand_light", Color(0.62, 0.45, 0.24))
	band.set_shader_parameter("strand_dark", Color(0.34, 0.22, 0.1))
	ResourceSaver.save(band, DIR + "/band.tres")
	var straw := ShaderMaterial.new()
	straw.shader = load("res://shaders/straw.gdshader")
	var img := _straw_image()
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	ResourceSaver.save(tex, DIR + "/straw_tex.res")
	straw.set_shader_parameter("straw_tex", load(DIR + "/straw_tex.res"))
	ResourceSaver.save(straw, DIR + "/straw.tres")
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(1.0, 0.6, 0.15)
	eye.emission_enabled = true
	eye.emission = Color(1.0, 0.55, 0.1)
	eye.emission_energy_multiplier = 2.5
	ResourceSaver.save(eye, DIR + "/eye.tres")

static func apply(root: Node) -> void:
	var mats := materials()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			var key := m.resource_name if m else ""
			if mats.has(key):
				mi.set_surface_override_material(i, mats[key])

## Dry straw fibres: many thin wavy strands, tapering toward the tip (V = 1).
static func _straw_image() -> Image:
	var img := Image.create(128, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := RandomNumberGenerator.new()
	r.seed = 21
	for k in 70:
		var x := r.randf_range(10, 118)
		var col := Color(0.55, 0.42, 0.24).lerp(Color(0.85, 0.72, 0.48), r.randf())
		var len := r.randf_range(150, 255)
		var wob := r.randf_range(2, 9)
		var ph := r.randf() * TAU
		var w := r.randf_range(1.0, 2.2)
		for y in int(len):
			var t := y / len
			var px := x + sin(t * 6.0 + ph) * wob * t
			var ww := w * (1.0 - t * 0.7)
			for dx in range(-int(ww) - 1, int(ww) + 2):
				var xi := int(px) + dx
				if xi >= 0 and xi < 128 and absf(dx) <= ww:
					img.set_pixel(xi, y, col * (0.85 + 0.15 * r.randf()))
	return img

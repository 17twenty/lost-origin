class_name GameSettings
## Non-camera settings (quality preset, skip intro), same user://settings.cfg
## as CameraSettings.

const PATH := "user://settings.cfg"
const QUALITIES := ["low", "medium", "high"]
static var quality := "high"
static var skip_intro := false
static var _loaded := false

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	CameraSettings.ensure_loaded()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		quality = cfg.get_value("game", "quality", quality)
		skip_intro = cfg.get_value("game", "skip_intro", skip_intro)
	if OS.has_feature("web") and not cfg.has_section_key("game", "quality"):
		quality = "medium"

static func save() -> void:
	CameraSettings.save()
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("game", "quality", quality)
	cfg.set_value("game", "skip_intro", skip_intro)
	cfg.save(PATH)

## Apply the quality preset to a scene's WorldEnvironment + the viewport.
static func is_compat() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"

static func apply_quality(root: Node) -> void:
	ensure_loaded()
	var we := root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	var vp := root.get_viewport()
	var compat := is_compat()   # web / WebGL2: no volumetrics, FogVolumes or SSAO
	if we and we.environment:
		var env := we.environment
		env.volumetric_fog_enabled = quality == "high" and not compat
		env.ssao_enabled = quality == "high" and not compat
		env.glow_enabled = true
		if compat:
			# WebGL2/Compatibility tonemaps hotter (LDR path): pull exposure down so
			# sand and stone don't blow out, add a little saturation back.
			env.fog_density = maxf(env.fog_density, 0.002)   # keep the depth haze
			env.tonemap_exposure = 0.72
			env.adjustment_saturation = 1.3
			env.adjustment_contrast = 1.1
	for fv in root.find_children("*", "FogVolume", true, false):
		(fv as FogVolume).visible = not compat
	if vp:
		vp.msaa_3d = Viewport.MSAA_2X if quality != "low" else Viewport.MSAA_DISABLED
		vp.scaling_3d_scale = 0.75 if quality == "low" else 1.0
	for l in root.find_children("*", "Light3D", true, false):
		if l is DirectionalLight3D:
			(l as DirectionalLight3D).directional_shadow_max_distance = 140.0 if quality == "high" else 70.0
		elif quality == "low" or compat:
			(l as Light3D).shadow_enabled = false   # compat: spot/omni shadows acne badly + cost a lot on WebGL2

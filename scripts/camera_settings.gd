class_name CameraSettings
## Player-facing camera/control settings, persisted to user://settings.cfg
## (the Settings menu in the start page edits these).

const PATH := "user://settings.cfg"
static var auto_recenter := true
static var sensitivity := 1.0      # multiplies mouse and keyboard look speed
static var invert_y := false
static var _loaded := false

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		auto_recenter = cfg.get_value("camera", "auto_recenter", auto_recenter)
		sensitivity = cfg.get_value("camera", "sensitivity", sensitivity)
		invert_y = cfg.get_value("camera", "invert_y", invert_y)

static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("camera", "auto_recenter", auto_recenter)
	cfg.set_value("camera", "sensitivity", sensitivity)
	cfg.set_value("camera", "invert_y", invert_y)
	cfg.save(PATH)

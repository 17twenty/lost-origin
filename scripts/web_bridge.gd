extends Node
## Autoload: on the web build, mirrors the game's state for the browser smoke
## test / page: window.__lost_origin = {state: "title"|"playing"|"paused", fps}.

var _t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func state() -> String:
	var cs := get_tree().current_scene
	if cs == null:
		return "loading"
	if get_tree().paused:
		return "paused"
	match String(cs.name):
		"Title":
			return "title"
		"Main":
			return "playing"
	return String(cs.name).to_lower()

func _process(delta: float) -> void:
	if not OS.has_feature("web"):
		return
	_t += delta
	if _t < 0.25:
		return
	_t = 0.0
	JavaScriptBridge.eval("window.__lost_origin = {state: '%s', fps: %d, renderer: '%s'};" % [state(), Engine.get_frames_per_second(), RenderingServer.get_current_rendering_method()], true)

extends CanvasLayer
## In-game pause menu (Esc): Resume / Controls / Settings / Quit to title.
## Pauses the tree; releases the mouse while open and recaptures it on resume.
## Also plays the fade-in from black when the level starts.

const TITLE := "res://scenes/title.tscn"
var panel: PanelContainer
var menu: VBoxContainer
var _was_captured := false
var _root: Control
var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	GameSettings.apply_quality(get_parent())
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIKit.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.7)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.visible = false
	panel.position = Vector2(80, 100)
	_root.add_child(panel)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	panel.add_child(menu)
	var h := Label.new()
	h.text = "PAUSED"
	h.add_theme_font_size_override("font_size", 40)
	menu.add_child(h)
	for spec in [["Resume", resume], ["Controls", _controls], ["Settings", _settings], ["Quit to title", quit_to_title]]:
		var b := UIKit.button(spec[0], spec[1])
		b.name = String(spec[0]).replace(" ", "")
		menu.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if get_tree().paused:
			resume()
		else:
			pause()


func pause() -> void:
	var p := get_parent().get_node_or_null("Player") as CharacterBody3D
	if p and p.input_locked:
		return   # not during cutscenes
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	panel.visible = true
	menu.visible = true
	(menu.get_node("Resume") as Control).grab_focus.call_deferred()


func resume() -> void:
	for c in _root.get_children():
		if String(c.name).begins_with("Overlay"):
			c.queue_free()
	panel.visible = false
	get_tree().paused = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func quit_to_title() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(TITLE)


func _overlay(p: PanelContainer) -> void:
	panel.visible = false
	p.name = "Overlay" + p.name
	p.position = Vector2(80, 100)
	_root.add_child(p)
	var first := p.find_children("*", "BaseButton", true, false)
	if first.size() > 0:
		(first[0] as Control).grab_focus.call_deferred()


func _close_overlay(p: Control, focus_name: String) -> void:
	p.queue_free()
	panel.visible = true
	(menu.get_node(focus_name) as Control).grab_focus.call_deferred()


func _controls() -> void:
	var p: PanelContainer
	p = UIKit.controls_panel(func() -> void: _close_overlay(p, "Controls"))
	_overlay(p)


func _settings() -> void:
	var p: PanelContainer
	p = UIKit.settings_panel(func() -> void: _close_overlay(p, "Settings"), func() -> void: GameSettings.apply_quality(get_parent()))
	_overlay(p)

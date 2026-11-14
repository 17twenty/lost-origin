extends Node3D
## Title / start page: the live level behind a slow fly-through, "LOST ORIGIN"
## logo, keyboard-navigable Start / Controls / Settings / Quit. Start fades
## into the level (summoning intro plays unless skipped in Settings).

const MAIN := "res://scenes/main.tscn"
var world: Node3D
var cam: Camera3D
var ui: CanvasLayer
var menu: VBoxContainer
var start_button: Button
var fade: ColorRect
var _t := 0.0
var _starting := false


func _ready() -> void:
	GameSettings.ensure_loaded()
	Engine.set_meta("skip_intro", true)   # the backdrop world never runs the intro
	world = (load(MAIN) as PackedScene).instantiate()
	world.name = "World"
	add_child(world)
	var p := world.get_node_or_null("Player") as CharacterBody3D
	if p:
		p.visible = false
		p.input_locked = true
		p.set_physics_process(false)
	var pm := world.get_node_or_null("PauseMenu")
	if pm:
		pm.queue_free()   # no pausing on the title screen
	cam = Camera3D.new()
	cam.fov = 65
	cam.far = 1500
	add_child(cam)
	cam.make_current()
	_fly(0.0)
	GameSettings.apply_quality(self)
	_build_ui()


func _process(delta: float) -> void:
	_t += delta
	_fly(_t)


## Slow drift along the beach past the totem row, looking out over the lagoon.
func _fly(t: float) -> void:
	var a := 0.6 + t * 0.035
	var c := Vector3(10.0, 0.0, 18.0)
	cam.global_position = c + Vector3(cos(a) * 22.0, 4.5 + sin(t * 0.2) * 0.8, sin(a) * 14.0)
	cam.look_at(Vector3(8.0, 3.0, 14.0), Vector3.UP)


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	ui.add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.03, 0.06, 0.25)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var col := VBoxContainer.new()
	col.name = "Column"
	col.set_anchors_preset(Control.PRESET_TOP_LEFT)
	col.position = Vector2(90, 70)
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)
	var logo := Label.new()
	logo.name = "Logo"
	logo.text = "LOST ORIGIN"
	logo.add_theme_font_size_override("font_size", 92)
	logo.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	logo.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.02))
	logo.add_theme_constant_override("outline_size", 14)
	logo.add_theme_color_override("font_shadow_color", Color(1.0, 0.55, 0.15, 0.55))
	logo.add_theme_constant_override("shadow_offset_y", 0)
	logo.add_theme_constant_override("shadow_outline_size", 28)
	col.add_child(logo)
	var sub := Label.new()
	sub.text = "the island's last guardian wakes"
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 24
	col.add_child(gap)
	menu = VBoxContainer.new()
	menu.name = "Menu"
	menu.add_theme_constant_override("separation", 12)
	col.add_child(menu)
	start_button = UIKit.button("Start", start_game)
	start_button.name = "Start"
	menu.add_child(start_button)
	var cb := UIKit.button("Controls", _show_controls)
	cb.name = "Controls"
	menu.add_child(cb)
	var sb := UIKit.button("Settings", _show_settings)
	sb.name = "Settings"
	menu.add_child(sb)
	if not OS.has_feature("web"):
		var qb := UIKit.button("Quit", func() -> void: get_tree().quit())
		qb.name = "Quit"
		menu.add_child(qb)
	fade = ColorRect.new()
	fade.name = "Fade"
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	start_button.grab_focus.call_deferred()


func _swap(panel: Control) -> void:
	menu.visible = false
	panel.name = "Overlay" + panel.name
	(ui.get_child(0) as Control).add_child(panel)
	panel.position = Vector2(520, 120)
	var first := panel.find_children("*", "BaseButton", true, false)
	if first.size() > 0:
		(first[0] as Control).grab_focus.call_deferred()


func _back(panel: Control, focus: Control) -> void:
	panel.queue_free()
	menu.visible = true
	focus.grab_focus.call_deferred()


func _show_controls() -> void:
	var p: PanelContainer
	p = UIKit.controls_panel(func() -> void: _back(p, menu.get_node("Controls")))
	_swap(p)


func _show_settings() -> void:
	var p: PanelContainer
	p = UIKit.settings_panel(func() -> void: _back(p, menu.get_node("Settings")), func() -> void: GameSettings.apply_quality(self))
	_swap(p)


func start_game() -> void:
	if _starting:
		return
	_starting = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	tw.tween_callback(func() -> void:
		Engine.set_meta("skip_intro", GameSettings.skip_intro)
		get_tree().change_scene_to_file(MAIN))

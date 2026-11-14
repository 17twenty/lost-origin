class_name UIKit
## Shared look for the title + pause menus (keyboard-first, visible focus) and
## the Controls / Settings panels.

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.04, 0.1, 0.16, 0.72)
	normal.border_color = Color(0.25, 0.75, 0.9, 0.6)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(12)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.12, 0.2, 0.26, 0.9)
	focus.border_color = Color(1.0, 0.68, 0.25)
	focus.set_border_width_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.1, 0.18, 0.24, 0.85)
	for type in ["Button", "CheckButton", "OptionButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("focus", type, focus)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, focus)
		t.set_color("font_color", type, Color(0.88, 0.95, 1.0))
		t.set_color("font_focus_color", type, Color(1.0, 0.85, 0.55))
		t.set_color("font_hover_color", type, Color(1.0, 0.92, 0.75))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.02, 0.06, 0.1, 0.86)
	panel.border_color = Color(0.25, 0.75, 0.9, 0.5)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(28)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_color("font_color", "Label", Color(0.9, 0.95, 1.0))
	return t

static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 56)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(cb)
	return b

const CONTROLS_TEXT := "Move ................ W A S D\nCamera .............. Arrow keys  (or mouse: click to capture)\nRecenter camera ..... R\nSprint .............. Shift\nJump / swim up ...... Space\nInteract ............ E\nPause menu .......... Esc\nControls overlay .... F1\n\nMenus: arrows / W S to move, Enter or Space to choose."

## Controls panel; returns the panel and calls `back` when closed.
static func controls_panel(back: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "ControlsPanel"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	p.add_child(v)
	var h := Label.new()
	h.text = "CONTROLS"
	h.add_theme_font_size_override("font_size", 34)
	v.add_child(h)
	var l := Label.new()
	l.text = CONTROLS_TEXT
	l.add_theme_font_size_override("font_size", 20)
	v.add_child(l)
	v.add_child(button("Back", back))
	return p

## Settings panel bound to CameraSettings + GameSettings (saved on every change).
static func settings_panel(back: Callable, on_quality: Callable = Callable()) -> PanelContainer:
	GameSettings.ensure_loaded()
	var p := PanelContainer.new()
	p.name = "SettingsPanel"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var h := Label.new()
	h.text = "SETTINGS"
	h.add_theme_font_size_override("font_size", 34)
	v.add_child(h)
	var rc := CheckButton.new()
	rc.name = "AutoRecenter"
	rc.text = "Auto-recenter camera"
	rc.button_pressed = CameraSettings.auto_recenter
	rc.toggled.connect(func(on: bool) -> void:
		CameraSettings.auto_recenter = on
		GameSettings.save())
	v.add_child(rc)
	var inv := CheckButton.new()
	inv.name = "InvertY"
	inv.text = "Invert camera Y"
	inv.button_pressed = CameraSettings.invert_y
	inv.toggled.connect(func(on: bool) -> void:
		CameraSettings.invert_y = on
		GameSettings.save())
	v.add_child(inv)
	var si := CheckButton.new()
	si.name = "SkipIntro"
	si.text = "Skip summoning intro"
	si.button_pressed = GameSettings.skip_intro
	si.toggled.connect(func(on: bool) -> void:
		GameSettings.skip_intro = on
		GameSettings.save())
	v.add_child(si)
	var sens_row := HBoxContainer.new()
	var sl := Label.new()
	sl.text = "Camera sensitivity"
	sl.custom_minimum_size.x = 260
	sens_row.add_child(sl)
	var sens := HSlider.new()
	sens.name = "Sensitivity"
	sens.min_value = 0.3
	sens.max_value = 2.0
	sens.step = 0.1
	sens.value = CameraSettings.sensitivity
	sens.custom_minimum_size = Vector2(240, 32)
	sens.focus_mode = Control.FOCUS_ALL
	sens.value_changed.connect(func(x: float) -> void:
		CameraSettings.sensitivity = x
		GameSettings.save())
	sens_row.add_child(sens)
	v.add_child(sens_row)
	var q := OptionButton.new()
	q.name = "Quality"
	for name in GameSettings.QUALITIES:
		q.add_item("Quality: " + String(name).capitalize())
	q.selected = GameSettings.QUALITIES.find(GameSettings.quality)
	q.item_selected.connect(func(i: int) -> void:
		GameSettings.quality = GameSettings.QUALITIES[i]
		GameSettings.save()
		if on_quality.is_valid():
			on_quality.call())
	v.add_child(q)
	v.add_child(button("Back", back))
	return p

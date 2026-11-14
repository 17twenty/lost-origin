extends Node
## Autoload: registers the input map in code so it stays diff-friendly.

const KEYS := {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	# Keyboard camera (no mouse needed).
	"cam_left": [KEY_LEFT],
	"cam_right": [KEY_RIGHT],
	"cam_up": [KEY_UP],
	"cam_down": [KEY_DOWN],
	"cam_recenter": [KEY_R],
	"toggle_help": [KEY_F1],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_E],
	"pause": [KEY_ESCAPE],
}

## Menus are keyboard-first: WASD also navigates (Enter/Space accept by default).
const UI_EXTRA := {"ui_up": [KEY_W], "ui_down": [KEY_S], "ui_left": [KEY_A], "ui_right": [KEY_D]}

func _enter_tree() -> void:
	for action in UI_EXTRA:
		for k in UI_EXTRA[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)

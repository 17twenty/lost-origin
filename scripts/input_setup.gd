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
	"ui_release_mouse": [KEY_ESCAPE],
}

func _enter_tree() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)

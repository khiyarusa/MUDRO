extends Node
## InputRouter (autoload): one action set shared by touch controls and the keyboard.
## The vehicle simulation only ever reads actions, never UI state.

const BINDINGS: Dictionary = {
	"throttle": [KEY_W, KEY_UP],
	"brake": [KEY_S, KEY_DOWN],
	"gear_up": [KEY_E, KEY_PAGEUP],
	"gear_down": [KEY_Q, KEY_PAGEDOWN],
	"clutch": [KEY_SHIFT],
	"handbrake": [KEY_SPACE],
	"recover": [KEY_R],
	"pause": [KEY_ESCAPE, KEY_P],
	"start_engine": [KEY_I],
	"debug_toggle": [KEY_F3],
}

func _enter_tree() -> void:
	_register_actions()

func _register_actions() -> void:
	for action: String in BINDINGS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key: int in (BINDINGS[action] as Array):
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			ev.pressed = true
			if not _has_key(action, key):
				InputMap.action_add_event(action, ev)

func _has_key(action: String, key: int) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == key:
			return true
	return false

func throttle() -> float:
	return 1.0 if Input.is_action_pressed("throttle") else 0.0

func brake() -> float:
	return 1.0 if Input.is_action_pressed("brake") else 0.0

func clutch() -> float:
	return 0.0 if Input.is_action_pressed("clutch") else 1.0

func handbrake() -> float:
	return 1.0 if Input.is_action_pressed("handbrake") else 0.0

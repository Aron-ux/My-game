extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"
const KEY_SECTION := "keybinds"

const ACTION_MOVE_UP := "move_up"
const ACTION_MOVE_DOWN := "move_down"
const ACTION_MOVE_LEFT := "move_left"
const ACTION_MOVE_RIGHT := "move_right"
const ACTION_ULTIMATE := "ultimate"
const ACTION_SWITCH_PREV := "switch_prev"
const ACTION_SWITCH_NEXT := "switch_next"
const ACTION_TOGGLE_ATTACK_MODE := "toggle_attack_mode"
const ACTION_CHARACTER_PANEL := "character_panel"

const ACTION_ORDER := [
	ACTION_MOVE_UP,
	ACTION_MOVE_DOWN,
	ACTION_MOVE_LEFT,
	ACTION_MOVE_RIGHT,
	ACTION_ULTIMATE,
	ACTION_SWITCH_PREV,
	ACTION_SWITCH_NEXT,
	ACTION_TOGGLE_ATTACK_MODE,
	ACTION_CHARACTER_PANEL
]

const DEFAULT_KEYS := {
	"move_up": KEY_W,
	"move_down": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"ultimate": KEY_R,
	"switch_prev": KEY_Q,
	"switch_next": KEY_E,
	"toggle_attack_mode": KEY_TAB,
	"character_panel": KEY_C
}

static func load_keycode(action_id: String) -> int:
	var config := ConfigFile.new()
	var load_result: Error = config.load(SETTINGS_PATH)
	var default_keycode: int = int(DEFAULT_KEYS.get(action_id, KEY_NONE))
	if load_result != OK:
		return default_keycode
	return int(config.get_value(KEY_SECTION, action_id, default_keycode))

static func save_keycode(action_id: String, keycode: int) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(KEY_SECTION, action_id, keycode)
	config.save(SETTINGS_PATH)

static func load_key_map() -> Dictionary:
	var key_map: Dictionary = {}
	for action_id in ACTION_ORDER:
		key_map[action_id] = load_keycode(action_id)
	return key_map

static func save_key_map(key_map: Dictionary) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	for action_id in ACTION_ORDER:
		config.set_value(KEY_SECTION, action_id, int(key_map.get(action_id, DEFAULT_KEYS.get(action_id, KEY_NONE))))
	config.save(SETTINGS_PATH)

static func reset_default_keybinds() -> void:
	save_key_map(DEFAULT_KEYS.duplicate())

static func is_action_pressed(action_id: String) -> bool:
	var keycode: int = load_keycode(action_id)
	return keycode != KEY_NONE and Input.is_key_pressed(keycode)

static func event_matches_action(event: InputEvent, action_id: String) -> bool:
	if event is not InputEventKey:
		return false
	var key_event := event as InputEventKey
	return key_event.pressed and not key_event.echo and key_event.keycode == load_keycode(action_id)

static func get_key_display_name(keycode: int) -> String:
	if keycode == KEY_NONE:
		return "-"
	var display_name: String = OS.get_keycode_string(keycode)
	if display_name == "":
		return str(keycode)
	return display_name

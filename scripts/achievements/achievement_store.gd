extends RefCounted

const SAVE_PATH := "user://achievements.json"
const SAVE_VERSION := 1

static func load_state() -> Dictionary:
	var parsed: Variant = _read_json(SAVE_PATH)
	if parsed is Dictionary:
		return _normalize_state(parsed)
	return _default_state()

static func save_state(state: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_PATH.get_base_dir()))
	var normalized := _normalize_state(state)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("AchievementStore could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(normalized, "\t"))

static func reset_state() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

static func _default_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"unlocked": {},
		"progress": {},
		"stats": {}
	}

static func _normalize_state(raw_state: Dictionary) -> Dictionary:
	var state := _default_state()
	state["version"] = int(raw_state.get("version", SAVE_VERSION))
	state["unlocked"] = _dictionary_or_empty(raw_state.get("unlocked", {}))
	state["progress"] = _dictionary_or_empty(raw_state.get("progress", {}))
	state["stats"] = _dictionary_or_empty(raw_state.get("stats", {}))
	return state

static func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}

static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var raw_text := file.get_as_text()
	var json := JSON.new()
	var parse_result := json.parse(raw_text)
	if parse_result != OK:
		printerr("AchievementStore JSON parse failed: %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data

extends Node

signal achievement_unlocked(id: String, definition: Dictionary)
signal achievement_progress_changed(id: String, current: int, goal: int, definition: Dictionary)
signal stat_changed(key: String, value: int)

const ACHIEVEMENT_STORE := preload("res://scripts/achievements/achievement_store.gd")
const DEFINITIONS_PATH := "res://data/achievements.json"

var _definitions: Dictionary = {}
var _definition_order: Array = []
var _state: Dictionary = {}
var _loaded := false
var _loading := false

func _ready() -> void:
	load_achievements()

func load_achievements() -> void:
	_loading = true
	_definitions = _load_definitions()
	_definition_order = _definitions.keys()
	_definition_order.sort()
	_state = ACHIEVEMENT_STORE.load_state()
	_sanitize_state()
	_loaded = true
	_loading = false

func get_all_definitions() -> Array:
	_ensure_loaded()
	var rows: Array = []
	for id in _definition_order:
		rows.append(_definitions[id].duplicate(true))
	return rows

func get_definition(id: String) -> Dictionary:
	_ensure_loaded()
	return _definitions.get(id, {}).duplicate(true)

func has_achievement(id: String) -> bool:
	_ensure_loaded()
	return _definitions.has(id)

func is_unlocked(id: String) -> bool:
	_ensure_loaded()
	var unlocked: Dictionary = _state.get("unlocked", {})
	return unlocked.has(id)

func get_progress(id: String) -> int:
	_ensure_loaded()
	var progress: Dictionary = _state.get("progress", {})
	return int(progress.get(id, 0))

func get_goal(id: String) -> int:
	_ensure_loaded()
	var definition: Dictionary = _definitions.get(id, {})
	return max(1, int(definition.get("goal", 1)))

func unlock(id: String) -> bool:
	_ensure_loaded()
	if not _definitions.has(id):
		push_warning("Unknown achievement id: %s" % id)
		return false
	if is_unlocked(id):
		return false

	var unlocked: Dictionary = _state.get("unlocked", {})
	unlocked[id] = {
		"unlocked_at_unix": Time.get_unix_time_from_system()
	}
	_state["unlocked"] = unlocked
	_set_progress_without_save(id, get_goal(id))
	_save()
	achievement_unlocked.emit(id, get_definition(id))
	return true

func add_progress(id: String, amount: int = 1) -> bool:
	_ensure_loaded()
	if amount <= 0:
		return false
	return set_progress(id, get_progress(id) + amount)

func set_progress(id: String, current: int) -> bool:
	_ensure_loaded()
	if not _definitions.has(id):
		push_warning("Unknown achievement id: %s" % id)
		return false
	if is_unlocked(id):
		return false

	var goal := get_goal(id)
	var clamped := clampi(current, 0, goal)
	var previous := get_progress(id)
	if clamped == previous:
		return false

	_set_progress_without_save(id, clamped)
	_save()
	achievement_progress_changed.emit(id, clamped, goal, get_definition(id))
	if clamped >= goal:
		return unlock(id)
	return true

func set_stat_max(key: String, value: int) -> bool:
	_ensure_loaded()
	var stats: Dictionary = _state.get("stats", {})
	var previous := int(stats.get(key, 0))
	if value <= previous:
		return false
	stats[key] = value
	_state["stats"] = stats
	_save()
	stat_changed.emit(key, value)
	return true

func add_stat(key: String, amount: int = 1) -> int:
	_ensure_loaded()
	if amount == 0:
		return get_stat(key)
	var stats: Dictionary = _state.get("stats", {})
	var value := int(stats.get(key, 0)) + amount
	stats[key] = value
	_state["stats"] = stats
	_save()
	stat_changed.emit(key, value)
	return value

func get_stat(key: String) -> int:
	_ensure_loaded()
	var stats: Dictionary = _state.get("stats", {})
	return int(stats.get(key, 0))

func record_enemy_defeated(enemy_kind: String) -> void:
	var total := add_stat("enemies_defeated_total", 1)
	set_progress("ACH_FIRST_BLOOD", total)

	if enemy_kind == "elite":
		var elites := add_stat("elite_enemies_defeated_total", 1)
		set_progress("ACH_FIRST_ELITE", elites)
	elif enemy_kind == "boss":
		var bosses := add_stat("bosses_defeated_total", 1)
		set_progress("ACH_FIRST_BOSS", bosses)

func record_endless_boss_defeated(count: int) -> void:
	set_stat_max("endless_bosses_defeated_best", count)
	set_progress("ACH_ENDLESS_BOSS_3", count)

func record_survival_time(seconds: float) -> void:
	var elapsed := int(floor(maxf(0.0, seconds)))
	set_stat_max("survival_seconds_best", elapsed)
	set_progress("ACH_SURVIVE_5_MIN", elapsed)

func record_player_level(level: int) -> void:
	set_stat_max("player_level_best", level)
	set_progress("ACH_REACH_LEVEL_5", level)

func get_save_snapshot() -> Dictionary:
	_ensure_loaded()
	return _state.duplicate(true)

func reset_local_state() -> void:
	ACHIEVEMENT_STORE.reset_state()
	_state = ACHIEVEMENT_STORE.load_state()
	_sanitize_state()

func _ensure_loaded() -> void:
	if not _loaded and not _loading:
		load_achievements()

func _load_definitions() -> Dictionary:
	var parsed: Variant = _read_json(DEFINITIONS_PATH)
	var result: Dictionary = {}
	if not parsed is Dictionary:
		push_error("Achievement definitions must be a Dictionary: %s" % DEFINITIONS_PATH)
		return result
	var rows: Array = parsed.get("achievements", []) as Array
	for row in rows:
		if not row is Dictionary:
			continue
		var id := str(row.get("id", "")).strip_edges()
		if id == "":
			continue
		var definition: Dictionary = row.duplicate(true)
		definition["id"] = id
		definition["goal"] = max(1, int(definition.get("goal", 1)))
		definition["steam_api_name"] = str(definition.get("steam_api_name", id))
		result[id] = definition
	return result

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	if parse_result != OK:
		printerr("Achievement definitions JSON parse failed: %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data

func _sanitize_state() -> void:
	for key in ["unlocked", "progress", "stats"]:
		if not _state.get(key, {}) is Dictionary:
			_state[key] = {}

	var progress: Dictionary = _state.get("progress", {})
	for id in _definitions.keys():
		var definition: Dictionary = _definitions.get(id, {})
		var goal: int = max(1, int(definition.get("goal", 1)))
		progress[id] = clampi(int(progress.get(id, 0)), 0, goal)
	_state["progress"] = progress

func _set_progress_without_save(id: String, current: int) -> void:
	var progress: Dictionary = _state.get("progress", {})
	progress[id] = clampi(current, 0, get_goal(id))
	_state["progress"] = progress

func _save() -> void:
	ACHIEVEMENT_STORE.save_state(_state)

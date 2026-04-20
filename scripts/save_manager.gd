extends RefCounted

const STORY_DATA := preload("res://scripts/story_data.gd")

const SAVE_ROOT := "user://story_slots"
const META_PATH := SAVE_ROOT + "/meta.json"
const SLOT_COUNT := 3

static var continue_requested: bool = false
static var active_slot_id: int = -1

static func _ensure_save_root() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_ROOT))

static func _slot_dir(slot_id: int) -> String:
	return "%s/slot_%d" % [SAVE_ROOT, slot_id]

static func _profile_path(slot_id: int) -> String:
	return _slot_dir(slot_id) + "/story_profile.json"

static func _run_path(slot_id: int) -> String:
	return _slot_dir(slot_id) + "/run_save.json"

static func _run_backup_path(slot_id: int) -> String:
	return _slot_dir(slot_id) + "/run_save_backup.json"

static func _resolve_slot(slot_id: int = -1) -> int:
	if slot_id >= 1 and slot_id <= SLOT_COUNT:
		return slot_id
	var current := get_active_slot_id()
	if current >= 1 and current <= SLOT_COUNT:
		return current
	return -1

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
		printerr("SaveManager JSON parse failed: %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data

static func _write_json(path: String, data: Dictionary) -> void:
	_ensure_save_root()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))

static func _load_meta() -> Dictionary:
	var parsed: Variant = _read_json(META_PATH)
	if parsed is Dictionary:
		return parsed
	return {}

static func _save_meta(meta: Dictionary) -> void:
	_write_json(META_PATH, meta)

static func _get_last_slot_id() -> int:
	return int(_load_meta().get("last_slot_id", -1))

static func set_active_slot(slot_id: int) -> void:
	if slot_id < 1 or slot_id > SLOT_COUNT:
		return
	active_slot_id = slot_id
	var meta := _load_meta()
	meta["last_slot_id"] = slot_id
	_save_meta(meta)

static func get_active_slot_id() -> int:
	if active_slot_id >= 1 and active_slot_id <= SLOT_COUNT:
		return active_slot_id
	active_slot_id = _get_last_slot_id()
	return active_slot_id

static func _ensure_profile_defaults(profile: Dictionary, slot_id: int) -> Dictionary:
	var normalized := STORY_DATA.build_default_story_profile(slot_id)
	for key in profile.keys():
		normalized[key] = profile[key]
	if not normalized.has("unlocked_styles") or not (normalized["unlocked_styles"] is Dictionary):
		normalized["unlocked_styles"] = {}
	if not normalized.has("equipped_styles") or not (normalized["equipped_styles"] is Dictionary):
		normalized["equipped_styles"] = {}
	if not normalized.has("team_order") or not (normalized["team_order"] is Array):
		normalized["team_order"] = ["swordsman", "gunner", "mage"]
	if not normalized.has("unlocked_role_ids") or not (normalized["unlocked_role_ids"] is Array):
		normalized["unlocked_role_ids"] = ["swordsman", "gunner", "mage"]
	for role_id in ["swordsman", "gunner", "mage"]:
		if not normalized["unlocked_styles"].has(role_id):
			normalized["unlocked_styles"][role_id] = []
		if not normalized["equipped_styles"].has(role_id):
			normalized["equipped_styles"][role_id] = "default"
	var ordered_roles: Array = []
	for role_variant in normalized["team_order"]:
		var role_id := str(role_variant)
		if role_id in ["swordsman", "gunner", "mage"] and not ordered_roles.has(role_id):
			ordered_roles.append(role_id)
	for fallback_role in ["swordsman", "gunner", "mage"]:
		if not ordered_roles.has(fallback_role):
			ordered_roles.append(fallback_role)
	normalized["team_order"] = ordered_roles
	normalized["slot_id"] = slot_id
	normalized["last_updated_unix"] = Time.get_unix_time_from_system()
	return normalized

static func has_story_profile(slot_id: int = -1) -> bool:
	var resolved := _resolve_slot(slot_id)
	if resolved < 1:
		return false
	return FileAccess.file_exists(_profile_path(resolved))

static func create_or_load_story_profile(slot_id: int) -> Dictionary:
	set_active_slot(slot_id)
	var existing := load_story_profile(slot_id)
	if not existing.is_empty():
		return existing
	var profile := STORY_DATA.build_default_story_profile(slot_id)
	save_story_profile(profile, slot_id)
	return profile

static func load_story_profile(slot_id: int = -1) -> Dictionary:
	var resolved := _resolve_slot(slot_id)
	if resolved < 1:
		return {}
	var parsed: Variant = _read_json(_profile_path(resolved))
	if parsed is Dictionary:
		return _ensure_profile_defaults(parsed, resolved)
	return {}

static func save_story_profile(profile: Dictionary, slot_id: int = -1) -> void:
	var resolved := _resolve_slot(slot_id)
	if resolved < 1:
		return
	set_active_slot(resolved)
	_write_json(_profile_path(resolved), _ensure_profile_defaults(profile, resolved))

static func delete_story_profile(slot_id: int) -> void:
	if slot_id < 1 or slot_id > SLOT_COUNT:
		return
	var profile_path := _profile_path(slot_id)
	var run_path := _run_path(slot_id)
	var run_backup_path := _run_backup_path(slot_id)
	if FileAccess.file_exists(profile_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))
	if FileAccess.file_exists(run_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(run_path))
	if FileAccess.file_exists(run_backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(run_backup_path))
	if get_active_slot_id() == slot_id:
		active_slot_id = -1

static func list_story_slots() -> Array:
	var slots: Array = []
	for slot_id in range(1, SLOT_COUNT + 1):
		var profile := load_story_profile(slot_id)
		slots.append({
			"slot_id": slot_id,
			"has_profile": not profile.is_empty(),
			"profile": profile
		})
	return slots

static func has_save(slot_id: int = -1) -> bool:
	var resolved := _resolve_slot(slot_id)
	if resolved < 1:
		return false
	return FileAccess.file_exists(_run_path(resolved)) or FileAccess.file_exists(_run_backup_path(resolved))

static func save_run(data: Dictionary, slot_id: int = -1) -> void:
	var resolved := _resolve_slot(slot_id)
	if resolved < 1:
		return
	set_active_slot(resolved)
	_write_json(_run_path(resolved), data)
	_write_json(_run_backup_path(resolved), data)

static func load_run(slot_id: int = -1) -> Dictionary:
	var resolved := _resolve_slot(slot_id)
	if resolved < 1:
		return {}
	var parsed: Variant = _read_json(_run_path(resolved))
	if parsed is Dictionary:
		return parsed
	var backup_parsed: Variant = _read_json(_run_backup_path(resolved))
	if backup_parsed is Dictionary:
		_write_json(_run_path(resolved), backup_parsed)
		return backup_parsed
	return {}

static func clear_save(slot_id: int = -1) -> void:
	var resolved := _resolve_slot(slot_id)
	if resolved < 1:
		return
	var run_path := _run_path(resolved)
	var run_backup_path := _run_backup_path(resolved)
	if not FileAccess.file_exists(run_path):
		if FileAccess.file_exists(run_backup_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(run_backup_path))
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_path))
	if FileAccess.file_exists(run_backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(run_backup_path))

static func has_continue_target() -> bool:
	return get_continue_target_scene() != ""

static func get_continue_target_scene() -> String:
	var slot_id := _get_last_slot_id()
	if slot_id < 1 or slot_id > SLOT_COUNT:
		return ""
	if has_save(slot_id):
		return STORY_DATA.BATTLE_SCENE_PATH
	if has_story_profile(slot_id):
		return STORY_DATA.PREP_SCENE_PATH
	return ""

static func request_continue_to_last_target() -> String:
	var scene_path := get_continue_target_scene()
	var slot_id := _get_last_slot_id()
	if scene_path == "" or slot_id < 1:
		return ""
	set_active_slot(slot_id)
	continue_requested = scene_path == STORY_DATA.BATTLE_SCENE_PATH
	return scene_path

static func request_continue() -> void:
	continue_requested = true

static func consume_continue_request() -> bool:
	var requested := continue_requested
	continue_requested = false
	return requested

static func get_current_story_stage() -> Dictionary:
	var profile := load_story_profile()
	if profile.is_empty():
		return {}
	return STORY_DATA.get_stage(int(profile.get("current_stage_index", 0)))

static func complete_current_story_stage(material_reward: int = 0) -> Dictionary:
	var profile := load_story_profile()
	if profile.is_empty():
		return {}
	profile["boss_core_fragments"] = int(profile.get("boss_core_fragments", 0)) + material_reward
	profile["current_stage_index"] = int(profile.get("current_stage_index", 0)) + 1
	save_story_profile(profile)
	clear_save()
	return profile

static func unlock_style(role_id: String, style_id: String) -> bool:
	var profile := load_story_profile()
	if profile.is_empty():
		return false
	var unlocked_styles: Dictionary = profile.get("unlocked_styles", {}).duplicate(true)
	var role_styles: Array = unlocked_styles.get(role_id, []).duplicate()
	if role_styles.has(style_id):
		return true
	var boss_cores: int = int(profile.get("boss_core_fragments", 0))
	if boss_cores <= 0:
		return false
	role_styles.append(style_id)
	unlocked_styles[role_id] = role_styles
	profile["unlocked_styles"] = unlocked_styles
	profile["boss_core_fragments"] = boss_cores - 1
	save_story_profile(profile)
	return true

static func equip_style(role_id: String, style_id: String) -> void:
	var profile := load_story_profile()
	if profile.is_empty():
		return
	var equipped_styles: Dictionary = profile.get("equipped_styles", {}).duplicate(true)
	equipped_styles[role_id] = style_id
	profile["equipped_styles"] = equipped_styles
	save_story_profile(profile)

static func update_team_order(team_order: Array) -> void:
	var profile := load_story_profile()
	if profile.is_empty():
		return
	profile["team_order"] = team_order.duplicate()
	save_story_profile(profile)

extends RefCounted

const STORY_DATA := preload("res://scripts/story_data.gd")
const DIFFICULTY_PROFILE := preload("res://scripts/game/difficulty_profile.gd")
const RUAN_STONE_SYSTEM := preload("res://scripts/player/ruan_stone_system.gd")

const MODE_STORY := "story"
const MODE_ENDLESS := "endless"
const DEFAULT_ROLE_IDS := ["swordsman", "gunner", "mage"]
const STORY_PROFILE_COPY_KEYS := [
	"chapter_index",
	"current_stage_index",
	"boss_core_fragments",
	"unlocked_role_ids",
	"team_order",
	"created_unix"
]

static func ensure_story_profile_defaults(profile: Dictionary, slot_id: int) -> Dictionary:
	var normalized := STORY_DATA.build_default_story_profile(slot_id)
	for key in STORY_PROFILE_COPY_KEYS:
		if profile.has(key):
			normalized[key] = profile[key]
	if not normalized.has("team_order") or not (normalized["team_order"] is Array):
		normalized["team_order"] = DEFAULT_ROLE_IDS.duplicate()
	if not normalized.has("unlocked_role_ids") or not (normalized["unlocked_role_ids"] is Array):
		normalized["unlocked_role_ids"] = DEFAULT_ROLE_IDS.duplicate()
	normalized["team_order"] = _normalize_team_order(normalized["team_order"])
	normalized["slot_id"] = slot_id
	normalized["mode"] = MODE_STORY
	normalized["last_updated_unix"] = Time.get_unix_time_from_system()
	return normalized

static func build_default_endless_profile(slot_id: int, difficulty: String) -> Dictionary:
	var normalized_difficulty := DIFFICULTY_PROFILE.normalize_id(difficulty)
	return RUAN_STONE_SYSTEM.normalize_profile({
		"slot_id": slot_id,
		"mode": MODE_ENDLESS,
		"difficulty": normalized_difficulty,
		"created_unix": Time.get_unix_time_from_system(),
		"last_updated_unix": Time.get_unix_time_from_system()
	})

static func ensure_endless_profile_defaults(profile: Dictionary, slot_id: int) -> Dictionary:
	var normalized := build_default_endless_profile(slot_id, str(profile.get("difficulty", "normal")))
	for key in profile.keys():
		normalized[key] = profile[key]
	normalized["slot_id"] = slot_id
	normalized["mode"] = MODE_ENDLESS
	normalized["difficulty"] = DIFFICULTY_PROFILE.normalize_id(str(normalized.get("difficulty", DIFFICULTY_PROFILE.DEFAULT_DIFFICULTY_ID)))
	normalized["last_updated_unix"] = Time.get_unix_time_from_system()
	return RUAN_STONE_SYSTEM.normalize_profile(normalized)

static func _normalize_team_order(team_order: Array) -> Array:
	var ordered_roles: Array = []
	for role_variant in team_order:
		var role_id := str(role_variant)
		if role_id in DEFAULT_ROLE_IDS and not ordered_roles.has(role_id):
			ordered_roles.append(role_id)
	for fallback_role in DEFAULT_ROLE_IDS:
		if not ordered_roles.has(fallback_role):
			ordered_roles.append(fallback_role)
	return ordered_roles

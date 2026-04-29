extends RefCounted

const BUILD_SYSTEM := preload("res://scripts/build/build_system.gd")
const PLAYER_BUILD_STATE := preload("res://scripts/player/player_build_state.gd")


static func get_role_theme_color(owner, role_id: String) -> Color:
	for role_data in owner.roles:
		if str(role_data.get("id", "")) == role_id:
			return role_data.get("color", Color.WHITE)
	return Color.WHITE


static func announce_completed_final_set(owner, set_key: String) -> void:
	var final_set: Dictionary = BUILD_SYSTEM.get_final_set_data(set_key)
	if set_key == "" or final_set.is_empty() or owner.final_set_unlock_announced.has(set_key):
		return
	if not PLAYER_BUILD_STATE.is_final_set_complete(owner.card_pick_levels, final_set):
		return
	owner.final_set_unlock_announced[set_key] = true
	var accent: Color = get_role_theme_color(owner, str(owner._get_active_role().get("id", "swordsman")))
	owner._show_switch_banner("SET", str(final_set.get("full_title", "")), accent)


static func record_card_pick(owner, slot_id: String, option_id: String) -> void:
	var stored_card_id := BUILD_SYSTEM.get_shared_card_id(option_id)
	var config: Dictionary = BUILD_SYSTEM.get_core_card_config(option_id)
	var max_level := int(config.get("max_level", 999))
	owner.card_pick_levels[stored_card_id] = min(max_level, owner._get_card_level(option_id) + 1)
	record_build_pick(owner, slot_id)
	if not config.is_empty():
		announce_completed_final_set(owner, str(config.get("set_key", "")))


static func record_build_pick(owner, slot_id: String) -> void:
	owner.build_slot_levels[slot_id] = int(owner.build_slot_levels.get(slot_id, 0)) + 1
	owner._check_slot_resonance_unlocks()

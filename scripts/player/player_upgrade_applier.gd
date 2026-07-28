extends RefCounted

const PLAYER_REWARD_APPLIER := preload("res://scripts/player/player_reward_applier.gd")
const PLAYER_EQUIPMENT_FLOW := preload("res://scripts/player/player_equipment_flow.gd")
const PLAYER_FINAL_UPGRADE_APPLIER := preload("res://scripts/player/player_final_upgrade_applier.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const POST_UPGRADE_NEXT_POPUP_DELAY := 0.08


static func apply_upgrade(owner, option_id: String) -> void:
	apply_upgrades(owner, [option_id])


static func apply_upgrades(owner, option_ids: Array) -> void:
	var refresh_stats := false
	var refresh_health := false
	for raw_option_id in option_ids:
		var option_id := str(raw_option_id)
		if option_id == "":
			continue
		if PLAYER_REWARD_APPLIER.is_noop_upgrade(option_id):
			continue
		var blessing_result: Dictionary = PLAYER_BLESSING_SYSTEM.apply_option_with_result(owner, option_id)
		if not blessing_result.is_empty():
			refresh_stats = true
			refresh_health = true
			var result_type := str(blessing_result.get("type", ""))
			if result_type != PLAYER_BLESSING_SYSTEM.CATEGORY_MAGIC_STONE and result_type != PLAYER_BUILD_SYSTEM.CATEGORY_ROLE_BUILD:
				if owner.has_method("_refresh_blessing_skill_unlocks"):
					owner._refresh_blessing_skill_unlocks(
						str(blessing_result.get("blessing_id", "")),
						int(blessing_result.get("tier", 0)),
						str(blessing_result.get("binding", ""))
					)
			continue
		if PLAYER_EQUIPMENT_FLOW.apply_equipment_reward(owner, option_id):
			refresh_stats = true
			refresh_health = true
			continue
		if PLAYER_REWARD_APPLIER.apply_small_boss_reward(owner, option_id):
			refresh_stats = true
			refresh_health = true
			continue
		if _apply_final_core(owner, option_id):
			refresh_stats = true
			refresh_health = true
			continue

	# Unknown ids are ignored intentionally. Stale save/editor option ids should
	# not mutate current runs.
	_finish_upgrade(owner, refresh_stats, refresh_health)


static func _apply_final_core(owner, option_id: String) -> bool:
	if not ["final_body_core", "final_combat_core", "final_skill_core"].has(option_id):
		return false
	var role_id: String = str(owner._get_active_role().get("id", ""))
	var role_data: Dictionary = owner.role_upgrade_levels.get(role_id, {})
	var special_data: Dictionary = owner._get_role_special_state(role_id)
	PLAYER_FINAL_UPGRADE_APPLIER.apply_final_upgrade(owner, option_id, role_id, role_data, special_data)
	owner.role_upgrade_levels[role_id] = role_data
	owner.role_special_states[role_id] = special_data
	return true


static func _finish_upgrade(owner, refresh_stats: bool = false, refresh_health: bool = false) -> void:
	owner.level_up_active = false
	if refresh_stats:
		owner._update_fire_timer()
		_emit_lightweight_stats_changed(owner)
		owner._emit_active_mana_changed()
	if refresh_health:
		owner.health_changed.emit(owner.current_health, owner.max_health)
	if owner.get("pending_blessing_binding_choices") is Array and not (owner.get("pending_blessing_binding_choices") as Array).is_empty():
		return
	if int(owner.get("pending_level_ups")) > 0 and owner.has_method("_delay_level_up_requests"):
		owner._delay_level_up_requests(POST_UPGRADE_NEXT_POPUP_DELAY)
	owner._try_request_level_up()


static func _emit_lightweight_stats_changed(owner) -> void:
	if owner.has_method("emit_frame_stats_changed"):
		owner.emit_frame_stats_changed()
	else:
		owner.stats_changed.emit(owner.get_stat_summary())

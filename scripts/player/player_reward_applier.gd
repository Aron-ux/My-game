extends RefCounted

const DANGZHEN_QICHAO_CARD := "battle_dangzhen_qichao"
const DANGZHEN_DIELANG_CARD := "battle_dangzhen_dielang"
const DANGZHEN_HUICHAO_CARD := "battle_dangzhen_huichao"

const SMALL_BOSS_QICHAO := "small_boss_dangzhen_qichao"
const SMALL_BOSS_DIELANG := "small_boss_dangzhen_dielang"
const SMALL_BOSS_HUICHAO := "small_boss_dangzhen_huichao"
const SMALL_BOSS_BLADE_STORM := "small_boss_dangzhen_blade_storm"
const SMALL_BOSS_INFINITE_RELOAD := "small_boss_dangzhen_infinite_reload"
const SMALL_BOSS_TIDAL_SURGE := "small_boss_dangzhen_tidal_surge"
const SMALL_BOSS_TRAINING_LEVEL_UP := "small_boss_training_level_up"

const BLADE_STORM_LABEL := "\u5251\u5203\u98CE\u66B4"
const INFINITE_RELOAD_LABEL := "\u65E0\u9650\u88C5\u586B"
const TIDAL_SURGE_LABEL := "\u6CE2\u6D9B\u6D8C\u52A8"


static func is_noop_upgrade(option_id: String) -> bool:
	return option_id == "final_blank_upgrade" \
		or option_id == "endless_blank_upgrade" \
		or option_id.begins_with("small_boss_blank_")


static func apply_small_boss_reward(owner, option_id: String) -> bool:
	match option_id:
		SMALL_BOSS_QICHAO:
			_grant_dangzhen_core_level(owner, DANGZHEN_QICHAO_CARD)
		SMALL_BOSS_DIELANG:
			_grant_dangzhen_core_level(owner, DANGZHEN_DIELANG_CARD)
		SMALL_BOSS_HUICHAO:
			_grant_dangzhen_core_level(owner, DANGZHEN_HUICHAO_CARD)
		SMALL_BOSS_BLADE_STORM:
			_grant_swordsman_blade_storm(owner)
		SMALL_BOSS_INFINITE_RELOAD:
			_grant_gunner_infinite_reload(owner)
		SMALL_BOSS_TIDAL_SURGE:
			_grant_mage_tidal_surge(owner)
		SMALL_BOSS_TRAINING_LEVEL_UP:
			_grant_training_level(owner)
		_:
			return false
	return true


static func _grant_dangzhen_core_level(owner, card_id: String) -> void:
	owner.card_pick_levels[card_id] = min(3, owner._get_card_level(card_id) + 1)
	owner._announce_completed_final_set("battle_dangzhen")


static func _grant_swordsman_blade_storm(owner) -> void:
	owner._add_special_reward_level(SMALL_BOSS_BLADE_STORM, 1)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), BLADE_STORM_LABEL, Color(0.4, 0.96, 1.0, 1.0))
	owner._spawn_ring_effect(owner.global_position, 92.0, Color(0.4, 0.96, 1.0, 0.82), 10.0, 0.24)
	owner._spawn_burst_effect(owner.global_position, 104.0, Color(0.2, 0.76, 1.0, 0.18), 0.22)
	if owner.swordsman_blade_storm_ability != null and owner.swordsman_blade_storm_ability.can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		owner._start_swordsman_blade_storm()


static func _grant_gunner_infinite_reload(owner) -> void:
	owner._add_special_reward_level(SMALL_BOSS_INFINITE_RELOAD, 1)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), INFINITE_RELOAD_LABEL, Color(1.0, 0.6, 0.34, 1.0))
	owner._spawn_ring_effect(owner.global_position, 96.0, Color(1.0, 0.56, 0.28, 0.78), 10.0, 0.24)
	owner._spawn_burst_effect(owner.global_position, 108.0, Color(1.0, 0.48, 0.2, 0.18), 0.22)
	if owner.gunner_infinite_reload_ability != null and owner.gunner_infinite_reload_ability.can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		owner._start_gunner_infinite_reload()


static func _grant_mage_tidal_surge(owner) -> void:
	owner._add_special_reward_level(SMALL_BOSS_TIDAL_SURGE, 1)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), TIDAL_SURGE_LABEL, Color(0.62, 0.9, 1.0, 1.0))
	owner._spawn_ring_effect(owner.global_position, 104.0, Color(0.56, 0.86, 1.0, 0.78), 10.0, 0.24)
	owner._spawn_burst_effect(owner.global_position, 116.0, Color(0.46, 0.78, 1.0, 0.18), 0.24)
	if owner.mage_tidal_surge_ability != null and owner.mage_tidal_surge_ability.can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		owner._start_mage_tidal_surge()


static func _grant_training_level(owner) -> void:
	owner.level += 1
	owner.experience_to_next_level = int(round(owner.experience_to_next_level * 1.42)) + 10
	owner.pending_level_ups += 1
	owner.experience_changed.emit(owner.experience, owner.experience_to_next_level, owner.level)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), "\u6f5c\u5fc3\u4fee\u70bc Lv.+1", Color(0.66, 1.0, 0.58, 1.0))
	owner._spawn_ring_effect(owner.global_position, 88.0, Color(0.58, 1.0, 0.48, 0.45), 8.0, 0.22)

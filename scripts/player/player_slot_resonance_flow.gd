extends RefCounted

const PLAYER_STATE_FACTORY := preload("res://scripts/player/player_state_factory.gd")

const SLOT_RESONANCE_FIRST_THRESHOLD := 3
const SLOT_RESONANCE_SECOND_THRESHOLD := 6


static func make_slot_resonance_key(slot_id: String, threshold: int) -> String:
	return PLAYER_STATE_FACTORY.make_slot_resonance_key(slot_id, threshold)


static func is_slot_resonance_unlocked(owner, slot_id: String, threshold: int) -> bool:
	return bool(owner.slot_resonances_unlocked.get(make_slot_resonance_key(slot_id, threshold), false))


static func unlock_slot_resonance(owner, slot_id: String, threshold: int) -> void:
	var resonance_key: String = make_slot_resonance_key(slot_id, threshold)
	if bool(owner.slot_resonances_unlocked.get(resonance_key, false)):
		return

	owner.slot_resonances_unlocked[resonance_key] = true
	var role_id: String = str(owner._get_active_role().get("id", ""))
	var role_data: Dictionary = owner.role_upgrade_levels.get(role_id, {}).duplicate(true)
	var tag_text := ""
	match slot_id:
		"body":
			tag_text = "鎴樻枟鍏遍福"
			if threshold == SLOT_RESONANCE_FIRST_THRESHOLD:
				role_data["damage_bonus"] = float(role_data.get("damage_bonus", 0.0)) + 4.0
				role_data["range_bonus"] = float(role_data.get("range_bonus", 0.0)) + 8.0
				role_data["skill_bonus"] = float(role_data.get("skill_bonus", 0.0)) + 0.08
				owner._apply_role_share(role_id, 1.4, 0.0, 3.0, 0.08)
			else:
				role_data["damage_bonus"] = float(role_data.get("damage_bonus", 0.0)) + 6.0
				role_data["interval_bonus"] = float(role_data.get("interval_bonus", 0.0)) + 0.03
				role_data["range_bonus"] = float(role_data.get("range_bonus", 0.0)) + 10.0
				role_data["skill_bonus"] = float(role_data.get("skill_bonus", 0.0)) + 0.12
				owner._apply_role_share(role_id, 2.0, 0.04, 5.0, 0.12)
		"combat":
			tag_text = "杩炴惡鍏遍福"
			if threshold == SLOT_RESONANCE_FIRST_THRESHOLD:
				owner.global_damage_multiplier += 0.04
				owner.background_interval_multiplier = max(0.66, owner.background_interval_multiplier - 0.05)
				owner.role_switch_cooldown_bonus += 0.45
				owner.switch_cooldown_remaining = max(0.0, owner.switch_cooldown_remaining - 0.4)
			else:
				owner.global_damage_multiplier += 0.06
				owner.background_interval_multiplier = max(0.55, owner.background_interval_multiplier - 0.07)
				owner.role_switch_cooldown_bonus += 0.55
				owner.switch_cooldown_remaining = max(0.0, owner.switch_cooldown_remaining - 0.8)
				owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, 0.12)
		"skill":
			tag_text = "澶ф嫑鍏遍福"
			if threshold == SLOT_RESONANCE_FIRST_THRESHOLD:
				owner.energy_gain_multiplier += 0.1
				owner.max_mana += 10.0
				owner._add_active_role_mana(15.0, false)
				owner.ultimate_cost_multiplier = max(0.68, owner.ultimate_cost_multiplier - 0.04)
			else:
				owner.energy_gain_multiplier += 0.14
				owner.max_mana += 14.0
				owner._add_active_role_mana(24.0, false)
				owner.ultimate_cost_multiplier = max(0.6, owner.ultimate_cost_multiplier - 0.05)
	if not role_data.is_empty():
		owner.role_upgrade_levels[role_id] = role_data
	if tag_text != "":
		owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -34.0), "%s %d" % [tag_text, threshold], Color(1.0, 0.9, 0.56, 1.0))
	owner._emit_active_mana_changed()


static func check_slot_resonance_unlocks(owner) -> void:
	for slot_id in ["body", "combat", "skill"]:
		var slot_level: int = int(owner.build_slot_levels.get(slot_id, 0))
		if slot_level >= SLOT_RESONANCE_FIRST_THRESHOLD and not is_slot_resonance_unlocked(owner, slot_id, SLOT_RESONANCE_FIRST_THRESHOLD):
			unlock_slot_resonance(owner, slot_id, SLOT_RESONANCE_FIRST_THRESHOLD)
		if slot_level >= SLOT_RESONANCE_SECOND_THRESHOLD and not is_slot_resonance_unlocked(owner, slot_id, SLOT_RESONANCE_SECOND_THRESHOLD):
			unlock_slot_resonance(owner, slot_id, SLOT_RESONANCE_SECOND_THRESHOLD)

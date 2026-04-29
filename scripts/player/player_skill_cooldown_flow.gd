extends RefCounted

const PLAYER_SKILL_COOLDOWN_SLOTS := preload("res://scripts/player/player_skill_cooldown_slots.gd")


static func get_active_skill_cooldown_slots(owner, attack_interval: float) -> Array:
	var role_data: Dictionary = owner._get_active_role()
	var role_id: String = str(role_data.get("id", ""))
	var attack_remaining: float = 0.0
	if owner.fire_timer != null and not owner.fire_timer.is_stopped():
		attack_remaining = clamp(owner.fire_timer.time_left, 0.0, attack_interval)

	var extra_slots: Array = []

	if owner._get_card_level("battle_dangzhen_qichao") > 0:
		match role_id:
			"swordsman":
				if owner._has_swordsman_blade_storm_reward() and owner.swordsman_blade_storm_ability != null:
					extra_slots.append(owner.swordsman_blade_storm_ability.get_cooldown_slot(owner))
				elif owner.swordsman_dangzhen_fan_ability != null:
					extra_slots.append(owner.swordsman_dangzhen_fan_ability.get_cooldown_slot(owner))
			"gunner":
				if owner._has_gunner_infinite_reload_reward() and owner.gunner_infinite_reload_ability != null:
					extra_slots.append(owner.gunner_infinite_reload_ability.get_cooldown_slot(owner))
				elif owner.gunner_dangzhen_beam_ability != null:
					extra_slots.append(owner.gunner_dangzhen_beam_ability.get_cooldown_slot(owner))
			"mage":
				if owner._has_mage_tidal_surge_reward() and owner.mage_tidal_surge_ability != null:
					extra_slots.append(owner.mage_tidal_surge_ability.get_cooldown_slot(owner))
				elif owner.mage_dangzhen_wave_ability != null:
					extra_slots.append(owner.mage_dangzhen_wave_ability.get_cooldown_slot(owner))
	return PLAYER_SKILL_COOLDOWN_SLOTS.build_slots(role_id, attack_remaining, attack_interval, extra_slots)

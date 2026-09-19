extends RefCounted

static func apply_final_upgrade(owner, option_id: String, role_id: String, _role_data: Dictionary, special_data: Dictionary) -> void:
	match option_id:
		"final_skill_core":
			apply_final_skill_core(owner, role_id, special_data)


static func apply_final_skill_core(owner, _role_id: String, _special_data: Dictionary) -> void:
	owner.energy_gain_multiplier += 0.16
	owner.background_interval_multiplier = max(0.6, owner.background_interval_multiplier - 0.08)
	owner.ultimate_cost_multiplier = max(0.6, owner.ultimate_cost_multiplier - 0.08)
	owner.role_switch_cooldown_bonus += 0.7
	owner._add_active_role_mana(30.0)

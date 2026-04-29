extends RefCounted

const PLAYER_STATE_FACTORY := preload("res://scripts/player/player_state_factory.gd")
const ROLE_ATTRIBUTE_RULES := preload("res://scripts/player/roles/role_attribute_rules.gd")


static func get_role_attribute_key(role_id: String, attribute_key: String) -> String:
	return PLAYER_STATE_FACTORY.make_role_attribute_key(role_id, attribute_key)


static func get_role_attribute_level(owner, role_id: String, attribute_key: String) -> int:
	if owner.attribute_training_levels.has(attribute_key):
		return int(owner.attribute_training_levels.get(attribute_key, 0))
	return int(owner.attribute_training_levels.get(get_role_attribute_key(role_id, attribute_key), 0))


static func increase_role_attribute_level(owner, role_id: String, attribute_key: String) -> int:
	var next_level: int = min(ROLE_ATTRIBUTE_RULES.MAX_ATTRIBUTE_LEVEL, get_role_attribute_level(owner, role_id, attribute_key) + 1)
	owner.attribute_training_levels[attribute_key] = next_level
	return next_level


static func get_max_attribute_level() -> int:
	return ROLE_ATTRIBUTE_RULES.MAX_ATTRIBUTE_LEVEL


static func is_attribute_evolved(level: int) -> bool:
	return ROLE_ATTRIBUTE_RULES.is_attribute_evolved(level)


static func get_swordsman_heart_interval_multiplier(level: int) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_heart_interval_multiplier(level)


static func get_swordsman_heart_range_multiplier(level: int) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_heart_range_multiplier(level)


static func get_swordsman_normal_attack_scale(level: int) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_normal_attack_scale(level)


static func get_swordsman_normal_attack_width_scale(level: int) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_normal_attack_width_scale(level)


static func get_swordsman_bloodthirst_ratio(level: int) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_bloodthirst_ratio(level)


static func get_swordsman_bloodthirst_heal_cap(level: int) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_bloodthirst_heal_cap(level)


static func get_swordsman_dodge_chance(level: int) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_dodge_chance(level)


static func get_gunner_barrage_speed_multiplier(level: int) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_speed_multiplier(level)


static func get_gunner_barrage_interval_reduction(level: int) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_interval_reduction(level)


static func get_gunner_barrage_bounce_count(level: int) -> int:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_bounce_count(level)


static func get_gunner_barrage_shotgun_wave_count(level: int) -> int:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_shotgun_wave_count(level)


static func get_gunner_barrage_shotgun_pellet_count(level: int) -> int:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_shotgun_pellet_count(level)


static func get_gunner_barrage_split_count(level: int) -> int:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_split_count(level)


static func get_gunner_footwork_range_multiplier(level: int) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_footwork_range_multiplier(level)


static func get_gunner_footwork_move_multiplier(level: int) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_footwork_move_multiplier(level)


static func get_gunner_footwork_flat_speed_bonus(level: int) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_footwork_flat_speed_bonus(level)


static func get_mage_arcane_focus_range_multiplier(level: int) -> float:
	return ROLE_ATTRIBUTE_RULES.get_mage_arcane_focus_range_multiplier(level)


static func get_mage_surplus_energy_multiplier(level: int, role_id: String = "") -> float:
	return ROLE_ATTRIBUTE_RULES.get_mage_surplus_energy_multiplier(level, role_id)


static func get_mage_surplus_passive_energy_per_second(level: int) -> float:
	return ROLE_ATTRIBUTE_RULES.get_mage_surplus_passive_energy_per_second(level)


static func get_role_attribute_range_multiplier(owner, role_id: String) -> float:
	match role_id:
		"swordsman":
			return get_swordsman_heart_range_multiplier(get_role_attribute_level(owner, role_id, "vitality"))
		"gunner":
			return get_gunner_footwork_range_multiplier(get_role_attribute_level(owner, role_id, "agility"))
		"mage":
			return get_mage_arcane_focus_range_multiplier(get_role_attribute_level(owner, role_id, "vitality"))
		_:
			return 1.0


static func get_role_attribute_move_speed_multiplier(owner, role_id: String) -> float:
	if role_id == "gunner":
		return get_gunner_footwork_move_multiplier(get_role_attribute_level(owner, role_id, "agility"))
	return 1.0


static func get_role_attribute_flat_move_speed_bonus(owner, role_id: String) -> float:
	if role_id == "gunner":
		return get_gunner_footwork_flat_speed_bonus(get_role_attribute_level(owner, role_id, "agility"))
	return 0.0


static func get_role_attack_interval_multiplier(owner, role_id: String) -> float:
	if role_id == "swordsman":
		return get_swordsman_heart_interval_multiplier(get_role_attribute_level(owner, role_id, "vitality"))
	return 1.0


static func get_role_attack_interval_flat_reduction(owner, role_id: String) -> float:
	if role_id == "gunner":
		return get_gunner_barrage_interval_reduction(get_role_attribute_level(owner, role_id, "vitality"))
	return 0.0


static func get_ultimate_energy_gain_multiplier_for_role(owner, role_id: String) -> float:
	return get_mage_surplus_energy_multiplier(get_role_attribute_level(owner, "mage", "agility"), role_id)


static func get_role_attribute_titles(role_id: String) -> Dictionary:
	return ROLE_ATTRIBUTE_RULES.get_role_attribute_titles(role_id)


static func get_role_attribute_titles_for_levels(role_id: String, levels: Dictionary) -> Dictionary:
	return ROLE_ATTRIBUTE_RULES.get_role_attribute_titles(role_id, levels)


static func get_role_attribute_description(role_id: String, attribute_key: String, next_level: int) -> String:
	return ROLE_ATTRIBUTE_RULES.get_role_attribute_description(role_id, attribute_key, next_level)


static func get_evolved_title_color() -> Color:
	return ROLE_ATTRIBUTE_RULES.EVOLVED_TITLE_COLOR

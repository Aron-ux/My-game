extends RefCounted

const PLAYER_STATE_FACTORY := preload("res://scripts/player/player_state_factory.gd")
const ROLE_ATTRIBUTE_RULES := preload("res://scripts/player/roles/role_attribute_rules.gd")

const COMMON_PROSPERITY_KEY := "common_prosperity"
const COMMON_PROSPERITY_TRAIT_GAIN := 0.35
const BACKGROUND_TRAIT_SUPPORT_RATIO := 0.3


static func normalize_attribute_training_data(raw_data: Variant) -> Dictionary:
	var normalized: Dictionary = PLAYER_STATE_FACTORY.build_attribute_training_data()
	if raw_data is not Dictionary:
		return normalized

	var data: Dictionary = raw_data
	for attribute_key in ROLE_ATTRIBUTE_RULES.get_attribute_keys():
		normalized[attribute_key] = ROLE_ATTRIBUTE_RULES.get_effective_level(float(data.get(attribute_key, normalized.get(attribute_key, 0.0))))
	normalized[COMMON_PROSPERITY_KEY] = max(0, int(data.get(COMMON_PROSPERITY_KEY, normalized.get(COMMON_PROSPERITY_KEY, 0))))

	return normalized


static func get_attribute_level(owner, attribute_key: String) -> float:
	var key: String = _canonical_attribute_key(attribute_key)
	if key == "":
		return 0.0
	if owner.attribute_training_levels is not Dictionary:
		return 0.0
	return ROLE_ATTRIBUTE_RULES.get_effective_level(float(owner.attribute_training_levels.get(key, 0.0)))


static func get_role_attribute_level(owner, _role_id: String, attribute_key: String) -> float:
	if attribute_key in ROLE_ATTRIBUTE_RULES.get_attribute_keys():
		return get_attribute_level(owner, attribute_key)
	return 0.0


static func add_attribute_levels(owner, deltas: Dictionary) -> Dictionary:
	owner.attribute_training_levels = normalize_attribute_training_data(owner.attribute_training_levels)
	for raw_key in deltas.keys():
		var attribute_key: String = _canonical_attribute_key(str(raw_key))
		if attribute_key == "":
			continue
		var current_level: float = get_attribute_level(owner, attribute_key)
		var delta: float = float(deltas.get(raw_key, 0.0))
		owner.attribute_training_levels[attribute_key] = ROLE_ATTRIBUTE_RULES.get_effective_level(current_level + delta)
	return owner.attribute_training_levels.duplicate(true)


static func increase_role_attribute_level(owner, _role_id: String, attribute_key: String) -> float:
	var key: String = _canonical_attribute_key(attribute_key)
	if key == "":
		return 0.0
	add_attribute_levels(owner, {key: 1.0})
	return get_attribute_level(owner, key)


static func get_max_attribute_level() -> float:
	return ROLE_ATTRIBUTE_RULES.MAX_ATTRIBUTE_LEVEL


static func is_attribute_evolved(level: float) -> bool:
	return ROLE_ATTRIBUTE_RULES.is_attribute_evolved(level)


static func format_attribute_level(level: float) -> String:
	if is_equal_approx(level, roundf(level)):
		return str(int(roundf(level)))
	return "%.1f" % level


static func get_attribute_health_regen_per_second(_owner) -> float:
	return 0.0


static func get_attribute_mana_regen_per_second(_owner) -> float:
	return 0.0


static func get_attribute_dodge_chance(owner) -> float:
	var active_role_id: String = str(owner._get_active_role().get("id", "")) if owner != null and owner.has_method("_get_active_role") else ""
	var dodge_chance: float = 0.0
	if active_role_id == "gunner":
		dodge_chance = ROLE_ATTRIBUTE_RULES.get_gunner_trait_dodge_chance(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_GUNNER))
	elif _is_role_in_background(owner, "gunner"):
		dodge_chance = ROLE_ATTRIBUTE_RULES.get_gunner_trait_dodge_chance(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_GUNNER)) * BACKGROUND_TRAIT_SUPPORT_RATIO
	return dodge_chance


static func get_attribute_pickup_range_bonus(_owner) -> float:
	return 0.0


static func get_swordsman_trait_heal_amount(owner) -> float:
	var heal_amount: float = ROLE_ATTRIBUTE_RULES.get_swordsman_trait_heal_amount(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_SWORDSMAN))
	if _is_role_in_background(owner, "swordsman"):
		heal_amount *= BACKGROUND_TRAIT_SUPPORT_RATIO
	return heal_amount


static func get_swordsman_trait_heal_proc_chance(owner) -> float:
	if _is_role_active(owner, "swordsman") or _is_role_in_background(owner, "swordsman"):
		return ROLE_ATTRIBUTE_RULES.get_swordsman_trait_heal_proc_chance(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_SWORDSMAN))
	return 0.0


static func get_mage_kill_energy_proc_chance(owner) -> float:
	var proc_chance: float = ROLE_ATTRIBUTE_RULES.get_mage_trait_kill_energy_proc_chance(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_MAGE))
	if _is_role_active(owner, "mage"):
		return proc_chance
	if _is_role_in_background(owner, "mage"):
		return proc_chance * BACKGROUND_TRAIT_SUPPORT_RATIO
	return 0.0


static func get_mage_kill_energy_proc_multiplier(_owner) -> float:
	return ROLE_ATTRIBUTE_RULES.MAGE_TRAIT_KILL_ENERGY_MULTIPLIER


static func _is_role_active(owner, role_id: String) -> bool:
	return owner != null and owner.has_method("_get_active_role_id") and str(owner._get_active_role_id()) == role_id


static func _is_role_in_background(owner, role_id: String) -> bool:
	if owner == null or owner.get("roles") is not Array:
		return false
	var active_role_id: String = str(owner._get_active_role_id()) if owner.has_method("_get_active_role_id") else ""
	if active_role_id == role_id:
		return false
	for role_data in owner.roles:
		if role_data is Dictionary and str((role_data as Dictionary).get("id", "")) == role_id:
			return true
	return false


static func get_primary_attribute_damage_bonus(owner, role_id: String) -> float:
	return ROLE_ATTRIBUTE_RULES.get_primary_attribute_damage_bonus(role_id, normalize_attribute_training_data(owner.attribute_training_levels))


static func get_role_trait_level(owner, role_id: String) -> float:
	return get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.get_primary_attribute_for_role(role_id))


static func get_trait_definitions_for_owner(owner) -> Array:
	if owner != null and owner.get("roles") is Array:
		var definitions := ROLE_ATTRIBUTE_RULES.get_trait_definitions(owner.roles)
		if not definitions.is_empty():
			return definitions
	return ROLE_ATTRIBUTE_RULES.get_trait_definitions()


static func get_trait_keys_for_owner(owner) -> Array:
	var keys: Array = []
	for definition in get_trait_definitions_for_owner(owner):
		if definition is not Dictionary:
			continue
		var trait_key := str((definition as Dictionary).get("trait_key", ""))
		if trait_key != "" and not keys.has(trait_key):
			keys.append(trait_key)
	return keys


static func get_balanced_attribute_description(owner, added_amount: float) -> String:
	return ROLE_ATTRIBUTE_RULES.get_balanced_attribute_description_for_roles(
		normalize_attribute_training_data(owner.attribute_training_levels),
		added_amount,
		get_trait_definitions_for_owner(owner)
	)


static func add_common_prosperity(owner) -> Dictionary:
	owner.attribute_training_levels = normalize_attribute_training_data(owner.attribute_training_levels)
	var deltas := {}
	for trait_key in get_trait_keys_for_owner(owner):
		deltas[str(trait_key)] = COMMON_PROSPERITY_TRAIT_GAIN
	add_attribute_levels(owner, deltas)
	owner.attribute_training_levels[COMMON_PROSPERITY_KEY] = get_common_prosperity_count(owner) + 1
	return owner.attribute_training_levels.duplicate(true)


static func get_common_prosperity_count(owner) -> int:
	var normalized := normalize_attribute_training_data(owner.attribute_training_levels)
	return max(0, int(normalized.get(COMMON_PROSPERITY_KEY, 0)))


static func get_common_prosperity_switch_cooldown_multiplier(owner) -> float:
	return pow(ROLE_ATTRIBUTE_RULES.COMMON_PROSPERITY_SWITCH_COOLDOWN_FACTOR, float(get_common_prosperity_count(owner)))


static func get_swordsman_heart_interval_multiplier(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_heart_interval_multiplier(level)


static func get_swordsman_heart_range_multiplier(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_heart_range_multiplier(level)


static func get_swordsman_normal_attack_scale(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_normal_attack_scale(level)


static func get_swordsman_normal_attack_width_scale(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_normal_attack_width_scale(level)


static func get_swordsman_bloodthirst_ratio(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_bloodthirst_ratio(level)


static func get_swordsman_bloodthirst_heal_cap(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_bloodthirst_heal_cap(level)


static func get_swordsman_dodge_chance(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_dodge_chance(level)


static func get_gunner_barrage_speed_multiplier(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_speed_multiplier(level)


static func get_gunner_barrage_interval_reduction(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_interval_reduction(level)


static func get_gunner_barrage_bounce_count(level: float) -> int:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_bounce_count(level)


static func get_gunner_barrage_shotgun_wave_count(level: float) -> int:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_shotgun_wave_count(level)


static func get_gunner_barrage_shotgun_pellet_count(level: float) -> int:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_shotgun_pellet_count(level)


static func get_gunner_barrage_split_count(level: float) -> int:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_split_count(level)


static func get_gunner_footwork_range_multiplier(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_footwork_range_multiplier(level)


static func get_gunner_footwork_move_multiplier(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_footwork_move_multiplier(level)


static func get_gunner_footwork_flat_speed_bonus(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_footwork_flat_speed_bonus(level)


static func get_mage_arcane_focus_range_multiplier(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_mage_arcane_focus_range_multiplier(level)


static func get_mage_surplus_energy_multiplier(level: float, role_id: String = "") -> float:
	return ROLE_ATTRIBUTE_RULES.get_mage_surplus_energy_multiplier(level, role_id)


static func get_mage_surplus_passive_energy_per_second(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_mage_surplus_passive_energy_per_second(level)


static func get_role_attribute_range_multiplier(_owner, _role_id: String) -> float:
	return 1.0


static func get_role_attribute_move_speed_multiplier(_owner, _role_id: String) -> float:
	return 1.0


static func get_role_attack_interval_multiplier(_owner, _role_id: String) -> float:
	return 1.0


static func get_role_attack_interval_flat_reduction(_owner, _role_id: String) -> float:
	return 0.0


static func get_ultimate_energy_gain_multiplier_for_role(_owner, _role_id: String) -> float:
	return 1.0


static func get_role_attribute_titles(role_id: String) -> Dictionary:
	return ROLE_ATTRIBUTE_RULES.get_role_attribute_titles(role_id)


static func get_role_attribute_titles_for_levels(role_id: String, levels: Dictionary) -> Dictionary:
	return ROLE_ATTRIBUTE_RULES.get_role_attribute_titles(role_id, levels)


static func get_role_attribute_description(role_id: String, attribute_key: String, next_level: float) -> String:
	return ROLE_ATTRIBUTE_RULES.get_role_attribute_description(role_id, attribute_key, next_level)


static func get_evolved_title_color() -> Color:
	return ROLE_ATTRIBUTE_RULES.EVOLVED_TITLE_COLOR


static func _canonical_attribute_key(attribute_key: String) -> String:
	match attribute_key:
		ROLE_ATTRIBUTE_RULES.ATTR_SWORDSMAN:
			return ROLE_ATTRIBUTE_RULES.ATTR_SWORDSMAN
		ROLE_ATTRIBUTE_RULES.ATTR_GUNNER:
			return ROLE_ATTRIBUTE_RULES.ATTR_GUNNER
		ROLE_ATTRIBUTE_RULES.ATTR_MAGE:
			return ROLE_ATTRIBUTE_RULES.ATTR_MAGE
		_:
			return ""

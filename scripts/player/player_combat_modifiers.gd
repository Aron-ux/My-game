extends RefCounted

static func get_role_armor(owner, role_id: String) -> float:
	var bonus := 0.0
	if role_id == _get_active_role_id(owner):
		var field: Variant = owner.get("mage_meta_field_ability")
		if field != null and field.has_method("get_armor_bonus"):
			bonus = float(field.get_armor_bonus(owner))
	for role_data in owner.roles:
		if str(role_data.get("id", "")) == role_id:
			return float(role_data.get("armor", 0.0)) + bonus
	return 0.0

const ROLE_ATTRIBUTE_RULES := preload("res://scripts/player/roles/role_attribute_rules.gd")
const PLAYER_EQUIPMENT_FLOW := preload("res://scripts/player/player_equipment_flow.gd")
const PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW := preload("res://scripts/player/player_swordsman_trait_runtime_flow.gd")
const PLAYER_RUAN_STONE_STAT_FLOW := preload("res://scripts/player/player_ruan_stone_stat_flow.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")

const DAMAGE_REDUCTION_RATE_SCALE := 0.75
const DAMAGE_REDUCTION_VALUE_SCALE := 160.0
const DAMAGE_REDUCTION_MIN_RATE := -0.30
const DAMAGE_REDUCTION_MAX_RATE := 0.70


static func get_priority_target_bonus(owner, enemy: Node) -> float:
	var multiplier: float = 1.0
	if enemy != null and is_instance_valid(enemy):
		var enemy_kind: String = str(enemy.get("enemy_kind"))
		if (enemy_kind == "elite" or enemy_kind == "boss") and owner._has_elite_relic("elite_execution_pact"):
			multiplier += 0.14
		var max_hp: float = float(enemy.get("max_health"))
		if max_hp > 0.0:
			var hp_ratio: float = float(enemy.get("current_health")) / max_hp
			if hp_ratio <= 0.45 and owner._has_elite_relic("elite_execution_pact"):
				multiplier += 0.08
	return multiplier


static func is_last_stand_active(owner) -> bool:
	if owner == null or not owner.has_method("_has_elite_relic"):
		return false
	if not owner._has_elite_relic("elite_last_stand"):
		return false
	if owner.max_health <= 0.0:
		return false
	return owner.current_health / owner.max_health <= 0.4


static func get_effective_damage_taken_multiplier(owner) -> float:
	if owner == null:
		return 1.0
	var damage_reduction_rate: float = get_role_damage_reduction_rate(owner, _get_active_role_id(owner))
	return max(0.0, 1.0 - damage_reduction_rate)


static func get_role_damage_reduction_rate(owner, role_id: String = "") -> float:
	var multiplier := 1.0
	for rate in _get_damage_reduction_rates(owner, role_id):
		multiplier *= max(0.0, 1.0 - float(rate))
	return 1.0 - multiplier


static func _get_damage_reduction_rates(owner, role_id: String = "") -> Array:
	var rates: Array = []
	if owner == null:
		return rates
	var resolved_role_id: String = role_id if role_id != "" else _get_active_role_id(owner)
	if resolved_role_id == "":
		return rates
	rates.append(get_role_base_damage_reduction_rate(owner, resolved_role_id))
	rates.append_array(PLAYER_BLESSING_SYSTEM.get_damage_reduction_rates(owner))
	rates.append(_get_equipment_damage_reduction_rate(owner, resolved_role_id))
	rates.append(PLAYER_RUAN_STONE_STAT_FLOW.get_damage_reduction_rate(owner))
	var legacy_value := _get_legacy_damage_reduction_value(owner, resolved_role_id)
	if not is_zero_approx(legacy_value):
		rates.append(calculate_damage_reduction_rate(legacy_value))
	if resolved_role_id == _get_active_role_id(owner):
		var low_health_rate := PLAYER_EQUIPMENT_FLOW.get_low_health_damage_reduction_rate(owner)
		if not is_zero_approx(low_health_rate):
			rates.append(low_health_rate)
	return rates


static func get_role_damage_reduction_value(owner, role_id: String = "") -> float:
	if owner == null:
		return 0.0
	var resolved_role_id: String = role_id if role_id != "" else _get_active_role_id(owner)
	if resolved_role_id == "":
		return 0.0
	var value: float = get_role_base_damage_reduction_rate(owner, resolved_role_id)
	value += _get_equipment_damage_reduction_value(owner, resolved_role_id)
	value += _get_passive_damage_reduction_value(owner)
	value += PLAYER_RUAN_STONE_STAT_FLOW.get_damage_reduction_rate(owner)
	if resolved_role_id == "swordsman":
		var judgement_ability: Variant = owner.get("swordsman_judgement_sword_ability")
		if judgement_ability != null and judgement_ability.has_method("get_active_damage_reduction_value"):
			value += float(judgement_ability.get_active_damage_reduction_value(owner))
	if resolved_role_id == _get_active_role_id(owner):
		value += _get_active_temporary_damage_reduction_value(owner)
	return value


static func _get_legacy_damage_reduction_value(owner, role_id: String) -> float:
	var value: float = 0.0
	value += _get_passive_damage_reduction_value(owner)
	if role_id == "swordsman":
		var judgement_ability: Variant = owner.get("swordsman_judgement_sword_ability")
		if judgement_ability != null and judgement_ability.has_method("get_active_damage_reduction_value"):
			value += float(judgement_ability.get_active_damage_reduction_value(owner))
	if role_id == _get_active_role_id(owner):
		value += _get_active_temporary_damage_reduction_value(owner)
	return value


static func get_role_base_damage_reduction_rate(owner, role_id: String) -> float:
	if owner != null:
		var roles_value: Variant = owner.get("roles")
		if roles_value is Array:
			for role_data in roles_value:
				if role_data is Dictionary and str((role_data as Dictionary).get("id", "")) == role_id:
					return float((role_data as Dictionary).get("base_damage_reduction_rate", ROLE_ATTRIBUTE_RULES.get_role_base_damage_reduction_rate(role_id)))
	return ROLE_ATTRIBUTE_RULES.get_role_base_damage_reduction_rate(role_id)


static func calculate_damage_reduction_rate(damage_reduction_value: float) -> float:
	if is_zero_approx(damage_reduction_value):
		return 0.0
	var rate: float = DAMAGE_REDUCTION_RATE_SCALE * damage_reduction_value / (abs(damage_reduction_value) + DAMAGE_REDUCTION_VALUE_SCALE)
	return clamp(rate, DAMAGE_REDUCTION_MIN_RATE, DAMAGE_REDUCTION_MAX_RATE)


static func damage_reduction_value_from_rate(damage_reduction_rate: float) -> float:
	var rate: float = clamp(damage_reduction_rate, DAMAGE_REDUCTION_MIN_RATE, DAMAGE_REDUCTION_MAX_RATE)
	if is_zero_approx(rate):
		return 0.0
	if rate > 0.0:
		return rate * DAMAGE_REDUCTION_VALUE_SCALE / max(0.001, DAMAGE_REDUCTION_RATE_SCALE - rate)
	return rate * DAMAGE_REDUCTION_VALUE_SCALE / max(0.001, DAMAGE_REDUCTION_RATE_SCALE + rate)


static func damage_reduction_value_from_multiplier(damage_taken_multiplier: float) -> float:
	return damage_reduction_value_from_rate(1.0 - max(0.0, damage_taken_multiplier))


static func _get_equipment_damage_reduction_rate(owner, role_id: String) -> float:
	if owner == null or role_id == "":
		return 0.0
	return PLAYER_EQUIPMENT_FLOW.get_role_damage_reduction_rate(owner, role_id)


static func _get_equipment_damage_reduction_value(owner, role_id: String) -> float:
	return _get_equipment_damage_reduction_rate(owner, role_id)


static func _get_passive_damage_reduction_value(owner) -> float:
	if owner == null:
		return 0.0
	var value: Variant = owner.get("passive_damage_reduction_value")
	if value == null:
		return 0.0
	return float(value)


static func _get_active_temporary_damage_reduction_value(owner) -> float:
	var value: float = 0.0
	if is_last_stand_active(owner):
		value += damage_reduction_value_from_multiplier(0.82)
	var guard_cover_remaining: Variant = owner.get("guard_cover_remaining")
	if guard_cover_remaining != null and float(guard_cover_remaining) > 0.0:
		value += damage_reduction_value_from_multiplier(_get_float_property(owner, "guard_cover_damage_multiplier", 1.0))
	var ultimate_guard_remaining: Variant = owner.get("ultimate_guard_remaining")
	if ultimate_guard_remaining != null and float(ultimate_guard_remaining) > 0.0:
		value += damage_reduction_value_from_multiplier(_get_float_property(owner, "ultimate_guard_damage_multiplier", 1.0))
	value += PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW.get_damage_reduction_value(owner, _get_active_role_id(owner))
	return value


static func _get_active_role_id(owner) -> String:
	if owner == null:
		return ""
	if owner.has_method("_get_active_role_id"):
		return str(owner._get_active_role_id())
	if owner.has_method("_get_active_role"):
		return str(owner._get_active_role().get("id", ""))
	return ""


static func _get_float_property(owner, property_name: String, default_value: float) -> float:
	if owner == null:
		return default_value
	var value: Variant = owner.get(property_name)
	if value == null:
		return default_value
	return float(value)

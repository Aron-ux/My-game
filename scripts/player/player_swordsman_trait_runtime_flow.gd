extends RefCounted

const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

const TALENT_KNIGHT_GLORY_1 := "swordsman_level_talent_knight_glory_1"
const TALENT_KNIGHT_GLORY_2 := "swordsman_level_talent_knight_glory_2"
const TALENT_BLOODTHIRST_1 := "swordsman_level_talent_bloodthirst_1"
const TALENT_BLOODTHIRST_2 := "swordsman_level_talent_bloodthirst_2"
const TALENT_BLADE_STORM_1 := "swordsman_level_talent_blade_storm_1"
const TALENT_CHARGE_1 := "swordsman_level_talent_charge_1"
const TALENT_CHARGE_2 := "swordsman_level_talent_charge_2"

const KNIGHT_GLORY_HEAL_MAX_HEALTH_RATIO := 0.25
const KNIGHT_GLORY_DAMAGE_REDUCTION_VALUE := 100.0
const KNIGHT_GLORY_DAMAGE_REDUCTION_DURATION := 3.0
const KNIGHT_GLORY_SURGE_DURATION := 2.0
const KNIGHT_GLORY_SURGE_DODGE_CHANCE := 0.50
const KNIGHT_GLORY_SURGE_DAMAGE_MULTIPLIER := 1.20
const KNIGHT_GLORY_SURGE_BATTLE_WILL_CHANCE_BONUS := 0.10
const BLOODTHIRST_DAMAGE_MULTIPLIER := 1.10
const BLOODTHIRST_ALL_HEAL_MULTIPLIER := 1.50
const BLADE_STORM_DAMAGE_REDUCTION_VALUE := 100.0
const BLADE_STORM_MOVE_SPEED_BONUS := 20.0
const CHARGE_DAMAGE_REDUCTION_VALUE := 150.0
const CHARGE_DAMAGE_REDUCTION_DURATION := 3.0
const CHARGE_TEAM_MISSING_HEAL_RATIO := 0.20

const STATE_KNIGHT_GLORY_DR_REMAINING := "level_knight_glory_damage_reduction_remaining"
const STATE_KNIGHT_GLORY_SURGE_REMAINING := "level_knight_glory_surge_remaining"
const STATE_CHARGE_DR_REMAINING := "level_charge_damage_reduction_remaining"


static func tick(owner, delta: float) -> void:
	if owner == null or delta <= 0.0:
		return
	_tick_runtime_state(owner, delta)
	_tick_knight_glory(owner, delta)
	_tick_bloodthirst(owner, delta)


static func activate_charge_talents(owner) -> void:
	if owner == null:
		return
	if has_level_talent(owner, TALENT_CHARGE_1):
		var state := _get_state(owner)
		state[STATE_CHARGE_DR_REMAINING] = CHARGE_DAMAGE_REDUCTION_DURATION
		_write_state(owner, state)
	if has_level_talent(owner, TALENT_CHARGE_2):
		_heal_all_roles_by_missing_health(owner, CHARGE_TEAM_MISSING_HEAL_RATIO)


static func get_damage_multiplier(owner, role_id: String) -> float:
	if owner == null or role_id != "swordsman":
		return 1.0
	var multiplier := 1.0
	if has_level_talent(owner, TALENT_BLOODTHIRST_1) and is_bloodthirst_active(owner):
		multiplier *= BLOODTHIRST_DAMAGE_MULTIPLIER
	if float(_get_state(owner).get(STATE_KNIGHT_GLORY_SURGE_REMAINING, 0.0)) > 0.0:
		multiplier *= KNIGHT_GLORY_SURGE_DAMAGE_MULTIPLIER
	return multiplier


static func get_healing_multiplier(owner) -> float:
	if owner == null:
		return 1.0
	if has_level_talent(owner, TALENT_BLOODTHIRST_2) and is_bloodthirst_active(owner):
		return BLOODTHIRST_ALL_HEAL_MULTIPLIER
	return 1.0


static func apply_healing_multiplier(owner, amount: float) -> float:
	return max(0.0, amount) * get_healing_multiplier(owner)


static func get_swordsman_trait_heal_multiplier(owner) -> float:
	if owner == null or _get_active_role_id(owner) != "swordsman":
		return 1.0
	if get_healing_multiplier(owner) > 1.0:
		return 1.0
	return max(1.0, float(owner.get("swordsman_bloodthirst_heal_multiplier")))


static func get_damage_reduction_value(owner, role_id: String) -> float:
	if owner == null or role_id != "swordsman" or _get_active_role_id(owner) != "swordsman":
		return 0.0
	var state := _get_state(owner)
	var value := 0.0
	if float(state.get(STATE_KNIGHT_GLORY_DR_REMAINING, 0.0)) > 0.0:
		value += KNIGHT_GLORY_DAMAGE_REDUCTION_VALUE
	if float(state.get(STATE_CHARGE_DR_REMAINING, 0.0)) > 0.0:
		value += CHARGE_DAMAGE_REDUCTION_VALUE
	if has_level_talent(owner, TALENT_BLADE_STORM_1) and is_blade_storm_active(owner):
		value += BLADE_STORM_DAMAGE_REDUCTION_VALUE
	return value


static func get_flat_dodge_chance_bonus(owner, role_id: String) -> float:
	if owner == null or role_id != "swordsman" or _get_active_role_id(owner) != "swordsman":
		return 0.0
	var state := _get_state(owner)
	if float(state.get(STATE_KNIGHT_GLORY_SURGE_REMAINING, 0.0)) > 0.0:
		return KNIGHT_GLORY_SURGE_DODGE_CHANCE
	return 0.0


static func get_battle_will_proc_chance_bonus(owner) -> float:
	if owner == null:
		return 0.0
	var state := _get_state(owner)
	if float(state.get(STATE_KNIGHT_GLORY_SURGE_REMAINING, 0.0)) > 0.0:
		return KNIGHT_GLORY_SURGE_BATTLE_WILL_CHANCE_BONUS
	return 0.0


static func get_move_speed_bonus(owner, role_id: String) -> float:
	if owner == null or role_id != "swordsman" or _get_active_role_id(owner) != "swordsman":
		return 0.0
	if has_level_talent(owner, TALENT_BLADE_STORM_1) and is_blade_storm_active(owner):
		return BLADE_STORM_MOVE_SPEED_BONUS
	return 0.0


static func is_bloodthirst_active(owner) -> bool:
	if owner == null or _get_active_role_id(owner) != "swordsman":
		return false
	return float(owner.get("swordsman_entry_trait_share_remaining")) > 0.0


static func clear_bloodthirst_on_role_switch(owner) -> void:
	if owner == null:
		return
	owner.swordsman_entry_trait_share_remaining = 0.0
	owner.swordsman_bloodthirst_heal_multiplier = 1.0
	var states_value: Variant = owner.get("role_special_states")
	if states_value is not Dictionary:
		return
	var states: Dictionary = states_value as Dictionary
	for role_id_value in states.keys():
		var role_id := str(role_id_value)
		if role_id == "swordsman":
			continue
		var state_value: Variant = states.get(role_id_value)
		if state_value is not Dictionary:
			continue
		var state: Dictionary = (state_value as Dictionary).duplicate(true)
		state.erase("swordsman_entry_bloodthirst_remaining")
		state.erase("swordsman_entry_bloodthirst_heal_multiplier")
		states[role_id_value] = state
	owner.set("role_special_states", states)


static func is_blade_storm_active(owner) -> bool:
	if owner == null:
		return false
	var ability: Variant = owner.get("swordsman_blade_storm_ability")
	return ability != null and ability.has_method("is_active") and bool(ability.is_active())


static func has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)


static func _tick_knight_glory(owner, delta: float) -> void:
	var previous_remaining := float(owner.get("swordsman_death_defiance_will_remaining"))
	if previous_remaining > 0.0:
		owner.swordsman_death_defiance_will_remaining = max(0.0, previous_remaining - delta)
		if owner.swordsman_death_defiance_will_remaining <= 0.0:
			owner.swordsman_death_defiance_cooldown_remaining = owner.SWORDSMAN_DEATH_DEFIANCE_COOLDOWN
			_apply_knight_glory_finished(owner)
	if float(owner.get("swordsman_death_defiance_cooldown_remaining")) > 0.0:
		owner.swordsman_death_defiance_cooldown_remaining = max(0.0, float(owner.swordsman_death_defiance_cooldown_remaining) - delta)


static func _tick_bloodthirst(owner, delta: float) -> void:
	if float(owner.get("swordsman_bloodthirst_cooldown_remaining")) > 0.0:
		owner.swordsman_bloodthirst_cooldown_remaining = max(0.0, float(owner.swordsman_bloodthirst_cooldown_remaining) - delta)
	if float(owner.get("swordsman_entry_trait_share_remaining")) > 0.0:
		var previous_remaining := float(owner.swordsman_entry_trait_share_remaining)
		owner.swordsman_entry_trait_share_remaining = max(0.0, previous_remaining - delta)
		if owner.swordsman_entry_trait_share_remaining > 0.0:
			owner.swordsman_bloodthirst_heal_multiplier = max(float(owner.swordsman_bloodthirst_heal_multiplier), 1.0)
		else:
			owner.swordsman_bloodthirst_heal_multiplier = 1.0
			if previous_remaining > 0.0:
				owner.swordsman_bloodthirst_cooldown_remaining = max(float(owner.swordsman_bloodthirst_cooldown_remaining), owner.SWORDSMAN_BLOODTHIRST_INTERNAL_COOLDOWN)
	else:
		owner.swordsman_bloodthirst_heal_multiplier = 1.0


static func _tick_runtime_state(owner, delta: float) -> void:
	var state := _get_state(owner)
	for key in [
		STATE_KNIGHT_GLORY_DR_REMAINING,
		STATE_KNIGHT_GLORY_SURGE_REMAINING,
		STATE_CHARGE_DR_REMAINING
	]:
		state[key] = max(0.0, float(state.get(key, 0.0)) - delta)
	_write_state(owner, state)


static func _apply_knight_glory_finished(owner) -> void:
	var state := _get_state(owner)
	if has_level_talent(owner, TALENT_KNIGHT_GLORY_1):
		_heal_role_by_max_health(owner, "swordsman", KNIGHT_GLORY_HEAL_MAX_HEALTH_RATIO)
		state[STATE_KNIGHT_GLORY_DR_REMAINING] = KNIGHT_GLORY_DAMAGE_REDUCTION_DURATION
		_cleanse_negative_statuses(owner)
	if has_level_talent(owner, TALENT_KNIGHT_GLORY_2):
		state[STATE_KNIGHT_GLORY_SURGE_REMAINING] = KNIGHT_GLORY_SURGE_DURATION
	_write_state(owner, state)


static func _heal_role_by_max_health(owner, role_id: String, ratio: float) -> void:
	if owner == null or role_id == "" or ratio <= 0.0:
		return
	var max_health := _get_role_max_health(owner, role_id)
	if max_health <= 0.0:
		return
	if owner.has_method("_heal_role"):
		owner._heal_role(role_id, max_health * ratio)


static func _heal_all_roles_by_missing_health(owner, ratio: float) -> void:
	if owner == null or ratio <= 0.0:
		return
	var roles_value: Variant = owner.get("roles")
	if roles_value is not Array:
		return
	for role_value in roles_value:
		if role_value is not Dictionary:
			continue
		var role_id := str((role_value as Dictionary).get("id", ""))
		if role_id == "":
			continue
		var max_health := _get_role_max_health(owner, role_id)
		var current_health := _get_role_current_health(owner, role_id)
		var missing_health: float = max(0.0, max_health - current_health)
		if missing_health > 0.0 and owner.has_method("_heal_role"):
			owner._heal_role(role_id, missing_health * ratio)


static func _cleanse_negative_statuses(owner) -> void:
	if owner == null:
		return
	if owner.get("healing_block_remaining") != null:
		owner.healing_block_remaining = 0.0
	if owner.get("aging_remaining") != null:
		owner.aging_remaining = 0.0
	if owner.get("aging_damage_carry") != null:
		owner.aging_damage_carry = 0.0
	if owner.get("confinement_remaining") != null:
		owner.confinement_remaining = 0.0
	if owner.get("confinement_radius") != null:
		owner.confinement_radius = 0.0
	if owner.get("confinement_polygon") != null:
		owner.confinement_polygon = PackedVector2Array()
	if owner.get("enemy_move_slow_remaining") != null:
		owner.enemy_move_slow_remaining = 0.0
	if owner.get("enemy_move_slow_multiplier") != null:
		owner.enemy_move_slow_multiplier = 1.0
	if owner.has_method("_clear_duration_status"):
		for status_id in ["orbit_pull", "entangled", "healing_block", "aging", "confinement"]:
			owner._clear_duration_status(status_id)


static func _get_role_max_health(owner, role_id: String) -> float:
	if owner != null and owner.has_method("_get_role_max_health"):
		return max(0.0, float(owner._get_role_max_health(role_id)))
	if owner != null and role_id == _get_active_role_id(owner):
		return max(0.0, float(owner.get("max_health")))
	return 0.0


static func _get_role_current_health(owner, role_id: String) -> float:
	if owner != null and owner.has_method("_get_role_current_health"):
		return max(0.0, float(owner._get_role_current_health(role_id)))
	if owner != null and role_id == _get_active_role_id(owner):
		return max(0.0, float(owner.get("current_health")))
	return 0.0


static func _get_active_role_id(owner) -> String:
	if owner == null:
		return ""
	if owner.has_method("_get_active_role_id"):
		return str(owner._get_active_role_id())
	if owner.has_method("_get_active_role"):
		var active_role: Variant = owner._get_active_role()
		return str(active_role.get("id", "")) if active_role is Dictionary else ""
	return ""


static func _get_state(owner) -> Dictionary:
	if owner == null:
		return {}
	var states_value: Variant = owner.get("role_special_states")
	if states_value is not Dictionary:
		return {}
	var states: Dictionary = states_value as Dictionary
	var state_value: Variant = states.get("swordsman", {})
	var state: Dictionary = state_value.duplicate(true) if state_value is Dictionary else {}
	states["swordsman"] = state
	owner.set("role_special_states", states)
	return state


static func _write_state(owner, state: Dictionary) -> void:
	if owner == null:
		return
	var states_value: Variant = owner.get("role_special_states")
	if states_value is not Dictionary:
		return
	var states: Dictionary = states_value as Dictionary
	states["swordsman"] = state
	owner.set("role_special_states", states)

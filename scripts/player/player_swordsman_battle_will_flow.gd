extends RefCounted

const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")
const ROLE_ATTRIBUTE_RULES := preload("res://scripts/player/roles/role_attribute_rules.gd")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW := preload("res://scripts/player/player_swordsman_trait_runtime_flow.gd")

const SWORDSMAN_LEVEL_TALENT_BATTLE_WILL_SHARED := "swordsman_level_talent_battle_will_1"
const SWORDSMAN_LEVEL_TALENT_BATTLE_WILL_LOW_HEALTH := "swordsman_level_talent_battle_will_2"
const SWORDSMAN_BACKGROUND_WILL_CHANCE_MULTIPLIER := 0.5
const SWORDSMAN_BACKGROUND_WILL_HEAL_MULTIPLIER := 0.2
const SWORDSMAN_LOW_HEALTH_WILL_THRESHOLD := 0.10
const SWORDSMAN_LOW_HEALTH_WILL_DURATION := 5.0
const SWORDSMAN_LOW_HEALTH_WILL_MULTIPLIER := 1.5


static func build_heal_context(owner, role_id: String, hit_count: int) -> Dictionary:
	if owner == null or hit_count <= 0:
		return {}
	var normalized_role_id: String = str(role_id)
	var heal_role_id: String = ""
	var chance_multiplier: float = 1.0
	var heal_multiplier: float = 1.0
	if normalized_role_id == "swordsman":
		heal_role_id = "swordsman"
	elif _can_active_role_trigger_background_will(owner, normalized_role_id):
		heal_role_id = normalized_role_id
		chance_multiplier = SWORDSMAN_BACKGROUND_WILL_CHANCE_MULTIPLIER
		heal_multiplier = SWORDSMAN_BACKGROUND_WILL_HEAL_MULTIPLIER
	else:
		return {}
	sync_low_health_state(owner)
	var low_health_multiplier: float = get_low_health_will_multiplier(owner)
	var proc_chance: float = owner._get_swordsman_trait_heal_proc_chance() if owner.has_method("_get_swordsman_trait_heal_proc_chance") else 0.0
	proc_chance += PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW.get_battle_will_proc_chance_bonus(owner)
	var heal_ratio: float = owner._get_swordsman_trait_heal_amount() if owner.has_method("_get_swordsman_trait_heal_amount") else 0.0
	var missing_heal_ratio: float = ROLE_ATTRIBUTE_RULES.SWORDSMAN_TRAIT_MISSING_HEAL_RATIO + PLAYER_BUILD_SYSTEM.get_swordsman_trait_heal_bonus(owner)
	return {
		"heal_role_id": heal_role_id,
		"proc_chance": proc_chance * chance_multiplier * low_health_multiplier,
		"heal_ratio": heal_ratio * heal_multiplier * low_health_multiplier,
		"missing_heal_ratio": missing_heal_ratio * heal_multiplier * low_health_multiplier,
		"forced_trigger": consume_low_health_forced_will(owner)
	}


static func sync_low_health_state(owner) -> void:
	if not has_level_talent(owner, SWORDSMAN_LEVEL_TALENT_BATTLE_WILL_LOW_HEALTH):
		return
	var state: Dictionary = _get_state(owner)
	var health_ratio: float = _get_role_health_ratio(owner, "swordsman")
	var was_below: bool = bool(state.get("battle_will_low_health_was_below", false))
	if health_ratio <= SWORDSMAN_LOW_HEALTH_WILL_THRESHOLD:
		if not was_below:
			state["battle_will_low_health_remaining"] = SWORDSMAN_LOW_HEALTH_WILL_DURATION
			state["battle_will_low_health_force_trigger"] = true
		state["battle_will_low_health_was_below"] = true
	else:
		state["battle_will_low_health_was_below"] = false
	_write_state(owner, state)


static func tick(owner, delta: float) -> void:
	if owner == null or delta <= 0.0:
		return
	sync_low_health_state(owner)
	if not has_level_talent(owner, SWORDSMAN_LEVEL_TALENT_BATTLE_WILL_LOW_HEALTH):
		return
	var state: Dictionary = _get_state(owner)
	if float(state.get("battle_will_low_health_remaining", 0.0)) > 0.0:
		state["battle_will_low_health_remaining"] = max(0.0, float(state.get("battle_will_low_health_remaining", 0.0)) - delta)
		_write_state(owner, state)


static func get_low_health_will_multiplier(owner) -> float:
	if not has_level_talent(owner, SWORDSMAN_LEVEL_TALENT_BATTLE_WILL_LOW_HEALTH):
		return 1.0
	var state: Dictionary = _get_state(owner)
	return SWORDSMAN_LOW_HEALTH_WILL_MULTIPLIER if float(state.get("battle_will_low_health_remaining", 0.0)) > 0.0 else 1.0


static func consume_low_health_forced_will(owner) -> bool:
	if not has_level_talent(owner, SWORDSMAN_LEVEL_TALENT_BATTLE_WILL_LOW_HEALTH):
		return false
	var state: Dictionary = _get_state(owner)
	if not bool(state.get("battle_will_low_health_force_trigger", false)):
		return false
	state["battle_will_low_health_force_trigger"] = false
	_write_state(owner, state)
	return true


static func has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)


static func _can_active_role_trigger_background_will(owner, role_id: String) -> bool:
	if role_id == "" or role_id == "swordsman":
		return false
	if not has_level_talent(owner, SWORDSMAN_LEVEL_TALENT_BATTLE_WILL_SHARED):
		return false
	if not _owner_has_role(owner, "swordsman"):
		return false
	var active_role_id: String = _get_owner_active_role_id(owner)
	return active_role_id == role_id and active_role_id != "swordsman"


static func _owner_has_role(owner, role_id: String) -> bool:
	if owner == null or role_id == "":
		return false
	var roles_value: Variant = owner.get("roles")
	if roles_value is not Array:
		return role_id == "swordsman"
	for role_value in roles_value:
		if role_value is Dictionary and str((role_value as Dictionary).get("id", "")) == role_id:
			return true
	return false


static func _get_owner_active_role_id(owner) -> String:
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
	var swordsman_state: Variant = states.get("swordsman", {})
	var state: Dictionary = swordsman_state.duplicate(true) if swordsman_state is Dictionary else {}
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


static func _get_role_health_ratio(owner, role_id: String) -> float:
	if owner == null or role_id == "":
		return 1.0
	var role_max_health: float = 1.0
	if owner.has_method("_get_role_max_health"):
		role_max_health = max(1.0, float(owner._get_role_max_health(role_id)))
	var role_current_health: float = role_max_health
	if owner.has_method("_get_role_current_health"):
		role_current_health = float(owner._get_role_current_health(role_id))
	return clamp(role_current_health / role_max_health, 0.0, 1.0)

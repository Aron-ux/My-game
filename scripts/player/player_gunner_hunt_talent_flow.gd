extends RefCounted

const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

const TALENT_HUNT_1 := "gunner_level_talent_hunt_1"
const TALENT_HUNT_2 := "gunner_level_talent_hunt_2"
const GUNNER_NO_HUNT_SOURCE_ROLE_ID := "gunner_no_hunt"

const HUNT_1_STACK_MAX := 50
const HUNT_1_DODGE_VALUE_PER_STACK := 2.0
const HUNT_1_MOVE_SPEED_PER_STACK := 1.0
const HUNT_2_STACK_MAX := 100
const HUNT_2_DAMAGE_MULTIPLIER_PER_STACK := 0.005
const DEFAULT_SAFE_ZONE_RADIUS := 115.0

const STATE_HUNT_1_STACKS := "level_hunt_1_kill_stacks"
const STATE_HUNT_2_STACKS := "level_hunt_2_kill_stacks"


static func on_enemy_killed(owner, source_role_id: String, target_position: Variant, raw_source_role_id: String = "") -> void:
	if owner == null or source_role_id != "gunner" or raw_source_role_id == GUNNER_NO_HUNT_SOURCE_ROLE_ID:
		return
	if not _is_active_gunner(owner) or target_position is not Vector2:
		return
	if not _is_position_outside_hunt_circle(owner, target_position as Vector2):
		return
	var has_hunt_1 := has_level_talent(owner, TALENT_HUNT_1)
	var has_hunt_2 := has_level_talent(owner, TALENT_HUNT_2)
	if not has_hunt_1 and not has_hunt_2:
		return
	var state := _get_state(owner)
	if has_hunt_1:
		state[STATE_HUNT_1_STACKS] = clampi(int(state.get(STATE_HUNT_1_STACKS, 0)) + 1, 0, HUNT_1_STACK_MAX)
	if has_hunt_2:
		state[STATE_HUNT_2_STACKS] = clampi(int(state.get(STATE_HUNT_2_STACKS, 0)) + 1, 0, HUNT_2_STACK_MAX)
	_write_state(owner, state)


static func clear_switch_limited_state(owner) -> void:
	if owner == null:
		return
	var state := _get_state(owner)
	state[STATE_HUNT_1_STACKS] = 0
	state[STATE_HUNT_2_STACKS] = 0
	_write_state(owner, state)


static func get_hunt_1_stacks(owner) -> int:
	if owner == null or not has_level_talent(owner, TALENT_HUNT_1):
		return 0
	return clampi(int(_get_state(owner).get(STATE_HUNT_1_STACKS, 0)), 0, HUNT_1_STACK_MAX)


static func get_hunt_2_stacks(owner) -> int:
	if owner == null or not has_level_talent(owner, TALENT_HUNT_2):
		return 0
	return clampi(int(_get_state(owner).get(STATE_HUNT_2_STACKS, 0)), 0, HUNT_2_STACK_MAX)


static func get_dodge_value(owner, role_id: String) -> float:
	if owner == null or role_id != "gunner" or not _is_active_gunner(owner):
		return 0.0
	return float(get_hunt_1_stacks(owner)) * HUNT_1_DODGE_VALUE_PER_STACK


static func get_move_speed_bonus(owner, role_id: String) -> float:
	if owner == null or role_id != "gunner" or not _is_active_gunner(owner):
		return 0.0
	return float(get_hunt_1_stacks(owner)) * HUNT_1_MOVE_SPEED_PER_STACK


static func get_damage_multiplier(owner, role_id: String) -> float:
	if owner == null or role_id != "gunner" or not _is_active_gunner(owner):
		return 1.0
	return 1.0 + float(get_hunt_2_stacks(owner)) * HUNT_2_DAMAGE_MULTIPLIER_PER_STACK


static func has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)


static func _is_position_outside_hunt_circle(owner, target_position: Vector2) -> bool:
	var owner_position := target_position
	if owner is Node2D:
		owner_position = (owner as Node2D).global_position
	var safe_zone_radius := DEFAULT_SAFE_ZONE_RADIUS
	if owner.has_method("_get_gunner_safe_zone_radius"):
		safe_zone_radius = max(0.0, float(owner._get_gunner_safe_zone_radius()))
	return owner_position.distance_squared_to(target_position) > safe_zone_radius * safe_zone_radius


static func _is_active_gunner(owner) -> bool:
	var role_id := _get_active_role_id(owner)
	return role_id == "" or role_id == "gunner"


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
	var state_value: Variant = states.get("gunner", {})
	var state: Dictionary = state_value.duplicate(true) if state_value is Dictionary else {}
	states["gunner"] = state
	owner.set("role_special_states", states)
	return state


static func _write_state(owner, state: Dictionary) -> void:
	if owner == null:
		return
	var states_value: Variant = owner.get("role_special_states")
	if states_value is not Dictionary:
		return
	var states: Dictionary = states_value as Dictionary
	states["gunner"] = state
	owner.set("role_special_states", states)

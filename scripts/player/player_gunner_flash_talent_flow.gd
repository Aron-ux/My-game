extends RefCounted

const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

const TALENT_EXECUTION_1 := "gunner_level_talent_execution_1"
const TALENT_EXECUTION_2 := "gunner_level_talent_execution_2"

const FLASH_MAX_STACKS := 10
const FLASH_COOLDOWN_DURATION := 15.0
const IMMUNITY_REQUIRED_STACKS := 10
const IMMUNITY_STACK_COST := 5
const IMMUNITY_BUFF_DURATION := 3.0
const IMMUNITY_DODGE_CHANCE := 0.20
const IMMUNITY_MOVE_SPEED_MULTIPLIER := 1.20
const DODGE_PERSISTENT_STACK_MAX := 5

const STATE_DODGE_PERSISTENT_STACKS := "level_execution_dodge_persistent_stacks"
const STATE_IMMUNITY_BUFF_REMAINING := "level_execution_immunity_buff_remaining"


static func tick(owner, delta: float) -> void:
	if owner == null or delta <= 0.0:
		return
	var state := _get_state(owner)
	state[STATE_DODGE_PERSISTENT_STACKS] = clampi(int(state.get(STATE_DODGE_PERSISTENT_STACKS, 0)), 0, DODGE_PERSISTENT_STACK_MAX)
	state[STATE_IMMUNITY_BUFF_REMAINING] = max(0.0, float(state.get(STATE_IMMUNITY_BUFF_REMAINING, 0.0)) - delta)
	_write_state(owner, state)
	clamp_base_flash_stacks(owner)


static func on_successful_dodge(owner) -> void:
	if owner == null or not has_level_talent(owner, TALENT_EXECUTION_2):
		return
	if not _is_active_gunner(owner):
		return
	var state := _get_state(owner)
	var previous_stacks := clampi(int(state.get(STATE_DODGE_PERSISTENT_STACKS, 0)), 0, DODGE_PERSISTENT_STACK_MAX)
	var updated_stacks := clampi(previous_stacks + 1, 0, DODGE_PERSISTENT_STACK_MAX)
	if updated_stacks == previous_stacks:
		return
	state[STATE_DODGE_PERSISTENT_STACKS] = updated_stacks
	_write_state(owner, state)
	clamp_base_flash_stacks(owner)


static func try_immunize_damage(owner) -> bool:
	if owner == null or not has_level_talent(owner, TALENT_EXECUTION_1):
		return false
	if not _is_active_gunner(owner):
		return false
	if float(owner.get("gunner_flash_cooldown_remaining")) > 0.0:
		return false
	clamp_base_flash_stacks(owner)
	if get_total_flash_stacks(owner) < IMMUNITY_REQUIRED_STACKS:
		return false
	if not consume_flash_stacks(owner, IMMUNITY_STACK_COST):
		return false
	if owner.get("gunner_flash_stack_elapsed") != null:
		owner.set("gunner_flash_stack_elapsed", 0.0)
	if owner.get("gunner_flash_cooldown_remaining") != null:
		owner.set("gunner_flash_cooldown_remaining", max(float(owner.get("gunner_flash_cooldown_remaining")), FLASH_COOLDOWN_DURATION))
	var state := _get_state(owner)
	state[STATE_IMMUNITY_BUFF_REMAINING] = IMMUNITY_BUFF_DURATION
	_write_state(owner, state)
	return true


static func consume_flash_stacks(owner, amount: int) -> bool:
	if owner == null or amount <= 0:
		return false
	var total_stacks := get_total_flash_stacks(owner)
	if total_stacks < amount:
		return false
	var base_stacks := _get_base_flash_stacks(owner)
	var base_cost := mini(base_stacks, amount)
	_set_base_flash_stacks(owner, base_stacks - base_cost)
	var persistent_cost := amount - base_cost
	if persistent_cost > 0:
		var state := _get_state(owner)
		state[STATE_DODGE_PERSISTENT_STACKS] = clampi(get_persistent_flash_stacks(owner) - persistent_cost, 0, DODGE_PERSISTENT_STACK_MAX)
		_write_state(owner, state)
	return true


static func clamp_base_flash_stacks(owner) -> void:
	if owner == null:
		return
	var base_capacity := get_base_flash_stack_capacity(owner)
	_set_base_flash_stacks(owner, clampi(_get_base_flash_stacks(owner), 0, base_capacity))


static func get_total_flash_stacks(owner) -> int:
	if owner == null:
		return 0
	return clampi(_get_base_flash_stacks(owner) + get_persistent_flash_stacks(owner), 0, FLASH_MAX_STACKS + DODGE_PERSISTENT_STACK_MAX)


static func get_active_flash_stacks(owner) -> int:
	if owner == null:
		return 0
	if not _is_active_gunner(owner):
		return 0
	return get_total_flash_stacks(owner)


static func get_persistent_flash_stacks(owner) -> int:
	if owner == null or not has_level_talent(owner, TALENT_EXECUTION_2):
		return 0
	var state := _get_state(owner)
	return clampi(int(state.get(STATE_DODGE_PERSISTENT_STACKS, 0)), 0, DODGE_PERSISTENT_STACK_MAX)


static func get_base_flash_stack_capacity(owner) -> int:
	return FLASH_MAX_STACKS


static func get_flat_dodge_chance_bonus(owner, role_id: String) -> float:
	if owner == null or role_id != "gunner" or not _is_active_gunner(owner):
		return 0.0
	if float(_get_state(owner).get(STATE_IMMUNITY_BUFF_REMAINING, 0.0)) <= 0.0:
		return 0.0
	return IMMUNITY_DODGE_CHANCE


static func get_move_speed_multiplier(owner, role_id: String) -> float:
	if owner == null or role_id != "gunner" or not _is_active_gunner(owner):
		return 1.0
	if float(_get_state(owner).get(STATE_IMMUNITY_BUFF_REMAINING, 0.0)) <= 0.0:
		return 1.0
	return IMMUNITY_MOVE_SPEED_MULTIPLIER


static func has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)


static func _get_base_flash_stacks(owner) -> int:
	if owner == null or owner.get("gunner_flash_stacks") == null:
		return 0
	return max(0, int(owner.get("gunner_flash_stacks")))


static func _set_base_flash_stacks(owner, stacks: int) -> void:
	if owner == null or owner.get("gunner_flash_stacks") == null:
		return
	owner.set("gunner_flash_stacks", max(0, stacks))


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

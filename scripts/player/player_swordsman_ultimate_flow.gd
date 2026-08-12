extends RefCounted

const PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW := preload("res://scripts/player/player_swordsman_trait_runtime_flow.gd")

const TALENT_ULTIMATE_1 := "swordsman_level_talent_ultimate_1"
const TALENT_ULTIMATE_2 := "swordsman_level_talent_ultimate_2"
const ULTIMATE_CHAIN_WINDOW_DURATION := 5.0
const ULTIMATE_CHAIN_REFUND_RATIO := 0.10
const ULTIMATE_CHAIN_HEAL_MAX_HEALTH_RATIO := 0.025
const ULTIMATE_CHAIN_HEAL_DAMAGE_RATIO := 0.50

const STATE_ULTIMATE_CHAIN_WINDOW_REMAINING := "level_ultimate_chain_window_remaining"
const STATE_ULTIMATE_CHAIN_REFUND_PENDING := "level_ultimate_chain_refund_pending"
const STATE_ULTIMATE_CHAIN_EXTRA_CAST_PENDING := "level_ultimate_chain_extra_cast_pending"
const STATE_ULTIMATE_CHAIN_BLOODTHIRST_PENDING := "level_ultimate_chain_bloodthirst_pending"
const STATE_ULTIMATE_CHAIN_ENTRY_REMAINING := "level_ultimate_chain_entry_remaining"
const STATE_ULTIMATE_CHAIN_ENTRY_ROLE_ID := "level_ultimate_chain_entry_role_id"
const STATE_ULTIMATE_CHAIN_ENTRY_TRIGGERED := "level_ultimate_chain_entry_triggered"
const STATE_ULTIMATE_CHAIN_PENDING_HEAL_RATIO := "level_ultimate_chain_pending_heal_ratio"
const STATE_ULTIMATE_CHAIN_PENDING_HEAL_MAX_RATIO := "level_ultimate_chain_pending_heal_max_ratio"
const STATE_ULTIMATE_CHAIN_PENDING_CAST_ROLE_ID := "level_ultimate_chain_pending_cast_role_id"
const STATE_ULTIMATE_CHAIN_PENDING_CAST_MULTIPLIER := "level_ultimate_chain_pending_cast_multiplier"
const STATE_ULTIMATE_CHAIN_PENDING_CAST_DAMAGE_MULTIPLIER := "level_ultimate_chain_pending_cast_damage_multiplier"
const STATE_ULTIMATE_CHAIN_PENDING_CAST_REMAINING := "level_ultimate_chain_pending_cast_remaining"


static func has_talent(owner, talent_id: String) -> bool:
	return PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW.has_level_talent(owner, talent_id)


static func can_use_chain_ultimate(owner) -> bool:
	return owner != null and _get_state(owner).get(STATE_ULTIMATE_CHAIN_EXTRA_CAST_PENDING, false) == true


static func start_ultimate_followup_window(owner) -> void:
	if owner == null or not has_talent(owner, TALENT_ULTIMATE_1):
		return
	var state := _get_state(owner)
	state[STATE_ULTIMATE_CHAIN_WINDOW_REMAINING] = ULTIMATE_CHAIN_WINDOW_DURATION
	state[STATE_ULTIMATE_CHAIN_REFUND_PENDING] = true
	state[STATE_ULTIMATE_CHAIN_EXTRA_CAST_PENDING] = false
	state[STATE_ULTIMATE_CHAIN_PENDING_HEAL_RATIO] = 0.0
	state[STATE_ULTIMATE_CHAIN_PENDING_HEAL_MAX_RATIO] = 0.0
	_write_state(owner, state)


static func trigger_ultimate_followup(owner, cast_payload: Dictionary) -> bool:
	if owner == null or not has_talent(owner, TALENT_ULTIMATE_1):
		return false
	var state := _get_state(owner)
	if float(state.get(STATE_ULTIMATE_CHAIN_WINDOW_REMAINING, 0.0)) <= 0.0:
		return false
	state[STATE_ULTIMATE_CHAIN_WINDOW_REMAINING] = 0.0
	state[STATE_ULTIMATE_CHAIN_REFUND_PENDING] = false
	state[STATE_ULTIMATE_CHAIN_EXTRA_CAST_PENDING] = false
	state[STATE_ULTIMATE_CHAIN_PENDING_HEAL_RATIO] = ULTIMATE_CHAIN_HEAL_DAMAGE_RATIO
	state[STATE_ULTIMATE_CHAIN_PENDING_HEAL_MAX_RATIO] = ULTIMATE_CHAIN_HEAL_MAX_HEALTH_RATIO
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_ROLE_ID] = str(owner._get_active_role().get("id", ""))
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_MULTIPLIER] = float(cast_payload.get("damage_multiplier", 1.0)) * 0.60
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_DAMAGE_MULTIPLIER] = float(cast_payload.get("damage_multiplier", 1.0))
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_REMAINING] = 2.0
	_write_state(owner, state)
	return true


static func update(owner, delta: float) -> void:
	if owner == null or delta <= 0.0:
		return
	var state := _get_state(owner)
	var window_remaining := max(0.0, float(state.get(STATE_ULTIMATE_CHAIN_WINDOW_REMAINING, 0.0)) - delta)
	if window_remaining <= 0.0 and bool(state.get(STATE_ULTIMATE_CHAIN_REFUND_PENDING, false)):
		_refund_ultimate_energy(owner)
		state[STATE_ULTIMATE_CHAIN_REFUND_PENDING] = false
		state[STATE_ULTIMATE_CHAIN_WINDOW_REMAINING] = 0.0
	else:
		state[STATE_ULTIMATE_CHAIN_WINDOW_REMAINING] = window_remaining
	var extra_cast_remaining := max(0.0, float(state.get(STATE_ULTIMATE_CHAIN_PENDING_CAST_REMAINING, 0.0)) - delta)
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_REMAINING] = extra_cast_remaining
	_write_state(owner, state)


static func on_ultimate_finished(owner) -> void:
	if owner == null:
		return
	var state := _get_state(owner)
	if not has_talent(owner, TALENT_ULTIMATE_2):
		state[STATE_ULTIMATE_CHAIN_ENTRY_REMAINING] = 0.0
		state[STATE_ULTIMATE_CHAIN_ENTRY_ROLE_ID] = ""
		_write_state(owner, state)
		return
	state[STATE_ULTIMATE_CHAIN_ENTRY_REMAINING] = 4.5
	state[STATE_ULTIMATE_CHAIN_ENTRY_ROLE_ID] = str(owner._get_active_role().get("id", ""))
	state[STATE_ULTIMATE_CHAIN_ENTRY_TRIGGERED] = false
	_write_state(owner, state)


static func transfer_pending_entry_to_role(owner, role_id: String) -> void:
	if owner == null or role_id == "":
		return
	var state := _get_state(owner)
	if not has_talent(owner, TALENT_ULTIMATE_2):
		return
	if float(state.get(STATE_ULTIMATE_CHAIN_ENTRY_REMAINING, 0.0)) <= 0.0:
		return
	if str(state.get(STATE_ULTIMATE_CHAIN_ENTRY_ROLE_ID, "")) == role_id:
		return
	if bool(state.get(STATE_ULTIMATE_CHAIN_ENTRY_TRIGGERED, false)):
		return
	state[STATE_ULTIMATE_CHAIN_ENTRY_TRIGGERED] = true
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_ROLE_ID] = role_id
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_MULTIPLIER] = 1.0
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_DAMAGE_MULTIPLIER] = 1.0
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_REMAINING] = 0.0
	_write_state(owner, state)
	if owner.has_method("_apply_enter_skill"):
		var role_index := _get_role_index(owner, role_id)
		if role_index >= 0:
			owner._apply_enter_skill(role_index)


static func inherit_bloodthirst_to_active_role(owner) -> void:
	if owner == null or not has_talent(owner, TALENT_ULTIMATE_2):
		return
	if float(owner.get("swordsman_entry_trait_share_remaining")) <= 0.0:
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if active_role_id == "" or active_role_id == "swordsman":
		return
	owner._set_role_special_state(active_role_id, "swordsman_entry_bloodthirst_remaining", float(owner.swordsman_entry_trait_share_remaining))
	owner._set_role_special_state(active_role_id, "swordsman_entry_bloodthirst_heal_multiplier", float(owner.swordsman_bloodthirst_heal_multiplier))


static func apply_followup_ultimate_cast(owner, cast_payload: Dictionary) -> Dictionary:
	var state := _get_state(owner)
	if float(state.get(STATE_ULTIMATE_CHAIN_PENDING_CAST_REMAINING, 0.0)) <= 0.0:
		return cast_payload
	var modified := cast_payload.duplicate(true)
	modified["damage_multiplier"] = float(state.get(STATE_ULTIMATE_CHAIN_PENDING_CAST_MULTIPLIER, 1.0))
	modified["ultimate_chain_followup"] = true
	_apply_followup_heal(owner, float(state.get(STATE_ULTIMATE_CHAIN_PENDING_HEAL_RATIO, 0.0)), float(state.get(STATE_ULTIMATE_CHAIN_PENDING_HEAL_MAX_RATIO, 0.0)))
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_REMAINING] = 0.0
	state[STATE_ULTIMATE_CHAIN_PENDING_HEAL_RATIO] = 0.0
	state[STATE_ULTIMATE_CHAIN_PENDING_HEAL_MAX_RATIO] = 0.0
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_ROLE_ID] = ""
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_MULTIPLIER] = 1.0
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_DAMAGE_MULTIPLIER] = 1.0
	_write_state(owner, state)
	return modified


static func consume_pending_followup(owner) -> void:
	if owner == null:
		return
	var state := _get_state(owner)
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_REMAINING] = 0.0
	state[STATE_ULTIMATE_CHAIN_PENDING_HEAL_RATIO] = 0.0
	state[STATE_ULTIMATE_CHAIN_PENDING_HEAL_MAX_RATIO] = 0.0
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_ROLE_ID] = ""
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_MULTIPLIER] = 1.0
	state[STATE_ULTIMATE_CHAIN_PENDING_CAST_DAMAGE_MULTIPLIER] = 1.0
	_write_state(owner, state)


static func _refund_ultimate_energy(owner) -> void:
	if owner == null:
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if active_role_id == "":
		return
	var max_energy: float = 100.0
	if owner.has_method("_get_ultimate_energy_cost"):
		max_energy = max(max_energy, float(owner._get_ultimate_energy_cost()))
	owner._add_energy(max_energy * ULTIMATE_CHAIN_REFUND_RATIO)


static func _apply_followup_heal(owner, heal_max_ratio: float, heal_damage_ratio: float) -> void:
	if owner == null or heal_max_ratio <= 0.0 and heal_damage_ratio <= 0.0:
		return
	var total_heal := 0.0
	if owner.has_method("_get_role_max_health"):
		total_heal += float(owner._get_role_max_health("swordsman")) * heal_max_ratio
	if owner.has_method("_get_role_current_health"):
		total_heal += max(0.0, float(owner._get_role_current_health("swordsman")) * 0.0)
	if owner.has_method("_heal"):
		owner._heal(total_heal)


static func get_followup_cast_multiplier(owner) -> float:
	var state := _get_state(owner)
	return float(state.get(STATE_ULTIMATE_CHAIN_PENDING_CAST_MULTIPLIER, 1.0))


static func get_followup_cast_damage_multiplier(owner) -> float:
	var state := _get_state(owner)
	return float(state.get(STATE_ULTIMATE_CHAIN_PENDING_CAST_DAMAGE_MULTIPLIER, 1.0))


static func should_extend_ultimate_window(owner) -> bool:
	var state := _get_state(owner)
	return float(state.get(STATE_ULTIMATE_CHAIN_WINDOW_REMAINING, 0.0)) > 0.0


static func clear_ultimate_runtime_state(owner) -> void:
	if owner == null:
		return
	_write_state(owner, {})


static func _get_role_index(owner, role_id: String) -> int:
	if owner == null or role_id == "" or not owner.has_method("_get_role_index_by_id"):
		return -1
	return int(owner._get_role_index_by_id(role_id))


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

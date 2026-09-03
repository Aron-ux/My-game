extends SceneTree

const TalentSystem := preload("res://scripts/player/player_skill_talent_system.gd")
const UltimateFlow := preload("res://scripts/player/player_swordsman_ultimate_flow.gd")

const ULTIMATE_1 := "swordsman_level_talent_ultimate_1"
const ULTIMATE_2 := "swordsman_level_talent_ultimate_2"


func _init() -> void:
	var owner := UltimateOwner.new()
	root.add_child(owner)
	_check_definitions()
	_check_followup_window(owner)
	_check_switch_without_inheritance(owner)
	print("SWORDSMAN_ULTIMATE_TALENTS_SMOKE_OK")
	quit()


func _check_definitions() -> void:
	var definitions: Array = TalentSystem.LEVEL_TALENT_DEFINITIONS.get("swordsman", [])
	var ids: Array = []
	for definition_value in definitions:
		if definition_value is Dictionary:
			ids.append(str((definition_value as Dictionary).get("id", "")))
	assert(ids.has(ULTIMATE_1))
	assert(ids.has(ULTIMATE_2))
	assert(TalentSystem._get_level_talent_required_skill_id({"id": ULTIMATE_1}) == "swordsman_ultimate")
	assert(TalentSystem._get_level_talent_required_skill_id({"id": ULTIMATE_2}) == "swordsman_ultimate")
	var definitions_by_id: Dictionary = {}
	for definition_value in definitions:
		if definition_value is Dictionary:
			var definition: Dictionary = definition_value
			definitions_by_id[str(definition.get("id", ""))] = definition
	assert(TalentSystem._get_level_talent_group_id(definitions_by_id[ULTIMATE_1]) == TalentSystem._get_level_talent_group_id(definitions_by_id[ULTIMATE_2]))
	var owner := UltimateOwner.new()
	owner.role_special_states["swordsman"] = {"level_talents": [ULTIMATE_1]}
	var ultimate_definitions: Array = [definitions_by_id[ULTIMATE_1], definitions_by_id[ULTIMATE_2]]
	var candidates: Array = TalentSystem._collect_level_talent_candidates(owner, ultimate_definitions, {}, false)
	assert(not _has_candidate(candidates, ULTIMATE_2))
	owner.role_special_states["swordsman"] = {"level_talents": [ULTIMATE_2]}
	candidates = TalentSystem._collect_level_talent_candidates(owner, ultimate_definitions, {}, false)
	assert(not _has_candidate(candidates, ULTIMATE_1))
	owner.free()


func _check_followup_window(owner: UltimateOwner) -> void:
	owner.level_talents = {ULTIMATE_1: true}
	UltimateFlow.start_ultimate_followup_window(owner)
	assert(UltimateFlow.can_use_chain_ultimate(owner))
	var payload := {"damage_multiplier": 2.0}
	assert(UltimateFlow.trigger_ultimate_followup(owner, payload))
	var modified := UltimateFlow.apply_followup_ultimate_cast(owner, payload)
	assert(is_equal_approx(float(modified["damage_multiplier"]), 1.2))
	assert(bool(modified["ultimate_chain_followup"]))
	assert(not UltimateFlow.can_use_chain_ultimate(owner))
	UltimateFlow.begin_ultimate(owner, 0.38, true)
	UltimateFlow.on_ultimate_finished(owner)
	assert(not UltimateFlow.can_use_chain_ultimate(owner))
	owner.role_mana_values["swordsman"] = 0.0
	UltimateFlow.start_ultimate_followup_window(owner)
	UltimateFlow.update(owner, 5.1)
	assert(is_equal_approx(float(owner.role_mana_values["swordsman"]), 10.0))


func _check_switch_without_inheritance(owner: UltimateOwner) -> void:
	owner.level_talents = {ULTIMATE_2: true}
	owner.swordsman_entry_trait_share_remaining = 4.5
	owner.swordsman_bloodthirst_heal_multiplier = 1.5
	UltimateFlow.begin_ultimate(owner, 1.0)
	assert(UltimateFlow.can_switch_during_ultimate(owner))
	owner.player_action_lock_remaining = 2.0
	UltimateFlow.release_action_lock_for_switch(owner)
	assert(is_zero_approx(owner.player_action_lock_remaining))
	assert(UltimateFlow.should_force_entry_during_ultimate(owner))
	UltimateFlow.record_ultimate_switch(owner, "gunner")
	assert(not UltimateFlow.should_force_entry_during_ultimate(owner))
	UltimateFlow.on_ultimate_finished(owner)
	var gunner_state: Dictionary = owner.role_special_states["gunner"]
	assert(not gunner_state.has("swordsman_entry_bloodthirst_remaining"))
	assert(not gunner_state.has("swordsman_entry_bloodthirst_heal_multiplier"))


func _has_candidate(candidates: Array, talent_id: String) -> bool:
	for candidate_value in candidates:
		if candidate_value is Dictionary and str((candidate_value as Dictionary).get("id", "")) == talent_id:
			return true
	return false


class UltimateOwner:
	extends Node2D

	var level_talents: Dictionary = {}
	var role_special_states: Dictionary = {"swordsman": {}, "gunner": {}, "mage": {}}
	var roles: Array = [{"id": "swordsman"}, {"id": "gunner"}, {"id": "mage"}]
	var active_role_index: int = 0
	var role_mana_values: Dictionary = {"swordsman": 0.0, "gunner": 0.0, "mage": 0.0}
	var player_action_lock_remaining: float = 0.0
	var swordsman_entry_trait_share_remaining: float = 0.0
	var swordsman_bloodthirst_heal_multiplier: float = 1.0

	func _has_level_talent(talent_id: String) -> bool:
		return bool(level_talents.get(talent_id, false))

	func _get_active_role() -> Dictionary:
		return roles[active_role_index]

	func _get_active_role_id() -> String:
		return str(_get_active_role().get("id", ""))

	func _unlock_player_actions() -> void:
		player_action_lock_remaining = 0.0

	func _get_role_special_state(role_id: String) -> Dictionary:
		if not role_special_states.has(role_id):
			role_special_states[role_id] = {}
		return role_special_states[role_id]

	func _get_role_max_health(_role_id: String) -> float:
		return 100.0

	func _get_role_mana(role_id: String) -> float:
		return float(role_mana_values.get(role_id, 0.0))

	func _set_role_mana(role_id: String, value: float, _emit_signal: bool = true) -> void:
		role_mana_values[role_id] = value

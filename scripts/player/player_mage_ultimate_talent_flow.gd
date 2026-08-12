extends RefCounted

const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

const TALENT_ARCANE_BOMBARDMENT_1 := "mage_level_talent_arcane_bombardment_1"
const TALENT_ARCANE_BOMBARDMENT_2 := "mage_level_talent_arcane_bombardment_2"
const ULTIMATE_SOURCE_PREFIX := "mage_ultimate:"
const EXTRA_BOMBARD_COUNT := 3
const ENERGY_BONUS_MULTIPLIER := 1.0
const BASE_DAMAGE_MULTIPLIER_BONUS := 0.05
const PERMANENT_DAMAGE_BONUS_PER_KILL := 0.0005
const PERMANENT_DAMAGE_STACKS_KEY := "arcane_bombardment_permanent_damage_kills"


static func has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)


static func make_damage_source_id(pulse_index: int) -> String:
	return "%s%d" % [ULTIMATE_SOURCE_PREFIX, max(0, pulse_index)]


static func is_ultimate_source(source_role_id: String, resolved_role_id: String = "") -> bool:
	return source_role_id.begins_with(ULTIMATE_SOURCE_PREFIX) or (source_role_id == "mage_ultimate" and (resolved_role_id == "" or resolved_role_id == "mage"))


static func get_extra_bombard_count(owner) -> int:
	return EXTRA_BOMBARD_COUNT if has_level_talent(owner, TALENT_ARCANE_BOMBARDMENT_1) else 0


static func get_ultimate_energy_bonus_multiplier(owner, source_role_id: String, resolved_role_id: String = "") -> float:
	if not is_ultimate_source(source_role_id, resolved_role_id):
		return 0.0
	return ENERGY_BONUS_MULTIPLIER if has_level_talent(owner, TALENT_ARCANE_BOMBARDMENT_1) else 0.0


static func get_pulse_damage_multiplier(owner) -> float:
	var multiplier := 1.0
	if has_level_talent(owner, TALENT_ARCANE_BOMBARDMENT_2):
		multiplier += BASE_DAMAGE_MULTIPLIER_BONUS
		multiplier += float(get_permanent_damage_kill_count(owner)) * PERMANENT_DAMAGE_BONUS_PER_KILL
	return multiplier


static func on_ultimate_bombardment_killed(owner, source_role_id: String, resolved_role_id: String = "") -> void:
	if owner == null or not is_ultimate_source(source_role_id, resolved_role_id):
		return
	if not has_level_talent(owner, TALENT_ARCANE_BOMBARDMENT_2):
		return
	var state: Dictionary = owner._get_role_special_state("mage") if owner.has_method("_get_role_special_state") else {}
	state[PERMANENT_DAMAGE_STACKS_KEY] = max(0, int(state.get(PERMANENT_DAMAGE_STACKS_KEY, 0))) + 1
	if owner.get("role_special_states") is Dictionary:
		owner.role_special_states["mage"] = state


static func get_permanent_damage_kill_count(owner) -> int:
	if owner == null or not owner.has_method("_get_role_special_state"):
		return 0
	var state: Dictionary = owner._get_role_special_state("mage")
	return max(0, int(state.get(PERMANENT_DAMAGE_STACKS_KEY, 0)))

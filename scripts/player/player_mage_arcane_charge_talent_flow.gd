extends RefCounted

const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

const TALENT_ARCANE_CHARGE_1 := "mage_level_talent_arcane_charge_1"
const TALENT_ARCANE_CHARGE_2 := "mage_level_talent_arcane_charge_2"

const PROC_CHANCE_BONUS := 0.05
const COOLDOWN_REDUCTION_PER_STACK := 0.01
const ULTIMATE_DAMAGE_PER_STACK := 0.02


static func get_proc_chance_bonus(owner) -> float:
	var bonus := 0.0
	if has_level_talent(owner, TALENT_ARCANE_CHARGE_1):
		bonus += PROC_CHANCE_BONUS
	if has_level_talent(owner, TALENT_ARCANE_CHARGE_2):
		bonus += PROC_CHANCE_BONUS
	return bonus


static func get_skill_cooldown_multiplier(owner, role_id: String = "") -> float:
	if not has_level_talent(owner, TALENT_ARCANE_CHARGE_1):
		return 1.0
	var stacks := get_effective_stacks(owner, role_id)
	return max(0.0, 1.0 - float(stacks) * COOLDOWN_REDUCTION_PER_STACK)


static func get_ultimate_damage_multiplier(owner, role_id: String = "") -> float:
	if not has_level_talent(owner, TALENT_ARCANE_CHARGE_2):
		return 1.0
	var stacks := get_effective_stacks(owner, role_id)
	return 1.0 + float(stacks) * ULTIMATE_DAMAGE_PER_STACK


static func get_effective_stacks(owner, role_id: String = "") -> int:
	if owner == null:
		return 0
	var resolved_role_id := role_id if role_id != "" else _get_active_role_id(owner)
	if resolved_role_id == "":
		return 0
	if owner.has_method("_get_mage_arcane_charge_effective_stacks_for_role"):
		return max(0, int(owner._get_mage_arcane_charge_effective_stacks_for_role(resolved_role_id)))
	return 0


static func has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)


static func _get_active_role_id(owner) -> String:
	if owner == null:
		return ""
	if owner.has_method("_get_active_role_id"):
		return str(owner._get_active_role_id())
	if owner.has_method("_get_active_role"):
		var active_role: Variant = owner._get_active_role()
		return str(active_role.get("id", "")) if active_role is Dictionary else ""
	return ""

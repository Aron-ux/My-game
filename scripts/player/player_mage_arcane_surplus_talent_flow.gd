extends RefCounted

const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

const TALENT_ARCANE_SURPLUS_1 := "mage_level_talent_arcane_surplus_1"
const TALENT_ARCANE_SURPLUS_2 := "mage_level_talent_arcane_surplus_2"

const DAMAGE_BONUS := 0.10
const COOLDOWN_TICK_TIME_SCALE := 0.90


static func get_damage_multiplier(owner, role_id: String = "") -> float:
	if not has_level_talent(owner, TALENT_ARCANE_SURPLUS_1):
		return 1.0
	if not is_role_under_arcane_surplus(owner, role_id):
		return 1.0
	return 1.0 + DAMAGE_BONUS


static func get_skill_cooldown_tick_multiplier(owner, role_id: String = "") -> float:
	if not has_level_talent(owner, TALENT_ARCANE_SURPLUS_2):
		return 1.0
	if not is_role_under_arcane_surplus(owner, role_id):
		return 1.0
	return 1.0 / COOLDOWN_TICK_TIME_SCALE


static func apply_skill_cooldown_tick_bonus(owner, ability, role_id: String, delta: float) -> void:
	if ability == null or delta <= 0.0:
		return
	var tick_multiplier := get_skill_cooldown_tick_multiplier(owner, role_id)
	if tick_multiplier <= 1.0:
		return
	if ability.get("cooldown_remaining") == null:
		return
	var previous_remaining: float = max(0.0, float(ability.get("cooldown_remaining")))
	if previous_remaining <= 0.0:
		return
	var bonus_delta: float = delta * (tick_multiplier - 1.0)
	ability.set("cooldown_remaining", max(0.0, previous_remaining - bonus_delta))


static func is_role_under_arcane_surplus(owner, role_id: String = "") -> bool:
	if owner == null:
		return false
	if float(owner.get("mage_arcane_surplus_remaining")) <= 0.0:
		return false
	var active_role_id := _get_active_role_id(owner)
	var resolved_role_id := role_id if role_id != "" else active_role_id
	return resolved_role_id != "" and resolved_role_id == active_role_id


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

extends SceneTree

const PLAYER_COMBAT_RESULT_FLOW := preload("res://scripts/player/player_combat_result_flow.gd")
const PLAYER_DAMAGE_HELPERS := preload("res://scripts/player/player_damage_helpers.gd")
const PLAYER_SWORDSMAN_BATTLE_WILL_FLOW := preload("res://scripts/player/player_swordsman_battle_will_flow.gd")
const ROLE_ATTRIBUTE_RULES := preload("res://scripts/player/roles/role_attribute_rules.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_trait_values()
	_check_multi_target_cap_and_cooldown()
	_check_background_level_talent_shared_will()
	_check_low_health_level_talent_forced_trigger()
	_check_low_health_level_talent_timer()
	_check_damage_helper_no_longer_applies_old_trait_heal()

	if failures.is_empty():
		print("SWORDSMAN_TRAIT_HEAL_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_trait_values() -> void:
	if not is_equal_approx(ROLE_ATTRIBUTE_RULES.get_swordsman_trait_heal_proc_chance(0.0), 0.05):
		failures.append("swordsman trait proc chance should be 5 percent")
	if not is_equal_approx(ROLE_ATTRIBUTE_RULES.get_swordsman_trait_heal_amount(0.0), 0.03):
		failures.append("swordsman trait max health heal ratio should be 3 percent")
	if not is_equal_approx(ROLE_ATTRIBUTE_RULES.SWORDSMAN_TRAIT_MISSING_HEAL_RATIO, 0.03):
		failures.append("swordsman trait missing health heal ratio should be 3 percent")
	if ROLE_ATTRIBUTE_RULES.SWORDSMAN_TRAIT_MAX_ROLL_HITS != 2:
		failures.append("swordsman trait should roll at most 2 hits for one multi-target result")


func _check_multi_target_cap_and_cooldown() -> void:
	var owner := OwnerStub.new()
	owner.proc_chance = 1.0
	owner.current_health = 50.0
	PLAYER_COMBAT_RESULT_FLOW.apply_swordsman_trait_heal_on_hit(owner, "swordsman", 6)
	var expected_heal := 8.865
	if not is_equal_approx(owner.healed_amount, expected_heal):
		failures.append("swordsman multi-target heal should cap at 2 triggers, got %.3f" % owner.healed_amount)
	if not is_equal_approx(owner.current_health, 58.865):
		failures.append("swordsman current health should receive capped heal, got %.3f" % owner.current_health)
	if not is_equal_approx(owner.swordsman_trait_heal_cooldown_remaining, ROLE_ATTRIBUTE_RULES.SWORDSMAN_TRAIT_HEAL_COOLDOWN):
		failures.append("swordsman trait should start 1 second cooldown after successful triggers")
	PLAYER_COMBAT_RESULT_FLOW.apply_swordsman_trait_heal_on_hit(owner, "swordsman", 6)
	if not is_equal_approx(owner.healed_amount, expected_heal):
		failures.append("swordsman trait should not heal again while cooldown is active")
	owner.free()


func _check_background_level_talent_shared_will() -> void:
	var owner := OwnerStub.new()
	owner.active_role_id = "gunner"
	owner.proc_chance = 2.0
	owner.role_health_values["gunner"] = 50.0
	owner.level_talents["swordsman_level_talent_battle_will_1"] = true
	PLAYER_COMBAT_RESULT_FLOW.apply_swordsman_trait_heal_on_hit(owner, "gunner", 1)
	var expected_heal := 0.9
	if not is_equal_approx(owner.healed_amount, expected_heal):
		failures.append("background battle will should heal active role by reduced amount, got %.3f" % owner.healed_amount)
	if not is_equal_approx(float(owner.role_health_values["gunner"]), 50.9):
		failures.append("background battle will should heal gunner current health, got %.3f" % float(owner.role_health_values["gunner"]))
	owner.free()


func _check_low_health_level_talent_forced_trigger() -> void:
	var owner := OwnerStub.new()
	owner.proc_chance = 0.0
	owner.current_health = 9.0
	owner.swordsman_trait_heal_cooldown_remaining = 99.0
	owner.level_talents["swordsman_level_talent_battle_will_2"] = true
	PLAYER_COMBAT_RESULT_FLOW.apply_swordsman_trait_heal_on_hit(owner, "swordsman", 1)
	var expected_heal := 8.595
	if not is_equal_approx(owner.healed_amount, expected_heal):
		failures.append("low health battle will should force one 1.5x heal, got %.3f" % owner.healed_amount)
	if not is_equal_approx(owner.current_health, 17.595):
		failures.append("low health battle will should update swordsman health, got %.3f" % owner.current_health)
	if not is_equal_approx(owner.swordsman_trait_heal_cooldown_remaining, ROLE_ATTRIBUTE_RULES.SWORDSMAN_TRAIT_HEAL_COOLDOWN):
		failures.append("forced low health battle will should bypass old cooldown and restart normal cooldown")
	var state: Dictionary = owner.role_special_states["swordsman"]
	if float(state.get("battle_will_low_health_remaining", 0.0)) <= 0.0:
		failures.append("low health battle will should open a timed 1.5x window")
	if bool(state.get("battle_will_low_health_force_trigger", false)):
		failures.append("forced low health battle will should consume the guaranteed trigger")
	owner.free()


func _check_low_health_level_talent_timer() -> void:
	var owner := OwnerStub.new()
	owner.current_health = 9.0
	owner.level_talents["swordsman_level_talent_battle_will_2"] = true
	PLAYER_SWORDSMAN_BATTLE_WILL_FLOW.tick(owner, 1.0)
	var state: Dictionary = owner.role_special_states["swordsman"]
	if not is_equal_approx(float(state.get("battle_will_low_health_remaining", 0.0)), 4.0):
		failures.append("low health battle will timer should tick from 5s to 4s, got %.3f" % float(state.get("battle_will_low_health_remaining", 0.0)))
	PLAYER_SWORDSMAN_BATTLE_WILL_FLOW.tick(owner, 6.0)
	if not is_zero_approx(float(owner.role_special_states["swordsman"].get("battle_will_low_health_remaining", 0.0))):
		failures.append("low health battle will timer should expire to zero")
	owner.free()


func _check_damage_helper_no_longer_applies_old_trait_heal() -> void:
	var owner := OwnerStub.new()
	owner.proc_chance = 1.0
	owner.current_health = 50.0
	PLAYER_DAMAGE_HELPERS.apply_role_damage_lifesteal(owner, "swordsman", 20.0)
	if owner.healed_amount > 0.0:
		failures.append("damage helper should not apply the old per-damage swordsman trait heal")
	owner.free()


class OwnerStub:
	extends Node2D

	var swordsman_trait_heal_cooldown_remaining: float = 0.0
	var swordsman_entry_trait_share_remaining: float = 0.0
	var swordsman_bloodthirst_heal_multiplier: float = 1.0
	var max_health: float = 100.0
	var current_health: float = 100.0
	var healed_amount: float = 0.0
	var proc_chance: float = 0.05
	var roles: Array = [{"id": "swordsman"}, {"id": "gunner"}, {"id": "mage"}]
	var active_role_id: String = "swordsman"
	var role_special_states: Dictionary = {"swordsman": {}, "gunner": {}, "mage": {}}
	var level_talents: Dictionary = {}
	var role_health_values: Dictionary = {"gunner": 100.0, "mage": 100.0}
	var role_max_health_values: Dictionary = {"gunner": 100.0, "mage": 100.0}

	func _get_swordsman_trait_heal_proc_chance() -> float:
		return proc_chance

	func _get_swordsman_trait_heal_amount() -> float:
		return ROLE_ATTRIBUTE_RULES.get_swordsman_trait_heal_amount(0.0)

	func _get_active_role_id() -> String:
		return active_role_id

	func _get_active_role() -> Dictionary:
		for role_data in roles:
			if str(role_data.get("id", "")) == active_role_id:
				return role_data
		return {}

	func _has_level_talent(talent_id: String) -> bool:
		return bool(level_talents.get(talent_id, false))

	func _get_role_special_state(role_id: String) -> Dictionary:
		if not role_special_states.has(role_id) or role_special_states[role_id] is not Dictionary:
			role_special_states[role_id] = {}
		return role_special_states[role_id]

	func _get_role_max_health(role_id: String) -> float:
		return max_health if role_id == "swordsman" else float(role_max_health_values.get(role_id, 0.0))

	func _get_role_current_health(role_id: String) -> float:
		return current_health if role_id == "swordsman" else float(role_health_values.get(role_id, 0.0))

	func _heal(amount: float) -> void:
		var heal_amount: float = max(0.0, amount)
		if heal_amount <= 0.0:
			return
		var role_id: String = active_role_id
		var previous_health: float = _get_role_current_health(role_id)
		var next_health: float = min(_get_role_max_health(role_id), previous_health + heal_amount)
		if role_id == "swordsman":
			current_health = next_health
		else:
			role_health_values[role_id] = next_health
		healed_amount += next_health - previous_health

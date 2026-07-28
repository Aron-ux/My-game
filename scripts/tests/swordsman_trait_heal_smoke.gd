extends SceneTree

const PLAYER_COMBAT_RESULT_FLOW := preload("res://scripts/player/player_combat_result_flow.gd")
const PLAYER_DAMAGE_HELPERS := preload("res://scripts/player/player_damage_helpers.gd")
const ROLE_ATTRIBUTE_RULES := preload("res://scripts/player/roles/role_attribute_rules.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_trait_values()
	_check_multi_target_cap_and_cooldown()
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

	func _get_swordsman_trait_heal_proc_chance() -> float:
		return proc_chance

	func _get_swordsman_trait_heal_amount() -> float:
		return ROLE_ATTRIBUTE_RULES.get_swordsman_trait_heal_amount(0.0)

	func _get_role_max_health(role_id: String) -> float:
		return max_health if role_id == "swordsman" else 0.0

	func _get_role_current_health(role_id: String) -> float:
		return current_health if role_id == "swordsman" else 0.0

	func _heal(amount: float) -> void:
		var previous_health := current_health
		current_health = min(max_health, current_health + max(0.0, amount))
		healed_amount += current_health - previous_health

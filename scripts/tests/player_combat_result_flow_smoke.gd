extends SceneTree

const PlayerCombatResultFlow := preload("res://scripts/player/player_combat_result_flow.gd")
const DamageResolver := preload("res://scripts/player/player_damage_resolver.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_kill_energy_sources()
	_check_boss_damage_energy_source()
	_check_damage_resolver_special_enemy_energy()
	if failures.is_empty():
		print("PLAYER_COMBAT_RESULT_FLOW_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_kill_energy_sources() -> void:
	var normal_enemy := _make_enemy("normal", 1)
	var elite_enemy := _make_enemy("elite", 1)
	var high_tier_enemy := _make_enemy("normal", 4)
	var boss_enemy := _make_enemy("boss", 1)
	var small_boss_enemy := _make_enemy("small_boss", 1)
	_assert_close(PlayerCombatResultFlow.get_kill_energy_from_enemy(normal_enemy), 0.8 * 0.75 * 1.2, "normal kill energy should include 20 percent source bonus")
	_assert_close(PlayerCombatResultFlow.get_kill_energy_from_enemy(elite_enemy), 10.0 * 0.75 * 1.2, "elite kill energy should include 20 percent source bonus")
	_assert_close(PlayerCombatResultFlow.get_kill_energy_from_enemy(high_tier_enemy), 2.0 * 0.75 * 1.2, "high tier kill energy should include 20 percent source bonus")
	_assert_close(PlayerCombatResultFlow.get_kill_energy_from_enemy(boss_enemy), 0.0, "boss kill should not use kill energy")
	_assert_close(PlayerCombatResultFlow.get_kill_energy_from_enemy(small_boss_enemy), 0.0, "small boss kill should not use normal kill energy")


func _check_boss_damage_energy_source() -> void:
	_assert_close(PlayerCombatResultFlow.get_boss_damage_energy(25.0), sqrt(25.0) * 0.18 * 1.2, "boss damage energy should include 20 percent source bonus")
	_assert_close(PlayerCombatResultFlow.get_boss_damage_energy(1.0), 0.25 * 1.2, "boss damage minimum energy should include 20 percent source bonus")
	_assert_close(PlayerCombatResultFlow.get_boss_damage_energy(10000.0), 2.0 * 1.2, "boss damage maximum energy should include 20 percent source bonus")


func _check_damage_resolver_special_enemy_energy() -> void:
	var owner := BossEnergyOwner.new()
	var boss_enemy := _make_damageable_enemy("boss")
	var small_boss_enemy := _make_damageable_enemy("small_boss")
	var normal_enemy := _make_damageable_enemy("normal")
	DamageResolver.deal_damage_to_enemy(owner, boss_enemy, 25.0, "swordsman")
	_assert_close(owner.boss_energy, PlayerCombatResultFlow.get_boss_damage_energy(25.0), "boss damage should add boss damage energy")
	owner.boss_energy = 0.0
	DamageResolver.deal_damage_to_enemy(owner, small_boss_enemy, 25.0, "swordsman")
	_assert_close(owner.boss_energy, PlayerCombatResultFlow.get_boss_damage_energy(25.0), "small boss damage should add boss damage energy")
	owner.boss_energy = 0.0
	DamageResolver.deal_damage_to_enemy(owner, normal_enemy, 25.0, "swordsman")
	_assert_close(owner.boss_energy, 0.0, "normal damage should not add boss damage energy")


func _make_enemy(kind: String, reward_tier_value: int) -> TestEnemy:
	var enemy := TestEnemy.new()
	enemy.enemy_kind = kind
	enemy.reward_tier = reward_tier_value
	return enemy


func _make_damageable_enemy(kind: String) -> DamageableEnemy:
	var enemy := DamageableEnemy.new()
	enemy.enemy_kind = kind
	return enemy


func _assert_close(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s, got %.4f expected %.4f" % [message, actual, expected])


class TestEnemy:
	extends Node

	var enemy_kind: String = "normal"
	var reward_tier: int = 1


class BossEnergyOwner:
	extends Node2D

	var boss_energy: float = 0.0

	func _add_boss_damage_energy(amount: float) -> void:
		boss_energy += amount

	func _get_boss_damage_energy(damage_amount: float) -> float:
		return PlayerCombatResultFlow.get_boss_damage_energy(damage_amount)


class DamageableEnemy:
	extends Node2D

	var enemy_kind: String = "normal"
	var current_health: float = 100.0

	func take_damage(amount: float, _is_critical: bool = false) -> bool:
		current_health -= amount
		return current_health <= 0.0

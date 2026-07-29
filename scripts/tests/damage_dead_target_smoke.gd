extends SceneTree

const DamageResolver := preload("res://scripts/player/player_damage_resolver.gd")
const DamageJobQueue := preload("res://scripts/player/player_damage_job_queue.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_direct_damage_skips_dead_enemy()
	_check_queued_damage_skips_dead_enemy()
	if failures.is_empty():
		print("DAMAGE_DEAD_TARGET_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_direct_damage_skips_dead_enemy() -> void:
	var owner := DamageOwner.new()
	var enemy := DeadEnemy.new()
	DamageResolver.deal_damage_to_enemy(owner, enemy, 10.0, "gunner")
	if enemy.damage_calls != 0:
		failures.append("direct damage should skip dead enemies")
	owner.free()
	enemy.free()


func _check_queued_damage_skips_dead_enemy() -> void:
	var owner := DamageOwner.new()
	var enemy := DeadEnemy.new()
	var queue := DamageJobQueue.new()
	queue.configure(owner)
	queue.enqueue_values(weakref(enemy), enemy.get_instance_id(), 10.0, 1, "gunner")
	queue._apply_job_at_index(0)
	if enemy.damage_calls != 0:
		failures.append("queued damage should skip dead enemies")
	queue.free()
	owner.free()
	enemy.free()


class DamageOwner:
	extends Node2D

	func _deal_damage_to_enemy(enemy: Node, damage_amount: float, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0, source_position: Variant = null, suppress_status_visual: bool = false, kill_energy_bonus: float = 0.0) -> bool:
		return DamageResolver.deal_damage_to_enemy(self, enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position, suppress_status_visual, kill_energy_bonus)


class DeadEnemy:
	extends Node2D

	var current_health: float = 0.0
	var damage_calls: int = 0

	func take_damage(_amount: float, _is_critical: bool = false) -> bool:
		damage_calls += 1
		return false

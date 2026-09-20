extends Node2D

const ENEMY := preload("res://scenes/enemy.tscn")
const BULLET := preload("res://scenes/enemy_bullet.tscn")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const SPAWN_BUDGET := preload("res://scripts/game/runtime_spawn_budget_flow.gd")
var runtime_spawn_budget_frame := -1
var runtime_spawn_counts: Dictionary = {}
var active: Dictionary = {}
var pool: Dictionary = {}
var player: Node2D
var peak_count := 0
var registered_count := 0
var ordinary_budget_calls := 0
var runtime_enemy_projectile_pool_nodes: Dictionary:
	get:
		return pool
var runtime_enemy_projectile_pool_cache_dirty := false


func make_boss() -> Node2D:
	var boss = ENEMY.instantiate()
	boss.apply_enemy_profile("boss", DATABASE.get_profile("boss", "boss_spellcore"))
	boss.projectile_scene = BULLET
	add_child(boss)
	boss.set_physics_process(false)
	boss.target = player
	boss.attack = 80.0
	boss.projectile_damage = 29.6
	boss._ensure_boss_helpers()
	return boss


func clear_bullets() -> void:
	for bullet in active.values() + pool.values():
		if is_instance_valid(bullet):
			bullet.free()
	active.clear()
	pool.clear()


func register_runtime_enemy_projectile(bullet: Node, pooled: bool) -> void:
	var key := bullet.get_instance_id()
	active.erase(key)
	pool.erase(key)
	if pooled:
		pool[key] = bullet
	else:
		active[key] = bullet
		registered_count += 1
		peak_count = maxi(peak_count, active.size())


func unregister_runtime_enemy_projectile(bullet: Node) -> void:
	active.erase(bullet.get_instance_id())
	pool.erase(bullet.get_instance_id())


func get_runtime_enemy_projectiles() -> Array:
	return active.values()


func get_runtime_enemy_projectile_pool() -> Array:
	return pool.values()


func take_runtime_enemy_projectile_from_pool() -> Node:
	return preload("res://scripts/game/runtime_projectile_registry_flow.gd").take_runtime_enemy_projectile_from_pool(self)


func _is_runtime_node_valid(node: Node) -> bool:
	return is_instance_valid(node) and not node.is_queued_for_deletion()


func _can_spawn_runtime_group(group: String, limit: int) -> bool:
	if group == "enemy_projectiles":
		ordinary_budget_calls += 1
	return SPAWN_BUDGET.can_spawn_runtime_group(self, group, limit)


func _trim_spawn_count_for_group(group: String, count: int, limit: int) -> int:
	if group == "enemy_projectiles":
		ordinary_budget_calls += 1
	return SPAWN_BUDGET.trim_spawn_count_for_group(self, group, count, limit)


func _get_difficulty_limit(_key: String, _fallback: int) -> int:
	return 180


class Target:
	extends Node2D
	var damage_taken := 0.0
	var hits := 0
	func get_hurtbox_center() -> Vector2:
		return global_position
	func get_hurtbox_radius() -> float:
		return 8.0
	func take_damage(amount: float) -> void:
		damage_taken += amount
		hits += 1

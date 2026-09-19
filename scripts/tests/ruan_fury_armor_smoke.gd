extends SceneTree

const ENEMY := preload("res://scenes/enemy.tscn")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const FLOW := preload("res://scripts/player/player_ruan_stone_flow.gd")
const SYSTEM := preload("res://scripts/player/ruan_stone_system.gd")
const STATUS := preload("res://scripts/enemies/enemy_status_effects.gd")
const DAMAGE := preload("res://scripts/enemies/enemy_damage.gd")
const POOL := preload("res://scripts/enemies/enemy_pool_lifecycle.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var target := Node2D.new()
	scene.add_child(target)
	var enemy = ENEMY.instantiate()
	enemy.target = target
	scene.add_child(enemy)
	enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", "chaser"))
	enemy.max_health = 1000.0
	enemy.current_health = 1000.0
	var values := SYSTEM.get_stacked_effect_values("fury", 1)
	FLOW._apply_fury(enemy, values)
	assert(is_equal_approx(enemy.armor, 5.0))
	assert(is_equal_approx(enemy.fury_armor_shred, 5.0))
	DAMAGE.apply_damage(enemy, 100.0, false)
	assert(is_equal_approx(enemy.current_health, 900.0))
	STATUS.tick_timers(enemy, 1.5)
	FLOW._apply_fury(enemy, values)
	assert(is_equal_approx(enemy.fury_armor_shred, 5.0))
	assert(is_equal_approx(enemy.fury_armor_shred_remaining, 2.0))
	FLOW._apply_fury(enemy, SYSTEM.get_stacked_effect_values("fury", 2))
	assert(is_equal_approx(enemy.fury_armor_shred, 10.0))
	DAMAGE.apply_damage(enemy, 105.0, false)
	assert(is_equal_approx(enemy.current_health, 790.0))
	STATUS.tick_timers(enemy, 0.5)
	var saved: Dictionary = enemy.get_save_data()
	var restored = ENEMY.instantiate()
	scene.add_child(restored)
	restored.apply_save_data(saved, target)
	assert(is_equal_approx(restored.fury_armor_shred, 10.0))
	assert(is_equal_approx(restored.fury_armor_shred_remaining, 1.5))
	STATUS.tick_timers(restored, 1.5)
	assert(is_zero_approx(restored.fury_armor_shred))
	DAMAGE.apply_damage(restored, 105.0, false)
	assert(is_equal_approx(restored.current_health, 690.0))
	FLOW._apply_fury(restored, values)
	POOL.prepare_for_pool(restored)
	assert(is_zero_approx(restored.fury_armor_shred))
	assert(is_zero_approx(restored.fury_armor_shred_remaining))
	scene.free()
	current_scene = null
	print("RUAN_FURY_ARMOR_SMOKE_OK")
	quit(0)

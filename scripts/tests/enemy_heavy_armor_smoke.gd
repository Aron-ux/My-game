extends SceneTree

const FORM := preload("res://scripts/enemies/enemy_heavy_armor_form.gd")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const DAMAGE := preload("res://scripts/enemies/enemy_damage.gd")
const MOVEMENT := preload("res://scripts/enemies/enemy_movement.gd")
const POOL := preload("res://scripts/enemies/enemy_pool_lifecycle.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var target := Target.new()
	scene.add_child(target)
	var enemy = ENEMY.instantiate()
	enemy.target = target
	scene.add_child(enemy)
	enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", "brute"))
	enemy.current_health = enemy.max_health
	enemy._cached_direction_to_target = Vector2.RIGHT
	assert(is_equal_approx(enemy.attack, 15.0))
	assert(is_equal_approx(enemy.max_health, 60.0))
	assert(is_equal_approx(enemy.armor, 20.0))
	assert(is_equal_approx(MOVEMENT.compute_velocity(enemy, 0.0).length(), 42.0))
	assert(not FORM.is_active(enemy))
	FORM.tick(enemy, 19.0)
	assert(not FORM.is_active(enemy))
	FORM.tick(enemy, 1.0)
	assert(FORM.is_active(enemy))
	assert(is_equal_approx(enemy.heavy_armor_cooldown, 20.0))
	assert(is_equal_approx(MOVEMENT.compute_velocity(enemy, 0.0).length(), 21.0))
	assert(enemy.get_node("ProfileVisual").sprite.material != null)
	DAMAGE.apply_damage(enemy, 42.0, false)
	assert(is_equal_approx(enemy.current_health, 30.0))
	assert(is_equal_approx(target.received, 1.5))
	# Armor loss during the form must survive expiry and save/restore.
	enemy.armor -= 5.0
	FORM.tick(enemy, 1.0)
	var saved: Dictionary = enemy.get_save_data()
	var restored = ENEMY.instantiate()
	scene.add_child(restored)
	restored.apply_save_data(saved, target)
	assert(is_equal_approx(restored.heavy_armor_remaining, 2.0))
	assert(is_equal_approx(restored.heavy_armor_cooldown, 19.0))
	assert(is_equal_approx(restored.armor, 15.0))
	assert(restored.get_node("ProfileVisual").sprite.material != null)
	FORM.tick(restored, 2.0)
	assert(not FORM.is_active(restored))
	assert(is_equal_approx(restored.armor, 15.0))
	assert(restored.get_node("ProfileVisual").sprite.material == null)
	DAMAGE.apply_damage(restored, 11.5, false)
	assert(is_equal_approx(restored.current_health, 20.0))
	assert(is_equal_approx(target.received, 1.5))
	FORM.tick(restored, 17.0)
	assert(FORM.is_active(restored))
	restored.skull_damage_immune_timer = 1.0
	DAMAGE.apply_damage(restored, 100.0, false)
	assert(is_equal_approx(target.received, 1.5))
	POOL.prepare_for_pool(restored)
	assert(not FORM.is_active(restored))
	assert(restored.get_node("ProfileVisual").sprite.material == null)
	restored.apply_enemy_profile("normal", DATABASE.get_profile("normal", "chaser"))
	assert(not FORM.is_active(restored))
	scene.free()
	current_scene = null
	print("ENEMY_HEAVY_ARMOR_SMOKE_OK")
	quit(0)


class Target:
	extends Node2D
	var received: float = 0.0

	func take_damage(amount: float) -> void:
		received += amount

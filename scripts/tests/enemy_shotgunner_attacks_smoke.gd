extends SceneTree

const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const BULLET := preload("res://scenes/enemy_bullet.tscn")
const BULLET_SCRIPT := preload("res://scripts/enemy_bullet.gd")
const BEHAVIOR := preload("res://scripts/enemies/enemy_trait_behavior.gd")
const POOL := preload("res://scripts/enemies/enemy_pool_lifecycle.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Runtime.new()
	root.add_child(scene)
	current_scene = scene
	var target := Node2D.new()
	scene.add_child(target)
	var enemy = ENEMY.instantiate()
	enemy.target = target
	enemy.projectile_scene = BULLET
	scene.add_child(enemy)
	enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", "shotgunner"))
	enemy._cached_direction_to_target = Vector2.RIGHT
	assert(is_equal_approx(enemy.attack, 25.0))
	assert(is_equal_approx(enemy.speed, 60.0))
	assert(is_equal_approx(enemy.armor, 5.0))
	assert(is_equal_approx(enemy.max_health, 80.0))
	assert(is_zero_approx(enemy.damage_reduction_rate))
	assert(is_equal_approx(enemy.try_stalwart_body_damage(), 37.5))
	assert(is_equal_approx(enemy.shot_timer, 15.0))
	enemy.projectile_damage = 999.0
	enemy.basic_shot_timer = 0.1
	BEHAVIOR.update_behavior_state(enemy, 0.1)
	_check_bullets(scene, 1, 0, 25.0)
	assert(is_equal_approx(enemy.basic_shot_timer, 6.5))
	assert(is_equal_approx(enemy.shot_timer, 14.9))
	enemy.basic_shot_timer = 10.0
	enemy.shot_timer = 0.1
	BEHAVIOR.update_behavior_state(enemy, 0.1)
	_check_bullets(scene, 0, 5, 25.0)
	assert(is_equal_approx(enemy.basic_shot_timer, 9.9))
	assert(is_equal_approx(enemy.shot_timer, 15.0))
	# Both attacks can fire on the same frame and scale from current attack.
	enemy.attack = 40.0
	enemy.basic_shot_timer = 0.1
	enemy.shot_timer = 0.1
	scene.speed_bonus = 20.0
	BEHAVIOR.update_behavior_state(enemy, 0.1)
	_check_bullets(scene, 1, 5, 40.0)
	var saved: Dictionary = enemy.get_save_data()
	var restored = ENEMY.instantiate()
	scene.add_child(restored)
	restored.apply_save_data(saved, target)
	assert(is_equal_approx(restored.basic_shot_timer, 6.5))
	assert(is_equal_approx(restored.shot_timer, 15.0))
	POOL.prepare_for_pool(restored)
	assert(is_zero_approx(restored.basic_shot_timer))
	restored.apply_enemy_profile("normal", DATABASE.get_profile("normal", "shotgunner"))
	assert(restored.basic_shot_timer >= 0.15 and restored.basic_shot_timer <= 2.6)
	assert(is_equal_approx(restored.shot_timer, 15.0))
	scene.free()
	current_scene = null
	print("ENEMY_SHOTGUNNER_ATTACKS_SMOKE_OK")
	quit(0)


func _check_bullets(scene: Runtime, expected_basic: int, expected_scatter: int, attack: float) -> void:
	var basic_count := 0
	var scatter_angles: Array[float] = []
	for child in scene.get_children():
		if child.get_script() != BULLET_SCRIPT:
			continue
		assert(is_equal_approx(child.hit_radius, 16.0))
		if is_equal_approx(child.lifetime, 4.2):
			basic_count += 1
			assert(is_equal_approx(child.damage, attack))
			assert(is_equal_approx(child.speed, 132.0 + scene.speed_bonus))
			assert(child.direction.is_equal_approx(Vector2.RIGHT))
		else:
			assert(is_equal_approx(child.lifetime, 4.6))
			assert(is_equal_approx(child.damage, attack * 2.0))
			assert(is_equal_approx(child.speed, 200.0 + scene.speed_bonus))
			scatter_angles.append(child.direction.angle())
		child.free()
	assert(basic_count == expected_basic)
	assert(scatter_angles.size() == expected_scatter)
	scatter_angles.sort()
	for index in range(scatter_angles.size()):
		assert(is_equal_approx(scatter_angles[index], (index - 2) * 0.22))


class Runtime:
	extends Node2D
	var speed_bonus: float = 0.0

	func _get_difficulty_projectile_speed_bonus() -> float:
		return speed_bonus

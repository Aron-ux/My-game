extends SceneTree

const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const BODY := preload("res://scripts/enemies/enemy_stalwart_body.gd")
const BEHAVIOR := preload("res://scripts/enemies/enemy_trait_behavior.gd")
const MOVEMENT := preload("res://scripts/enemies/enemy_movement.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var target := Node2D.new()
	scene.add_child(target)
	var enemy = ENEMY.instantiate()
	scene.add_child(enemy)
	enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", "dasher"))
	enemy.target = target
	enemy.current_health = enemy.max_health
	enemy._cached_direction_to_target = Vector2.RIGHT
	assert(is_equal_approx(enemy.attack, 20.0))
	assert(is_equal_approx(enemy.armor, 10.0))
	assert(is_equal_approx(enemy.max_health, 60.0))
	assert(is_zero_approx(enemy.damage_reduction_rate))
	assert(is_equal_approx(enemy.speed, 80.0))
	assert(is_equal_approx(BODY.try_trigger(enemy), 30.0))
	BODY.tick(enemy, 1.0)
	BEHAVIOR.update_behavior_state(enemy, 10.0)
	assert(is_equal_approx(enemy.dash_windup_remaining, 0.6))
	assert(MOVEMENT.compute_velocity(enemy, 0.0) == Vector2.ZERO)
	BEHAVIOR.update_behavior_state(enemy, 0.6)
	assert(is_equal_approx(enemy.dash_remaining, 2.0))
	assert(is_equal_approx(enemy.dash_distance_remaining, 500.0))
	assert(is_equal_approx(BODY.try_trigger(enemy), 50.0))
	assert(is_zero_approx(BODY.try_trigger(enemy)))
	# Spawn speed scaling and moving targets must not alter fixed dash speed/direction.
	enemy.speed *= 2.0
	enemy._cached_direction_to_target = Vector2.DOWN
	enemy.velocity = MOVEMENT.compute_velocity(enemy, 0.0)
	assert(enemy.velocity.is_equal_approx(Vector2(250.0, 0.0)))
	enemy._apply_direct_motion(0.8)
	assert(enemy.position.is_equal_approx(Vector2(200.0, 0.0)))
	assert(is_equal_approx(enemy.dash_distance_remaining, 300.0))
	var data: Dictionary = enemy.get_save_data()
	var restored = ENEMY.instantiate()
	scene.add_child(restored)
	restored.apply_save_data(data, target)
	assert(is_equal_approx(restored.dash_remaining, 1.2))
	assert(is_equal_approx(restored.dash_distance_remaining, 300.0))
	restored.velocity = MOVEMENT.compute_velocity(restored, 0.0)
	# An oversized frame must stop at the maximum distance.
	restored._apply_direct_motion(5.0)
	assert(restored.position.is_equal_approx(Vector2(500.0, 0.0)))
	assert(is_zero_approx(restored.dash_remaining))
	assert(is_equal_approx(restored.dash_timer, 10.0))
	BODY.tick(restored, 1.0)
	assert(is_equal_approx(BODY.try_trigger(restored), 30.0))
	BEHAVIOR.update_behavior_state(restored, 9.5)
	assert(is_zero_approx(restored.dash_windup_remaining))
	BEHAVIOR.update_behavior_state(restored, 0.5)
	assert(is_equal_approx(restored.dash_windup_remaining, 0.6))
	# Elite charges share fixed speed and the added collision damage.
	enemy.apply_enemy_profile("elite", DATABASE.get_profile("elite", "elite_ram_trail"))
	enemy.current_health = enemy.max_health
	enemy.dash_remaining = 0.4
	enemy.dash_distance_remaining = 100.0
	BEHAVIOR.update_behavior_state(enemy, 0.1)
	enemy._apply_direct_motion(0.1)
	assert(is_equal_approx(enemy.dash_remaining, 0.3))
	assert(is_equal_approx(BODY.try_trigger(enemy), enemy.attack * 2.5))
	scene.free()
	current_scene = null
	print("ENEMY_DASHER_CHARGE_SMOKE_OK")
	quit(0)

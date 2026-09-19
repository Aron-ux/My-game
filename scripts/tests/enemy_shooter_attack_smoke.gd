extends SceneTree

const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const PROJECTILES := preload("res://scripts/enemies/enemy_projectiles.gd")
const BODY := preload("res://scripts/enemies/enemy_stalwart_body.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const BULLET := preload("res://scenes/enemy_bullet.tscn")
const BULLET_SCRIPT := preload("res://scripts/enemy_bullet.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var target := Node2D.new()
	scene.add_child(target)
	target.position = Vector2(240.0, 0.0)
	var enemy = ENEMY.instantiate()
	enemy.target = target
	enemy.projectile_scene = BULLET
	scene.add_child(enemy)
	enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", "shooter"))
	assert(is_equal_approx(enemy.attack, 25.0))
	assert(is_equal_approx(enemy.speed, 50.0))
	assert(is_equal_approx(enemy.armor, -10.0))
	assert(is_equal_approx(enemy.max_health, 20.0))
	assert(is_zero_approx(enemy.damage_reduction_rate))
	assert(is_equal_approx(BODY.try_trigger(enemy), 37.5))
	assert(is_zero_approx(BODY.try_trigger(enemy)))
	BODY.tick(enemy, 1.0)
	assert(is_equal_approx(BODY.try_trigger(enemy), 37.5))
	# A stale independent projectile value must not affect this skill.
	enemy.projectile_damage = 999.0
	_check_shot(scene, enemy, 25.0)
	enemy.attack *= 1.8
	_check_shot(scene, enemy, 45.0)
	# Other ranged archetypes retain their existing damage configuration.
	enemy.archetype_id = "smallboss_turret"
	enemy.projectile_damage = 26.0
	_check_shot(scene, enemy, 26.0)
	scene.free()
	current_scene = null
	print("ENEMY_SHOOTER_ATTACK_SMOKE_OK")
	quit(0)


func _check_shot(scene: Node, enemy, expected_damage: float) -> void:
	PROJECTILES.fire_shooter_pattern(enemy)
	var count := 0
	for child in scene.get_children():
		if child.get_script() == BULLET_SCRIPT:
			count += 1
			assert(is_equal_approx(child.damage, expected_damage))
			assert(is_equal_approx(child.speed, 132.0))
			assert(is_equal_approx(child.lifetime, 4.2))
			child.free()
	assert(count == 1)

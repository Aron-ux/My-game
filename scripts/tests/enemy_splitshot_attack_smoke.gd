extends SceneTree

const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const PROJECTILES := preload("res://scripts/enemies/enemy_projectiles.gd")
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
	target.position = Vector2(0, 500)
	var enemy = ENEMY.instantiate()
	scene.add_child(enemy)
	enemy.apply_enemy_profile("elite", DATABASE.get_profile("elite", "elite_splitshot"))
	enemy.target = target
	enemy.projectile_scene = BULLET
	enemy._cached_direction_to_target = Vector2.RIGHT
	assert(is_equal_approx(enemy.attack, 50.0))
	assert(is_equal_approx(enemy.speed, 40.0))
	assert(is_equal_approx(enemy.armor, 10.0))
	assert(is_equal_approx(enemy.max_health, 600.0))
	assert(is_zero_approx(enemy.damage_reduction_rate))
	assert(is_equal_approx(enemy.try_stalwart_body_damage(), 75.0))
	enemy.projectile_damage = 999.0
	_check_volley(scene, enemy, 50.0)
	_check_volley(scene, enemy, 80.0)
	scene.free()
	current_scene = null
	print("ENEMY_SPLITSHOT_ATTACK_SMOKE_OK")
	quit(0)


func _check_volley(scene: Node, enemy, attack: float) -> void:
	enemy.attack = attack
	PROJECTILES.fire_shooter_pattern(enemy)
	var mothers: Array = []
	for child in scene.get_children():
		if child.get_script() == BULLET_SCRIPT and not child.pooled:
			mothers.append(child)
	assert(mothers.size() == 5)
	# Projectiles retain the attack sampled at launch.
	enemy.attack = 999.0
	for index in range(mothers.size()):
		var mother = mothers[index]
		assert(is_equal_approx(mother.damage, attack))
		assert(is_equal_approx(mother.speed, 150.0))
		assert(is_equal_approx(mother.direction.angle(), (index - 2) * 0.18))
		mother.batch_physics_process(1.9)
		assert(not mother.split_performed)
		mother.batch_physics_process(0.11)
		assert(mother.split_performed and mother.pooled)
	var children_count := 0
	for child in scene.get_children():
		if child.get_script() != BULLET_SCRIPT:
			continue
		if not child.pooled:
			children_count += 1
			assert(is_equal_approx(child.damage, attack * 0.6))
			assert(is_equal_approx(child.speed, 300.0))
			assert(is_equal_approx(child.lifetime, 3.456))
			assert(is_equal_approx(child.hit_radius, 8.0))
			assert(child.split_count == 0)
		child.free()
	assert(children_count == 20)

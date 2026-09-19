extends SceneTree

const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const ROSE := preload("res://scripts/enemies/enemy_rose_behavior.gd")
const MINION := preload("res://scripts/enemies/rose_minion.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const BULLET := preload("res://scenes/enemy_bullet.tscn")
const BULLET_SCRIPT := preload("res://scripts/enemy_bullet.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var target := Target.new()
	scene.add_child(target)
	target.position = Vector2(0, 500)
	var enemy = ENEMY.instantiate()
	scene.add_child(enemy)
	enemy.apply_enemy_profile("small_boss", DATABASE.get_profile("small_boss", "smallboss_turret"))
	enemy.target = target
	enemy.projectile_scene = BULLET
	enemy.set_physics_process(false)
	assert(is_equal_approx(enemy.attack, 80.0))
	assert(is_zero_approx(enemy.speed))
	assert(is_equal_approx(enemy.armor, -20.0))
	assert(is_zero_approx(enemy.damage_reduction_rate))
	assert(is_equal_approx(enemy.max_health, 2800.0))
	assert(is_equal_approx(enemy.try_stalwart_body_damage(), 120.0))
	enemy.projectile_damage = 999.0
	enemy.shot_timer = 0.0
	ROSE._update_normal_attack(enemy, 0.0)
	_check_bullets(scene, 3, 80.0, 211.2, 4.4)
	var sequence := {"enemy_ref": weakref(enemy), "impact_center": target.position}
	ROSE._finish_split_sequence(scene, sequence)
	_check_bullets(scene, 8, 80.0, 181.632, 1.2)
	ROSE._finish_bombard_sequence(sequence)
	assert(is_equal_approx(target.received, 80.0))
	_check_bullets(scene, 10, 80.0, 288.288, 5.7)
	enemy.attack = 160.0
	enemy.shot_timer = 0.0
	ROSE._update_normal_attack(enemy, 0.0)
	_check_bullets(scene, 3, 160.0, 211.2, 4.4)
	ROSE._finish_bombard_sequence(sequence)
	assert(is_equal_approx(target.received, 240.0))
	_check_bullets(scene, 10, 160.0, 288.288, 5.7)
	# Exercise actual delayed minion creation, not just configure().
	await create_timer(1.4).timeout
	var minion_count := 0
	for child in scene.get_children():
		if child.get_script() != MINION:
			continue
		minion_count += 1
		child.set_process(false)
		assert(is_equal_approx(child.projectile_damage, 160.0))
		child._fire_attack()
		_check_bullets(scene, 3, 160.0, 352.0, 4.4)
	assert(minion_count == 3)
	scene.free()
	current_scene = null
	print("ENEMY_ROSE_ATTACK_SMOKE_OK")
	quit(0)


func _check_bullets(scene: Node, count: int, damage: float, speed: float, lifetime: float) -> void:
	var found := 0
	for child in scene.get_children():
		if child.get_script() != BULLET_SCRIPT:
			continue
		found += 1
		assert(is_equal_approx(child.damage, damage))
		assert(is_equal_approx(child.speed, speed))
		assert(is_equal_approx(child.lifetime, lifetime))
		child.free()
	assert(found == count)


class Target:
	extends Node2D
	var received: float = 0.0

	func take_damage(amount: float) -> void:
		received += amount

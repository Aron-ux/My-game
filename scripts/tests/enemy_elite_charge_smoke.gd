extends SceneTree

const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const CHARGE := preload("res://scripts/enemies/enemy_dasher_charge.gd")
const GROUND := preload("res://scripts/enemies/elite_charge_ground.gd")
const BEHAVIOR := preload("res://scripts/enemies/enemy_trait_behavior.gd")
const MOVEMENT := preload("res://scripts/enemies/enemy_movement.gd")
const RUNTIME := preload("res://scripts/enemies/enemy_runtime_process.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var player := PlayerStub.new()
	scene.add_child(player)
	var elite = _enemy(scene, player, "elite", "elite_ram_trail")
	var normal = _enemy(scene, player, "normal", "dasher")
	var chaser = _enemy(scene, player, "normal", "chaser")
	normal.position = Vector2(5000.0, 0.0)
	assert(is_equal_approx(elite.attack, 30.0))
	assert(is_equal_approx(elite.speed, 100.0))
	assert(is_equal_approx(elite.armor, 10.0))
	assert(is_equal_approx(elite.max_health, 100.0))
	assert(is_zero_approx(elite.damage_reduction_rate))
	assert(is_equal_approx(elite.try_stalwart_body_damage(), 45.0))
	elite.stalwart_body_cooldown = 0.0
	BEHAVIOR.update_behavior_state(elite, 10.0)
	assert(is_equal_approx(elite.dash_windup_remaining, 0.6))
	BEHAVIOR.update_behavior_state(elite, 0.6)
	assert(is_equal_approx(elite.try_stalwart_body_damage(), 75.0))
	assert(is_equal_approx(MOVEMENT.compute_velocity(elite, 0.0).length(), 250.0))
	assert(is_equal_approx(normal.elite_charge_haste_remaining, 3.0))
	assert(is_zero_approx(chaser.elite_charge_haste_remaining))
	assert(is_zero_approx(elite.elite_charge_haste_remaining))
	assert(is_equal_approx(MOVEMENT.compute_velocity(normal, 0.0).length(), 61.6))
	normal.elite_charge_haste_remaining = 1.0
	CHARGE.grant_charge_haste(elite)
	assert(is_equal_approx(normal.elite_charge_haste_remaining, 3.0))
	assert(is_equal_approx(MOVEMENT.compute_velocity(normal, 0.0).length(), 61.6))
	var saved: Dictionary = normal.get_save_data()
	normal.apply_save_data(saved, player)
	assert(is_equal_approx(normal.elite_charge_haste_remaining, 3.0))
	normal.target = null
	RUNTIME.physics_process(normal, 3.0)
	assert(is_zero_approx(normal.elite_charge_haste_remaining))
	elite.velocity = MOVEMENT.compute_velocity(elite, 0.0)
	elite._apply_direct_motion(3.0)
	assert(is_equal_approx(elite.position.x, 500.0))
	assert(is_equal_approx(elite.dash_timer, 10.0))
	var hazard: Node2D
	for child in scene.get_children():
		if child.get_script() == GROUND:
			hazard = child
	assert(hazard != null)
	var old_length: float = maxf(32.0, (42.0 + elite.scale.x * 8.0) * 0.6) * 2.0
	assert(is_equal_approx(hazard.size.x, old_length * 2.0))
	assert(is_equal_approx(hazard.size.y, 62.4))
	hazard._on_body_entered(player)
	assert(is_equal_approx(player.damage_received, 10.0))
	assert(is_equal_approx(GROUND.get_slow_multiplier(player), 0.7))
	hazard._physics_process(0.9)
	assert(is_equal_approx(player.damage_received, 10.0))
	player.max_health = 2000.0
	hazard._physics_process(0.1)
	assert(is_equal_approx(player.damage_received, 30.0))
	var second = GROUND.new()
	second.size = Vector2(100, 50)
	scene.add_child(second)
	second._on_body_entered(player)
	hazard._on_body_exited(player)
	assert(is_equal_approx(GROUND.get_slow_multiplier(player), 0.7))
	second._on_body_exited(player)
	assert(is_equal_approx(GROUND.get_slow_multiplier(player), 1.0))
	second._on_body_entered(player)
	player.immune = true
	assert(is_equal_approx(GROUND.get_slow_multiplier(player), 1.0))
	player.immune = false
	second._physics_process(3.0)
	assert(is_equal_approx(GROUND.get_slow_multiplier(player), 1.0))
	var damage_after_exit: float = player.damage_received
	hazard._physics_process(1.0)
	assert(is_equal_approx(player.damage_received, damage_after_exit))
	hazard._physics_process(1.0)
	assert(hazard.is_queued_for_deletion())
	scene.free()
	# Verify actual Area2D entry/exit, including a field with no living enemies.
	scene = Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var actual_player := PlayerStub.new()
	actual_player.position = Vector2(1000, 0)
	actual_player.collision_layer = 1
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	collider.shape = circle
	actual_player.add_child(collider)
	scene.add_child(actual_player)
	var actual_ground = GROUND.new()
	actual_ground.size = Vector2(200, 100)
	scene.add_child(actual_ground)
	for _index in range(3):
		await physics_frame
	actual_player.position = Vector2.ZERO
	for _index in range(3):
		await physics_frame
	assert(is_equal_approx(actual_player.damage_received, 10.0))
	assert(is_equal_approx(GROUND.get_slow_multiplier(actual_player), 0.7))
	actual_player.position = Vector2(1000, 0)
	for _index in range(3):
		await physics_frame
	assert(is_equal_approx(GROUND.get_slow_multiplier(actual_player), 1.0))
	actual_ground._physics_process(3.0)
	assert(actual_ground.is_queued_for_deletion())
	scene.free()
	current_scene = null
	print("ENEMY_ELITE_CHARGE_SMOKE_OK")
	quit(0)


func _enemy(scene: Node, player: Node2D, kind: String, archetype: String):
	var enemy = ENEMY.instantiate()
	scene.add_child(enemy)
	enemy.apply_enemy_profile(kind, DATABASE.get_profile(kind, archetype))
	enemy.target = player
	enemy._cached_direction_to_target = Vector2.RIGHT
	enemy.set_physics_process(false)
	return enemy


class PlayerStub:
	extends CharacterBody2D
	var max_health: float = 1000.0
	var damage_received: float = 0.0
	var immune: bool = false

	func take_damage(amount: float) -> void:
		damage_received += amount

	func _is_status_immune() -> bool:
		return immune

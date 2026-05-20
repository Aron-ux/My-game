extends SceneTree

const ENEMY_GLUTTON_BEHAVIOR := preload("res://scripts/enemies/enemy_glutton_behavior.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := RuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene

	var glutton := EnemyStub.new()
	glutton.enemy_kind = "small_boss"
	glutton.global_position = Vector2.ZERO
	glutton.glutton_aura_radius = 120.0
	glutton.glutton_aura_damage = 9.0
	scene.add_enemy(glutton)

	var target := EnemyStub.new()
	target.global_position = Vector2(40.0, 0.0)
	target.current_health = 100.0
	target.max_health = 100.0
	scene.add_enemy(target)

	ENEMY_GLUTTON_BEHAVIOR.damage_nearby_enemies(glutton)
	if not is_instance_valid(target) or target.current_health >= 100.0:
		failures.append("first glutton aura hit should damage target")
	if not is_instance_valid(target) or target.current_health <= 0.0:
		failures.append("first glutton aura hit should not execute high-health target")

	ENEMY_GLUTTON_BEHAVIOR.damage_nearby_enemies(glutton)
	if not is_instance_valid(target) or target.current_health <= 0.0:
		failures.append("second glutton aura hit should not execute high-health target")

	for _index in range(4):
		ENEMY_GLUTTON_BEHAVIOR.damage_nearby_enemies(glutton)
	if is_instance_valid(target) and not target.was_defeated:
		failures.append("sixth glutton aura hit should execute target regardless of remaining health")

	var player_like := PlayerLikeStub.new()
	player_like.global_position = Vector2(36.0, 0.0)
	scene.add_enemy(player_like)
	for _index in range(6):
		ENEMY_GLUTTON_BEHAVIOR.damage_nearby_enemies(glutton)
	if player_like.damage_calls != 0:
		failures.append("glutton aura execute should not affect player-like nodes even if they enter runtime enemy list")

	var batch_a := EnemyStub.new()
	batch_a.global_position = Vector2(60.0, 0.0)
	batch_a.current_health = 100.0
	batch_a.max_health = 100.0
	scene.add_enemy(batch_a)

	var batch_b := EnemyStub.new()
	batch_b.global_position = Vector2(80.0, 0.0)
	batch_b.current_health = 100.0
	batch_b.max_health = 100.0
	scene.add_enemy(batch_b)
	await physics_frame
	for _index in range(6):
		ENEMY_GLUTTON_BEHAVIOR.damage_nearby_enemies(glutton)
	if is_instance_valid(batch_a) and not batch_a.was_defeated:
		failures.append("glutton aura execute should affect multiple enemies in the same batch")
	if is_instance_valid(batch_b) and not batch_b.was_defeated:
		failures.append("glutton aura execute should not stop after the first enemy")

	var edge_target := EnemyStub.new()
	edge_target.global_position = Vector2(132.0, 0.0)
	edge_target.contact_radius = 20.0
	edge_target.current_health = 100.0
	edge_target.max_health = 100.0
	scene.add_enemy(edge_target)
	await physics_frame
	ENEMY_GLUTTON_BEHAVIOR.damage_nearby_enemies(glutton)
	if edge_target.current_health >= 100.0:
		failures.append("glutton aura should include target contact radius at the edge")

	var shadow_glutton := EnemyStub.new()
	shadow_glutton.enemy_kind = "small_boss"
	shadow_glutton.global_position = Vector2(360.0, 0.0)
	shadow_glutton.glutton_aura_radius = 40.0
	shadow_glutton.glutton_aura_damage = 9.0
	var shadow_visual := ShadowVisualStub.new()
	shadow_visual.shadow_world_radius = 100.0
	shadow_visual.name = "ProfileVisual"
	shadow_glutton.add_child(shadow_visual)
	scene.add_enemy(shadow_glutton)

	var shadow_target := EnemyStub.new()
	shadow_target.global_position = Vector2(360.0 + 105.0, 0.0)
	shadow_target.current_health = 100.0
	shadow_target.max_health = 100.0
	shadow_target.contact_radius = 0.0
	scene.add_enemy(shadow_target)
	await physics_frame
	ENEMY_GLUTTON_BEHAVIOR.damage_nearby_enemies(shadow_glutton)
	if shadow_target.current_health >= 100.0:
		failures.append("glutton aura should use 110 percent of visual shadow radius when available")

	scene.queue_free()
	await process_frame
	current_scene = null

	if failures.is_empty():
		print("ENEMY_GLUTTON_BEHAVIOR_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


class RuntimeRoot:
	extends Node2D

	var enemies: Array = []

	func add_enemy(enemy: Node2D) -> void:
		enemies.append(enemy)
		add_child(enemy)

	func get_runtime_enemies() -> Array:
		var result: Array = []
		for enemy in enemies:
			if enemy != null and is_instance_valid(enemy):
				result.append(enemy)
		return result


class EnemyStub:
	extends Node2D

	signal defeated(enemy_kind: String)

	var enemy_kind: String = "normal"
	var current_health: float = 20.0
	var max_health: float = 20.0
	var vulnerability_bonus: float = 0.0
	var contact_radius: float = 16.0
	var profile_visual_scene: PackedScene = null
	var drop_absorber: Node = null
	var glutton_aura_radius: float = 0.0
	var glutton_aura_damage: float = 0.0
	var glutton_aura_hits_by_enemy_id: Dictionary = {}
	var was_defeated: bool = false

	func take_damage(amount: float) -> bool:
		current_health -= amount * (1.0 + vulnerability_bonus)
		if current_health <= 0.0:
			was_defeated = true
			defeated.emit(enemy_kind)
			queue_free()
			return true
		return false


class PlayerLikeStub:
	extends Node2D

	var damage_calls: int = 0
	var current_health: float = 60.0

	func take_damage(_amount: float) -> void:
		damage_calls += 1


class ShadowVisualStub:
	extends Node2D

	var shadow_world_radius: float = 0.0

	func get_shadow_world_radius() -> float:
		return shadow_world_radius

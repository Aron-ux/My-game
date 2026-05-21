extends SceneTree

const ENEMY_BATCH_SIMULATION := preload("res://scripts/enemies/enemy_batch_simulation.gd")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := RuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene
	var target := Node2D.new()
	target.global_position = Vector2(240.0, 0.0)
	scene.add_child(target)

	var batched_enemy := _create_enemy(scene, target, "chaser")
	ENEMY_BATCH_SIMULATION.update_simple_normal_enemies(scene, 0.1)
	if not bool(batched_enemy.get("batch_simulation_enabled")):
		failures.append("simple chaser should be marked as batch-simulated")
	if batched_enemy.is_physics_processing():
		failures.append("batch-simulated chaser should disable per-node physics callback")
	if batched_enemy.global_position.x <= 0.0:
		failures.append("batch-simulated chaser should still move toward the target")

	var first_position := batched_enemy.global_position
	ENEMY_BATCH_SIMULATION.update_simple_normal_enemies(scene, 0.1)
	if batched_enemy.global_position != first_position:
		failures.append("batch simulation should run at most once per physics frame")

	await physics_frame
	ENEMY_BATCH_SIMULATION.update_simple_normal_enemies(scene, 0.1)
	if batched_enemy.global_position.x <= first_position.x:
		failures.append("batch-simulated chaser should advance on the next physics frame")

	var swarm_enemy := _create_enemy(scene, target, "swarm")
	await physics_frame
	ENEMY_BATCH_SIMULATION.update_simple_normal_enemies(scene, 0.1)
	if not bool(swarm_enemy.get("batch_simulation_enabled")):
		failures.append("simple swarm mover should be batch-simulated")
	if swarm_enemy.is_physics_processing():
		failures.append("batch-simulated swarm should disable per-node physics callback")
	if swarm_enemy.global_position.x <= 0.0:
		failures.append("batch-simulated swarm should still move toward the target")

	var shooter_enemy := _create_enemy(scene, target, "shooter")
	await physics_frame
	ENEMY_BATCH_SIMULATION.update_simple_normal_enemies(scene, 0.1)
	if not bool(shooter_enemy.get("batch_simulation_enabled")):
		failures.append("normal shooter should be batch-simulated")
	if shooter_enemy.is_physics_processing():
		failures.append("batch-simulated shooter should disable per-node physics callback")

	var dash_enemy := _create_enemy(scene, target, "dash")
	dash_enemy.set("dash_interval", 0.05)
	dash_enemy.set("dash_timer", 0.0)
	await physics_frame
	ENEMY_BATCH_SIMULATION.update_simple_normal_enemies(scene, 0.1)
	if not bool(dash_enemy.get("batch_simulation_enabled")):
		failures.append("normal dash enemy should be batch-simulated")
	if dash_enemy.is_physics_processing():
		failures.append("batch-simulated dash enemy should disable per-node physics callback")
	if float(dash_enemy.get("dash_windup_remaining")) <= 0.0:
		failures.append("batch-simulated dash enemy should keep dash timing behavior")

	scene.queue_free()
	await process_frame
	current_scene = null

	if failures.is_empty():
		print("ENEMY_BATCH_SIMULATION_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _create_enemy(scene: RuntimeRoot, target_node: Node2D, behavior: String) -> Node2D:
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	scene.add_child(enemy)
	enemy.target = target_node
	enemy.enemy_kind = "normal"
	enemy.archetype_id = behavior
	enemy.behavior_id = behavior
	enemy.secondary_behavior_id = ""
	enemy._sync_trait_flags()
	enemy.current_health = enemy.max_health
	enemy.global_position = Vector2.ZERO
	enemy.show()
	enemy.set_process(true)
	enemy.set_physics_process(true)
	scene.register_runtime_enemy(enemy)
	return enemy


class RuntimeRoot:
	extends Node2D

	var active_enemies: Dictionary = {}

	func register_runtime_enemy(enemy: Node) -> void:
		active_enemies[enemy.get_instance_id()] = enemy

	func unregister_runtime_enemy(enemy: Node) -> void:
		active_enemies.erase(enemy.get_instance_id())

	func get_runtime_enemies() -> Array:
		var result: Array = []
		for enemy in active_enemies.values():
			if enemy != null and is_instance_valid(enemy):
				result.append(enemy)
		return result

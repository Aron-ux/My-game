extends SceneTree

const ENEMY_OCCLUSION_SORT := preload("res://scripts/enemies/enemy_occlusion_sort.gd")


func _init() -> void:
	var failures: Array[String] = []
	var scene := _RuntimeEnemyScene.new()
	root.add_child(scene)
	current_scene = scene

	var glutton := _make_enemy("small_boss", "glutton", Vector2(0.0, 100.0))
	var behind := _make_enemy("normal", "chaser", Vector2(0.0, 60.0))
	var front := _make_enemy("normal", "chaser", Vector2(0.0, 160.0))
	scene.add_child(glutton)
	scene.add_child(behind)
	scene.add_child(front)
	scene.runtime_enemies = [glutton, behind, front]

	ENEMY_OCCLUSION_SORT.update_scene_from_glutton(glutton)
	if glutton.z_index != 30:
		failures.append("glutton should use occlusion middle z index")
	if behind.z_index != 20:
		failures.append("enemy behind glutton should be below glutton")
	if front.z_index != 40:
		failures.append("enemy in front of glutton should be above glutton")

	for node in [glutton, behind, front]:
		node.queue_free()
	scene.queue_free()

	if failures.is_empty():
		print("enemy_glutton_occlusion_smoke: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _make_enemy(kind: String, behavior: String, position: Vector2) -> Node2D:
	var enemy := _FakeEnemy.new()
	enemy.enemy_kind = kind
	enemy.behavior_id = behavior
	enemy.secondary_behavior_id = ""
	enemy._is_glutton = behavior == "glutton"
	enemy.global_position = position
	return enemy


class _RuntimeEnemyScene:
	extends Node2D

	var runtime_enemies: Array = []

	func get_runtime_enemies() -> Array:
		return runtime_enemies


class _FakeEnemy:
	extends Node2D

	var enemy_kind: String = "normal"
	var behavior_id: String = "chaser"
	var secondary_behavior_id: String = ""
	var _is_glutton: bool = false

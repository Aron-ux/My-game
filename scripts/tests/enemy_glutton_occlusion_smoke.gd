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
	if glutton.z_index != 8:
		failures.append("glutton should use occlusion middle z index")
	if behind.z_index != 4:
		failures.append("enemy behind glutton should be below glutton")
	if front.z_index != 9:
		failures.append("enemy in front of glutton should be above glutton")

	var skulltomb := _make_enemy("small_boss", "skulltomb", Vector2(200.0, 100.0))
	var skulltomb_behind := _make_enemy("normal", "chaser", Vector2(200.0, 60.0))
	var skulltomb_front := _make_enemy("elite", "dash", Vector2(200.0, 160.0))
	scene.add_child(skulltomb)
	scene.add_child(skulltomb_behind)
	scene.add_child(skulltomb_front)
	scene.runtime_enemies = [skulltomb, skulltomb_behind, skulltomb_front]

	scene.remove_meta("__enemy_occlusion_sort_frame")
	ENEMY_OCCLUSION_SORT.update_scene_from_occluder(skulltomb)
	if skulltomb.z_index != 8:
		failures.append("skulltomb should use occlusion middle z index")
	if skulltomb_behind.z_index != 4:
		failures.append("enemy behind skulltomb should be below skulltomb")
	if skulltomb_front.z_index != 9:
		failures.append("enemy in front of skulltomb should be above skulltomb")

	for node in [glutton, behind, front, skulltomb, skulltomb_behind, skulltomb_front]:
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

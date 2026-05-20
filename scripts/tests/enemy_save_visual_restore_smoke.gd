extends SceneTree

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")


func _init() -> void:
	var failures: Array[String] = []
	_check_visual_restore("dasher", "res://assets/enemies/skullsolider/skullsoilder.tscn", failures)
	_check_visual_restore("elite_ram_trail", "res://assets/enemies/skullsolider/eliteskull.tscn", failures)
	if failures.is_empty():
		print("enemy_save_visual_restore_smoke: OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_visual_restore(archetype: String, expected_scene_path: String, failures: Array[String]) -> void:
	var enemy := ENEMY_SCENE.instantiate()
	if enemy == null:
		failures.append("%s enemy scene instantiate failed" % archetype)
		return
	root.add_child(enemy)
	enemy.apply_enemy_profile("normal", ENEMY_ARCHETYPE_DATABASE.get_profile("normal", archetype))
	var save_data: Dictionary = enemy.get_save_data()
	enemy.queue_free()

	var restored_enemy := ENEMY_SCENE.instantiate()
	root.add_child(restored_enemy)
	restored_enemy.apply_save_data(save_data, null)
	if restored_enemy.profile_visual_scene == null:
		failures.append("%s restored visual scene is null" % archetype)
	elif restored_enemy.profile_visual_scene.resource_path != expected_scene_path:
		failures.append("%s restored visual scene expected %s got %s" % [archetype, expected_scene_path, restored_enemy.profile_visual_scene.resource_path])
	restored_enemy.queue_free()

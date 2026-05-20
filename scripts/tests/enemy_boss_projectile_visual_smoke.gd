extends SceneTree

const ENEMY_BULLET_SCENE := preload("res://scenes/enemy_bullet.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene

	await _check_style(scene, "boss_dark_orb", true, false)
	await _check_style(scene, "boss_dark_core_orb", true, true)
	await _check_style(scene, "boss_turning_hex", false, false)

	scene.queue_free()
	await process_frame
	current_scene = null

	if failures.is_empty():
		print("ENEMY_BOSS_PROJECTILE_VISUAL_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_style(scene: Node2D, style: String, expects_outline: bool, expects_core: bool) -> void:
	var bullet := ENEMY_BULLET_SCENE.instantiate() as Node2D
	scene.add_child(bullet)
	bullet.reset_projectile({
		"position": Vector2.ZERO,
		"direction": Vector2.RIGHT,
		"visual_style": style,
		"size_scale": 1.0,
		"lifetime": 1.0
	})
	await process_frame
	if expects_outline and bullet.get_node_or_null("Outline") == null:
		failures.append("%s should have black outline" % style)
	if expects_core and bullet.get_node_or_null("BossCore") == null:
		failures.append("%s should have white core" % style)
	if not expects_core and bullet.get_node_or_null("BossCore") != null:
		failures.append("%s should not keep white core" % style)
	bullet.queue_free()


func register_runtime_enemy_projectile(_projectile: Node, _is_pooled: bool) -> void:
	pass


func unregister_runtime_enemy_projectile(_projectile: Node) -> void:
	pass

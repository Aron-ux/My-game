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
	_check_legacy_danmaku(scene)

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


func _check_legacy_danmaku(scene: Node2D) -> void:
	var bullet = ENEMY_BULLET_SCENE.instantiate()
	scene.add_child(bullet)
	bullet.reset_projectile({
		"position": Vector2(120, 80), "direction": Vector2.RIGHT,
		"speed": 140.0, "damage": 64.0, "hit_radius": 6.8, "lifetime": 10.0,
		"motion_mode": "danmaku", "danmaku_angular_speed": 0.13,
		"visual_style": "boss_danmaku_shard", "visual_color": Color(0.65, 0.25, 1.0)
	})
	bullet.set_physics_process(false)
	bullet.travel_time = 0.7
	bullet._update_danmaku_motion()
	var expected_position: Vector2 = bullet.position
	var old_styles := {
		"boss_danmaku_butterfly": "boss_danmaku_shadow_orb",
		"boss_danmaku_petal": "boss_danmaku_violet_orb",
		"boss_danmaku_rice": "boss_danmaku_violet_orb",
		"boss_danmaku_orb": "boss_danmaku_violet_orb",
		"boss_danmaku_arrow": "boss_danmaku_violet_orb",
		"boss_danmaku_shard": "boss_danmaku_shadow_orb",
		"boss_danmaku_splinter": "boss_danmaku_violet_orb",
		"boss_danmaku_spike": "boss_danmaku_violet_orb",
		"boss_danmaku_void_orb": "boss_danmaku_shadow_orb"
	}
	for old_style in old_styles:
		var saved: Dictionary = JSON.parse_string(JSON.stringify(bullet.get_save_data()))
		saved.visual_style = old_style
		saved.visual_color = [1.0, 0.3, 0.6, 1.0]
		bullet.apply_save_data(saved, null)
		bullet.set_physics_process(false)
		if bullet.visual_style != old_styles[old_style]:
			failures.append("legacy save must migrate %s to the dark-stone skin" % old_style)
		if not is_equal_approx(bullet.damage, 64.0) or not is_equal_approx(bullet.hit_radius, 6.8) or not is_equal_approx(bullet.travel_time, 0.7) or bullet.position.distance_to(expected_position) > 0.001:
			failures.append("reskin must preserve saved damage, collision and trajectory state")
		if bullet.get_node("BossCore").color.v < 0.8:
			failures.append("purple and black orbs need visible round cores")
		for point in bullet.get_node("Polygon2D").polygon:
			if not is_equal_approx(point.length(), 8.0):
				failures.append("every old shard/needle skin must become the original circular silhouette")
		if bullet.get_save_data().visual_style != old_styles[old_style]:
			failures.append("the next save must persist the migrated style")
	bullet.reset_projectile({"visual_style": "solid_circle", "visual_color": Color(0.2, 0.8, 0.3), "motion_mode": "straight"})
	if bullet.get_node("Polygon2D").color != Color(0.2, 0.8, 0.3) or bullet.get_node_or_null("BossCore") != null:
		failures.append("ordinary pooled projectile must not inherit dark stone skin or crack")
	bullet.free()

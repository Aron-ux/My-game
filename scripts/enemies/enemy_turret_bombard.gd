extends RefCounted

const ENEMY_GEOMETRY := preload("res://scripts/enemies/enemy_geometry.gd")

static func start_bombard(enemy) -> void:
	if enemy.target == null or not is_instance_valid(enemy.target):
		return
	var current_scene: Node = enemy.get_tree().current_scene
	if current_scene == null:
		return
	var aim_center: Vector2 = enemy.target.global_position
	if enemy.target.has_method("get_hurtbox_center"):
		aim_center = enemy.target.get_hurtbox_center()
	var impact_center: Vector2 = aim_center + Vector2(randf_range(-42.0, 42.0), randf_range(-42.0, 42.0))

	var warning := Line2D.new()
	warning.global_position = impact_center
	warning.width = 4.0
	warning.default_color = Color(1.0, 0.28, 0.18, 0.86)
	warning.closed = true
	warning.points = ENEMY_GEOMETRY.build_circle_points(enemy.turret_bombard_radius)
	warning.z_index = 15
	current_scene.add_child(warning)

	var warning_fill := Polygon2D.new()
	warning_fill.global_position = impact_center
	warning_fill.color = Color(1.0, 0.22, 0.14, 0.14)
	warning_fill.polygon = warning.points
	warning_fill.z_index = 14
	current_scene.add_child(warning_fill)

	var warning_tween := warning.create_tween()
	warning_tween.parallel().tween_property(warning, "scale", Vector2(1.08, 1.08), 0.7)
	warning_tween.parallel().tween_property(warning_fill, "scale", Vector2(1.08, 1.08), 0.7)
	warning_tween.tween_callback(func() -> void:
		if is_instance_valid(warning):
			warning.queue_free()
		if is_instance_valid(warning_fill):
			warning_fill.queue_free()
		if enemy == null or not is_instance_valid(enemy):
			return
		enemy._spawn_status_burst(Color(1.0, 0.42, 0.18, 0.24), 34.0 + enemy.scale.x * 8.0)
		if enemy.target != null and is_instance_valid(enemy.target):
			var target_center: Vector2 = enemy.target.global_position
			var target_radius: float = 0.0
			if enemy.target.has_method("get_hurtbox_center"):
				target_center = enemy.target.get_hurtbox_center()
			if enemy.target.has_method("get_hurtbox_radius"):
				target_radius = float(enemy.target.get_hurtbox_radius())
			if impact_center.distance_to(target_center) <= enemy.turret_bombard_radius + target_radius and enemy.target.has_method("take_damage"):
				enemy.target.take_damage(enemy.projectile_damage * 1.25)
		for index in range(max(6, enemy.turret_bombard_projectiles)):
			var angle: float = TAU * float(index) / float(max(1, enemy.turret_bombard_projectiles))
			var shot_direction: Vector2 = Vector2.RIGHT.rotated(angle)
			enemy._spawn_projectile(
				impact_center + shot_direction * 12.0,
				shot_direction,
				max(280.0, enemy.projectile_speed * 1.05),
				enemy.projectile_damage,
				3.8,
				Color(1.0, 0.4, 0.16, 1.0),
				"straight",
				{"size_scale": 1.1}
			)
	)

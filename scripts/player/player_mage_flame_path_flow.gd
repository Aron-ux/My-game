extends RefCounted

static func apply_damage_tick(owner, points: Array[Vector2], path_width: float, damage_per_second: float, interval: float) -> void:
	if owner == null or not is_instance_valid(owner) or points.size() < 2:
		return
	var hit_registry: Dictionary = {}
	for index in range(points.size() - 1):
		var start: Vector2 = points[index]
		var end: Vector2 = points[index + 1]
		var axis: Vector2 = end - start
		var length: float = axis.length()
		if length <= 0.001:
			continue
		var direction: Vector2 = axis / length
		if owner.has_method("_damage_enemies_in_oriented_rect_unique"):
			owner._damage_enemies_in_oriented_rect_unique(
				(start + end) * 0.5,
				direction,
				length + path_width,
				path_width,
				damage_per_second * interval,
				0.0,
				1.0,
				0.0,
				hit_registry,
				"mage"
			)

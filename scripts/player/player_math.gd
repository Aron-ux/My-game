extends RefCounted

static func get_dangzhen_sword_visual_size(split_level: int, huichao_level: int) -> Vector2:
	var scale_multiplier: float = 0.72 + split_level * 0.07 + huichao_level * 0.05
	return Vector2(138.0, 74.0) * scale_multiplier

static func get_dangzhen_gunner_beam_hit_half_width(visual_thickness: float, visual_scale: float) -> float:
	var beam_visible_height: float = visual_thickness * visual_scale
	return beam_visible_height * 0.5

static func get_dangzhen_gunner_range_multiplier(huichao_level: int) -> float:
	match huichao_level:
		1:
			return 1.5
		2:
			return 2.0
		3:
			return 3.0
		_:
			return 1.0

static func get_dangzhen_qichao_damage(role_id: String, qichao_level: int) -> float:
	var level_index: int = clamp(qichao_level - 1, 0, 2)
	match role_id:
		"swordsman":
			return [22.0, 30.0, 38.0][level_index]
		"gunner":
			return [18.0, 25.0, 32.0][level_index]
		"mage":
			return [24.0, 32.0, 40.0][level_index]
		_:
			return [20.0, 28.0, 36.0][level_index]

static func get_downward_perpendicular(direction: Vector2) -> Vector2:
	var normalized_direction: Vector2 = direction.normalized()
	if normalized_direction.length_squared() <= 0.001:
		return Vector2.DOWN
	var perpendicular: Vector2 = normalized_direction.orthogonal().normalized()
	var mirrored: Vector2 = -perpendicular
	if mirrored.dot(Vector2.DOWN) > perpendicular.dot(Vector2.DOWN):
		return mirrored
	return perpendicular

static func build_circle_polygon(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments := 18
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

static func build_arc_points(radius: float, arc_degrees: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments := 24
	var half_arc := deg_to_rad(arc_degrees) * 0.5
	var start_angle := -half_arc
	var end_angle := half_arc
	for index in range(segments + 1):
		var weight := float(index) / float(segments)
		var angle := lerpf(start_angle, end_angle, weight)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

static func build_arc_band_polygon(outer_radius: float, inner_radius: float, arc_degrees: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var outer_points := build_arc_points(outer_radius, arc_degrees)
	var inner_points := build_arc_points(inner_radius, arc_degrees)
	for point in outer_points:
		points.append(point)
	for index in range(inner_points.size() - 1, -1, -1):
		points.append(inner_points[index])
	return points

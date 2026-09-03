extends RefCounted

# Handoff note:
# Player movement clamping lives here so map bounds remain gameplay data instead
# of visual-only HUD state. main.gd owns the active bounds; this flow discovers
# them through the scene tree and clamps after move_and_slide().

static func clamp_to_active_map_bounds(owner: Node2D) -> void:
	var bounds := get_active_map_bounds(owner)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	bounds = _get_hurtbox_safe_bounds(owner, bounds)
	owner.global_position = Vector2(
		clamp(owner.global_position.x, bounds.position.x, bounds.position.x + bounds.size.x),
		clamp(owner.global_position.y, bounds.position.y, bounds.position.y + bounds.size.y)
	)
	_clamp_to_active_confinement(owner)

static func get_active_map_bounds(owner: Node) -> Rect2:
	var main := _find_main_node(owner)
	if main != null:
		var bounds = main.get("map_bounds")
		if bounds is Rect2:
			return bounds
	return Rect2()

static func _find_main_node(owner: Node) -> Node:
	var current := owner
	while current != null:
		if current.get("map_bounds") != null:
			return current
		current = current.get_parent()
	return null

static func _get_hurtbox_safe_bounds(owner: Node2D, bounds: Rect2) -> Rect2:
	var margin: float = 0.0
	if owner.has_method("get_hurtbox_radius"):
		margin = max(0.0, float(owner.call("get_hurtbox_radius")))
	if bounds.size.x <= margin * 2.0 or bounds.size.y <= margin * 2.0:
		return Rect2(bounds.get_center(), Vector2.ZERO)
	return bounds.grow(-margin)

static func _clamp_to_active_confinement(owner: Node2D) -> void:
	return

static func _shrink_polygon_toward_center(points: PackedVector2Array, owner: Node2D) -> PackedVector2Array:
	var center := Vector2.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	var margin := _get_owner_hurtbox_radius(owner)
	if margin <= 0.0:
		return points
	var safe_points := PackedVector2Array()
	for point in points:
		var offset := point - center
		var length := offset.length()
		if length <= margin:
			safe_points.append(center)
		else:
			safe_points.append(center + offset.normalized() * (length - margin))
	return safe_points

static func _get_closest_point_on_polygon(point: Vector2, polygon: PackedVector2Array) -> Vector2:
	var closest := polygon[0]
	var closest_distance := INF
	for index in range(polygon.size()):
		var start := polygon[index]
		var end := polygon[(index + 1) % polygon.size()]
		var candidate := Geometry2D.get_closest_point_to_segment(point, start, end)
		var distance := point.distance_squared_to(candidate)
		if distance < closest_distance:
			closest_distance = distance
			closest = candidate
	return closest

static func _get_owner_hurtbox_radius(owner: Node2D) -> float:
	if owner.has_method("get_hurtbox_radius"):
		return max(0.0, float(owner.call("get_hurtbox_radius")))
	return 0.0

extends RefCounted

static func get_role_sprite_offset(role_id: String, full_sizes: Dictionary, visible_bounds_map: Dictionary) -> Vector2:
	var full_size: Vector2 = full_sizes.get(role_id, Vector2.ZERO)
	var visible_bounds: Rect2 = visible_bounds_map.get(role_id, Rect2())
	var visible_center := visible_bounds.position + visible_bounds.size * 0.5
	return full_size * 0.5 - visible_center

static func get_role_visual_scale(role_id: String, target_height: float, scale_multipliers: Dictionary, visible_bounds_map: Dictionary) -> float:
	var visible_bounds: Rect2 = visible_bounds_map.get(role_id, Rect2())
	if visible_bounds.size.y <= 0.0:
		return 0.0
	var target_scale: float = target_height / visible_bounds.size.y
	return target_scale * float(scale_multipliers.get(role_id, 1.0))

static func get_role_health_bar_width(role_id: String, target_height: float, scale_multipliers: Dictionary, visible_bounds_map: Dictionary) -> float:
	var bounds_value: Variant = visible_bounds_map.get(role_id, Rect2(0.0, 0.0, 54.0, 72.0))
	var visible_bounds: Rect2 = Rect2(0.0, 0.0, 54.0, 72.0)
	if bounds_value is Rect2:
		visible_bounds = bounds_value
	if visible_bounds.size.x <= 0.0 or visible_bounds.size.y <= 0.0:
		return 54.0
	var target_scale: float = get_role_visual_scale(role_id, target_height, scale_multipliers, visible_bounds_map)
	return clamp(visible_bounds.size.x * target_scale * 0.72, 42.0, 72.0)

static func get_player_role_health_bar_width(owner, role_id: String) -> float:
	return get_role_health_bar_width(
		role_id,
		owner.ROLE_SKETCH_TARGET_HEIGHT,
		owner.ROLE_SKETCH_SCALE_MULTIPLIERS,
		owner.ROLE_SKETCH_VISIBLE_BOUNDS
	)

static func get_support_offset(role_id: String, facing_direction: Vector2, aggressive: bool) -> Vector2:
	var side := -1.0
	if role_id == "gunner":
		side = 1.0
	var lateral := facing_direction.orthogonal() * 34.0 * side
	var forward := facing_direction * (14.0 if aggressive else -10.0)
	return lateral + forward

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
	if owner.get("confinement_remaining") == null or float(owner.get("confinement_remaining")) <= 0.0:
		return
	var radius: float = float(owner.get("confinement_radius"))
	if radius <= 0.0:
		return
	var center_value: Variant = owner.get("confinement_center")
	if center_value is not Vector2:
		return
	var center: Vector2 = center_value
	var safe_radius: float = max(0.0, radius - _get_owner_hurtbox_radius(owner))
	var offset: Vector2 = owner.global_position - center
	if offset.length_squared() <= safe_radius * safe_radius:
		return
	owner.global_position = center + offset.normalized() * safe_radius

static func _get_owner_hurtbox_radius(owner: Node2D) -> float:
	if owner.has_method("get_hurtbox_radius"):
		return max(0.0, float(owner.call("get_hurtbox_radius")))
	return 0.0

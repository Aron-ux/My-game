extends RefCounted

# Handoff note:
# Player movement clamping lives here so map bounds remain gameplay data instead
# of visual-only HUD state. main.gd owns the active bounds; this flow discovers
# them through the scene tree and clamps after move_and_slide().

static func clamp_to_active_map_bounds(owner: Node2D) -> void:
	var bounds := get_active_map_bounds(owner)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	owner.global_position = Vector2(
		clamp(owner.global_position.x, bounds.position.x, bounds.position.x + bounds.size.x),
		clamp(owner.global_position.y, bounds.position.y, bounds.position.y + bounds.size.y)
	)

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

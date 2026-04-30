extends RefCounted

const MAP_BOUNDARY_VIEW := preload("res://scripts/map/map_boundary_view.gd")

# Handoff note:
# Map-scale presentation lives here. Keep gameplay rules separate:
# - player movement clamping is owned by player/player_map_bounds_flow.gd
# - HUD minimap drawing is owned by scripts/hud.gd
# - this flow only creates/updates map boundary and minimap presentation.

static func setup_map_features(main: Node) -> void:
	_setup_boundary_view(main)
	if main.hud != null and main.hud.has_method("configure_minimap"):
		main.hud.configure_minimap(main.map_bounds)

static func update_minimap(main: Node) -> void:
	if main.hud == null or not main.hud.has_method("update_minimap"):
		return
	main.hud.update_minimap(_build_minimap_payload(main))

static func _setup_boundary_view(main: Node) -> void:
	if main.map_boundary_node != null and is_instance_valid(main.map_boundary_node):
		if main.map_boundary_node.has_method("configure"):
			main.map_boundary_node.configure(main.map_bounds)
		return
	var boundary := MAP_BOUNDARY_VIEW.new()
	boundary.name = "MapBoundary"
	boundary.z_index = -20
	main.add_child(boundary)
	main.map_boundary_node = boundary
	boundary.configure(main.map_bounds)

static func _build_minimap_payload(main: Node) -> Dictionary:
	return {
		"bounds": main.map_bounds,
		"player_position": _get_node_position(main.player),
		"enemies": _collect_group_points(main, "enemies"),
		"boss_position": _get_node_position(main.boss_enemy) if main.boss_enemy != null and is_instance_valid(main.boss_enemy) else null,
		"gems": _collect_group_points(main, "exp_gems", 18),
		"hearts": _collect_group_points(main, "heart_pickups", 8)
	}

static func _collect_group_points(main: Node, group_name: String, limit: int = 48) -> Array:
	var points: Array = []
	for node in main.get_tree().get_nodes_in_group(group_name):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var entry := {
			"position": (node as Node2D).global_position
		}
		if node.has_method("get_minimap_kind"):
			entry["kind"] = str(node.get_minimap_kind())
		elif node.get("enemy_kind") != null:
			entry["kind"] = str(node.get("enemy_kind"))
		points.append(entry)
		if points.size() >= limit:
			break
	return points

static func _get_node_position(node) -> Variant:
	if node != null and is_instance_valid(node) and node is Node2D:
		return (node as Node2D).global_position
	return null

extends RefCounted

const MAP_BOUNDARY_VIEW := preload("res://scripts/map/map_boundary_view.gd")
const DEFAULT_MAP_BOUNDS := Rect2(Vector2(-1600.0, -900.0), Vector2(3200.0, 1800.0))

const TILE_MAP_LAYER_NAMES := {
	"GroundLayer": true,
	"RoadLayer": true,
	"WaterLayer": true,
	"DecorLayer": true,
	"ground": true,
	"stone": true
}
const MAP_BOUNDS_PADDING := 0.0


static func setup_boundary_view(main: Node) -> void:
	if main.map_boundary_node != null and is_instance_valid(main.map_boundary_node):
		if main.map_boundary_node.has_method("configure"):
			main.map_boundary_node.configure(main.map_bounds)
		apply_camera_limits(main)
		return
	var boundary: Node2D = create_battle_map_view()
	boundary.name = "MapBoundary"
	boundary.z_index = -20
	main.add_child(boundary)
	main.map_boundary_node = boundary
	apply_tile_map_bounds_to_main(main, boundary)
	if boundary.has_method("configure"):
		boundary.configure(main.map_bounds)
	apply_camera_limits(main)


static func create_battle_map_view() -> Node2D:
	return MAP_BOUNDARY_VIEW.new()


static func prepare_battle_map_scene(_map_scene: Node) -> void:
	pass


static func add_grassland_background(_map_scene: Node) -> void:
	pass


static func apply_tile_map_bounds_to_main(main: Node, map_scene: Node2D) -> void:
	var tile_bounds: Rect2 = calculate_tile_map_bounds(map_scene)
	if tile_bounds.size.x > 0.0 and tile_bounds.size.y > 0.0:
		main.map_bounds = tile_bounds.grow(MAP_BOUNDS_PADDING)
		return
	main.map_bounds = DEFAULT_MAP_BOUNDS


static func calculate_tile_map_bounds(map_scene: Node2D) -> Rect2:
	var merged := Rect2()
	var has_bounds: bool = false
	for child in map_scene.get_children():
		if not (child is TileMapLayer) or not (child.name in TILE_MAP_LAYER_NAMES):
			continue
		var layer_bounds: Rect2 = calculate_layer_bounds(child as TileMapLayer)
		if layer_bounds.size.x <= 0.0 or layer_bounds.size.y <= 0.0:
			continue
		if has_bounds:
			merged = merged.merge(layer_bounds)
		else:
			merged = layer_bounds
			has_bounds = true
	return merged if has_bounds else Rect2()


static func calculate_layer_bounds(layer: TileMapLayer) -> Rect2:
	var used_rect: Rect2i = layer.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return Rect2()
	var tile_size: Vector2 = Vector2(layer.tile_set.tile_size) if layer.tile_set != null else Vector2(32.0, 32.0)
	var top_left: Vector2 = layer.to_global(layer.map_to_local(used_rect.position) - tile_size * 0.5)
	var bottom_right_cell: Vector2i = used_rect.position + used_rect.size - Vector2i.ONE
	var bottom_right: Vector2 = layer.to_global(layer.map_to_local(bottom_right_cell) + tile_size * 0.5)
	return Rect2(top_left, bottom_right - top_left).abs()


static func apply_camera_limits(main: Node) -> void:
	var bounds: Rect2 = main.map_bounds
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var camera: Camera2D = get_player_camera(main)
	if camera == null:
		return
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.position.x + bounds.size.x)
	camera.limit_bottom = ceili(bounds.position.y + bounds.size.y)


static func get_player_camera(main: Node) -> Camera2D:
	var player: Variant = main.get("player")
	if player == null or not is_instance_valid(player):
		return null
	if player.get("camera_node") is Camera2D:
		return player.get("camera_node") as Camera2D
	if player is Node:
		return (player as Node).get_node_or_null("Camera2D") as Camera2D
	return null

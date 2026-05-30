extends RefCounted

const SORT_FRAME_META := "__enemy_occlusion_sort_frame"
const SORT_INTERVAL_FRAMES := 3
const BEHIND_OCCLUDER_Z_INDEX := 4
const OCCLUDER_Z_INDEX := 8
const IN_FRONT_OF_OCCLUDER_Z_INDEX := 9

const GLUTTON_Z_INDEX := OCCLUDER_Z_INDEX
const BEHIND_GLUTTON_Z_INDEX := BEHIND_OCCLUDER_Z_INDEX
const IN_FRONT_OF_GLUTTON_Z_INDEX := IN_FRONT_OF_OCCLUDER_Z_INDEX


static func update_scene_from_glutton(glutton) -> void:
	update_scene_from_occluder(glutton)


static func update_scene_from_occluder(occluder) -> void:
	if occluder == null or not is_instance_valid(occluder) or not occluder is Node:
		return
	if not _is_large_enemy_occluder(occluder as Node2D):
		return
	var scene: Node = _get_runtime_scene(occluder as Node)
	if scene == null:
		return
	var current_frame: int = Engine.get_physics_frames()
	var last_sort_frame: int = int(scene.get_meta(SORT_FRAME_META, -SORT_INTERVAL_FRAMES))
	if current_frame - last_sort_frame < SORT_INTERVAL_FRAMES:
		return
	scene.set_meta(SORT_FRAME_META, current_frame)
	_update_scene(scene)


static func _update_scene(scene: Node) -> void:
	var enemies: Array = _get_runtime_enemies(scene)
	if enemies.is_empty():
		return
	var occluders: Array[Node2D] = []
	var sortable_enemies: Array[Node2D] = []
	_collect_sort_targets(enemies, occluders, sortable_enemies)
	if occluders.is_empty():
		return
	for occluder in occluders:
		_apply_enemy_z_index(occluder, OCCLUDER_Z_INDEX)
	for enemy_node in sortable_enemies:
		_apply_enemy_z_index(enemy_node, _get_z_index_against_occluders(enemy_node, occluders))


static func _get_runtime_enemies(scene: Node) -> Array:
	if scene.has_method("get_runtime_enemies"):
		return scene.get_runtime_enemies()
	if scene.is_inside_tree():
		return scene.get_tree().get_nodes_in_group("enemies")
	return []


static func _get_runtime_scene(source: Node) -> Node:
	var cursor: Node = source
	while cursor != null:
		if cursor.has_method("get_runtime_enemies"):
			return cursor
		cursor = cursor.get_parent()
	var tree: SceneTree = source.get_tree()
	if tree != null:
		return tree.current_scene
	return null


static func _collect_sort_targets(enemies: Array, occluders: Array[Node2D], sortable_enemies: Array[Node2D]) -> void:
	for enemy in enemies:
		if not _is_valid_enemy_node(enemy):
			continue
		var enemy_node: Node2D = enemy as Node2D
		if _is_large_enemy_occluder(enemy_node):
			occluders.append(enemy_node)
		elif _should_sort_against_large_occluder(enemy_node):
			sortable_enemies.append(enemy_node)


static func _get_z_index_against_occluders(enemy: Node2D, occluders: Array[Node2D]) -> int:
	var enemy_sort_y: float = _get_sort_y(enemy)
	for occluder in occluders:
		if not is_instance_valid(occluder):
			continue
		var occluder_sort_y: float = _get_sort_y(occluder)
		if enemy_sort_y < occluder_sort_y:
			return BEHIND_OCCLUDER_Z_INDEX
	return IN_FRONT_OF_OCCLUDER_Z_INDEX


static func _apply_enemy_z_index(enemy: Node2D, z_value: int) -> void:
	enemy.z_index = z_value
	var visual: Node2D = enemy.get_node_or_null("ProfileVisual") as Node2D
	if visual != null:
		visual.z_index = 0
	var polygon: Polygon2D = enemy.get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null:
		polygon.z_index = 0


static func _is_valid_enemy_node(enemy: Variant) -> bool:
	return enemy != null and is_instance_valid(enemy) and enemy is Node2D and not (enemy as Node2D).is_queued_for_deletion()


static func _is_glutton(enemy: Node2D) -> bool:
	return bool(enemy.get("_is_glutton")) or str(enemy.get("behavior_id")) == "glutton" or str(enemy.get("secondary_behavior_id")) == "glutton"


static func _is_skulltomb(enemy: Node2D) -> bool:
	return str(enemy.get("behavior_id")) == "skulltomb" or str(enemy.get("secondary_behavior_id")) == "skulltomb"


static func _is_large_enemy_occluder(enemy: Node2D) -> bool:
	return _is_glutton(enemy) or _is_skulltomb(enemy)


static func _should_sort_against_large_occluder(enemy: Node2D) -> bool:
	var kind: String = str(enemy.get("enemy_kind"))
	return kind == "normal" or kind == "elite"


static func _get_sort_y(enemy: Node2D) -> float:
	var visual: Node = enemy.get_node_or_null("ProfileVisual")
	if visual != null and visual.has_method("get_shadow_world_ellipse"):
		var ellipse: Variant = visual.call("get_shadow_world_ellipse")
		if ellipse is Dictionary and not (ellipse as Dictionary).is_empty():
			return float((ellipse as Dictionary).get("center", enemy.global_position).y)
	return enemy.global_position.y

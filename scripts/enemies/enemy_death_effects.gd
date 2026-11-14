extends RefCounted

const SQUASH_DURATION := 0.18
const SQUASH_FADE_DELAY := 0.04
const SQUASH_X_SCALE := 1.18
const SQUASH_Y_SCALE := 0.24
const SQUASH_FOOT_OFFSET_RATIO := 0.18
const SPIN_SHRINK_DURATION := 0.32
const SPIN_SHRINK_TURNS := 1.0
const DEATH_FLY_DISTANCE := 48.0


static func spawn_spin_shrink(enemy, hit_direction: Vector2 = Vector2.ZERO) -> void:
	var scene := _get_current_scene(enemy)
	if scene == null:
		return
	var root := Node2D.new()
	root.name = "EnemySpinShrinkDeath"
	scene.add_child(root)
	root.global_position = enemy.global_position
	root.global_rotation = enemy.global_rotation
	root.scale = enemy.scale
	root.z_index = int(enemy.z_index)
	root.modulate = enemy.modulate
	if not _attach_profile_visual(root, enemy) and not _attach_boss_visual(root, enemy):
		_attach_fallback_polygon(root, enemy)

	var tween := root.create_tween()
	tween.set_parallel(true)
	if hit_direction.is_finite() and hit_direction.length_squared() > 0.001:
		tween.tween_property(root, "global_position", root.global_position + hit_direction.normalized() * DEATH_FLY_DISTANCE, SPIN_SHRINK_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "rotation", root.rotation + TAU * SPIN_SHRINK_TURNS, SPIN_SHRINK_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(root, "scale", Vector2.ZERO, SPIN_SHRINK_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(root.queue_free)


static func spawn_glutton_squash(enemy) -> void:
	var scene := _get_current_scene(enemy)
	if scene == null:
		return
	var root := Node2D.new()
	root.name = "GluttonSquashDeath"
	root.global_position = enemy.global_position + Vector2(0.0, float(enemy.get("contact_radius")) * SQUASH_FOOT_OFFSET_RATIO)
	root.scale = enemy.scale
	root.z_index = int(enemy.z_index)
	root.modulate = Color(1.0, 1.0, 1.0, 0.92)
	scene.add_child(root)

	if not _attach_profile_visual(root, enemy):
		_attach_fallback_polygon(root, enemy)

	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "scale", Vector2(root.scale.x * SQUASH_X_SCALE, root.scale.y * SQUASH_Y_SCALE), SQUASH_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "modulate:a", 0.0, max(0.05, SQUASH_DURATION - SQUASH_FADE_DELAY)).set_delay(SQUASH_FADE_DELAY)
	tween.chain().tween_callback(root.queue_free)


static func _attach_profile_visual(root: Node2D, enemy) -> bool:
	var visual_scene: PackedScene = enemy.get("profile_visual_scene") as PackedScene
	if visual_scene == null:
		return false
	var visual := visual_scene.instantiate() as Node2D
	if visual == null:
		return false
	root.add_child(visual)
	visual.position = Vector2.ZERO
	if visual.has_method("set_moving"):
		visual.set_moving(false)
	return true


static func _attach_boss_visual(root: Node2D, enemy) -> bool:
	var source: Node2D = enemy.get("boss_visual_instance") as Node2D
	if source == null or not is_instance_valid(source):
		return false
	var visual := source.duplicate() as Node2D
	if visual == null:
		return false
	root.add_child(visual)
	_disable_processing_recursive(visual)
	return true


static func _disable_processing_recursive(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_disable_processing_recursive(child)


static func _attach_fallback_polygon(root: Node2D, enemy) -> void:
	var source := enemy.get_node_or_null("Polygon2D") as Polygon2D
	var polygon := Polygon2D.new()
	if source != null:
		polygon.polygon = source.polygon
		polygon.color = source.color
		polygon.rotation = source.rotation
	else:
		polygon.polygon = PackedVector2Array([
			Vector2(-14.0, -14.0),
			Vector2(14.0, -14.0),
			Vector2(14.0, 14.0),
			Vector2(-14.0, 14.0)
		])
		polygon.color = Color(0.7, 0.85, 1.0, 0.92)
	root.add_child(polygon)


static func _get_current_scene(enemy) -> Node:
	if enemy == null or not is_instance_valid(enemy):
		return null
	if enemy is Node and not (enemy as Node).is_inside_tree():
		return null
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		return null
	return tree.current_scene

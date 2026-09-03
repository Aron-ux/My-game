extends RefCounted

const MODEL_ENEMY_KINDS := ["boss", "small_boss"]
const FALLBACK_MODEL_HURTBOX_SIDE := 128.0


static func get_shape(enemy: Node2D) -> Dictionary:
	if enemy == null or not is_instance_valid(enemy):
		return {}
	var enemy_kind: String = str(enemy.get("enemy_kind"))
	if enemy_kind not in MODEL_ENEMY_KINDS:
		return {}

	var visual: Node2D = enemy.get_node_or_null("ProfileVisual") as Node2D
	if visual == null:
		visual = enemy.get_node_or_null("BossVisual") as Node2D
	var sprite: AnimatedSprite2D = _find_animated_sprite(visual)
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(sprite.animation):
		var frame_texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if frame_texture != null:
			var frame_size: Vector2 = frame_texture.get_size()
			var world_scale: Vector2 = sprite.global_scale
			var side: float = max(frame_size.x * abs(world_scale.x), frame_size.y * abs(world_scale.y))
			if side > 0.0:
				return _build_square(sprite.global_position, side * 0.5)

	var contact_radius_value: Variant = enemy.get("contact_radius")
	var fallback_side: float = FALLBACK_MODEL_HURTBOX_SIDE
	if contact_radius_value != null:
		fallback_side = max(fallback_side, float(contact_radius_value) * 2.0)
	return _build_square(enemy.global_position, fallback_side * 0.5)


static func get_query_radius(enemy: Node2D) -> float:
	var shape := get_shape(enemy)
	if shape.is_empty():
		return 0.0
	return max(float(shape.get("half_extent", 0.0)), 0.0)


static func _find_animated_sprite(root: Node) -> AnimatedSprite2D:
	if root == null or not is_instance_valid(root):
		return null
	if root is AnimatedSprite2D:
		return root as AnimatedSprite2D
	var found: Node = root.find_child("AnimatedSprite2D", true, false)
	return found as AnimatedSprite2D


static func _build_square(center: Vector2, half_extent: float) -> Dictionary:
	var safe_half_extent: float = max(1.0, half_extent)
	return {
		"type": "square",
		"center": center,
		"half_extent": safe_half_extent,
		"horizontal_radius": safe_half_extent,
		"vertical_radius": safe_half_extent
	}

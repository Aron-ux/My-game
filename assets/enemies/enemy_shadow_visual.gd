extends RefCounted

const SHADOW_TEXTURE := preload("res://assets/阴影.png")
const SHADOW_COLOR := Color(0.58, 0.58, 0.58, 1.0)


static func ensure_shadow(owner: Node2D, current_shadow: Sprite2D, shadow_position: Vector2, shadow_scale: Vector2) -> Sprite2D:
	var shadow := current_shadow
	if shadow == null:
		shadow = owner.get_node_or_null("Shadow") as Sprite2D
	if shadow == null:
		shadow = Sprite2D.new()
		shadow.name = "Shadow"
		owner.add_child(shadow)
		owner.move_child(shadow, 0)
	shadow.texture = SHADOW_TEXTURE
	shadow.centered = true
	shadow.modulate = SHADOW_COLOR
	shadow.position = shadow_position
	shadow.scale = shadow_scale
	shadow.z_index = -1
	return shadow

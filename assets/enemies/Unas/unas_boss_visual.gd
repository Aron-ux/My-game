extends Node2D

const SHADOW_TEXTURE := preload("res://assets/阴影.png")
const SHADOW_COLOR := Color(0.28, 0.24, 0.32, 0.62)
const VISUAL_SCALE := Vector2(0.46, 0.46)
const SHADOW_SCALE := Vector2(2.25, 0.82)

var sprite: AnimatedSprite2D
var shadow: Sprite2D


func _ready() -> void:
	_ensure_visuals()


func get_shadow_world_ellipse() -> Dictionary:
	_ensure_visuals()
	if shadow == null or shadow.texture == null:
		return {}
	var texture_size: Vector2 = shadow.texture.get_size()
	var world_scale: Vector2 = shadow.global_scale
	return {
		"center": shadow.global_position,
		"horizontal_radius": texture_size.x * abs(world_scale.x) * 0.5,
		"vertical_radius": texture_size.y * abs(world_scale.y) * 0.5
	}


func get_shadow_world_radius() -> float:
	var ellipse: Dictionary = get_shadow_world_ellipse()
	if ellipse.is_empty():
		return 0.0
	return max(float(ellipse.get("horizontal_radius", 0.0)), float(ellipse.get("vertical_radius", 0.0)))


func _ensure_visuals() -> void:
	shadow = get_node_or_null("Shadow") as Sprite2D
	if shadow == null:
		shadow = Sprite2D.new()
		shadow.name = "Shadow"
		add_child(shadow)
		move_child(shadow, 0)
	shadow.texture = SHADOW_TEXTURE
	shadow.centered = true
	shadow.position = Vector2(0.0, 82.0)
	shadow.scale = SHADOW_SCALE
	shadow.modulate = SHADOW_COLOR
	shadow.z_index = -1

	sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	sprite.centered = true
	sprite.position = Vector2(0.0, -58.0)
	sprite.scale = VISUAL_SCALE
	sprite.z_index = 1
	if not sprite.is_playing():
		sprite.play()

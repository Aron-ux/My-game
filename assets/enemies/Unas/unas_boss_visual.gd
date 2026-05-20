extends Node2D

const SHADOW_TEXTURE := preload("res://assets/阴影.png")
const SHADOW_COLOR := Color(0.28, 0.24, 0.32, 0.62)
const VISUAL_SCALE := Vector2(0.46, 0.46)
const SHADOW_SCALE := Vector2(2.25, 0.82)

var sprite: AnimatedSprite2D
var shadow: Sprite2D


func _ready() -> void:
	_ensure_visuals()


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

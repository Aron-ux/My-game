extends Node2D

const RUN_ANIMATION := "treewalk"
const VISUAL_SCALE := Vector2(0.48, 0.48)
const SHADOW_SCALE := Vector2(1.656, 0.828)
const SHADOW_COLOR := Color(0.58, 0.58, 0.58, 1.0)

var sprite: AnimatedSprite2D
var shadow: Sprite2D
var last_moving_state: bool = false


func _ready() -> void:
	_ensure_sprite()
	set_moving(false)


func set_moving(is_moving: bool, move_direction: Vector2 = Vector2.ZERO) -> void:
	_ensure_sprite()
	last_moving_state = is_moving
	_update_facing(move_direction)
	if sprite.animation != RUN_ANIMATION or not sprite.is_playing():
		sprite.play(RUN_ANIMATION)


func play_hit() -> void:
	_ensure_sprite()
	if not sprite.is_playing():
		sprite.play(RUN_ANIMATION)


func get_shadow_world_ellipse() -> Dictionary:
	_ensure_sprite()
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
	var ellipse := get_shadow_world_ellipse()
	if ellipse.is_empty():
		return 0.0
	return max(float(ellipse.get("horizontal_radius", 0.0)), float(ellipse.get("vertical_radius", 0.0)))


func _update_facing(move_direction: Vector2) -> void:
	if abs(move_direction.x) <= 0.01:
		return
	sprite.flip_h = move_direction.x < 0.0


func _ensure_sprite() -> void:
	if sprite != null:
		return
	shadow = get_node_or_null("Shadow") as Sprite2D
	if shadow != null:
		shadow.centered = true
		shadow.position = Vector2(0.0, 8.0)
		shadow.scale = SHADOW_SCALE
		shadow.modulate = SHADOW_COLOR
		shadow.z_index = -1
	sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	sprite.centered = true
	sprite.position = Vector2(0.0, -36.0)
	sprite.scale = VISUAL_SCALE
	sprite.z_index = 1

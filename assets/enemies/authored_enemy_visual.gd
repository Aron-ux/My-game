extends Node2D

const SHADOW_TEXTURE := preload("res://assets/阴影.png")
const SHADOW_COLOR := Color(0.58, 0.58, 0.58, 1.0)

@export var move_animation: StringName
@export var hit_animation: StringName
@export var visual_scale: Vector2 = Vector2.ONE
@export var sprite_position: Vector2 = Vector2.ZERO
@export var sprite_faces_left_by_default: bool = true
@export var reference_animation: StringName
@export var shadow_scale: Vector2 = Vector2(0.7, 0.36)
@export var shadow_position: Vector2 = Vector2.ZERO

var sprite: AnimatedSprite2D
var shadow: Sprite2D
var hit_lock_remaining: float = 0.0
var last_moving_state: bool = false


func _ready() -> void:
	_ensure_visuals()
	set_moving(false)
	set_process(false)


func _process(delta: float) -> void:
	if hit_lock_remaining <= 0.0:
		set_process(false)
		return
	hit_lock_remaining = max(0.0, hit_lock_remaining - delta)
	if hit_lock_remaining <= 0.0:
		set_moving(last_moving_state)
		set_process(false)


func set_moving(is_moving: bool, move_direction: Vector2 = Vector2.ZERO) -> void:
	_ensure_visuals()
	last_moving_state = is_moving
	_update_facing(move_direction)
	_play_animation(move_animation)


func play_hit() -> void:
	_ensure_visuals()
	if hit_animation == StringName() or not _has_animation(hit_animation):
		return
	hit_lock_remaining = 0.18
	_play_animation(hit_animation)
	set_process(true)


func _update_facing(move_direction: Vector2) -> void:
	if sprite == null or abs(move_direction.x) <= 0.01:
		return
	sprite.flip_h = move_direction.x > 0.0 if sprite_faces_left_by_default else move_direction.x < 0.0


func _play_animation(animation_name: StringName) -> void:
	if sprite == null or animation_name == StringName() or not _has_animation(animation_name):
		return
	_apply_animation_size_correction(animation_name)
	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)


func _has_animation(animation_name: StringName) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name)


func _ensure_visuals() -> void:
	if sprite != null:
		return
	shadow = get_node_or_null("Shadow") as Sprite2D
	if shadow == null:
		shadow = Sprite2D.new()
		shadow.name = "Shadow"
		add_child(shadow)
		move_child(shadow, 0)
	shadow.texture = SHADOW_TEXTURE
	shadow.centered = true
	shadow.position = shadow_position
	shadow.scale = shadow_scale
	shadow.modulate = SHADOW_COLOR
	shadow.z_index = -1

	sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	sprite.centered = true
	sprite.position = sprite_position
	sprite.scale = visual_scale
	sprite.z_index = 1
	_apply_animation_size_correction(move_animation)


func _apply_animation_size_correction(animation_name: StringName) -> void:
	if sprite == null or animation_name == StringName() or not _has_animation(animation_name):
		return
	var reference_size := _get_animation_frame_size(_get_reference_animation())
	var current_size := _get_animation_frame_size(animation_name)
	if reference_size.x <= 0.0 or reference_size.y <= 0.0 or current_size.x <= 0.0 or current_size.y <= 0.0:
		sprite.scale = visual_scale
		return
	sprite.scale = Vector2(
		visual_scale.x * reference_size.x / current_size.x,
		visual_scale.y * reference_size.y / current_size.y
	)


func _get_reference_animation() -> StringName:
	if reference_animation != StringName():
		return reference_animation
	return move_animation


func _get_animation_frame_size(animation_name: StringName) -> Vector2:
	if not _has_animation(animation_name):
		return Vector2.ZERO
	var frame_count := sprite.sprite_frames.get_frame_count(animation_name)
	if frame_count <= 0:
		return Vector2.ZERO
	var texture := sprite.sprite_frames.get_frame_texture(animation_name, 0)
	if texture == null:
		return Vector2.ZERO
	return texture.get_size()

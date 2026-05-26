extends Node2D

const RUN_ANIMATION := "treewalk"
const ATTACK_ANIMATION := "treeattack"
const ATTACK_LOCK_DURATION := 0.62
const VISUAL_SCALE := Vector2(0.48, 0.48)
const SHADOW_SCALE := Vector2(1.656, 0.828)
const SHADOW_COLOR := Color(0.58, 0.58, 0.58, 1.0)

var sprite: AnimatedSprite2D
var shadow: Sprite2D
var last_moving_state: bool = false
var attack_locked: bool = false
var attack_lock_remaining: float = 0.0
var attack_base_speed_scale: float = 1.0


func _ready() -> void:
	_ensure_sprite()
	set_moving(false)


func _process(delta: float) -> void:
	if not attack_locked:
		return
	attack_lock_remaining = max(0.0, attack_lock_remaining - delta)
	if attack_lock_remaining <= 0.0:
		_release_attack_lock()


func set_moving(is_moving: bool, move_direction: Vector2 = Vector2.ZERO) -> void:
	_ensure_sprite()
	last_moving_state = is_moving
	_update_facing(move_direction)
	if attack_locked:
		return
	if sprite.animation != RUN_ANIMATION or not sprite.is_playing():
		sprite.play(RUN_ANIMATION)


func play_attack(duration: float = ATTACK_LOCK_DURATION) -> void:
	_ensure_sprite()
	if sprite == null:
		return
	attack_locked = true
	attack_lock_remaining = max(0.05, duration)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(ATTACK_ANIMATION):
		_apply_attack_speed_for_duration(ATTACK_ANIMATION, attack_lock_remaining)
		sprite.play(ATTACK_ANIMATION)
	else:
		sprite.speed_scale = attack_base_speed_scale
		sprite.play(RUN_ANIMATION)


func play_hit() -> void:
	_ensure_sprite()
	if attack_locked:
		return
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
	attack_base_speed_scale = sprite.speed_scale
	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)
	sprite.centered = true
	sprite.position = Vector2(0.0, -36.0)
	sprite.scale = VISUAL_SCALE
	sprite.z_index = 1


func _on_animation_finished() -> void:
	if sprite == null:
		return
	if sprite.animation != ATTACK_ANIMATION:
		return
	_release_attack_lock()


func _release_attack_lock() -> void:
	attack_locked = false
	attack_lock_remaining = 0.0
	if sprite != null:
		sprite.speed_scale = attack_base_speed_scale
		sprite.play(RUN_ANIMATION)


func _apply_attack_speed_for_duration(animation_name: StringName, target_duration: float) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var frame_count: int = sprite.sprite_frames.get_frame_count(animation_name)
	var animation_speed: float = sprite.sprite_frames.get_animation_speed(animation_name)
	if frame_count <= 0 or animation_speed <= 0.0 or target_duration <= 0.0:
		sprite.speed_scale = attack_base_speed_scale
		return
	var duration_sum: float = 0.0
	for frame_index in range(frame_count):
		duration_sum += sprite.sprite_frames.get_frame_duration(animation_name, frame_index)
	var natural_duration: float = duration_sum / animation_speed
	sprite.speed_scale = attack_base_speed_scale * natural_duration / target_duration

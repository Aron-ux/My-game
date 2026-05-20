extends Node2D

const SHADOW_TEXTURE := preload("res://assets/阴影.png")
const SHADOW_COLOR := Color(0.42, 0.42, 0.42, 0.72)
const IDLE_ANIMATION := &"roseidle"
const ATTACK_ANIMATION := &"roseattack"
const VISUAL_SCALE := Vector2(0.62, 0.62)
const SHADOW_SCALE := Vector2(1.25, 0.58)
const ATTACK_LOCK_SECONDS := 0.64

var sprite: AnimatedSprite2D
var shadow: Sprite2D
var attack_lock_remaining: float = 0.0


func _ready() -> void:
	_ensure_visuals()
	set_process(false)
	_play_idle()


func _process(delta: float) -> void:
	attack_lock_remaining = max(0.0, attack_lock_remaining - delta)
	if attack_lock_remaining > 0.0:
		return
	_play_idle()
	set_process(false)


func set_moving(_is_moving: bool, _move_direction: Vector2 = Vector2.ZERO) -> void:
	_ensure_visuals()
	if attack_lock_remaining <= 0.0:
		_play_idle()


func set_facing_direction(direction: Vector2) -> void:
	_ensure_visuals()
	if sprite == null or absf(direction.x) <= 0.001:
		return
	sprite.flip_h = direction.x < 0.0


func play_hit() -> void:
	_ensure_visuals()
	if attack_lock_remaining <= 0.0:
		_play_idle()


func play_attack() -> void:
	_ensure_visuals()
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(ATTACK_ANIMATION):
		return
	attack_lock_remaining = ATTACK_LOCK_SECONDS
	if sprite.animation != ATTACK_ANIMATION:
		sprite.play(ATTACK_ANIMATION)
	elif not sprite.is_playing():
		sprite.play()
	set_process(true)


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


func _play_idle() -> void:
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(IDLE_ANIMATION):
		return
	if sprite.animation != IDLE_ANIMATION or not sprite.is_playing():
		sprite.play(IDLE_ANIMATION)


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
	shadow.position = Vector2(0.0, 31.0)
	shadow.scale = SHADOW_SCALE
	shadow.modulate = SHADOW_COLOR
	shadow.z_index = -1

	sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	sprite.centered = true
	sprite.position = Vector2(0.0, -20.0)
	sprite.scale = VISUAL_SCALE
	sprite.z_index = 1

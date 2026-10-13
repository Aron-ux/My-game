extends Node2D

const CLIPS := [
	[&"mechanic-idle", preload("res://assets/players/mechanic/mechanic-idle.png"), 4, 5.0, true],
	[&"mechanic-run", preload("res://assets/players/mechanic/mechanic-run.png"), 8, 11.0, true],
	[&"mechanic-command", preload("res://assets/players/mechanic/mechanic-command.png"), 4, 12.0, false]
]

var sprite: AnimatedSprite2D
var moving := false
var commanding := false


func _ready() -> void:
	set_moving(moving)


func set_moving(is_moving: bool, move_direction: Vector2 = Vector2.ZERO) -> void:
	_ensure_sprite()
	moving = is_moving
	if abs(move_direction.x) > 0.01:
		sprite.flip_h = move_direction.x < 0.0
	if not commanding:
		sprite.play(&"mechanic-run" if moving else &"mechanic-idle")


func play_command() -> void:
	_ensure_sprite()
	if commanding:
		return
	commanding = true
	sprite.play(&"mechanic-command")


func _finish_command() -> void:
	commanding = false
	set_moving(moving)


func _ensure_sprite() -> void:
	if sprite != null:
		return
	sprite = $AnimatedSprite2D
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.remove_animation(&"default")
	for clip in CLIPS:
		sprite.sprite_frames.add_animation(clip[0])
		sprite.sprite_frames.set_animation_speed(clip[0], clip[3])
		sprite.sprite_frames.set_animation_loop(clip[0], clip[4])
		for index in range(clip[2]):
			var frame := AtlasTexture.new()
			frame.atlas = clip[1]
			frame.region = Rect2(index * 96, 0, 96, 96)
			sprite.sprite_frames.add_frame(clip[0], frame)
	sprite.animation_finished.connect(_finish_command)

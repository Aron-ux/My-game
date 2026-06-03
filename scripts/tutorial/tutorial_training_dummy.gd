extends Node2D

signal hit_registered

const TREEBOSS_SCENE := preload("res://assets/enemies/treeboss/treeboss.tscn")

var visual: Node2D
var hit_once: bool = false
var hit_flash_tween: Tween

var enemy_kind: String = "tutorial_dummy"
var archetype_id: String = "tutorial_dummy"
var behavior_id: String = "tutorial_dummy"
var reward_tier: int = 1
var pooled_inactive: bool = false
var current_health: float = 999999.0
var max_health: float = 999999.0
var contact_radius: float = 42.0
var body_collision_radius: float = 42.0
var touch_damage: float = 0.0
var slow_multiplier: float = 1.0
var slow_timer: float = 0.0
var vulnerability_bonus: float = 0.0
var vulnerability_timer: float = 0.0
var bleed_damage_per_second: float = 0.0
var bleed_timer: float = 0.0
var status_root: Node2D
var display_color: Color = Color(0.56, 0.85, 0.47, 1.0)
var base_scale: Vector2 = Vector2(2.05, 2.05)


func _ready() -> void:
	_spawn_visual()
	add_to_group("enemies")


func _spawn_visual() -> void:
	visual = TREEBOSS_SCENE.instantiate() as Node2D
	if visual == null:
		return
	visual.name = "Visual"
	visual.scale = base_scale
	add_child(visual)
	var animated_sprite: AnimatedSprite2D = visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null:
		return
	animated_sprite.play(&"treewalk")
	animated_sprite.stop()
	animated_sprite.frame = 0
	animated_sprite.frame_progress = 0.0


func take_damage(amount: float) -> bool:
	current_health = max(0.0, current_health - max(0.0, amount))
	_play_hit_flash()
	if not hit_once:
		hit_once = true
		hit_registered.emit()
	return false


func apply_bleed(damage_per_second: float, duration: float) -> void:
	bleed_damage_per_second = max(bleed_damage_per_second, max(0.0, damage_per_second))
	bleed_timer = max(bleed_timer, max(0.0, duration))


func apply_slow(multiplier: float, duration: float) -> void:
	slow_multiplier = min(slow_multiplier, multiplier)
	slow_timer = max(slow_timer, max(0.0, duration))


func apply_slow_silent(multiplier: float, duration: float) -> void:
	apply_slow(multiplier, duration)


func apply_vulnerability(bonus: float, duration: float) -> void:
	vulnerability_bonus = max(vulnerability_bonus, max(0.0, bonus))
	vulnerability_timer = max(vulnerability_timer, max(0.0, duration))


func _play_hit_flash() -> void:
	if visual == null:
		return
	if hit_flash_tween != null and hit_flash_tween.is_valid():
		hit_flash_tween.kill()
	visual.modulate = Color(1.0, 1.0, 1.0, 1.0)
	hit_flash_tween = create_tween()
	hit_flash_tween.tween_property(visual, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.04)
	hit_flash_tween.tween_property(visual, "modulate", Color(0.72, 0.72, 0.72, 1.0), 0.08)
	hit_flash_tween.tween_property(visual, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)

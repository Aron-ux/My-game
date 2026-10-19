extends Node2D

# Shared driver for the generated pixel sheets (scripts/tools/enemy_pixel_art).
# Deliberately no get_shadow_world_ellipse(): touch rings and sorting keep using
# contact_radius / origin for these enemies, as before the art rework.
# Each sheet row is one looping animation and the art faces right. Body sheets
# are exported at x2, so ART_PIXEL_SCALE makes one art pixel 0.75 world px.
#
# Hit feedback: an additive white flash, a quick squash-and-recoil away from
# the facing direction, and a material-specific burst sheet (hit_sheet) at a
# random point on the body.

const ENEMY_SHADOW_VISUAL := preload("res://assets/enemies/enemy_shadow_visual.gd")
const ART_PIXEL_SCALE := 0.375
const HIT_FLASH_DURATION := 0.14
const HIT_SQUASH_DURATION := 0.16
const HIT_SQUASH := Vector2(1.12, 0.88)
const HIT_RECOIL := 3.0
const HIT_BURST_COOLDOWN := 0.09
const SHEET_EFFECT := preload("res://scripts/enemies/enemy_sheet_effect.gd")

@export var sheet: Texture2D
@export var columns: int = 6
@export var rows: int = 1
@export var fps: float = 9.0
# Loop speed while standing still (stationary casters keep 1.0).
@export var idle_speed: float = 0.35
@export var art_scale: float = 1.0
# World offset of the sprite centre from the enemy origin (art facing right).
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var shadow_position: Vector2 = Vector2(0, 18)
@export var shadow_scale: Vector2 = Vector2(1.4, 1.1)
@export var hit_sheet: Texture2D
@export var hit_columns: int = 5
# Body centre and area (art facing right) where hit bursts may appear.
@export var hit_center: Vector2 = Vector2.ZERO
@export var hit_area: Vector2 = Vector2(24, 24)

static var _flash_material: CanvasItemMaterial

var sprite: Sprite2D
var flash: Sprite2D
var shadow: Sprite2D
var fx: Node2D
var moving := false
var facing := 1.0
var anim_time := 0.0
var hit_remaining := 0.0
var once_row := -1
var once_time := 0.0
var fx_was_active := false
var squash_remaining := 0.0
var burst_cooldown := 0.0


func _ready() -> void:
	_ensure_nodes()
	_apply_frame()


func set_moving(value: bool, direction := Vector2.ZERO) -> void:
	moving = value
	if absf(direction.x) > 0.01:
		facing = signf(direction.x)
	_ensure_nodes()
	_apply_facing()


func play_hit() -> void:
	hit_remaining = HIT_FLASH_DURATION
	squash_remaining = HIT_SQUASH_DURATION
	_spawn_hit_burst()


func _spawn_hit_burst() -> void:
	# Throttled so multi-hit attacks don't stack dozens of bursts on one enemy.
	if hit_sheet == null or burst_cooldown > 0.0 or not is_inside_tree():
		return
	burst_cooldown = HIT_BURST_COOLDOWN
	var spot := Vector2(randf_range(-0.5, 0.5) * hit_area.x, randf_range(-0.5, 0.5) * hit_area.y)
	var point := global_transform * facing_point(hit_center + spot)
	SHEET_EFFECT.spawn(get_tree().current_scene, hit_sheet, hit_columns, point, {"fps": 20.0, "art_scale": 1.3 * absf(global_scale.x), "z_index": 17})


# Plays one pass of a row (cast / throw), then returns to the looping row.
func play_once(row: int) -> void:
	once_row = row
	once_time = 0.0


func _process(delta: float) -> void:
	anim_time += delta * (1.0 if moving else idle_speed)
	hit_remaining = maxf(0.0, hit_remaining - delta)
	burst_cooldown = maxf(0.0, burst_cooldown - delta)
	if squash_remaining > 0.0:
		squash_remaining = maxf(0.0, squash_remaining - delta)
		_apply_hit_pose()
	if once_row >= 0:
		once_time += delta
		if once_time * fps >= columns:
			once_row = -1
	_update_state(delta)
	_apply_frame()
	# Redraw while effects are active, plus one frame to clear them afterwards.
	var fx_active := _wants_fx()
	if fx != null and (fx_active or fx_was_active):
		fx.queue_redraw()
	fx_was_active = fx_active


# Overridden by subclasses.
func _loop_row() -> int:
	return 0


func _update_state(_delta: float) -> void:
	pass


func _wants_fx() -> bool:
	return false


func _draw_fx(_canvas: Node2D) -> void:
	pass


func _apply_frame() -> void:
	if sprite == null:
		return
	var row := once_row if once_row >= 0 else _loop_row()
	var column := int(once_time * fps) if once_row >= 0 else int(anim_time * fps) % columns
	sprite.frame = clampi(row, 0, rows - 1) * columns + clampi(column, 0, columns - 1)
	flash.frame = sprite.frame
	flash.visible = hit_remaining > 0.0
	if flash.visible:
		flash.modulate.a = hit_remaining / HIT_FLASH_DURATION * 0.85


func _apply_facing() -> void:
	if sprite == null:
		return
	var flipped := facing < 0.0
	for node: Sprite2D in [sprite, flash]:
		node.flip_h = flipped
	_apply_hit_pose()


# Squash-and-recoil pivoting on the feet, so the monster stays planted.
func _apply_hit_pose() -> void:
	if sprite == null:
		return
	var t := squash_remaining / HIT_SQUASH_DURATION
	var amount := sin(t * PI) if t > 0.0 else 0.0
	var squash := Vector2.ONE.lerp(HIT_SQUASH, amount)
	var base_scale := Vector2.ONE * ART_PIXEL_SCALE * art_scale
	var frame_height := float(sheet.get_height()) / float(rows) * base_scale.y if sheet != null else 0.0
	var feet_y := sprite_offset.y + frame_height * 0.5
	var offset := facing_point(sprite_offset) + Vector2(-facing * HIT_RECOIL * amount, 0.0)
	offset.y = feet_y - (feet_y - sprite_offset.y) * squash.y
	for node: Sprite2D in [sprite, flash]:
		node.scale = base_scale * squash
		node.position = offset


# Mirrors an art-space offset (art faces right) into the current facing.
func facing_point(point: Vector2) -> Vector2:
	return Vector2(point.x * (-1.0 if facing < 0.0 else 1.0), point.y)


func _ensure_nodes() -> void:
	if sprite != null:
		return
	shadow = ENEMY_SHADOW_VISUAL.ensure_shadow(self, shadow, shadow_position, shadow_scale)
	sprite = Sprite2D.new()
	sprite.name = "AnimatedSheet"
	sprite.texture = sheet
	sprite.hframes = columns
	sprite.vframes = rows
	sprite.scale = Vector2.ONE * ART_PIXEL_SCALE * art_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = 1
	add_child(sprite)
	if _flash_material == null:
		_flash_material = CanvasItemMaterial.new()
		_flash_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash = Sprite2D.new()
	flash.name = "HitFlash"
	flash.texture = sheet
	flash.hframes = columns
	flash.vframes = rows
	flash.scale = sprite.scale
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	flash.material = _flash_material
	flash.z_index = 2
	flash.visible = false
	add_child(flash)
	fx = Node2D.new()
	fx.name = "SkillFx"
	fx.z_index = 3
	fx.draw.connect(_draw_fx.bind(fx))
	add_child(fx)
	_apply_facing()


# Pixel-snapped helpers so procedural skill effects keep the sheet's grain.
static func snap(point: Vector2, grid := 1.5) -> Vector2:
	return Vector2(roundf(point.x / grid) * grid, roundf(point.y / grid) * grid)


static func draw_pixel(canvas: CanvasItem, point: Vector2, color: Color, size := 3.0) -> void:
	var p := snap(point, size * 0.5)
	canvas.draw_rect(Rect2(p - Vector2.ONE * size * 0.5, Vector2.ONE * size), color)

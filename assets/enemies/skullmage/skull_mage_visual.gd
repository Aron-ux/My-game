extends "res://assets/enemies/pixel_sheet_visual.gd"

# Rows: 0 walk, 1 cast, 2 walk_ice, 3 cast_ice.
const ROW_CAST := 1
const ROW_ICE_OFFSET := 2
const ICE_SHARD := preload("res://assets/enemies/skullmage/ice_shard.png")
const DEATH_AURA := preload("res://assets/enemies/skullmage/death_aura.png")
# Staff crystal relative to the enemy origin, art facing right.
# Effect sheets keep their own x4 grain (see enemy_pixel_art/effects.py).
const EFFECT_PIXEL_SCALE := 0.375
const CRYSTAL_OFFSET := Vector2(23.5, -67.5)
const DRAIN_COLOR := Color(0.55, 1.0, 0.78)
const DRAIN_GLOW := Color(0.15, 0.85, 0.65)

var ice_active := false
var invulnerable := false
var drain_target: Vector2
var draining := false
var aura: Sprite2D
var effect_time := 0.0


func play_cast() -> void:
	play_once(ROW_CAST + (ROW_ICE_OFFSET if ice_active else 0))


func _loop_row() -> int:
	return ROW_ICE_OFFSET if ice_active else 0


func _update_state(delta: float) -> void:
	if aura == null:
		aura = Sprite2D.new()
		aura.name = "DeathAura"
		aura.texture = DEATH_AURA
		aura.hframes = 4
		aura.scale = Vector2.ONE * EFFECT_PIXEL_SCALE * 1.15
		aura.position = Vector2(0, 12)
		aura.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		aura.z_index = 0
		add_child(aura)
	effect_time += delta
	aura.visible = invulnerable
	if invulnerable:
		aura.frame = int(effect_time * 10.0) % 4
	if sprite != null:
		sprite.modulate = Color(0.85, 0.7, 1.0, 0.75 + 0.25 * sin(effect_time * 18.0)) if invulnerable else Color.WHITE


func _wants_fx() -> bool:
	return ice_active or draining


func _draw_fx(canvas: Node2D) -> void:
	if ice_active:
		_draw_ice_shards(canvas)
	if draining:
		_draw_drain(canvas)


func _draw_ice_shards(canvas: Node2D) -> void:
	var size := ICE_SHARD.get_size() * EFFECT_PIXEL_SCALE
	for index in 5:
		var angle := effect_time * 1.1 + float(index) * TAU / 5.0
		var depth := sin(angle)
		var point := snap(Vector2(cos(angle) * 38.0, depth * 15.0 - 22.0 + sin(effect_time * 3.0 + index) * 2.0))
		canvas.draw_texture_rect(ICE_SHARD, Rect2(point - size * 0.5, size), false, Color(1, 1, 1, 0.55 + 0.4 * (depth * 0.5 + 0.5)))


func _draw_drain(canvas: Node2D) -> void:
	var start := facing_point(CRYSTAL_OFFSET)
	var end := canvas.to_local(drain_target)
	var length := start.distance_to(end)
	if length < 1.0:
		return
	var axis := (end - start) / length
	var normal := axis.orthogonal()
	var steps := int(length / 6.0)
	# Blocky siphon: a wavering chain of pixels with a dim halo.
	for step in steps + 1:
		var t := float(step) / maxf(1.0, float(steps))
		var wave := sin(t * 14.0 - effect_time * 10.0) * 4.0 * sin(t * PI)
		var point := start.lerp(end, t) + normal * wave
		draw_pixel(canvas, point, Color(DRAIN_GLOW, 0.28), 9.0)
		draw_pixel(canvas, point, Color(DRAIN_COLOR, 0.85), 4.5)
	# Souls flowing back from the player to the staff.
	for index in 4:
		var progress := fposmod(effect_time * 1.5 + float(index) / 4.0, 1.0)
		var point := end.lerp(start, progress) + normal * sin(progress * 20.0) * 3.0
		draw_pixel(canvas, point, Color(0.85, 1.0, 0.9), 6.0)
	draw_pixel(canvas, end, Color(DRAIN_COLOR, 0.5 + 0.3 * sin(effect_time * 12.0)), 12.0)

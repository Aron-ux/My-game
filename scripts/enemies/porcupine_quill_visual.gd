extends Node2D

const SPEED := 900.0
const RADIUS := 150.0
const START_RADIUS := 24.0
const FLIGHT_TIME := (RADIUS - START_RADIUS) / SPEED
const FADE_TIME := 0.10
const COUNT := 24
const QUILL_TEXTURE := preload("res://assets/enemies/porcupine/quill.png")
const QUILL_FRAME := Vector2(72, 20)
const QUILL_SCALE := 0.375
var elapsed := 0.0
var enraged := false
var angle_offset := 0.0


func _ready() -> void:
	z_index = 14
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= FLIGHT_TIME + FADE_TIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var radius := minf(RADIUS, START_RADIUS + elapsed * SPEED)
	var alpha := 1.0 - clampf((elapsed - FLIGHT_TIME) / FADE_TIME, 0, 1)
	var trail := Color(1.0, 0.5, 0.22, alpha * 0.35) if enraged else Color(0.9, 0.86, 0.74, alpha * 0.28)
	# Pixel quill sheet: row 0 normal, row 1 enraged; 18x5 art px stored at x4.
	var source := Rect2(0, QUILL_FRAME.y * (1 if enraged else 0), QUILL_FRAME.x, QUILL_FRAME.y)
	var size := QUILL_FRAME * QUILL_SCALE
	for index in COUNT:
		var angle := angle_offset + float(index) * TAU / COUNT
		var axis := Vector2.from_angle(angle)
		var tip := axis * radius
		# Dotted pixel trail behind each quill.
		for step in 3:
			var point := tip - axis * (size.x + 6.0 + step * 7.0)
			draw_rect(Rect2(point.snapped(Vector2(1.5, 1.5)) - Vector2(1.5, 1.5), Vector2(3, 3)), Color(trail, trail.a * (1.0 - step * 0.3)))
		draw_set_transform(tip - axis * size.x * 0.5, angle, Vector2.ONE)
		draw_texture_rect_region(QUILL_TEXTURE, Rect2(-size * 0.5, size), source, Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

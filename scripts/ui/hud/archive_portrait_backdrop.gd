extends Control

const GOLD_WASH := Color(1.0, 0.68, 0.20, 0.12)
const GOLD_LINE := Color(1.0, 0.72, 0.24, 0.34)
const GOLD_DOT := Color(1.0, 0.78, 0.32, 0.50)
const BLUE_LINE := Color(0.52, 0.68, 0.88, 0.14)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var center := Vector2(size.x * 0.52, size.y * 0.42)
	var radius: float = minf(size.x, size.y) * 0.34
	_draw_aura(center, radius)
	_draw_build_grid()
	_draw_rune_cross(center, radius)

func _draw_aura(center: Vector2, radius: float) -> void:
	for index in range(4):
		var alpha := 0.11 - float(index) * 0.020
		draw_circle(center, radius + float(index) * 13.0, Color(1.0, 0.62, 0.12, alpha))
	draw_arc(center, radius, deg_to_rad(18.0), deg_to_rad(326.0), 96, GOLD_LINE, 1.4)
	draw_arc(center, radius * 0.68, deg_to_rad(205.0), deg_to_rad(520.0), 72, Color(1.0, 0.78, 0.32, 0.24), 1.0)
	draw_arc(center, radius * 1.22, deg_to_rad(-25.0), deg_to_rad(150.0), 80, Color(1.0, 0.78, 0.32, 0.18), 1.0)
	for index in range(8):
		var angle := TAU * float(index) / 8.0 + 0.20
		var point := center + Vector2(cos(angle), sin(angle)) * (radius + 12.0)
		_draw_diamond(point, 3.5, GOLD_DOT)

func _draw_build_grid() -> void:
	var step := 42.0
	var y := 18.0
	while y < size.y - 18.0:
		draw_line(Vector2(18.0, y), Vector2(size.x - 18.0, y), BLUE_LINE, 1.0)
		y += step
	var x := 26.0
	while x < size.x - 24.0:
		draw_line(Vector2(x, 16.0), Vector2(x, size.y - 16.0), Color(0.52, 0.68, 0.88, 0.06), 1.0)
		x += step

func _draw_rune_cross(center: Vector2, radius: float) -> void:
	var horizontal := Vector2(radius * 1.16, 0.0)
	var vertical := Vector2(0.0, radius * 0.86)
	draw_line(center - horizontal, center + horizontal, Color(1.0, 0.74, 0.24, 0.14), 1.0)
	draw_line(center - vertical, center + vertical, Color(1.0, 0.74, 0.24, 0.14), 1.0)
	_draw_diamond(center, 5.0, Color(1.0, 0.74, 0.24, 0.22))

func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0)
	])
	draw_colored_polygon(points, color)

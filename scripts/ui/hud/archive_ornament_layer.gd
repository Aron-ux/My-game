extends Control

const GOLD := Color(1.0, 0.74, 0.25, 0.82)
const GOLD_SOFT := Color(1.0, 0.74, 0.25, 0.30)
const BLUE_LINE := Color(0.48, 0.62, 0.78, 0.22)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	_draw_outer_frame(rect)
	_draw_header_filagree(rect)
	_draw_corner_marks(rect)
	_draw_subtle_scanlines(rect)

func _draw_outer_frame(rect: Rect2) -> void:
	draw_rect(rect, GOLD_SOFT, false, 1.0)
	var inner := rect.grow(-7.0)
	draw_rect(inner, Color(0.90, 0.62, 0.22, 0.26), false, 1.0)

func _draw_header_filagree(rect: Rect2) -> void:
	var y := rect.position.y + 66.0
	if y >= rect.end.y - 24.0:
		return
	var left := rect.position.x + 26.0
	var right := rect.end.x - 26.0
	draw_line(Vector2(left, y), Vector2(right, y), Color(0.95, 0.65, 0.22, 0.38), 1.0)
	var mid := rect.get_center().x
	_draw_diamond(Vector2(mid - 158.0, y), 5.0, GOLD_SOFT)
	_draw_diamond(Vector2(mid + 158.0, y), 5.0, GOLD_SOFT)
	_draw_diamond(Vector2(mid, y), 6.0, GOLD)

func _draw_corner_marks(rect: Rect2) -> void:
	var length: float = minf(54.0, minf(rect.size.x * 0.08, rect.size.y * 0.10))
	var inset := 12.0
	_draw_corner_mark(rect.position + Vector2(inset, inset), Vector2.RIGHT, Vector2.DOWN, length)
	_draw_corner_mark(Vector2(rect.end.x - inset, rect.position.y + inset), Vector2.LEFT, Vector2.DOWN, length)
	_draw_corner_mark(Vector2(rect.position.x + inset, rect.end.y - inset), Vector2.RIGHT, Vector2.UP, length)
	_draw_corner_mark(rect.end - Vector2(inset, inset), Vector2.LEFT, Vector2.UP, length)

func _draw_corner_mark(origin: Vector2, axis_x: Vector2, axis_y: Vector2, length: float) -> void:
	draw_line(origin, origin + axis_x * length, GOLD, 2.0)
	draw_line(origin, origin + axis_y * length, GOLD, 2.0)
	draw_line(origin + axis_x * 10.0 + axis_y * 10.0, origin + axis_x * 28.0 + axis_y * 10.0, GOLD_SOFT, 1.0)
	draw_line(origin + axis_x * 10.0 + axis_y * 10.0, origin + axis_x * 10.0 + axis_y * 28.0, GOLD_SOFT, 1.0)
	_draw_diamond(origin + axis_x * (length + 7.0), 4.0, GOLD_SOFT)
	_draw_diamond(origin + axis_y * (length + 7.0), 4.0, GOLD_SOFT)

func _draw_subtle_scanlines(rect: Rect2) -> void:
	var y := rect.position.y + 92.0
	while y < rect.end.y - 34.0:
		draw_line(Vector2(rect.position.x + 18.0, y), Vector2(rect.end.x - 18.0, y), BLUE_LINE, 1.0)
		y += 56.0

func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0)
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), color.lightened(0.18), 1.0)

extends Node2D

var phase := 0.0
var hit := 0.0

func set_moving(_moving: bool, _direction := Vector2.ZERO) -> void:
	pass

func play_hit() -> void:
	hit = 0.15

func _process(delta: float) -> void:
	phase += delta
	hit = maxf(0, hit - delta)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(0, 22), 24, Color(0.03, 0.03, 0.06, 0.4))
	var robe := Color(0.27, 0.2, 0.4).lightened(0.4 if hit > 0 else 0)
	draw_colored_polygon(PackedVector2Array([Vector2(-13, -18), Vector2(13, -18), Vector2(22, 29), Vector2(0, 21), Vector2(-22, 29)]), robe)
	draw_line(Vector2(0, -6), Vector2(0, 20), Color(0.67, 0.51, 0.8), 3)
	draw_circle(Vector2(0, -23), 17, Color(0.15, 0.1, 0.23))
	draw_circle(Vector2(0, -22), 11, Color(0.7, 0.75, 0.66))
	draw_circle(Vector2(-4, -23), 3, Color(0.45, 1, 0.8))
	draw_circle(Vector2(5, -23), 3, Color(0.45, 1, 0.8))
	draw_line(Vector2(-4, -14), Vector2(5, -14), Color(0.1, 0.08, 0.15), 3)
	draw_line(Vector2(27, 26), Vector2(27, -36), Color(0.63, 0.48, 0.75), 4)
	draw_line(Vector2(18, -29), Vector2(36, -29), Color(0.65, 1, 0.83), 4)
	draw_circle(Vector2(27, -39), 5, Color(0.6, 1, 0.85))
	draw_arc(Vector2(0, -5), 39, phase * 0.4, phase * 0.4 + TAU - 0.3, 40, Color(0.5, 0.8, 0.77, 0.35), 2)

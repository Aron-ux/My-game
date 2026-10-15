extends Node2D

var enraged := false
var moving := false
var facing := 1.0
var phase := 0.0
var hit_remaining := 0.0


func set_moving(value: bool, direction := Vector2.ZERO) -> void:
	moving = value
	if absf(direction.x) > 0.01:
		facing = signf(direction.x)


func play_hit() -> void:
	hit_remaining = 0.14


func _process(delta: float) -> void:
	phase += delta
	hit_remaining = maxf(0, hit_remaining - delta)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
	draw_circle(Vector2(0, 20), 30, Color(0.03, 0.02, 0.04, 0.35))
	var bob := sin(phase * 9) * 1.5 if moving else 0.0
	draw_set_transform(Vector2(0, bob), 0, Vector2(facing, 1))
	var body := Color(0.46, 0.21, 0.18) if enraged else Color(0.28, 0.22, 0.31)
	var quill := Color(0.97, 0.47, 0.34) if enraged else Color(0.72, 0.67, 0.8)
	if hit_remaining > 0:
		body = body.lightened(0.35)
	for index in 11:
		var angle := PI + float(index) * PI / 10
		var axis := Vector2.from_angle(angle)
		var root := axis * 23
		var tip := axis * (44 + 4 * (index % 2))
		draw_colored_polygon(PackedVector2Array([root - axis.orthogonal() * 5, tip, root + axis.orthogonal() * 5]), Color(0.09, 0.05, 0.13))
		draw_colored_polygon(PackedVector2Array([root - axis.orthogonal() * 3, tip - axis * 3, root + axis.orthogonal() * 3]), quill)
	draw_circle(Vector2(0, 0), 27, Color(0.08, 0.05, 0.12))
	draw_circle(Vector2(0, 0), 23, body)
	draw_circle(Vector2(23, 7), 14, body)
	draw_colored_polygon(PackedVector2Array([Vector2(29, 1), Vector2(42, 12), Vector2(25, 18)]), body)
	draw_circle(Vector2(39, 12), 4, Color(0.05, 0.04, 0.07))
	draw_circle(Vector2(23, 2), 3, Color(1, 0.32, 0.19) if enraged else Color(0.75, 0.48, 1))
	for x in [-14, 13]:
		var lift := sin(phase * 10 + float(x)) * 2 if moving else 0.0
		draw_line(Vector2(x, 13), Vector2(x + 3, 27 + lift), body.darkened(0.25), 8)
	if enraged:
		draw_arc(Vector2.ZERO, 35, phase * 1.2, phase * 1.2 + 4, 26, Color(1, 0.28, 0.13, 0.45), 3)

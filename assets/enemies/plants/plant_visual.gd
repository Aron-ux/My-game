extends Node2D

@export var variant := "vine"
var phase := 0.0
var moving := false
var facing := 1.0
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
	if variant == "seed":
		draw_circle(Vector2.ZERO, 16, Color(0.07, 0.06, 0.12))
		draw_circle(Vector2.ZERO, 12, Color(0.28, 0.16, 0.4))
		draw_arc(Vector2.ZERO, 9, phase, phase + 4, 16, Color(0.72, 0.48, 0.93), 2)
		draw_circle(Vector2(-3, -4), 3, Color(0.85, 0.64, 1))
		return
	var young := variant == "young"
	var vine := variant == "vine"
	var sway := sin(phase * 5) * (2.0 if moving else 0.6)
	var bark := Color(0.35, 0.27, 0.22) if not vine else Color(0.18, 0.32, 0.22)
	if hit_remaining > 0:
		bark = bark.lightened(0.5)
	draw_set_transform(Vector2(0, sway), 0, Vector2.ONE * (0.85 if young else 1.0))
	draw_circle(Vector2(0, 25), 24, Color(0.02, 0.04, 0.03, 0.32))
	for side in [-1, 1]:
		var root := PackedVector2Array([Vector2(side * 8, 13), Vector2(side * 14, 22), Vector2(side * 28, 27), Vector2(side * 13, 26), Vector2(side * 4, 18)])
		draw_polyline(root, Color(0.06, 0.1, 0.08), 9)
		draw_polyline(root, bark, 5)
		var arm := PackedVector2Array([Vector2(side * 10, -5), Vector2(side * 25, -1), Vector2(side * 29, -17), Vector2(side * 37, -24)])
		draw_polyline(arm, Color(0.06, 0.1, 0.08), 8)
		draw_polyline(arm, bark, 4)
	draw_colored_polygon(PackedVector2Array([Vector2(-13, -19), Vector2(12, -23), Vector2(18, 10), Vector2(10, 21), Vector2(-16, 18)]), Color(0.06, 0.1, 0.08))
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -17), Vector2(8, -20), Vector2(13, 8), Vector2(7, 17), Vector2(-12, 15)]), bark)
	draw_line(Vector2(-5, -13), Vector2(-1, 13), bark.lightened(0.18), 2)
	draw_line(Vector2(6, -14), Vector2(3, 10), bark.darkened(0.25), 2)
	var glow := Color(0.7, 0.95, 0.35) if vine else Color(0.75, 0.43, 1)
	for x in [-5, 6]:
		draw_circle(Vector2(x + facing, -6), 5, Color(glow, 0.18))
		draw_circle(Vector2(x + facing, -6), 2.3, glow)
	draw_line(Vector2(-5, 4), Vector2(6, 2), Color(0.04, 0.04, 0.06), 3)
	for index in (7 if vine else 4):
		var angle := float(index) * TAU / (7 if vine else 4) - PI * 0.5
		var point := Vector2.from_angle(angle) * 19 + Vector2(0, -20)
		draw_colored_polygon(PackedVector2Array([point, point + Vector2(-9, -6), point + Vector2(0, -20), point + Vector2(8, -7)]), Color(0.24, 0.46, 0.23) if vine else Color(0.2, 0.18, 0.29))
	if vine:
		draw_arc(Vector2(0, 5), 21, phase * 0.4, phase * 0.4 + 4, 18, Color(0.42, 0.65, 0.29), 3)

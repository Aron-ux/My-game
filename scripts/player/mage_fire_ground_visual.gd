extends Node2D

## 火球术留下的燃烧地面视觉。

var radius: float = 200.0
var _time := 0.0
var _flame_seed: float = 0.0


func _ready() -> void:
	z_index = 15
	_flame_seed = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var flicker := 0.85 + 0.15 * sin(_time * 13.0 + _flame_seed)
	var pulse := 0.5 + 0.5 * sin(_time * 5.0 + _flame_seed)
	# 燃烧地面本体（橙色→暗红渐变圆）
	var steps := 24
	var outer_points := PackedVector2Array()
	var inner_points := PackedVector2Array()
	for index in range(steps):
		var angle := float(index) / float(steps) * TAU
		var jitter := 1.0 + 0.06 * sin(_time * 11.0 + angle * 3.0 + _flame_seed)
		outer_points.append(Vector2.from_angle(angle) * radius * jitter)
		inner_points.append(Vector2.from_angle(angle) * radius * 0.82)
	draw_polygon(outer_points, PackedColorArray([Color(0.9, 0.34, 0.08, 0.30 * flicker)]))
	draw_polygon(inner_points, PackedColorArray([Color(1.0, 0.62, 0.16, 0.20 * flicker)]))
	# 边缘跳动火焰
	for index in range(10):
		var angle := float(index) / 10.0 * TAU + _flame_seed
		var flame_radius: float = radius * (0.92 + 0.10 * sin(_time * 17.0 + float(index) * 2.1 + _flame_seed))
		draw_circle(Vector2.from_angle(angle) * flame_radius, 7.0 + pulse * 4.0, Color(1.0, 0.72, 0.22, 0.55 * flicker))
	# 落点核心
	draw_circle(Vector2.ZERO, radius * 0.16, Color(1.0, 0.85, 0.4, 0.5))

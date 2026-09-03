extends Node2D

## 魔法榴弹飞行体视觉：紫色魔法光球 + 后向尾焰。
## 位置由能力脚本逐帧推进，本脚本只负责绘制。

var tail_direction: Vector2 = Vector2.RIGHT
var _glow_pulse := 0.0


func _ready() -> void:
	z_index = 26


func _process(delta: float) -> void:
	_glow_pulse += delta * 6.0
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_glow_pulse)
	# 尾焰
	var tail: Vector2 = -tail_direction.normalized()
	if tail.length_squared() <= 0.001:
		tail = Vector2.LEFT
	var tail_length := 16.0 + pulse * 8.0
	var tail_width := 7.0
	var tail_points := PackedVector2Array([
		Vector2.ZERO,
		Vector2.ZERO + tail * tail_length + Vector2(0.0, -tail_width) * 0.5,
		Vector2.ZERO + tail * tail_length * 1.35
	])
	draw_colored_polygon(tail_points, Color(0.55, 0.35, 1.0, 0.55))
	draw_line(Vector2.ZERO, Vector2.ZERO + tail * tail_length, Color(0.9, 0.72, 1.0, 0.9), 3.0)
	# 光晕
	draw_circle(Vector2.ZERO, 14.0 + pulse * 3.0, Color(0.72, 0.45, 1.0, 0.16))
	# 弹体
	draw_circle(Vector2.ZERO, 9.0, Color(0.82, 0.55, 1.0, 0.95))
	draw_circle(Vector2.ZERO, 5.5, Color(1.0, 0.92, 1.0, 1.0))

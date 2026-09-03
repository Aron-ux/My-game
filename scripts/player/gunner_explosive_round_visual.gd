extends Node2D

var direction := Vector2.RIGHT

func _ready() -> void:
	queue_redraw()

func _process(_delta: float) -> void:
	rotation = direction.angle()
	queue_redraw()

func _draw() -> void:
	# 尾焰：向后（局部 -X 方向）延伸的渐隐拖尾
	draw_line(Vector2(-34.0, 0.0), Vector2(-10.0, 0.0), Color(1.0, 0.26, 0.06, 0.28), 6.0)
	draw_line(Vector2(-26.0, 0.0), Vector2(-9.0, 0.0), Color(1.0, 0.5, 0.12, 0.5), 4.0)
	# 弹体：外圈红晕 -> 中圈橙 -> 核心亮黄白
	draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.34, 0.08, 0.7))
	draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.6, 0.2, 0.95))
	draw_circle(Vector2.ZERO, 3.6, Color(1.0, 0.94, 0.62, 1.0))

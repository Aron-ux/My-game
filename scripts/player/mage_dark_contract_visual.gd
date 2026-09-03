extends Node2D

## 黑暗契约球体视觉：黑色核心 + 旋转的暗紫吸积光环。

var _spin := 0.0
var _pulse := 0.0


func _ready() -> void:
	z_index = 27


func _process(delta: float) -> void:
	_spin += delta * 5.2
	_pulse += delta * 7.0
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_pulse)
	# 暗紫光环
	draw_arc(Vector2.ZERO, 20.0 + pulse * 4.0, 0.0, TAU, 40, Color(0.55, 0.25, 0.85, 0.8), 2.5)
	draw_arc(Vector2.ZERO, 30.0 + pulse * 6.0, _spin, _spin + PI * 1.25, 40, Color(0.72, 0.4, 1.0, 0.45), 2.0)
	draw_arc(Vector2.ZERO, 30.0 + pulse * 6.0, _spin + PI, _spin + PI * 2.25, 40, Color(0.72, 0.4, 1.0, 0.45), 2.0)
	# 黑色球体
	draw_circle(Vector2.ZERO, 13.0 + pulse * 1.5, Color(0.04, 0.02, 0.07, 0.98))
	draw_circle(Vector2.ZERO, 9.0, Color(0.08, 0.04, 0.14, 1.0))
	draw_circle(Vector2(2.0, -2.0), 4.0, Color(0.35, 0.2, 0.6, 0.9))

extends Node2D

## 审判之誓：从天而降后插在地面的金色巨剑视觉。

var _elapsed := 0.0


func _ready() -> void:
	z_index = 20


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_elapsed * 4.0)
	# 落点符文环
	draw_arc(Vector2.ZERO, 46.0 + pulse * 3.0, 0.0, TAU, 48, Color(1.0, 0.86, 0.5, 0.55), 2.0)
	draw_arc(Vector2.ZERO, 62.0, _elapsed * 1.2, _elapsed * 1.2 + PI * 0.8, 48, Color(1.0, 0.95, 0.75, 0.35), 1.5)
	# 金色光柱（从天而降的余晖）
	draw_rect(Rect2(-7.0, -70.0, 14.0, 140.0 + pulse * 6.0), Color(1.0, 0.92, 0.7, 0.16))
	# 剑刃（尖朝下插入地面）
	var blade := PackedVector2Array([
		Vector2(-11.0, -54.0),
		Vector2(11.0, -54.0),
		Vector2(9.0, 30.0),
		Vector2(0.0, 52.0),
		Vector2(-9.0, 30.0)
	])
	draw_colored_polygon(blade, Color(0.98, 0.9, 0.72, 0.96))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3.2, -54.0), Vector2(3.2, -54.0), Vector2(2.6, 40.0), Vector2(-2.6, 40.0)
	]), Color(1.0, 1.0, 0.95, 1.0))
	# 剑柄
	draw_rect(Rect2(-13.0, -70.0, 26.0, 8.0), Color(0.85, 0.66, 0.3, 1.0))
	draw_circle(Vector2(0.0, -78.0), 6.0, Color(0.75, 0.55, 0.25, 1.0))
	draw_circle(Vector2(0.0, -78.0), 3.2, Color(1.0, 0.95, 0.8, 1.0))

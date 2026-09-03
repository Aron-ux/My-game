extends Node2D

## 魔眼聚合：枪手前方的持续蓝色加农炮光束视觉。

var origin_position: Vector2 = Vector2.ZERO
var beam_direction: Vector2 = Vector2.RIGHT
var beam_length: float = 450.0
var beam_width: float = 64.0
var follow_target: Node2D = null
var flash := 0.0
var _time := 0.0


func _ready() -> void:
	z_index = 24


func _process(delta: float) -> void:
	_time += delta
	flash = max(0.0, flash - delta * 3.0)
	if follow_target != null:
		if is_instance_valid(follow_target):
			var direction := beam_direction.normalized()
			if direction.length_squared() <= 0.001:
				direction = Vector2.RIGHT
			origin_position = follow_target.global_position + direction * 20.0
		else:
			queue_free()
	queue_redraw()


func fire_pulse() -> void:
	flash = 1.0


func _draw() -> void:
	var direction := beam_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	var side := Vector2(-direction.y, direction.x)
	var brightness := 0.75 + 0.25 * sin(_time * 9.0)
	brightness += flash * 0.5
	var color := Color(0.3, 0.62, 1.0, clampf(brightness, 0.0, 1.35))
	var half_width := beam_width * 0.5
	var points := PackedVector2Array([
		origin_position + side * 13.0,
		origin_position + direction * beam_length + side * half_width,
		origin_position + direction * beam_length - side * half_width,
		origin_position - side * 13.0
	])
	draw_colored_polygon(points, color)
	# 中心亮核
	draw_line(origin_position, origin_position + direction * beam_length, Color(0.85, 0.95, 1.0, clampf(0.9 + flash, 0.0, 1.5)), 8.0)
	# 炮口光球（魔眼）
	draw_circle(origin_position, 14.0, Color(0.3, 0.66, 1.0, 0.95))
	draw_circle(origin_position, 8.0, Color(0.85, 0.97, 1.0, 1.0))

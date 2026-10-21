extends Node2D

## 火球术：0.5 秒聚能期间飞向落点的火球。
## 火球由 3 个绕轴旋转的焰瓣、拖着余烬的尾焰和外层热辉组成；
## 抵达后由技能本体结算爆炸，本节点自行淡出。

const TRAVEL_TIME := 0.5
const FLAME_COUNT := 3
const TAIL_LENGTH := 34.0
const TAIL_POINTS := 9
const MAX_TRAIL_POINTS := 18

const EMBER := Color(1.0, 0.78, 0.34, 1.0)
const FLAME := Color(1.0, 0.55, 0.16, 1.0)
const DEEP := Color(0.86, 0.20, 0.06, 1.0)
const SMOKE := Color(0.28, 0.10, 0.06, 1.0)
const HOT_CORE := Color(1.0, 0.95, 0.78, 1.0)

var radius: float = 26.0
var start_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var travel: float = 0.0
var fade: float = 1.0

var _time := 0.0
var _trail: Array[Dictionary] = []
var _armed := true
var _arc_height := 40.0


func _ready() -> void:
	z_index = 22
	add_to_group("temporary_effects")
	_arc_height = clampf(start_position.distance_to(target_position) * 0.18, 18.0, 70.0)


func _process(delta: float) -> void:
	_time += delta
	if _armed:
		travel = minf(1.0, travel + delta / TRAVEL_TIME)
		# 抛物线：先抬升再俯冲落点。
		var eased := ease(travel, 0.55)
		var base := start_position.lerp(target_position, eased)
		var lift := sin(travel * PI) * _arc_height
		global_position = base - Vector2(0.0, lift)
		_trail.append({"pos": global_position + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 4.0)), "age": 0.0, "size": randf_range(0.6, 1.2)})
		if _trail.size() > MAX_TRAIL_POINTS:
			_trail.pop_front()
		if travel >= 1.0:
			_armed = false
	else:
		fade = maxf(0.0, fade - delta * 5.0)
		if fade <= 0.0:
			queue_free()
	for index in range(_trail.size() - 1, -1, -1):
		_trail[index]["age"] = float(_trail[index]["age"]) + delta
		if float(_trail[index]["age"]) > 0.34:
			_trail.remove_at(index)
	queue_redraw()


func get_impact_position() -> Vector2:
	return target_position


func _draw() -> void:
	# 尾焰：从旧到新的余烬，颜色由暗红转向亮黄。
	for index in _trail.size():
		var point: Dictionary = _trail[index]
		var age: float = float(point["age"]) / 0.34
		var local: Vector2 = (point["pos"] as Vector2) - global_position
		var color := SMOKE if age > 0.7 else (DEEP if age > 0.4 else FLAME)
		var size: float = radius * 0.32 * float(point["size"]) * (1.0 - age * 0.8) * fade
		if size > 0.5:
			draw_circle(local, size, Color(color, (1.0 - age) * 0.75 * fade))

	if fade <= 0.0:
		return

	# 外层热辉 + 中层火团。
	var pulse := 0.9 + 0.1 * sin(_time * 26.0)
	draw_circle(Vector2.ZERO, radius * 1.35 * pulse, Color(DEEP, 0.30 * fade))
	draw_circle(Vector2.ZERO, radius * 1.05 * pulse, Color(FLAME, 0.55 * fade))
	# 三个绕轴旋转的焰瓣：用旋转的长椭圆拼出翻滚的火球。
	for index in FLAME_COUNT:
		var angle := _time * 11.0 + float(index) * TAU / float(FLAME_COUNT)
		var side := Vector2.from_angle(angle)
		var lobe := radius * (0.62 + 0.12 * sin(_time * 17.0 + float(index)))
		draw_colored_polygon(PackedVector2Array([
			side * lobe + side.orthogonal() * radius * 0.34,
			-side * lobe * 0.7,
			side * lobe - side.orthogonal() * radius * 0.34,
		]), Color(EMBER, 0.75 * fade))
	# 核心：最亮的白黄点，随旋转轻微偏移。
	var core_offset := Vector2.from_angle(_time * 8.0) * radius * 0.12
	draw_circle(core_offset, radius * 0.52, Color(FLAME, 0.9 * fade))
	draw_circle(core_offset, radius * 0.3, Color(HOT_CORE, fade))
	# 向外甩出的火星。
	for index in 5:
		var spark_angle := _time * 6.0 + float(index) * 1.7
		var distance := radius * (1.25 + 0.35 * sin(_time * 9.0 + float(index) * 2.3))
		draw_circle(Vector2.from_angle(spark_angle) * distance, 1.8, Color(EMBER, 0.8 * fade))

extends Node2D

## 魔眼聚合：枪手前方的紫色激光加农炮（细长光束 + 炮口聚能 + 沿线能量脉冲）。
## 判定宽度仍由技能里的 BEAM_WIDTH 决定，这里只画视觉。

const ERUPT_TIME := 0.12
# 视觉核心半径（远小于判定半宽，做“细”的激光感）。
const CORE_RADIUS := 4.2
const GLOW_RADIUS := 11.0
const COIL_RADIUS := 17.0
const PULSE_COUNT := 6
const PULSE_SPEED := 1500.0
const SPARK_COUNT := 7

const CORE := Color(1.0, 0.94, 1.0, 1.0)
const HOT := Color(0.86, 0.62, 1.0, 1.0)
const MID := Color(0.66, 0.28, 1.0, 1.0)
const OUTER := Color(0.40, 0.10, 0.78, 1.0)
const DEEP := Color(0.22, 0.04, 0.44, 1.0)

var origin_position: Vector2 = Vector2.ZERO
var beam_direction: Vector2 = Vector2.RIGHT
var beam_length: float = 450.0
var beam_width: float = 64.0
var follow_target: Node2D = null
var flash := 0.0

var _time := 0.0
var _erupt := 0.0
var _recoil := 0.0
var _pulses: Array[float] = []
var _sparks: Array[Vector3] = []


func _ready() -> void:
	z_index = 24


func _process(delta: float) -> void:
	_time += delta
	_erupt = minf(1.0, _erupt + delta / ERUPT_TIME)
	flash = maxf(0.0, flash - delta * 3.0)
	_recoil = maxf(0.0, _recoil - delta * 7.0)
	if follow_target != null:
		if is_instance_valid(follow_target):
			origin_position = follow_target.global_position + _direction() * 20.0
		else:
			queue_free()
	_advance_pulses(delta)
	_advance_sparks()
	queue_redraw()


func fire_pulse() -> void:
	flash = 1.0
	_recoil = 1.0
	# 每发都从炮口推出一道能量波，让光束看起来在“连续开火”。
	_pulses.append(0.0)
	if _pulses.size() > PULSE_COUNT:
		_pulses.remove_at(0)
	for index in SPARK_COUNT:
		_sparks.append(Vector3(_time, randf_range(-1.0, 1.0), randf_range(0.6, 1.4)))


func _advance_pulses(delta: float) -> void:
	for index in range(_pulses.size() - 1, -1, -1):
		_pulses[index] += delta
		if _pulses[index] > beam_length / PULSE_SPEED + 0.1:
			_pulses.remove_at(index)


func _advance_sparks() -> void:
	for index in range(_sparks.size() - 1, -1, -1):
		if _time - _sparks[index].x > 0.28:
			_sparks.remove_at(index)


func _direction() -> Vector2:
	var direction := beam_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	return direction


func _draw() -> void:
	var direction := _direction()
	var side := Vector2(-direction.y, direction.x)
	var end := origin_position + direction * beam_length
	var flicker := 0.9 + 0.1 * sin(_time * 34.0) + 0.06 * sin(_time * 71.0)
	var heat := clampf(flicker + flash * 0.35, 0.0, 1.4)
	# 起手：光束从炮口冲出去。
	var reach: float = beam_length * ease(_erupt, 0.35)
	var tip := origin_position + direction * reach

	# 外辉光（宽而暗，给紫色底）。
	_draw_tapered_beam(origin_position, tip, side, GLOW_RADIUS * (1.0 + flash * 0.25), OUTER, 0.26 * heat)
	_draw_tapered_beam(origin_position, tip, side, GLOW_RADIUS * 0.62, MID, 0.34 * heat)
	# 主体：细的亮紫激光。
	_draw_tapered_beam(origin_position, tip, side, CORE_RADIUS * 1.8, MID, 0.95)
	_draw_tapered_beam(origin_position, tip, side, CORE_RADIUS * 0.95, HOT, 0.95)
	# 白色芯线：分段轻微抖动，让光束像在放电而不是一根直棍。
	var steps := maxi(2, int(reach / 26.0))
	var axis := origin_position.direction_to(tip)
	var previous := origin_position
	for step in range(1, steps + 1):
		var t := float(step) / float(steps)
		var point := origin_position + axis * (reach * t) + side * sin(_time * 46.0 + float(step) * 1.7) * 1.1
		draw_line(previous, point, Color(0.97, 0.86, 1.0, 0.95), CORE_RADIUS * 0.55, true)
		previous = point

	# 沿光束游走的能量脉冲。
	for progress in _pulses:
		var distance: float = progress * PULSE_SPEED
		if distance > reach:
			continue
		var center: Vector2 = origin_position + direction * distance
		var life: float = 1.0 - clampf(distance / maxf(reach, 1.0), 0.0, 1.0) * 0.45
		var jitter: Vector2 = side * sin(_time * 40.0 + distance * 0.05) * 1.2
		_draw_soft_ellipse(center + jitter, direction, CORE_RADIUS * 7.0, CORE_RADIUS * 4.4, Color(MID, 0.22 * life))
		_draw_soft_ellipse(center + jitter, direction, CORE_RADIUS * 4.2, CORE_RADIUS * 2.6, Color(HOT, 0.55 * life))
		_draw_soft_ellipse(center + jitter, direction, CORE_RADIUS * 1.9, CORE_RADIUS * 1.3, Color(CORE, 0.9 * life))

	# 沿线电火花：贴着光束跳动。
	for spark in _sparks:
		var age := (_time - spark.x) / 0.28
		var along := fposmod(spark.y * 97.0 + age * 160.0, 1.0) * reach
		var point := origin_position + direction * along + side * spark.y * CORE_RADIUS * 2.2
		draw_line(point, point - direction * 7.0, Color(CORE, (1.0 - age) * 0.85), 1.4, true)

	# 炮口：魔眼聚能球 + 蓄能环 + 后坐力闪光。
	var muzzle := origin_position
	draw_circle(muzzle, COIL_RADIUS * (1.0 + flash * 0.3), Color(DEEP, 0.55))
	draw_circle(muzzle, COIL_RADIUS * 0.7, Color(OUTER, 0.55))
	draw_circle(muzzle, CORE_RADIUS * 2.4, Color(MID, 0.85))
	draw_circle(muzzle, CORE_RADIUS * 1.2, Color(CORE, 1.0))
	for index in 3:
		var phase := fposmod(_time * (2.2 + index * 0.6) + float(index) / 3.0, 1.0)
		var radius := COIL_RADIUS * (0.5 + phase * 0.9)
		draw_arc(muzzle, radius, 0.0, TAU, 20, Color(HOT, (1.0 - phase) * 0.7), 2.0, true)
	if _recoil > 0.0:
		for index in 6:
			var angle := side.angle() + (float(index) - 2.5) * 0.55
			if index % 2 == 0:
				angle = -side.angle() + (float(index) - 2.5) * 0.55
			var length := (6.0 + index * 3.0) * _recoil
			var start := muzzle + Vector2.from_angle(angle) * CORE_RADIUS * 2.0
			draw_line(start, start + Vector2.from_angle(angle) * length, Color(CORE, _recoil * 0.8), 2.0, true)

	# 命中端：亮点 + 十字闪光，随脉冲呼吸。
	if reach >= beam_length - 0.5:
		var impact_glow := 0.45 + 0.25 * sin(_time * 18.0)
		draw_circle(end, CORE_RADIUS * 3.4, Color(MID, impact_glow * 0.5))
		draw_circle(end, CORE_RADIUS * 1.6, Color(CORE, impact_glow))
		draw_line(end - side * CORE_RADIUS * 5.0, end + side * CORE_RADIUS * 5.0, Color(CORE, impact_glow), 1.6, true)


func _draw_tapered_beam(start: Vector2, finish: Vector2, side: Vector2, half_width: float, color: Color, alpha: float) -> void:
	if alpha <= 0.0:
		return
	# 靠近炮口更粗，远端收细。
	var near := half_width
	var far := half_width * 0.62
	draw_colored_polygon(PackedVector2Array([
		start + side * near,
		finish + side * far,
		finish - side * far,
		start - side * near,
	]), Color(color, alpha))


func _draw_soft_ellipse(center: Vector2, direction: Vector2, along: float, across: float, color: Color) -> void:
	var side := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([
		center + direction * along,
		center + side * across,
		center - direction * along,
		center - side * across,
	]), color)

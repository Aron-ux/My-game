extends Node2D

## 火球术爆炸：向外翻滚的火球团 + 上扬的焰舌 + 甩出的火星，最后化为暗红余烬。
## 0.55 秒后自动结束；伤害由技能本体结算，这里只负责表现。

const DURATION := 0.55
const LOBE_COUNT := 9
const TONGUE_COUNT := 12
const EMBER_COUNT := 22
const VISUAL_UPDATE_INTERVAL := 1.0 / 30.0

const HOT_CORE := Color(1.0, 0.97, 0.82, 1.0)
const EMBER := Color(1.0, 0.80, 0.36, 1.0)
const FLAME := Color(1.0, 0.52, 0.14, 1.0)
const DEEP := Color(0.82, 0.18, 0.05, 1.0)
const SMOKE := Color(0.22, 0.09, 0.06, 1.0)

var radius: float = 120.0
var elapsed := 0.0

var _lobes: Array[Dictionary] = []
var _tongues: Array[Dictionary] = []
var _embers: Array[Dictionary] = []
var _visual_elapsed := VISUAL_UPDATE_INTERVAL


func _ready() -> void:
	z_index = 18
	add_to_group("temporary_effects")
	for index in LOBE_COUNT:
		_lobes.append({
			"angle": float(index) / float(LOBE_COUNT) * TAU + randf_range(-0.2, 0.2),
			"reach": randf_range(0.68, 1.0),
			"speed": randf_range(1.4, 2.2),
			"spin": randf_range(-0.6, 0.6),
		})
	for index in TONGUE_COUNT:
		_tongues.append({
			"angle": float(index) / float(TONGUE_COUNT) * TAU + randf_range(-0.14, 0.14),
			"height": randf_range(0.35, 0.85),
			"wobble": randf_range(0.7, 1.6),
		})
	for index in EMBER_COUNT:
		_embers.append({
			"angle": randf() * TAU,
			"speed": randf_range(0.5, 1.3),
			"rise": randf_range(0.6, 1.5),
			"size": randf_range(1.5, 3.4),
		})


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	_visual_elapsed += delta
	if _visual_elapsed >= VISUAL_UPDATE_INTERVAL:
		_visual_elapsed = fmod(_visual_elapsed, VISUAL_UPDATE_INTERVAL)
		queue_redraw()


func _draw() -> void:
	var t := clampf(elapsed / DURATION, 0.0, 1.0)
	var growth := 1.0 - pow(1.0 - minf(t * 2.6, 1.0), 3.0)
	var fade := 1.0 - smoothstep(0.45, 1.0, t)
	var heat := 1.0 - smoothstep(0.15, 0.8, t)
	var current_radius := radius * (0.35 + growth * 0.85)

	# 冲击外圈：一圈快速外扩的亮边。
	if t < 0.35:
		var ring_ratio := t / 0.35
		draw_arc(Vector2.ZERO, radius * (0.4 + ring_ratio * 1.0), 0.0, TAU, 48, Color(EMBER, (1.0 - ring_ratio) * 0.75), 5.0 * (1.0 - ring_ratio) + 1.0, true)

	# 底层：暗红火海 + 橙色火团。
	draw_circle(Vector2.ZERO, current_radius * 1.02, Color(DEEP, 0.42 * fade))
	draw_circle(Vector2.ZERO, current_radius * 0.78, Color(FLAME, 0.55 * fade))
	# 翻滚的焰瓣：从中心向外炸开，颜色随热度由白黄转为暗红。
	for lobe in _lobes:
		var angle: float = float(lobe["angle"]) + float(lobe["spin"]) * t
		var reach: float = current_radius * float(lobe["reach"]) * (0.5 + growth * 0.9) * (1.0 + t * 0.25)
		var side := Vector2.from_angle(angle)
		var bulge := current_radius * 0.42 * (1.0 - t * 0.5)
		var color := Color(EMBER if heat > 0.6 else FLAME, 0.62 * fade)
		draw_colored_polygon(PackedVector2Array([
			side * reach + side.orthogonal() * bulge,
			side * reach * 0.35,
			side * reach - side.orthogonal() * bulge,
		]), color)
	# 上扬焰舌：沿圆周点燃的地面火舌，越高越细。
	for tongue in _tongues:
		var angle: float = float(tongue["angle"])
		var wobble: float = sin(elapsed * 15.0 * float(tongue["wobble"]) + angle * 3.0)
		var base := Vector2.from_angle(angle) * current_radius * 0.9
		var height: float = current_radius * 0.42 * float(tongue["height"]) * growth
		var tip := base + Vector2(wobble * height * 0.35, -height)
		var width := current_radius * 0.13 * (1.0 - t * 0.4)
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-width, 0.0),
			tip,
			base + Vector2(width, 0.0),
		]), Color(FLAME if heat < 0.7 else EMBER, 0.55 * fade))
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-width * 0.4, 0.0),
			base.lerp(tip, 0.72),
			base + Vector2(width * 0.4, 0.0),
		]), Color(HOT_CORE, 0.65 * fade * heat))

	# 中心：白热核心迅速消退。
	if heat > 0.0:
		draw_circle(Vector2.ZERO, current_radius * 0.46 * (0.5 + heat * 0.7), Color(FLAME, 0.85 * heat))
		draw_circle(Vector2.ZERO, current_radius * 0.3 * (0.4 + heat * 0.8), Color(HOT_CORE, heat))

	# 火星：向外飞并上扬。
	for ember in _embers:
		var travel: float = t * float(ember["speed"])
		var pos := Vector2.from_angle(float(ember["angle"])) * current_radius * 1.15 * travel
		pos.y -= current_radius * 0.45 * float(ember["rise"]) * t * t
		var alpha := (1.0 - t) * 0.9
		draw_circle(pos, float(ember["size"]) * (1.0 - t * 0.4), Color(EMBER if t < 0.5 else DEEP, alpha))
	# 尾声的烟。
	if t > 0.55:
		var smoke_alpha := smoothstep(0.55, 1.0, t) * 0.3
		draw_circle(Vector2(0.0, -current_radius * 0.15), current_radius * 0.85, Color(SMOKE, smoke_alpha))

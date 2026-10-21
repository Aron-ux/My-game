extends Node2D

## 火球术留下的燃烧地面：焦黑的地表裂缝里透出火光，上面窜起高低不一的火舌，
## 边缘不断抛出火星与烟。持续期间一直燃烧，最后 0.6 秒整体淡出。

const CRACK_COUNT := 9
const TONGUE_COUNT := 16
const EMBER_COUNT := 18
const FADE_OUT_TIME := 0.6
const VISUAL_UPDATE_INTERVAL := 1.0 / 30.0

const HOT_CORE := Color(1.0, 0.95, 0.74, 1.0)
const EMBER := Color(1.0, 0.72, 0.26, 1.0)
const FLAME := Color(1.0, 0.43, 0.10, 1.0)
const DEEP := Color(0.72, 0.13, 0.03, 1.0)
const CHAR := Color(0.10, 0.06, 0.05, 1.0)
const SMOKE := Color(0.16, 0.13, 0.12, 1.0)

var radius: float = 200.0
var remaining: float = -1.0

var _time := 0.0
var _seed := 0.0
var _cracks: Array[Dictionary] = []
var _tongues: Array[Dictionary] = []
var _embers: Array[Dictionary] = []
var _visual_elapsed := VISUAL_UPDATE_INTERVAL


func _ready() -> void:
	z_index = 15
	add_to_group("temporary_effects")
	_seed = randf() * TAU
	for index in CRACK_COUNT:
		var angle := float(index) / float(CRACK_COUNT) * TAU + randf_range(-0.22, 0.22)
		var segments: Array[Vector2] = []
		var start := Vector2.from_angle(angle) * radius * randf_range(0.12, 0.3)
		var direction := Vector2.from_angle(angle)
		for step in 4:
			start += direction * radius * randf_range(0.14, 0.2) + direction.orthogonal() * randf_range(-radius, radius) * 0.05
			segments.append(start)
		_cracks.append({"segments": segments, "width": randf_range(1.6, 3.4)})
	for index in TONGUE_COUNT:
		var angle := float(index) / float(TONGUE_COUNT) * TAU + randf_range(-0.16, 0.16)
		var distance := radius * sqrt(randf_range(0.02, 0.72))
		_tongues.append({
			"pos": Vector2.from_angle(angle) * distance,
			"height": randf_range(0.16, 0.42),
			"width": randf_range(0.035, 0.07),
			"rate": randf_range(9.0, 16.0),
			"phase": randf() * TAU,
		})
	for index in EMBER_COUNT:
		_embers.append({
			"pos": Vector2(randf_range(-radius, radius), randf_range(-radius, radius)).limit_length(radius * 0.9),
			"rise": randf_range(0.4, 1.0),
			"rate": randf_range(0.5, 1.4),
			"offset": randf() * TAU,
		})


## 由技能传入剩余持续时间，用于结尾淡出。
func set_remaining(value: float) -> void:
	remaining = value


func _process(delta: float) -> void:
	_time += delta
	_visual_elapsed += delta
	if _visual_elapsed >= VISUAL_UPDATE_INTERVAL:
		_visual_elapsed = fmod(_visual_elapsed, VISUAL_UPDATE_INTERVAL)
		queue_redraw()


func _fade_alpha() -> float:
	if remaining < 0.0:
		return 1.0
	return clampf(remaining / FADE_OUT_TIME, 0.0, 1.0)


func _draw() -> void:
	var alpha := _fade_alpha()
	if alpha <= 0.0:
		return
	var flicker := 0.82 + 0.18 * sin(_time * 11.0 + _seed) + 0.06 * sin(_time * 27.0 + _seed * 2.0)
	var pulse := 0.5 + 0.5 * sin(_time * 5.0 + _seed)

	# 焦黑地面：不规则边缘的暗斑，靠近中心更黑。
	var jitter := PackedVector2Array()
	var steps := 36
	for index in steps:
		var angle := float(index) / float(steps) * TAU
		var wobble := 1.0 + 0.07 * sin(_time * 2.5 + angle * 3.0 + _seed) + 0.04 * sin(angle * 7.0 + _seed)
		jitter.append(Vector2.from_angle(angle) * radius * wobble)
	draw_colored_polygon(jitter, Color(CHAR, 0.34 * alpha))
	draw_circle(Vector2.ZERO, radius * 0.72, Color(CHAR, 0.28 * alpha))
	# 余烬底色：从中心向外变暗的暖光。
	draw_circle(Vector2.ZERO, radius * 0.92, Color(DEEP, 0.16 * flicker * alpha))
	draw_circle(Vector2.ZERO, radius * 0.6, Color(FLAME, 0.12 * flicker * alpha))

	# 地裂：裂缝里透出橙黄的光，光随呼吸闪动。
	for crack in _cracks:
		var segments: Array = crack["segments"]
		if segments.size() < 2:
			continue
		var glow_alpha := (0.45 + 0.3 * pulse) * alpha
		for index in range(segments.size() - 1):
			var a: Vector2 = segments[index]
			var b: Vector2 = segments[index + 1]
			draw_line(a, b, Color(DEEP, glow_alpha * 0.8), float(crack["width"]) * 2.4, true)
			draw_line(a, b, Color(FLAME, glow_alpha), float(crack["width"]) * 1.2, true)
			draw_line(a, b, Color(EMBER, glow_alpha * 0.9), maxf(1.0, float(crack["width"]) * 0.45), true)

	# 火舌：底部宽、顶部收尖，左右摆动。
	for tongue in _tongues:
		var base_pos: Vector2 = tongue["pos"]
		var height: float = radius * float(tongue["height"]) * (0.85 + 0.3 * pulse)
		var width: float = radius * float(tongue["width"])
		var sway := sin(_time * float(tongue["rate"]) + float(tongue["phase"])) * width * 1.1
		var tip := base_pos + Vector2(sway, -height)
		draw_colored_polygon(PackedVector2Array([
			base_pos + Vector2(-width, 0.0),
			base_pos + Vector2(-width * 0.55 + sway * 0.4, -height * 0.55),
			tip,
			base_pos + Vector2(width * 0.55 + sway * 0.4, -height * 0.55),
			base_pos + Vector2(width, 0.0),
		]), Color(FLAME, 0.42 * alpha))
		draw_colored_polygon(PackedVector2Array([
			base_pos + Vector2(-width * 0.45, 0.0),
			tip.lerp(base_pos, 0.35),
			base_pos + Vector2(width * 0.45, 0.0),
		]), Color(EMBER, 0.55 * alpha))
		draw_colored_polygon(PackedVector2Array([
			base_pos + Vector2(-width * 0.2, 0.0),
			tip.lerp(base_pos, 0.6),
			base_pos + Vector2(width * 0.2, 0.0),
		]), Color(HOT_CORE, 0.5 * alpha))

	# 火星：在地面上反复上飘、熄灭、再燃起。
	for ember in _embers:
		var cycle := fposmod(_time * float(ember["rate"]) + float(ember["offset"]), 1.0)
		var pos: Vector2 = ember["pos"] + Vector2(sin(cycle * 6.0 + float(ember["offset"])) * 5.0, -cycle * radius * 0.22 * float(ember["rise"]))
		var color := EMBER if cycle < 0.5 else DEEP
		draw_circle(pos, 1.6 + (1.0 - cycle) * 1.4, Color(color, (1.0 - cycle) * 0.85 * alpha))

	# 边缘的烟：缓慢外扩的暗灰圆。
	for index in 6:
		var angle := float(index) / 6.0 * TAU + _seed
		var drift := fposmod(_time * 0.18 + float(index) / 6.0, 1.0)
		var smoke_pos := Vector2.from_angle(angle) * radius * (0.55 + drift * 0.5)
		smoke_pos.y -= drift * radius * 0.12
		draw_circle(smoke_pos, radius * (0.1 + drift * 0.1), Color(SMOKE, (1.0 - drift) * 0.16 * alpha))

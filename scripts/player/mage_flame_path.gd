extends Node2D

## 火焰之径：法师跑过时留下的燃烧足迹。
## 焦黑的地面带状痕迹上，沿路窜起高低不一、彼此错相的火舌，并不断抛出火星；
## 时间越久的段落烧得越低、越暗，最旧的尾端只剩余烬。
## 判定仍按 PATH_WIDTH 与 points 计算，本脚本只负责表现。

const PLAYER_MAGE_FLAME_PATH_FLOW := preload("res://scripts/player/player_mage_flame_path_flow.gd")

const PATH_WIDTH := 54.0
const SAMPLE_DISTANCE := 10.0
const DAMAGE_INTERVAL := 0.20
const TONGUE_SPACING := 13.0
const TONGUE_COUNT := 2
const EMBER_SPACING := 26.0
const VISUAL_UPDATE_INTERVAL := 1.0 / 30.0
const MAX_DETAIL_SEGMENTS := 140
const MAX_EMBER_SEGMENTS := 90

const HOT_CORE := Color(1.0, 0.96, 0.76, 1.0)
const EMBER := Color(1.0, 0.78, 0.30, 1.0)
const FLAME := Color(1.0, 0.46, 0.11, 1.0)
const DEEP := Color(0.74, 0.14, 0.04, 1.0)
const CHAR := Color(0.09, 0.06, 0.05, 1.0)

var owner_node: Node
var damage_per_second: float = 0.0
var points: Array[Vector2] = []
var damage_elapsed: float = 0.0
var flicker_elapsed: float = 0.0
var age: float = 0.0
var visual_elapsed: float = VISUAL_UPDATE_INTERVAL


func configure(owner: Node, damage: float) -> void:
	owner_node = owner
	damage_per_second = damage
	z_index = 11
	add_to_group("temporary_effects")
	set_process(true)


func record_position(position: Vector2) -> void:
	if points.is_empty() or points.back().distance_to(position) >= SAMPLE_DISTANCE:
		points.append(position)


func _process(delta: float) -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		queue_free()
		return
	flicker_elapsed += delta
	age += delta
	damage_elapsed += delta
	if damage_elapsed >= DAMAGE_INTERVAL and points.size() >= 2:
		damage_elapsed = 0.0
		PLAYER_MAGE_FLAME_PATH_FLOW.apply_damage_tick(owner_node, points, PATH_WIDTH, damage_per_second, DAMAGE_INTERVAL)
	visual_elapsed += delta
	if visual_elapsed >= VISUAL_UPDATE_INTERVAL:
		visual_elapsed = fmod(visual_elapsed, VISUAL_UPDATE_INTERVAL)
		queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	var path := PackedVector2Array()
	for point in points:
		path.append(to_local(point))
	var head := path[path.size() - 1]
	var tail := path[0]
	var fade_end: float = clampf(1.0 - age / 15.0, 0.0, 1.0) * 0.5 + 0.5

	# 焦黑地面：沿路线铺一条不规则的暗色带。
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for index in path.size():
		var prev_index := maxi(0, index - 1)
		var next_index := mini(path.size() - 1, index + 1)
		var tangent: Vector2 = (path[next_index] - path[prev_index]).normalized()
		if tangent.length_squared() <= 0.001:
			tangent = Vector2.RIGHT
		var normal: Vector2 = tangent.orthogonal()
		var wobble: float = 1.0 + 0.12 * sin(flicker_elapsed * 3.0 + float(index) * 0.7)
		var half: float = PATH_WIDTH * 0.5 * wobble
		left.append(path[index] + normal * half)
		right.append(path[index] - normal * half)
	var ground := PackedVector2Array()
	ground.append_array(left)
	for index in range(right.size() - 1, -1, -1):
		ground.append(right[index])
	draw_colored_polygon(ground, Color(CHAR, 0.26 * fade_end))
	# 焦黑带中心的暗红余烬底光（越旧越弱）。
	var glow := PackedVector2Array()
	for index in path.size():
		glow.append(path[index])
	draw_polyline(glow, Color(DEEP, 0.30 * fade_end), PATH_WIDTH * 0.66, true)
	draw_polyline(glow, Color(FLAME, 0.14 * fade_end), PATH_WIDTH * 0.44, true)

	# 火舌：沿路径每隔一段长出一簇 2～3 团高低不同的火焰，位置随时间而波动。
	var tongue_index := 0
	var tongue_step: int = maxi(1, ceili(float(path.size() - 1) / float(MAX_DETAIL_SEGMENTS)))
	for index in range(1, path.size(), tongue_step):
		var segment := path[index] - path[index - 1]
		var length: float = segment.length()
		if length <= 0.0001:
			continue
		var normal: Vector2 = segment.normalized().orthogonal()
		var along := 0.0
		while along < length:
			var base := path[index - 1] + segment * (along / length)
			# 越靠近尾部（越旧）火焰越矮。
			var recency: float = clampf(float(index) / float(maxi(1, path.size() - 1)), 0.0, 1.0)
			for sub in TONGUE_COUNT:
				var seed_value: float = float(tongue_index * TONGUE_COUNT + sub)
				var offset: Vector2 = normal * (sin(seed_value * 2.7) * PATH_WIDTH * 0.28)
				var height: float = PATH_WIDTH * (0.30 + 0.26 * absf(sin(seed_value * 1.9))) * (0.35 + recency * 0.75)
				var width: float = PATH_WIDTH * (0.14 + 0.06 * absf(cos(seed_value * 1.3)))
				var sway: float = sin(flicker_elapsed * (9.0 + sub * 2.3) + seed_value * 1.7) * width * 1.6
				var base_pos: Vector2 = base + offset
				var tip := base_pos + Vector2(sway, -height)
				var layer_alpha: float = (0.20 + recency * 0.30) * fade_end
				# 柔软的焰层：底部圆润、顶端收成弯钩，避免锯齿感。
				draw_colored_polygon(PackedVector2Array([
					base_pos + Vector2(-width, 0.0),
					base_pos + Vector2(-width * 0.85 + sway * 0.3, -height * 0.42),
					base_pos + Vector2(-width * 0.3 + sway * 0.7, -height * 0.86),
					tip,
					base_pos + Vector2(width * 0.35 + sway * 0.6, -height * 0.8),
					base_pos + Vector2(width * 0.9 + sway * 0.3, -height * 0.4),
					base_pos + Vector2(width, 0.0),
				]), Color(FLAME, layer_alpha))
				draw_colored_polygon(PackedVector2Array([
					base_pos + Vector2(-width * 0.55, 0.0),
					base_pos + Vector2(-width * 0.25 + sway * 0.4, -height * 0.5),
					base_pos.lerp(tip, 0.8),
					base_pos + Vector2(width * 0.3 + sway * 0.4, -height * 0.45),
					base_pos + Vector2(width * 0.55, 0.0),
				]), Color(EMBER, layer_alpha * 1.15))
				if recency > 0.55:
					draw_colored_polygon(PackedVector2Array([
						base_pos + Vector2(-width * 0.24, 0.0),
						base_pos.lerp(tip, 0.7),
						base_pos + Vector2(width * 0.24, 0.0),
					]), Color(HOT_CORE, layer_alpha * 0.9))
			tongue_index += 1
			along += TONGUE_SPACING * float(tongue_step)

	# 火星：沿路径上升的亮点。
	var ember_index := 0
	var ember_step: int = maxi(3, ceili(float(path.size()) / float(MAX_EMBER_SEGMENTS)))
	for index in range(0, path.size(), ember_step):
		var seed_value: float = float(ember_index)
		var cycle: float = fposmod(flicker_elapsed * (0.7 + 0.25 * abs(sin(seed_value))) + seed_value * 0.37, 1.0)
		var base_pos: Vector2 = path[index] + Vector2(sin(seed_value * 2.1), 0.0) * PATH_WIDTH * 0.3
		var rise: Vector2 = Vector2(sin(cycle * 5.0 + seed_value) * 6.0, -cycle * PATH_WIDTH * 0.9)
		var recency: float = clampf(float(index) / float(maxi(1, path.size() - 1)), 0.0, 1.0)
		draw_circle(base_pos + rise, 1.4 + (1.0 - cycle) * 1.6, Color(EMBER if cycle < 0.5 else DEEP, (1.0 - cycle) * 0.8 * recency * fade_end))
		ember_index += 1

	# 头部（脚下最新位置）：最旺的焰心与地面爆点。
	var head_pulse := 0.5 + 0.5 * sin(flicker_elapsed * 16.0)
	draw_circle(head, PATH_WIDTH * 0.5 * (1.0 + head_pulse * 0.12), Color(DEEP, 0.22))
	draw_circle(head, PATH_WIDTH * 0.34 * (1.0 + head_pulse * 0.18), Color(FLAME, 0.45))
	draw_circle(head, PATH_WIDTH * 0.17 * (1.0 + head_pulse * 0.2), Color(HOT_CORE, 0.8))
	# 尾部：只剩暗红余烬与一缕烟。
	draw_circle(tail, PATH_WIDTH * 0.34, Color(DEEP, 0.14))
	for index in 3:
		var drift: float = fposmod(flicker_elapsed * 0.4 + float(index) / 3.0, 1.0)
		draw_circle(tail + Vector2(sin(float(index) * 2.0) * 8.0, -drift * 34.0), 6.0 + drift * 5.0, Color(0.14, 0.12, 0.11, (1.0 - drift) * 0.18))

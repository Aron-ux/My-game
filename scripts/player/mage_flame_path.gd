extends Node2D

const PLAYER_MAGE_FLAME_PATH_FLOW := preload("res://scripts/player/player_mage_flame_path_flow.gd")

var owner_node: Node
var damage_per_second: float = 0.0
var points: Array[Vector2] = []
var damage_elapsed: float = 0.0
var flicker_elapsed: float = 0.0
const PATH_WIDTH := 54.0
const SAMPLE_DISTANCE := 10.0
const DAMAGE_INTERVAL := 0.20

func configure(owner: Node, damage: float) -> void:
	owner_node = owner
	damage_per_second = damage
	z_index = 11
	add_to_group("temporary_effects")
	set_process(true)

func record_position(position: Vector2) -> void:
	if points.is_empty() or points.back().distance_to(position) >= SAMPLE_DISTANCE:
		points.append(position)
		queue_redraw()

func _process(delta: float) -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		queue_free()
		return
	flicker_elapsed += delta
	damage_elapsed += delta
	if damage_elapsed >= DAMAGE_INTERVAL and points.size() >= 2:
		damage_elapsed = 0.0
		PLAYER_MAGE_FLAME_PATH_FLOW.apply_damage_tick(owner_node, points, PATH_WIDTH, damage_per_second, DAMAGE_INTERVAL)
	queue_redraw()

func _draw() -> void:
	if points.size() < 2:
		return
	var path := PackedVector2Array()
	for point in points:
		path.append(to_local(point))
	var pulse := 0.5 + 0.5 * sin(flicker_elapsed * 14.0)
	# 外层：宽、暗红，构成火焰外焰
	draw_polyline(path, Color(1.0, 0.16, 0.03, 0.30), PATH_WIDTH * (1.0 + pulse * 0.05), true)
	# 中层：橙红
	draw_polyline(path, Color(1.0, 0.42, 0.08, 0.45), PATH_WIDTH * 0.62 * (1.0 + pulse * 0.09), true)
	# 内层：亮黄，构成内焰
	draw_polyline(path, Color(1.0, 0.72, 0.24, 0.60), PATH_WIDTH * 0.30 * (1.0 + pulse * 0.15), true)
	# 头部（最新点）：高亮焰心
	var head := path[path.size() - 1]
	draw_circle(head, PATH_WIDTH * 0.44 * (1.0 + pulse * 0.2), Color(1.0, 0.88, 0.42, 0.7))
	draw_circle(head, PATH_WIDTH * 0.22 * (1.0 + pulse * 0.24), Color(1.0, 0.97, 0.68, 0.95))
	# 尾部（最旧点）：渐隐余烬
	var tail := path[0]
	draw_circle(tail, PATH_WIDTH * 0.42, Color(1.0, 0.22, 0.05, 0.16))

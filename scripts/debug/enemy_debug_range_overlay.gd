extends Node2D

const ENEMY_BODY_SEPARATION := preload("res://scripts/enemies/enemy_body_separation.gd")
const ENEMY_GLUTTON_BEHAVIOR := preload("res://scripts/enemies/enemy_glutton_behavior.gd")

const BODY_LINE_WIDTH := 2.0
const TREE_RANGE_LINE_WIDTH := 4.0
const ELLIPSE_SEGMENTS := 48

const KIND_COLORS := {
	"normal": Color(0.2, 1.0, 0.3, 0.2),
	"elite": Color(1.0, 0.82, 0.18, 0.28),
	"small_boss": Color(1.0, 0.18, 0.86, 0.28),
	"boss": Color(1.0, 1.0, 1.0, 0.28)
}
const TREE_SQUASH_COLOR := Color(0.1, 0.48, 1.0, 0.88)
const TREE_ATTACK_COLOR := Color(1.0, 0.12, 0.08, 0.9)
const TREE_WOOD_SPIKE_COLOR := Color(1.0, 0.72, 0.08, 0.95)

var battle_root: Node
var debug_enabled: bool = false


func configure(root_node: Node) -> void:
	battle_root = root_node
	z_as_relative = false
	z_index = 4090
	set_debug_enabled(false)


func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled
	visible = enabled
	set_process(enabled)
	if not enabled:
		queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not debug_enabled:
		return
	if battle_root == null or not is_instance_valid(battle_root):
		return
	for enemy in _get_runtime_enemies():
		if enemy == null or not is_instance_valid(enemy) or enemy is not Node2D:
			continue
		_draw_enemy_body_collision(enemy as Node2D)
		if _is_tree_glutton(enemy):
			_draw_tree_ranges(enemy as Node2D)


func _draw_enemy_body_collision(enemy: Node2D) -> void:
	var radius: float = ENEMY_BODY_SEPARATION.get_body_collision_radius(enemy)
	if radius <= 0.0:
		return
	var kind: String = str(enemy.get("enemy_kind"))
	draw_circle(to_local(enemy.global_position), radius, _get_kind_color(kind))
	draw_arc(to_local(enemy.global_position), radius, 0.0, TAU, ELLIPSE_SEGMENTS, Color.WHITE, 1.0, true)


func _draw_tree_ranges(enemy: Node2D) -> void:
	_draw_shape(ENEMY_GLUTTON_BEHAVIOR.get_debug_aura_shape(enemy), TREE_SQUASH_COLOR, TREE_RANGE_LINE_WIDTH)
	_draw_shape(ENEMY_GLUTTON_BEHAVIOR.get_player_touch_shape(enemy), TREE_ATTACK_COLOR, TREE_RANGE_LINE_WIDTH)
	for shape in ENEMY_GLUTTON_BEHAVIOR.get_debug_wood_spike_hitboxes(enemy):
		if shape is Dictionary:
			_draw_shape(shape, TREE_WOOD_SPIKE_COLOR, TREE_RANGE_LINE_WIDTH)


func _draw_shape(shape: Dictionary, color: Color, width: float) -> void:
	if shape.is_empty():
		return
	var center: Vector2 = shape.get("center", Vector2.ZERO)
	var horizontal_radius: float = max(0.0, float(shape.get("horizontal_radius", 0.0)))
	var vertical_radius: float = max(0.0, float(shape.get("vertical_radius", 0.0)))
	if horizontal_radius <= 0.0 or vertical_radius <= 0.0:
		return
	_draw_ellipse_outline(center, horizontal_radius, vertical_radius, color, width)


func _draw_ellipse_outline(center: Vector2, horizontal_radius: float, vertical_radius: float, color: Color, width: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(ELLIPSE_SEGMENTS + 1):
		var angle: float = TAU * float(index) / float(ELLIPSE_SEGMENTS)
		points.append(to_local(center + Vector2(cos(angle) * horizontal_radius, sin(angle) * vertical_radius)))
	draw_polyline(points, color, width, true)


func _get_runtime_enemies() -> Array:
	if battle_root != null and battle_root.has_method("get_runtime_enemies"):
		return battle_root.get_runtime_enemies()
	if battle_root != null and battle_root.get_tree() != null:
		return battle_root.get_tree().get_nodes_in_group("enemies")
	return []


func _get_kind_color(kind: String) -> Color:
	return KIND_COLORS.get(kind, Color(0.4, 0.9, 1.0, 0.72))


func _is_tree_glutton(enemy: Variant) -> bool:
	if enemy == null:
		return false
	return str(enemy.get("archetype_id")) == "smallboss_glutton" or str(enemy.get("behavior_id")) == "glutton"

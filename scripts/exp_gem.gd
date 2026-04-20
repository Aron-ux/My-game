extends Node2D

const TIER_VALUES := {
	1: 4,
	2: 9,
	3: 18,
	4: 40
}

const TIER_COLORS := {
	1: Color(0.37, 0.98, 0.57, 1.0),
	2: Color(0.34, 0.74, 1.0, 1.0),
	3: Color(1.0, 0.88, 0.34, 1.0),
	4: Color(1.0, 0.56, 0.22, 1.0)
}

const TIER_SCALES := {
	1: 1.0,
	2: 1.08,
	3: 1.18,
	4: 1.32
}

@export var value: int = 10
@export var tier: int = 1

var polygon_node: Polygon2D

func _ready() -> void:
	add_to_group("exp_gems")
	polygon_node = get_node_or_null("Polygon2D") as Polygon2D
	if value <= 0:
		value = int(TIER_VALUES.get(tier, 4))
	_apply_appearance()

func configure(new_tier: int, custom_value: int = -1) -> void:
	tier = clamp(new_tier, 1, 4)
	value = custom_value if custom_value > 0 else int(TIER_VALUES.get(tier, 4))
	_apply_appearance()

func collect() -> int:
	queue_free()
	return value

func _apply_appearance() -> void:
	if polygon_node == null:
		polygon_node = get_node_or_null("Polygon2D") as Polygon2D
	if polygon_node != null:
		polygon_node.color = TIER_COLORS.get(tier, TIER_COLORS[1])
	scale = Vector2.ONE * float(TIER_SCALES.get(tier, 1.0))

func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"value": value,
		"tier": tier
	}

func apply_save_data(data: Dictionary) -> void:
	var position_data = data.get("position", [0.0, 0.0])
	if position_data.size() >= 2:
		global_position = Vector2(float(position_data[0]), float(position_data[1]))

	value = int(data.get("value", value))
	tier = clamp(int(data.get("tier", tier)), 1, 4)
	_apply_appearance()

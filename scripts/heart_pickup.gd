extends Node2D

const HEAL_AMOUNT := 50.0

@export var heal_amount: float = HEAL_AMOUNT

var polygon_node: Polygon2D

func _ready() -> void:
	add_to_group("heart_pickups")
	polygon_node = get_node_or_null("Polygon2D") as Polygon2D
	_apply_appearance()

func collect() -> float:
	queue_free()
	return heal_amount

func _apply_appearance() -> void:
	if polygon_node == null:
		polygon_node = get_node_or_null("Polygon2D") as Polygon2D
	if polygon_node != null:
		polygon_node.color = Color(1.0, 0.36, 0.48, 1.0)

func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"heal_amount": heal_amount
	}

func apply_save_data(data: Dictionary) -> void:
	var position_data = data.get("position", [0.0, 0.0])
	if position_data.size() >= 2:
		global_position = Vector2(float(position_data[0]), float(position_data[1]))
	heal_amount = float(data.get("heal_amount", heal_amount))
	_apply_appearance()

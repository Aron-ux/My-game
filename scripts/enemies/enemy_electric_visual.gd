extends Node2D

var remaining := 0.28
var elapsed := 0.0

static func flash(enemy: Node2D) -> void:
	var effect := enemy.get_node_or_null("ElectricFlash")
	if effect != null:
		effect.remaining = 0.28
		return
	effect = load("res://scripts/enemies/enemy_electric_visual.gd").new()
	effect.name = "ElectricFlash"
	effect.z_index = 20
	enemy.add_child(effect)

func _process(delta: float) -> void:
	remaining -= delta
	elapsed += delta
	if remaining <= 0.0:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	for side in [-1.0, 1.0]:
		var points := PackedVector2Array()
		for index in range(6):
			points.append(Vector2(side * (9.0 + sin(elapsed * 95.0 + index * 2.2) * 5.0), -28.0 + index * 7.0))
		draw_polyline(points, Color(0.7, 0.9, 1.0, minf(1.0, remaining * 6.0)), 1.6, true)

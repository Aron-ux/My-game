extends Node2D

var center := Vector2.ZERO
var radius := 0.0

func _draw() -> void:
	if radius > 0.0:
		draw_arc(center, radius, 0.0, TAU, 128, Color(0.2, 1.0, 0.3, 0.9), 2.0)

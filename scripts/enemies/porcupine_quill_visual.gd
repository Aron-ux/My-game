extends Node2D

const SPEED := 900.0
const RADIUS := 150.0
const START_RADIUS := 24.0
const FLIGHT_TIME := (RADIUS - START_RADIUS) / SPEED
const FADE_TIME := 0.10
const COUNT := 24
var elapsed := 0.0
var enraged := false
var angle_offset := 0.0


func _ready() -> void:
	z_index = 14
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= FLIGHT_TIME + FADE_TIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var radius := minf(RADIUS, START_RADIUS + elapsed * SPEED)
	var alpha := 1.0 - clampf((elapsed - FLIGHT_TIME) / FADE_TIME, 0, 1)
	var color := Color(1, 0.48, 0.32, alpha) if enraged else Color(0.85, 0.73, 1, alpha)
	for index in COUNT:
		var axis := Vector2.from_angle(angle_offset + float(index) * TAU / COUNT)
		var tip := axis * radius
		var base := tip - axis * 23
		draw_line(tip - axis * 43, base, Color(color, alpha * 0.28), 3, true)
		draw_colored_polygon(PackedVector2Array([tip, base + axis.orthogonal() * 3.5, base - axis.orthogonal() * 3.5]), color)
		draw_line(base, tip - axis * 3, Color(1, 0.94, 1, alpha), 1, true)

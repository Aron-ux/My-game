extends Node2D

var owner_node: Node2D
var remaining: float = 0.0
var duration: float = 1.0

func configure(target: Node2D, active_duration: float) -> void:
	owner_node = target
	duration = maxf(0.01, active_duration)
	z_index = 30
	set_process(true)
	queue_redraw()

func set_remaining(value: float) -> void:
	remaining = clampf(value, 0.0, duration)
	queue_redraw()

func _process(_delta: float) -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		queue_free()
		return
	global_position = owner_node.global_position + Vector2(0.0, -58.0)
	if remaining <= 0.0:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var ratio := clampf(remaining / duration, 0.0, 1.0)
	var width := 54.0
	var height := 7.0
	var rect := Rect2(-width * 0.5, -height * 0.5, width, height)
	draw_rect(rect.grow(2.0), Color(0.08, 0.03, 0.01, 0.85), true)
	draw_rect(rect, Color(0.25, 0.08, 0.02, 0.92), true)
	draw_rect(Rect2(rect.position, Vector2(width * ratio, height)), Color(1.0, 0.45, 0.08, 0.95), true)
	draw_line(Vector2(-width * 0.5, height * 0.5 + 2.0), Vector2(width * 0.5, height * 0.5 + 2.0), Color(1.0, 0.78, 0.22, 0.8), 1.0)

extends Node2D

# Reuse the current skeleton animation, with a robe, staff and spell effects.
const SKULL_SCENE := preload("res://assets/enemies/skullshot/skull-soilder.tscn")
var skull: Node2D
var ice_active := false
var invulnerable := false
var drain_target: Vector2
var draining := false
var time := 0.0


func _ready() -> void:
	skull = SKULL_SCENE.instantiate()
	skull.position = Vector2(0, -12)
	skull.scale = Vector2(0.72, 0.72)
	add_child(skull)


func set_moving(moving: bool, direction := Vector2.ZERO) -> void:
	if skull != null:
		skull.set_moving(moving, direction)


func play_hit() -> void:
	if skull != null:
		skull.play_hit()


func _process(delta: float) -> void:
	time += delta
	if skull != null:
		skull.modulate = Color(0.45, 0.7, 1.0) if ice_active else Color.WHITE
	queue_redraw()


func _draw() -> void:
	var outline := Color(0.08, 0.06, 0.16)
	var robe := Color(0.12, 0.32, 0.65) if ice_active else Color(0.25, 0.16, 0.39)
	draw_colored_polygon(PackedVector2Array([Vector2(-17, 0), Vector2(17, 0), Vector2(24, 31), Vector2(9, 26), Vector2(0, 33), Vector2(-23, 29)]), outline)
	draw_colored_polygon(PackedVector2Array([Vector2(-13, 1), Vector2(13, 1), Vector2(17, 26), Vector2(0, 29), Vector2(-17, 25)]), robe)
	draw_line(Vector2(0, 5), Vector2(0, 24), Color(0.72, 0.5, 0.85), 2.0)
	draw_line(Vector2(26, 30), Vector2(26, -33), Color(0.15, 0.09, 0.23), 7.0)
	draw_line(Vector2(26, 29), Vector2(26, -32), Color(0.61, 0.4, 0.71), 3.0)
	draw_circle(Vector2(26, -35), 9, Color(0.35, 0.85, 0.81, 0.2))
	draw_circle(Vector2(26, -35), 5, Color(0.5, 1.0, 0.9))
	if ice_active:
		draw_arc(Vector2.ZERO, 43, 0, TAU, 48, Color(0.25, 0.75, 1, 0.75), 3.0)
		for index in 6:
			var point := Vector2.from_angle(time * 0.7 + index * TAU / 6) * 41
			draw_colored_polygon(PackedVector2Array([point + Vector2(0, -7), point + Vector2(4, 0), point + Vector2(0, 7), point + Vector2(-4, 0)]), Color(0.55, 0.92, 1, 0.9))
	if invulnerable:
		draw_arc(Vector2.ZERO, 47, 0, TAU, 48, Color(0.8, 0.35, 1, 0.9), 4.0)
	if draining:
		var endpoint := to_local(drain_target)
		draw_line(Vector2(26, -35), endpoint, Color(0.15, 0.85, 0.65, 0.3), 8.0)
		draw_line(Vector2(26, -35), endpoint, Color(0.55, 1, 0.78, 0.85), 2.0)
		for index in 4:
			var progress := fposmod(time * 1.5 + float(index) / 4, 1.0)
			draw_circle(endpoint.lerp(Vector2(26, -35), progress), 3, Color(0.75, 1, 0.85))

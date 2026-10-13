extends Node2D

const SOURCES_META := "skull_mage_domains"
const RADIUS := 300.0
const DURATION := 10.0
var remaining := DURATION
var player: Node2D
var time := 0.0


func _ready() -> void:
	z_index = 10
	add_to_group("skull_mage_domains")
	if is_instance_valid(player):
		var sources: Dictionary = player.get_meta(SOURCES_META, {})
		sources[get_instance_id()] = weakref(self)
		player.set_meta(SOURCES_META, sources)


func _physics_process(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	time += delta
	if remaining <= 0:
		queue_free()
	queue_redraw()


func _exit_tree() -> void:
	if is_instance_valid(player):
		var sources: Dictionary = player.get_meta(SOURCES_META, {})
		sources.erase(get_instance_id())
		player.set_meta(SOURCES_META, sources)


func get_save_data() -> Dictionary:
	return {"position": [global_position.x, global_position.y], "remaining": remaining}


func _draw() -> void:
	var alpha := minf(1.0, remaining)
	draw_circle(Vector2.ZERO, RADIUS, Color(0.2, 0.08, 0.3, 0.18 * alpha))
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 96, Color(0.68, 0.34, 0.88, 0.7 * alpha), 3.0)
	draw_arc(Vector2.ZERO, RADIUS - 13, 0, TAU, 96, Color(0.42, 0.18, 0.65, 0.55 * alpha), 2.0)
	for index in 8:
		var angle := float(index) * TAU / 8
		var center := Vector2.from_angle(angle) * (RADIUS - 27)
		var axis := Vector2.from_angle(angle)
		draw_line(center - axis * 8, center + axis * 8, Color(0.8, 0.5, 1, 0.7 * alpha), 2.0)
		draw_line(center - axis.orthogonal() * 6, center + axis.orthogonal() * 6, Color(0.8, 0.5, 1, 0.7 * alpha), 2.0)


static func get_remaining(body: Object) -> float:
	if not body is Node2D or (body.has_method("_is_status_immune") and body._is_status_immune()):
		return 0.0
	var sources: Dictionary = body.get_meta(SOURCES_META, {})
	var result := 0.0
	for id in sources.keys():
		var field = sources[id].get_ref()
		if field == null or not is_instance_valid(field) or field.is_queued_for_deletion():
			sources.erase(id)
			continue
		if body.global_position.distance_squared_to(field.global_position) <= RADIUS * RADIUS:
			result = maxf(result, field.remaining)
	return result


static func get_slow_multiplier(body: Object) -> float:
	return 0.8 if get_remaining(body) > 0 else 1.0

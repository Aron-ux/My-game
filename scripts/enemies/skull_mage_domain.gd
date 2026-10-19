extends Node2D

const SOURCES_META := "skull_mage_domains"
const RADIUS := 300.0
const DURATION := 10.0
# Generated at x2 with a 200 art-px radius: x0.75 maps it onto RADIUS.
const DOMAIN_TEXTURE := preload("res://assets/enemies/skullmage/unclean_domain.png")
const DOMAIN_SCALE := RADIUS / 200.0 / 2.0
var remaining := DURATION
var player: Node2D
var time := 0.0


func _ready() -> void:
	z_index = 10
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	# Fade in over the first 0.4 s, out over the last second, with a slow pulse.
	var alpha := minf(1.0, remaining) * minf(1.0, time / 0.4)
	var pulse := 0.85 + 0.15 * sin(time * 2.4)
	var size := DOMAIN_TEXTURE.get_size() * DOMAIN_SCALE
	draw_texture_rect(DOMAIN_TEXTURE, Rect2(-size * 0.5, size), false, Color(1, 1, 1, alpha * pulse))
	# Blocky miasma motes rising across the field.
	for index in 18:
		var hash_value := float(index) * 12.9898
		var angle := fposmod(hash_value * 1.7, TAU)
		var distance := RADIUS * sqrt(fposmod(hash_value * 0.618, 1.0)) * 0.92
		var progress := fposmod(time * 0.45 + fposmod(hash_value, 1.0), 1.0)
		var point := Vector2.from_angle(angle) * distance + Vector2(0, -progress * 36.0)
		var mote_alpha := sin(progress * PI) * 0.7 * alpha
		var color := Color(0.75, 0.45, 1.0, mote_alpha) if index % 3 else Color(0.55, 0.8, 0.35, mote_alpha)
		draw_rect(Rect2(point.snapped(Vector2(3, 3)), Vector2(3, 3)), color)


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

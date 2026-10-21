extends Polygon2D

var owner_node: Node
var wave_node: Node2D
var wave_token: int = -1
var origin: Vector2 = Vector2.ZERO
var visual_width_multiplier: float = 1.0
var min_length: float = 6.0
var post_wave_remaining: float = 8.0
var frozen_end_position: Vector2 = Vector2.ZERO
var has_frozen_end_position: bool = false


func setup(owner: Node, wave: Node2D, token: int, start_position: Vector2, trail_color: Color, width_multiplier: float, minimum_length: float) -> void:
	owner_node = owner
	wave_node = wave
	wave_token = token
	origin = start_position
	color = trail_color
	visual_width_multiplier = width_multiplier
	min_length = minimum_length
	z_as_relative = false
	z_index = 12
	global_position = origin
	add_to_group("temporary_effects")
	set_process(true)


func _process(delta: float) -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		_release()
		return
	if wave_node == null or not is_instance_valid(wave_node):
		_release()
		return
	if int(wave_node.get_meta("mage_surge_token", -1)) != wave_token:
		_release()
		return
	var released := bool(wave_node.get_meta("player_projectile_released", false))
	if released:
		post_wave_remaining -= delta
		if not has_frozen_end_position:
			frozen_end_position = wave_node.global_position
			has_frozen_end_position = true
			if bool(get_meta("mage_surge_water_path", false)):
				var axis := frozen_end_position - origin
				if axis.length() >= min_length:
					var areas: Array = owner_node.get_meta("mage_surge_water_path_areas", [])
					areas.append({
						"center": origin + axis * 0.5,
						"direction": axis.normalized(),
						"length": axis.length(),
						"width": maxf(4.0, float(wave_node.get("hit_radius")) * 2.0),
						"remaining": 8.0,
						"tick_remaining": 1.0
					})
					owner_node.set_meta("mage_surge_water_path_areas", areas)
		if post_wave_remaining <= 0.0:
			_release()
			return
	var end_position: Vector2 = frozen_end_position if released else wave_node.global_position
	var axis: Vector2 = end_position - origin
	var length: float = axis.length()
	if length < min_length:
		return
	var width: float = max(4.0, float(wave_node.get("hit_radius")) * 2.0) * visual_width_multiplier
	global_position = origin + axis * 0.5
	rotation = axis.angle()
	var half_length: float = length * 0.5
	var half_width: float = width * 0.5
	polygon = PackedVector2Array([
		Vector2(-half_length, -half_width),
		Vector2(half_length, -half_width),
		Vector2(half_length, half_width),
		Vector2(-half_length, half_width)
	])


func _release() -> void:
	if not is_inside_tree():
		return
	remove_from_group("temporary_effects")
	queue_free()

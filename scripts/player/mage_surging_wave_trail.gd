extends Polygon2D

var owner_node: Node
var wave_node: Node2D
var wave_token: int = -1
var origin: Vector2 = Vector2.ZERO
var visual_width_multiplier: float = 1.0
var min_length: float = 6.0


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


func _process(_delta: float) -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		_release()
		return
	if wave_node == null or not is_instance_valid(wave_node):
		_release()
		return
	if int(wave_node.get_meta("mage_surge_token", -1)) != wave_token or bool(wave_node.get_meta("player_projectile_released", false)):
		_release()
		return
	var end_position: Vector2 = wave_node.global_position
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
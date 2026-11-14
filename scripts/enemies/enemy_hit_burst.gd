extends Node2D

const DURATION := 0.24
const RING_DURATION := 0.17
const PARTICLE_COUNT := 9
const RING_START_RADIUS := 4.0
const RING_LINE_WIDTH := 2.2
const PARTICLE_COLORS: Array[Color] = [
	Color(1.0, 0.055, 0.09, 1.0),
	Color(0.96, 0.02, 0.035, 1.0),
	Color(1.0, 0.19, 0.13, 1.0)
]

var _progress: float = 0.0
var _ring_target_radius: float = 30.0
var _particles: Array[Dictionary] = []


func start_burst(ring_target_radius: float) -> void:
	_progress = 0.0
	_ring_target_radius = maxf(RING_START_RADIUS + 1.0, ring_target_radius)
	_particles.clear()
	for _index in range(PARTICLE_COUNT):
		var angle := randf_range(0.0, TAU)
		_particles.append({
			"direction": Vector2.from_angle(angle),
			"origin": Vector2.from_angle(angle) * randf_range(6.0, 12.0),
			"speed": randf_range(115.0, 200.0),
			"size": randf_range(3.8, 6.4),
			"color": PARTICLE_COLORS[randi_range(0, PARTICLE_COLORS.size() - 1)],
			"gravity": randf_range(4.0, 22.0)
		})
	show()
	queue_redraw()


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func get_ring_radius() -> float:
	var eased_progress := 1.0 - pow(1.0 - _get_ring_progress(), 2.0)
	return lerpf(RING_START_RADIUS, _ring_target_radius, eased_progress)


func _get_ring_progress() -> float:
	return clampf(_progress * DURATION / RING_DURATION, 0.0, 1.0)


func get_particle_count() -> int:
	return _particles.size()


func _draw() -> void:
	var fade := 1.0 - _progress
	for particle: Dictionary in _particles:
		var direction: Vector2 = particle["direction"]
		var origin: Vector2 = particle["origin"]
		var speed: float = float(particle["speed"])
		var gravity: float = float(particle["gravity"])
		var particle_position := origin + direction * speed * DURATION * _progress
		particle_position.y += gravity * _progress * _progress
		var particle_size: float = float(particle["size"]) * (1.0 - _progress * 0.2)
		var particle_color: Color = particle["color"]
		particle_color.a *= fade
		draw_circle(particle_position, particle_size * 1.55, Color(1.0, 0.035, 0.055, fade * 0.24))
		draw_circle(particle_position, particle_size, particle_color)

	var ring_progress := _get_ring_progress()
	var ring_alpha := 0.72 * (1.0 - ring_progress)
	draw_arc(
		Vector2.ZERO,
		get_ring_radius(),
		0.0,
		TAU,
		32,
		Color(1.0, 1.0, 1.0, ring_alpha),
		RING_LINE_WIDTH * (1.0 - ring_progress * 0.35),
		true
	)

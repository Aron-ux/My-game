extends Node2D

const ENEMY_BULLET_SCENE_PATH := "res://scenes/enemy_bullet.tscn"
const ENEMY_BULLET_SCENE := preload("res://scenes/enemy_bullet.tscn")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const ENEMY_GEOMETRY := preload("res://scripts/enemies/enemy_geometry.gd")
const MAX_TURN_CATCH_UP_TICKS := 8
const POOL_GROUP := "enemy_projectile_pool"
const POOL_SOFT_LIMIT := 96
const PROJECTILE_Z_INDEX := 12
const LIFETIME_FADE_DURATION := 0.6

@export var speed: float = 260.0
@export var damage: float = 8.0
@export var lifetime: float = 4.0
@export var hit_radius: float = 16.0
@export var visual_color: Color = Color(1.0, 0.45, 0.3, 1.0)
@export var motion_mode: String = "straight"
@export var sine_amplitude: float = 36.0
@export var sine_frequency: float = 1.4
@export var sine_phase: float = 0.0
@export var turn_start_delay: float = 0.45
@export var turn_interval: float = 0.18
@export var turn_angle_step: float = 0.2
@export var turn_direction_sign: float = 1.0
@export var homing_turn_rate: float = 1.1
@export var quarter_sine_distance: float = 180.0
@export var quarter_sine_side: float = 1.0
@export var return_after: float = 0.8
@export var return_speed: float = 320.0
@export var return_target_x: float = 0.0
@export var return_target_y: float = 0.0
@export var split_on_return: bool = false
@export var split_count: int = 0
@export var split_speed: float = 180.0
@export var split_damage_scale: float = 0.45
@export var split_lifetime: float = 3.2
@export var split_motion_mode: String = "quarter_sine"
@export var split_after_time: float = 0.0
@export var split_pattern: String = "radial"
@export var split_spread: float = 1.2
@export var split_visual_style: String = ""
@export var split_size_scale: float = 0.75
@export var split_hit_radius_scale: float = 0.8
@export var size_scale: float = 1.0
@export var visual_style: String = ""
@export var chain_follow_spacing: float = 18.0
@export var chain_follow_index: int = 0

var direction: Vector2 = Vector2.RIGHT
var target: Node2D
var travel_time: float = 0.0
var forward_distance: float = 0.0
var base_position: Vector2 = Vector2.ZERO
var base_direction: Vector2 = Vector2.RIGHT
var perpendicular_direction: Vector2 = Vector2.UP
var turn_delay_remaining: float = 0.0
var turn_tick_remaining: float = 0.0
var return_started: bool = false
var split_performed: bool = false
var pooled: bool = false
var batch_simulation_enabled: bool = false
var chain_head: Node2D
var chain_history: Array[Dictionary] = []
var chain_trail: Dictionary = {}
var chain_follow_distance: float = 0.0
var chain_path_distance: float = 0.0
var max_lifetime: float = 4.0

static var visual_shape_cache: Dictionary = {}

func _ready() -> void:
	if pooled:
		return
	_initialize_runtime_state()

func _exit_tree() -> void:
	_unregister_runtime_projectile()

func reset_projectile(config: Dictionary) -> void:
	pooled = false
	batch_simulation_enabled = false
	show()
	set_process(true)
	set_physics_process(true)
	global_position = config.get("position", global_position)
	direction = (config.get("direction", Vector2.RIGHT) as Vector2).normalized()
	speed = float(config.get("speed", speed))
	damage = float(config.get("damage", damage))
	lifetime = float(config.get("lifetime", lifetime))
	max_lifetime = max(lifetime, 0.001)
	hit_radius = float(config.get("hit_radius", hit_radius))
	visual_color = config.get("visual_color", visual_color)
	motion_mode = str(config.get("motion_mode", motion_mode))
	target = config.get("target", target)
	sine_amplitude = float(config.get("sine_amplitude", sine_amplitude))
	sine_frequency = float(config.get("sine_frequency", sine_frequency))
	sine_phase = float(config.get("sine_phase", sine_phase))
	turn_start_delay = float(config.get("turn_start_delay", turn_start_delay))
	turn_interval = float(config.get("turn_interval", turn_interval))
	turn_angle_step = float(config.get("turn_angle_step", turn_angle_step))
	turn_direction_sign = float(config.get("turn_direction_sign", turn_direction_sign))
	homing_turn_rate = float(config.get("homing_turn_rate", homing_turn_rate))
	quarter_sine_distance = float(config.get("quarter_sine_distance", quarter_sine_distance))
	quarter_sine_side = float(config.get("quarter_sine_side", quarter_sine_side))
	return_after = float(config.get("return_after", return_after))
	return_speed = float(config.get("return_speed", return_speed))
	return_target_x = float(config.get("return_target_x", return_target_x))
	return_target_y = float(config.get("return_target_y", return_target_y))
	split_on_return = bool(config.get("split_on_return", split_on_return))
	split_count = int(config.get("split_count", split_count))
	split_speed = float(config.get("split_speed", split_speed))
	split_damage_scale = float(config.get("split_damage_scale", split_damage_scale))
	split_lifetime = float(config.get("split_lifetime", split_lifetime))
	split_motion_mode = str(config.get("split_motion_mode", split_motion_mode))
	split_after_time = float(config.get("split_after_time", split_after_time))
	split_pattern = str(config.get("split_pattern", split_pattern))
	split_spread = float(config.get("split_spread", split_spread))
	split_visual_style = str(config.get("split_visual_style", ""))
	split_size_scale = float(config.get("split_size_scale", split_size_scale))
	split_hit_radius_scale = float(config.get("split_hit_radius_scale", split_hit_radius_scale))
	size_scale = float(config.get("size_scale", size_scale))
	visual_style = str(config.get("visual_style", ""))
	chain_head = config.get("chain_head", null) as Node2D
	chain_trail = config.get("chain_trail", {})
	chain_follow_spacing = float(config.get("chain_follow_spacing", chain_follow_spacing))
	chain_follow_index = int(config.get("chain_follow_index", chain_follow_index))
	_initialize_runtime_state()

func recycle() -> void:
	if motion_mode == "chain_head":
		_seal_chain_trail()
	if _get_runtime_pool_count() >= POOL_SOFT_LIMIT:
		queue_free()
		return
	pooled = true
	batch_simulation_enabled = false
	hide()
	set_process(false)
	set_physics_process(false)
	remove_from_group("enemy_projectiles")
	add_to_group(POOL_GROUP)
	_register_runtime_projectile(true)
	target = null
	chain_head = null
	chain_history.clear()
	chain_trail = {}

func _initialize_runtime_state() -> void:
	direction = direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	base_position = global_position
	base_direction = direction
	perpendicular_direction = base_direction.orthogonal().normalized()
	turn_delay_remaining = turn_start_delay
	turn_tick_remaining = turn_interval
	travel_time = 0.0
	forward_distance = 0.0
	return_started = false
	split_performed = false
	modulate = Color.WHITE
	chain_history.clear()
	chain_follow_distance = max(0.0, float(chain_follow_index) * chain_follow_spacing)
	chain_path_distance = -chain_follow_distance
	if motion_mode == "chain_head":
		_ensure_chain_trail()
		_record_chain_history()
	remove_from_group(POOL_GROUP)
	add_to_group("enemy_projectiles")
	_register_runtime_projectile(false)
	z_index = PROJECTILE_Z_INDEX
	_apply_visuals()

func _physics_process(delta: float) -> void:
	if batch_simulation_enabled and can_use_batch_simulation():
		return
	_run_physics_tick(delta)

func batch_physics_process(delta: float) -> void:
	_run_physics_tick(delta)

func can_use_batch_simulation() -> bool:
	return not pooled

func _run_physics_tick(delta: float) -> void:
	if pooled:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		if motion_mode == "returning_sine" and split_on_return and not split_performed:
			_spawn_split_bullets()
		if motion_mode == "chain_head":
			_seal_chain_trail()
		recycle()
		return
	_update_lifetime_fade()

	travel_time += delta

	match motion_mode:
		"sine":
			_update_sine_motion(delta)
		"turning":
			_update_turning_motion(delta)
		"homing":
			_update_homing_motion(delta)
		"chain_head":
			_update_chain_head_motion(delta)
		"chain_follow":
			if not _update_chain_follow_motion(delta):
				return
		"quarter_sine":
			_update_quarter_sine_motion(delta)
		"returning_sine":
			if _update_returning_sine_motion(delta):
				return
		_:
			_update_straight_motion(delta)

	if split_after_time > 0.0 and not split_performed and travel_time >= split_after_time:
		_spawn_split_bullets()
		recycle()
		return

	_try_hit_player()

func _update_straight_motion(delta: float) -> void:
	global_position += direction * speed * delta
	rotation = direction.angle()

func _update_sine_motion(delta: float) -> void:
	forward_distance += speed * delta
	var forward_offset := base_direction * forward_distance
	var wave_phase_value: float = travel_time * TAU * sine_frequency + sine_phase
	var lateral_offset := perpendicular_direction * sin(wave_phase_value) * sine_amplitude
	global_position = base_position + forward_offset + lateral_offset
	rotation = (base_direction + perpendicular_direction * cos(wave_phase_value) * 0.28).angle()

func _update_turning_motion(delta: float) -> void:
	if turn_delay_remaining > 0.0:
		turn_delay_remaining = max(0.0, turn_delay_remaining - delta)
	else:
		turn_tick_remaining -= delta
		var catch_up_ticks := 0
		while turn_tick_remaining <= 0.0 and catch_up_ticks < MAX_TURN_CATCH_UP_TICKS:
			turn_tick_remaining += max(0.05, turn_interval)
			direction = direction.rotated(turn_angle_step * turn_direction_sign).normalized()
			catch_up_ticks += 1
		if catch_up_ticks >= MAX_TURN_CATCH_UP_TICKS and turn_tick_remaining <= 0.0:
			turn_tick_remaining = max(0.05, turn_interval)
	global_position += direction * speed * delta
	rotation = direction.angle()

func _update_homing_motion(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var target_position: Vector2 = target.global_position
		if target.has_method("get_hurtbox_center"):
			target_position = target.get_hurtbox_center()
		var desired_direction: Vector2 = global_position.direction_to(target_position)
		if desired_direction.length_squared() > 0.001:
			var angle_delta: float = wrapf(desired_direction.angle() - direction.angle(), -PI, PI)
			var max_turn: float = max(0.0, homing_turn_rate) * delta
			direction = direction.rotated(clamp(angle_delta, -max_turn, max_turn)).normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()

func _update_chain_head_motion(delta: float) -> void:
	_update_homing_motion(delta)
	_record_chain_history()

func _update_chain_follow_motion(delta: float) -> bool:
	chain_path_distance += speed * delta
	if chain_path_distance < 0.0:
		_update_straight_motion(delta)
		return true
	var sample: Dictionary = _get_chain_trail_sample_by_distance(chain_path_distance)
	if sample.is_empty():
		if not chain_trail.is_empty() and bool(chain_trail.get("sealed", false)):
			recycle()
			return false
		_update_straight_motion(delta)
		return true
	global_position = sample.get("position", global_position)
	rotation = float(sample.get("rotation", rotation))
	direction = sample.get("direction", direction)
	return true

func _record_chain_history() -> void:
	var history: Array = _get_chain_history()
	var previous_position: Vector2 = global_position
	var total_distance: float = 0.0
	if not history.is_empty():
		var previous_sample: Dictionary = history[history.size() - 1]
		previous_position = previous_sample.get("position", global_position)
		total_distance = float(previous_sample.get("distance", 0.0)) + previous_position.distance_to(global_position)
	chain_path_distance = total_distance
	chain_trail["total_distance"] = total_distance
	history.append({
		"position": global_position,
		"rotation": rotation,
		"direction": direction,
		"distance": total_distance
	})
	var max_history: int = 320
	while history.size() > max_history and not bool(chain_trail.get("sealed", false)):
		history.pop_front()

func get_chain_sample(distance_behind: float) -> Dictionary:
	var trail_distance: float = max(0.0, float(chain_trail.get("total_distance", 0.0)) - distance_behind)
	return _sample_chain_history_at_distance(_get_chain_history(), trail_distance)

func _ensure_chain_trail() -> void:
	if chain_trail.is_empty():
		chain_trail = {
			"history": [],
			"sealed": false,
			"total_distance": 0.0
		}
	if not chain_trail.has("history") or not (chain_trail.get("history") is Array):
		chain_trail["history"] = []
	if not chain_trail.has("sealed"):
		chain_trail["sealed"] = false
	if not chain_trail.has("total_distance"):
		chain_trail["total_distance"] = 0.0

func _seal_chain_trail() -> void:
	_ensure_chain_trail()
	chain_trail["sealed"] = true

func _get_chain_history() -> Array:
	if chain_trail.is_empty():
		return chain_history
	_ensure_chain_trail()
	return chain_trail.get("history") as Array

func _get_chain_trail_sample(distance_behind: float) -> Dictionary:
	if chain_trail.is_empty():
		return {}
	var trail_distance: float = max(0.0, float(chain_trail.get("total_distance", 0.0)) - distance_behind)
	return _sample_chain_history_at_distance(_get_chain_history(), trail_distance)

func _get_chain_trail_sample_by_distance(trail_distance: float) -> Dictionary:
	if chain_trail.is_empty():
		return {}
	return _sample_chain_history_at_distance(_get_chain_history(), trail_distance)

func _sample_chain_history_at_distance(history: Array, trail_distance: float) -> Dictionary:
	if history.is_empty():
		return {}
	if trail_distance <= float(history[0].get("distance", 0.0)):
		return history[0]
	var last_sample: Dictionary = history[history.size() - 1]
	if trail_distance > float(last_sample.get("distance", 0.0)):
		return {}
	for index in range(1, history.size()):
		var previous_sample: Dictionary = history[index - 1]
		var sample: Dictionary = history[index]
		var previous_distance: float = float(previous_sample.get("distance", 0.0))
		var sample_distance: float = float(sample.get("distance", previous_distance))
		if trail_distance <= sample_distance:
			var alpha: float = clamp((trail_distance - previous_distance) / max(sample_distance - previous_distance, 0.001), 0.0, 1.0)
			var previous_position: Vector2 = previous_sample.get("position", global_position)
			var sample_position: Vector2 = sample.get("position", previous_position)
			return {
				"position": previous_position.lerp(sample_position, alpha),
				"rotation": lerp_angle(float(previous_sample.get("rotation", rotation)), float(sample.get("rotation", rotation)), alpha),
				"direction": (previous_sample.get("direction", direction) as Vector2).lerp(sample.get("direction", direction), alpha).normalized()
			}
	return {}

func _update_quarter_sine_motion(delta: float) -> void:
	forward_distance += speed * delta
	var progress: float = clamp(forward_distance / max(quarter_sine_distance, 1.0), 0.0, 1.0)
	var forward_offset: Vector2 = base_direction * forward_distance
	var lateral_offset: Vector2 = perpendicular_direction * sin(progress * PI * 0.5) * sine_amplitude * quarter_sine_side
	global_position = base_position + forward_offset + lateral_offset
	var curve_strength: float = cos(progress * PI * 0.5) * 0.34 * quarter_sine_side
	rotation = (base_direction + perpendicular_direction * curve_strength).angle()

func _update_returning_sine_motion(delta: float) -> bool:
	if not return_started and travel_time < return_after:
		_update_quarter_sine_motion(delta)
		return false

	return_started = true
	var return_target: Vector2 = Vector2(return_target_x, return_target_y)
	var to_target: Vector2 = return_target - global_position
	var distance_to_target: float = sqrt(to_target.length_squared())
	if distance_to_target <= max(hit_radius, return_speed * delta):
		global_position = return_target
		if split_on_return and not split_performed:
			_spawn_split_bullets()
		recycle()
		return true

	direction = to_target / distance_to_target
	var wobble := direction.orthogonal() * sin(travel_time * TAU * sine_frequency + sine_phase) * sine_amplitude * 0.18
	global_position += (direction * return_speed + wobble) * delta
	rotation = direction.angle()
	return false

func _try_hit_player() -> void:
	if target == null or not is_instance_valid(target):
		return
	var target_center: Vector2 = target.global_position
	var target_radius: float = 0.0
	if target.has_method("get_hurtbox_center"):
		target_center = target.get_hurtbox_center()
	if target.has_method("get_hurtbox_radius"):
		target_radius = float(target.get_hurtbox_radius())
	var total_radius: float = hit_radius + target_radius
	if global_position.distance_squared_to(target_center) > total_radius * total_radius:
		return
	if target.has_method("take_damage"):
		target.take_damage(damage)
	recycle()

func _update_lifetime_fade() -> void:
	var fade_duration: float = min(LIFETIME_FADE_DURATION, max_lifetime)
	modulate.a = clamp(lifetime / max(fade_duration, 0.001), 0.0, 1.0)

func _spawn_split_bullets() -> void:
	split_performed = true
	if split_count <= 0:
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var bullet_scene := ENEMY_BULLET_SCENE
	if bullet_scene == null:
		return

	var count: int = max(1, split_count)
	if current_scene.has_method("_trim_spawn_count_for_group"):
		count = int(current_scene._trim_spawn_count_for_group("enemy_projectiles", count, _get_enemy_projectile_limit(current_scene)))
	else:
		count = PERFORMANCE_GUARD.trim_requested_count(current_scene, "enemy_projectiles", count, _get_enemy_projectile_limit(current_scene))
	if count <= 0:
		return
	for index in range(count):
		var bullet = null
		if current_scene.has_method("take_runtime_enemy_projectile_from_pool"):
			bullet = current_scene.take_runtime_enemy_projectile_from_pool()
		if bullet == null:
			bullet = bullet_scene.instantiate()
		if bullet == null:
			continue
		var shot_direction := Vector2.RIGHT
		if split_pattern == "fan":
			var angle_offset := 0.0
			if count > 1:
				angle_offset = lerpf(-split_spread * 0.5, split_spread * 0.5, float(index) / float(count - 1))
			shot_direction = direction.rotated(angle_offset)
		elif split_pattern == "cross":
			shot_direction = _get_relative_cross_split_direction(index)
		else:
			var shot_angle := TAU * float(index) / float(count)
			shot_direction = Vector2.RIGHT.rotated(shot_angle)
		if bullet.get_parent() == null:
			current_scene.add_child(bullet)
		elif bullet.get_parent() != current_scene:
			bullet.get_parent().remove_child(bullet)
			current_scene.add_child(bullet)
		if bullet.has_method("reset_projectile"):
			bullet.reset_projectile({
				"position": global_position,
				"direction": shot_direction,
				"speed": split_speed,
				"damage": damage * split_damage_scale,
				"lifetime": split_lifetime,
				"hit_radius": max(1.0, hit_radius * split_hit_radius_scale),
				"visual_color": visual_color,
				"motion_mode": split_motion_mode,
				"split_on_return": false,
				"split_count": 0,
				"split_after_time": 0.0,
				"sine_amplitude": max(18.0, sine_amplitude * 0.55),
				"sine_frequency": max(1.0, sine_frequency + 0.2),
				"quarter_sine_distance": max(120.0, quarter_sine_distance * 0.72),
				"quarter_sine_side": -1.0 if index % 2 == 0 else 1.0,
				"size_scale": max(0.1, size_scale * split_size_scale),
				"visual_style": split_visual_style if split_visual_style != "" else visual_style,
				"target": target
			})

func _get_relative_cross_split_direction(index: int) -> Vector2:
	var forward := direction.normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT
	var right := forward.orthogonal().normalized()
	match index % 4:
		0:
			return forward
		1:
			return right
		2:
			return -forward
		_:
			return -right

func _apply_visuals() -> void:
	var polygon := get_node_or_null("Polygon2D") as Polygon2D
	if polygon == null:
		return
	if visual_style == "rose_flower":
		_clear_boss_projectile_visuals()
		_apply_rose_flower_visual(polygon)
		return
	_clear_rose_flower_visuals()
	if visual_style.begins_with("boss_"):
		_apply_boss_projectile_visual(polygon)
		return
	_clear_boss_projectile_visuals()
	if visual_style == "solid_circle":
		_apply_solid_circle_visual(polygon)
		return

	var glow := get_node_or_null("Glow") as Polygon2D
	if glow == null:
		glow = Polygon2D.new()
		glow.name = "Glow"
		glow.z_index = -1
		add_child(glow)

	var outline := get_node_or_null("Outline") as Polygon2D
	if outline == null:
		outline = Polygon2D.new()
		outline.name = "Outline"
		outline.z_index = -2
		add_child(outline)

	var ring := get_node_or_null("Ring") as Line2D
	if ring == null:
		ring = Line2D.new()
		ring.name = "Ring"
		ring.closed = true
		ring.z_index = 1
		add_child(ring)

	var base_shape := _get_shape_for_mode()
	polygon.color = visual_color
	polygon.polygon = base_shape
	polygon.scale = _get_visual_scale()

	outline.color = Color(0.0, 0.0, 0.0, 0.88)
	outline.polygon = base_shape
	outline.scale = polygon.scale * 1.24

	glow.color = Color(visual_color.r, visual_color.g, visual_color.b, 0.28)
	glow.polygon = base_shape
	glow.scale = polygon.scale * 1.7

	ring.width = 2.5 * max(size_scale, 0.8)
	ring.default_color = Color(0.05, 0.02, 0.04, 0.7)
	ring.points = ENEMY_GEOMETRY.build_circle_points(12.0 * polygon.scale.x, 14)

func _apply_solid_circle_visual(polygon: Polygon2D) -> void:
	_clear_extra_visual("Glow")
	_clear_extra_visual("Ring")
	var outline := get_node_or_null("Outline") as Polygon2D
	if outline == null:
		outline = Polygon2D.new()
		outline.name = "Outline"
		add_child(outline)
	outline.z_index = -1
	outline.color = Color(0.0, 0.0, 0.0, 0.92)
	outline.polygon = ENEMY_GEOMETRY.build_circle_points(9.6, 24)
	outline.scale = Vector2.ONE * size_scale

	polygon.color = visual_color
	polygon.polygon = ENEMY_GEOMETRY.build_circle_points(8.0, 24)
	polygon.scale = Vector2.ONE * size_scale

func _apply_rose_flower_visual(polygon: Polygon2D) -> void:
	_clear_extra_visual("Glow")
	_clear_extra_visual("Outline")
	_clear_extra_visual("Ring")
	polygon.color = Color(0.9, 0.08, 0.18, 1.0)
	polygon.polygon = ENEMY_GEOMETRY.build_circle_points(8.0, 18)
	polygon.scale = Vector2.ONE * size_scale

	for index in range(4):
		var petal_name := "RosePetal%d" % index
		var petal := get_node_or_null(petal_name) as Polygon2D
		if petal == null:
			petal = Polygon2D.new()
			petal.name = petal_name
			petal.z_index = -1
			add_child(petal)
		var angle: float = TAU * float(index) / 4.0
		petal.position = Vector2.RIGHT.rotated(angle) * 10.0 * size_scale
		petal.color = Color(0.14, 0.72, 0.22, 1.0)
		petal.polygon = ENEMY_GEOMETRY.build_circle_points(2.0, 12)
		petal.scale = Vector2.ONE * size_scale


func _apply_boss_projectile_visual(polygon: Polygon2D) -> void:
	_clear_extra_visual("Glow")
	_clear_extra_visual("Ring")
	_clear_extra_visual("BossCore")
	if visual_style == "boss_dark_triangle":
		var outline := get_node_or_null("Outline") as Polygon2D
		if outline == null:
			outline = Polygon2D.new()
			outline.name = "Outline"
			add_child(outline)
		polygon.color = Color(0.16, 0.05, 0.24, 1.0)
		polygon.polygon = PackedVector2Array([
			Vector2(14.0, 0.0),
			Vector2(-10.0, -5.0),
			Vector2(-10.0, 5.0)
		])
		polygon.scale = Vector2.ONE * size_scale
		outline.z_index = -1
		outline.color = Color(0.0, 0.0, 0.0, 0.9)
		outline.polygon = PackedVector2Array([
			Vector2(16.0, 0.0),
			Vector2(-12.0, -7.0),
			Vector2(-12.0, 7.0)
		])
		outline.scale = Vector2.ONE * size_scale
		return
	if visual_style == "boss_turning_hex":
		_clear_extra_visual("Outline")
		polygon.color = Color(0.16, 0.05, 0.24, 1.0)
		polygon.polygon = ENEMY_GEOMETRY.build_circle_points(9.0, 20)
		polygon.scale = Vector2.ONE * size_scale
		return
	polygon.color = Color(0.16, 0.05, 0.24, 1.0)
	polygon.polygon = ENEMY_GEOMETRY.build_circle_points(8.0, 20)
	polygon.scale = Vector2.ONE * size_scale

	var outline := get_node_or_null("Outline") as Polygon2D
	if outline == null:
		outline = Polygon2D.new()
		outline.name = "Outline"
		add_child(outline)
	outline.z_index = -1
	outline.color = Color(0.0, 0.0, 0.0, 0.9)
	outline.polygon = ENEMY_GEOMETRY.build_circle_points(8.0, 20)
	outline.scale = Vector2.ONE * size_scale * 1.2

	if visual_style == "boss_dark_core_orb":
		var core := Polygon2D.new()
		core.name = "BossCore"
		core.z_index = 1
		core.color = Color(1.0, 1.0, 1.0, 0.96)
		core.polygon = ENEMY_GEOMETRY.build_circle_points(4.0, 16)
		core.scale = Vector2.ONE * size_scale
		add_child(core)


func _get_boss_hex_shape() -> PackedVector2Array:
	var shape_key := "boss_hex"
	if visual_shape_cache.has(shape_key):
		return visual_shape_cache[shape_key] as PackedVector2Array
	var shape := PackedVector2Array()
	for index in range(6):
		shape.append(Vector2.RIGHT.rotated(TAU * float(index) / 6.0) * 9.0)
	visual_shape_cache[shape_key] = shape
	return shape


func _clear_extra_visual(node_name: String) -> void:
	var node := get_node_or_null(node_name)
	if node != null:
		remove_child(node)
		node.queue_free()


func _clear_rose_flower_visuals() -> void:
	for index in range(4):
		_clear_extra_visual("RosePetal%d" % index)


func _clear_boss_projectile_visuals() -> void:
	_clear_extra_visual("BossCore")

func _get_shape_for_mode() -> PackedVector2Array:
	var shape_key: String = "straight"
	match motion_mode:
		"sine", "quarter_sine", "returning_sine":
			shape_key = "curve"
		"turning":
			shape_key = "turning"
	if visual_shape_cache.has(shape_key):
		return visual_shape_cache[shape_key] as PackedVector2Array
	var shape: PackedVector2Array = PackedVector2Array()
	match shape_key:
		"curve":
			shape = PackedVector2Array([
				Vector2(0.0, -9.0),
				Vector2(10.0, -3.0),
				Vector2(12.0, 0.0),
				Vector2(10.0, 3.0),
				Vector2(0.0, 9.0),
				Vector2(-8.0, 0.0)
			])
		"turning":
			shape = PackedVector2Array([
				Vector2(0.0, -10.0),
				Vector2(8.0, -4.0),
				Vector2(10.0, 4.0),
				Vector2(0.0, 10.0),
				Vector2(-10.0, 4.0),
				Vector2(-8.0, -4.0)
			])
		_:
			shape = ENEMY_GEOMETRY.build_circle_points(8.0, 20)
	visual_shape_cache[shape_key] = shape
	return shape

func _get_visual_scale() -> Vector2:
	match motion_mode:
		"sine":
			return Vector2(1.65, 1.05) * size_scale
		"quarter_sine":
			return Vector2(1.85, 1.08) * size_scale
		"returning_sine":
			return Vector2(1.95, 1.16) * size_scale
		"turning":
			return Vector2(1.3, 1.3) * size_scale
		_:
			return Vector2.ONE * size_scale

func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"direction": [direction.x, direction.y],
		"speed": speed,
		"damage": damage,
		"lifetime": lifetime,
		"hit_radius": hit_radius,
		"visual_color": [visual_color.r, visual_color.g, visual_color.b, visual_color.a],
		"motion_mode": motion_mode,
		"sine_amplitude": sine_amplitude,
		"sine_frequency": sine_frequency,
		"sine_phase": sine_phase,
		"turn_start_delay": turn_start_delay,
		"turn_interval": turn_interval,
		"turn_angle_step": turn_angle_step,
		"turn_direction_sign": turn_direction_sign,
		"homing_turn_rate": homing_turn_rate,
		"quarter_sine_distance": quarter_sine_distance,
		"quarter_sine_side": quarter_sine_side,
		"return_after": return_after,
		"return_speed": return_speed,
		"return_target_x": return_target_x,
		"return_target_y": return_target_y,
		"split_on_return": split_on_return,
		"split_count": split_count,
		"split_speed": split_speed,
		"split_damage_scale": split_damage_scale,
		"split_lifetime": split_lifetime,
		"split_motion_mode": split_motion_mode,
		"split_after_time": split_after_time,
		"split_pattern": split_pattern,
		"split_spread": split_spread,
		"split_visual_style": split_visual_style,
		"split_size_scale": split_size_scale,
		"split_hit_radius_scale": split_hit_radius_scale,
		"visual_style": visual_style,
		"size_scale": size_scale,
		"chain_follow_spacing": chain_follow_spacing,
		"chain_follow_index": chain_follow_index,
		"travel_time": travel_time,
		"forward_distance": forward_distance,
		"base_position": [base_position.x, base_position.y],
		"base_direction": [base_direction.x, base_direction.y],
		"turn_delay_remaining": turn_delay_remaining,
		"turn_tick_remaining": turn_tick_remaining,
		"return_started": return_started,
		"split_performed": split_performed
	}

func apply_save_data(data: Dictionary, target_node: Node2D) -> void:
	pooled = false
	batch_simulation_enabled = false
	var position_data = data.get("position", [0.0, 0.0])
	if position_data.size() >= 2:
		global_position = Vector2(float(position_data[0]), float(position_data[1]))

	var direction_data = data.get("direction", [1.0, 0.0])
	if direction_data.size() >= 2:
		direction = Vector2(float(direction_data[0]), float(direction_data[1])).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	speed = float(data.get("speed", speed))
	damage = float(data.get("damage", damage))
	lifetime = float(data.get("lifetime", lifetime))
	hit_radius = float(data.get("hit_radius", hit_radius))
	motion_mode = str(data.get("motion_mode", motion_mode))
	sine_amplitude = float(data.get("sine_amplitude", sine_amplitude))
	sine_frequency = float(data.get("sine_frequency", sine_frequency))
	sine_phase = float(data.get("sine_phase", sine_phase))
	turn_start_delay = float(data.get("turn_start_delay", turn_start_delay))
	turn_interval = float(data.get("turn_interval", turn_interval))
	turn_angle_step = float(data.get("turn_angle_step", turn_angle_step))
	turn_direction_sign = float(data.get("turn_direction_sign", turn_direction_sign))
	homing_turn_rate = float(data.get("homing_turn_rate", homing_turn_rate))
	quarter_sine_distance = float(data.get("quarter_sine_distance", quarter_sine_distance))
	quarter_sine_side = float(data.get("quarter_sine_side", quarter_sine_side))
	return_after = float(data.get("return_after", return_after))
	return_speed = float(data.get("return_speed", return_speed))
	return_target_x = float(data.get("return_target_x", return_target_x))
	return_target_y = float(data.get("return_target_y", return_target_y))
	split_on_return = bool(data.get("split_on_return", split_on_return))
	split_count = int(data.get("split_count", split_count))
	split_speed = float(data.get("split_speed", split_speed))
	split_damage_scale = float(data.get("split_damage_scale", split_damage_scale))
	split_lifetime = float(data.get("split_lifetime", split_lifetime))
	split_motion_mode = str(data.get("split_motion_mode", split_motion_mode))
	split_after_time = float(data.get("split_after_time", split_after_time))
	split_pattern = str(data.get("split_pattern", split_pattern))
	split_spread = float(data.get("split_spread", split_spread))
	split_visual_style = str(data.get("split_visual_style", split_visual_style))
	split_size_scale = float(data.get("split_size_scale", split_size_scale))
	split_hit_radius_scale = float(data.get("split_hit_radius_scale", split_hit_radius_scale))
	visual_style = str(data.get("visual_style", visual_style))
	size_scale = float(data.get("size_scale", size_scale))
	chain_follow_spacing = float(data.get("chain_follow_spacing", chain_follow_spacing))
	chain_follow_index = int(data.get("chain_follow_index", chain_follow_index))
	travel_time = float(data.get("travel_time", 0.0))
	forward_distance = float(data.get("forward_distance", 0.0))

	var base_position_data = data.get("base_position", [global_position.x, global_position.y])
	if base_position_data.size() >= 2:
		base_position = Vector2(float(base_position_data[0]), float(base_position_data[1]))
	else:
		base_position = global_position

	var base_direction_data = data.get("base_direction", [direction.x, direction.y])
	if base_direction_data.size() >= 2:
		base_direction = Vector2(float(base_direction_data[0]), float(base_direction_data[1])).normalized()
	if base_direction == Vector2.ZERO:
		base_direction = direction

	perpendicular_direction = base_direction.orthogonal().normalized()
	turn_delay_remaining = float(data.get("turn_delay_remaining", turn_start_delay))
	turn_tick_remaining = float(data.get("turn_tick_remaining", turn_interval))
	return_started = bool(data.get("return_started", false))
	split_performed = bool(data.get("split_performed", false))

	var color_data = data.get("visual_color", [visual_color.r, visual_color.g, visual_color.b, visual_color.a])
	if color_data.size() >= 4:
		visual_color = Color(float(color_data[0]), float(color_data[1]), float(color_data[2]), float(color_data[3]))

	target = target_node
	add_to_group("enemy_projectiles")
	_register_runtime_projectile(false)
	_apply_visuals()

func _get_enemy_projectile_limit(current_scene: Node) -> int:
	if current_scene != null and current_scene.has_method("_get_difficulty_limit"):
		return int(current_scene._get_difficulty_limit("enemy_projectile_limit", PERFORMANCE_GUARD.DEFAULT_ENEMY_PROJECTILE_LIMIT))
	return PERFORMANCE_GUARD.DEFAULT_ENEMY_PROJECTILE_LIMIT

func _register_runtime_projectile(is_pooled: bool) -> void:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("register_runtime_enemy_projectile"):
		scene.register_runtime_enemy_projectile(self, is_pooled)

func _unregister_runtime_projectile() -> void:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("unregister_runtime_enemy_projectile"):
		scene.unregister_runtime_enemy_projectile(self)

func _get_runtime_pool_count() -> int:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("get_runtime_enemy_projectile_pool"):
		return (scene.get_runtime_enemy_projectile_pool() as Array).size()
	var tree := get_tree()
	return tree.get_node_count_in_group(POOL_GROUP) if tree != null else 0

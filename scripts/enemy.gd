extends CharacterBody2D

signal defeated(enemy_kind: String)

const HEART_DROP_CHANCE := 0.012
const HEART_DROP_CHANCE_ELITE := 0.02
const HEART_DROP_CHANCE_BOSS := 0.044
const BOSS_LASER_LENGTH := 980.0

@export var speed: float = 80.0
@export var max_health: float = 20.0
@export var touch_damage: float = 10.0
@export var contact_radius: float = 36.0
@export var experience_reward: int = 10
@export var reward_tier: int = 1
@export var exp_gem_scene: PackedScene = preload("res://scenes/exp_gem.tscn")
@export var heart_pickup_scene: PackedScene = preload("res://scenes/heart_pickup.tscn")
@export var projectile_scene: PackedScene = preload("res://scenes/enemy_bullet.tscn")

var target: Node2D
var current_health: float
var slow_multiplier: float = 1.0
var slow_timer: float = 0.0
var vulnerability_bonus: float = 0.0
var vulnerability_timer: float = 0.0
var bleed_damage_per_second: float = 0.0
var bleed_timer: float = 0.0
var enemy_kind: String = "normal"
var archetype_id: String = "chaser"
var behavior_id: String = "chaser"
var secondary_behavior_id: String = ""
var base_scale: Vector2 = Vector2.ONE
var status_visual_time: float = 0.0
var status_root: Node2D
var slow_ring: Line2D
var vulnerability_ring: Line2D
var trait_ring: Line2D
var dash_warning_ring: Line2D
var display_color: Color = Color(0.34, 0.8, 1.0, 1.0)

var preferred_distance: float = 220.0
var shot_interval: float = 1.8
var shot_timer: float = 0.0
var projectile_speed: float = 240.0
var projectile_damage: float = 8.0
var projectile_lifetime: float = 4.0
var projectile_spread: float = 0.0
var projectile_count: int = 1

var acceleration_interval: float = 0.0
var acceleration_boost: float = 1.8
var acceleration_duration: float = 0.0
var acceleration_timer: float = 0.0
var acceleration_remaining: float = 0.0

var dash_interval: float = 0.0
var dash_duration: float = 0.0
var dash_speed_multiplier: float = 2.4
var dash_windup_duration: float = 0.42
var dash_timer: float = 0.0
var dash_windup_remaining: float = 0.0
var dash_remaining: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT

var strafe_sign: float = 1.0

var boss_radial_interval: float = 0.95
var boss_radial_timer: float = 0.0
var boss_radial_bullets: int = 12
var boss_sine_interval: float = 3.2
var boss_sine_cooldown: float = 0.0
var boss_sine_stream_duration: float = 1.6
var boss_sine_stream_remaining: float = 0.0
var boss_sine_stream_rate: float = 0.14
var boss_sine_stream_timer: float = 0.0
var boss_turning_interval: float = 4.0
var boss_turning_timer: float = 0.0
var boss_turning_bullets: int = 8
var boss_turning_sign: float = 1.0
var boss_orbit_sign: float = 1.0
var boss_pattern_rotation: float = 0.0
var boss_display_name: String = "祸月星核"
var boss_battle_elapsed: float = 0.0
var boss_phase: int = 1
var boss_split_interval: float = 5.8
var boss_split_timer: float = 0.0
var boss_laser_interval: float = 8.5
var boss_laser_timer: float = 0.0
var boss_laser_duration: float = 2.7
var boss_laser_remaining: float = 0.0
var boss_laser_rotation: float = 0.0
var boss_laser_spin_duration: float = 1.75
var boss_laser_start_rotation: float = 0.0
var boss_laser_final_rotation: float = 0.0
var boss_laser_hit_timer: float = 0.0
var boss_orbit_bomb_interval: float = 10.0
var boss_orbit_bomb_timer: float = 0.0
var boss_orbit_bomb_remaining: float = 0.0
var boss_orbit_bomb_angle: float = 0.0
var boss_orbit_bomb_shot_timer: float = 0.0
var boss_peacock_interval: float = 9.0
var boss_peacock_timer: float = 0.0
var boss_peacock_charge_remaining: float = 0.0
var boss_helper_root: Node2D
var boss_laser_lines: Array[Line2D] = []
var boss_laser_core_lines: Array[Line2D] = []
var boss_orbit_ball: Node2D
var boss_peacock_markers: Array[Polygon2D] = []
var profile_initialized: bool = false

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 0
	collision_mask = 0
	current_health = max_health if current_health <= 0.0 else min(current_health, max_health)
	base_scale = scale
	if enemy_kind == "":
		enemy_kind = "normal"
	add_to_group("enemies")
	if not profile_initialized:
		_reset_runtime_state(true)
	_ensure_status_visuals()
	_apply_visuals()
	if enemy_kind == "boss":
		_ensure_boss_helpers()

func _physics_process(delta: float) -> void:
	status_visual_time += delta
	_update_status_timers(delta)
	_update_bleed(delta)
	_update_status_visuals()

	if target == null or not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_update_behavior_state(delta)
	velocity = _compute_velocity(delta)
	move_and_slide()

func apply_enemy_profile(kind: String, profile: Dictionary) -> void:
	enemy_kind = kind
	archetype_id = str(profile.get("archetype", archetype_id))
	behavior_id = str(profile.get("behavior", behavior_id))
	secondary_behavior_id = str(profile.get("secondary_behavior", secondary_behavior_id))
	max_health = float(profile.get("max_health", max_health))
	current_health = min(current_health if current_health > 0.0 else max_health, max_health)
	speed = float(profile.get("speed", speed))
	touch_damage = float(profile.get("touch_damage", touch_damage))
	contact_radius = float(profile.get("contact_radius", contact_radius))
	experience_reward = int(profile.get("experience_reward", experience_reward))
	reward_tier = clamp(int(profile.get("reward_tier", reward_tier)), 1, 4)

	preferred_distance = float(profile.get("preferred_distance", preferred_distance))
	shot_interval = float(profile.get("shot_interval", shot_interval))
	projectile_speed = float(profile.get("projectile_speed", projectile_speed))
	projectile_damage = float(profile.get("projectile_damage", projectile_damage))
	projectile_lifetime = float(profile.get("projectile_lifetime", projectile_lifetime))
	projectile_spread = float(profile.get("projectile_spread", projectile_spread))
	projectile_count = int(profile.get("projectile_count", projectile_count))

	acceleration_interval = float(profile.get("acceleration_interval", acceleration_interval))
	acceleration_boost = float(profile.get("acceleration_boost", acceleration_boost))
	acceleration_duration = float(profile.get("acceleration_duration", acceleration_duration))
	dash_interval = float(profile.get("dash_interval", dash_interval))
	dash_duration = float(profile.get("dash_duration", dash_duration))
	dash_speed_multiplier = float(profile.get("dash_speed_multiplier", dash_speed_multiplier))
	dash_windup_duration = float(profile.get("dash_windup_duration", dash_windup_duration))

	boss_radial_interval = float(profile.get("boss_radial_interval", boss_radial_interval))
	boss_radial_bullets = int(profile.get("boss_radial_bullets", boss_radial_bullets))
	boss_sine_interval = float(profile.get("boss_sine_interval", boss_sine_interval))
	boss_sine_stream_duration = float(profile.get("boss_sine_stream_duration", boss_sine_stream_duration))
	boss_sine_stream_rate = float(profile.get("boss_sine_stream_rate", boss_sine_stream_rate))
	boss_turning_interval = float(profile.get("boss_turning_interval", boss_turning_interval))
	boss_turning_bullets = int(profile.get("boss_turning_bullets", boss_turning_bullets))
	boss_display_name = str(profile.get("boss_name", boss_display_name))

	var scale_value: float = float(profile.get("scale", 1.0))
	scale = base_scale * scale_value
	display_color = profile.get("color", display_color) if profile.has("color") else display_color
	profile_initialized = true
	_reset_runtime_state(true)
	_apply_visuals(display_color)
	if enemy_kind == "boss":
		_ensure_boss_helpers()

func _reset_runtime_state(randomize_timers: bool) -> void:
	if randomize_timers:
		shot_timer = randf_range(0.15, max(0.16, shot_interval))
		acceleration_timer = randf_range(0.2, max(0.22, acceleration_interval)) if acceleration_interval > 0.0 else 0.0
		dash_timer = randf_range(0.35, max(0.4, dash_interval)) if dash_interval > 0.0 else 0.0
		boss_radial_timer = randf_range(0.18, max(0.2, boss_radial_interval))
		boss_sine_cooldown = randf_range(1.0, max(1.1, boss_sine_interval))
		boss_turning_timer = randf_range(1.4, max(1.5, boss_turning_interval))
		boss_split_timer = randf_range(2.0, max(2.2, boss_split_interval))
		boss_laser_timer = randf_range(3.0, max(3.2, boss_laser_interval))
		boss_orbit_bomb_timer = randf_range(4.0, max(4.2, boss_orbit_bomb_interval))
		boss_peacock_timer = randf_range(4.0, max(4.2, boss_peacock_interval))
		strafe_sign = -1.0 if randi() % 2 == 0 else 1.0
		boss_turning_sign = -1.0 if randi() % 2 == 0 else 1.0
		boss_orbit_sign = -1.0 if randi() % 2 == 0 else 1.0
	else:
		shot_timer = shot_interval
		acceleration_timer = acceleration_interval
		dash_timer = dash_interval
		boss_radial_timer = boss_radial_interval
		boss_sine_cooldown = boss_sine_interval
		boss_turning_timer = boss_turning_interval
		boss_split_timer = boss_split_interval
		boss_laser_timer = boss_laser_interval
		boss_orbit_bomb_timer = boss_orbit_bomb_interval
		boss_peacock_timer = boss_peacock_interval
		strafe_sign = 1.0
		boss_turning_sign = 1.0
		boss_orbit_sign = 1.0
	acceleration_remaining = 0.0
	dash_windup_remaining = 0.0
	dash_remaining = 0.0
	boss_sine_stream_remaining = 0.0
	boss_sine_stream_timer = 0.0
	boss_pattern_rotation = randf() * TAU if randomize_timers else 0.0
	boss_battle_elapsed = 0.0
	boss_phase = 1
	boss_laser_remaining = 0.0
	boss_laser_rotation = randf() * TAU if randomize_timers else 0.0
	boss_laser_start_rotation = boss_laser_rotation
	boss_laser_final_rotation = boss_laser_rotation
	boss_laser_hit_timer = 0.0
	boss_orbit_bomb_remaining = 0.0
	boss_orbit_bomb_angle = 0.0
	boss_orbit_bomb_shot_timer = 0.0
	boss_peacock_charge_remaining = 0.0

func get_boss_ui_payload() -> Dictionary:
	return {
		"name": boss_display_name,
		"current_health": current_health,
		"max_health": max_health,
		"phase": boss_phase
	}

func _get_boss_phase() -> int:
	var health_ratio: float = current_health / max(max_health, 1.0)
	if health_ratio <= 0.34:
		return 3
	if health_ratio <= 0.67:
		return 2
	return 1

func _ensure_boss_helpers() -> void:
	if boss_helper_root != null:
		return

	boss_helper_root = Node2D.new()
	boss_helper_root.name = "BossHelpers"
	boss_helper_root.z_index = 15
	add_child(boss_helper_root)

	for index in range(8):
		var laser := Line2D.new()
		laser.width = 18.0
		laser.default_color = Color(1.0, 0.44, 0.16, 0.36)
		laser.visible = false
		boss_helper_root.add_child(laser)
		boss_laser_lines.append(laser)

		var laser_core := Line2D.new()
		laser_core.width = 7.0
		laser_core.default_color = Color(1.0, 0.92, 0.58, 0.94)
		laser_core.visible = false
		boss_helper_root.add_child(laser_core)
		boss_laser_core_lines.append(laser_core)

func _ensure_boss_orbit_ball() -> void:
	_ensure_boss_helpers()
	if boss_orbit_ball != null:
		return

	boss_orbit_ball = Node2D.new()
	boss_orbit_ball.name = "OrbitBomb"
	boss_helper_root.add_child(boss_orbit_ball)

	var glow := Polygon2D.new()
	glow.name = "Glow"
	glow.color = Color(1.0, 0.72, 0.28, 0.26)
	glow.polygon = PackedVector2Array([
		Vector2(0.0, -26.0),
		Vector2(26.0, 0.0),
		Vector2(0.0, 26.0),
		Vector2(-26.0, 0.0)
	])
	glow.scale = Vector2(1.55, 1.55)
	boss_orbit_ball.add_child(glow)

	var core := Polygon2D.new()
	core.name = "Core"
	core.color = Color(1.0, 0.86, 0.56, 0.98)
	core.polygon = PackedVector2Array([
		Vector2(0.0, -18.0),
		Vector2(18.0, 0.0),
		Vector2(0.0, 18.0),
		Vector2(-18.0, 0.0)
	])
	boss_orbit_ball.add_child(core)

	var ring := Line2D.new()
	ring.name = "Ring"
	ring.width = 4.0
	ring.default_color = Color(1.0, 0.96, 0.7, 0.9)
	ring.closed = true
	ring.points = _build_circle_points(24.0)
	boss_orbit_ball.add_child(ring)

func _clear_boss_orbit_ball() -> void:
	if boss_orbit_ball != null:
		boss_orbit_ball.queue_free()
		boss_orbit_ball = null

func _ensure_boss_peacock_markers(count: int) -> void:
	_ensure_boss_helpers()
	if boss_peacock_markers.size() == count:
		return
	_clear_boss_peacock_markers()
	for index in range(count):
		var marker := Polygon2D.new()
		marker.color = Color(0.98, 0.84, 0.38, 0.72)
		marker.polygon = PackedVector2Array([
			Vector2(0.0, -10.0),
			Vector2(10.0, 0.0),
			Vector2(0.0, 10.0),
			Vector2(-10.0, 0.0)
		])
		boss_helper_root.add_child(marker)
		boss_peacock_markers.append(marker)

func _clear_boss_peacock_markers() -> void:
	for marker in boss_peacock_markers:
		if marker != null:
			marker.queue_free()
	boss_peacock_markers.clear()

func _compute_velocity(delta: float) -> Vector2:
	var to_target := target.global_position - global_position
	var distance_to_target := to_target.length()
	var direction_to_target := to_target.normalized() if distance_to_target > 0.001 else Vector2.RIGHT
	var move_direction := direction_to_target
	var move_speed := speed * slow_multiplier

	if behavior_id == "boss":
		return _compute_boss_velocity(direction_to_target, distance_to_target, delta)

	if has_trait("shooter"):
		if distance_to_target < preferred_distance - 34.0:
			move_direction = -direction_to_target
		elif distance_to_target > preferred_distance + 44.0:
			move_direction = direction_to_target
		else:
			move_direction = (direction_to_target.orthogonal() * strafe_sign + direction_to_target * 0.18).normalized()

	if has_trait("dash") and dash_windup_remaining > 0.0:
		return Vector2.ZERO

	if has_trait("dash") and dash_remaining > 0.0:
		move_direction = dash_direction
		move_speed *= dash_speed_multiplier

	if has_trait("accelerator") and acceleration_remaining > 0.0:
		move_speed *= acceleration_boost

	if behavior_id == "swarm":
		move_speed *= 1.1

	return move_direction.normalized() * move_speed

func _compute_boss_velocity(direction_to_target: Vector2, distance_to_target: float, delta: float) -> Vector2:
	var radial := Vector2.ZERO
	if distance_to_target > preferred_distance + 42.0:
		radial = direction_to_target
	elif distance_to_target < preferred_distance - 36.0:
		radial = -direction_to_target * 0.88
	else:
		radial = direction_to_target * 0.18

	var tangential := direction_to_target.orthogonal() * boss_orbit_sign
	boss_pattern_rotation = wrapf(boss_pattern_rotation + delta * 0.45, 0.0, TAU)
	var drift := Vector2.RIGHT.rotated(boss_pattern_rotation) * 0.16
	var move_direction := (tangential * 0.92 + radial * 0.58 + drift).normalized()
	return move_direction * speed * slow_multiplier

func _update_behavior_state(delta: float) -> void:
	_tick_trait(behavior_id, delta)
	if secondary_behavior_id != "" and secondary_behavior_id != behavior_id:
		_tick_trait(secondary_behavior_id, delta)

func _tick_trait(trait_id: String, delta: float) -> void:
	match trait_id:
		"shooter":
			_update_shooter_trait(delta)
		"accelerator":
			_update_accelerator_trait(delta)
		"dash":
			_update_dash_trait(delta)
		"boss":
			_update_boss_trait(delta)

func _update_shooter_trait(delta: float) -> void:
	if shot_interval <= 0.0:
		return
	shot_timer -= delta
	if shot_timer > 0.0:
		return
	shot_timer += max(0.18, shot_interval)
	_fire_shooter_pattern()

func _update_accelerator_trait(delta: float) -> void:
	if acceleration_remaining > 0.0:
		acceleration_remaining = max(0.0, acceleration_remaining - delta)
	if acceleration_interval <= 0.0:
		return
	acceleration_timer -= delta
	if acceleration_timer > 0.0:
		return
	acceleration_timer += max(0.2, acceleration_interval)
	acceleration_remaining = max(acceleration_remaining, acceleration_duration)
	_spawn_status_burst(Color(1.0, 0.74, 0.34, 0.26), 22.0 + scale.x * 6.0)

func _update_dash_trait(delta: float) -> void:
	if dash_remaining > 0.0:
		dash_remaining = max(0.0, dash_remaining - delta)
		return
	if dash_windup_remaining > 0.0:
		dash_windup_remaining = max(0.0, dash_windup_remaining - delta)
		if dash_windup_remaining <= 0.0:
			dash_remaining = max(dash_remaining, dash_duration)
			_spawn_dash_trail(dash_direction, 42.0 + scale.x * 8.0)
		return
	if dash_interval <= 0.0:
		return
	dash_timer -= delta
	if dash_timer > 0.0:
		return
	dash_timer += max(0.3, dash_interval)
	var direction_to_target := global_position.direction_to(target.global_position)
	dash_direction = direction_to_target if direction_to_target != Vector2.ZERO else Vector2.RIGHT
	dash_windup_remaining = max(dash_windup_duration, 0.18)
	_spawn_status_burst(Color(1.0, 0.88, 0.32, 0.24), 28.0 + scale.x * 6.0)

func _update_boss_trait(delta: float) -> void:
	_ensure_boss_helpers()
	boss_battle_elapsed += delta
	var next_phase := _get_boss_phase()
	if next_phase != boss_phase:
		boss_phase = next_phase
		_spawn_status_burst(Color(1.0, 0.84, 0.42, 0.24), 54.0 + scale.x * 12.0)

	var radial_interval := 0.74
	var radial_count := 16
	var sine_interval := 2.9
	var sine_count := 12
	if boss_phase == 2:
		radial_interval = 0.6
		radial_count = 18
		sine_interval = 2.15
		sine_count = 18
	elif boss_phase >= 3:
		radial_interval = 0.48
		radial_count = 20
		sine_interval = 1.95
		sine_count = 16

	boss_radial_timer -= delta
	if boss_radial_timer <= 0.0:
		boss_radial_timer += radial_interval
		_fire_boss_radial_burst(radial_count)

	boss_sine_cooldown -= delta
	if boss_sine_cooldown <= 0.0:
		boss_sine_cooldown += sine_interval
		_fire_boss_quarter_sine_ring(sine_count)

	if boss_phase >= 2:
		boss_split_timer -= delta
		if boss_split_timer <= 0.0:
			boss_split_timer += 5.4 if boss_phase == 2 else 4.2
			_fire_boss_recall_split()

		boss_laser_timer -= delta
		if boss_laser_timer <= 0.0 and boss_laser_remaining <= 0.0:
			boss_laser_timer += 8.0 if boss_phase == 2 else 6.4
			_start_boss_laser_sweep()

	_update_boss_lasers(delta)

	if boss_phase >= 3:
		boss_orbit_bomb_timer -= delta
		if boss_orbit_bomb_timer <= 0.0 and boss_orbit_bomb_remaining <= 0.0:
			boss_orbit_bomb_timer += 9.8
			_start_boss_orbit_bomb()

		boss_peacock_timer -= delta
		if boss_peacock_timer <= 0.0 and boss_peacock_charge_remaining <= 0.0:
			boss_peacock_timer += 8.2
			_start_boss_peacock_attack()

	_update_boss_orbit_bomb(delta)
	_update_boss_peacock_attack(delta)

func _fire_boss_radial_burst(count: int = -1) -> void:
	var bullet_count: int = max(10, count if count > 0 else boss_radial_bullets)
	var base_angle := boss_pattern_rotation
	for index in range(bullet_count):
		var shot_angle := base_angle + TAU * float(index) / float(bullet_count)
		var shot_direction := Vector2.RIGHT.rotated(shot_angle)
		_spawn_projectile(
			global_position + shot_direction * (28.0 + scale.x * 5.0),
			shot_direction,
			255.0 + float(boss_phase - 1) * 12.0,
			projectile_damage * (0.78 + float(boss_phase - 1) * 0.08),
			5.0,
			Color(1.0, 0.38, 0.12, 1.0),
			"straight",
			{"size_scale": 1.15}
		)
	boss_pattern_rotation = wrapf(boss_pattern_rotation + 0.16, 0.0, TAU)
	_spawn_status_burst(Color(1.0, 0.44, 0.16, 0.16), 34.0 + scale.x * 8.0)

func _fire_boss_quarter_sine_ring(count: int = 12) -> void:
	var bullet_count: int = max(8, count)
	var base_angle: float = boss_pattern_rotation * 0.72 + PI * 0.08
	for index in range(bullet_count):
		var shot_angle: float = base_angle + TAU * float(index) / float(bullet_count)
		var shot_direction: Vector2 = Vector2.RIGHT.rotated(shot_angle)
		var side: float = -1.0 if index % 2 == 0 else 1.0
		_spawn_projectile(
			global_position + shot_direction * (28.0 + scale.x * 4.0),
			shot_direction,
			210.0 + float(boss_phase - 1) * 8.0,
			projectile_damage * 0.72,
			5.0,
			Color(0.24, 0.92, 1.0, 1.0),
			"quarter_sine",
			{
				"sine_amplitude": 54.0,
				"quarter_sine_distance": 165.0,
				"quarter_sine_side": side,
				"size_scale": 1.3
			}
		)
	boss_turning_sign *= -1.0
	_spawn_status_burst(Color(0.24, 0.92, 1.0, 0.18), 40.0 + scale.x * 8.0)

func _fire_boss_recall_split() -> void:
	var seed_count := 10 if boss_phase == 2 else 12
	var start_angle := boss_pattern_rotation * 0.5
	for index in range(seed_count):
		var shot_angle := start_angle + TAU * float(index) / float(seed_count)
		var shot_direction := Vector2.RIGHT.rotated(shot_angle)
		_spawn_projectile(
			global_position + shot_direction * (24.0 + scale.x * 5.0),
			shot_direction,
			175.0,
			projectile_damage * 0.65,
			3.4,
			Color(0.32, 0.98, 1.0, 1.0),
			"returning_sine",
			{
				"sine_amplitude": 46.0,
				"sine_frequency": 1.35,
				"quarter_sine_distance": 220.0 if boss_phase == 2 else 240.0,
				"quarter_sine_side": -1.0 if index % 2 == 0 else 1.0,
				"return_after": 1.28 if boss_phase == 2 else 1.15,
				"return_speed": 340.0,
				"return_target_x": global_position.x,
				"return_target_y": global_position.y,
				"split_on_return": true,
				"split_count": 6 if boss_phase == 2 else 8,
				"split_speed": 215.0,
				"split_damage_scale": 0.45,
				"split_lifetime": 3.8,
				"split_motion_mode": "quarter_sine",
				"size_scale": 1.45
			}
		)
	_spawn_status_burst(Color(0.46, 1.0, 1.0, 0.22), 46.0 + scale.x * 8.0)

func _start_boss_laser_sweep() -> void:
	boss_laser_remaining = boss_laser_duration
	boss_laser_hit_timer = 0.0
	boss_laser_start_rotation = global_position.angle_to_point(target.global_position) if target != null and is_instance_valid(target) else boss_pattern_rotation
	boss_laser_final_rotation = boss_laser_start_rotation - 0.52
	boss_laser_rotation = boss_laser_start_rotation
	_spawn_status_burst(Color(1.0, 0.7, 0.24, 0.2), 50.0 + scale.x * 10.0)

func _update_boss_lasers(delta: float) -> void:
	if boss_laser_remaining <= 0.0:
		for laser in boss_laser_lines:
			laser.visible = false
		for laser_core in boss_laser_core_lines:
			laser_core.visible = false
		return

	boss_laser_remaining = max(0.0, boss_laser_remaining - delta)
	boss_laser_hit_timer = max(0.0, boss_laser_hit_timer - delta)
	var elapsed: float = boss_laser_duration - boss_laser_remaining
	if elapsed < boss_laser_spin_duration:
		var spin_ratio: float = clamp(elapsed / max(boss_laser_spin_duration, 0.001), 0.0, 1.0)
		boss_laser_rotation = lerpf(boss_laser_start_rotation, boss_laser_final_rotation, spin_ratio)
	else:
		boss_laser_rotation = boss_laser_final_rotation

	for index in range(boss_laser_lines.size()):
		var angle := boss_laser_rotation + TAU * float(index) / float(max(1, boss_laser_lines.size()))
		var laser_direction := Vector2.RIGHT.rotated(angle)
		var start_point := laser_direction * (18.0 + scale.x * 3.0)
		var end_point := start_point + laser_direction * BOSS_LASER_LENGTH
		var alpha := 0.32 + 0.08 * sin(status_visual_time * 9.0 + float(index))

		var outer := boss_laser_lines[index]
		outer.visible = true
		outer.points = PackedVector2Array([start_point, end_point])
		outer.default_color = Color(1.0, 0.44, 0.12, alpha)

		var core := boss_laser_core_lines[index]
		core.visible = true
		core.points = PackedVector2Array([start_point, end_point])
		core.default_color = Color(1.0, 0.92, 0.58, min(1.0, alpha + 0.4))

		if boss_laser_hit_timer <= 0.0 and target != null and is_instance_valid(target):
			var distance_to_beam := Geometry2D.get_closest_point_to_segment(target.global_position, global_position + start_point, global_position + end_point).distance_to(target.global_position)
			if distance_to_beam <= 22.0 and target.has_method("take_damage"):
				target.take_damage(projectile_damage * 0.62)
				boss_laser_hit_timer = 0.16

func _start_boss_orbit_bomb() -> void:
	boss_orbit_bomb_remaining = 3.4
	boss_orbit_bomb_angle = boss_pattern_rotation
	boss_orbit_bomb_shot_timer = 0.0
	_ensure_boss_orbit_ball()
	_spawn_status_burst(Color(1.0, 0.8, 0.34, 0.22), 42.0 + scale.x * 8.0)

func _update_boss_orbit_bomb(delta: float) -> void:
	if boss_orbit_bomb_remaining <= 0.0:
		_clear_boss_orbit_ball()
		return

	_ensure_boss_orbit_ball()
	boss_orbit_bomb_remaining = max(0.0, boss_orbit_bomb_remaining - delta)
	boss_orbit_bomb_angle = wrapf(boss_orbit_bomb_angle + 2.35 * delta, 0.0, TAU)
	var orbit_offset := Vector2.RIGHT.rotated(boss_orbit_bomb_angle) * (116.0 + 8.0 * sin(status_visual_time * 4.0))
	if boss_orbit_ball != null:
		boss_orbit_ball.position = orbit_offset
		boss_orbit_ball.rotation = -status_visual_time * 1.8

	boss_orbit_bomb_shot_timer -= delta
	while boss_orbit_bomb_shot_timer <= 0.0 and boss_orbit_bomb_remaining > 0.0:
		boss_orbit_bomb_shot_timer += 0.2
		var shot_angle := randf() * TAU
		var shot_direction := Vector2.RIGHT.rotated(shot_angle)
		var origin := global_position + orbit_offset
		_spawn_projectile(origin, shot_direction, 215.0, projectile_damage * 0.5, 4.2, Color(1.0, 0.76, 0.3, 1.0), "straight", {"size_scale": 0.86})

	if boss_orbit_bomb_remaining <= 0.0:
		var burst_origin := global_position + orbit_offset
		for index in range(26):
			var burst_angle := TAU * float(index) / 26.0
			var burst_direction := Vector2.RIGHT.rotated(burst_angle)
			_spawn_projectile(burst_origin, burst_direction, 250.0, projectile_damage * 0.66, 4.4, Color(1.0, 0.86, 0.52, 1.0), "straight", {"size_scale": 1.0})
		_spawn_status_burst(Color(1.0, 0.84, 0.46, 0.22), 58.0)
		_clear_boss_orbit_ball()

func _start_boss_peacock_attack() -> void:
	boss_peacock_charge_remaining = 0.78
	_ensure_boss_peacock_markers(7)
	_spawn_status_burst(Color(0.98, 0.86, 0.42, 0.2), 48.0 + scale.x * 8.0)

func _update_boss_peacock_attack(delta: float) -> void:
	if boss_peacock_charge_remaining <= 0.0:
		if not boss_peacock_markers.is_empty():
			_clear_boss_peacock_markers()
		return

	_ensure_boss_peacock_markers(7)
	boss_peacock_charge_remaining = max(0.0, boss_peacock_charge_remaining - delta)
	var aim_direction := global_position.direction_to(target.global_position) if target != null and is_instance_valid(target) else Vector2.RIGHT
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	var base_angle := aim_direction.angle()
	var spread: float = 1.1
	var center_offset: float = float(boss_peacock_markers.size() - 1) * 0.5
	for index in range(boss_peacock_markers.size()):
		var marker := boss_peacock_markers[index]
		var offset_ratio: float = (float(index) - center_offset) / max(1.0, center_offset)
		var angle: float = base_angle + offset_ratio * spread * 0.5
		var distance: float = lerpf(58.0, 118.0, abs(offset_ratio))
		marker.position = Vector2.RIGHT.rotated(angle) * distance
		marker.rotation = status_visual_time * 1.8 + float(index) * 0.2
		marker.modulate.a = 0.42 + 0.4 * (1.0 - boss_peacock_charge_remaining / 0.78)

	if boss_peacock_charge_remaining <= 0.0:
		var bullet_count: int = 17
		var row_count: int = 3
		for row in range(row_count):
			var row_ratio: float = float(row) / float(max(1, row_count - 1))
			var row_speed: float = 210.0 + row_ratio * 50.0
			var row_damage: float = projectile_damage * (0.72 + row_ratio * 0.18)
			var row_distance: float = 16.0 + row * 12.0
			for index in range(bullet_count):
				var offset: float = (float(index) - float(bullet_count - 1) * 0.5) * (1.34 / float(max(1, bullet_count - 1)))
				var shot_direction := aim_direction.rotated(offset)
				_spawn_projectile(
					global_position + shot_direction * (row_distance + scale.x * 4.0),
					shot_direction,
					row_speed,
					row_damage,
					5.2,
					Color(1.0, 0.82, 0.4, 1.0),
					"turning",
					{
						"turn_start_delay": 0.24 + row_ratio * 0.08,
						"turn_interval": 0.16,
						"turn_angle_step": 0.08,
						"turn_direction_sign": -1.0 if index < bullet_count / 2 else 1.0,
						"size_scale": 0.96 + row_ratio * 0.16
					}
				)
		_spawn_status_burst(Color(1.0, 0.86, 0.44, 0.22), 52.0 + scale.x * 8.0)
		_clear_boss_peacock_markers()

func has_trait(trait_id: String) -> bool:
	return behavior_id == trait_id or secondary_behavior_id == trait_id

func _fire_shooter_pattern() -> void:
	if target == null or not is_instance_valid(target):
		return
	var aim_direction := global_position.direction_to(target.global_position)
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	var start_position := global_position + aim_direction * (22.0 + scale.x * 4.0)
	var count: int = max(1, projectile_count)
	var spread_step := projectile_spread
	var offset_center := float(count - 1) * 0.5
	for index in range(count):
		var shot_direction := aim_direction.rotated((float(index) - offset_center) * spread_step)
		_spawn_projectile(start_position, shot_direction, projectile_speed, projectile_damage, projectile_lifetime, _get_projectile_color(), "straight")
	_spawn_status_burst(Color(_get_projectile_color().r, _get_projectile_color().g, _get_projectile_color().b, 0.18), 16.0 + scale.x * 4.0)

func _spawn_projectile(origin: Vector2, shot_direction: Vector2, shot_speed: float, shot_damage: float, shot_lifetime: float, color: Color, mode: String, extra_config: Dictionary = {}) -> void:
	if projectile_scene == null:
		return
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var projectile = projectile_scene.instantiate()
	if projectile == null:
		return
	projectile.global_position = origin
	projectile.direction = shot_direction.normalized()
	projectile.speed = shot_speed
	projectile.damage = shot_damage
	projectile.lifetime = shot_lifetime
	projectile.visual_color = color
	projectile.motion_mode = mode
	projectile.target = target
	for key in extra_config.keys():
		projectile.set(key, extra_config[key])
	current_scene.add_child(projectile)

func _get_projectile_color() -> Color:
	match archetype_id:
		"shooter":
			return Color(0.98, 0.56, 0.32, 1.0)
		"accelerator":
			return Color(1.0, 0.78, 0.38, 1.0)
		"dasher":
			return Color(1.0, 0.42, 0.42, 1.0)
		_:
			return Color(0.95, 0.45, 0.35, 1.0)

func _apply_visuals(color_override = null) -> void:
	var polygon := get_node_or_null("Polygon2D") as Polygon2D
	if polygon == null:
		return

	if color_override is Color:
		display_color = color_override
	elif enemy_kind == "boss":
		display_color = Color(0.95, 0.2, 0.2, 1.0)
	elif enemy_kind == "elite":
		display_color = Color(1.0, 0.58, 0.25, 1.0)
	else:
		match archetype_id:
			"shooter":
				display_color = Color(1.0, 0.52, 0.3, 1.0)
			"accelerator":
				display_color = Color(0.92, 0.76, 0.24, 1.0)
			"swarm":
				display_color = Color(0.78, 0.94, 1.0, 1.0)
			"dasher":
				display_color = Color(1.0, 0.34, 0.42, 1.0)
			_:
				display_color = Color(0.34, 0.8, 1.0, 1.0)

	polygon.color = display_color
	polygon.polygon = _get_shape_points()
	polygon.rotation = 0.0

	if trait_ring != null:
		trait_ring.visible = enemy_kind != "normal" or secondary_behavior_id != ""
		trait_ring.points = _build_circle_points(18.0 + scale.x * 4.0)
		if enemy_kind == "boss":
			trait_ring.default_color = Color(1.0, 0.54, 0.4, 0.72)
			trait_ring.width = 5.0
		elif enemy_kind == "elite":
			trait_ring.default_color = _get_trait_ring_color()
			trait_ring.width = 4.0
		else:
			trait_ring.default_color = Color(display_color.r, display_color.g, display_color.b, 0.46)
			trait_ring.width = 3.0

	if dash_warning_ring != null:
		dash_warning_ring.points = _build_circle_points(24.0 + scale.x * 10.0)

func _get_shape_points() -> PackedVector2Array:
	match behavior_id:
		"shooter":
			return PackedVector2Array([
				Vector2(0.0, -18.0),
				Vector2(16.0, 0.0),
				Vector2(0.0, 18.0),
				Vector2(-16.0, 0.0)
			])
		"accelerator":
			return PackedVector2Array([
				Vector2(0.0, -18.0),
				Vector2(15.0, -9.0),
				Vector2(15.0, 9.0),
				Vector2(0.0, 18.0),
				Vector2(-15.0, 9.0),
				Vector2(-15.0, -9.0)
			])
		"swarm":
			return PackedVector2Array([
				Vector2(0.0, -16.0),
				Vector2(14.0, 14.0),
				Vector2(-14.0, 14.0)
			])
		"dash":
			return PackedVector2Array([
				Vector2(0.0, -20.0),
				Vector2(18.0, -2.0),
				Vector2(8.0, 18.0),
				Vector2(-8.0, 18.0),
				Vector2(-18.0, -2.0)
			])
		"boss":
			return PackedVector2Array([
				Vector2(0.0, -24.0),
				Vector2(18.0, -16.0),
				Vector2(24.0, 0.0),
				Vector2(18.0, 16.0),
				Vector2(0.0, 24.0),
				Vector2(-18.0, 16.0),
				Vector2(-24.0, 0.0),
				Vector2(-18.0, -16.0)
			])
		_:
			return PackedVector2Array([
				Vector2(14.0, 14.0),
				Vector2(-14.0, 14.0),
				Vector2(-14.0, -14.0),
				Vector2(14.0, -14.0)
			])

func _get_trait_ring_color() -> Color:
	if secondary_behavior_id == "dash":
		return Color(1.0, 0.46, 0.46, 0.7)
	if secondary_behavior_id == "shooter":
		return Color(1.0, 0.68, 0.34, 0.7)
	if secondary_behavior_id == "accelerator":
		return Color(1.0, 0.82, 0.36, 0.7)
	return Color(1.0, 0.9, 0.52, 0.64)

func _update_status_timers(delta: float) -> void:
	if slow_timer > 0.0:
		slow_timer = max(0.0, slow_timer - delta)
		if slow_timer == 0.0:
			slow_multiplier = 1.0

	if vulnerability_timer > 0.0:
		vulnerability_timer = max(0.0, vulnerability_timer - delta)
		if vulnerability_timer == 0.0:
			vulnerability_bonus = 0.0

	if bleed_timer > 0.0:
		bleed_timer = max(0.0, bleed_timer - delta)
		if bleed_timer == 0.0:
			bleed_damage_per_second = 0.0

func _update_bleed(delta: float) -> void:
	if bleed_timer <= 0.0 or bleed_damage_per_second <= 0.0:
		return

	var bleed_damage: float = bleed_damage_per_second * delta
	if bleed_damage > 0.0:
		take_damage(bleed_damage)

func take_damage(amount: float) -> bool:
	var adjusted_damage: float = amount * (1.0 + vulnerability_bonus)
	current_health -= adjusted_damage
	_play_hit_feedback(adjusted_damage, current_health <= 0.0)
	if current_health <= 0.0:
		defeated.emit(enemy_kind)
		_drop_experience_gem()
		_maybe_drop_heart()
		queue_free()
		return true

	return false

func apply_slow(multiplier: float, duration: float) -> void:
	slow_multiplier = min(slow_multiplier, clamp(multiplier, 0.2, 1.0))
	slow_timer = max(slow_timer, duration)
	_spawn_status_burst(Color(0.56, 0.92, 1.0, 0.28), 22.0)

func apply_vulnerability(bonus: float, duration: float) -> void:
	vulnerability_bonus = max(vulnerability_bonus, bonus)
	vulnerability_timer = max(vulnerability_timer, duration)
	_spawn_status_burst(Color(1.0, 0.46, 0.36, 0.24), 18.0)

func apply_bleed(damage_per_second: float, duration: float) -> void:
	bleed_damage_per_second = max(bleed_damage_per_second, damage_per_second)
	bleed_timer = max(bleed_timer, duration)

func _ensure_status_visuals() -> void:
	if status_root != null:
		return

	status_root = Node2D.new()
	status_root.name = "StatusRoot"
	add_child(status_root)

	slow_ring = Line2D.new()
	slow_ring.width = 4.0
	slow_ring.default_color = Color(0.56, 0.92, 1.0, 0.0)
	slow_ring.closed = true
	slow_ring.points = _build_circle_points(24.0)
	status_root.add_child(slow_ring)

	vulnerability_ring = Line2D.new()
	vulnerability_ring.width = 3.0
	vulnerability_ring.default_color = Color(1.0, 0.48, 0.38, 0.0)
	vulnerability_ring.closed = true
	vulnerability_ring.points = _build_circle_points(30.0)
	status_root.add_child(vulnerability_ring)

	trait_ring = Line2D.new()
	trait_ring.width = 3.0
	trait_ring.default_color = Color(1.0, 1.0, 1.0, 0.0)
	trait_ring.closed = true
	trait_ring.points = _build_circle_points(20.0)
	status_root.add_child(trait_ring)

	dash_warning_ring = Line2D.new()
	dash_warning_ring.width = 4.0
	dash_warning_ring.default_color = Color(1.0, 0.88, 0.28, 0.0)
	dash_warning_ring.closed = true
	dash_warning_ring.points = _build_circle_points(34.0)
	dash_warning_ring.visible = false
	status_root.add_child(dash_warning_ring)

func _update_status_visuals() -> void:
	var polygon := get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null:
		var target_modulate := Color.WHITE
		if slow_timer > 0.0:
			target_modulate = target_modulate.lerp(Color(0.68, 0.9, 1.0, 1.0), 0.45)
		if vulnerability_timer > 0.0:
			target_modulate = target_modulate.lerp(Color(1.0, 0.76, 0.76, 1.0), 0.4)
		if has_trait("accelerator") and acceleration_remaining > 0.0:
			target_modulate = target_modulate.lerp(Color(1.0, 0.88, 0.64, 1.0), 0.32)
		if has_trait("dash") and dash_windup_remaining > 0.0:
			target_modulate = target_modulate.lerp(Color(1.0, 0.92, 0.56, 1.0), 0.46)
		if has_trait("dash") and dash_remaining > 0.0:
			target_modulate = target_modulate.lerp(Color(1.0, 0.72, 0.72, 1.0), 0.32)
		polygon.modulate = polygon.modulate.lerp(target_modulate, 0.18)

	if slow_ring != null:
		slow_ring.visible = slow_timer > 0.0
		slow_ring.rotation = status_visual_time * 2.1
		slow_ring.scale = Vector2.ONE * (1.0 + 0.08 * sin(status_visual_time * 6.0))
		slow_ring.default_color = Color(0.56, 0.92, 1.0, 0.72 if slow_timer > 0.0 else 0.0)

	if vulnerability_ring != null:
		vulnerability_ring.visible = vulnerability_timer > 0.0
		vulnerability_ring.rotation = -status_visual_time * 1.6
		vulnerability_ring.scale = Vector2.ONE * (1.0 + 0.05 * cos(status_visual_time * 5.0))
		vulnerability_ring.default_color = Color(1.0, 0.46, 0.36, 0.68 if vulnerability_timer > 0.0 else 0.0)

	if trait_ring != null and trait_ring.visible:
		trait_ring.rotation = status_visual_time * 0.8 * (1.0 if enemy_kind == "boss" else -1.0)
		trait_ring.scale = Vector2.ONE * (1.0 + 0.05 * sin(status_visual_time * 4.0))

	if dash_warning_ring != null:
		dash_warning_ring.visible = has_trait("dash") and dash_windup_remaining > 0.0
		if dash_warning_ring.visible:
			var windup_ratio: float = clamp(dash_windup_remaining / max(dash_windup_duration, 0.001), 0.0, 1.0)
			dash_warning_ring.rotation = -status_visual_time * 2.4
			dash_warning_ring.scale = Vector2.ONE * lerpf(0.72, 1.5, windup_ratio)
			dash_warning_ring.width = lerpf(5.0, 2.0, windup_ratio)
			dash_warning_ring.default_color = Color(1.0, 0.9, 0.28, lerpf(0.9, 0.3, windup_ratio))

func _spawn_status_burst(color: Color, radius: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var ring := Line2D.new()
	ring.global_position = global_position
	ring.width = 5.0
	ring.default_color = color
	ring.closed = true
	ring.points = _build_circle_points(radius)
	ring.z_index = 16
	current_scene.add_child(ring)

	var tween := ring.create_tween()
	tween.parallel().tween_property(ring, "scale", Vector2(1.35, 1.35), 0.18)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	tween.tween_callback(ring.queue_free)

func _spawn_dash_trail(direction_vector: Vector2, length: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var trail := Line2D.new()
	trail.width = 8.0
	trail.default_color = Color(1.0, 0.46, 0.46, 0.28 if enemy_kind != "boss" else 0.38)
	trail.points = PackedVector2Array([
		global_position - direction_vector * length * 0.2,
		global_position + direction_vector * length
	])
	trail.z_index = 13
	current_scene.add_child(trail)

	var tween := trail.create_tween()
	tween.parallel().tween_property(trail, "modulate:a", 0.0, 0.16)
	tween.parallel().tween_property(trail, "width", 2.0, 0.16)
	tween.tween_callback(trail.queue_free)

func _build_circle_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments := 20
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _drop_experience_gem() -> void:
	if exp_gem_scene == null:
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var gem = exp_gem_scene.instantiate()
	if gem == null:
		return

	current_scene.add_child(gem)
	gem.global_position = global_position
	if gem.has_method("configure"):
		gem.configure(reward_tier, experience_reward)
	else:
		gem.value = experience_reward

func _maybe_drop_heart() -> void:
	if heart_pickup_scene == null:
		return

	var drop_chance := HEART_DROP_CHANCE
	if enemy_kind == "elite":
		drop_chance = HEART_DROP_CHANCE_ELITE
	elif enemy_kind == "boss":
		drop_chance = HEART_DROP_CHANCE_BOSS

	if randf() > drop_chance:
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var heart_pickup = heart_pickup_scene.instantiate()
	if heart_pickup == null:
		return

	current_scene.add_child(heart_pickup)
	heart_pickup.global_position = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))

func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"enemy_kind": enemy_kind,
		"archetype_id": archetype_id,
		"behavior_id": behavior_id,
		"secondary_behavior_id": secondary_behavior_id,
		"max_health": max_health,
		"current_health": current_health,
		"speed": speed,
		"touch_damage": touch_damage,
		"contact_radius": contact_radius,
		"experience_reward": experience_reward,
		"reward_tier": reward_tier,
		"scale_x": scale.x,
		"scale_y": scale.y,
		"display_color": [display_color.r, display_color.g, display_color.b, display_color.a],
		"slow_multiplier": slow_multiplier,
		"slow_timer": slow_timer,
		"vulnerability_bonus": vulnerability_bonus,
		"vulnerability_timer": vulnerability_timer,
		"bleed_damage_per_second": bleed_damage_per_second,
		"bleed_timer": bleed_timer,
		"preferred_distance": preferred_distance,
		"shot_interval": shot_interval,
		"shot_timer": shot_timer,
		"projectile_speed": projectile_speed,
		"projectile_damage": projectile_damage,
		"projectile_lifetime": projectile_lifetime,
		"projectile_spread": projectile_spread,
		"projectile_count": projectile_count,
		"acceleration_interval": acceleration_interval,
		"acceleration_boost": acceleration_boost,
		"acceleration_duration": acceleration_duration,
		"acceleration_timer": acceleration_timer,
		"acceleration_remaining": acceleration_remaining,
		"dash_interval": dash_interval,
		"dash_duration": dash_duration,
		"dash_speed_multiplier": dash_speed_multiplier,
		"dash_windup_duration": dash_windup_duration,
		"dash_timer": dash_timer,
		"dash_windup_remaining": dash_windup_remaining,
		"dash_remaining": dash_remaining,
		"dash_direction": [dash_direction.x, dash_direction.y],
		"strafe_sign": strafe_sign,
		"boss_radial_interval": boss_radial_interval,
		"boss_radial_timer": boss_radial_timer,
		"boss_radial_bullets": boss_radial_bullets,
		"boss_sine_interval": boss_sine_interval,
		"boss_sine_cooldown": boss_sine_cooldown,
		"boss_sine_stream_duration": boss_sine_stream_duration,
		"boss_sine_stream_remaining": boss_sine_stream_remaining,
		"boss_sine_stream_rate": boss_sine_stream_rate,
		"boss_sine_stream_timer": boss_sine_stream_timer,
		"boss_turning_interval": boss_turning_interval,
		"boss_turning_timer": boss_turning_timer,
		"boss_turning_bullets": boss_turning_bullets,
		"boss_turning_sign": boss_turning_sign,
		"boss_orbit_sign": boss_orbit_sign,
		"boss_pattern_rotation": boss_pattern_rotation,
		"boss_display_name": boss_display_name,
		"boss_battle_elapsed": boss_battle_elapsed,
		"boss_phase": boss_phase,
		"boss_split_timer": boss_split_timer,
		"boss_laser_timer": boss_laser_timer,
		"boss_laser_remaining": boss_laser_remaining,
		"boss_laser_rotation": boss_laser_rotation,
		"boss_laser_start_rotation": boss_laser_start_rotation,
		"boss_laser_final_rotation": boss_laser_final_rotation,
		"boss_laser_hit_timer": boss_laser_hit_timer,
		"boss_orbit_bomb_timer": boss_orbit_bomb_timer,
		"boss_orbit_bomb_remaining": boss_orbit_bomb_remaining,
		"boss_orbit_bomb_angle": boss_orbit_bomb_angle,
		"boss_orbit_bomb_shot_timer": boss_orbit_bomb_shot_timer,
		"boss_peacock_timer": boss_peacock_timer,
		"boss_peacock_charge_remaining": boss_peacock_charge_remaining
	}

func apply_save_data(data: Dictionary, target_node: Node2D) -> void:
	var position_data = data.get("position", [0.0, 0.0])
	if position_data.size() >= 2:
		global_position = Vector2(float(position_data[0]), float(position_data[1]))

	enemy_kind = str(data.get("enemy_kind", "normal"))
	archetype_id = str(data.get("archetype_id", "chaser"))
	behavior_id = str(data.get("behavior_id", archetype_id))
	secondary_behavior_id = str(data.get("secondary_behavior_id", ""))
	max_health = float(data.get("max_health", max_health))
	current_health = float(data.get("current_health", max_health))
	speed = float(data.get("speed", speed))
	touch_damage = float(data.get("touch_damage", touch_damage))
	contact_radius = float(data.get("contact_radius", contact_radius))
	experience_reward = int(data.get("experience_reward", experience_reward))
	reward_tier = clamp(int(data.get("reward_tier", reward_tier)), 1, 4)
	scale = Vector2(float(data.get("scale_x", 1.0)), float(data.get("scale_y", 1.0)))

	var color_data = data.get("display_color", [display_color.r, display_color.g, display_color.b, display_color.a])
	if color_data.size() >= 4:
		display_color = Color(float(color_data[0]), float(color_data[1]), float(color_data[2]), float(color_data[3]))

	slow_multiplier = float(data.get("slow_multiplier", 1.0))
	slow_timer = float(data.get("slow_timer", 0.0))
	vulnerability_bonus = float(data.get("vulnerability_bonus", 0.0))
	vulnerability_timer = float(data.get("vulnerability_timer", 0.0))
	bleed_damage_per_second = float(data.get("bleed_damage_per_second", 0.0))
	bleed_timer = float(data.get("bleed_timer", 0.0))

	preferred_distance = float(data.get("preferred_distance", preferred_distance))
	shot_interval = float(data.get("shot_interval", shot_interval))
	shot_timer = float(data.get("shot_timer", shot_interval))
	projectile_speed = float(data.get("projectile_speed", projectile_speed))
	projectile_damage = float(data.get("projectile_damage", projectile_damage))
	projectile_lifetime = float(data.get("projectile_lifetime", projectile_lifetime))
	projectile_spread = float(data.get("projectile_spread", projectile_spread))
	projectile_count = int(data.get("projectile_count", projectile_count))

	acceleration_interval = float(data.get("acceleration_interval", acceleration_interval))
	acceleration_boost = float(data.get("acceleration_boost", acceleration_boost))
	acceleration_duration = float(data.get("acceleration_duration", acceleration_duration))
	acceleration_timer = float(data.get("acceleration_timer", acceleration_interval))
	acceleration_remaining = float(data.get("acceleration_remaining", 0.0))

	dash_interval = float(data.get("dash_interval", dash_interval))
	dash_duration = float(data.get("dash_duration", dash_duration))
	dash_speed_multiplier = float(data.get("dash_speed_multiplier", dash_speed_multiplier))
	dash_windup_duration = float(data.get("dash_windup_duration", dash_windup_duration))
	dash_timer = float(data.get("dash_timer", dash_interval))
	dash_windup_remaining = float(data.get("dash_windup_remaining", 0.0))
	dash_remaining = float(data.get("dash_remaining", 0.0))
	var dash_direction_data = data.get("dash_direction", [1.0, 0.0])
	if dash_direction_data.size() >= 2:
		dash_direction = Vector2(float(dash_direction_data[0]), float(dash_direction_data[1])).normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2.RIGHT

	strafe_sign = float(data.get("strafe_sign", 1.0))
	boss_radial_interval = float(data.get("boss_radial_interval", boss_radial_interval))
	boss_radial_timer = float(data.get("boss_radial_timer", boss_radial_interval))
	boss_radial_bullets = int(data.get("boss_radial_bullets", boss_radial_bullets))
	boss_sine_interval = float(data.get("boss_sine_interval", boss_sine_interval))
	boss_sine_cooldown = float(data.get("boss_sine_cooldown", boss_sine_interval))
	boss_sine_stream_duration = float(data.get("boss_sine_stream_duration", boss_sine_stream_duration))
	boss_sine_stream_remaining = float(data.get("boss_sine_stream_remaining", 0.0))
	boss_sine_stream_rate = float(data.get("boss_sine_stream_rate", boss_sine_stream_rate))
	boss_sine_stream_timer = float(data.get("boss_sine_stream_timer", 0.0))
	boss_turning_interval = float(data.get("boss_turning_interval", boss_turning_interval))
	boss_turning_timer = float(data.get("boss_turning_timer", boss_turning_interval))
	boss_turning_bullets = int(data.get("boss_turning_bullets", boss_turning_bullets))
	boss_turning_sign = float(data.get("boss_turning_sign", 1.0))
	boss_orbit_sign = float(data.get("boss_orbit_sign", 1.0))
	boss_pattern_rotation = float(data.get("boss_pattern_rotation", 0.0))
	boss_display_name = str(data.get("boss_display_name", boss_display_name))
	boss_battle_elapsed = float(data.get("boss_battle_elapsed", 0.0))
	boss_phase = int(data.get("boss_phase", _get_boss_phase()))
	boss_split_timer = float(data.get("boss_split_timer", boss_split_interval))
	boss_laser_timer = float(data.get("boss_laser_timer", boss_laser_interval))
	boss_laser_remaining = float(data.get("boss_laser_remaining", 0.0))
	boss_laser_rotation = float(data.get("boss_laser_rotation", 0.0))
	boss_laser_start_rotation = float(data.get("boss_laser_start_rotation", boss_laser_rotation))
	boss_laser_final_rotation = float(data.get("boss_laser_final_rotation", boss_laser_rotation))
	boss_laser_hit_timer = float(data.get("boss_laser_hit_timer", 0.0))
	boss_orbit_bomb_timer = float(data.get("boss_orbit_bomb_timer", boss_orbit_bomb_interval))
	boss_orbit_bomb_remaining = float(data.get("boss_orbit_bomb_remaining", 0.0))
	boss_orbit_bomb_angle = float(data.get("boss_orbit_bomb_angle", 0.0))
	boss_orbit_bomb_shot_timer = float(data.get("boss_orbit_bomb_shot_timer", 0.0))
	boss_peacock_timer = float(data.get("boss_peacock_timer", boss_peacock_interval))
	boss_peacock_charge_remaining = float(data.get("boss_peacock_charge_remaining", 0.0))

	target = target_node
	profile_initialized = true
	_ensure_status_visuals()
	_apply_visuals(display_color)
	if enemy_kind == "boss":
		_ensure_boss_helpers()
		if boss_orbit_bomb_remaining > 0.0:
			_ensure_boss_orbit_ball()
		if boss_peacock_charge_remaining > 0.0:
			_ensure_boss_peacock_markers(7)

func _play_hit_feedback(damage_amount: float, killed: bool) -> void:
	var polygon := get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null:
		polygon.modulate = Color(1.0, 1.0, 1.0, 1.0)
		var tween := create_tween()
		tween.tween_property(polygon, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.02)
		tween.tween_property(polygon, "modulate", Color(1.0, 1.0, 1.0, 0.78), 0.05)
		tween.tween_property(polygon, "modulate", Color.WHITE, 0.08)

	_show_damage_number(damage_amount, killed)
	if killed:
		_spawn_death_burst()

func _show_damage_number(damage_amount: float, killed: bool) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var label := Label.new()
	label.text = str(int(round(damage_amount)))
	var label_color: Color = Color(1.0, 1.0, 1.0, 0.95)
	var label_font_size: int = 15
	if killed:
		label_color = Color(1.0, 0.95, 0.75, 1.0)
		label_font_size = 18
	label.modulate = label_color
	label.add_theme_font_size_override("font_size", label_font_size)
	label.z_index = 20
	current_scene.add_child(label)
	label.global_position = global_position + Vector2(-10.0, -28.0)

	var target_position := label.global_position + Vector2(randf_range(-10.0, 10.0), -28.0)
	var tween := label.create_tween()
	tween.parallel().tween_property(label, "global_position", target_position, 0.38)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.38)
	tween.tween_callback(label.queue_free)

func _spawn_death_burst() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var burst := Polygon2D.new()
	burst.global_position = global_position
	burst.z_index = 14
	burst.color = Color(1.0, 0.88, 0.65, 0.75)
	burst.polygon = PackedVector2Array([
		Vector2(0.0, -18.0),
		Vector2(18.0, 0.0),
		Vector2(0.0, 18.0),
		Vector2(-18.0, 0.0)
	])
	current_scene.add_child(burst)

	burst.scale = Vector2(0.25, 0.25)
	var tween := burst.create_tween()
	tween.parallel().tween_property(burst, "scale", Vector2(1.2, 1.2), 0.16)
	tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.16)
	tween.tween_callback(burst.queue_free)

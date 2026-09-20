extends RefCounted

const DANMAKU := preload("res://scripts/enemies/enemy_boss_danmaku.gd")
const BOSS_PROJECTILE_SPEED_SCALE := 0.588
const BOSS_PROJECTILE_LIFETIME_SCALE := 1.5
const BOSS_LASER_LENGTH := 980.0
const BOSS_LASER_COLOR := Color(0.70, 0.32, 1.0, 1.0)
const ORBIT_PULL_DURATION := 7.0
const ORBIT_PULL_STRENGTH := 200.0
const ORBIT_ROTATION_SPEED := 0.987
const BOSS_PASSIVE_PULL_STRENGTH := 50.0
const ORBIT_AIMED_BURST_INTERVAL := 2.9
const ORBIT_AIMED_BURST_COUNT := 7
const ORBIT_AIMED_SHOT_INTERVAL := 0.12
const ORBIT_BALL_RADIUS := 232.0
const DANMAKU_WAVES := 6
const DANMAKU_WAVE_INTERVAL := 0.20
const LASER_DAMAGE_INTERVAL := 0.2

static func fire_radial_burst(enemy, count: int = -1) -> void:
	var bullet_count: int = max(10, count if count > 0 else enemy.boss_radial_bullets)
	var base_angle: float = enemy.boss_pattern_rotation + randf_range(-0.08, 0.08)
	for index in range(bullet_count):
		var shot_angle: float = base_angle + TAU * float(index) / float(bullet_count)
		var shot_direction: Vector2 = Vector2.RIGHT.rotated(shot_angle)
		enemy._spawn_projectile(
			enemy.global_position + shot_direction * (28.0 + enemy.scale.x * 5.0),
			shot_direction,
			(255.0 + float(enemy.boss_phase - 1) * 12.0) * BOSS_PROJECTILE_SPEED_SCALE,
			enemy.attack * 0.8,
			10.0,
			Color(0.60, 0.32, 0.96, 1.0),
			"straight",
			{"size_scale": 1.15, "visual_style": "boss_dark_orb"}
		)
	var rotation_step: float = TAU / float(max(1, bullet_count)) * 0.5
	enemy.boss_pattern_rotation = wrapf(base_angle + rotation_step + randf_range(-0.06, 0.06), 0.0, TAU)
	enemy._spawn_status_burst(Color(0.60, 0.32, 0.96, 0.16), 34.0 + enemy.scale.x * 8.0)

static func fire_quarter_sine_ring(enemy, count: int = 12, pattern: int = -1, spin: float = 1.0) -> void:
	# Keep the existing entry point/cooldown; each cast is now a complete
	# six-wave pattern, scheduled in Boss state rather than orphan timers.
	enemy.boss_danmaku_pattern = posmod(pattern, DANMAKU.PATTERN_COUNT) if pattern >= 0 else (enemy.boss_danmaku_pattern + 1) % 3
	enemy.boss_danmaku_spin = spin
	enemy.boss_danmaku_wave = 0
	enemy.boss_danmaku_count = maxi(8, count) * 2
	enemy.boss_danmaku_rotation = enemy.boss_pattern_rotation
	if pattern >= 3 and is_instance_valid(enemy.target):
		enemy.boss_danmaku_rotation = enemy.global_position.angle_to_point(enemy.target.global_position) + sin(enemy.boss_pattern_rotation) * 0.18
	enemy.boss_sine_stream_timer = 0.0
	update_danmaku_stream(enemy, 0.0)
	enemy._spawn_status_burst(Color(0.24, 0.92, 1.0, 0.18), 40.0 + enemy.scale.x * 8.0)

static func update_danmaku_stream(enemy, delta: float) -> void:
	if enemy.boss_danmaku_wave >= DANMAKU_WAVES:
		return
	enemy.boss_sine_stream_timer -= delta
	while enemy.boss_sine_stream_timer <= 0.000001 and enemy.boss_danmaku_wave < DANMAKU_WAVES:
		_fire_danmaku_wave(enemy)
		enemy.boss_danmaku_wave += 1
		enemy.boss_sine_stream_timer += DANMAKU_WAVE_INTERVAL

static func _fire_danmaku_wave(enemy) -> void:
	DANMAKU.fire_wave(enemy)

static func fire_recall_split(enemy) -> void:
	var seed_count: int = 10 if enemy.boss_phase == 2 else 12
	var start_angle: float = enemy.boss_pattern_rotation * 0.5 + randf_range(-0.12, 0.12)
	for index in range(seed_count):
		var shot_angle: float = start_angle + TAU * float(index) / float(seed_count)
		var shot_direction: Vector2 = Vector2.RIGHT.rotated(shot_angle)
		enemy._spawn_projectile(
			enemy.global_position + shot_direction * (24.0 + enemy.scale.x * 5.0),
			shot_direction,
			175.0 * BOSS_PROJECTILE_SPEED_SCALE,
			enemy.projectile_damage * 0.65,
			3.4 * BOSS_PROJECTILE_LIFETIME_SCALE,
			Color(0.16, 0.44, 0.86, 1.0),
			"returning_sine",
			{
				"sine_amplitude": 46.0,
				"sine_frequency": 1.35,
				"quarter_sine_distance": 990.0 if enemy.boss_phase == 2 else 1080.0,
				"quarter_sine_side": -1.0 if index % 2 == 0 else 1.0,
				"return_after": 5.76 if enemy.boss_phase == 2 else 5.175,
				"return_speed": 340.0 * BOSS_PROJECTILE_SPEED_SCALE,
				"return_target_x": enemy.global_position.x,
				"return_target_y": enemy.global_position.y,
				"split_on_return": true,
				"split_count": 6 if enemy.boss_phase == 2 else 8,
				"split_speed": 215.0 * BOSS_PROJECTILE_SPEED_SCALE,
				"split_damage_override": enemy.attack * 0.5,
				"split_lifetime": 7.6,
				"split_motion_mode": "quarter_sine",
				"size_scale": 1.45,
				"visual_style": "boss_dark_core_orb",
				"split_visual_style": "boss_dark_core_orb"
			}
		)
	enemy._spawn_status_burst(Color(0.46, 1.0, 1.0, 0.22), 46.0 + enemy.scale.x * 8.0)

static func start_laser_sweep(enemy, locked_rotation: float = INF) -> void:
	enemy.boss_laser_remaining = enemy.boss_laser_duration
	enemy.boss_laser_hit_timer = 0.0
	enemy.boss_laser_start_rotation = enemy.global_position.angle_to_point(enemy.target.global_position) if enemy.target != null and is_instance_valid(enemy.target) else enemy.boss_pattern_rotation
	if is_finite(locked_rotation):
		enemy.boss_laser_start_rotation = locked_rotation
	enemy.boss_laser_final_rotation = enemy.boss_laser_start_rotation - 0.52
	enemy.boss_laser_rotation = enemy.boss_laser_start_rotation
	enemy._spawn_status_burst(Color(1.0, 0.7, 0.24, 0.2), 50.0 + enemy.scale.x * 10.0)

static func update_laser_warning(enemy, locked_rotation: float) -> void:
	# Mark both edges of the forthcoming sweep; the firing angle stays locked.
	for index in range(enemy.boss_laser_lines.size()):
		var angle: float = locked_rotation + TAU * float(index) / float(enemy.boss_laser_lines.size())
		for edge in range(2):
			var ray = enemy.boss_laser_lines[index] if edge == 0 else enemy.boss_laser_core_lines[index]
			var shot_direction := Vector2.RIGHT.rotated(angle - 0.52 * float(edge))
			var start: Vector2 = shot_direction * (18.0 + enemy.scale.x * 3.0)
			ray.scale = Vector2.ONE / enemy.global_scale
			ray.points = PackedVector2Array([start, start + shot_direction * BOSS_LASER_LENGTH])
			ray.width = 3.0
			ray.default_color = Color(1.0, 0.65, 0.22, 0.55)
			ray.visible = true

static func update_lasers(enemy, delta: float) -> void:
	if enemy.boss_laser_remaining <= 0.0:
		for laser in enemy.boss_laser_lines:
			laser.visible = false
		for laser_core in enemy.boss_laser_core_lines:
			laser_core.visible = false
		return

	var active_delta: float = min(maxf(delta, 0.0), enemy.boss_laser_remaining)
	enemy.boss_laser_remaining = max(0.0, enemy.boss_laser_remaining - active_delta)
	var elapsed: float = enemy.boss_laser_duration - enemy.boss_laser_remaining
	if elapsed < enemy.boss_laser_spin_duration:
		var spin_ratio: float = clamp(elapsed / max(enemy.boss_laser_spin_duration, 0.001), 0.0, 1.0)
		enemy.boss_laser_rotation = lerpf(enemy.boss_laser_start_rotation, enemy.boss_laser_final_rotation, spin_ratio)
	else:
		enemy.boss_laser_rotation = enemy.boss_laser_final_rotation

	var touching_beam := false
	for index in range(enemy.boss_laser_lines.size()):
		var angle: float = enemy.boss_laser_rotation + TAU * float(index) / float(max(1, enemy.boss_laser_lines.size()))
		var laser_direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var start_point: Vector2 = laser_direction * (18.0 + enemy.scale.x * 3.0)
		var end_point: Vector2 = start_point + laser_direction * BOSS_LASER_LENGTH
		var alpha: float = 0.32 + 0.08 * sin(enemy.status_visual_time * 9.0 + float(index))

		var outer = enemy.boss_laser_lines[index]
		outer.scale = Vector2.ONE / enemy.global_scale
		outer.width = 44.0
		outer.visible = true
		outer.points = PackedVector2Array([start_point, end_point])
		outer.default_color = Color(BOSS_LASER_COLOR.r, BOSS_LASER_COLOR.g, BOSS_LASER_COLOR.b, alpha)

		var core = enemy.boss_laser_core_lines[index]
		core.scale = Vector2.ONE / enemy.global_scale
		core.width = 7.0
		core.visible = true
		core.points = PackedVector2Array([start_point, end_point])
		core.default_color = Color(1.0, 0.88, 1.0, 0.96)

		if not touching_beam and enemy.target != null and is_instance_valid(enemy.target):
			var target_center: Vector2 = enemy.target.global_position
			var target_radius: float = 0.0
			if enemy.target.has_method("get_hurtbox_center"):
				target_center = enemy.target.get_hurtbox_center()
			if enemy.target.has_method("get_hurtbox_radius"):
				target_radius = float(enemy.target.get_hurtbox_radius())
			var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(target_center, enemy.global_position + start_point, enemy.global_position + end_point)
			var distance_to_beam: float = closest_point.distance_to(target_center)
			if distance_to_beam <= 22.0 + target_radius and enemy.target.has_method("take_damage"):
				touching_beam = true
	# All eight beams share contact time: overlaps cannot multiply the DPS.
	if touching_beam:
		enemy.boss_laser_hit_timer += active_delta
		while enemy.boss_laser_hit_timer + 0.000001 >= LASER_DAMAGE_INTERVAL:
			enemy.boss_laser_hit_timer = maxf(0.0, enemy.boss_laser_hit_timer - LASER_DAMAGE_INTERVAL)
			enemy.target.take_damage(enemy.attack * LASER_DAMAGE_INTERVAL)
	# Settle fractional contact on exit/end, so brief crossings also hurt.
	if (not touching_beam or enemy.boss_laser_remaining <= 0.0) and enemy.boss_laser_hit_timer > 0.0:
		if enemy.target != null and is_instance_valid(enemy.target) and enemy.target.has_method("take_damage"):
			enemy.target.take_damage(enemy.attack * enemy.boss_laser_hit_timer)
		enemy.boss_laser_hit_timer = 0.0
	if enemy.boss_laser_remaining <= 0.0:
		for laser in enemy.boss_laser_lines:
			laser.visible = false
		for core in enemy.boss_laser_core_lines:
			core.visible = false

static func apply_passive_boss_pull(enemy, delta: float) -> void:
	_pull_target_toward_point(enemy, enemy.global_position, BOSS_PASSIVE_PULL_STRENGTH, delta, false)

static func start_orbit_bomb(enemy) -> void:
	enemy.boss_orbit_bomb_remaining = 1.0
	enemy.boss_orbit_pull_remaining = ORBIT_PULL_DURATION
	enemy._ensure_boss_orbit_ball()
	enemy._spawn_status_burst(Color(0.05, 0.0, 0.08, 0.28), 42.0 + enemy.scale.x * 8.0)

static func update_orbit_bomb(enemy, delta: float, fire_aimed: bool = true, start_new_burst: bool = true) -> void:
	enemy._ensure_boss_orbit_ball()
	if enemy.boss_orbit_pull_remaining <= 0.0:
		enemy.boss_orbit_bomb_angle = wrapf(enemy.boss_orbit_bomb_angle + ORBIT_ROTATION_SPEED * delta, 0.0, TAU)
	var orbit_offset: Vector2 = Vector2.RIGHT.rotated(enemy.boss_orbit_bomb_angle) * (ORBIT_BALL_RADIUS + 8.0 * sin(enemy.status_visual_time * 4.0))
	if enemy.boss_orbit_ball != null:
		enemy.boss_orbit_ball.position = orbit_offset
		if enemy.boss_orbit_pull_remaining <= 0.0:
			enemy.boss_orbit_ball.rotation = -enemy.status_visual_time * 1.26
	_update_orbit_pull(enemy, delta)
	if fire_aimed:
		_update_orbit_aimed_burst(enemy, delta, start_new_burst)

static func _update_orbit_pull(enemy, delta: float) -> void:
	if enemy.boss_orbit_pull_remaining > 0.0:
		enemy.boss_orbit_pull_remaining = max(0.0, enemy.boss_orbit_pull_remaining - delta)
		_update_orbit_gather_visual(enemy, enemy.boss_orbit_pull_remaining / ORBIT_PULL_DURATION)
		_pull_target_to_orbit_ball(enemy, delta)
		return
	_update_orbit_gather_visual(enemy, 1.0, false)
	_sync_target_pull_status(enemy, 0.0)

static func _update_orbit_aimed_burst(enemy, delta: float, start_new_burst: bool = true) -> void:
	if enemy.boss_orbit_ball == null or not is_instance_valid(enemy.boss_orbit_ball):
		return
	if enemy.target == null or not is_instance_valid(enemy.target):
		return
	if start_new_burst:
		enemy.boss_orbit_bomb_shot_timer -= delta
	if start_new_burst and enemy.boss_orbit_bomb_shot_timer <= 0.0:
		enemy.boss_orbit_bomb_shot_timer += ORBIT_AIMED_BURST_INTERVAL
		enemy.boss_aimed_shots_remaining = ORBIT_AIMED_BURST_COUNT
		enemy.boss_aimed_shot_timer = 0.0
	else:
		enemy.boss_aimed_shot_timer -= delta
	while enemy.boss_aimed_shots_remaining > 0 and enemy.boss_aimed_shot_timer <= 0.000001:
		_fire_aimed_volley(enemy)
		enemy.boss_aimed_shots_remaining -= 1
		enemy.boss_aimed_shot_timer += ORBIT_AIMED_SHOT_INTERVAL

static func _fire_aimed_volley(enemy) -> void:
	var target_position: Vector2 = enemy.target.global_position
	if enemy.target.has_method("get_hurtbox_center"):
		target_position = enemy.target.get_hurtbox_center()
	var aim_direction: Vector2 = enemy.global_position.direction_to(target_position)
	if aim_direction.length_squared() <= 0.001:
		aim_direction = Vector2.RIGHT
	for lane in range(3):
		var shot_direction: Vector2 = aim_direction.rotated(float(lane - 1) * 0.13)
		enemy._spawn_projectile(
			enemy.global_position + shot_direction * 34.0,
			shot_direction, 405.0 * BOSS_PROJECTILE_SPEED_SCALE,
			enemy.projectile_damage * 0.48,
			5.2,
			Color(0.62, 0.38, 1.0), "straight",
			{"size_scale": 1.0, "hit_radius": 7.0, "visual_style": "boss_danmaku_violet_orb"}
		)

static func _pull_target_to_orbit_ball(enemy, delta: float) -> void:
	if enemy.target == null or not is_instance_valid(enemy.target):
		return
	var pull_origin: Vector2 = enemy.global_position
	if enemy.boss_orbit_ball != null and is_instance_valid(enemy.boss_orbit_ball):
		pull_origin = enemy.boss_orbit_ball.global_position
	_pull_target_toward_point(enemy, pull_origin, ORBIT_PULL_STRENGTH, delta, true)

static func _pull_target_toward_point(enemy, pull_origin: Vector2, strength: float, delta: float, sync_status: bool) -> void:
	if enemy.target == null or not is_instance_valid(enemy.target):
		return
	var target_node := enemy.target as Node2D
	if target_node == null:
		return
	var to_origin: Vector2 = pull_origin - target_node.global_position
	var distance: float = to_origin.length()
	if distance <= 1.0:
		return
	var pull_direction: Vector2 = to_origin / distance
	var movement_alignment: float = _get_target_pull_alignment(target_node, pull_direction)
	var pull_factor: float = 1.0
	if movement_alignment > 0.2:
		pull_factor = 1.45
	elif movement_alignment < -0.2:
		pull_factor = 0.35
	var pull_distance: float = min(distance, strength * pull_factor * delta)
	target_node.global_position += pull_direction * pull_distance
	if "velocity" in target_node:
		target_node.velocity += pull_direction * strength * pull_factor * 0.18
	if sync_status and target_node.has_method("queue_external_camera_shake"):
		target_node.queue_external_camera_shake(8.0, 0.08)
	if sync_status:
		_sync_target_pull_status(enemy, enemy.boss_orbit_pull_remaining)

static func _sync_target_pull_status(enemy, remaining: float) -> void:
	if enemy.target == null or not is_instance_valid(enemy.target):
		return
	var pull_origin: Vector2 = enemy.global_position
	if enemy.boss_orbit_ball != null and is_instance_valid(enemy.boss_orbit_ball):
		pull_origin = enemy.boss_orbit_ball.global_position
	if enemy.target.has_method("_sync_orbit_pull_status"):
		enemy.target._sync_orbit_pull_status(remaining, pull_origin)
		return
	if not enemy.target.has_method("_sync_duration_status"):
		return
	enemy.target._sync_duration_status("orbit_pull", "牵引", remaining, 80, Color(0.22, 0.14, 0.28, 0.95))

static func _get_target_pull_alignment(target_node: Node2D, pull_direction: Vector2) -> float:
	if not ("velocity" in target_node):
		return 0.0
	var target_velocity: Vector2 = target_node.velocity
	if target_velocity.length_squared() <= 9.0:
		return 0.0
	return target_velocity.normalized().dot(pull_direction)

static func _update_orbit_gather_visual(enemy, remaining_ratio: float, visible: bool = true) -> void:
	if enemy.boss_orbit_ball == null or not is_instance_valid(enemy.boss_orbit_ball):
		return
	var gather := enemy.boss_orbit_ball.get_node_or_null("GatherEffect") as Node2D
	if gather == null:
		return
	gather.visible = visible
	if not visible:
		return
	var progress: float = 1.0 - clamp(remaining_ratio, 0.0, 1.0)
	var start_radius: float = lerpf(74.0, 28.0, progress)
	for index in range(gather.get_child_count()):
		var ray := gather.get_child(index) as Line2D
		if ray == null:
			continue
		var angle: float = TAU * float(index) / float(max(1, gather.get_child_count())) + enemy.status_visual_time * 1.4
		var direction: Vector2 = Vector2.RIGHT.rotated(angle)
		ray.points = PackedVector2Array([direction * start_radius, direction * 18.0])
		ray.default_color = Color(0.0, 0.0, 0.0, 0.28 + progress * 0.54)
		ray.width = 2.0 + progress * 3.0

static func start_peacock_attack(enemy) -> void:
	enemy.boss_peacock_charge_remaining = 0.78
	enemy._ensure_boss_peacock_markers(7)
	enemy._spawn_status_burst(Color(0.60, 0.40, 1.0, 0.2), 48.0 + enemy.scale.x * 8.0)

static func update_peacock_attack(enemy, delta: float) -> void:
	if enemy.boss_peacock_charge_remaining <= 0.0:
		if not enemy.boss_peacock_markers.is_empty():
			enemy._clear_boss_peacock_markers()
		return

	enemy._ensure_boss_peacock_markers(7)
	enemy.boss_peacock_charge_remaining = max(0.0, enemy.boss_peacock_charge_remaining - delta)
	var aim_direction: Vector2 = enemy.global_position.direction_to(enemy.target.global_position) if enemy.target != null and is_instance_valid(enemy.target) else Vector2.RIGHT
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	var base_angle: float = aim_direction.angle()
	var spread: float = 1.1
	var center_offset: float = float(enemy.boss_peacock_markers.size() - 1) * 0.5
	for index in range(enemy.boss_peacock_markers.size()):
		var marker = enemy.boss_peacock_markers[index]
		var offset_ratio: float = (float(index) - center_offset) / max(1.0, center_offset)
		var angle: float = base_angle + offset_ratio * spread * 0.5
		var distance: float = lerpf(58.0, 118.0, abs(offset_ratio))
		marker.position = Vector2.RIGHT.rotated(angle) * distance
		marker.rotation = enemy.status_visual_time * 1.8 + float(index) * 0.2
		marker.modulate.a = 0.42 + 0.4 * (1.0 - enemy.boss_peacock_charge_remaining / 0.78)

	if enemy.boss_peacock_charge_remaining <= 0.0:
		var bullet_count: int = 17
		var row_count: int = 3
		for row in range(row_count):
			var row_ratio: float = float(row) / float(max(1, row_count - 1))
			var row_speed: float = (210.0 + row_ratio * 50.0) * BOSS_PROJECTILE_SPEED_SCALE
			var row_damage: float = enemy.projectile_damage * (0.72 + row_ratio * 0.18)
			var row_distance: float = 16.0 + row * 12.0
			for index in range(bullet_count):
				var offset: float = (float(index) - float(bullet_count - 1) * 0.5) * (1.34 / float(max(1, bullet_count - 1)))
				var shot_direction: Vector2 = aim_direction.rotated(offset)
				enemy._spawn_projectile(
					enemy.global_position + shot_direction * (row_distance + enemy.scale.x * 4.0),
					shot_direction,
					row_speed,
					row_damage,
					5.2 * BOSS_PROJECTILE_LIFETIME_SCALE,
					Color(0.60, 0.40, 1.0, 1.0),
					"turning",
					{
						"turn_start_delay": 0.24 + row_ratio * 0.08,
						"turn_interval": 0.16,
						"turn_angle_step": 0.08,
						"turn_direction_sign": -1.0 if index < bullet_count / 2 else 1.0,
						"size_scale": 0.96 + row_ratio * 0.16,
						"visual_style": "boss_turning_hex"
					}
				)
		enemy._spawn_status_burst(Color(0.60, 0.40, 1.0, 0.22), 52.0 + enemy.scale.x * 8.0)
		enemy._clear_boss_peacock_markers()

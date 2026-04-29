extends RefCounted

const BOSS_PROJECTILE_SPEED_SCALE := 0.588
const BOSS_PROJECTILE_LIFETIME_SCALE := 1.5
const BOSS_LASER_LENGTH := 980.0

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
			enemy.projectile_damage * (0.78 + float(enemy.boss_phase - 1) * 0.08),
			5.0 * BOSS_PROJECTILE_LIFETIME_SCALE,
			Color(1.0, 0.38, 0.12, 1.0),
			"straight",
			{"size_scale": 1.15}
		)
	var rotation_step: float = TAU / float(max(1, bullet_count)) * 0.5
	enemy.boss_pattern_rotation = wrapf(base_angle + rotation_step + randf_range(-0.06, 0.06), 0.0, TAU)
	enemy._spawn_status_burst(Color(1.0, 0.44, 0.16, 0.16), 34.0 + enemy.scale.x * 8.0)

static func fire_quarter_sine_ring(enemy, count: int = 12) -> void:
	var bullet_count: int = max(8, count)
	var base_angle: float = enemy.boss_pattern_rotation * 0.72 + PI * 0.08 + randf_range(-0.1, 0.1)
	for index in range(bullet_count):
		var shot_angle: float = base_angle + TAU * float(index) / float(bullet_count)
		var shot_direction: Vector2 = Vector2.RIGHT.rotated(shot_angle)
		var side: float = -1.0 if index % 2 == 0 else 1.0
		enemy._spawn_projectile(
			enemy.global_position + shot_direction * (28.0 + enemy.scale.x * 4.0),
			shot_direction,
			(210.0 + float(enemy.boss_phase - 1) * 8.0) * BOSS_PROJECTILE_SPEED_SCALE,
			enemy.projectile_damage * 0.72,
			5.0 * BOSS_PROJECTILE_LIFETIME_SCALE,
			Color(0.24, 0.92, 1.0, 1.0),
			"quarter_sine",
			{
				"sine_amplitude": 54.0,
				"quarter_sine_distance": 165.0,
				"quarter_sine_side": side,
				"size_scale": 1.3
			}
		)
	enemy.boss_turning_sign *= -1.0
	enemy._spawn_status_burst(Color(0.24, 0.92, 1.0, 0.18), 40.0 + enemy.scale.x * 8.0)

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
				"split_damage_scale": 0.45,
				"split_lifetime": 3.8 * BOSS_PROJECTILE_LIFETIME_SCALE,
				"split_motion_mode": "quarter_sine",
				"size_scale": 1.45
			}
		)
	enemy._spawn_status_burst(Color(0.46, 1.0, 1.0, 0.22), 46.0 + enemy.scale.x * 8.0)

static func start_laser_sweep(enemy) -> void:
	enemy.boss_laser_remaining = enemy.boss_laser_duration
	enemy.boss_laser_hit_timer = 0.0
	enemy.boss_laser_start_rotation = enemy.global_position.angle_to_point(enemy.target.global_position) if enemy.target != null and is_instance_valid(enemy.target) else enemy.boss_pattern_rotation
	enemy.boss_laser_final_rotation = enemy.boss_laser_start_rotation - 0.52
	enemy.boss_laser_rotation = enemy.boss_laser_start_rotation
	enemy._spawn_status_burst(Color(1.0, 0.7, 0.24, 0.2), 50.0 + enemy.scale.x * 10.0)

static func update_lasers(enemy, delta: float) -> void:
	if enemy.boss_laser_remaining <= 0.0:
		for laser in enemy.boss_laser_lines:
			laser.visible = false
		for laser_core in enemy.boss_laser_core_lines:
			laser_core.visible = false
		return

	enemy.boss_laser_remaining = max(0.0, enemy.boss_laser_remaining - delta)
	enemy.boss_laser_hit_timer = max(0.0, enemy.boss_laser_hit_timer - delta)
	var elapsed: float = enemy.boss_laser_duration - enemy.boss_laser_remaining
	if elapsed < enemy.boss_laser_spin_duration:
		var spin_ratio: float = clamp(elapsed / max(enemy.boss_laser_spin_duration, 0.001), 0.0, 1.0)
		enemy.boss_laser_rotation = lerpf(enemy.boss_laser_start_rotation, enemy.boss_laser_final_rotation, spin_ratio)
	else:
		enemy.boss_laser_rotation = enemy.boss_laser_final_rotation

	for index in range(enemy.boss_laser_lines.size()):
		var angle: float = enemy.boss_laser_rotation + TAU * float(index) / float(max(1, enemy.boss_laser_lines.size()))
		var laser_direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var start_point: Vector2 = laser_direction * (18.0 + enemy.scale.x * 3.0)
		var end_point: Vector2 = start_point + laser_direction * BOSS_LASER_LENGTH
		var alpha: float = 0.32 + 0.08 * sin(enemy.status_visual_time * 9.0 + float(index))

		var outer = enemy.boss_laser_lines[index]
		outer.visible = true
		outer.points = PackedVector2Array([start_point, end_point])
		outer.default_color = Color(1.0, 0.44, 0.12, alpha)

		var core = enemy.boss_laser_core_lines[index]
		core.visible = true
		core.points = PackedVector2Array([start_point, end_point])
		core.default_color = Color(1.0, 0.92, 0.58, min(1.0, alpha + 0.4))

		if enemy.boss_laser_hit_timer <= 0.0 and enemy.target != null and is_instance_valid(enemy.target):
			var target_center: Vector2 = enemy.target.global_position
			var target_radius: float = 0.0
			if enemy.target.has_method("get_hurtbox_center"):
				target_center = enemy.target.get_hurtbox_center()
			if enemy.target.has_method("get_hurtbox_radius"):
				target_radius = float(enemy.target.get_hurtbox_radius())
			var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(target_center, enemy.global_position + start_point, enemy.global_position + end_point)
			var distance_to_beam: float = closest_point.distance_to(target_center)
			if distance_to_beam <= 22.0 + target_radius and enemy.target.has_method("take_damage"):
				enemy.target.take_damage(enemy.projectile_damage * 0.62)
				enemy.boss_laser_hit_timer = 0.16

static func start_orbit_bomb(enemy) -> void:
	enemy.boss_orbit_bomb_remaining = 3.4
	enemy.boss_orbit_bomb_angle = enemy.boss_pattern_rotation
	enemy.boss_orbit_bomb_shot_timer = 0.0
	enemy._ensure_boss_orbit_ball()
	enemy._spawn_status_burst(Color(1.0, 0.8, 0.34, 0.22), 42.0 + enemy.scale.x * 8.0)

static func update_orbit_bomb(enemy, delta: float) -> void:
	if enemy.boss_orbit_bomb_remaining <= 0.0:
		enemy._clear_boss_orbit_ball()
		return

	enemy._ensure_boss_orbit_ball()
	enemy.boss_orbit_bomb_remaining = max(0.0, enemy.boss_orbit_bomb_remaining - delta)
	enemy.boss_orbit_bomb_angle = wrapf(enemy.boss_orbit_bomb_angle + 2.35 * delta, 0.0, TAU)
	var orbit_offset: Vector2 = Vector2.RIGHT.rotated(enemy.boss_orbit_bomb_angle) * (116.0 + 8.0 * sin(enemy.status_visual_time * 4.0))
	if enemy.boss_orbit_ball != null:
		enemy.boss_orbit_ball.position = orbit_offset
		enemy.boss_orbit_ball.rotation = -enemy.status_visual_time * 1.8

	enemy.boss_orbit_bomb_shot_timer -= delta
	while enemy.boss_orbit_bomb_shot_timer <= 0.0 and enemy.boss_orbit_bomb_remaining > 0.0:
		enemy.boss_orbit_bomb_shot_timer += 0.2
		var shot_angle: float = randf() * TAU
		var shot_direction: Vector2 = Vector2.RIGHT.rotated(shot_angle)
		var origin: Vector2 = enemy.global_position + orbit_offset
		enemy._spawn_projectile(origin, shot_direction, 215.0 * BOSS_PROJECTILE_SPEED_SCALE, enemy.projectile_damage * 0.5, 4.2 * BOSS_PROJECTILE_LIFETIME_SCALE, Color(1.0, 0.76, 0.3, 1.0), "straight", {"size_scale": 0.86})

	if enemy.boss_orbit_bomb_remaining <= 0.0:
		var burst_origin: Vector2 = enemy.global_position + orbit_offset
		for index in range(26):
			var burst_angle: float = TAU * float(index) / 26.0
			var burst_direction: Vector2 = Vector2.RIGHT.rotated(burst_angle)
			enemy._spawn_projectile(burst_origin, burst_direction, 250.0 * BOSS_PROJECTILE_SPEED_SCALE, enemy.projectile_damage * 0.66, 4.4 * BOSS_PROJECTILE_LIFETIME_SCALE, Color(1.0, 0.86, 0.52, 1.0), "straight", {"size_scale": 1.0})
		enemy._spawn_status_burst(Color(1.0, 0.84, 0.46, 0.22), 58.0)
		enemy._clear_boss_orbit_ball()

static func start_peacock_attack(enemy) -> void:
	enemy.boss_peacock_charge_remaining = 0.78
	enemy._ensure_boss_peacock_markers(7)
	enemy._spawn_status_burst(Color(0.98, 0.86, 0.42, 0.2), 48.0 + enemy.scale.x * 8.0)

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
		enemy._spawn_status_burst(Color(1.0, 0.86, 0.44, 0.22), 52.0 + enemy.scale.x * 8.0)
		enemy._clear_boss_peacock_markers()

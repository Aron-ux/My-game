extends RefCounted

const ENEMY_GLUTTON_SKILL_BEHAVIOR := preload("res://scripts/enemies/enemy_glutton_skill_behavior.gd")

const GLOBAL_UNIT_MOVE_SPEED_SCALE := 0.7
const BOSS_MOVE_SPEED_SCALE := 0.7

static func compute_velocity(enemy, delta: float) -> Vector2:
	var to_target: Vector2 = enemy._cached_to_target
	var distance_to_target: float = enemy._cached_distance_to_target
	var direction_to_target: Vector2 = enemy._cached_direction_to_target
	var move_direction := direction_to_target
	var move_speed: float = enemy.speed * enemy.slow_multiplier

	if enemy._is_boss:
		return compute_boss_velocity(enemy, direction_to_target, distance_to_target, delta)
	if enemy._is_turret or enemy.behavior_id == "rose" or enemy.secondary_behavior_id == "rose" or enemy.rebirth_timer > 0.0:
		return Vector2.ZERO
	if enemy._is_glutton and ENEMY_GLUTTON_SKILL_BEHAVIOR.should_hold_position_for_cast(enemy):
		return Vector2.ZERO

	if enemy._is_shooter:
		if distance_to_target < enemy.preferred_distance - 34.0:
			move_direction = -direction_to_target
		elif distance_to_target > enemy.preferred_distance + 44.0:
			move_direction = direction_to_target
		else:
			move_direction = (direction_to_target.orthogonal() * enemy.strafe_sign + direction_to_target * 0.18).normalized()

	var has_dash_windup: bool = (enemy._is_dasher and enemy.dash_windup_remaining > 0.0) or (enemy.behavior_id == "skulltomb" and enemy.skulltomb_charge_windup_remaining > 0.0)
	if has_dash_windup:
		return Vector2.ZERO

	var has_active_dash: bool = (enemy._is_dasher and enemy.dash_remaining > 0.0) or (enemy.behavior_id == "skulltomb" and enemy.dash_remaining > 0.0)
	if has_active_dash:
		move_direction = enemy.dash_direction
		move_speed *= enemy.dash_speed_multiplier
		if enemy.behavior_id == "skulltomb":
			var remaining_forward: float = max(0.0, (enemy.skulltomb_charge_target_position - enemy.global_position).dot(move_direction.normalized()))
			var max_speed_for_target: float = remaining_forward / max(0.001, delta * GLOBAL_UNIT_MOVE_SPEED_SCALE)
			move_speed = min(move_speed, max_speed_for_target)

	if enemy._is_accelerator and enemy.acceleration_remaining > 0.0:
		move_speed *= enemy.acceleration_boost

	if enemy._is_glutton:
		move_speed += enemy.glutton_bonus_speed
		move_speed *= ENEMY_GLUTTON_SKILL_BEHAVIOR.get_war_stomp_speed_multiplier(enemy)
	if enemy._is_swarm:
		move_speed *= 1.1
	move_speed *= max(0.0, float(enemy.skull_soldier_speed_multiplier))

	return move_direction * move_speed * GLOBAL_UNIT_MOVE_SPEED_SCALE

static func compute_boss_velocity(enemy, direction_to_target: Vector2, distance_to_target: float, delta: float) -> Vector2:
	if enemy.boss_phase_transition_target > 0 or bool(enemy.boss_shield_break_visual_intro_active):
		return Vector2.ZERO
	var radial := Vector2.ZERO
	var radial_weight := 1.0
	var tangential_weight := 0.12
	var movement_scale := 1.0
	if distance_to_target > enemy.preferred_distance + 42.0:
		radial = direction_to_target
	elif distance_to_target < enemy.preferred_distance - 36.0:
		radial = -direction_to_target
		tangential_weight = 0.14
	else:
		radial = direction_to_target * 0.08
		radial_weight = 0.42
		tangential_weight = 0.24
		movement_scale = 0.45

	var tangential: Vector2 = direction_to_target.orthogonal() * enemy.boss_orbit_sign
	enemy.boss_pattern_rotation = wrapf(enemy.boss_pattern_rotation + delta * 0.3, 0.0, TAU)
	var drift := Vector2.RIGHT.rotated(enemy.boss_pattern_rotation) * 0.08
	var blended_direction := tangential * tangential_weight + radial * radial_weight + drift
	if blended_direction.length_squared() <= 0.001:
		return Vector2.ZERO
	var move_direction := blended_direction.normalized()
	return move_direction * enemy.speed * enemy.slow_multiplier * BOSS_MOVE_SPEED_SCALE * GLOBAL_UNIT_MOVE_SPEED_SCALE * movement_scale

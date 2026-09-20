extends RefCounted

const ENEMY_BOSS_VISUALS := preload("res://scripts/enemies/enemy_boss_visuals.gd")
const ROUTINE := preload("res://scripts/enemies/enemy_boss_routine.gd")
const BOSS_PHASE_THREE_CHARGE_DURATION := 5.0
const BOSS_PHASE_THREE_SHAKE_STRENGTH := 60.0
const BOSS_PHASE_THREE_SHAKE_DURATION := 2.0
const SHIELD_ARMOR_BONUS := 15.0
const SHIELD_REDUCTION_BONUS := 0.15


static func get_shield_armor_bonus(enemy) -> float:
	return SHIELD_ARMOR_BONUS if has_boss_shield(enemy) else 0.0


static func get_shield_reduction_bonus(enemy) -> float:
	return SHIELD_REDUCTION_BONUS if has_boss_shield(enemy) else 0.0

static func get_boss_phase(enemy) -> int:
	return int(enemy.boss_phase)

static func get_phase_bar_max_health(enemy) -> float:
	return max(1.0, float(enemy.max_health) / 3.0)

static func get_boss_shield_max_health(enemy) -> float:
	return max(0.0, float(enemy.boss_shield_max_health))

static func get_boss_spawn_health(enemy) -> float:
	return get_phase_bar_max_health(enemy) + get_boss_shield_max_health(enemy)

static func has_boss_shield(enemy) -> bool:
	if str(enemy.enemy_kind) != "boss" or bool(enemy.boss_shield_break_intro_played):
		return false
	return float(enemy.current_health) > get_phase_bar_max_health(enemy)

static func start_phase_transition(enemy, next_phase: int) -> void:
	enemy.boss_phase_transition_target = clamp(next_phase, 2, 3)
	if int(enemy.boss_phase_transition_target) >= 3:
		enemy.boss_shield_break_intro_played = true
	enemy.boss_phase_three_intro_remaining = BOSS_PHASE_THREE_CHARGE_DURATION
	enemy.current_health = 0.0
	_prepare_transition_state(enemy)
	enemy._spawn_status_burst(Color(1.0, 0.84, 0.42, 0.24), 54.0 + enemy.scale.x * 12.0)

static func start_shield_break_intro(enemy) -> void:
	enemy.boss_shield_break_intro_played = true
	enemy.boss_shield_break_visual_intro_active = true
	enemy.boss_phase_three_intro_remaining = BOSS_PHASE_THREE_CHARGE_DURATION
	enemy.current_health = get_phase_bar_max_health(enemy)
	_prepare_transition_state(enemy)
	enemy._spawn_status_burst(Color(1.0, 0.84, 0.42, 0.24), 54.0 + enemy.scale.x * 12.0)

static func _prepare_transition_state(enemy) -> void:
	ROUTINE.stop_attacks(enemy)
	preload("res://scripts/enemies/enemy_projectiles.gd").clear_projectiles_from_source(enemy)
	var theme: int = ROUTINE.PHASE_OPENING_THEMES[clampi(enemy.boss_phase_transition_target - 1, 0, 2)] if enemy.boss_phase_transition_target > 0 else int(enemy.boss_routine.get("theme", 0))
	ROUTINE.reset(enemy, theme)

static func update_boss_trait(enemy, delta: float) -> void:
	enemy._ensure_boss_helpers()
	enemy.boss_battle_elapsed += delta

	if enemy.boss_phase_transition_target > 0:
		update_boss_phase_transition(enemy, delta)
		return
	if bool(enemy.boss_shield_break_visual_intro_active):
		update_boss_shield_break_intro(enemy, delta)
		return

	if enemy.boss_phase >= 3:
		enemy.boss_phase_three_elapsed += delta
	ROUTINE.update(enemy, delta)

static func update_boss_shield_break_intro(enemy, delta: float) -> void:
	enemy.boss_phase_three_intro_remaining = max(0.0, enemy.boss_phase_three_intro_remaining - delta)
	ENEMY_BOSS_VISUALS.update_boss_phase_three_charge_visuals(enemy)
	if enemy.boss_phase_three_intro_remaining > 0.000001:
		return
	enemy.boss_phase_three_intro_remaining = 0.0
	enemy.boss_shield_break_visual_intro_active = false
	ENEMY_BOSS_VISUALS.clear_boss_phase_three_charge_visuals(enemy)
	enemy.current_health = get_phase_bar_max_health(enemy)
	enemy._spawn_status_burst(Color(0.2, 0.42, 1.0, 0.34), 84.0 + enemy.scale.x * 12.0)
	if enemy.target != null and is_instance_valid(enemy.target) and enemy.target.has_method("queue_external_camera_shake"):
		enemy.target.queue_external_camera_shake(BOSS_PHASE_THREE_SHAKE_STRENGTH, BOSS_PHASE_THREE_SHAKE_DURATION)

static func update_boss_phase_transition(enemy, delta: float) -> void:
	enemy.boss_phase_three_intro_remaining = max(0.0, enemy.boss_phase_three_intro_remaining - delta)
	ENEMY_BOSS_VISUALS.update_boss_phase_three_charge_visuals(enemy)
	if enemy.boss_phase_three_intro_remaining > 0.000001:
		return
	enemy.boss_phase_three_intro_remaining = 0.0
	ENEMY_BOSS_VISUALS.clear_boss_phase_three_charge_visuals(enemy)
	var target_phase: int = int(enemy.boss_phase_transition_target)
	enemy.boss_phase_transition_target = 0
	enemy.boss_phase = target_phase
	enemy.current_health = get_phase_bar_max_health(enemy)
	enemy.boss_phase_three_elapsed = 0.0
	enemy.boss_radial_timer = 0.18
	enemy.boss_sine_cooldown = 0.75
	enemy.boss_split_timer = 1.6 if target_phase >= 2 else enemy.boss_split_interval
	enemy.boss_laser_timer = 2.9 if target_phase >= 2 else enemy.boss_laser_interval
	enemy.boss_orbit_bomb_timer = 3.8 if target_phase >= 3 else enemy.boss_orbit_bomb_interval
	enemy.boss_orbit_bomb_remaining = 1.0 if target_phase >= 3 else 0.0
	enemy.boss_orbit_pull_remaining = 0.0
	if target_phase >= 3:
		enemy._ensure_boss_orbit_ball()
	enemy.boss_peacock_timer = 4.6 if target_phase >= 3 else enemy.boss_peacock_interval
	enemy._spawn_status_burst(Color(0.2, 0.42, 1.0, 0.34), 84.0 + enemy.scale.x * 12.0)
	if target_phase >= 3 and enemy.target != null and is_instance_valid(enemy.target) and enemy.target.has_method("queue_external_camera_shake"):
		enemy.target.queue_external_camera_shake(BOSS_PHASE_THREE_SHAKE_STRENGTH, BOSS_PHASE_THREE_SHAKE_DURATION)

static func update_boss_phase_three_intro(enemy, delta: float) -> void:
	update_boss_phase_transition(enemy, delta)

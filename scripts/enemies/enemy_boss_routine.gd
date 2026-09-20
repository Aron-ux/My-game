extends RefCounted

const ATTACKS := preload("res://scripts/enemies/enemy_boss_attacks.gd")
const VISUALS := preload("res://scripts/enemies/enemy_boss_visuals.gd")
const PROJECTILES := preload("res://scripts/enemies/enemy_projectiles.gd")
const THEMES := ["污染绽放", "双螺旋回廊", "魔核过载"]
const PREVIEW_DURATION := 1.5
const RECOVERY_DURATION := 2.0
const LASER_WARNING_DURATION := 1.2
const CLEAR_FADE_DURATION := 0.45


static func reset(enemy, theme: int = 0) -> void:
	enemy.boss_routine = {"stage": "basic", "elapsed": 0.0, "theme": posmod(theme, 3), "events": 0, "laser_aim": 0.0}
	enemy.boss_radial_timer = 0.4
	enemy.boss_orbit_bomb_shot_timer = 1.0


static func get_duration(enemy, stage: String) -> float:
	match stage:
		"basic":
			return 8.0 if enemy.boss_phase >= 3 else 12.0
		"preview":
			return PREVIEW_DURATION
		"performance":
			return 18.0 if enemy.boss_phase >= 3 else 15.0
		_:
			return RECOVERY_DURATION


static func get_status(enemy) -> Dictionary:
	var state: Dictionary = enemy.boss_routine
	var stage := str(state.get("stage", "basic"))
	var duration := get_duration(enemy, stage)
	var label := "常规战斗"
	if enemy.boss_shield_break_visual_intro_active:
		return {"label": "护盾破碎", "remaining": enemy.boss_phase_three_intro_remaining, "duration": 5.0}
	var title: String = THEMES[int(state.get("theme", 0)) % 3]
	match stage:
		"preview":
			label = "即将发动 · %s" % title
		"performance":
			label = "弹幕 · %s" % title
			if is_laser_warning(enemy):
				label += " · 激光预警"
				return {"label": label, "remaining": maxf(0.0, _warning_start(enemy) + LASER_WARNING_DURATION - float(state.elapsed)), "duration": LASER_WARNING_DURATION}
		"recovery":
			label = "能量平息"
	return {"label": label, "remaining": maxf(0.0, duration - float(state.get("elapsed", 0.0))), "duration": duration}


static func stop_attacks(enemy) -> void:
	enemy.boss_danmaku_wave = ATTACKS.DANMAKU_WAVES
	enemy.boss_aimed_shots_remaining = 0
	enemy.boss_sine_stream_timer = 0.0
	enemy.boss_laser_remaining = 0.0
	enemy.boss_laser_hit_timer = 0.0
	enemy.boss_orbit_bomb_remaining = 0.0
	enemy.boss_orbit_pull_remaining = 0.0
	enemy.boss_peacock_charge_remaining = 0.0
	enemy._clear_boss_orbit_ball()
	enemy._clear_boss_peacock_markers()
	ATTACKS.update_lasers(enemy, 0.0)
	VISUALS.clear_boss_phase_three_charge_visuals(enemy)
	if enemy.target != null and is_instance_valid(enemy.target) and enemy.target.has_method("_sync_orbit_pull_status"):
		enemy.target._sync_orbit_pull_status(0.0, enemy.global_position)


static func update(enemy, delta: float) -> void:
	if enemy.boss_routine.is_empty():
		reset(enemy)
	var remaining := maxf(0.0, delta)
	# Split only long steps. Cross-stage overshoot is consumed by the next
	# stage, so pause/resume and speed changes cannot skip a preview/recovery.
	while remaining > 0.000001:
		var stage := str(enemy.boss_routine.stage)
		var duration := get_duration(enemy, stage)
		var available := maxf(0.0, duration - float(enemy.boss_routine.elapsed))
		if available <= 0.000001:
			advance_stage(enemy)
			continue
		var step := minf(remaining, minf(available, 0.05))
		match stage:
			"basic":
				_update_basic(enemy, step)
			"preview":
				VISUALS.update_boss_spell_preview(enemy, (float(enemy.boss_routine.elapsed) + step) / duration, int(enemy.boss_routine.theme))
			"performance":
				_update_performance(enemy, step)
		enemy.boss_routine.elapsed = float(enemy.boss_routine.elapsed) + step
		remaining -= step
		if float(enemy.boss_routine.elapsed) >= duration - 0.000001:
			advance_stage(enemy)


static func advance_stage(enemy) -> void:
	var old_stage := str(enemy.boss_routine.stage)
	stop_attacks(enemy)
	enemy.boss_routine.elapsed = 0.0
	enemy.boss_routine.events = 0
	match old_stage:
		"basic":
			enemy.boss_routine.stage = "preview"
			PROJECTILES.clear_projectiles_from_source(enemy, CLEAR_FADE_DURATION)
			VISUALS.update_boss_spell_preview(enemy, 0.0, int(enemy.boss_routine.theme))
		"preview":
			enemy.boss_routine.stage = "performance"
			enemy.boss_sine_cooldown = 0.0
			enemy.boss_orbit_bomb_shot_timer = 0.0
		"performance":
			enemy.boss_routine.stage = "recovery"
			PROJECTILES.clear_projectiles_from_source(enemy, CLEAR_FADE_DURATION)
		_:
			reset(enemy, int(enemy.boss_routine.theme) + 1)


static func _shielded(enemy) -> bool:
	return not enemy.boss_shield_break_intro_played and enemy.current_health > maxf(1.0, enemy.max_health / 3.0)


static func _update_basic(enemy, delta: float) -> void:
	var pressure := sqrt(maxf(0.6, enemy.boss_attack_pressure_scale))
	var phase: int = clampi(enemy.boss_phase - 1, 0, 2)
	enemy.boss_radial_timer -= delta
	if enemy.boss_radial_timer <= 0.0:
		enemy.boss_radial_timer += float([1.98, 0.89, 0.71][phase]) / pressure
		ATTACKS.fire_radial_burst(enemy, roundi(float([16, 18, 20][phase]) * pressure))
	if not _shielded(enemy):
		# The orbit remains a visual source; no autonomous pull in basic play.
		ATTACKS.update_orbit_bomb(enemy, delta)


static func _event(enemy, bit: int, time: float, end_time: float) -> bool:
	if end_time + 0.000001 < time or (int(enemy.boss_routine.events) & bit) != 0:
		return false
	enemy.boss_routine.events = int(enemy.boss_routine.events) | bit
	return true


static func _warning_start(enemy) -> float:
	# The third-bar overload reserves its opening for the existing 7s pull.
	if enemy.boss_phase >= 3 and not _shielded(enemy):
		return ATTACKS.ORBIT_PULL_DURATION
	return get_duration(enemy, "performance") / 3.0


static func is_laser_warning(enemy) -> bool:
	var state: Dictionary = enemy.boss_routine
	if str(state.get("stage", "")) != "performance" or int(state.get("theme", 0)) != 2:
		return false
	var elapsed := float(state.get("elapsed", 0.0))
	return elapsed + 0.000001 >= _warning_start(enemy) and elapsed < _warning_start(enemy) + LASER_WARNING_DURATION - 0.000001


static func _update_performance(enemy, delta: float) -> void:
	var theme: int = enemy.boss_routine.theme
	var duration := get_duration(enemy, "performance")
	var end_time: float = float(enemy.boss_routine.elapsed) + delta
	var section := mini(2, int(end_time / (duration / 3.0)))
	var shielded := _shielded(enemy)
	var pulling: bool = theme == 2 and enemy.boss_phase >= 3 and not shielded and end_time < ATTACKS.ORBIT_PULL_DURATION - 0.000001

	# Existing continuous skills finish their elapsed step before new cues.
	ATTACKS.update_lasers(enemy, delta)
	if enemy.boss_peacock_charge_remaining > 0.0:
		ATTACKS.update_peacock_attack(enemy, delta)
	if pulling:
		if _event(enemy, 1, 0.0, end_time):
			ATTACKS.start_orbit_bomb(enemy)
		ATTACKS.apply_passive_boss_pull(enemy, delta)
		ATTACKS.update_orbit_bomb(enemy, delta, false)
	else:
		if enemy.boss_orbit_pull_remaining > 0.0:
			enemy.boss_orbit_pull_remaining = 0.0
			ATTACKS.update_orbit_bomb(enemy, 0.0, false)
		var pressure := sqrt(maxf(0.6, enemy.boss_attack_pressure_scale))
		ATTACKS.update_danmaku_stream(enemy, delta)
		enemy.boss_sine_cooldown -= delta
		if enemy.boss_sine_cooldown <= 0.0 and enemy.boss_danmaku_wave >= ATTACKS.DANMAKU_WAVES:
			enemy.boss_sine_cooldown += float([2.4, 2.0, 1.6][clampi(enemy.boss_phase - 1, 0, 2)]) / pressure
			enemy.boss_pattern_rotation = wrapf(enemy.boss_pattern_rotation + 0.18, 0.0, TAU)
			ATTACKS.fire_quarter_sine_ring(enemy, roundi(float([12, 18, 16][clampi(enemy.boss_phase - 1, 0, 2)]) * pressure), theme, -1.0 if section >= 1 else 1.0)
	if theme == 0 and section == 2 and not shielded:
		ATTACKS.update_orbit_bomb(enemy, delta)
	if theme == 1 and enemy.boss_phase >= 2:
		if _event(enemy, 2, duration / 3.0, end_time):
			ATTACKS.fire_recall_split(enemy)
		if _event(enemy, 4, duration * 0.55, end_time):
			ATTACKS.fire_recall_split(enemy)
	if theme == 2:
		var warning_start := _warning_start(enemy)
		if _event(enemy, 8, warning_start, end_time):
			enemy.boss_routine.laser_aim = enemy.global_position.angle_to_point(enemy.target.global_position) if is_instance_valid(enemy.target) else enemy.boss_pattern_rotation
		if end_time + 0.000001 >= warning_start and end_time < warning_start + LASER_WARNING_DURATION - 0.000001:
			ATTACKS.update_laser_warning(enemy, float(enemy.boss_routine.laser_aim))
		if _event(enemy, 16, warning_start + LASER_WARNING_DURATION, end_time):
			ATTACKS.start_laser_sweep(enemy, float(enemy.boss_routine.laser_aim))
			ATTACKS.update_lasers(enemy, 0.0)
		if not shielded and _event(enemy, 32, maxf(duration * 0.75, warning_start + LASER_WARNING_DURATION + enemy.boss_laser_duration), end_time):
			ATTACKS.start_peacock_attack(enemy)


static func restore(enemy, saved: Variant) -> void:
	if not saved is Dictionary or str(saved.get("stage", "")) not in ["basic", "preview", "performance", "recovery"]:
		stop_attacks(enemy)
		reset(enemy)
		return
	var stage := str(saved.stage)
	enemy.boss_routine = {
		"stage": stage,
		"elapsed": clampf(float(saved.get("elapsed", 0.0)), 0.0, get_duration(enemy, stage)),
		"theme": posmod(int(saved.get("theme", 0)), 3),
		"events": int(saved.get("events", 0)),
		"laser_aim": float(saved.get("laser_aim", 0.0))
	}
	if stage in ["preview", "recovery"]:
		stop_attacks(enemy)
	if stage == "preview":
		VISUALS.update_boss_spell_preview(enemy, float(enemy.boss_routine.elapsed) / PREVIEW_DURATION, int(enemy.boss_routine.theme))
	elif is_laser_warning(enemy):
		ATTACKS.update_laser_warning(enemy, float(enemy.boss_routine.laser_aim))

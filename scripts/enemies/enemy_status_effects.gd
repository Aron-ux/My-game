extends RefCounted

const STATUS_VISUAL_REFRESH_EPSILON := 0.08
const NORMAL_STATUS_VISUAL_REFRESH_EPSILON := 0.35

static func tick_timers(enemy, delta: float) -> void:
	for index in range(enemy.storm_armor_shred_timers.size() - 1, -1, -1):
		enemy.storm_armor_shred_timers[index] -= delta
		if enemy.storm_armor_shred_timers[index] <= 0.0:
			enemy.storm_armor_shred_timers.remove_at(index)
	if enemy.fury_armor_shred_remaining > 0.0:
		enemy.fury_armor_shred_remaining = maxf(0.0, enemy.fury_armor_shred_remaining - delta)
		if enemy.fury_armor_shred_remaining == 0.0:
			enemy.fury_armor_shred = 0.0
	if enemy.slow_timer > 0.0:
		var slow := preload("res://scripts/combat/movement_slow.gd").tick(enemy, delta, enemy.slow_multiplier, enemy.slow_timer)
		enemy.slow_multiplier = slow.x
		enemy.slow_timer = slow.y

	if enemy.vulnerability_timer > 0.0:
		enemy.vulnerability_timer = max(0.0, enemy.vulnerability_timer - delta)
		if enemy.vulnerability_timer == 0.0:
			enemy.vulnerability_bonus = 0.0

	if enemy.bleed_timer > 0.0:
		enemy.bleed_timer = max(0.0, enemy.bleed_timer - delta)
		if enemy.bleed_timer == 0.0:
			enemy.bleed_damage_per_second = 0.0

	if enemy.mage_wet_remaining > 0.0:
		enemy.mage_wet_remaining = maxf(0.0, enemy.mage_wet_remaining - delta)
		enemy.mage_wet_tick_remaining -= delta
		if enemy.mage_wet_tick_remaining <= 0.0:
			enemy.mage_wet_tick_remaining += 1.0
			if enemy.current_health > 0.0:
				enemy.take_soul_impact_damage(enemy.current_health * 0.01)
		if enemy.mage_wet_remaining <= 0.0:
			enemy.mage_wet_source = null

	if enemy.skull_soldier_speed_timer > 0.0:
		enemy.skull_soldier_speed_timer = max(0.0, enemy.skull_soldier_speed_timer - delta)
		if enemy.skull_soldier_speed_timer == 0.0:
			enemy.skull_soldier_speed_multiplier = 1.0

	if enemy.skull_damage_immune_timer > 0.0:
		enemy.skull_damage_immune_timer = max(0.0, enemy.skull_damage_immune_timer - delta)
		if enemy.skull_damage_immune_timer == 0.0 and enemy.has_method("_update_status_visuals"):
			enemy._update_status_visuals()

	if enemy.skullshot_attack_frequency_timer > 0.0:
		enemy.skullshot_attack_frequency_timer = max(0.0, enemy.skullshot_attack_frequency_timer - delta)
		if enemy.skullshot_attack_frequency_timer == 0.0:
			enemy.skullshot_attack_frequency_multiplier = 1.0

static func tick_bleed(enemy, delta: float) -> void:
	if enemy.bleed_timer <= 0.0 or enemy.bleed_damage_per_second <= 0.0:
		return

	var bleed_damage: float = enemy.bleed_damage_per_second * delta
	if bleed_damage > 0.0:
		if enemy.has_method("take_batched_damage"):
			enemy.take_batched_damage(bleed_damage)
		else:
			enemy.take_damage(bleed_damage)

static func apply_slow(enemy, multiplier: float, duration: float) -> void:
	_apply_slow(enemy, multiplier, duration, true)

static func apply_slow_without_status_visuals(enemy, multiplier: float, duration: float) -> void:
	_apply_slow(enemy, multiplier, duration, false)

static func _apply_slow(enemy, multiplier: float, duration: float, allow_status_visuals: bool, source_id: String = "") -> void:
	duration = preload("res://scripts/combat/status_resistance.gd").duration(enemy, duration)
	if duration <= 0.0:
		return
	var slow := preload("res://scripts/combat/movement_slow.gd").apply(enemy, source_id, multiplier, duration, enemy.slow_multiplier, enemy.slow_timer)
	var next_multiplier: float = slow.x
	var next_timer: float = slow.y
	var should_refresh_visual: bool = next_multiplier < enemy.slow_multiplier or next_timer > enemy.slow_timer + _get_status_visual_refresh_epsilon(enemy)
	enemy.slow_multiplier = next_multiplier
	enemy.slow_timer = next_timer
	if allow_status_visuals and should_refresh_visual:
		if not _should_suppress_normal_status_visuals(enemy):
			enemy._ensure_status_visuals()
		enemy._spawn_status_burst(Color(0.56, 0.92, 1.0, 0.28), 22.0)

static func apply_vulnerability(enemy, bonus: float, duration: float) -> void:
	duration = preload("res://scripts/combat/status_resistance.gd").duration(enemy, duration)
	if duration <= 0.0:
		return
	var next_bonus: float = max(enemy.vulnerability_bonus, bonus)
	var next_timer: float = max(enemy.vulnerability_timer, duration)
	var should_refresh_visual: bool = next_bonus > enemy.vulnerability_bonus or next_timer > enemy.vulnerability_timer + _get_status_visual_refresh_epsilon(enemy)
	enemy.vulnerability_bonus = next_bonus
	enemy.vulnerability_timer = next_timer
	if should_refresh_visual:
		if not _should_suppress_normal_status_visuals(enemy):
			enemy._ensure_status_visuals()
		enemy._spawn_status_burst(Color(1.0, 0.46, 0.36, 0.24), 18.0)

static func apply_bleed(enemy, damage_per_second: float, duration: float) -> void:
	duration = preload("res://scripts/combat/status_resistance.gd").duration(enemy, duration)
	if duration <= 0.0:
		return
	enemy.bleed_damage_per_second = max(enemy.bleed_damage_per_second, damage_per_second)
	enemy.bleed_timer = max(enemy.bleed_timer, duration)

static func apply_mage_wet(enemy, source_owner, duration: float = 4.0) -> void:
	if enemy == null or duration <= 0.0:
		return
	enemy.mage_wet_remaining = maxf(enemy.mage_wet_remaining, duration)
	enemy.mage_wet_tick_remaining = 1.0
	enemy.mage_wet_source = source_owner
	_apply_slow(enemy, 0.70, duration, true, "mage_surge_wet")
	enemy._spawn_status_burst(Color(0.30, 0.72, 1.0, 0.36), 20.0)

static func _get_status_visual_refresh_epsilon(enemy) -> float:
	if enemy == null:
		return STATUS_VISUAL_REFRESH_EPSILON
	if str(enemy.get("enemy_kind")) == "normal" and str(enemy.get("secondary_behavior_id")) == "":
		return NORMAL_STATUS_VISUAL_REFRESH_EPSILON
	return STATUS_VISUAL_REFRESH_EPSILON

static func _should_suppress_normal_status_visuals(enemy) -> bool:
	if enemy == null:
		return false
	if str(enemy.get("enemy_kind")) != "normal" or str(enemy.get("secondary_behavior_id")) != "":
		return false
	if enemy.get("status_root") != null:
		return false
	return enemy.has_method("_is_scene_under_enemy_pressure") and bool(enemy._is_scene_under_enemy_pressure())

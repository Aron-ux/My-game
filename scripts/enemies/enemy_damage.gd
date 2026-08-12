extends RefCounted

const ENEMY_SKULLTOMB_BEHAVIOR := preload("res://scripts/enemies/enemy_skulltomb_behavior.gd")
const ENEMY_BOSS_STATE := preload("res://scripts/enemies/enemy_boss_state.gd")
const PLAYER_GUNNER_BASIC_TALENT_FLOW := preload("res://scripts/player/player_gunner_basic_talent_flow.gd")

static func take_damage(enemy, amount: float, is_critical: bool = false) -> bool:
	return apply_damage(enemy, amount, true, is_critical)

static func apply_damage(enemy, amount: float, show_feedback: bool = true, is_critical: bool = false) -> bool:
	if enemy.enemy_kind == "boss" and (enemy.boss_phase_transition_target > 0 or enemy.boss_phase_three_intro_remaining > 0.0):
		return false
	if enemy.rebirth_timer > 0.0:
		return false
	if enemy.skull_damage_immune_timer > 0.0:
		return false
	var previous_health: float = float(enemy.current_health)
	var adjusted_damage: float = amount * PLAYER_GUNNER_BASIC_TALENT_FLOW.get_enemy_damage_taken_multiplier(enemy) * (1.0 + enemy.vulnerability_bonus)
	enemy.current_health -= adjusted_damage
	var shield_broken := _should_start_boss_shield_break_intro(enemy, previous_health)
	var killed: bool = enemy.current_health <= 0.0 and not shield_broken
	if show_feedback:
		enemy._play_hit_feedback(adjusted_damage, killed, is_critical)
	if shield_broken:
		ENEMY_BOSS_STATE.start_shield_break_intro(enemy)
		return false
	if enemy.enemy_kind == "boss" and killed and int(enemy.boss_phase) < 3:
		ENEMY_BOSS_STATE.start_phase_transition(enemy, int(enemy.boss_phase) + 1)
		return false
	if enemy.enemy_kind == "small_boss" and enemy.behavior_id == "skulltomb" and killed:
		if ENEMY_SKULLTOMB_BEHAVIOR.handle_lethal_damage(enemy):
			return false
	if enemy.enemy_kind == "small_boss" and enemy.behavior_id == "rebirth" and killed and enemy.rebirth_lives_remaining > 0:
		enemy.rebirth_lives_remaining -= 1
		enemy.current_health = enemy.max_health
		enemy.rebirth_timer = enemy.rebirth_delay
		enemy.velocity = Vector2.ZERO
		enemy.throttled_motion_delta = 0.0
		enemy.motion_refresh_frame = -1
		enemy.separation_refresh_frame = -1
		if enemy.target != null and is_instance_valid(enemy.target) and enemy.target.has_method("apply_enemy_slow"):
			enemy.target.apply_enemy_slow(enemy.rebirth_slow_multiplier, enemy.rebirth_slow_duration)
		enemy._spawn_status_burst(Color(0.8, 0.64, 1.0, 0.32), 40.0 + enemy.scale.x * 10.0)
		return false
	if enemy.current_health <= 0.0:
		enemy.defeated.emit(enemy.enemy_kind)
		enemy._drop_experience_gem()
		enemy._maybe_drop_heart()
		enemy._maybe_drop_bones()
		enemy.drop_absorber = null
		if enemy.has_method("clear_runtime_effects_after_defeat"):
			enemy.clear_runtime_effects_after_defeat()
		if enemy.has_method("release_after_defeat") and bool(enemy.release_after_defeat()):
			return true
		enemy.queue_free()
		return true

	return false

static func _should_start_boss_shield_break_intro(enemy, previous_health: float) -> bool:
	if str(enemy.enemy_kind) != "boss" or bool(enemy.boss_shield_break_intro_played):
		return false
	if enemy.boss_phase_transition_target > 0 or enemy.boss_phase_three_intro_remaining > 0.0:
		return false
	var phase_bar_max_health := ENEMY_BOSS_STATE.get_phase_bar_max_health(enemy)
	return previous_health > phase_bar_max_health and float(enemy.current_health) <= phase_bar_max_health

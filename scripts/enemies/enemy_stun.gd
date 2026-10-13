extends RefCounted

# Stun duration belongs to the skill. There is no control meter.
static func apply(enemy, duration: float) -> bool:
	duration = preload("res://scripts/combat/status_resistance.gd").duration(enemy, duration)
	if duration <= 0.0 or enemy.pooled_inactive or enemy.current_health <= 0.0 or enemy.rebirth_timer > 0.0:
		return false
	if enemy.boss_phase_transition_target > 0 or enemy.boss_phase_three_intro_remaining > 0.0:
		return false
	if enemy.enemy_kind == "boss":
		var stage: String = str(enemy.boss_routine.get("stage", "basic"))
		if stage == "recovery":
			return false
		if stage in ["performance", "finishing"]:
			if not bool(enemy.boss_routine.get("stun_extension_recorded", false)):
				enemy.boss_routine["stun_extension_recorded"] = true
				enemy.boss_routine["stun_extension"] = duration
			return false
		if stage == "preview":
			# Cancel the pending cast, preserve already emitted projectiles.
			enemy.boss_routine["stage"] = "basic"
			enemy.boss_routine["elapsed"] = 0.0
			enemy.boss_routine["events"] = 0
			enemy.ENEMY_BOSS_VISUALS.clear_boss_phase_three_charge_visuals(enemy)
		enemy.boss_aimed_shots_remaining = 0
		enemy.boss_peacock_charge_remaining = 0.0
		enemy._clear_boss_peacock_markers()
	enemy.stun_remaining = maxf(enemy.stun_remaining, duration)
	enemy.dash_remaining = 0.0
	enemy.dash_distance_remaining = 0.0
	enemy.dash_windup_remaining = 0.0
	enemy.skulltomb_charge_windup_remaining = 0.0
	enemy.skulltomb_summon_windup_remaining = 0.0
	if enemy.behavior_id == "skulltomb":
		preload("res://scripts/enemies/enemy_skulltomb_behavior.gd")._clear_channel_ring(enemy)
	if enemy.dash_warning_rect != null and is_instance_valid(enemy.dash_warning_rect):
		enemy.dash_warning_rect.visible = false
	if enemy.behavior_id == "rose":
		var rose = preload("res://scripts/enemies/enemy_rose_behavior.gd")
		var scene: Node = enemy.get_tree().current_scene
		for key in [rose.ACTIVE_SPLITS_META_KEY, rose.ACTIVE_BOMBARDS_META_KEY]:
			var active: Array = scene.get_meta(key, [])
			for index in range(active.size() - 1, -1, -1):
				var sequence: Dictionary = active[index]
				if rose._get_enemy_from_sequence(sequence) == enemy and str(sequence.get("phase", "warning")) == "warning":
					rose._release_sequence_visuals(sequence)
					active.remove_at(index)
			scene.set_meta(key, active)
	if bool(enemy._is_glutton):
		enemy.ENEMY_GLUTTON_SKILL_BEHAVIOR._clear_warnings(enemy)
	enemy.glutton_cast_lock_active = false
	enemy.glutton_skill_state = ""
	enemy.glutton_skill_state_remaining = 0.0
	enemy.glutton_skill_action = ""
	enemy.glutton_skill_action_remaining = 0.0
	enemy.velocity = Vector2.ZERO
	enemy.throttled_motion_delta = 0.0
	enemy.motion_refresh_frame = -1
	enemy._spawn_status_burst(Color(1.0, 0.85, 0.3, 0.7), 24.0)
	return true

static func tick(enemy, delta: float) -> bool:
	if enemy.stun_remaining <= 0.0:
		return false
	if enemy.boss_phase_transition_target > 0 or enemy.boss_phase_three_intro_remaining > 0.0 or enemy.rebirth_timer > 0.0:
		enemy.stun_remaining = 0.0
		return false
	enemy.stun_remaining = maxf(0.0, enemy.stun_remaining - delta)
	# Cooldowns progress but clamp at ready; they never queue missed attacks.
	for key in ["shot_timer", "basic_shot_timer", "dash_timer", "acceleration_timer",
			"turret_bombard_timer", "rose_split_timer", "skulltomb_summon_timer",
			"skulltomb_charge_timer", "skulltomb_charge_decision_timer",
			"boss_radial_timer", "boss_sine_cooldown", "boss_split_timer",
			"boss_laser_timer", "boss_orbit_bomb_timer", "boss_peacock_timer"]:
		enemy.set(key, maxf(0.0, float(enemy.get(key)) - delta))
	# Existing ground effects and independent attacks keep their lifetimes.
	if bool(enemy._is_glutton):
		var tree_skills = enemy.ENEMY_GLUTTON_SKILL_BEHAVIOR
		tree_skills._tick_twine_hitboxes(enemy, delta)
		tree_skills._tick_wood_spike_hitboxes(enemy, delta)
		tree_skills._tick_war_stomp_cooldown(enemy, delta)
		tree_skills._tick_war_stomp(enemy, delta)
		tree_skills._tick_entangle_damage(enemy, delta)
	if enemy.behavior_id == "skulltomb":
		var tomb = preload("res://scripts/enemies/enemy_skulltomb_behavior.gd")
		tomb._update_summon_area(enemy, delta)
		tomb._update_pending_spawns(enemy, delta)
	if enemy.behavior_id == "rose":
		var rose = preload("res://scripts/enemies/enemy_rose_behavior.gd")
		rose._update_active_sequences(enemy.get_tree().current_scene, delta)
	if enemy.enemy_kind == "boss":
		preload("res://scripts/enemies/enemy_boss_attacks.gd").update_lasers(enemy, delta)
	enemy.velocity = Vector2.ZERO
	enemy.throttled_motion_delta = 0.0
	enemy._update_motion_visual()
	return true

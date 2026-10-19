extends RefCounted
const ARMOR_RULES := preload("res://scripts/combat/armor_rules.gd")
const HEAVY_ARMOR := preload("res://scripts/enemies/enemy_heavy_armor_form.gd")
const ENEMY_DROPS := preload("res://scripts/enemies/enemy_drops.gd")

const ENEMY_SKULLTOMB_BEHAVIOR := preload("res://scripts/enemies/enemy_skulltomb_behavior.gd")
const ENEMY_BOSS_STATE := preload("res://scripts/enemies/enemy_boss_state.gd")
const ENEMY_GLUTTON_SKILL_BEHAVIOR := preload("res://scripts/enemies/enemy_glutton_skill_behavior.gd")
const ENEMY_MUSHROOM_SWARM := preload("res://scripts/enemies/enemy_mushroom_swarm.gd")
const PLAYER_GUNNER_BASIC_TALENT_FLOW := preload("res://scripts/player/player_gunner_basic_talent_flow.gd")
const PLAYER_COMBAT_MODIFIERS := preload("res://scripts/player/player_combat_modifiers.gd")
const VULNERABILITY_RULES := preload("res://scripts/combat/vulnerability_rules.gd")

static func take_damage(enemy, amount: float, is_critical: bool = false) -> bool:
	return apply_damage(enemy, amount, true, is_critical)

static func apply_damage(enemy, amount: float, show_feedback: bool = true, is_critical: bool = false, ignore_armor: bool = false, direct_damage: bool = false, bypass_shield: bool = true) -> bool:
	if enemy.has_meta("wave_cleanup"):
		return false
	var mage := preload("res://scripts/enemies/enemy_skull_mage.gd")
	if mage.is_invulnerable(enemy):
		return false
	if enemy.enemy_kind == "boss" and (enemy.boss_phase_transition_target > 0 or enemy.boss_phase_three_intro_remaining > 0.0):
		return false
	if enemy.rebirth_timer > 0.0:
		return false
	if enemy.skull_damage_immune_timer > 0.0:
		return false
	if amount <= 0.0:
		return false
	var electric_damage := 0.0
	var electric_armor_shred: float = enemy.electric_stacks * 10.0
	if enemy.electric_stacks >= 3:
		enemy.electric_stacks = 0
		var player = enemy.target
		if player != null and is_instance_valid(player) and player.has_method("_get_role_damage") and player.has_method("_get_active_role"):
			electric_damage = float(player._get_role_damage(str(player._get_active_role()["id"]))) * 3.0
		preload("res://scripts/enemies/enemy_electric_visual.gd").flash(enemy)
	var previous_health: float = float(enemy.current_health)
	var porcupine := preload("res://scripts/enemies/enemy_porcupine.gd")
	var was_enraged := porcupine.is_enraged(enemy)
	# Damage order: total damage -> defense (armor) -> damage reduction -> HP.
	var armor_value: Variant = enemy.get("armor")
	var effective_armor: float = float(armor_value) if armor_value != null else 0.0
	if was_enraged:
		effective_armor -= 20.0
	effective_armor += ENEMY_MUSHROOM_SWARM.get_armor_bonus(enemy)
	if mage.is_ice_active(enemy):
		effective_armor += 10.0
	effective_armor -= electric_armor_shred
	effective_armor -= enemy.storm_armor_shred_timers.size() * 2.0
	if enemy.enemy_kind == "boss":
		effective_armor += ENEMY_BOSS_STATE.get_shield_armor_bonus(enemy)
		effective_armor += ENEMY_BOSS_STATE.ROUTINE.get_armor_modifier(enemy)
	var fury_shred: Variant = enemy.get("fury_armor_shred")
	effective_armor -= float(fury_shred) if fury_shred != null else 0.0
	if HEAVY_ARMOR.is_active(enemy):
		effective_armor += HEAVY_ARMOR.get_armor_bonus(enemy)
	var armored_damage: float = amount if ignore_armor else ARMOR_RULES.apply_damage(amount, effective_armor)
	var damage_reduction_rate := PLAYER_COMBAT_MODIFIERS.calculate_damage_reduction_rate(PLAYER_GUNNER_BASIC_TALENT_FLOW.get_effective_damage_reduction_value(enemy))
	var damage_reduction_multiplier: float = max(0.0, 1.0 - damage_reduction_rate)
	var base_reduction: Variant = enemy.get("damage_reduction_rate")
	var base_reduction_rate: float = float(base_reduction) if base_reduction != null else 0.0
	if was_enraged:
		base_reduction_rate = 0.0
	if enemy.enemy_kind == "boss":
		base_reduction_rate += ENEMY_BOSS_STATE.get_shield_reduction_bonus(enemy)
	damage_reduction_multiplier *= max(0.0, 1.0 - base_reduction_rate)
	if mage.is_ice_active(enemy):
		damage_reduction_multiplier *= 0.8
	damage_reduction_multiplier *= max(0.0, ENEMY_GLUTTON_SKILL_BEHAVIOR.get_damage_taken_multiplier(enemy))
	var vulnerability_multiplier := VULNERABILITY_RULES.get_multiplier(maxf(0.0, float(enemy.vulnerability_bonus)))
	var adjusted_damage: float = amount * vulnerability_multiplier if direct_damage else armored_damage * vulnerability_multiplier * damage_reduction_multiplier
	adjusted_damage += ARMOR_RULES.apply_damage(electric_damage, effective_armor) * vulnerability_multiplier * damage_reduction_multiplier
	if direct_damage and bypass_shield and ENEMY_BOSS_STATE.has_boss_shield(enemy):
		# Shield is stored above the phase health bar. Track bypassed HP
		# separately so direct hits cannot consume it or fire shield-break.
		var health_left: float = ENEMY_BOSS_STATE.get_phase_bar_max_health(enemy) - enemy.boss_direct_health_loss
		var bypassed: float = minf(amount * vulnerability_multiplier, maxf(0.0, health_left))
		enemy.boss_direct_health_loss += bypassed
		adjusted_damage = bypassed + ARMOR_RULES.apply_damage(electric_damage, effective_armor) * damage_reduction_multiplier
	enemy.current_health -= mage.absorb_temporary_health(enemy, adjusted_damage)
	if mage.is_ice_active(enemy) and is_instance_valid(enemy.target):
		preload("res://scripts/player/player_skull_mage_effects.gd").on_enemy_damage(enemy.target, enemy, adjusted_damage)
	mage.try_death_save(enemy)
	porcupine.accumulate(enemy, amount + electric_damage)
	if porcupine.is_porcupine(enemy):
		porcupine.show_quill_burst(enemy, porcupine.crossed_health_thresholds(enemy.max_health, previous_health, maxf(0, enemy.current_health)))
	if enemy.current_health <= 0.0:
		ENEMY_MUSHROOM_SWARM.invalidate_cache()
	HEAVY_ARMOR.reflect_damage(enemy, minf(maxf(0.0, previous_health), maxf(0.0, adjusted_damage)))
	var shield_broken := (not direct_damage or not bypass_shield) and _should_start_boss_shield_break_intro(enemy, previous_health)
	if direct_damage and bypass_shield and not enemy.boss_shield_break_intro_played and enemy.boss_direct_health_loss >= ENEMY_BOSS_STATE.get_phase_bar_max_health(enemy):
		enemy.stun_remaining = 0.0
		enemy.boss_shield_break_intro_played = true
		ENEMY_BOSS_STATE.start_phase_transition(enemy, int(enemy.boss_phase) + 1)
		return false
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
			enemy.target.apply_enemy_slow(enemy.rebirth_slow_multiplier, enemy.rebirth_slow_duration, "rebirth")
		enemy._spawn_status_burst(Color(0.8, 0.64, 1.0, 0.32), 40.0 + enemy.scale.x * 10.0)
		return false
	if enemy.current_health <= 0.0:
		enemy.defeated.emit(enemy.enemy_kind)
		enemy._drop_experience_gem()
		enemy._maybe_drop_heart()
		enemy._maybe_drop_bones()
		ENEMY_DROPS.maybe_drop_experience_vacuum(enemy)
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
	var phase_bar_max_health: float = ENEMY_BOSS_STATE.get_phase_bar_max_health(enemy) - enemy.boss_direct_health_loss
	return previous_health > phase_bar_max_health and float(enemy.current_health) <= phase_bar_max_health

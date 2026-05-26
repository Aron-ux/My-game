extends RefCounted

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")

const ULTIMATE_ENERGY_GAIN_GLOBAL_MULTIPLIER := 0.715
const SMALL_ENEMY_KILL_ENERGY_MULTIPLIER := 0.75
const BACKGROUND_ULTIMATE_ENERGY_GAIN_RATIO := 0.3
const LIFESTEAL_PROC_HEAL_AMOUNT := 1.0
const LIFESTEAL_PROC_COOLDOWN := 0.15
const SWORDSMAN_TRAIT_HEAL_COOLDOWN := 3.0
const GREED_HEAL_COOLDOWN := 3.0
const LIFESTEAL_MAX_ROLL_HITS := 6
const LIFESTEAL_MAX_PROC_CHANCE := 0.80


static func add_kill_energy(owner, amount: float, bypass_lock_role_id: String = "") -> void:
	if amount <= 0.0:
		return
	var active_role_id: String = owner._get_active_role_id()
	for role_data in owner.roles:
		var role_id: String = str(role_data.get("id", ""))
		if role_id == "":
			continue
		if role_id != bypass_lock_role_id and owner._get_role_ultimate_lock_remaining(role_id) > 0.0 and not DEVELOPER_MODE.should_unlock_ultimate_freely():
			continue
		var gain_scale: float = 1.0 if role_id == active_role_id else BACKGROUND_ULTIMATE_ENERGY_GAIN_RATIO
		var base_energy_gain_multiplier: float = owner.energy_gain_multiplier - owner.equipment_energy_gain_bonus + owner._get_role_equipment_energy_gain_bonus(role_id)
		var adjusted_amount: float = amount * ULTIMATE_ENERGY_GAIN_GLOBAL_MULTIPLIER * gain_scale * max(0.01, base_energy_gain_multiplier) * owner._get_ultimate_energy_gain_multiplier_for_role(role_id)
		if adjusted_amount <= 0.0:
			continue
		var updated_mana: float = owner._add_role_mana(role_id, adjusted_amount, false)
		if role_id == active_role_id and owner._has_elite_relic("elite_reactor") and is_equal_approx(updated_mana, owner.max_mana):
			owner._activate_switch_power(active_role_id, "\u6EE1\u80FD\u53CD\u5E94", 2.8, 1.14, 0.04)
	owner._emit_active_mana_changed()


static func get_kill_energy_from_enemy(enemy: Node) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return 0.0
	var enemy_kind: String = str(enemy.get("enemy_kind"))
	if enemy_kind == "boss":
		return 0.0
	if enemy_kind == "elite":
		return 10.0 * SMALL_ENEMY_KILL_ENERGY_MULTIPLIER
	var reward_tier: int = int(enemy.get("reward_tier"))
	match reward_tier:
		2:
			return 1.1 * SMALL_ENEMY_KILL_ENERGY_MULTIPLIER
		3:
			return 1.5 * SMALL_ENEMY_KILL_ENERGY_MULTIPLIER
		4:
			return 2.0 * SMALL_ENEMY_KILL_ENERGY_MULTIPLIER
		_:
			return 0.8 * SMALL_ENEMY_KILL_ENERGY_MULTIPLIER


static func get_boss_damage_energy(damage_amount: float) -> float:
	if damage_amount <= 0.0:
		return 0.0
	var energy_amount: float = sqrt(damage_amount) * 0.18
	return clamp(energy_amount, 0.25, 2.0)


static func register_attack_result(owner, role_id: String, hit_count: int, killed: bool, kill_count: int = 0) -> void:
	apply_swordsman_trait_heal_on_kill(owner, role_id, killed, kill_count)
	apply_greed_heal_on_kill(owner, killed, kill_count)
	apply_role_flat_heal_on_hit(owner, role_id, hit_count)
	apply_entry_lifesteal(owner, role_id, hit_count, killed)
	if killed and owner._has_elite_relic("elite_execution_pact") and not owner.execution_pact_burst_active:
		owner.execution_pact_burst_active = true
		owner._spawn_burst_effect(owner.global_position + owner.facing_direction * 20.0, 42.0, Color(1.0, 0.62, 0.4, 0.16), 0.16)
		owner._damage_enemies_in_radius(owner.global_position + owner.facing_direction * 20.0, 42.0, owner._get_role_damage(role_id) * 0.34, 0.0, 1.0, 0.0)
		owner.execution_pact_burst_active = false
	if killed and owner._has_elite_relic("elite_battle_frenzy"):
		var previous_stacks: int = owner.frenzy_stacks
		owner.frenzy_stacks = min(8, owner.frenzy_stacks + 1)
		owner.frenzy_remaining = 5.0
		if previous_stacks >= 8 and owner.frenzy_stacks >= 8:
			owner.frenzy_overkill_counter += 1
			if owner.frenzy_overkill_counter >= 6:
				owner.frenzy_overkill_counter = 0


static func apply_theme_hit_returns(owner, role_id: String, hit_count: int, killed: bool) -> void:
	return


static func apply_swordsman_trait_heal_on_kill(owner, role_id: String, killed: bool, kill_count: int = 0) -> void:
	if not killed:
		return
	if owner.swordsman_trait_heal_cooldown_remaining > 0.0:
		return
	var heal_amount: float = owner._get_swordsman_trait_heal_amount() if owner.has_method("_get_swordsman_trait_heal_amount") else 0.0
	if heal_amount <= 0.0:
		return
	var proc_chance: float = owner._get_swordsman_trait_heal_proc_chance() if owner.has_method("_get_swordsman_trait_heal_proc_chance") else 0.0
	var proc_rolls: int = max(1, kill_count)
	var combined_chance: float = 1.0 - pow(max(0.0, 1.0 - clamp(proc_chance, 0.0, 1.0)), float(proc_rolls))
	if combined_chance <= 0.0 or randf() > combined_chance:
		return
	owner.swordsman_trait_heal_cooldown_remaining = SWORDSMAN_TRAIT_HEAL_COOLDOWN
	owner._heal(heal_amount)


static func apply_greed_heal_on_kill(owner, killed: bool, kill_count: int = 0) -> void:
	if not killed:
		return
	if owner.greed_heal_cooldown_remaining > 0.0:
		return
	var heal_amount: float = PLAYER_BLESSING_SYSTEM.get_greed_heal_amount(owner)
	if heal_amount <= 0.0:
		return
	var proc_chance: float = PLAYER_BLESSING_SYSTEM.get_greed_proc_chance(owner)
	var proc_rolls: int = max(1, kill_count)
	var combined_chance: float = 1.0 - pow(max(0.0, 1.0 - clamp(proc_chance, 0.0, 1.0)), float(proc_rolls))
	if combined_chance <= 0.0 or randf() > combined_chance:
		return
	owner.greed_heal_cooldown_remaining = GREED_HEAL_COOLDOWN
	owner._heal(heal_amount)


static func try_apply_mage_kill_energy_proc(owner, source_role_id: String, base_energy: float, bypass_lock_role_id: String = "") -> void:
	if base_energy <= 0.0:
		return
	var proc_chance: float = owner._get_mage_kill_energy_proc_chance() if owner.has_method("_get_mage_kill_energy_proc_chance") else 0.0
	if proc_chance <= 0.0 or randf() > clamp(proc_chance, 0.0, 1.0):
		return
	var multiplier: float = owner._get_mage_kill_energy_proc_multiplier() if owner.has_method("_get_mage_kill_energy_proc_multiplier") else 3.0
	owner._add_kill_energy(base_energy * max(0.0, multiplier - 1.0), bypass_lock_role_id)


static func apply_role_flat_heal_on_hit(owner, role_id: String, hit_count: int) -> void:
	if role_id == "" or hit_count <= 0:
		return
	if owner.lifesteal_proc_cooldown_remaining > 0.0:
		return
	var proc_chance: float = owner._get_role_blessing_stat_bonus(role_id, "flat_heal_on_hit")
	if proc_chance <= 0.0:
		return
	if role_id == "swordsman":
		var special_data: Dictionary = owner._get_role_special_state("swordsman")
		if float(special_data.get("ultimate_lifesteal_multiplier_remaining", 0.0)) > 0.0:
			proc_chance *= max(0.0, float(special_data.get("ultimate_lifesteal_chance_multiplier", 2.0)))
	var capped_hits: int = min(hit_count, LIFESTEAL_MAX_ROLL_HITS)
	var combined_chance: float = 1.0 - pow(max(0.0, 1.0 - proc_chance), float(capped_hits))
	if randf() > clamp(combined_chance, 0.0, LIFESTEAL_MAX_PROC_CHANCE):
		return
	owner.lifesteal_proc_cooldown_remaining = LIFESTEAL_PROC_COOLDOWN
	owner._heal(LIFESTEAL_PROC_HEAL_AMOUNT)


static func apply_entry_lifesteal(owner, role_id: String, hit_count: int, killed: bool) -> void:
	if owner.entry_blessing_remaining <= 0.0:
		return
	if owner.entry_blessing_role_id != role_id:
		return
	if owner.entry_lifesteal_ratio <= 0.0 or hit_count <= 0:
		return

	var capped_hits: int = min(hit_count, 6)
	var estimated_damage: float = owner._get_role_damage(role_id) * float(capped_hits) * 0.55
	if killed:
		estimated_damage += owner._get_role_damage(role_id) * 0.35
	var heal_amount: float = estimated_damage * owner.entry_lifesteal_ratio
	if heal_amount > 0.0:
		owner._heal(heal_amount)


static func trigger_chain_reaction(owner, role_id: String) -> void:
	return


static func trigger_clean_tide(owner, role_id: String) -> void:
	return


static func spawn_attack_aftershock(owner, center: Vector2, role_id: String) -> void:
	return


static func play_player_hurt_feedback(owner) -> void:
	owner._queue_camera_shake(6.0, 0.16)
	owner._pulse_player_visual(1.18, 0.16)
	owner._spawn_burst_effect(owner.get_hurtbox_center(), 54.0, Color(1.0, 0.3, 0.3, 0.18), 0.16)


static func trigger_swordsman_counter(owner) -> void:
	var special_data: Dictionary = owner._get_role_special_state("swordsman")
	var counter_level: int = int(special_data.get("counter_level", 0))
	if counter_level <= 0:
		return

	var radius: float = 62.0 + counter_level * 14.0
	var damage_amount: float = owner._get_role_damage("swordsman") * (0.38 + counter_level * 0.14)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -24.0), "\u53CD\u51FB", Color(1.0, 0.84, 0.48, 1.0))
	owner._spawn_guard_effect(owner.global_position, radius, Color(1.0, 0.84, 0.46, 0.22), 0.18)
	owner._spawn_burst_effect(owner.global_position, radius, Color(1.0, 0.76, 0.38, 0.22), 0.16)
	var hits: int = owner._damage_enemies_in_radius(owner.global_position, radius, damage_amount, 0.08 * counter_level, 1.0, 0.0)
	if hits > 0:
		owner._register_attack_result("swordsman", hits, false)
		owner._heal(0.6 + counter_level * 0.25)
		owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, 0.05 + counter_level * 0.02)


static func count_enemies_in_radius(owner, center: Vector2, radius: float) -> int:
	return PLAYER_DAMAGE_RESOLVER.count_enemies_in_radius(owner, center, radius)

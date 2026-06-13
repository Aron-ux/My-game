extends RefCounted

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const ROLE_RESOURCE_STATE := preload("res://scripts/player/roles/role_resource_state.gd")
const MAGE_ARCANE_SURPLUS_EXPIRE_CHARGE_STACKS := 3


static func update_timers(owner, delta: float) -> void:
	owner.role_visual_time += delta
	if owner.has_method("_tick_duration_statuses"):
		owner._tick_duration_statuses(delta)
	ROLE_RESOURCE_STATE.tick_locks(owner.role_ultimate_energy_lock_remaining, owner.roles, delta)
	owner._sync_active_role_ultimate_state()
	if owner.hurt_cooldown_remaining > 0.0:
		owner.hurt_cooldown_remaining = max(0.0, owner.hurt_cooldown_remaining - delta)
	if owner.switch_invulnerability_remaining > 0.0:
		owner.switch_invulnerability_remaining = max(0.0, owner.switch_invulnerability_remaining - delta)
	if owner.hidden_invulnerability_status_remaining > 0.0:
		owner.hidden_invulnerability_status_remaining = max(0.0, owner.hidden_invulnerability_status_remaining - delta)
	if owner.has_method("_sync_invulnerability_status"):
		owner._sync_invulnerability_status()
	if owner.level_up_delay_remaining > 0.0:
		owner.level_up_delay_remaining = max(0.0, owner.level_up_delay_remaining - delta)
		if owner.level_up_delay_remaining <= 0.0:
			owner._try_request_level_up()
	if owner.switch_cooldown_remaining > 0.0:
		owner.switch_cooldown_remaining = max(0.0, owner.switch_cooldown_remaining - delta)
	if owner.lifesteal_proc_cooldown_remaining > 0.0:
		owner.lifesteal_proc_cooldown_remaining = max(0.0, owner.lifesteal_proc_cooldown_remaining - delta)
	if owner.swordsman_trait_heal_cooldown_remaining > 0.0:
		owner.swordsman_trait_heal_cooldown_remaining = max(0.0, owner.swordsman_trait_heal_cooldown_remaining - delta)
	if owner.swordsman_death_defiance_will_remaining > 0.0:
		owner.swordsman_death_defiance_will_remaining = max(0.0, owner.swordsman_death_defiance_will_remaining - delta)
		if owner.swordsman_death_defiance_will_remaining <= 0.0:
			owner.swordsman_death_defiance_cooldown_remaining = owner.SWORDSMAN_DEATH_DEFIANCE_COOLDOWN
	if owner.swordsman_death_defiance_cooldown_remaining > 0.0:
		owner.swordsman_death_defiance_cooldown_remaining = max(0.0, owner.swordsman_death_defiance_cooldown_remaining - delta)
	if owner.swordsman_entry_trait_share_remaining > 0.0:
		owner.swordsman_entry_trait_share_remaining = max(0.0, owner.swordsman_entry_trait_share_remaining - delta)
		if owner.swordsman_entry_trait_share_remaining > 0.0:
			owner.swordsman_bloodthirst_heal_multiplier = max(owner.swordsman_bloodthirst_heal_multiplier, 1.0)
		else:
			owner.swordsman_bloodthirst_heal_multiplier = 1.0
	else:
		owner.swordsman_bloodthirst_heal_multiplier = 1.0
	if owner.mage_arcane_surplus_remaining > 0.0:
		var previous_arcane_surplus_remaining: float = owner.mage_arcane_surplus_remaining
		owner.mage_arcane_surplus_remaining = max(0.0, owner.mage_arcane_surplus_remaining - delta)
		var active_role_id: String = str(owner._get_active_role().get("id", "")) if owner.has_method("_get_active_role") else ""
		if previous_arcane_surplus_remaining > 0.0 and owner.mage_arcane_surplus_remaining <= 0.0 and active_role_id == "mage" and owner.has_method("_add_mage_arcane_charge_stacks"):
			owner._add_mage_arcane_charge_stacks(MAGE_ARCANE_SURPLUS_EXPIRE_CHARGE_STACKS)
		if owner.has_method("_sync_duration_status"):
			owner._sync_duration_status("mage_arcane_surplus", "\u5965\u6CD5\u76C8\u4F59", owner.mage_arcane_surplus_remaining, 18, Color(0.34, 0.72, 1.0, 0.95))
	if owner.mage_arcane_charge_transfer_remaining > 0.0:
		owner.mage_arcane_charge_transfer_remaining = max(0.0, owner.mage_arcane_charge_transfer_remaining - delta)
		if owner.mage_arcane_charge_transfer_remaining <= 0.0 and owner.has_method("_clear_mage_arcane_charge_transfer"):
			owner._clear_mage_arcane_charge_transfer()
	if owner.greed_heal_cooldown_remaining > 0.0:
		owner.greed_heal_cooldown_remaining = max(0.0, owner.greed_heal_cooldown_remaining - delta)
	if owner.has_method("_tick_gunner_flash_trait"):
		owner._tick_gunner_flash_trait(delta)
	var swordsman_special: Dictionary = owner._get_role_special_state("swordsman")
	if float(swordsman_special.get("ultimate_lifesteal_multiplier_remaining", 0.0)) > 0.0:
		swordsman_special["ultimate_lifesteal_multiplier_remaining"] = max(0.0, float(swordsman_special.get("ultimate_lifesteal_multiplier_remaining", 0.0)) - delta)
		owner.role_special_states["swordsman"] = swordsman_special
	if owner.enemy_move_slow_remaining > 0.0:
		owner.enemy_move_slow_remaining = max(0.0, owner.enemy_move_slow_remaining - delta)
		if owner.enemy_move_slow_remaining <= 0.0:
			owner.enemy_move_slow_multiplier = 1.0
	if owner.gunner_infinite_reload_ability != null:
		owner.gunner_infinite_reload_ability.update(owner, delta)
	if owner.gunner_shrapnel_field_ability != null:
		owner.gunner_shrapnel_field_ability.update(owner, delta)
	if owner.mage_tidal_surge_ability != null:
		owner.mage_tidal_surge_ability.update(delta)
	if owner.mage_meta_field_ability != null:
		owner.mage_meta_field_ability.update(owner, delta)
	if owner.swordsman_blade_storm_ability != null:
		owner.swordsman_blade_storm_ability.update(owner, delta)
	if owner.swordsman_crescent_wave_ability != null:
		owner.swordsman_crescent_wave_ability.update(delta)
	owner._try_trigger_swordsman_blade_storm()
	owner._try_trigger_swordsman_crescent_wave()
	owner._try_trigger_gunner_infinite_reload()
	owner._try_trigger_gunner_shrapnel_field()
	owner._try_trigger_mage_tidal_surge()
	owner._try_trigger_mage_meta_field()
	if owner.perpetual_motion_cooldown_remaining > 0.0:
		owner.perpetual_motion_cooldown_remaining = max(0.0, owner.perpetual_motion_cooldown_remaining - delta)
	apply_developer_no_cooldown(owner)
	if owner.switch_power_remaining > 0.0:
		owner.switch_power_remaining = max(0.0, owner.switch_power_remaining - delta)
		if owner.switch_power_remaining <= 0.0:
			owner.switch_power_role_id = ""
			owner.switch_power_damage_multiplier = 1.0
			owner.switch_power_interval_bonus = 0.0
			owner.switch_power_label = ""
			owner._update_fire_timer()
	if owner.entry_blessing_remaining > 0.0:
		owner.entry_blessing_remaining = max(0.0, owner.entry_blessing_remaining - delta)
		if owner.entry_blessing_remaining <= 0.0:
			owner._clear_entry_blessing()
	if owner.ultimate_haste_remaining > 0.0:
		owner.ultimate_haste_remaining = max(0.0, owner.ultimate_haste_remaining - delta)
		if owner.ultimate_haste_remaining <= 0.0:
			owner.ultimate_haste_move_speed_multiplier = 1.0
			owner.ultimate_haste_dodge_chance = 0.0
	if owner.entry_rescue_remaining > 0.0:
		owner.entry_rescue_remaining = max(0.0, owner.entry_rescue_remaining - delta)
		if owner.entry_rescue_regen_per_second > 0.0:
			owner._heal(owner.entry_rescue_regen_per_second * delta)
		if owner.entry_rescue_remaining <= 0.0:
			owner.entry_rescue_regen_per_second = 0.0
	if owner.standby_entry_remaining > 0.0:
		owner.standby_entry_remaining = max(0.0, owner.standby_entry_remaining - delta)
		if owner.standby_entry_remaining <= 0.0:
			owner._clear_standby_entry_buff()
	if owner.guard_cover_remaining > 0.0:
		owner.guard_cover_remaining = max(0.0, owner.guard_cover_remaining - delta)
		if owner.guard_cover_remaining <= 0.0:
			owner.guard_cover_damage_multiplier = 1.0
	if owner.borrow_fire_remaining > 0.0:
		owner.borrow_fire_remaining = max(0.0, owner.borrow_fire_remaining - delta)
		if owner.borrow_fire_remaining <= 0.0:
			owner.borrow_fire_role_id = ""
			owner.borrow_fire_damage_multiplier = 1.0
			owner.borrow_fire_interval_bonus = 0.0
			owner.borrow_fire_background_multiplier = 1.0
			owner._update_fire_timer()
	if owner.post_ultimate_flow_remaining > 0.0:
		owner.post_ultimate_flow_remaining = max(0.0, owner.post_ultimate_flow_remaining - delta)
		if owner.post_ultimate_flow_remaining <= 0.0:
			owner.post_ultimate_flow_background_multiplier = 1.0
	if owner.ultimate_guard_remaining > 0.0:
		owner.ultimate_guard_remaining = max(0.0, owner.ultimate_guard_remaining - delta)
		if owner.ultimate_guard_remaining <= 0.0:
			owner.ultimate_guard_damage_multiplier = 1.0
	if owner.player_action_lock_remaining > 0.0:
		owner.player_action_lock_remaining = max(0.0, owner.player_action_lock_remaining - delta)
	if owner.frenzy_remaining > 0.0:
		owner.frenzy_remaining = max(0.0, owner.frenzy_remaining - delta)
		if owner.frenzy_remaining <= 0.0:
			owner.frenzy_stacks = 0
			owner.frenzy_overkill_counter = 0
	for role_data in owner.roles:
		var role_id: String = str(role_data.get("id", ""))
		if role_id == str(owner._get_active_role().get("id", "")):
			owner.role_standby_elapsed[role_id] = 0.0
		else:
			owner.role_standby_elapsed[role_id] = float(owner.role_standby_elapsed.get(role_id, 0.0)) + delta
	owner._update_camera_shake(delta)


static func apply_developer_no_cooldown(owner) -> void:
	if not DEVELOPER_MODE.should_ignore_cooldowns():
		return
	owner.switch_cooldown_remaining = 0.0
	owner.perpetual_motion_cooldown_remaining = 0.0
	if owner.gunner_infinite_reload_ability != null:
		owner.gunner_infinite_reload_ability.cooldown_remaining = 0.0
	if owner.gunner_shrapnel_field_ability != null:
		owner.gunner_shrapnel_field_ability.cooldown_remaining = 0.0
	if owner.mage_tidal_surge_ability != null:
		owner.mage_tidal_surge_ability.cooldown_remaining = 0.0
	if owner.mage_meta_field_ability != null:
		owner.mage_meta_field_ability.cooldown_remaining = 0.0
	if owner.swordsman_blade_storm_ability != null:
		owner.swordsman_blade_storm_ability.cooldown_remaining = 0.0
	if owner.swordsman_crescent_wave_ability != null:
		owner.swordsman_crescent_wave_ability.cooldown_remaining = 0.0

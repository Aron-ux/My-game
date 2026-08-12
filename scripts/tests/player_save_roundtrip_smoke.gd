extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")

const EXACT_KEYS := [
	"position",
	"level",
	"experience",
	"experience_to_next_level",
	"pending_level_ups",
	"role_health_values",
	"temporary_health_stacks",
	"role_temporary_health_values",
	"role_mana_values",
	"role_ultimate_energy_lock_remaining",
	"hurt_cooldown_remaining",
	"switch_invulnerability_remaining",
	"level_up_delay_remaining",
	"switch_cooldown_remaining",
	"greed_heal_cooldown_remaining",
	"enemy_move_slow_multiplier",
	"enemy_move_slow_remaining",
	"ability_runtime",
	"gunner_infinite_reload_cooldown_remaining",
	"gunner_infinite_reload_remaining",
	"gunner_infinite_reload_tick_remaining",
	"gunner_shrapnel_field_cooldown_remaining",
	"mage_tidal_surge_cooldown_remaining",
	"mage_meta_field_cooldown_remaining",
	"mage_meta_field_remaining",
	"mage_meta_field_tick_remaining",
	"mage_meta_field_transferred_role_id",
	"swordsman_blade_storm_cooldown_remaining",
	"swordsman_blade_storm_remaining",
	"swordsman_blade_storm_tick_remaining",
	"swordsman_crescent_wave_cooldown_remaining",
	"switch_power_remaining",
	"switch_power_role_id",
	"switch_power_damage_multiplier",
	"switch_power_interval_bonus",
	"switch_power_label",
	"pending_entry_blessing_source_role_id",
	"entry_blessing_role_id",
	"entry_blessing_label",
	"entry_blessing_remaining",
	"entry_lifesteal_ratio",
	"entry_haste_interval_bonus",
	"entry_haste_move_speed_multiplier",
	"standby_entry_role_id",
	"standby_entry_label",
	"standby_entry_remaining",
	"standby_entry_damage_multiplier",
	"standby_entry_interval_bonus",
	"guard_cover_remaining",
	"guard_cover_damage_multiplier",
	"borrow_fire_role_id",
	"borrow_fire_remaining",
	"borrow_fire_damage_multiplier",
	"borrow_fire_interval_bonus",
	"borrow_fire_background_multiplier",
	"post_ultimate_flow_remaining",
	"post_ultimate_flow_background_multiplier",
	"ultimate_guard_remaining",
	"ultimate_guard_damage_multiplier",
	"perpetual_motion_cooldown_remaining",
	"frenzy_remaining",
	"frenzy_stacks",
	"frenzy_overkill_counter",
	"role_standby_elapsed",
	"role_share_initialized",
	"mage_arcane_charge_stacks",
	"mage_arcane_charge_transfer_stacks",
	"mage_arcane_charge_transfer_remaining",
	"mage_arcane_charge_transfer_duration",
	"mage_arcane_charge_transfer_target_role_id",
	"mage_arcane_charge_transfer_relay_used",
	"active_role_index",
	"auto_attack_enabled",
	"role_upgrade_levels",
	"background_cooldowns",
	"equipment_levels",
	"role_equipment_levels",
	"elite_relics_unlocked",
	"attribute_training_levels",
	"role_blessing_levels",
	"skill_blessing_levels",
	"owned_magic_stones",
	"blessing_skill_state",
	"role_special_states",
	"roles"
]

const APPROX_KEYS := [
	"max_health",
	"max_mana",
	"current_health",
	"current_temporary_health",
	"current_mana",
	"ultimate_energy_lock_remaining",
	"speed",
	"pickup_radius",
	"energy_gain_multiplier",
	"global_damage_multiplier",
	"background_interval_multiplier",
	"ultimate_cost_multiplier",
	"damage_taken_multiplier",
	"passive_damage_reduction_value",
	"equipment_damage_multiplier_bonus",
	"equipment_speed_bonus",
	"equipment_max_health_bonus",
	"equipment_energy_gain_bonus",
	"equipment_dodge_chance",
	"equipment_health_regen_per_second",
	"equipment_low_health_threshold",
	"equipment_low_health_damage_taken_multiplier",
	"equipment_low_health_damage_reduction_value",
	"equipment_skill_range_multiplier",
	"equipment_cooldown_multiplier",
	"role_switch_cooldown_bonus"
]

const APPROX_VECTOR_ARRAY_KEYS := [
	"gunner_infinite_reload_locked_aim_direction",
	"swordsman_blade_storm_cast_origin",
	"swordsman_blade_storm_cast_direction"
]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene

	var source = PLAYER_SCENE.instantiate()
	var target = PLAYER_SCENE.instantiate()
	scene.add_child(source)
	scene.add_child(target)
	await process_frame

	_check_legacy_role_balance_migration(target)
	_seed_run_state(source)
	var source_save: Dictionary = source.get_save_data()
	target.apply_save_data(source_save)
	var target_save: Dictionary = target.get_save_data()
	_compare_roundtrip(source_save, target_save)

	scene.queue_free()
	await process_frame
	current_scene = null
	if failures.is_empty():
		print("PLAYER_SAVE_ROUNDTRIP_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_legacy_role_balance_migration(player: Node) -> void:
	var legacy_roles: Array = player._build_role_data()
	for role_variant in legacy_roles:
		var role: Dictionary = role_variant
		match str(role.get("id", "")):
			"swordsman":
				role["base_health"] = 100.0
			"gunner":
				role["base_health"] = 50.0
				role["base_damage_reduction_value"] = -80.0
			"mage":
				role["base_health"] = 50.0
	var normalized_roles: Array = player._normalize_loaded_roles(legacy_roles)
	var expected_health := {"swordsman": 150.0, "gunner": 120.0, "mage": 120.0}
	for role_variant in normalized_roles:
		var role: Dictionary = role_variant
		var role_id := str(role.get("id", ""))
		if expected_health.has(role_id) and not is_equal_approx(float(role.get("base_health", 0.0)), float(expected_health[role_id])):
			failures.append("%s legacy save should use current base health" % role_id)
		if role_id == "gunner" and not is_equal_approx(float(role.get("base_damage_reduction_value", 0.0)), -40.0):
			failures.append("gunner legacy save should use current base damage reduction")


func _seed_run_state(player: Node) -> void:
	player.global_position = Vector2(123.0, -45.0)
	player.level = 16
	player.experience = 47
	player.experience_to_next_level = 210
	player.pending_level_ups = 2
	player.level_up_active = false
	player.active_role_index = 1
	player.auto_attack_enabled = true

	player.role_health_values = {
		"swordsman": 92.0,
		"gunner": 81.0,
		"mage": 73.0
	}
	player.role_temporary_health_values = {
		"swordsman": 21.0,
		"gunner": 21.0,
		"mage": 21.0
	}
	player.temporary_health_stacks = [
		{"amount": 10.0, "remaining": 28.0},
		{"amount": 11.0, "remaining": 30.0}
	]
	player.role_mana_values = {
		"swordsman": 11.0,
		"gunner": 64.0,
		"mage": 33.0
	}
	player.role_ultimate_energy_lock_remaining = {
		"swordsman": 0.6,
		"gunner": 1.7,
		"mage": 2.8
	}
	player.current_health = 81.0
	player.current_temporary_health = 21.0
	player.current_mana = 64.0
	player.max_mana = 145.0

	player.hurt_cooldown_remaining = 0.33
	player.switch_invulnerability_remaining = 0.44
	player.level_up_delay_remaining = 0.55
	player.switch_cooldown_remaining = 1.25
	player.greed_heal_cooldown_remaining = 1.75
	player.enemy_move_slow_multiplier = 0.72
	player.enemy_move_slow_remaining = 2.4

	player.gunner_infinite_reload_ability.apply_save_data({
		"cooldown_remaining": 4.5,
		"active_remaining": 1.5,
		"tick_remaining": 0.2,
		"locked_aim_direction": [0.3, 0.7],
		"sweep_elapsed": 0.6,
		"hit_during_cast": true,
		"talent_ids": ["gunner_infinite_axis", "gunner_infinite_recycle"],
		"talent_snapshot_valid": true
	})
	player.gunner_shrapnel_field_ability.apply_save_data({"cooldown_remaining": 3.4})
	player.mage_tidal_surge_ability.cooldown_remaining = 5.6
	player.mage_meta_field_ability.apply_save_data({
		"cooldown_remaining": 6.7,
		"active_remaining": 2.6,
		"tick_remaining": 0.3,
		"transferred_role_id": "gunner",
		"expansion_tick_count": 2,
		"talent_ids": ["mage_meta_transfer", "mage_meta_expansion"],
		"talent_snapshot_valid": true
	})
	player.swordsman_blade_storm_ability.apply_save_data({
		"cooldown_remaining": 7.8,
		"active_remaining": 1.4,
		"tick_remaining": 0.2,
		"cast_origin": Vector2(321.0, -123.0),
		"cast_direction": Vector2(0.6, 0.8),
		"ring_visual_tick_index": 3,
		"base_tick_count": 4,
		"cast_elapsed": 0.9,
		"talent_ids": ["swordsman_blade_storm_stationary", "swordsman_blade_storm_rending_spin"],
		"talent_snapshot_valid": true
	})
	player.swordsman_crescent_wave_ability.apply_save_data({"cooldown_remaining": 8.9})

	player.role_equipment_levels = {
		"swordsman": {"small_boss_equipment_flame_amulet": 1},
		"gunner": {
			"small_boss_equipment_spell_prism": 2,
			"small_boss_equipment_spyglass": 1
		},
		"mage": {"small_boss_equipment_ocean_amulet": 1}
	}
	player.equipment_levels = (player.role_equipment_levels["gunner"] as Dictionary).duplicate(true)
	player.elite_relics_unlocked = {"stability_relic": true}
	player.role_special_states["swordsman"] = {
		"ultimate_lifesteal_multiplier_remaining": 3.0,
		"level_knight_glory_damage_reduction_remaining": 2.5,
		"level_knight_glory_surge_remaining": 1.5,
		"level_charge_damage_reduction_remaining": 2.0,
		"level_talents": [
			"swordsman_level_talent_knight_glory_1",
			"swordsman_level_talent_charge_2"
		]
	}
	player.role_special_states["gunner"] = {"lock_bonus_stacks": 2, "level_execution_dodge_persistent_stacks": 4, "level_execution_immunity_buff_remaining": 1.8, "level_talents": ["gunner_level_talent_execution_1", "gunner_level_talent_execution_2"]}

	PLAYER_BLESSING_SYSTEM.apply_blessing(player, "divine_grace", 1)
	PLAYER_BLESSING_SYSTEM.apply_blessing(player, "blazing_sun", 2)
	PLAYER_BLESSING_SYSTEM.apply_blessing(player, "tide_rain", 1)
	PLAYER_BLESSING_SYSTEM.apply_blessing(player, "reprise", 2)
	PLAYER_BLESSING_SYSTEM.apply_magic_stone(player, "kebiru")

	player.switch_power_remaining = 3.1
	player.switch_power_role_id = "gunner"
	player.switch_power_damage_multiplier = 1.35
	player.switch_power_interval_bonus = 0.12
	player.switch_power_label = "roundtrip switch"
	player.pending_entry_blessing_source_role_id = "swordsman"
	player.entry_blessing_role_id = "mage"
	player.entry_blessing_label = "roundtrip entry"
	player.entry_blessing_remaining = 2.2
	player.entry_lifesteal_ratio = 0.08
	player.entry_haste_interval_bonus = 0.16
	player.entry_haste_move_speed_multiplier = 1.18
	player.standby_entry_role_id = "swordsman"
	player.standby_entry_label = "roundtrip standby"
	player.standby_entry_remaining = 1.9
	player.standby_entry_damage_multiplier = 1.22
	player.standby_entry_interval_bonus = 0.09
	player.guard_cover_remaining = 2.7
	player.guard_cover_damage_multiplier = 0.66
	player.borrow_fire_role_id = "mage"
	player.borrow_fire_remaining = 2.6
	player.borrow_fire_damage_multiplier = 1.28
	player.borrow_fire_interval_bonus = 0.11
	player.borrow_fire_background_multiplier = 1.17
	player.post_ultimate_flow_remaining = 2.5
	player.post_ultimate_flow_background_multiplier = 1.14
	player.ultimate_guard_remaining = 2.3
	player.ultimate_guard_damage_multiplier = 0.54
	player.perpetual_motion_cooldown_remaining = 4.4
	player.frenzy_remaining = 3.3
	player.frenzy_stacks = 4
	player.frenzy_overkill_counter = 2
	player.role_standby_elapsed = {"swordsman": 1.1, "gunner": 0.0, "mage": 2.2}
	player.role_share_initialized = true
	player.background_cooldowns = {"swordsman": 0.4, "gunner": 0.5, "mage": 0.6}
	player.mage_arcane_charge_stacks = 7
	player.mage_arcane_charge_transfer_stacks = 7
	player.mage_arcane_charge_transfer_remaining = 2.1
	player.mage_arcane_charge_transfer_duration = 3.7
	player.mage_arcane_charge_transfer_target_role_id = "gunner"
	player.mage_arcane_charge_transfer_relay_used = true

	player._update_active_role_state()
	player.fire_timer.stop()


func _compare_roundtrip(source_save: Dictionary, target_save: Dictionary) -> void:
	for key in EXACT_KEYS:
		if not source_save.has(key):
			failures.append("source save should contain key '%s'" % key)
			continue
		if not target_save.has(key):
			failures.append("target save should contain key '%s'" % key)
			continue
		if source_save[key] != target_save[key]:
			failures.append("roundtrip mismatch for '%s': %s != %s" % [key, str(source_save[key]), str(target_save[key])])
	for key in APPROX_KEYS:
		if not source_save.has(key) or not target_save.has(key):
			failures.append("roundtrip approximate key missing '%s'" % key)
			continue
		var source_value := float(source_save[key])
		var target_value := float(target_save[key])
		if not is_equal_approx(source_value, target_value):
			failures.append("roundtrip mismatch for '%s': %.5f != %.5f" % [key, source_value, target_value])
	for key in APPROX_VECTOR_ARRAY_KEYS:
		if not source_save.has(key) or not target_save.has(key):
			failures.append("roundtrip vector key missing '%s'" % key)
			continue
		var source_array: Array = source_save[key]
		var target_array: Array = target_save[key]
		if source_array.size() != target_array.size():
			failures.append("roundtrip vector size mismatch for '%s'" % key)
			continue
		for index in range(source_array.size()):
			if not is_equal_approx(float(source_array[index]), float(target_array[index])):
				failures.append("roundtrip vector mismatch for '%s'[%d]: %.5f != %.5f" % [key, index, float(source_array[index]), float(target_array[index])])

extends RefCounted

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const ENEMY_GLUTTON_SKILL_BEHAVIOR := preload("res://scripts/enemies/enemy_glutton_skill_behavior.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")
const DEVELOPER_OPTION_PROVIDER := preload("res://scripts/developer/developer_option_provider.gd")

static func activate(main: Node) -> void:
	DEVELOPER_MODE.set_ignore_damage_enabled(true)
	if main.spawn_timer != null:
		main.spawn_timer.stop()
	for enemy in _get_runtime_or_group_nodes(main, "enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	for projectile in _get_runtime_or_group_nodes(main, "enemy_projectiles"):
		if is_instance_valid(projectile):
			projectile.queue_free()
	main.spawned_elite_count = 0
	main.spawned_small_boss_count = 0
	main.stage_cleared = false
	main.boss_spawned = false
	main.boss_enemy = null
	if main.hud != null and main.hud.has_method("hide_boss_ui"):
		main.hud.hide_boss_ui()
	if main.hud != null and main.hud.has_method("set_developer_invincibility_enabled"):
		main.hud.set_developer_invincibility_enabled(true)
	main._refresh_hud()

static func update(main: Node) -> void:
	if main.spawn_timer != null and not main.spawn_timer.is_stopped():
		main.spawn_timer.stop()

static func grant_level_up(main: Node) -> void:
	if main.player == null or not main.player.has_method("grant_developer_level_up"):
		return
	main.player.grant_developer_level_up()
	main._refresh_hud()

static func spawn_boss(main: Node, archetype_id: String = "boss_spellcore") -> void:
	if not ENEMY_ARCHETYPE_DATABASE.is_boss_archetype(archetype_id):
		return
	var allowed_archetypes := ENEMY_ARCHETYPE_DATABASE.get_boss_archetypes()
	if not allowed_archetypes.has(archetype_id):
		return
	main.boss_spawned = true
	var health_multiplier: float = main._get_spawn_enemy_health_multiplier()
	var speed_multiplier: float = main._get_spawn_enemy_speed_multiplier()
	var damage_multiplier: float = main._get_spawn_enemy_damage_multiplier()
	main.boss_enemy = main._spawn_configured_enemy("boss", archetype_id, health_multiplier, speed_multiplier, INF, 0.0, damage_multiplier)
	main._refresh_hud()

static func spawn_small_boss(main: Node, archetype_id: String) -> void:
	if not ENEMY_ARCHETYPE_DATABASE.is_small_boss_archetype(archetype_id):
		return
	var allowed_archetypes := ENEMY_ARCHETYPE_DATABASE.get_small_boss_archetypes()
	if not allowed_archetypes.has(archetype_id):
		return
	var health_multiplier: float = main._get_spawn_enemy_health_multiplier()
	var speed_multiplier: float = main._get_spawn_enemy_speed_multiplier()
	var damage_multiplier: float = main._get_spawn_enemy_damage_multiplier()
	main._spawn_configured_enemy("small_boss", archetype_id, health_multiplier, speed_multiplier, INF, 0.0, damage_multiplier)

static func spawn_normal_enemy_batch(main: Node, archetype_id: String, _count: int) -> void:
	if main == null or main.player == null or not ENEMY_ARCHETYPE_DATABASE.is_normal_archetype(archetype_id):
		return
	var spawn_count := 1
	var health_multiplier: float = main._get_spawn_enemy_health_multiplier("normal")
	var speed_multiplier: float = main._get_spawn_enemy_speed_multiplier()
	var damage_multiplier: float = main._get_spawn_enemy_damage_multiplier()
	main.ENEMY_SPAWN_FLOW.spawn_wave_pack(main, "normal", archetype_id, spawn_count, health_multiplier, speed_multiplier, damage_multiplier)

static func spawn_elite_enemy(main: Node, archetype_id: String) -> void:
	if main == null or main.player == null or not ENEMY_ARCHETYPE_DATABASE.is_elite_archetype(archetype_id):
		return
	var health_multiplier: float = main._get_spawn_enemy_health_multiplier("elite")
	var speed_multiplier: float = main._get_spawn_enemy_speed_multiplier()
	var damage_multiplier: float = main._get_spawn_enemy_damage_multiplier()
	main._spawn_configured_enemy("elite", archetype_id, health_multiplier, speed_multiplier, INF, 0.0, damage_multiplier)

static func spawn_enemy(main: Node, kind: String, archetype_id: String, count: int = 1) -> void:
	match kind:
		"boss":
			spawn_boss(main, archetype_id)
		"small_boss":
			spawn_small_boss(main, archetype_id)
		"elite":
			spawn_elite_enemy(main, archetype_id)
		"normal":
			spawn_normal_enemy_batch(main, archetype_id, count)

static func unlock_skill(main: Node, skill_id: String, tier: int) -> void:
	if main == null or main.player == null:
		return
	if not PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(main.player, skill_id, tier):
		return
	_clear_skill_cooldown(main.player, skill_id)
	if main.player.has_signal("stats_changed") and main.player.has_method("get_stat_summary"):
		main.player.stats_changed.emit(main.player.get_stat_summary())
	main._refresh_hud()

static func grant_skill_talent(main: Node, talent_id: String) -> void:
	if main == null or main.player == null:
		return
	if talent_id == DEVELOPER_OPTION_PROVIDER.CLEAR_SKILL_TALENTS_OPTION_ID:
		_clear_all_skill_talents(main.player)
		_finish_player_change(main)
		return
	if talent_id.begins_with(DEVELOPER_OPTION_PROVIDER.CLEAR_SKILL_TALENT_STAGE_PREFIX):
		var clear_parts := talent_id.trim_prefix(DEVELOPER_OPTION_PROVIDER.CLEAR_SKILL_TALENT_STAGE_PREFIX).split(":")
		if clear_parts.size() != 3:
			return
		_clear_skill_talent(main.player, str(clear_parts[0]), str(clear_parts[1]), int(clear_parts[2]))
		_finish_player_change(main)
		return
	if talent_id.begins_with(DEVELOPER_OPTION_PROVIDER.SKILL_TALENT_PATH_PREFIX):
		var path_parts := talent_id.trim_prefix(DEVELOPER_OPTION_PROVIDER.SKILL_TALENT_PATH_PREFIX).split(":")
		if path_parts.size() != 3 or not _set_skill_talent_path(main.player, str(path_parts[0]), str(path_parts[1]), str(path_parts[2])):
			return
		_finish_player_change(main)
		return
	var location := _find_skill_talent(talent_id)
	if location.is_empty():
		return
	var role_id := str(location.get("role_id", ""))
	var progress_id := str(location.get("progress_id", ""))
	var stage := int(location.get("stage", 1))
	var required_skill := str(PLAYER_SKILL_TALENT_SYSTEM.UNLOCKABLE_PROGRESS.get(progress_id, ""))
	if required_skill != "" and not PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(main.player, required_skill, 1):
		return
	if not _raise_skill_progress_to(main.player, role_id, progress_id, int(PLAYER_SKILL_TALENT_SYSTEM.TRIGGER_LEVELS[stage - 1])):
		return
	_clear_skill_talent(main.player, role_id, progress_id, stage)
	for previous_stage in range(1, stage):
		if PLAYER_SKILL_TALENT_SYSTEM.get_selected_talents(main.player, role_id, progress_id).size() >= previous_stage:
			continue
		var fallback_id := _get_stage_talent_id(progress_id, previous_stage, "left")
		if not _apply_skill_talent_stage(main.player, role_id, progress_id, previous_stage, fallback_id):
			return
	if not _apply_skill_talent_stage(main.player, role_id, progress_id, stage, talent_id):
		return
	_finish_player_change(main)


static func _apply_skill_talent_stage(player, role_id: String, progress_id: String, stage: int, talent_id: String) -> bool:
	var offer := PLAYER_SKILL_TALENT_SYSTEM.build_choice_offer(player, {
		"role_id": role_id,
		"progress_id": progress_id,
		"talent_stage": stage
	})
	return not PLAYER_SKILL_TALENT_SYSTEM.apply_option_with_result(player, PLAYER_SKILL_TALENT_SYSTEM.OPTION_PREFIX + talent_id, offer).is_empty()


static func _find_skill_talent(talent_id: String) -> Dictionary:
	for role_id in ["swordsman", "gunner", "mage"]:
		for progress_id in PLAYER_SKILL_TALENT_SYSTEM.ROLE_PROGRESS_ORDER.get(role_id, []):
			for talent_value in PLAYER_SKILL_TALENT_SYSTEM.TALENT_DEFINITIONS.get(progress_id, []):
				if str((talent_value as Dictionary).get("id", "")) == talent_id:
					return {
						"role_id": role_id,
						"progress_id": progress_id,
						"stage": int((talent_value as Dictionary).get("stage", 1))
					}
	return {}


static func _get_progress_build_id(role_id: String, progress_id: String) -> String:
	for definition_value in PLAYER_BUILD_SYSTEM.BUILD_DEFINITIONS.get(role_id, []):
		var definition: Dictionary = definition_value
		if str(definition.get("skill_progress_id", "")) == progress_id and str(definition.get("unlock_skill", "")) == "":
			return str(definition.get("id", ""))
	return ""


static func _raise_skill_progress_to(player, role_id: String, progress_id: String, target_level: int) -> bool:
	var build_id := _get_progress_build_id(role_id, progress_id)
	while PLAYER_SKILL_TALENT_SYSTEM.get_skill_progress_level(player, role_id, progress_id) < target_level:
		if build_id == "" or not PLAYER_BUILD_SYSTEM.apply_option(player, "%s%s:%s" % [PLAYER_BUILD_SYSTEM.OPTION_PREFIX, role_id, build_id]):
			return false
	return true


static func _get_stage_talent_id(progress_id: String, stage: int, side: String) -> String:
	for talent_value in PLAYER_SKILL_TALENT_SYSTEM.TALENT_DEFINITIONS.get(progress_id, []):
		var talent: Dictionary = talent_value
		if int(talent.get("stage", 0)) == stage and str(talent.get("side", "")) == side:
			return str(talent.get("id", ""))
	return ""


static func _set_skill_talent_path(player, role_id: String, progress_id: String, path: String) -> bool:
	if path.length() != PLAYER_SKILL_TALENT_SYSTEM.TALENT_STAGE_COUNT or not PLAYER_SKILL_TALENT_SYSTEM.ROLE_PROGRESS_ORDER.get(role_id, []).has(progress_id):
		return false
	var required_skill := str(PLAYER_SKILL_TALENT_SYSTEM.UNLOCKABLE_PROGRESS.get(progress_id, ""))
	if required_skill != "" and not PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(player, required_skill, 1):
		return false
	if not _raise_skill_progress_to(player, role_id, progress_id, int(PLAYER_SKILL_TALENT_SYSTEM.TRIGGER_LEVELS[-1])):
		return false
	_clear_skill_talent(player, role_id, progress_id, 1)
	for stage_index in range(PLAYER_SKILL_TALENT_SYSTEM.TALENT_STAGE_COUNT):
		var side := "left" if path[stage_index] == "1" else ("right" if path[stage_index] == "2" else "")
		var talent_id := _get_stage_talent_id(progress_id, stage_index + 1, side)
		if talent_id == "" or not _apply_skill_talent_stage(player, role_id, progress_id, stage_index + 1, talent_id):
			return false
	return true


static func _clear_skill_talent(player, role_id: String, progress_id: String, stage: int = 1) -> void:
	var role_state: Dictionary = player.role_special_states.get(role_id, {})
	var talents: Dictionary = role_state.get(PLAYER_SKILL_TALENT_SYSTEM.TALENTS_KEY, {})
	var selected := PLAYER_SKILL_TALENT_SYSTEM.get_selected_talents(player, role_id, progress_id)
	var removed: Array = selected.slice(maxi(0, stage - 1))
	selected.resize(mini(selected.size(), maxi(0, stage - 1)))
	if selected.is_empty():
		talents.erase(progress_id)
	else:
		talents[progress_id] = selected
	role_state[PLAYER_SKILL_TALENT_SYSTEM.TALENTS_KEY] = talents
	player.role_special_states[role_id] = role_state
	if player.has_method("_clear_skill_talent_runtime_state"):
		player._clear_skill_talent_runtime_state(removed)


static func _clear_all_skill_talents(player) -> void:
	var removed: Array = []
	for role_id in ["swordsman", "gunner", "mage"]:
		var role_state: Dictionary = player.role_special_states.get(role_id, {})
		var talents: Dictionary = role_state.get(PLAYER_SKILL_TALENT_SYSTEM.TALENTS_KEY, {})
		for progress_id in talents:
			removed.append_array(PLAYER_SKILL_TALENT_SYSTEM.get_selected_talents(player, role_id, str(progress_id)))
		role_state[PLAYER_SKILL_TALENT_SYSTEM.TALENTS_KEY] = {}
		player.role_special_states[role_id] = role_state
	if player.has_method("_clear_skill_talent_runtime_state"):
		player._clear_skill_talent_runtime_state(removed)


static func _finish_player_change(main: Node) -> void:
	if main.player.has_method("_update_fire_timer"):
		main.player._update_fire_timer()
	if main.player.has_signal("stats_changed") and main.player.has_method("get_stat_summary"):
		main.player.stats_changed.emit(main.player.get_stat_summary())
	main._refresh_hud()
	if main.has_method("_save_run_state"):
		main._save_run_state()

static func grant_blessing(main: Node, blessing_id: String, tier: int) -> void:
	if main == null or main.player == null:
		return
	if not PLAYER_BLESSING_SYSTEM.apply_blessing(main.player, blessing_id, tier):
		return
	if main.player.has_signal("stats_changed") and main.player.has_method("get_stat_summary"):
		main.player.stats_changed.emit(main.player.get_stat_summary())
	main._refresh_hud()

static func grant_all_blessings(main: Node) -> void:
	if main == null or main.player == null:
		return
	var granted_any := false
	for blessing_id_value in PLAYER_BLESSING_SYSTEM.DEFINITIONS.keys():
		var blessing_id := str(blessing_id_value)
		var definition: Dictionary = PLAYER_BLESSING_SYSTEM.DEFINITIONS.get(blessing_id, {})
		var tier_values: Dictionary = definition.get("tier_values", {})
		for tier in range(1, PLAYER_BLESSING_SYSTEM.MAX_BLESSING_TIER + 1):
			if not tier_values.has(tier):
				continue
			if PLAYER_BLESSING_SYSTEM.apply_blessing(main.player, blessing_id, tier):
				granted_any = true
	if not granted_any:
		return
	if main.player.has_signal("stats_changed") and main.player.has_method("get_stat_summary"):
		main.player.stats_changed.emit(main.player.get_stat_summary())
	main._refresh_hud()


static func force_glutton_skill(main: Node, skill_id: String) -> void:
	if main == null:
		return
	var glutton_enemy: Node = _get_or_spawn_glutton_enemy(main)
	if glutton_enemy == null or not is_instance_valid(glutton_enemy):
		return
	ENEMY_GLUTTON_SKILL_BEHAVIOR.force_start_skill(glutton_enemy, skill_id)


static func _get_or_spawn_glutton_enemy(main: Node) -> Node:
	for enemy in _get_runtime_or_group_nodes(main, "enemies"):
		if _is_glutton_enemy(enemy):
			return enemy
	if main.player == null:
		return null
	var health_multiplier: float = main._get_spawn_enemy_health_multiplier("small_boss")
	var speed_multiplier: float = main._get_spawn_enemy_speed_multiplier()
	var damage_multiplier: float = main._get_spawn_enemy_damage_multiplier()
	return main._spawn_configured_enemy("small_boss", "smallboss_glutton", health_multiplier, speed_multiplier, INF, 0.0, damage_multiplier)


static func _is_glutton_enemy(enemy: Variant) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy is Node and (enemy as Node).is_queued_for_deletion():
		return false
	if enemy.get("behavior_id") != null and str(enemy.get("behavior_id")) == "glutton":
		return true
	if enemy.get("archetype_id") != null and str(enemy.get("archetype_id")) == "smallboss_glutton":
		return true
	return false

static func _clear_skill_cooldown(player, skill_id: String) -> void:
	var property_name := _get_skill_ability_property(skill_id)
	if property_name == "":
		return
	var ability: Variant = _get_owner_property(player, property_name)
	if ability != null:
		if "cooldown_remaining" in ability:
			ability.cooldown_remaining = 0.0
		if "active_remaining" in ability:
			ability.active_remaining = 0.0

static func _get_skill_ability_property(skill_id: String) -> String:
	match skill_id:
		PLAYER_BLESSING_SKILL_STATE.SKILL_BLADE_STORM:
			return "swordsman_blade_storm_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_CRESCENT_WAVE:
			return "swordsman_crescent_wave_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_INFINITE_RELOAD:
			return "gunner_infinite_reload_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_SHRAPNEL_FIELD:
			return "gunner_shrapnel_field_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_SURGING_WAVE:
			return "mage_tidal_surge_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_META_FIELD:
			return "mage_meta_field_ability"
	return ""

static func _get_owner_property(owner, property_name: String):
	if owner == null or not is_instance_valid(owner):
		return null
	for property_info in owner.get_property_list():
		if property_info is Dictionary and str(property_info.get("name", "")) == property_name:
			return owner.get(property_name)
	return null

static func _get_runtime_or_group_nodes(main: Node, group_name: String) -> Array:
	if main == null or main.get_tree() == null:
		return []
	if group_name == "enemies" and main.has_method("get_runtime_enemies"):
		return main.get_runtime_enemies()
	if group_name == "enemy_projectiles" and main.has_method("get_runtime_enemy_projectiles"):
		return main.get_runtime_enemy_projectiles()
	return main.get_tree().get_nodes_in_group(group_name)

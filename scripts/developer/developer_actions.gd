extends RefCounted

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const ENEMY_GLUTTON_SKILL_BEHAVIOR := preload("res://scripts/enemies/enemy_glutton_skill_behavior.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")

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

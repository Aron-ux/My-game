extends RefCounted

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const ENEMY_GLUTTON_SKILL_BEHAVIOR := preload("res://scripts/enemies/enemy_glutton_skill_behavior.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")
const DIFFICULTY_PROFILE := preload("res://scripts/game/difficulty_profile.gd")
const BUILD_TOOLS := preload("res://scripts/developer/developer_build_tools.gd")

static func apply_catalog_action(main: Node, request: Dictionary) -> bool:
	if not DEVELOPER_MODE.is_enabled() or main == null or main.player == null:
		return false
	var changed := BUILD_TOOLS.apply(main.player, request)
	if changed:
		main._refresh_hud()
	return changed

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
	main.small_boss_enemy = null
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

static func set_endless_tier(main: Node, tier: int) -> void:
	DEVELOPER_MODE.set_test_endless_tier(tier)
	main.endless_tier = DEVELOPER_MODE.get_test_endless_tier()
	main.difficulty_profile = DIFFICULTY_PROFILE.get_endless_tier_profile(main.endless_tier)
	main.difficulty_id = str(main.difficulty_profile.get("id", "n%d" % main.endless_tier))
	main._refresh_hud()


static func apply_ruan_stone_action(main: Node, action_id: String) -> bool:
	if main == null or main.player == null:
		return false
	var parts := action_id.split(":")
	var changed := false
	if parts.size() == 3 and parts[0] == "bones":
		changed = _set_developer_bones(main.player, str(parts[1]), int(parts[2]))
	elif parts.size() == 4 and parts[0] == "level":
		changed = _set_developer_ruan_stone_level(main.player, str(parts[1]), str(parts[2]), int(parts[3]))
	elif parts.size() == 2 and parts[0] == "equip" and main.player.has_method("equip_developer_ruan_stone"):
		changed = bool(main.player.equip_developer_ruan_stone(str(parts[1])))
	if changed and main.has_method("_refresh_hud"):
		main._refresh_hud()
	return changed


static func _set_developer_bones(player, operation: String, value: int) -> bool:
	if not player.has_method("get_developer_bone_count") or not player.has_method("set_developer_bone_count"):
		return false
	var target := value if operation == "set" else int(player.get_developer_bone_count()) + value
	if operation != "set" and operation != "add":
		return false
	player.set_developer_bone_count(max(0, target))
	return true


static func _set_developer_ruan_stone_level(player, operation: String, stone_id: String, value: int) -> bool:
	if not player.has_method("get_ruan_stone_level") or not player.has_method("set_developer_ruan_stone_level"):
		return false
	var target := value if operation == "set" else int(player.get_ruan_stone_level(stone_id)) + value
	if operation != "set" and operation != "add":
		return false
	player.set_developer_ruan_stone_level(stone_id, max(0, target))
	return true


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
	main.small_boss_enemy = main._spawn_configured_enemy("small_boss", archetype_id, health_multiplier, speed_multiplier, INF, 0.0, damage_multiplier)

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
		PLAYER_BLESSING_SKILL_STATE.SKILL_KNIGHT_THRUST:
			return "swordsman_knight_thrust_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_KING_BLADE:
			return "swordsman_king_blade_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_JUDGEMENT_SWORD:
			return "swordsman_judgement_sword_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_INFINITE_RELOAD:
			return "gunner_infinite_reload_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_SHRAPNEL_FIELD:
			return "gunner_shrapnel_field_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_EXPLOSIVE_ROUND:
			return "gunner_explosive_round_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_MAGIC_GRENADE:
			return "gunner_magic_grenade_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_MAGIC_EYE:
			return "gunner_magic_eye_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_SURGING_WAVE:
			return "mage_tidal_surge_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_META_FIELD:
			return "mage_meta_field_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_FLAME_PATH:
			return "mage_flame_path_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_DARK_CONTRACT:
			return "mage_dark_contract_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_FIREBALL:
			return "mage_fireball_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_DRONE:
			return "mechanic_drone_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_MINE:
			return "mechanic_mine_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_EMP_BURST:
			return "mechanic_emp_burst_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_TULIP_TURRET:
			return "mechanic_tulip_turret_ability"
		PLAYER_BLESSING_SKILL_STATE.SKILL_MISSILE_VOLLEY:
			return "mechanic_missile_volley_ability"
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

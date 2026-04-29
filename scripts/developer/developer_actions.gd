extends RefCounted

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")

static func activate(main: Node) -> void:
	DEVELOPER_MODE.set_ignore_damage_enabled(true)
	if main.spawn_timer != null:
		main.spawn_timer.stop()
	for enemy in main.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	for projectile in main.get_tree().get_nodes_in_group("enemy_projectiles"):
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

static func grant_card(main: Node, card_id: String) -> void:
	if main.player == null or not main.player.has_method("apply_upgrade"):
		return
	main.player.apply_upgrade(card_id)
	main._refresh_hud()
	main._save_run_state()

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

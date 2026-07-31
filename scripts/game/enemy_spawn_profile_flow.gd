extends RefCounted

const ENEMY_DIRECTOR := preload("res://scripts/enemy/enemy_director.gd")
const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")


static func get_wave_profile(main: Node) -> Dictionary:
	var player_growth_score := get_player_growth_score(main)
	var expected_growth_score := get_expected_growth_score(main)
	if main != null and bool(main.get("endless_mode_active")):
		player_growth_score = expected_growth_score
	var profile: Dictionary = ENEMY_DIRECTOR.get_wave_profile(
		get_stage_elapsed_time(main),
		ENEMY_DIRECTOR.get_default_elite_spawn_times(),
		player_growth_score,
		expected_growth_score
	)
	if main.has_method("_apply_difficulty_to_wave_profile"):
		return main._apply_difficulty_to_wave_profile(profile)
	return profile


static func get_player_growth_score(main: Node) -> float:
	if main.player == null:
		return 0.0

	var summary: Dictionary = {
		"bullet_damage": _get_active_role_damage(main.player)
	}

	return ENEMY_DIRECTOR.get_player_growth_score(
		int(main.player.level),
		summary,
		{},
		main.player.elite_relics_unlocked
	)


static func _get_active_role_damage(player: Node) -> float:
	if player == null:
		return 0.0
	if not player.has_method("_get_active_role") or not player.has_method("_get_role_damage"):
		return 0.0
	var role_data: Dictionary = player._get_active_role()
	var role_id := str(role_data.get("id", ""))
	if role_id == "":
		return 0.0
	return float(player._get_role_damage(role_id))


static func get_expected_growth_score(main: Node) -> float:
	return ENEMY_DIRECTOR.get_expected_growth_score(get_stage_elapsed_time(main), ENEMY_DIRECTOR.get_default_boss_spawn_time())


static func get_stage_elapsed_time(main: Node) -> float:
	return float(main.get("survival_time")) if main != null else 0.0


static func get_enemy_profile(main: Node, kind: String, archetype: String) -> Dictionary:
	var profile: Dictionary = ENEMY_ARCHETYPE_DATABASE.get_profile(kind, archetype)
	if main != null and main.has_method("_apply_difficulty_to_enemy_profile"):
		profile = main._apply_difficulty_to_enemy_profile(kind, profile)
	return profile


static func has_active_special_enemy(main: Node, kind: String) -> bool:
	if main.boss_enemy == null or not is_instance_valid(main.boss_enemy):
		return false
	return str(main.boss_enemy.get("enemy_kind")) == kind

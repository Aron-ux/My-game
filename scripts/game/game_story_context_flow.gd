extends RefCounted

const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const ENEMY_DIRECTOR := preload("res://scripts/enemy/enemy_director.gd")

# Handoff note:
# This flow owns the story/endless context consumed by battle spawning and stage
# rewards. Keep main.gd as the caller/holder of current scene state, but add new
# story/endless derivation rules here instead of scattering SAVE_MANAGER and
# ENEMY_DIRECTOR calls across the combat scene.

static func load_story_stage_context(main: Node) -> void:
	main.story_stage = SAVE_MANAGER.get_current_story_stage()
	main.story_mode_active = not main.story_stage.is_empty()
	main.endless_mode_active = not main.story_mode_active and SAVE_MANAGER.is_endless_mode_active()

static func apply_story_loadout(main: Node) -> void:
	if not main.story_mode_active or main.player == null or not main.player.has_method("configure_story_loadout"):
		return
	var profile := SAVE_MANAGER.load_story_profile()
	main.player.configure_story_loadout(
		profile.get("team_order", ["swordsman", "gunner", "mage"]),
		profile.get("equipped_styles", {})
	)

static func get_effective_boss_spawn_time(main: Node) -> float:
	return ENEMY_DIRECTOR.get_effective_boss_spawn_time(
		main.story_stage,
		main.story_mode_active,
		main.endless_mode_active,
		main.defeated_boss_count
	)

static func get_effective_stage_curve_time(main: Node) -> float:
	return ENEMY_DIRECTOR.get_effective_stage_curve_time(main.story_stage, main.story_mode_active)

static func get_story_spawn_interval_multiplier(main: Node) -> float:
	return ENEMY_DIRECTOR.get_story_spawn_interval_multiplier(main.story_stage, main.story_mode_active)

static func get_story_enemy_health_multiplier(main: Node) -> float:
	return ENEMY_DIRECTOR.get_story_enemy_health_multiplier(main.story_stage, main.story_mode_active)

static func get_story_enemy_speed_multiplier(main: Node) -> float:
	return ENEMY_DIRECTOR.get_story_enemy_speed_multiplier(main.story_stage, main.story_mode_active)

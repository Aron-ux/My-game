extends SceneTree

const DEVELOPER_ACTIONS := preload("res://scripts/developer/developer_actions.gd")
const DEVELOPER_OPTION_PROVIDER := preload("res://scripts/developer/developer_option_provider.gd")
const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var main := MainStub.new()
	scene.add_child(main)
	main.player = PLAYER_SCENE.instantiate()
	main.add_child(main.player)
	await process_frame

	_check_developer_options(main.player)
	_check_developer_level_talent_actions(main)

	scene.queue_free()
	await process_frame
	current_scene = null
	if failures.is_empty():
		print("DEVELOPER_SKILL_TALENT_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_developer_options(player: Node) -> void:
	var level_talent_ids: Dictionary = {}
	for role_id in PLAYER_SKILL_TALENT_SYSTEM.LEVEL_TALENT_DEFINITIONS:
		for talent_value in PLAYER_SKILL_TALENT_SYSTEM.LEVEL_TALENT_DEFINITIONS[role_id]:
			var talent_id := str((talent_value as Dictionary).get("id", ""))
			if talent_id != "":
				level_talent_ids[talent_id] = true
	var old_skill_talent_ids: Dictionary = {}
	for definitions_value in PLAYER_SKILL_TALENT_SYSTEM.TALENT_DEFINITIONS.values():
		for talent_value in definitions_value:
			var talent_id := str((talent_value as Dictionary).get("id", ""))
			if talent_id != "":
				old_skill_talent_ids[talent_id] = true

	var level_talent_option_count := 0
	var old_skill_talent_option_count := 0
	var has_clear_all := false
	var has_stage_clear := false
	var has_direct_path := false
	for option_value in DEVELOPER_OPTION_PROVIDER.get_skill_options(player):
		var option: Dictionary = option_value
		var option_id := str(option.get("id", ""))
		var raw_id := option_id.trim_prefix(DEVELOPER_OPTION_PROVIDER.SKILL_TALENT_OPTION_PREFIX)
		if level_talent_ids.has(raw_id):
			level_talent_option_count += 1
		if old_skill_talent_ids.has(raw_id):
			old_skill_talent_option_count += 1
		has_clear_all = has_clear_all or raw_id == DEVELOPER_OPTION_PROVIDER.CLEAR_SKILL_TALENTS_OPTION_ID
		has_stage_clear = has_stage_clear or raw_id.begins_with(DEVELOPER_OPTION_PROVIDER.CLEAR_SKILL_TALENT_STAGE_PREFIX)
		has_direct_path = has_direct_path or raw_id.begins_with(DEVELOPER_OPTION_PROVIDER.SKILL_TALENT_PATH_PREFIX)
	_expect(level_talent_option_count == level_talent_ids.size(), "developer skill list should expose every level talent definition")
	_expect(old_skill_talent_option_count == 0, "developer skill list should not expose old skill-talent nodes")
	_expect(has_clear_all, "developer skill list should expose the global level-talent clear action")
	_expect(not has_stage_clear, "developer skill list should not expose old stage-specific clear actions")
	_expect(not has_direct_path, "developer skill list should not expose old direct path construction")


func _check_developer_level_talent_actions(main: MainStub) -> void:
	DEVELOPER_ACTIONS.grant_skill_talent(main, "swordsman_level_talent_battle_will_1")
	_expect(main.player._has_level_talent("swordsman_level_talent_battle_will_1"), "developer level-talent grant should select the requested swordsman talent")
	_expect(not main.player._has_skill_talent("swordsman_trait_blood_battle"), "developer level-talent grant should not activate old skill talents")
	_expect(main.refresh_count == 1 and main.save_count == 1, "successful developer level-talent grant should refresh and save once")

	DEVELOPER_ACTIONS.grant_skill_talent(main, "swordsman_level_talent_battle_will_1")
	_expect(PLAYER_SKILL_TALENT_SYSTEM.get_selected_level_talents(main.player, "swordsman").size() == 1, "duplicate developer level-talent grant should not duplicate selection")
	_expect(main.refresh_count == 1 and main.save_count == 1, "duplicate developer level-talent grant should not refresh or save")

	DEVELOPER_ACTIONS.grant_skill_talent(main, "gunner_level_talent_hunt_1")
	_expect(main.player._has_level_talent("gunner_level_talent_hunt_1"), "developer level-talent grant should select the requested gunner talent")

	main.player.role_special_states["swordsman"]["skill_talents"] = {
		"swordsman_trait": ["swordsman_trait_blood_battle"]
	}
	main.player.role_special_states["swordsman"][PLAYER_SKILL_TALENT_SYSTEM.LEVEL_TALENT_GROUP_LOCKS_KEY] = {
		"default": {"swordsman_level_talent_battle_will": "swordsman_level_talent_battle_will_1"}
	}
	DEVELOPER_ACTIONS.grant_skill_talent(main, DEVELOPER_OPTION_PROVIDER.CLEAR_SKILL_TALENTS_OPTION_ID)
	_expect(PLAYER_SKILL_TALENT_SYSTEM.get_selected_level_talents(main.player, "swordsman").is_empty(), "developer clear action should remove swordsman level talents")
	_expect(PLAYER_SKILL_TALENT_SYSTEM.get_selected_level_talents(main.player, "gunner").is_empty(), "developer clear action should remove gunner level talents")
	_expect((main.player.role_special_states["swordsman"][PLAYER_SKILL_TALENT_SYSTEM.LEVEL_TALENT_GROUP_LOCKS_KEY] as Dictionary).is_empty(), "developer clear action should clear level-talent group locks")
	_expect((main.player.role_special_states["swordsman"]["skill_talents"] as Dictionary).is_empty(), "developer clear action should clear legacy skill-talent storage")
	_expect(main.refresh_count == 3 and main.save_count == 3, "each successful developer level-talent action should refresh and save once")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


class MainStub:
	extends Node

	var player: Node
	var refresh_count := 0
	var save_count := 0

	func _refresh_hud() -> void:
		refresh_count += 1

	func _save_run_state() -> void:
		save_count += 1

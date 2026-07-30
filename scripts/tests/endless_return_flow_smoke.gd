extends SceneTree

const REWARD_FLOW := preload("res://scripts/game/reward_flow.gd")
const PAUSE_MENU := preload("res://scripts/pause_menu.gd")
const GAME_OVER_UI := preload("res://scripts/game_over_ui.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := MainStub.new()
	root.add_child(main)
	main.player = PlayerStub.new()
	main.add_child(main.player)
	main.level_up_ui = LevelUpStub.new()
	main.add_child(main.level_up_ui)

	REWARD_FLOW.show_endless_boss_reward(main)
	assert(main.reward_context == "endless_boss_reward")
	assert(bool(main.get_meta(REWARD_FLOW.ENDLESS_BOSS_EXIT_PENDING_META, false)))
	REWARD_FLOW.handle_upgrade_selected(main, "boss_skill")
	assert(main.player.applied_option == "boss_skill")
	assert(main.reward_context == REWARD_FLOW.ENDLESS_BOSS_EXIT_CONTEXT)
	assert(bool(main.get_meta(REWARD_FLOW.ENDLESS_BOSS_EXIT_PENDING_META, false)))
	assert(main.level_up_ui.last_option_ids == [
		REWARD_FLOW.ENDLESS_CONTINUE_OPTION_ID,
		REWARD_FLOW.ENDLESS_RETURN_CAMP_OPTION_ID
	])
	REWARD_FLOW.handle_upgrade_selected(main, REWARD_FLOW.ENDLESS_CONTINUE_OPTION_ID)
	assert(main.maintenance_count == 1)
	assert(not main.has_meta(REWARD_FLOW.ENDLESS_BOSS_EXIT_PENDING_META))

	REWARD_FLOW.show_endless_boss_reward(main)
	REWARD_FLOW.handle_upgrade_selected(main, "boss_skill")
	REWARD_FLOW.handle_upgrade_selected(main, REWARD_FLOW.ENDLESS_RETURN_CAMP_OPTION_ID)
	assert(main.preserve_return_count == 1)
	assert(not main.preserve_return_had_pending_checkpoint)

	var pause_menu := PAUSE_MENU.new()
	root.add_child(pause_menu)
	await process_frame
	pause_menu.set_endless_mode_enabled(true)
	assert(pause_menu.end_run_button.visible)
	pause_menu._on_end_run_pressed()
	assert(pause_menu.end_run_confirm_dialog != null)
	var end_requested := [false]
	pause_menu.end_run_requested.connect(func(): end_requested[0] = true)
	pause_menu.end_run_confirm_dialog.confirmed.emit()
	assert(end_requested[0])

	var game_over_ui := GAME_OVER_UI.new()
	root.add_child(game_over_ui)
	await process_frame
	game_over_ui.show_game_over(65.0, 7, true)
	assert(game_over_ui.restart_button.text == "返回营地")
	var camp_requested := [false]
	game_over_ui.return_to_camp_requested.connect(func(): camp_requested[0] = true)
	game_over_ui._on_restart_pressed()
	assert(camp_requested[0])

	print("ENDLESS_RETURN_FLOW_SMOKE_OK")
	quit(0)

class MainStub:
	extends Node

	var player: Node
	var level_up_ui: Node
	var reward_context := ""
	var game_over := false
	var maintenance_count := 0
	var preserve_return_count := 0
	var preserve_return_had_pending_checkpoint := false

	func _schedule_reward_maintenance(_resume_level_ups: bool = false) -> void:
		maintenance_count += 1

	func _return_to_endless_camp_preserving_run() -> void:
		preserve_return_count += 1
		preserve_return_had_pending_checkpoint = bool(get_meta(REWARD_FLOW.ENDLESS_BOSS_EXIT_PENDING_META, false))

class PlayerStub:
	extends Node

	var applied_option := ""

	func get_boss_skill_reward_options() -> Array:
		return [{"id": "boss_skill", "title": "Boss Skill"}]

	func apply_upgrade(option_id: String) -> void:
		applied_option = option_id

class LevelUpStub:
	extends Node

	var last_option_ids: Array = []

	func show_menu(_title: String, options: Array) -> void:
		last_option_ids.clear()
		for option_value in options:
			last_option_ids.append(str((option_value as Dictionary).get("id", "")))

	func hide_ui() -> void:
		pass

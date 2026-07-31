extends SceneTree

const SaveManager := preload("res://scripts/save_manager.gd")
const StoryContextFlow := preload("res://scripts/game/game_story_context_flow.gd")
const DeveloperMode := preload("res://scripts/developer_mode.gd")


func _init() -> void:
	var previous_mode := SaveManager.active_mode
	var previous_story_slot := SaveManager.active_slot_id
	var previous_endless_slot := SaveManager.active_endless_slot_id

	SaveManager.active_mode = SaveManager.MODE_ENDLESS
	SaveManager.active_slot_id = 1
	SaveManager.active_endless_slot_id = 1
	assert(SaveManager.get_current_story_stage().is_empty())

	var main := ContextMain.new()
	main.player = ContextPlayer.new()
	StoryContextFlow.load_story_stage_context(main)
	StoryContextFlow.apply_story_loadout(main)
	assert(main.endless_mode_active)
	assert(not main.story_mode_active)
	assert(main.story_stage.is_empty())
	assert(main.player.ruan_stones_configured)

	DeveloperMode.activate()
	DeveloperMode.set_test_endless_tier(21)
	var developer_main := ContextMain.new()
	developer_main.player = ContextPlayer.new()
	StoryContextFlow.load_story_stage_context(developer_main)
	StoryContextFlow.apply_story_loadout(developer_main)
	assert(not developer_main.endless_mode_active)
	assert(not developer_main.story_mode_active)
	assert(developer_main.story_stage.is_empty())
	assert(developer_main.endless_tier == 21)
	assert(developer_main.endless_run_id.is_empty())
	assert(not developer_main.player.ruan_stones_configured)
	DeveloperMode.deactivate()

	SaveManager.active_mode = previous_mode
	SaveManager.active_slot_id = previous_story_slot
	SaveManager.active_endless_slot_id = previous_endless_slot
	developer_main.player.free()
	developer_main.free()
	main.player.free()
	main.free()
	print("GAME_MODE_RUAN_STONE_CONTEXT_SMOKE_OK")
	quit(0)


class ContextMain:
	extends Node
	var player: Node
	var story_stage: Dictionary = {}
	var story_mode_active := false
	var endless_mode_active := false
	var endless_tier := 1
	var endless_run_id := ""
	var difficulty_profile: Dictionary = {}
	var difficulty_id := ""


class ContextPlayer:
	extends Node
	var ruan_stones_configured := false

	func configure_ruan_stones(_profile: Dictionary) -> void:
		ruan_stones_configured = true

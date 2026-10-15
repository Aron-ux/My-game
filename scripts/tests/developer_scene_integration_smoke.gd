extends SceneTree

const MODE := preload("res://scripts/developer_mode.gd")
const MAIN := preload("res://scenes/main.tscn")
const TOOLS := preload("res://scripts/developer/developer_build_tools.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	MODE.activate()
	var game = MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var panel = game.hud.developer_panel
	assert(panel != null)
	assert(panel.catalogs["blessing"].catalog.size() == 7)
	assert(panel.catalogs["item"].catalog.size() == TOOLS.ITEMS.STONE_IDS.size())
	var page = panel.catalogs["skill"]
	page.selected_id = "swordsman_basic"
	page._rebuild_list()
	var before := TOOLS.BASIC.level(game.player)
	panel.catalog_action_requested.emit({"kind": "skill", "role_id": "swordsman", "id": "swordsman_basic", "operation": "add"})
	assert(TOOLS.BASIC.level(game.player) == before + 1)
	assert(int(page._selected()["level"]) == before + 1)
	panel.catalog_action_requested.emit({"kind": "item", "id": "ground_branch", "operation": "add", "amount": 2})
	assert(game.player.get_ruan_stone_level("ground_branch") == 2)
	panel.catalog_action_requested.emit({"kind": "bones", "operation": "add", "amount": 100})
	assert(game.player.get_developer_bone_count() == 100)
	assert(MODE.should_disable_save())
	game.queue_free()
	await process_frame
	current_scene = null
	MODE.deactivate()
	print("DEVELOPER_SCENE_INTEGRATION_SMOKE_OK")
	quit(0)

extends SceneTree

const TOOLS := preload("res://scripts/developer/developer_build_tools.gd")
const ITEMS := preload("res://scripts/player/ruan_stone_system.gd")
const PLAYER := preload("res://scenes/player.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player = PLAYER.instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var options := TOOLS.item_catalog(player)
	assert(options.size() == ITEMS.STONE_IDS.size())
	for option in options:
		assert(ITEMS.STONE_IDS.has(option["id"]))
		assert(not str(option["description"]).is_empty())
		var request := {"kind": "item", "id": option["id"], "operation": "add", "amount": 2}
		assert(TOOLS.apply(player, request))
		assert(player.get_ruan_stone_level(option["id"]) == 2)
		assert(TOOLS.apply(player, request.merged({"operation": "remove", "amount": 1}, true)))
		assert(player.get_ruan_stone_level(option["id"]) == 1)
		assert(TOOLS.apply(player, request.merged({"operation": "clear"}, true)))
		assert(player.get_ruan_stone_level(option["id"]) == 0)
	player.queue_free()
	await process_frame
	print("DEVELOPER_RUAN_STONE_SMOKE_OK")
	quit(0)

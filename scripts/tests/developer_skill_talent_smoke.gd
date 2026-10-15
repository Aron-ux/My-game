extends SceneTree

const TOOLS := preload("res://scripts/developer/developer_build_tools.gd")
const PLAYER := preload("res://scenes/player.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player = PLAYER.instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var options := TOOLS.skill_catalog(player)
	assert(not options.is_empty())
	for option in options:
		assert(not str(option["id"]).contains("talent"))
		assert(TOOLS.LEVELS.get_role_progress_ids(option["role_id"]).has(option["id"]))
	var base := {"kind": "skill", "role_id": "swordsman", "id": "swordsman_basic"}
	assert(TOOLS.apply(player, base.merged({"operation": "set", "amount": 9})))
	assert(TOOLS.apply(player, base.merged({"operation": "branch", "stage": 4, "choice": "heavy"})))
	assert(TOOLS.apply(player, base.merged({"operation": "branch", "stage": 8, "choice": "ground"})))
	assert(TOOLS.apply(player, base.merged({"operation": "branch", "stage": 9, "choice": "guard"})))
	assert(TOOLS.BASIC.choices(player).size() == 3)
	assert(not TOOLS.apply(player, base.merged({"operation": "branch", "stage": 4, "choice": "guard"})))
	assert(TOOLS.apply(player, base.merged({"operation": "reset"})))
	assert(TOOLS.BASIC.choices(player).is_empty())
	player.queue_free()
	await process_frame
	print("DEVELOPER_SKILL_TALENT_SMOKE_OK")
	quit(0)

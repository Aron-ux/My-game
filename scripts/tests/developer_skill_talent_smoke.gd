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
	var grenade := {"kind": "skill", "role_id": "gunner", "id": "gunner_magic_grenade"}
	assert(TOOLS.apply(player, grenade.merged({"operation": "unlock"})))
	assert(TOOLS.apply(player, grenade.merged({"operation": "set", "amount": 9})))
	var grenade_option: Dictionary = {}
	for option in TOOLS.skill_catalog(player):
		if str(option.get("id", "")) == "gunner_magic_grenade":
			grenade_option = option
			break
	assert(bool(grenade_option.get("talent_pending", false)))
	assert(grenade_option.get("talents", []).size() == 2)
	assert(str(grenade_option.get("description", "")).contains("4 枚魔法榴弹"))
	assert(str(grenade_option.get("description", "")).contains("425%"))
	assert(not str(grenade_option.get("description", "")).contains("魔法榴弹 I："))
	assert(TOOLS.apply(player, grenade.merged({"operation": "talent", "slot": 1})))
	assert(TOOLS.LEVELS.get_granted_talent_slots(player, "gunner", "gunner_magic_grenade") == [1])
	assert(TOOLS.skill_catalog(player).filter(func(option): return str(option.get("id", "")) == "gunner_magic_grenade")[0]["description"].contains("7 枚魔法榴弹"))
	assert(not TOOLS.apply(player, grenade.merged({"operation": "talent", "slot": 2})))
	assert(TOOLS.apply(player, grenade.merged({"operation": "set", "amount": 10})))
	assert(TOOLS.LEVELS.get_granted_talent_slots(player, "gunner", "gunner_magic_grenade") == [1, 2])
	player.queue_free()
	await process_frame
	print("DEVELOPER_SKILL_TALENT_SMOKE_OK")
	quit(0)

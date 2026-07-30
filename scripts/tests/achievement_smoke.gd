extends SceneTree

class MainStub:
	extends Node
	var survival_time: float = 0.0

func _init() -> void:
	await process_frame
	var bridge_script := load("res://scripts/game/game_achievement_bridge.gd")
	if bridge_script == null:
		push_error("Cannot load game_achievement_bridge.gd")
		quit(1)
		return
	var service = root.get_node_or_null("AchievementService")
	if service == null:
		push_error("AchievementService autoload is missing")
		quit(1)
		return
	var main_stub := MainStub.new()
	root.add_child(main_stub)
	service.load_achievements()
	if not service.has_achievement("ACH_FIRST_BLOOD"):
		push_error("missing ACH_FIRST_BLOOD")
		quit(1)
		return
	service.reset_local_state()
	bridge_script.record_enemy_defeated(main_stub, "normal")
	if not service.is_unlocked("ACH_FIRST_BLOOD"):
		push_error("ACH_FIRST_BLOOD not unlocked through bridge")
		quit(1)
		return
	main_stub.survival_time = 300.0
	bridge_script.record_survival_time(main_stub)
	if not service.is_unlocked("ACH_SURVIVE_5_MIN"):
		push_error("ACH_SURVIVE_5_MIN not unlocked through bridge")
		quit(1)
		return
	bridge_script.record_endless_tier_cleared(main_stub, 3)
	if not service.is_unlocked("ACH_ENDLESS_BOSS_3"):
		push_error("ACH_ENDLESS_BOSS_3 not unlocked through bridge")
		quit(1)
		return
	bridge_script.record_player_level(main_stub, 5)
	if not service.is_unlocked("ACH_REACH_LEVEL_5"):
		push_error("ACH_REACH_LEVEL_5 not unlocked through bridge")
		quit(1)
		return
	service.reset_local_state()
	print("ACHIEVEMENT_SMOKE_OK")
	quit(0)

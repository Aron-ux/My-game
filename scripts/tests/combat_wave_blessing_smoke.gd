extends SceneTree

const FLOW_TEST := preload("res://scripts/tests/combat_wave_flow_smoke.gd")
const FLOW := preload("res://scripts/game/combat_wave_flow.gd")
const REWARDS := preload("res://scripts/game/reward_flow.gd")
const PLAYER := preload("res://scenes/player.tscn")
var failures: Array[String] = []

class TestMain:
	extends FLOW_TEST.TestMain
	var completed: int = 0
	func _on_stage_cleared() -> void:
		completed += 1

class CardUI:
	extends Control
	var options: Array = []
	var context: Dictionary = {}
	func show_options(cards: Array, _attributes: Array, offer_context: Dictionary) -> void:
		options = cards.duplicate(true)
		context = offer_context.duplicate(true)
		show()
	func hide_ui() -> void:
		hide()

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _run() -> void:
	var main := TestMain.new()
	root.add_child(main)
	current_scene = main
	main.set_process(false)
	main.set_physics_process(false)
	main.player = PLAYER.instantiate()
	main.add_child(main.player)
	main.player.set_physics_process(false)
	main.player.set_process(false)
	main.player.skill_points = 4
	main.level_up_ui = CardUI.new()
	main.add_child(main.level_up_ui)
	FLOW.setup(main)
	var flow = main.wave_flow
	flow.begin_preparation()
	check(not paused and main.reward_context == "" and not flow.blessing_pending, "Wave ending must not immediately open the Build UI")
	FLOW_TEST.finish_ending(flow)
	await process_frame
	check(paused and main.reward_context == REWARDS.WAVE_BLESSING_CONTEXT, "Wave end must open the paused build UI")
	check(main.level_up_ui.options.size() == 3 and int(main.level_up_ui.context.get("selection_count", 0)) == 1, "Build UI must offer three cards and select one")
	var seen := {}
	for option: Dictionary in main.level_up_ui.options:
		check(str(option.get("blessing_category", "")) == "general_blessing", "Only general blessings may be offered")
		check(not seen.has(option.get("blessing_id")), "Choices must have different blessing identities")
		seen[option.get("blessing_id")] = true
	check(main.player.skill_points == 4 and main.player.pending_level_ups == 0, "Opening reward must not affect skill points or level queues")
	var snapshot: Dictionary = flow.get_save_data()
	var options: Array = flow.blessing_offer.options.duplicate(true)
	main.level_up_ui.hide_ui()
	main.reward_context = ""
	paused = false
	flow.apply_save_data(snapshot)
	check(REWARDS.resume_saved_reward(main), "Continue must restore the pending wave reward")
	check(main.level_up_ui.options == options, "Continue must preserve the original random choices")
	REWARDS.handle_upgrade_selected(main, "not_offered")
	check(paused and flow.blessing_pending, "Invalid choices cannot dismiss or consume the reward")
	var selected: Dictionary = options[0]
	var before: Dictionary = main.player.get_save_data()
	REWARDS.handle_upgrade_selected(main, str(selected.id))
	var after: Dictionary = main.player.get_save_data()
	check(main.player.skill_points == 4, "Choosing a wave blessing must be free")
	check(before != after, "Choosing a wave blessing must apply its effect")
	check(not paused and not flow.blessing_pending and flow.blessing_offer.is_empty(), "Successful selection must consume the reward and resume preparation")
	flow.apply_save_data(flow.get_save_data())
	check(not REWARDS.resume_saved_reward(main), "Consumed reward must not reappear after loading")
	flow.skip_preparation()
	check(flow.wave == 2, "Preparation must still allow advancing after selection")
	flow.begin_preparation()
	main.reward_context = "small_boss_reward"
	var boss_gem := preload("res://scripts/exp_gem.gd").new()
	main.add_child(boss_gem)
	boss_gem.configure(1, 10, 1.0)
	boss_gem.global_position = main.player.global_position + Vector2(1000, 0)
	await process_frame
	check(not boss_gem.pooled and flow.phase == "clearing", "Late boss XP must remain visible until cleanup finishes")
	check(not paused and main.reward_context == "small_boss_reward", "Wave blessing must not overwrite the existing boss reward")
	main.reward_context = ""
	flow.tick(FLOW.DEATH_SECONDS)
	check(flow.phase == "collecting" and boss_gem.attraction_active, "Late boss gems must be attracted after death animation")
	check(not paused and not flow.blessing_pending, "Build must remain closed while a distant gem travels")
	var start_position: Vector2 = boss_gem.global_position
	boss_gem._run_physics_tick(0.1)
	check(boss_gem.global_position.distance_to(main.player.global_position) < start_position.distance_to(main.player.global_position), "Gem must physically fly toward the player")
	var collection_save: Dictionary = flow.get_save_data()
	flow.apply_save_data(collection_save)
	check(flow.phase == "collecting" and not flow.show_pending_blessing(), "Continue during collection cannot skip into a menu")
	FLOW_TEST.finish_ending(flow)
	check(get_nodes_in_group("exp_gems").is_empty(), "All boss XP must arrive before rewards open")
	REWARDS._schedule_post_reward_maintenance(main)
	check(paused and main.reward_context == REWARDS.WAVE_BLESSING_CONTEXT, "Wave blessing must appear after the existing reward finishes")
	REWARDS.handle_upgrade_selected(main, str(flow.blessing_offer.options[0].id))
	flow.wave = 20
	flow.phase = "combat"
	flow._begin_wave_ending(true)
	var final_gem := preload("res://scripts/exp_gem.gd").new()
	main.add_child(final_gem)
	final_gem.configure(1, 10, 1.0)
	FLOW_TEST.finish_ending(flow)
	await process_frame
	check(get_nodes_in_group("exp_gems").is_empty(), "Final-wave XP must be absorbed before victory")
	check(main.completed == 0 and paused, "Final wave blessing must precede victory")
	REWARDS.handle_upgrade_selected(main, str(flow.blessing_offer.options[0].id))
	check(main.completed == 1 and main.player.skill_points == 4, "Final wave must finish once after the free choice")
	paused = false
	for pool in main.runtime_pickup_pool_nodes.values():
		for pickup in pool.values():
			if is_instance_valid(pickup):
				pickup.free()
	main.runtime_pickup_pool_nodes.clear()
	main.free()
	await process_frame
	if failures.is_empty():
		print("COMBAT_WAVE_BLESSING_SMOKE_OK")
		quit(0)
	else:
		for message in failures:
			push_error(message)
		quit(1)

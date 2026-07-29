extends SceneTree

const REWARD_FLOW := preload("res://scripts/game/reward_flow.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_reward_chain_stays_serial()
	await _check_active_talent_save_roundtrip()
	if failures.is_empty():
		print("REWARD_FLOW_TALENT_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_reward_chain_stays_serial() -> void:
	var main := MainStub.new()
	root.add_child(main)
	main.player.pending_binding_choices.append({"blessing_id": "test_blessing"})
	main.player.pending_talent_progress_ids.assign(["swordsman_trait", "gunner_trait"])
	main.reward_context = "level_up"

	REWARD_FLOW.handle_upgrade_selected(main, "role_build_a", "general_blessing_b")
	_expect(main.player.applied_upgrade_batches == [["role_build_a", "general_blessing_b"]], "normal reward should apply exactly the selected two cards")
	_expect(main.reward_context == "blessing_binding_choice", "blessing binding should run before skill talents")
	_expect(main.level_up_ui.talent_progress_ids.is_empty(), "talent UI should wait for blessing binding")

	REWARD_FLOW.handle_upgrade_selected(main, "blade_storm")
	_expect(main.player.applied_binding_options == ["blade_storm"], "binding choice should be applied once")
	_expect(main.level_up_ui.talent_progress_ids == ["swordsman_trait"], "first pending talent should open after binding")
	_expect(main.maintenance_calls.is_empty(), "maintenance should wait until all talents finish")

	REWARD_FLOW.handle_upgrade_selected(main, "skill_talent:swordsman_trait_a")
	_expect(main.level_up_ui.talent_progress_ids == ["swordsman_trait", "gunner_trait"], "multiple talents should open one at a time")
	_expect(main.maintenance_calls.is_empty(), "next normal upgrade should still wait for remaining talents")

	REWARD_FLOW.handle_upgrade_selected(main, "skill_talent:gunner_trait_a")
	_expect(main.player.applied_talent_progress_ids == ["swordsman_trait", "gunner_trait"], "each pending talent should be applied once")
	_expect(main.maintenance_calls == [true], "reward maintenance should resume only after the last talent")
	_expect(main.player.resume_count == 1, "the next normal upgrade should resume once after the talent chain")
	_expect(main.reward_context == "", "reward context should clear after the serial chain")

	main.queue_free()
	paused = false


func _check_active_talent_save_roundtrip() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var source = PLAYER_SCENE.instantiate()
	var target = PLAYER_SCENE.instantiate()
	scene.add_child(source)
	scene.add_child(target)
	await process_frame

	source.role_special_states["swordsman"] = {
		"build_levels": {"trait_extra_roll": 1, "trait_heal_bonus": 1}
	}
	source.role_special_states["gunner"] = {
		"skill_talents": {"gunner_basic": "gunner_basic_armor"}
	}
	source.pending_level_ups = 2
	source.level_up_active = true
	source.active_upgrade_kind = "skill_talent"
	source.current_blessing_offer = source.build_next_skill_talent_offer()
	var saved: Dictionary = source.get_save_data()

	_expect(int(saved.get("pending_level_ups", -1)) == 2, "active talent save should not create a duplicate normal level-up")
	_expect(str(saved.get("active_upgrade_kind", "")) == "skill_talent", "active talent kind should be saved")

	target.apply_save_data(saved)
	var resumed_offer: Dictionary = target.build_next_skill_talent_offer()
	var resumed_context: Dictionary = resumed_offer.get("context", {})
	_expect(target.active_upgrade_kind == "skill_talent", "active talent kind should survive load")
	_expect(not target.level_up_active, "loaded talent should be reopened by reward flow instead of staying falsely active")
	_expect(target.pending_level_ups == 2, "normal level-up queue should survive active talent load unchanged")
	_expect(str(resumed_context.get("skill_progress_id", "")) == "swordsman_trait", "loaded run should derive the same pending talent")
	_expect(target._has_skill_talent("gunner_basic_armor"), "already selected talents should survive the save roundtrip")

	var save_main := MainStub.new()
	save_main.player = target
	root.add_child(save_main)
	_expect(REWARD_FLOW.resume_saved_reward(save_main), "continue flow should reopen the saved talent choice")
	_expect(target.level_up_active and target.active_upgrade_kind == "skill_talent", "reopened talent should become the active reward")
	_expect(save_main.level_up_ui.talent_progress_ids == ["swordsman_trait"], "continue flow should reopen the same pending talent UI")
	_expect(target.pending_level_ups == 2, "reopening a saved talent should not consume a normal level-up")
	save_main.queue_free()
	paused = false

	scene.queue_free()
	await process_frame
	current_scene = null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


class MainStub:
	extends Node

	var game_over := false
	var reward_context := ""
	var player: Variant = RewardPlayerStub.new()
	var level_up_ui := LevelUpUiStub.new()
	var maintenance_calls: Array[bool] = []

	func _schedule_reward_maintenance(resume_level_ups: bool) -> void:
		maintenance_calls.append(resume_level_ups)
		if resume_level_ups:
			player.resume_pending_level_ups()

	func _save_run_state() -> void:
		pass


class RewardPlayerStub:
	extends RefCounted

	var pending_binding_choices: Array[Dictionary] = []
	var pending_talent_progress_ids: Array[String] = []
	var applied_upgrade_batches: Array = []
	var applied_binding_options: Array[String] = []
	var applied_talent_progress_ids: Array[String] = []
	var current_blessing_offer: Dictionary = {}
	var level_up_active := true
	var active_upgrade_kind := "level_up"
	var resume_count := 0

	func apply_upgrades(option_ids: Array) -> void:
		applied_upgrade_batches.append(option_ids.duplicate())
		level_up_active = false
		active_upgrade_kind = ""

	func consume_pending_blessing_binding_choice() -> Dictionary:
		return pending_binding_choices.pop_front() if not pending_binding_choices.is_empty() else {}

	func build_blessing_binding_options(_choice: Dictionary) -> Array:
		return [{"id": "blade_storm"}]

	func apply_blessing_binding_choice(_choice: Dictionary, option_id: String) -> void:
		applied_binding_options.append(option_id)

	func build_next_skill_talent_offer() -> Dictionary:
		if pending_talent_progress_ids.is_empty():
			return {}
		var progress_id := pending_talent_progress_ids[0]
		return {
			"options": [
				{"id": "skill_talent:%s_a" % progress_id},
				{"id": "skill_talent:%s_b" % progress_id}
			],
			"context": {
				"skill_talent_offer": true,
				"skill_progress_id": progress_id,
				"selection_count": 1
			}
		}

	func get_current_blessing_offer_context() -> Dictionary:
		return current_blessing_offer.get("context", {})

	func apply_skill_talent_choice(option_id: String, expected_progress_id: String = "") -> bool:
		if pending_talent_progress_ids.is_empty() or pending_talent_progress_ids[0] != expected_progress_id:
			return false
		if not option_id.begins_with("skill_talent:%s_" % expected_progress_id):
			return false
		applied_talent_progress_ids.append(expected_progress_id)
		pending_talent_progress_ids.pop_front()
		return true

	func resume_pending_level_ups() -> void:
		resume_count += 1


class LevelUpUiStub:
	extends RefCounted

	var talent_progress_ids: Array[String] = []

	func hide_ui() -> void:
		pass

	func show_menu(_title: String, _options: Array) -> void:
		pass

	func show_options(_options: Array, _attribute_options: Array = [], context: Dictionary = {}) -> void:
		if bool(context.get("skill_talent_offer", false)):
			talent_progress_ids.append(str(context.get("skill_progress_id", "")))

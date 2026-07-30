extends SceneTree

const DEVELOPER_ACTIONS := preload("res://scripts/developer/developer_actions.gd")
const DEVELOPER_OPTION_PROVIDER := preload("res://scripts/developer/developer_option_provider.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")
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

	var definition_ids: Dictionary = {}
	for definitions_value in PLAYER_SKILL_TALENT_SYSTEM.TALENT_DEFINITIONS.values():
		for talent_value in definitions_value:
			definition_ids[str((talent_value as Dictionary).get("id", ""))] = true
	var talent_option_count := 0
	var has_clear_all := false
	var has_stage_two_clear := false
	var has_direct_path := false
	for option_value in DEVELOPER_OPTION_PROVIDER.get_skill_options(main.player):
		var option: Dictionary = option_value
		var option_id := str(option.get("id", ""))
		var raw_id := option_id.trim_prefix(DEVELOPER_OPTION_PROVIDER.SKILL_TALENT_OPTION_PREFIX)
		if definition_ids.has(raw_id):
			talent_option_count += 1
		has_clear_all = has_clear_all or raw_id == DEVELOPER_OPTION_PROVIDER.CLEAR_SKILL_TALENTS_OPTION_ID
		has_stage_two_clear = has_stage_two_clear or raw_id == "%sswordsman:swordsman_trait:2" % DEVELOPER_OPTION_PROVIDER.CLEAR_SKILL_TALENT_STAGE_PREFIX
		has_direct_path = has_direct_path or raw_id == "%sswordsman:swordsman_trait:221" % DEVELOPER_OPTION_PROVIDER.SKILL_TALENT_PATH_PREFIX
	_expect(talent_option_count == 108, "developer skill list should expose all 108 talent definitions")
	_expect(has_clear_all, "developer skill list should expose the global clear action")
	_expect(has_stage_two_clear, "developer skill list should expose stage-specific clear actions")
	_expect(has_direct_path, "developer skill list should expose direct three-stage path construction")

	DEVELOPER_ACTIONS.grant_skill_talent(main, "swordsman_trait_blood_battle")
	_expect(main.player.get_skill_progress_level("swordsman", "swordsman_trait") == 3, "developer talent grant should raise its skill build to Lv.3")
	_expect(main.player._has_skill_talent("swordsman_trait_blood_battle"), "developer talent grant should select the requested talent")

	DEVELOPER_ACTIONS.grant_skill_talent(main, "swordsman_trait_guard_stance")
	_expect(main.player.get_skill_progress_level("swordsman", "swordsman_trait") == 6, "developer second-stage grant should raise its skill build to Lv.6")
	_expect(main.player._has_skill_talent("swordsman_trait_guard_stance"), "developer second-stage grant should preserve and extend the path")

	DEVELOPER_ACTIONS.grant_skill_talent(main, "swordsman_trait_unyielding")
	_expect(main.player.get_skill_progress_level("swordsman", "swordsman_trait") == 9, "developer third-stage grant should raise its skill build to Lv.9")
	_expect(main.player._has_skill_talent("swordsman_trait_unyielding"), "developer third-stage grant should complete the path")

	DEVELOPER_ACTIONS.grant_skill_talent(main, "swordsman_trait_blood_surge")
	_expect(main.player._has_skill_talent("swordsman_trait_blood_battle"), "replacing stage II should preserve stage I")
	_expect(main.player._has_skill_talent("swordsman_trait_blood_surge"), "developer grant should replace the requested stage")
	_expect(not main.player._has_skill_talent("swordsman_trait_unyielding"), "replacing stage II should clear stage III")

	DEVELOPER_ACTIONS.grant_skill_talent(main, "swordsman_trait_head_high")
	_expect(main.player._has_skill_talent("swordsman_trait_head_high"), "developer grant should restore the cleared third stage")

	DEVELOPER_ACTIONS.grant_skill_talent(main, "swordsman_trait_last_guard")
	_expect(main.player._has_skill_talent("swordsman_trait_last_guard"), "developer talent grant should replace stage I")
	_expect(not main.player._has_skill_talent("swordsman_trait_blood_battle"), "replaced stage-I talent should no longer be active")
	_expect(not main.player._has_skill_talent("swordsman_trait_blood_surge"), "replacing stage I should clear stage II")
	_expect(not main.player._has_skill_talent("swordsman_trait_head_high"), "replacing stage I should clear stage III")

	DEVELOPER_ACTIONS.grant_skill_talent(main, "swordsman_trait_guard_stance")
	DEVELOPER_ACTIONS.grant_skill_talent(main, "swordsman_trait_unyielding")
	DEVELOPER_ACTIONS.grant_skill_talent(
		main,
		"%sswordsman:swordsman_trait:2" % DEVELOPER_OPTION_PROVIDER.CLEAR_SKILL_TALENT_STAGE_PREFIX
	)
	_expect(main.player._has_skill_talent("swordsman_trait_last_guard"), "clearing stage II should preserve stage I")
	_expect(not main.player._has_skill_talent("swordsman_trait_guard_stance"), "clearing stage II should remove stage II")
	_expect(not main.player._has_skill_talent("swordsman_trait_unyielding"), "clearing stage II should also remove stage III")

	DEVELOPER_ACTIONS.grant_skill_talent(
		main,
		"%sswordsman:swordsman_trait:221" % DEVELOPER_OPTION_PROVIDER.SKILL_TALENT_PATH_PREFIX
	)
	_expect(
		PLAYER_SKILL_TALENT_SYSTEM.get_selected_talents(main.player, "swordsman", "swordsman_trait") == [
			"swordsman_trait_last_guard",
			"swordsman_trait_guard_stance",
			"swordsman_trait_head_high"
		],
		"developer path action should construct the requested ordered three-stage path"
	)

	DEVELOPER_ACTIONS.grant_skill_talent(main, "mage_meta_transfer")
	_expect(PLAYER_BLESSING_SKILL_STATE.is_skill_unlocked(main.player, "meta_field"), "developer active-skill talent should unlock the required skill")
	_expect(main.player.get_skill_progress_level("mage", "mage_meta_field") == 3, "developer active-skill talent should raise the unlocked skill to Lv.3")
	_expect(main.player._has_skill_talent("mage_meta_transfer"), "developer active-skill talent should be selected")
	var meta_slot_name := ""
	for slot_value in main.player._get_role_skill_cooldown_slots("mage", 2.5):
		var slot: Dictionary = slot_value
		if str(slot.get("skill_id", "")) == "meta_field":
			meta_slot_name = str(slot.get("name", ""))
	_expect(meta_slot_name == "梅塔领域·领域转移", "developer talent grant should refresh the evolved skill name in HUD payloads")
	_expect(main.player.get_skill_graph_text("mage").contains("梅塔领域·领域转移"), "character panel graph should use the evolved skill name")

	DEVELOPER_ACTIONS.grant_skill_talent(main, DEVELOPER_OPTION_PROVIDER.CLEAR_SKILL_TALENTS_OPTION_ID)
	_expect(not main.player._has_skill_talent("swordsman_trait_last_guard") and not main.player._has_skill_talent("mage_meta_transfer"), "developer clear action should remove all selected talents")
	_expect(main.player.get_skill_progress_level("mage", "mage_meta_field") == 3, "developer clear action should preserve build progress")
	_expect(main.refresh_count == 12 and main.save_count == 12, "each successful developer talent action should refresh and save once")

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

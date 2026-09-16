extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")
const PLAYER_ABILITY_FLOW := preload("res://scripts/player/player_ability_flow.gd")
const PLAYER_SKILL_COOLDOWN_FLOW := preload("res://scripts/player/player_skill_cooldown_flow.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# 1) 设置层：默认自动、切换可反转、随设置持久（与存档无关）
	var previous_manual := GAME_SETTINGS.is_skill_manual("blade_storm")
	GAME_SETTINGS.set_skill_manual("blade_storm", false)
	assert(not GAME_SETTINGS.is_skill_manual("blade_storm"), "skills should default to auto release")
	assert(GAME_SETTINGS.toggle_skill_manual("blade_storm"), "toggle should switch to manual")
	assert(GAME_SETTINGS.is_skill_manual("blade_storm"), "manual state should persist in settings")
	assert(not GAME_SETTINGS.toggle_skill_manual("blade_storm"), "toggle should switch back to auto")
	assert(not GAME_SETTINGS.is_skill_manual("blade_storm"), "auto state should persist in settings")

	# 2) 事件映射：槽位动作按设置的键位解析
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = GAME_SETTINGS.load_keycode(GAME_SETTINGS.get_skill_slot_action_id(2))
	assert(GAME_SETTINGS.get_skill_slot_index_for_event(key_event) == 2, "slot key should map to its slot index")

	# 3) 分发层：自动状态快捷键不施放；手动状态快捷键施放；手动状态不自动施放
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	var player = PLAYER_SCENE.instantiate()
	holder.add_child(player)
	await process_frame
	assert(PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(player, "blade_storm", 1), "blade storm should unlock")
	var slot_index := _find_slot_index(player, "blade_storm")
	assert(slot_index > 0, "blade storm should occupy a hotkey slot")
	GAME_SETTINGS.set_skill_manual("blade_storm", false)
	assert(PLAYER_ABILITY_FLOW.try_handle_manual_skill_slot(player, slot_index), "auto state should consume the hotkey and show a hint")
	assert(not player.swordsman_blade_storm_ability.is_active(), "auto state hotkey should not cast the skill")
	assert(PLAYER_ABILITY_FLOW.toggle_skill_manual(player, "blade_storm"), "toggle should turn manual on")
	assert(GAME_SETTINGS.is_skill_manual("blade_storm"), "blade storm should now be manual")
	PLAYER_ABILITY_FLOW.try_trigger_swordsman_blade_storm(player)
	assert(not player.swordsman_blade_storm_ability.is_active(), "manual skill should not auto cast")
	assert(PLAYER_ABILITY_FLOW.try_handle_manual_skill_slot(player, slot_index), "manual state should cast from the hotkey")
	assert(player.swordsman_blade_storm_ability.is_active(), "hotkey cast should activate the skill")
	PLAYER_ABILITY_FLOW.toggle_manual_skill_slot(player, slot_index)
	assert(not GAME_SETTINGS.is_skill_manual("blade_storm"), "slot toggle should turn manual off again")

	# 4) 槽位交换：拖动交换等价于重排该角色的技能槽顺序（全局设置，测试前后保存还原）
	var previous_order: Array[String] = GAME_SETTINGS.get_skill_slot_order("swordsman")
	GAME_SETTINGS.set_skill_slot_order("swordsman", [])
	assert(PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(player, "knight_thrust", 1), "knight thrust should unlock")
	var order_before: Array[String] = PLAYER_SKILL_COOLDOWN_FLOW.get_role_active_skill_ids(player, "swordsman")
	assert(order_before.size() >= 2, "swordsman should have at least two skill slots")
	var first_skill: String = order_before[0]
	var second_skill: String = order_before[1]
	assert(player._swap_skill_slot_order("swordsman", 1, 2), "slot swap should succeed")
	var order_after: Array[String] = PLAYER_SKILL_COOLDOWN_FLOW.get_role_active_skill_ids(player, "swordsman")
	assert(order_after[0] == second_skill and order_after[1] == first_skill, "slots should exchange positions")
	GAME_SETTINGS.set_skill_slot_order("swordsman", [])
	var order_restored: Array[String] = PLAYER_SKILL_COOLDOWN_FLOW.get_role_active_skill_ids(player, "swordsman")
	assert(order_restored[0] == first_skill, "clearing the custom order should restore the unlock order")
	GAME_SETTINGS.set_skill_slot_order("swordsman", previous_order)

	# 5) 无天赋的无限装填按普通技能处理：手动状态下快捷键应能单次施放（不再是只能开关）
	assert(PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(player, "infinite_reload", 1), "infinite reload should unlock")
	player.active_role_index = 1
	GAME_SETTINGS.set_skill_manual("infinite_reload", true)
	var reload_slot := _find_slot_index(player, "infinite_reload", "gunner")
	assert(reload_slot > 0, "infinite reload should occupy a gunner slot")
	assert(PLAYER_ABILITY_FLOW.try_handle_manual_skill_slot(player, reload_slot), "manual infinite reload without talent should cast from the hotkey")
	assert(player.gunner_infinite_reload_ability.is_active(), "infinite reload should be active after the hotkey cast")
	GAME_SETTINGS.set_skill_manual("infinite_reload", false)

	GAME_SETTINGS.set_skill_manual("blade_storm", previous_manual)
	print("SKILL_MANUAL_MODE_SMOKE_OK")
	quit(0)


func _find_slot_index(player, skill_id: String, role_id: String = "swordsman") -> int:
	var skill_ids: Array[String] = PLAYER_SKILL_COOLDOWN_FLOW.get_role_active_skill_ids(player, role_id)
	for index in range(skill_ids.size()):
		if skill_ids[index] == skill_id:
			return index + 1
	return 0

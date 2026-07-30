extends SceneTree

const CHARACTER_PANEL := preload("res://scripts/ui/hud/character_panel.gd")
const HUD := preload("res://scripts/hud.gd")
const PLAYER_STAT_PAYLOAD := preload("res://scripts/player/player_stat_payload.gd")

var failures: Array[String] = []


class StoneOwner:
	extends Node

	func get_ruan_bone_count() -> int:
		return 17

	func get_ruan_stone_level(stone_id: String) -> int:
		return 3 if stone_id == "thunder" else 0

	func get_equipped_ruan_stone() -> String:
		return "thunder"

	func _get_role_equipment_levels(_role_id: String) -> Dictionary:
		return {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := StoneOwner.new()
	root.add_child(owner)
	var projection := PLAYER_STAT_PAYLOAD._build_ruan_stone_summary(owner)
	_expect(projection.get("ruan_bone_count") == 17, "统计投影未包含骨头数量。")
	_expect(projection.get("equipped_ruan_stone_title") == "雷石", "统计投影未解析石头名称。")

	var hud := HUD.new()
	root.add_child(hud)
	await process_frame
	var hud_panel := hud.find_child("RuanStoneHudPanel", true, false)
	var hud_label := hud.find_child("RuanStoneHudLabel", true, false) as Label
	_expect(hud_panel != null and hud_label != null, "战斗 HUD 缺少常驻阮石状态控件。")
	if hud_label != null:
		var original_id := hud_label.get_instance_id()
		hud.update_stats(projection)
		_expect(hud_label.text.contains("骨头 17") and hud_label.text.contains("雷石 Lv.3"), "战斗 HUD 未显示骨头和当前石头。")
		hud.update_stats(projection)
		_expect(hud.find_child("RuanStoneHudLabel", true, false).get_instance_id() == original_id, "刷新 HUD 时重建了阮石控件。")

	var character_panel := CHARACTER_PANEL.new()
	var equipment_list := HBoxContainer.new()
	character_panel.set("equipment_list", equipment_list)
	character_panel.set("cached_player", owner)
	character_panel.call("_refresh_equipment_list", "swordsman")
	var stone_slot := equipment_list.get_node_or_null("RuanStoneSlot") as Button
	_expect(stone_slot != null, "角色面板装备行缺少全局阮石槽。")
	if stone_slot != null:
		_expect(stone_slot == equipment_list.get_child(0), "阮石槽不是装备行第一项。")
		_expect(stone_slot.text.contains("全队") and stone_slot.text.contains("雷石 Lv.3"), "阮石槽未明确显示共享范围、名称和等级。")
		_expect(stone_slot.text.contains("36%") and stone_slot.tooltip_text.contains("不可赠与"), "阮石槽未显示当前效果或不可赠与说明。")

	equipment_list.free()
	character_panel.free()
	root.remove_child(hud)
	hud.free()
	root.remove_child(owner)
	owner.free()
	await process_frame
	if failures.is_empty():
		print("RUAN_STONE_UI_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

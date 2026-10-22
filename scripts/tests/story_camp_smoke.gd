extends SceneTree

const SAVE := preload("res://scripts/save_manager.gd")
const STORE := preload("res://scripts/save/save_file_store.gd")
const CAMP := preload("res://scenes/endless_camp.tscn")
const ITEMS := preload("res://scripts/player/ruan_stone_system.gd")
const SLOT := 1

var originals: Dictionary = {}
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in [STORE.META_PATH, STORE.story_profile_path(SLOT), STORE.story_run_path(SLOT), STORE.story_run_backup_path(SLOT)]:
		originals[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	SAVE.create_or_load_story_profile(SLOT)
	var profile := SAVE.load_story_profile(SLOT)
	profile["boss_core_fragments"] = 2
	profile["current_stage_index"] = 0
	profile["ruan_stone_purchased"] = []
	SAVE.save_story_profile(profile, SLOT)
	SAVE.set_active_slot(SLOT)

	var camp := CAMP.instantiate()
	root.add_child(camp)
	await process_frame
	_expect(camp.overview.title_label.text == "主线营地", "主线档案应显示主线营地标题。")
	_expect(camp.overview.status_label.text.contains("Boss 核心 2"), "主线营地应显示 Boss 核心余额。")

	camp._open_ruan_stone_shop()
	var shop: Control = camp.shop_panel
	shop.selected_id = "thunder"
	shop._refresh()
	_expect(shop.buy_button.text.contains("1 Boss 核心"), "主线商店应按 Boss 核心显示价格。")
	shop.buy_button.pressed.emit()
	var after := SAVE.load_story_profile(SLOT)
	_expect(ITEMS.get_count(after, "thunder") == 1 and int(after.get("boss_core_fragments", 0)) == 1, "主线商店购买应扣除 Boss 核心并保存携带物品。")
	_expect(shop.inventory_grid.get_child_count() == 17, "阮狗商店应以物品格子呈现全部商品。")
	var first_card: Button = shop.inventory_grid.get_child(0)
	_expect(not _has_texture_rect(first_card), "商店道具格应仅显示文字名称，不依赖图片资源。")
	_expect(_collect_text(first_card).contains(str(ITEMS.get_definition("thunder").get("title", ""))), "商店道具格应显示道具名称。")
	_expect(shop.carried_slots.get_child_count() == ITEMS.get_carry_limit(after), "背包应按当前携带上限展示装备槽。")
	_expect((shop.carried_slots.get_child(0).get_child(0) as Label).text == "雷石", "购买成功后装备槽应显示已携带物品。")
	camp._close_panels()

	camp._open_tier_overlay()
	await process_frame
	_expect(current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn", "主线出击应进入现有战斗场景。")
	_restore()
	if failures.is_empty():
		print("STORY_CAMP_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _collect_text(node: Node) -> String:
	var result := ""
	if node is Label:
		result += (node as Label).text
	for child in node.get_children():
		result += _collect_text(child)
	return result

func _has_texture_rect(node: Node) -> bool:
	if node is TextureRect:
		return true
	for child in node.get_children():
		if _has_texture_rect(child):
			return true
	return false

func _restore() -> void:
	for path in originals:
		var bytes: Variant = originals[path]
		if bytes == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(bytes)
				file.close()

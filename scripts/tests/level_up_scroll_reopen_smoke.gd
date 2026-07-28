extends SceneTree

const LEVEL_UP_UI_SCENE := preload("res://scenes/level_up_ui.tscn")
const MAGIC_STONE_CARD_PATH := "res://assets/UI/card/magicstone.tscn"
const STONE_CARD_PATH := "res://assets/UI/card/stone.tscn"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ui := LEVEL_UP_UI_SCENE.instantiate()
	root.add_child(ui)

	ui.show_menu("技能奖励 1", _make_options("first", 18))
	await process_frame
	await process_frame
	_check_scroll_range(ui, "first skill panel should be scrollable")

	ui.hide_ui()
	ui.show_menu("技能奖励 2", _make_options("second", 18))
	await process_frame
	await process_frame
	_check_scroll_range(ui, "second same-frame skill panel should stay scrollable")

	ui.hide_ui()
	await _check_build_multi_select_toggle(ui)
	await _check_build_card_refresh_update(ui)
	_check_role_build_card_scene_routing(ui)

	ui.queue_free()
	await process_frame
	if failures.is_empty():
		print("LEVEL_UP_SCROLL_REOPEN_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _make_options(prefix: String, count: int) -> Array:
	var options: Array = []
	for index in range(count):
		options.append({
			"id": "%s_%d" % [prefix, index],
			"title": "技能选项 %d" % [index + 1],
			"description": "用于验证连续奖励面板滚动条的长列表选项。",
			"preview_description": "滚动验证"
		})
	return options


func _make_build_options() -> Array:
	var options: Array = []
	for index in range(4):
		options.append({
			"id": "role_build:test:%d" % index,
			"title": "构筑选项 %d" % [index + 1],
			"summary": "用于验证构筑卡片选中切换。",
			"option_category": "role_build",
			"blessing_tier": 1
		})
	return options


func _make_refreshed_build_options(refreshed_index: int) -> Array:
	var options := _make_build_options()
	if refreshed_index >= 0 and refreshed_index < options.size():
		var option: Dictionary = options[refreshed_index]
		option["id"] = "role_build:test:refreshed_%d" % refreshed_index
		option["title"] = "刷新后的构筑 %d" % [refreshed_index + 1]
		option["summary"] = "用于验证单卡刷新。"
		options[refreshed_index] = option
	return options


func _check_build_multi_select_toggle(ui: Node) -> void:
	ui.show_options(_make_build_options(), [], {
		"role_build_offer": true,
		"selection_count": 2
	})
	await process_frame
	await create_timer(0.7).timeout
	var entries: Array = ui.get("build_card_entries")
	if entries.is_empty():
		failures.append("build multi-select toggle: missing build card entries")
		return
	var entry: Dictionary = entries[0]
	var card := entry.get("button") as TextureButton
	var option: Dictionary = entry.get("option", {})
	if card == null:
		failures.append("build multi-select toggle: missing card button")
		return
	ui.call("_on_build_card_pressed", card, option)
	await process_frame
	var selected_ids: Array = ui.get("pending_blessing_option_ids")
	if selected_ids.size() != 1:
		failures.append("build multi-select toggle: first click should select one card, got %d" % selected_ids.size())
	var outline := card.get_node_or_null("SelectedOutline") as Control
	if outline == null or not outline.visible:
		failures.append("build multi-select toggle: selected card should show outline")
	ui.call("_on_build_card_pressed", card, option)
	await process_frame
	selected_ids = ui.get("pending_blessing_option_ids")
	if not selected_ids.is_empty():
		failures.append("build multi-select toggle: second click should cancel selection, got %d" % selected_ids.size())
	if outline != null and outline.visible:
		failures.append("build multi-select toggle: deselected card should hide outline")


func _check_build_card_refresh_update(ui: Node) -> void:
	var context := {
		"role_build_offer": true,
		"selection_count": 2
	}
	ui.show_options(_make_build_options(), [], context)
	await process_frame
	await create_timer(0.7).timeout
	var entries: Array = ui.get("build_card_entries")
	if entries.size() != 4:
		failures.append("build card refresh: expected 4 build card entries, got %d" % entries.size())
		return
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var refresh_button := entry.get("refresh_button") as Button
		var card := entry.get("button") as Control
		if refresh_button == null or not refresh_button.visible:
			failures.append("build card refresh: card %d should show a refresh button" % index)
		elif card != null and refresh_button.position.y <= card.position.y:
			failures.append("build card refresh: card %d refresh button should be below the card top" % index)
		var normal_style: StyleBoxFlat = null
		if refresh_button != null:
			normal_style = refresh_button.get_theme_stylebox("normal") as StyleBoxFlat
		if normal_style != null and normal_style.bg_color.a > 0.40:
			failures.append("build card refresh: refresh button should use lower alpha, got %.2f" % normal_style.bg_color.a)
	var emitted_refresh_indices: Array[int] = []
	ui.upgrade_card_refresh_requested.connect(func(option_index: int) -> void:
		emitted_refresh_indices.append(option_index)
	)
	ui.call("_on_build_card_refresh_pressed", 0)
	await create_timer(0.25).timeout
	if emitted_refresh_indices.size() != 1 or emitted_refresh_indices[0] != 0:
		failures.append("build card refresh: first refresh click should emit index 0, got %s" % str(emitted_refresh_indices))
	ui.show_refreshed_build_options(_make_refreshed_build_options(0), context, 0)
	await process_frame
	entries = ui.get("build_card_entries")
	var refreshed_button := (entries[0] as Dictionary).get("refresh_button") as Button
	if refreshed_button == null or not refreshed_button.disabled:
		failures.append("build card refresh: refreshed card button should be disabled for the rest of this level-up")
	ui.call("_on_build_card_refresh_pressed", 0)
	await process_frame
	if emitted_refresh_indices.size() != 1:
		failures.append("build card refresh: second refresh click on same card should not emit again, got %s" % str(emitted_refresh_indices))
	var first_entry: Dictionary = entries[0]
	var first_card := first_entry.get("button") as TextureButton
	var first_option: Dictionary = first_entry.get("option", {})
	ui.call("_on_build_card_pressed", first_card, first_option)
	await process_frame
	ui.show_refreshed_build_options(_make_refreshed_build_options(0), context, 0)
	await process_frame
	var selected_ids: Array = ui.get("pending_blessing_option_ids")
	if not selected_ids.is_empty():
		failures.append("build card refresh: refreshing selected card should cancel that selection, got %s" % str(selected_ids))
	entries = ui.get("build_card_entries")
	var refreshed_option: Dictionary = (entries[0] as Dictionary).get("option", {})
	if str(refreshed_option.get("id", "")) != "role_build:test:refreshed_0":
		failures.append("build card refresh: refreshed card should be replaced, got %s" % str(refreshed_option))
	var second_entry: Dictionary = entries[1]
	var second_card := second_entry.get("button") as TextureButton
	var second_option: Dictionary = second_entry.get("option", {})
	var second_id := str(second_option.get("id", ""))
	ui.call("_on_build_card_pressed", second_card, second_option)
	await process_frame
	ui.show_refreshed_build_options(_make_refreshed_build_options(0), context, 0)
	await process_frame
	selected_ids = ui.get("pending_blessing_option_ids")
	if selected_ids.size() != 1 or not selected_ids.has(second_id):
		failures.append("build card refresh: refreshing another card should preserve existing selection, got %s" % str(selected_ids))


func _check_role_build_card_scene_routing(ui: Node) -> void:
	var scene: PackedScene = ui.call("_get_build_card_scene", {
		"option_category": "role_build",
		"unlock_skill": "blade_storm",
		"blessing_tier": 1
	})
	if scene == null or scene.resource_path != MAGIC_STONE_CARD_PATH:
		failures.append("role skill unlock build should use magicstone card scene, got %s" % (scene.resource_path if scene != null else "null"))
	var stone_scene: PackedScene = ui.call("_get_build_card_scene", {
		"option_category": "role_build",
		"build_card_scene": "stone",
		"blessing_tier": 1
	})
	if stone_scene == null or stone_scene.resource_path != STONE_CARD_PATH:
		failures.append("stone role build should use stone card scene, got %s" % (stone_scene.resource_path if stone_scene != null else "null"))
	var normal_scene: PackedScene = ui.call("_get_build_card_scene", {
		"option_category": "role_build",
		"blessing_tier": 1
	})
	if normal_scene == null or normal_scene.resource_path == MAGIC_STONE_CARD_PATH or normal_scene.resource_path == STONE_CARD_PATH:
		failures.append("normal role build should use normal card scene, got %s" % (normal_scene.resource_path if normal_scene != null else "null"))


func _check_scroll_range(ui: Node, failure_message: String) -> void:
	var card_list: Variant = ui.get("card_list")
	if card_list == null:
		failures.append("%s: missing card list" % failure_message)
		return
	var scroll_area: Variant = card_list.get("scroll_area")
	if scroll_area == null:
		failures.append("%s: missing scroll area" % failure_message)
		return
	var scroll_bar: VScrollBar = (scroll_area as ScrollContainer).get_v_scroll_bar()
	if scroll_bar == null or scroll_bar.max_value <= scroll_bar.page:
		failures.append("%s: scrollbar range max %.1f page %.1f" % [failure_message, scroll_bar.max_value if scroll_bar != null else 0.0, scroll_bar.page if scroll_bar != null else 0.0])

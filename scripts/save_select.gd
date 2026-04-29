extends Control

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const STORY_DATA := preload("res://scripts/story_data.gd")

func _ready() -> void:
	if not STORY_DATA.is_story_mode_enabled():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.06, 0.08, 0.12, 1.0)
	add_child(background)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 64)
	root_margin.add_theme_constant_override("margin_top", 48)
	root_margin.add_theme_constant_override("margin_right", 64)
	root_margin.add_theme_constant_override("margin_bottom", 48)
	add_child(root_margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	root_margin.add_child(content)

	var title := Label.new()
	title.text = "选择主线存档"
	title.add_theme_font_size_override("font_size", 32)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "第一阶段先接 3 个独立存档位。"
	subtitle.add_theme_font_size_override("font_size", 18)
	content.add_child(subtitle)

	for slot_payload in SAVE_MANAGER.list_story_slots():
		content.add_child(_build_slot_card(slot_payload))

	var back_button := Button.new()
	back_button.text = "返回主菜单"
	back_button.custom_minimum_size = Vector2(180, 48)
	back_button.pressed.connect(_on_back_pressed)
	content.add_child(back_button)

func _build_slot_card(slot_payload: Dictionary) -> Control:
	var slot_id: int = int(slot_payload.get("slot_id", 0))
	var has_profile: bool = bool(slot_payload.get("has_profile", false))
	var profile: Dictionary = slot_payload.get("profile", {})

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 128)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var info_column := VBoxContainer.new()
	info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_column.add_theme_constant_override("separation", 8)
	row.add_child(info_column)

	var slot_title := Label.new()
	slot_title.text = "存档 %d" % slot_id
	slot_title.add_theme_font_size_override("font_size", 24)
	info_column.add_child(slot_title)

	var detail_label := Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if has_profile:
		var stage_index: int = int(profile.get("current_stage_index", 0))
		var stage_data := STORY_DATA.get_stage(stage_index)
		var stage_text := "主线已完成" if stage_data.is_empty() else str(stage_data.get("title", "未知关卡"))
		detail_label.text = "当前进度：%s\nBoss核心：%d" % [stage_text, int(profile.get("boss_core_fragments", 0))]
	else:
		detail_label.text = "空存档。\n新建后将从第一章第一关开始。"
	info_column.add_child(detail_label)

	var button_column := VBoxContainer.new()
	button_column.custom_minimum_size = Vector2(180, 0)
	button_column.add_theme_constant_override("separation", 10)
	row.add_child(button_column)

	var enter_button := Button.new()
	enter_button.text = "继续" if has_profile else "新建"
	enter_button.custom_minimum_size = Vector2(180, 44)
	enter_button.pressed.connect(_on_slot_pressed.bind(slot_id))
	button_column.add_child(enter_button)

	var delete_button := Button.new()
	delete_button.text = "删除存档"
	delete_button.custom_minimum_size = Vector2(180, 40)
	delete_button.disabled = not has_profile
	delete_button.pressed.connect(_on_delete_pressed.bind(slot_id))
	button_column.add_child(delete_button)

	return panel

func _on_slot_pressed(slot_id: int) -> void:
	if SAVE_MANAGER.create_or_load_story_profile(slot_id).is_empty():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
		return
	get_tree().change_scene_to_file(STORY_DATA.PREP_SCENE_PATH)

func _on_delete_pressed(slot_id: int) -> void:
	SAVE_MANAGER.delete_story_profile(slot_id)
	_build_ui()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

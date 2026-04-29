extends CanvasLayer

signal upgrade_selected(option_id: String, attribute_option_id: String)

const LEVEL_UP_DETAIL_OVERLAY := preload("res://scripts/ui/level_up/level_up_detail_overlay.gd")
const BUILD_SLOT_MENU := preload("res://scripts/ui/level_up/build_slot_menu.gd")
const LONG_PRESS_TIME := 0.28
const HOVER_DETAIL_TIME := 0.38

var root: Control
var dimmer: ColorRect
var panel: PanelContainer
var title_label: Label
var hint_label: Label
var attribute_row: HBoxContainer
var attribute_buttons: Array[Button] = []
var direct_button_container: VBoxContainer
var direct_buttons: Array[Button] = []
var build_slot_menu: HBoxContainer
var detail_overlay: Control
var current_options: Array = []
var current_attribute_options: Array = []
var build_groups: Dictionary = {}
var current_mode: String = "direct"
var active_slot_id: String = ""
var pending_build_option_id: String = ""
var pending_build_title: String = ""
var pending_attribute_option_id: String = ""
var pending_attribute_title: String = ""
var pending_equipment_option_id: String = ""
var pending_equipment_title: String = ""
var pending_card_option_id: String = ""
var pending_card_title: String = ""
var hold_slot_id: String = ""
var hold_option_index: int = -1
var hold_elapsed: float = 0.0
var hold_detail_shown: bool = false
var hover_slot_id: String = ""
var hover_option_index: int = -1
var hover_elapsed: float = 0.0
var hover_detail_shown: bool = false

func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.7)
	root.add_child(dimmer)

	var center_container := CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center_container)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 440)
	center_container.add_child(panel)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)

	title_label = Label.new()
	title_label.text = "\u5347\u7EA7\u9009\u62E9"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	content.add_child(title_label)

	hint_label = Label.new()
	hint_label.text = "\u6BCF\u7EA7\u5148\u9009 1 \u4E2A\u5C5E\u6027\u52A0\u70B9\uff0C\u518D\u9009 1 \u5F20 Build\u3002\u77ED\u6309\u9009\u724C\uff0C\u957F\u6309\u6216\u957F\u60AC\u505C\u770B\u4E09\u7EA7\u8BE6\u60C5\uff0C\u70B9\u51FB\u84DD\u8272\u672F\u8BED\u53EF\u6253\u5F00\u56DB\u7EA7\u8BF4\u660E\u3002"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.modulate = Color(0.9, 0.9, 0.9, 0.9)
	content.add_child(hint_label)

	attribute_row = HBoxContainer.new()
	attribute_row.alignment = BoxContainer.ALIGNMENT_CENTER
	attribute_row.add_theme_constant_override("separation", 14)
	content.add_child(attribute_row)

	for index in range(3):
		var attribute_button := Button.new()
		attribute_button.custom_minimum_size = Vector2(280, 96)
		attribute_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		attribute_button.add_theme_font_size_override("font_size", 18)
		attribute_button.visible = false
		attribute_button.pressed.connect(_on_attribute_option_pressed.bind(index))
		attribute_row.add_child(attribute_button)
		attribute_buttons.append(attribute_button)

	direct_button_container = VBoxContainer.new()
	direct_button_container.add_theme_constant_override("separation", 12)
	content.add_child(direct_button_container)

	_ensure_direct_button_count(3)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	build_slot_menu = BUILD_SLOT_MENU.new()
	build_slot_menu.setup(root)
	build_slot_menu.category_hovered.connect(_on_category_hovered)
	build_slot_menu.option_button_down.connect(_on_submenu_option_button_down)
	build_slot_menu.option_button_up.connect(_on_submenu_option_button_up)
	content.add_child(build_slot_menu)

	detail_overlay = LEVEL_UP_DETAIL_OVERLAY.new()
	detail_overlay.focus_pressed.connect(_on_focus_blur_pressed)
	root.add_child(detail_overlay)

	hide_ui()

func _process(delta: float) -> void:
	if not visible or (current_mode != "build" and current_mode != "small_boss_pair"):
		return

	if hold_slot_id != "" and hold_option_index >= 0:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			hold_elapsed += delta
			if hold_elapsed >= LONG_PRESS_TIME and not hold_detail_shown:
				_show_detail_panel(hold_slot_id, hold_option_index)
				hold_detail_shown = true
		else:
			_cancel_hold_state()

	var hovered := get_viewport().gui_get_hovered_control()
	var hover_option: Dictionary = build_slot_menu.resolve_hover_option(hovered) if build_slot_menu != null else {}
	var hovered_option_slot_id := str(hover_option.get("slot_id", ""))
	var hovered_option_index := int(hover_option.get("option_index", -1))
	if hovered_option_slot_id != "" and hovered_option_index >= 0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if hovered_option_slot_id != hover_slot_id or hovered_option_index != hover_option_index:
			hover_slot_id = hovered_option_slot_id
			hover_option_index = hovered_option_index
			hover_elapsed = 0.0
			hover_detail_shown = false
		else:
			hover_elapsed += delta
			if hover_elapsed >= HOVER_DETAIL_TIME and not hover_detail_shown:
				_show_detail_panel(hover_slot_id, hover_option_index)
				hover_detail_shown = true
	else:
		_cancel_hover_state()

	var slot_id: String = build_slot_menu.resolve_hover_slot(hovered) if build_slot_menu != null else ""
	if slot_id == "":
		if active_slot_id != "" and _is_mouse_within_active_slot_bridge():
			return
		_hide_all_submenus()
		_hide_detail_panel()
		_hide_final_progress_panel()
		_hide_glossary_panel()
		active_slot_id = ""
		_update_focus_blur()
		return

	if slot_id != active_slot_id:
		_show_submenu(slot_id)

func show_options(options: Array, attribute_options: Array = []) -> void:
	current_mode = "build"
	current_options = options
	current_attribute_options = attribute_options
	build_groups = _group_build_options(options)
	pending_build_option_id = ""
	pending_build_title = ""
	pending_attribute_option_id = ""
	pending_attribute_title = ""
	pending_equipment_option_id = ""
	pending_equipment_title = ""
	pending_card_option_id = ""
	pending_card_title = ""
	panel.custom_minimum_size = Vector2(980, 440)
	title_label.text = "\u5347\u7EA7\u9009\u62E9"
	hint_label.visible = true
	direct_button_container.visible = false
	attribute_row.visible = not current_attribute_options.is_empty()
	build_slot_menu.visible = true
	_refresh_attribute_buttons()
	_refresh_selection_hint()

	if build_slot_menu != null and build_slot_menu.has_method("set_groups"):
		build_slot_menu.set_groups(build_groups)
	if build_slot_menu != null and build_slot_menu.has_method("set_selected_options"):
		build_slot_menu.set_selected_options({})

	_hide_all_submenus()
	active_slot_id = ""
	_hide_detail_panel()
	_hide_final_progress_panel()
	_hide_glossary_panel()
	visible = true
	_update_focus_blur()
	call_deferred("_refresh_submenu_positions")

func show_menu(title: String, options: Array) -> void:
	current_mode = "direct"
	current_options = options
	current_attribute_options = []
	title_label.text = title
	hint_label.visible = false
	direct_button_container.visible = true
	attribute_row.visible = false
	build_slot_menu.visible = false
	_hide_all_submenus()
	_hide_detail_panel()
	_hide_final_progress_panel()
	_hide_glossary_panel()
	active_slot_id = ""
	pending_build_option_id = ""
	pending_build_title = ""
	pending_attribute_option_id = ""
	pending_attribute_title = ""
	pending_equipment_option_id = ""
	pending_equipment_title = ""
	pending_card_option_id = ""
	pending_card_title = ""
	panel.custom_minimum_size = Vector2(980, max(440.0, 250.0 + float(current_options.size()) * 82.0))
	_update_focus_blur()
	if build_slot_menu != null and build_slot_menu.has_method("set_selected_options"):
		build_slot_menu.set_selected_options({})
	_ensure_direct_button_count(current_options.size())

	for index in range(direct_buttons.size()):
		var button := direct_buttons[index]
		if index < current_options.size():
			var option: Dictionary = current_options[index]
			var slot_label := str(option.get("slot_label", ""))
			var prefix := "[%s] " % slot_label if slot_label != "" else ""
			button.visible = true
			button.text = "%s%s\n%s" % [prefix, option.get("title", "\u5347\u7EA7"), option.get("description", "")]
		else:
			button.visible = false

	visible = true

func show_small_boss_reward_menu(title: String, options: Array) -> void:
	current_mode = "small_boss_pair"
	current_options = options
	current_attribute_options = []
	build_groups = _group_small_boss_reward_options(options)
	pending_build_option_id = ""
	pending_build_title = ""
	pending_attribute_option_id = ""
	pending_attribute_title = ""
	pending_equipment_option_id = ""
	pending_equipment_title = ""
	pending_card_option_id = ""
	pending_card_title = ""
	panel.custom_minimum_size = Vector2(980, 440)
	title_label.text = title
	hint_label.visible = true
	direct_button_container.visible = false
	attribute_row.visible = false
	build_slot_menu.visible = true
	hint_label.text = "\u5148\u4ece\u9053\u5177\u4e2d\u9009 1 \u4e2a\uff0c\u518d\u4ece\u5361\u724c\u4e2d\u9009 1 \u4e2a\u3002\u9f20\u6807\u79fb\u5230\u5206\u7c7b\u4e0a\u5c55\u5f00\u9009\u9879\uff0c\u957f\u6309\u6216\u957f\u60ac\u505c\u770b\u8be6\u60c5\u3002\n\u5f53\u524d\uff1a\u9053\u5177 \u672a\u9009 | \u5361\u724c \u672a\u9009"
	if build_slot_menu != null and build_slot_menu.has_method("set_groups"):
		build_slot_menu.set_groups(build_groups, ["equipment", "card"], {
			"equipment": "\u9053\u5177",
			"card": "\u5361\u724c"
		})
	if build_slot_menu != null and build_slot_menu.has_method("set_selected_options"):
		build_slot_menu.set_selected_options({})

	_hide_all_submenus()
	active_slot_id = ""
	_hide_detail_panel()
	_hide_final_progress_panel()
	_hide_glossary_panel()
	visible = true
	_update_focus_blur()
	call_deferred("_refresh_submenu_positions")

func _ensure_direct_button_count(count: int) -> void:
	while direct_buttons.size() < count:
		var index := direct_buttons.size()
		var button := Button.new()
		button.custom_minimum_size = Vector2(720, 76)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 17)
		button.text = "\u9009\u9879 %d" % (index + 1)
		button.pressed.connect(_on_direct_option_pressed.bind(index))
		direct_button_container.add_child(button)
		direct_buttons.append(button)

func hide_ui() -> void:
	visible = false
	_hide_all_submenus()
	_hide_detail_panel()
	_hide_final_progress_panel()
	_hide_glossary_panel()
	_cancel_hold_state()
	_cancel_hover_state()
	active_slot_id = ""
	pending_build_option_id = ""
	pending_build_title = ""
	pending_attribute_option_id = ""
	pending_attribute_title = ""
	pending_equipment_option_id = ""
	pending_equipment_title = ""
	pending_card_option_id = ""
	pending_card_title = ""
	if build_slot_menu != null and build_slot_menu.has_method("set_selected_options"):
		build_slot_menu.set_selected_options({})
	_update_focus_blur()

func _group_build_options(options: Array) -> Dictionary:
	var groups := {
		"body": [],
		"combat": [],
		"skill": []
	}

	for option in options:
		var slot_id := str(option.get("slot", ""))
		if not groups.has(slot_id):
			groups[slot_id] = []
		groups[slot_id].append(option)

	return groups

func _group_small_boss_reward_options(options: Array) -> Dictionary:
	var groups := {
		"equipment": [],
		"card": []
	}
	for raw_option in options:
		if not (raw_option is Dictionary):
			continue
		var option: Dictionary = raw_option.duplicate(true)
		if str(option.get("slot", "")) == "equipment":
			option["slot"] = "equipment"
			option["slot_label"] = "\u9053\u5177"
			groups["equipment"].append(option)
		else:
			option["slot"] = "card"
			option["slot_label"] = "\u5361\u724c"
			groups["card"].append(option)
	return groups

func _refresh_attribute_buttons() -> void:
	for index in range(attribute_buttons.size()):
		var button := attribute_buttons[index] as Button
		if index < current_attribute_options.size():
			var option: Dictionary = current_attribute_options[index]
			button.visible = true
			var prefix := "\u2713 " if str(option.get("id", "")) == pending_attribute_option_id else ""
			button.text = "%s%s\n%s" % [prefix, option.get("title", "\u5C5E\u6027"), option.get("description", "")]
			_apply_attribute_button_font_color(button, option, prefix != "")
			if prefix != "":
				button.modulate = Color(1.0, 0.92, 0.58, 1.0)
			else:
				button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			button.visible = false

func _apply_attribute_button_font_color(button: Button, option: Dictionary, selected: bool) -> void:
	var font_color := Color(1.0, 1.0, 1.0, 1.0)
	if bool(option.get("evolved", false)):
		font_color = option.get("title_color", Color(0.38, 1.0, 0.48, 1.0))
	elif selected:
		font_color = Color(1.0, 0.92, 0.58, 1.0)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color.lightened(0.12))
	button.add_theme_color_override("font_pressed_color", font_color.darkened(0.08))

func _refresh_selection_hint() -> void:
	if current_mode != "build":
		return
	var attribute_text := pending_attribute_title if pending_attribute_title != "" else "\u672A\u9009\u5C5E\u6027"
	var build_text := pending_build_title if pending_build_title != "" else "\u672A\u9009\u6784\u7B51"
	hint_label.text = "\u6BCF\u7EA7\u5148\u9009 1 \u4E2A\u5C5E\u6027\u52A0\u70B9\uff0C\u518D\u9009 1 \u4E2A Build\u3002\u77ED\u6309\u76F4\u63A5\u9009\u724C\uff0C\u957F\u6309\u6216\u957F\u60AC\u505C\u6253\u5F00\u4E09\u7EA7\u8BE6\u60C5\uff0C\u84DD\u8272\u672F\u8BED\u70B9\u51FB\u53EF\u770B\u56DB\u7EA7\u8BF4\u660E\u3002\n\u5F53\u524D\uff1A%s | %s" % [attribute_text, build_text]

func _select_attribute_option(option: Dictionary) -> void:
	pending_attribute_option_id = str(option.get("id", ""))
	pending_attribute_title = str(option.get("title", "\u5C5E\u6027"))
	_refresh_attribute_buttons()
	_refresh_selection_hint()
	_try_emit_combined_selection()

func _select_build_option(option: Dictionary) -> void:
	if current_mode == "small_boss_pair":
		_select_small_boss_reward_option(option)
		return
	pending_build_option_id = str(option.get("id", ""))
	pending_build_title = str(option.get("title", "Build"))
	_refresh_selection_hint()
	if build_slot_menu != null and build_slot_menu.has_method("set_selected_options"):
		build_slot_menu.set_selected_options({str(option.get("slot", "")): pending_build_option_id})
	_try_emit_combined_selection()

func _select_small_boss_reward_option(option: Dictionary) -> void:
	var slot_id := str(option.get("slot", ""))
	if slot_id == "equipment":
		pending_equipment_option_id = str(option.get("id", ""))
		pending_equipment_title = str(option.get("title", "\u9053\u5177"))
	elif slot_id == "card":
		pending_card_option_id = str(option.get("id", ""))
		pending_card_title = str(option.get("title", "\u5361\u724c"))
	_refresh_small_boss_reward_hint()
	if build_slot_menu != null and build_slot_menu.has_method("set_selected_options"):
		build_slot_menu.set_selected_options({
			"equipment": pending_equipment_option_id,
			"card": pending_card_option_id
		})
	if pending_equipment_option_id != "" and pending_card_option_id != "":
		upgrade_selected.emit(pending_equipment_option_id, pending_card_option_id)

func _refresh_small_boss_reward_hint() -> void:
	var equipment_text := pending_equipment_title if pending_equipment_title != "" else "\u672a\u9009"
	var card_text := pending_card_title if pending_card_title != "" else "\u672a\u9009"
	hint_label.text = "\u5c0f Boss \u5956\u52b1\u9700\u8981\u5404\u9009 1 \u4e2a\u3002\u9f20\u6807\u79fb\u5230\u9053\u5177 / \u5361\u724c\u4e0a\u5c55\u5f00\u9009\u9879\uff0c\u5df2\u9009\u5185\u5bb9\u4f1a\u53d8\u9ec4\u3002\n\u5f53\u524d\uff1a\u9053\u5177 %s | \u5361\u724c %s" % [equipment_text, card_text]

func _try_emit_combined_selection() -> void:
	if pending_build_option_id == "":
		return
	if not current_attribute_options.is_empty() and pending_attribute_option_id == "":
		return
	upgrade_selected.emit(pending_build_option_id, pending_attribute_option_id)

func _show_submenu(slot_id: String) -> void:
	if build_slot_menu == null:
		return
	if (build_groups.get(slot_id, []) as Array).is_empty():
		return

	if slot_id != active_slot_id:
		_hide_all_submenus()
		_hide_detail_panel()
		_hide_glossary_panel()
	active_slot_id = slot_id

	if build_slot_menu.show_submenu(slot_id):
		_update_focus_blur()

func _hide_all_submenus() -> void:
	if build_slot_menu != null and build_slot_menu.has_method("hide_all_submenus"):
		build_slot_menu.hide_all_submenus()

func _refresh_submenu_positions() -> void:
	if build_slot_menu != null and build_slot_menu.has_method("refresh_submenu_positions"):
		build_slot_menu.refresh_submenu_positions()

func _is_mouse_within_active_slot_bridge() -> bool:
	if build_slot_menu == null or active_slot_id == "":
		return false
	var extra_rects: Array = []
	if detail_overlay != null and detail_overlay.has_method("get_visible_rects"):
		for overlay_rect in detail_overlay.get_visible_rects():
			if overlay_rect is Rect2:
				extra_rects.append(overlay_rect)
	return build_slot_menu.is_mouse_within_active_slot_bridge(active_slot_id, extra_rects)

func _on_category_hovered(slot_id: String) -> void:
	if current_mode != "build" and current_mode != "small_boss_pair":
		return
	_show_submenu(slot_id)

func _on_direct_option_pressed(index: int) -> void:
	if index >= current_options.size():
		return

	var option: Dictionary = current_options[index]
	upgrade_selected.emit(option.get("id", ""), "")

func _on_attribute_option_pressed(index: int) -> void:
	if index >= current_attribute_options.size():
		return

	var option: Dictionary = current_attribute_options[index]
	_select_attribute_option(option)

func _on_submenu_option_button_down(slot_id: String, index: int) -> void:
	if current_mode != "build" and current_mode != "small_boss_pair":
		return
	hold_slot_id = slot_id
	hold_option_index = index
	hold_elapsed = 0.0
	hold_detail_shown = false

func _on_submenu_option_button_up(slot_id: String, index: int) -> void:
	if slot_id != hold_slot_id or index != hold_option_index:
		return
	var grouped_options: Array = build_groups.get(slot_id, [])
	var was_short_click := not hold_detail_shown and hold_elapsed < LONG_PRESS_TIME
	_cancel_hold_state()
	if was_short_click and index < grouped_options.size():
		_select_build_option(grouped_options[index])

func _show_detail_panel(slot_id: String, index: int) -> void:
	var grouped_options: Array = build_groups.get(slot_id, [])
	if index >= grouped_options.size():
		_cancel_hold_state()
		return

	var option: Dictionary = grouped_options[index]
	if build_slot_menu == null or not build_slot_menu.has_method("get_option_button"):
		return
	var button: Button = build_slot_menu.get_option_button(slot_id, index)
	if button == null:
		return
	if detail_overlay != null and detail_overlay.has_method("show_detail"):
		detail_overlay.show_detail(slot_id, option, button)
	_update_focus_blur()

func _hide_detail_panel() -> void:
	if detail_overlay != null and detail_overlay.has_method("hide_detail"):
		detail_overlay.hide_detail()
	_cancel_hover_state()
	_update_focus_blur()

func _cancel_hold_state() -> void:
	hold_slot_id = ""
	hold_option_index = -1
	hold_elapsed = 0.0
	hold_detail_shown = false

func _cancel_hover_state() -> void:
	hover_slot_id = ""
	hover_option_index = -1
	hover_elapsed = 0.0
	hover_detail_shown = false

func _hide_final_progress_panel() -> void:
	if detail_overlay != null and detail_overlay.has_method("hide_final_progress"):
		detail_overlay.hide_final_progress()
	_update_focus_blur()

func _hide_glossary_panel() -> void:
	if detail_overlay != null and detail_overlay.has_method("hide_glossary"):
		detail_overlay.hide_glossary()
	_update_focus_blur()

func _update_focus_blur() -> void:
	if detail_overlay == null:
		return
	var overlay_visible := false
	if detail_overlay.has_method("has_visible_overlay"):
		overlay_visible = detail_overlay.has_visible_overlay()
	var should_show: bool = visible and (current_mode == "build" or current_mode == "small_boss_pair") and overlay_visible
	if detail_overlay.has_method("set_focus_visible"):
		detail_overlay.set_focus_visible(should_show)

func _on_focus_blur_pressed() -> void:
	_hide_all_submenus()
	_hide_detail_panel()
	_hide_final_progress_panel()
	_hide_glossary_panel()
	active_slot_id = ""
	_update_focus_blur()

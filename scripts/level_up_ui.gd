extends CanvasLayer

signal upgrade_selected(option_id: String, attribute_option_id: String)

const SLOT_ORDER := ["body", "combat", "skill"]
const LONG_PRESS_TIME := 0.28
const HOVER_DETAIL_TIME := 0.38
const SLOT_LABELS := {
	"body": "\u6218\u6597",
	"combat": "\u8FDE\u643A",
	"skill": "\u5927\u62DB"
}

var root: Control
var dimmer: ColorRect
var panel: PanelContainer
var title_label: Label
var hint_label: Label
var attribute_row: HBoxContainer
var attribute_buttons: Array[Button] = []
var direct_button_container: VBoxContainer
var direct_buttons: Array[Button] = []
var category_row: HBoxContainer
var category_buttons: Dictionary = {}
var submenu_panels: Dictionary = {}
var submenu_scrolls: Dictionary = {}
var submenu_boxes: Dictionary = {}
var submenu_buttons: Dictionary = {}
var focus_blur: ColorRect
var detail_panel: PanelContainer
var detail_title_label: Label
var detail_final_card_button: Button
var detail_desc_label: RichTextLabel
var final_progress_panel: PanelContainer
var final_progress_title_label: Label
var final_progress_list: VBoxContainer
var glossary_panel: PanelContainer
var glossary_title_label: Label
var glossary_desc_label: RichTextLabel
var current_options: Array = []
var current_attribute_options: Array = []
var build_groups: Dictionary = {}
var current_mode: String = "direct"
var active_slot_id: String = ""
var pending_build_option_id: String = ""
var pending_build_title: String = ""
var pending_attribute_option_id: String = ""
var pending_attribute_title: String = ""
var hold_slot_id: String = ""
var hold_option_index: int = -1
var hold_elapsed: float = 0.0
var hold_detail_shown: bool = false
var hover_slot_id: String = ""
var hover_option_index: int = -1
var hover_elapsed: float = 0.0
var hover_detail_shown: bool = false
var detail_slot_id: String = ""
var detail_option_id: String = ""
var detail_option_title: String = ""
var detail_glossary_terms: Dictionary = {}
var detail_final_card_data: Dictionary = {}

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

	focus_blur = ColorRect.new()
	focus_blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	focus_blur.visible = false
	focus_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_blur.material = _create_focus_blur_material()
	root.add_child(focus_blur)

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

	for index in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(720, 92)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 18)
		button.text = "\u9009\u9879 %d" % (index + 1)
		button.pressed.connect(_on_direct_option_pressed.bind(index))
		direct_button_container.add_child(button)
		direct_buttons.append(button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	category_row = HBoxContainer.new()
	category_row.alignment = BoxContainer.ALIGNMENT_CENTER
	category_row.add_theme_constant_override("separation", 18)
	content.add_child(category_row)

	for slot_id in SLOT_ORDER:
		var button := Button.new()
		button.custom_minimum_size = Vector2(230, 84)
		button.text = str(SLOT_LABELS[slot_id])
		button.add_theme_font_size_override("font_size", 24)
		button.set_meta("slot_id", slot_id)
		button.mouse_entered.connect(_on_category_hovered.bind(slot_id))
		category_row.add_child(button)
		category_buttons[slot_id] = button

		var submenu_panel := PanelContainer.new()
		submenu_panel.visible = false
		submenu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		submenu_panel.set_meta("slot_id", slot_id)
		root.add_child(submenu_panel)
		submenu_panels[slot_id] = submenu_panel

		var submenu_scroll := ScrollContainer.new()
		submenu_scroll.custom_minimum_size = Vector2(320, 260)
		submenu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		submenu_panel.add_child(submenu_scroll)
		submenu_scrolls[slot_id] = submenu_scroll

		var submenu_box := VBoxContainer.new()
		submenu_box.custom_minimum_size = Vector2(300, 0)
		submenu_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		submenu_box.add_theme_constant_override("separation", 10)
		submenu_scroll.add_child(submenu_box)
		submenu_boxes[slot_id] = submenu_box

		var buttons: Array[Button] = []
		submenu_buttons[slot_id] = buttons

	detail_panel = PanelContainer.new()
	detail_panel.visible = false
	detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(detail_panel)

	var detail_box := VBoxContainer.new()
	detail_box.custom_minimum_size = Vector2(320, 0)
	detail_box.add_theme_constant_override("separation", 10)
	detail_panel.add_child(detail_box)

	var detail_header := HBoxContainer.new()
	detail_header.add_theme_constant_override("separation", 12)
	detail_box.add_child(detail_header)

	detail_title_label = Label.new()
	detail_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_title_label.add_theme_font_size_override("font_size", 20)
	detail_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_header.add_child(detail_title_label)

	detail_final_card_button = Button.new()
	detail_final_card_button.flat = true
	detail_final_card_button.visible = false
	detail_final_card_button.text = ""
	detail_final_card_button.add_theme_font_size_override("font_size", 16)
	detail_final_card_button.modulate = Color(0.98, 0.88, 0.48, 1.0)
	detail_final_card_button.mouse_entered.connect(_on_detail_final_card_hovered)
	detail_final_card_button.focus_exited.connect(_hide_final_progress_panel)
	detail_final_card_button.pressed.connect(_show_final_progress_panel)
	detail_header.add_child(detail_final_card_button)

	detail_desc_label = RichTextLabel.new()
	detail_desc_label.bbcode_enabled = true
	detail_desc_label.fit_content = true
	detail_desc_label.scroll_active = false
	detail_desc_label.custom_minimum_size = Vector2(360, 140)
	detail_desc_label.add_theme_font_size_override("normal_font_size", 16)
	detail_desc_label.meta_clicked.connect(_on_detail_meta_clicked)
	detail_box.add_child(detail_desc_label)

	final_progress_panel = PanelContainer.new()
	final_progress_panel.visible = false
	final_progress_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(final_progress_panel)

	var progress_box := VBoxContainer.new()
	progress_box.custom_minimum_size = Vector2(280, 0)
	progress_box.add_theme_constant_override("separation", 8)
	final_progress_panel.add_child(progress_box)

	final_progress_title_label = Label.new()
	final_progress_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	final_progress_title_label.add_theme_font_size_override("font_size", 18)
	progress_box.add_child(final_progress_title_label)

	final_progress_list = VBoxContainer.new()
	final_progress_list.add_theme_constant_override("separation", 6)
	progress_box.add_child(final_progress_list)

	glossary_panel = PanelContainer.new()
	glossary_panel.visible = false
	glossary_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(glossary_panel)

	var glossary_box := VBoxContainer.new()
	glossary_box.custom_minimum_size = Vector2(320, 0)
	glossary_box.add_theme_constant_override("separation", 10)
	glossary_panel.add_child(glossary_box)

	glossary_title_label = Label.new()
	glossary_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	glossary_title_label.add_theme_font_size_override("font_size", 20)
	glossary_box.add_child(glossary_title_label)

	glossary_desc_label = RichTextLabel.new()
	glossary_desc_label.bbcode_enabled = true
	glossary_desc_label.fit_content = true
	glossary_desc_label.scroll_active = false
	glossary_desc_label.custom_minimum_size = Vector2(320, 120)
	glossary_desc_label.add_theme_font_size_override("normal_font_size", 16)
	glossary_box.add_child(glossary_desc_label)

	hide_ui()

func _process(delta: float) -> void:
	if not visible or current_mode != "build":
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
	var hover_option := _resolve_hover_option(hovered)
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

	var slot_id := _resolve_hover_slot(hovered)
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
	title_label.text = "\u5347\u7EA7\u9009\u62E9"
	hint_label.visible = true
	direct_button_container.visible = false
	attribute_row.visible = not current_attribute_options.is_empty()
	category_row.visible = true
	_refresh_attribute_buttons()
	_refresh_selection_hint()

	for slot_id in SLOT_ORDER:
		var button := category_buttons[slot_id] as Button
		var grouped_options: Array = build_groups.get(slot_id, [])
		button.visible = not grouped_options.is_empty()
		if not grouped_options.is_empty():
			button.text = str(grouped_options[0].get("slot_label", SLOT_LABELS[slot_id]))
		else:
			button.text = str(SLOT_LABELS[slot_id])
		_update_submenu(slot_id, grouped_options)

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
	category_row.visible = false
	_hide_all_submenus()
	_hide_detail_panel()
	_hide_final_progress_panel()
	_hide_glossary_panel()
	active_slot_id = ""
	pending_build_option_id = ""
	pending_build_title = ""
	pending_attribute_option_id = ""
	pending_attribute_title = ""
	_update_focus_blur()

	for index in range(direct_buttons.size()):
		var button := direct_buttons[index]
		if index < current_options.size():
			var option: Dictionary = current_options[index]
			button.visible = true
			button.text = "%s\n%s" % [option.get("title", "\u5347\u7EA7"), option.get("description", "")]
		else:
			button.visible = false

	visible = true

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

func _update_submenu(slot_id: String, options: Array) -> void:
	_ensure_submenu_button_count(slot_id, options.size())
	if submenu_scrolls.has(slot_id):
		var submenu_scroll := submenu_scrolls.get(slot_id) as ScrollContainer
		var visible_button_count: int = max(1, min(options.size(), 4))
		submenu_scroll.custom_minimum_size = Vector2(320, 14.0 + visible_button_count * 98.0)
	var buttons: Array = submenu_buttons.get(slot_id, [])
	for index in range(buttons.size()):
		var button := buttons[index] as Button
		if index < options.size():
			var option: Dictionary = options[index]
			button.visible = true
			var preview_text := str(option.get("preview_description", ""))
			if preview_text == "":
				preview_text = str(option.get("description", ""))
			button.text = "%s\n%s" % [option.get("title", "\u5347\u7EA7"), preview_text]
		else:
			button.visible = false

func _ensure_submenu_button_count(slot_id: String, count: int) -> void:
	if not submenu_buttons.has(slot_id) or not submenu_boxes.has(slot_id):
		return
	var buttons: Array = submenu_buttons.get(slot_id, [])
	var submenu_box := submenu_boxes.get(slot_id) as VBoxContainer
	while buttons.size() < count:
		var option_index := buttons.size()
		var option_button := Button.new()
		option_button.custom_minimum_size = Vector2(270, 88)
		option_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option_button.add_theme_font_size_override("font_size", 16)
		option_button.visible = false
		option_button.set_meta("slot_id", slot_id)
		option_button.set_meta("option_index", option_index)
		option_button.button_down.connect(_on_submenu_option_button_down.bind(slot_id, option_index))
		option_button.button_up.connect(_on_submenu_option_button_up.bind(slot_id, option_index))
		submenu_box.add_child(option_button)
		buttons.append(option_button)
	submenu_buttons[slot_id] = buttons

func _refresh_attribute_buttons() -> void:
	for index in range(attribute_buttons.size()):
		var button := attribute_buttons[index] as Button
		if index < current_attribute_options.size():
			var option: Dictionary = current_attribute_options[index]
			button.visible = true
			var prefix := "\u2713 " if str(option.get("id", "")) == pending_attribute_option_id else ""
			button.text = "%s%s\n%s" % [prefix, option.get("title", "\u5C5E\u6027"), option.get("description", "")]
			if prefix != "":
				button.modulate = Color(1.0, 0.92, 0.58, 1.0)
			else:
				button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			button.visible = false

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
	pending_build_option_id = str(option.get("id", ""))
	pending_build_title = str(option.get("title", "Build"))
	_refresh_selection_hint()
	_try_emit_combined_selection()

func _try_emit_combined_selection() -> void:
	if pending_build_option_id == "":
		return
	if not current_attribute_options.is_empty() and pending_attribute_option_id == "":
		return
	upgrade_selected.emit(pending_build_option_id, pending_attribute_option_id)

func _show_submenu(slot_id: String) -> void:
	if not submenu_panels.has(slot_id):
		return
	if (build_groups.get(slot_id, []) as Array).is_empty():
		return

	if slot_id != active_slot_id:
		_hide_all_submenus()
		_hide_detail_panel()
		_hide_glossary_panel()
	active_slot_id = slot_id

	var submenu_panel := submenu_panels[slot_id] as PanelContainer
	submenu_panel.visible = true
	_position_submenu(slot_id)
	_update_focus_blur()

func _hide_all_submenus() -> void:
	for submenu_panel in submenu_panels.values():
		(submenu_panel as PanelContainer).visible = false

func _refresh_submenu_positions() -> void:
	for slot_id in SLOT_ORDER:
		if (submenu_panels[slot_id] as PanelContainer).visible:
			_position_submenu(slot_id)

func _position_submenu(slot_id: String) -> void:
	var button := category_buttons[slot_id] as Button
	var submenu_panel := submenu_panels[slot_id] as PanelContainer
	if button == null or submenu_panel == null or not button.visible:
		return

	submenu_panel.size = submenu_panel.get_combined_minimum_size()
	var button_rect := button.get_global_rect()
	var viewport_rect := get_viewport().get_visible_rect()
	var target_x := button_rect.position.x + button_rect.size.x * 0.5 - submenu_panel.size.x * 0.5
	var target_y := button_rect.position.y - submenu_panel.size.y + 8.0
	submenu_panel.size.y = min(submenu_panel.size.y, viewport_rect.size.y - 48.0)
	submenu_panel.size.x = max(submenu_panel.size.x, 340.0)
	target_x = clamp(target_x, viewport_rect.position.x + 12.0, viewport_rect.end.x - submenu_panel.size.x - 12.0)
	target_y = max(viewport_rect.position.y + 12.0, target_y)
	submenu_panel.global_position = Vector2(target_x, target_y)

func _is_mouse_within_active_slot_bridge() -> bool:
	if active_slot_id == "":
		return false
	if not category_buttons.has(active_slot_id) or not submenu_panels.has(active_slot_id):
		return false

	var button := category_buttons[active_slot_id] as Button
	var submenu_panel := submenu_panels[active_slot_id] as PanelContainer
	if button == null or submenu_panel == null or not submenu_panel.visible:
		return false

	var mouse_position := get_viewport().get_mouse_position()
	var button_rect := button.get_global_rect()
	var submenu_rect := submenu_panel.get_global_rect()
	var min_x: float = min(button_rect.position.x, submenu_rect.position.x) - 8.0
	var min_y: float = min(button_rect.position.y, submenu_rect.position.y) - 8.0
	var max_x: float = max(button_rect.end.x, submenu_rect.end.x) + 8.0
	var max_y: float = max(button_rect.end.y, submenu_rect.end.y) + 8.0
	if detail_panel != null and detail_panel.visible:
		var detail_rect := detail_panel.get_global_rect()
		min_x = min(min_x, detail_rect.position.x - 8.0)
		min_y = min(min_y, detail_rect.position.y - 8.0)
		max_x = max(max_x, detail_rect.end.x + 8.0)
		max_y = max(max_y, detail_rect.end.y + 8.0)
	if glossary_panel != null and glossary_panel.visible:
		var glossary_rect := glossary_panel.get_global_rect()
		min_x = min(min_x, glossary_rect.position.x - 8.0)
		min_y = min(min_y, glossary_rect.position.y - 8.0)
		max_x = max(max_x, glossary_rect.end.x + 8.0)
		max_y = max(max_y, glossary_rect.end.y + 8.0)
	if final_progress_panel != null and final_progress_panel.visible:
		var progress_rect := final_progress_panel.get_global_rect()
		min_x = min(min_x, progress_rect.position.x - 8.0)
		min_y = min(min_y, progress_rect.position.y - 8.0)
		max_x = max(max_x, progress_rect.end.x + 8.0)
		max_y = max(max_y, progress_rect.end.y + 8.0)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y)).has_point(mouse_position)

func _resolve_hover_slot(control: Control) -> String:
	var current: Node = control
	while current != null:
		if current is Control and (current as Control).has_meta("slot_id"):
			return str((current as Control).get_meta("slot_id"))
		current = current.get_parent()
	return ""

func _resolve_hover_option(control: Control) -> Dictionary:
	var current: Node = control
	while current != null:
		if current is Control and (current as Control).has_meta("slot_id") and (current as Control).has_meta("option_index"):
			return {
				"slot_id": str((current as Control).get_meta("slot_id")),
				"option_index": int((current as Control).get_meta("option_index"))
			}
		current = current.get_parent()
	return {}

func _on_category_hovered(slot_id: String) -> void:
	if current_mode != "build":
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
	if current_mode != "build":
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
	detail_slot_id = slot_id
	detail_option_id = str(option.get("id", ""))
	detail_option_title = str(option.get("title", "Build"))
	detail_glossary_terms.clear()
	detail_final_card_data = {
		"name": str(option.get("final_card_name", "")),
		"title": str(option.get("final_card_title", "")),
		"requirements": option.get("final_card_requirements", [])
	}
	for entry in option.get("glossary_terms", []):
		if entry is Dictionary:
			detail_glossary_terms[str(entry.get("term", ""))] = entry
	detail_title_label.text = detail_option_title
	detail_final_card_button.text = str(detail_final_card_data.get("name", ""))
	detail_final_card_button.visible = detail_final_card_button.text != ""
	detail_final_card_button.set_meta("slot_id", slot_id)
	detail_desc_label.text = _decorate_glossary_terms(str(option.get("detail_description", option.get("description", ""))))
	detail_panel.visible = true
	detail_panel.set_meta("slot_id", slot_id)
	_hide_final_progress_panel()
	_hide_glossary_panel()
	_update_focus_blur()
	call_deferred("_position_detail_panel", slot_id, index)

func _position_detail_panel(slot_id: String, index: int) -> void:
	var buttons: Array = submenu_buttons.get(slot_id, [])
	if index >= buttons.size():
		return
	var button := buttons[index] as Button
	if button == null or not button.visible:
		return

	detail_panel.size = detail_panel.get_combined_minimum_size()
	var button_rect := button.get_global_rect()
	var viewport_rect := get_viewport().get_visible_rect()
	var target_x := button_rect.position.x + button_rect.size.x + 14.0
	var target_y := button_rect.position.y + button_rect.size.y * 0.5 - detail_panel.size.y * 0.5
	if target_x + detail_panel.size.x > viewport_rect.end.x - 12.0:
		target_x = button_rect.position.x - detail_panel.size.x - 14.0
	target_x = clamp(target_x, viewport_rect.position.x + 12.0, viewport_rect.end.x - detail_panel.size.x - 12.0)
	target_y = clamp(target_y, viewport_rect.position.y + 12.0, viewport_rect.end.y - detail_panel.size.y - 12.0)
	detail_panel.global_position = Vector2(target_x, target_y)

func _hide_detail_panel() -> void:
	if detail_panel != null:
		detail_panel.visible = false
	detail_slot_id = ""
	detail_option_id = ""
	detail_option_title = ""
	detail_glossary_terms.clear()
	detail_final_card_data.clear()
	if detail_final_card_button != null:
		detail_final_card_button.visible = false
		detail_final_card_button.text = ""
	_hide_final_progress_panel()
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

func _decorate_glossary_terms(text: String) -> String:
	var decorated := text
	for term in detail_glossary_terms.keys():
		var term_text := str(term)
		if term_text == "":
			continue
		var tag := "[url=term:%s][u][color=#6DB3FF]%s[/color][/u][/url]" % [term_text, term_text]
		decorated = decorated.replace(term_text, tag)
	return decorated

func _on_detail_meta_clicked(meta: Variant) -> void:
	var meta_text := str(meta)
	if not meta_text.begins_with("term:"):
		return
	var term := meta_text.trim_prefix("term:")
	_show_glossary_panel(term)

func _show_glossary_panel(term: String) -> void:
	if not detail_glossary_terms.has(term):
		return
	var entry: Dictionary = detail_glossary_terms.get(term, {})
	glossary_title_label.text = str(entry.get("title", term))
	glossary_desc_label.text = "%s\n\n[color=#A9C8FF]每层效果[/color]\n%s" % [
		str(entry.get("description", "")),
		str(entry.get("per_level", ""))
	]
	glossary_panel.set_meta("slot_id", detail_slot_id)
	glossary_panel.visible = true
	_update_focus_blur()
	call_deferred("_position_glossary_panel")

func _on_detail_final_card_hovered() -> void:
	_show_final_progress_panel()

func _show_final_progress_panel() -> void:
	if detail_final_card_data.is_empty():
		return
	final_progress_title_label.text = str(detail_final_card_data.get("title", ""))
	for child in final_progress_list.get_children():
		child.queue_free()
	for requirement in detail_final_card_data.get("requirements", []):
		if requirement is not Dictionary:
			continue
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.custom_minimum_size = Vector2(250, 0)
		label.add_theme_font_size_override("normal_font_size", 16)
		var current_level := int(requirement.get("current_level", 0))
		var max_level := int(requirement.get("max_level", 0))
		var level_parts: Array[String] = []
		for level in range(1, max_level + 1):
			var text := "LV%d" % level
			if level <= current_level:
				text = "[color=#FFE08A]%s[/color]" % text
			else:
				text = "[color=#6E7380]%s[/color]" % text
			level_parts.append(text)
		label.text = "%s %s" % [str(requirement.get("label", "")), " / ".join(level_parts)]
		final_progress_list.add_child(label)
	final_progress_panel.visible = true
	final_progress_panel.set_meta("slot_id", detail_slot_id)
	_update_focus_blur()
	call_deferred("_position_final_progress_panel")

func _position_final_progress_panel() -> void:
	if final_progress_panel == null or not final_progress_panel.visible or detail_panel == null or not detail_panel.visible:
		return
	final_progress_panel.size = final_progress_panel.get_combined_minimum_size()
	var detail_rect := detail_panel.get_global_rect()
	var viewport_rect := get_viewport().get_visible_rect()
	var target_x := detail_rect.end.x + 14.0
	var target_y := detail_rect.position.y
	if glossary_panel != null and glossary_panel.visible:
		target_y = glossary_panel.get_global_rect().end.y + 12.0
	if target_x + final_progress_panel.size.x > viewport_rect.end.x - 12.0:
		target_x = detail_rect.position.x - final_progress_panel.size.x - 14.0
	target_x = clamp(target_x, viewport_rect.position.x + 12.0, viewport_rect.end.x - final_progress_panel.size.x - 12.0)
	target_y = clamp(target_y, viewport_rect.position.y + 12.0, viewport_rect.end.y - final_progress_panel.size.y - 12.0)
	final_progress_panel.global_position = Vector2(target_x, target_y)

func _hide_final_progress_panel() -> void:
	if final_progress_panel != null:
		final_progress_panel.visible = false
	_update_focus_blur()

func _position_glossary_panel() -> void:
	if glossary_panel == null or not glossary_panel.visible or detail_panel == null or not detail_panel.visible:
		return
	glossary_panel.size = glossary_panel.get_combined_minimum_size()
	var detail_rect := detail_panel.get_global_rect()
	var viewport_rect := get_viewport().get_visible_rect()
	var target_x := detail_rect.end.x + 14.0
	var target_y := detail_rect.position.y
	if target_x + glossary_panel.size.x > viewport_rect.end.x - 12.0:
		target_x = detail_rect.position.x - glossary_panel.size.x - 14.0
	target_x = clamp(target_x, viewport_rect.position.x + 12.0, viewport_rect.end.x - glossary_panel.size.x - 12.0)
	target_y = clamp(target_y, viewport_rect.position.y + 12.0, viewport_rect.end.y - glossary_panel.size.y - 12.0)
	glossary_panel.global_position = Vector2(target_x, target_y)

func _hide_glossary_panel() -> void:
	if glossary_panel != null:
		glossary_panel.visible = false
	_update_focus_blur()

func _create_focus_blur_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_scale = 1.8;

void fragment() {
	vec2 pixel_size = 1.0 / vec2(textureSize(screen_texture, 0));
	vec3 accum = vec3(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 dir = vec2(float(x), float(y));
			float weight = 1.0 / (1.0 + length(dir));
			accum += texture(screen_texture, SCREEN_UV + dir * pixel_size * blur_scale * 2.0).rgb * weight;
			total += weight;
		}
	}
	vec3 blurred = accum / max(total, 0.001);
	vec3 tinted = mix(blurred, vec3(0.05, 0.07, 0.10), 0.22);
	COLOR = vec4(tinted, 0.94);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _update_focus_blur() -> void:
	if focus_blur == null:
		return
	var should_show: bool = visible and current_mode == "build" and (active_slot_id != "" or detail_panel.visible or glossary_panel.visible or final_progress_panel.visible)
	focus_blur.visible = should_show

func _on_focus_blur_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	_hide_all_submenus()
	_hide_detail_panel()
	_hide_final_progress_panel()
	_hide_glossary_panel()
	active_slot_id = ""
	_update_focus_blur()

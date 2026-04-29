extends HBoxContainer

signal category_hovered(slot_id: String)
signal option_button_down(slot_id: String, option_index: int)
signal option_button_up(slot_id: String, option_index: int)

const DEFAULT_SLOT_ORDER := ["body", "combat", "skill"]
const SLOT_LABELS := {
	"body": "战斗",
	"combat": "连携",
	"skill": "大招"
}

var overlay_root: Control
var category_buttons: Dictionary = {}
var submenu_panels: Dictionary = {}
var submenu_scrolls: Dictionary = {}
var submenu_boxes: Dictionary = {}
var submenu_buttons: Dictionary = {}
var build_groups: Dictionary = {}
var slot_order: Array = DEFAULT_SLOT_ORDER.duplicate()
var slot_labels: Dictionary = SLOT_LABELS.duplicate()
var selected_option_ids: Dictionary = {}

func setup(menu_overlay_root: Control) -> void:
	overlay_root = menu_overlay_root
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 18)
	_build_category_buttons()
	_build_submenus()

func set_groups(new_groups: Dictionary, new_slot_order: Array = [], new_slot_labels: Dictionary = {}) -> void:
	build_groups = new_groups
	slot_order = new_slot_order.duplicate() if not new_slot_order.is_empty() else DEFAULT_SLOT_ORDER.duplicate()
	slot_labels = SLOT_LABELS.duplicate()
	for label_key in new_slot_labels.keys():
		slot_labels[str(label_key)] = str(new_slot_labels[label_key])
	for existing_button in category_buttons.values():
		(existing_button as Button).visible = false
	for slot_id_value in slot_order:
		var slot_id := str(slot_id_value)
		_ensure_slot(slot_id)
		var button := category_buttons[slot_id] as Button
		var grouped_options: Array = build_groups.get(slot_id, [])
		button.visible = not grouped_options.is_empty()
		if not grouped_options.is_empty():
			button.text = str(grouped_options[0].get("slot_label", slot_labels.get(slot_id, slot_id)))
		else:
			button.text = str(slot_labels.get(slot_id, slot_id))
		button.modulate = Color(1.0, 0.92, 0.58, 1.0) if str(selected_option_ids.get(slot_id, "")) != "" else Color.WHITE
		_update_submenu(slot_id, grouped_options)

func set_selected_options(new_selected_option_ids: Dictionary) -> void:
	selected_option_ids = new_selected_option_ids.duplicate(true)
	set_groups(build_groups, slot_order, slot_labels)

func show_submenu(slot_id: String) -> bool:
	if not submenu_panels.has(slot_id):
		return false
	if (build_groups.get(slot_id, []) as Array).is_empty():
		return false
	var submenu_panel := submenu_panels[slot_id] as PanelContainer
	submenu_panel.visible = true
	_position_submenu(slot_id)
	return true

func hide_all_submenus() -> void:
	for submenu_panel in submenu_panels.values():
		(submenu_panel as PanelContainer).visible = false

func refresh_submenu_positions() -> void:
	for slot_id_value in slot_order:
		var slot_id := str(slot_id_value)
		if (submenu_panels[slot_id] as PanelContainer).visible:
			_position_submenu(slot_id)

func resolve_hover_slot(control: Control) -> String:
	var current: Node = control
	while current != null:
		if current is Control and (current as Control).has_meta("slot_id"):
			return str((current as Control).get_meta("slot_id"))
		current = current.get_parent()
	return ""

func resolve_hover_option(control: Control) -> Dictionary:
	var current: Node = control
	while current != null:
		if current is Control and (current as Control).has_meta("slot_id") and (current as Control).has_meta("option_index"):
			return {
				"slot_id": str((current as Control).get_meta("slot_id")),
				"option_index": int((current as Control).get_meta("option_index"))
			}
		current = current.get_parent()
	return {}

func is_mouse_within_active_slot_bridge(active_slot_id: String, extra_rects: Array = []) -> bool:
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
	for extra_rect in extra_rects:
		if extra_rect is Rect2:
			min_x = min(min_x, extra_rect.position.x - 8.0)
			min_y = min(min_y, extra_rect.position.y - 8.0)
			max_x = max(max_x, extra_rect.end.x + 8.0)
			max_y = max(max_y, extra_rect.end.y + 8.0)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y)).has_point(mouse_position)

func get_option_button(slot_id: String, option_index: int) -> Button:
	var buttons: Array = submenu_buttons.get(slot_id, [])
	if option_index < 0 or option_index >= buttons.size():
		return null
	return buttons[option_index] as Button

func _build_category_buttons() -> void:
	for slot_id_value in DEFAULT_SLOT_ORDER:
		_ensure_category_button(str(slot_id_value))

func _build_submenus() -> void:
	if overlay_root == null:
		return
	for slot_id_value in DEFAULT_SLOT_ORDER:
		_ensure_submenu(str(slot_id_value))

func _ensure_slot(slot_id: String) -> void:
	_ensure_category_button(slot_id)
	_ensure_submenu(slot_id)

func _ensure_category_button(slot_id: String) -> void:
	if category_buttons.has(slot_id):
		return
	var button := Button.new()
	button.custom_minimum_size = Vector2(230, 84)
	button.text = str(slot_labels.get(slot_id, slot_id))
	button.add_theme_font_size_override("font_size", 24)
	button.set_meta("slot_id", slot_id)
	button.mouse_entered.connect(func(): category_hovered.emit(slot_id))
	add_child(button)
	category_buttons[slot_id] = button

func _ensure_submenu(slot_id: String) -> void:
	if overlay_root == null or submenu_panels.has(slot_id):
		return
	var submenu_panel := PanelContainer.new()
	submenu_panel.visible = false
	submenu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	submenu_panel.set_meta("slot_id", slot_id)
	overlay_root.add_child(submenu_panel)
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
	submenu_buttons[slot_id] = []

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
			var option_id := str(option.get("id", ""))
			var selected := option_id != "" and option_id == str(selected_option_ids.get(slot_id, ""))
			button.visible = true
			var preview_text := str(option.get("preview_description", ""))
			if preview_text == "":
				preview_text = str(option.get("description", ""))
			_apply_option_button_style(button, selected)
			button.text = "%s\n%s" % [option.get("title", "升级"), preview_text]
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
		option_button.button_down.connect(func(): option_button_down.emit(slot_id, option_index))
		option_button.button_up.connect(func(): option_button_up.emit(slot_id, option_index))
		submenu_box.add_child(option_button)
		buttons.append(option_button)
	submenu_buttons[slot_id] = buttons

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

func _apply_option_button_style(button: Button, selected: bool) -> void:
	var font_color := Color(1.0, 0.92, 0.58, 1.0) if selected else Color.WHITE
	button.modulate = Color(1.0, 0.92, 0.58, 1.0) if selected else Color.WHITE
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color.lightened(0.12))
	button.add_theme_color_override("font_pressed_color", font_color.darkened(0.08))

extends Control

signal closed
signal profile_changed

const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const ITEMS := preload("res://scripts/player/ruan_stone_system.gd")
const SERVICE := preload("res://scripts/camp/camp_shop_service.gd")
const MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const UI := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const STONES := ["thunder", "frost", "poison", "flame", "fury"]
const FILTERS := {"all": "全部", "stones": "阮石", "equipment": "装备", "owned": "已携带"}
var modal: Control
var status_label: Label
var carried_label: Label
var item_list: ItemList
var inventory_grid: GridContainer
var grid_buttons: Dictionary = {}
var detail_scroll: ScrollContainer
var detail_title: Label
var detail_type: Label
var item_placeholder: Label
var description_label: Label
var current_label: Label
var next_label: Label
var feedback_label: Label
var buy_button: Button
var refund_button: Button
var carried_slots: HBoxContainer
var filter_buttons: Dictionary = {}
var profile: Dictionary = {}
var filtered_ids: Array[String] = []
var selected_id := ""
var current_filter := "all"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	modal = MODAL.new()
	add_child(modal)
	modal.configure(Vector2(1420, 850), 0.96, 0.92, Vector2(720, 480))
	modal.set_title("阮狗 · 营地商店")
	modal.set_hint("")
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	modal.set_body(body)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 22)
	body.add_child(columns)
	var catalog := VBoxContainer.new()
	catalog.custom_minimum_size.x = 650
	catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog.add_theme_constant_override("separation", 10)
	columns.add_child(catalog)
	var catalog_header := PanelContainer.new()
	catalog_header.custom_minimum_size.y = 52
	catalog_header.add_theme_stylebox_override("panel", UI.panel_style(UI.COLOR_BG_SOFT, UI.COLOR_BORDER_GOLD, 2, 5, 10))
	catalog.add_child(catalog_header)
	var catalog_title := _label("商品", 22, UI.COLOR_TEXT_GOLD)
	catalog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catalog_header.add_child(catalog_title)
	catalog.add_child(filters)
	for key in FILTERS:
		var button := Button.new()
		button.text = FILTERS[key]
		button.custom_minimum_size = Vector2(90, 36)
		button.pressed.connect(_set_filter.bind(str(key)))
		filters.add_child(button)
		filter_buttons[key] = button
	var grid_scroll := ScrollContainer.new()
	grid_scroll.name = "InventoryScroll"
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	catalog.add_child(grid_scroll)
	inventory_grid = GridContainer.new()
	inventory_grid.name = "InventoryGrid"
	inventory_grid.columns = 3
	inventory_grid.custom_minimum_size = Vector2(620, 0)
	inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_grid.add_theme_constant_override("h_separation", 8)
	inventory_grid.add_theme_constant_override("v_separation", 8)
	grid_scroll.add_child(inventory_grid)
	item_list = ItemList.new()
	item_list.name = "InventoryCompatibilityList"
	item_list.visible = false
	item_list.custom_minimum_size.x = 280
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.add_theme_font_size_override("font_size", 17)
	item_list.add_theme_constant_override("v_separation", 12)
	item_list.add_theme_color_override("font_color", UI.COLOR_TEXT)
	item_list.add_theme_color_override("font_selected_color", UI.COLOR_TEXT_GOLD)
	item_list.add_theme_stylebox_override("panel", UI.panel_style(UI.COLOR_BG_SOFT, UI.COLOR_BORDER, 1, 6, 8))
	item_list.add_theme_stylebox_override("selected", UI.card_style(true))
	item_list.add_theme_stylebox_override("selected_focus", UI.card_style(true))
	item_list.add_theme_stylebox_override("focus", UI.panel_style(Color.TRANSPARENT, UI.COLOR_TEXT_GOLD, 2, 6))
	item_list.item_selected.connect(_select_index)
	columns.add_child(item_list)
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size.x = 430
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", UI.panel_style(UI.COLOR_BG_SOFT, UI.COLOR_BORDER_GOLD, 2, 6, 16))
	columns.add_child(detail_panel)
	detail_scroll = ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(detail_scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 12)
	detail_scroll.add_child(details)
	var product_head := HBoxContainer.new()
	product_head.add_theme_constant_override("separation", 14)
	details.add_child(product_head)
	var placeholder_panel := PanelContainer.new()
	placeholder_panel.custom_minimum_size = Vector2(150, 142)
	placeholder_panel.add_theme_stylebox_override("panel", UI.panel_style(UI.COLOR_BG_CARD, UI.COLOR_BORDER, 1, 4, 6))
	product_head.add_child(placeholder_panel)
	item_placeholder = _label("道具图示", 17, UI.COLOR_TEXT_MUTED)
	item_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder_panel.add_child(item_placeholder)
	var product_labels := VBoxContainer.new()
	product_labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	product_labels.alignment = BoxContainer.ALIGNMENT_CENTER
	product_head.add_child(product_labels)
	detail_title = _label("", 24, UI.COLOR_TEXT_GOLD)
	product_labels.add_child(detail_title)
	detail_type = _label("", 15, UI.COLOR_TEXT_MUTED)
	product_labels.add_child(detail_type)
	description_label = _label("", 16)
	description_label.custom_minimum_size.y = 54
	details.add_child(_detail_box(description_label))
	current_label = _label("", 17)
	details.add_child(_detail_box(current_label))
	next_label = Label.new()
	details.add_child(_label("具体数值、触发方式与叠加规则以当前物品说明为准。", 14, UI.COLOR_TEXT_MUTED))
	feedback_label = _label("", 15, UI.COLOR_TEXT_GOLD)
	feedback_label.custom_minimum_size.y = 24
	body.add_child(feedback_label)
	modal.add_footer_button("关闭", close_panel)
	refund_button = modal.add_footer_button("退还 1 份 · 5 骨", _trade.bind(true))
	buy_button = modal.add_footer_button("购买 1 份 · 5 骨", _trade.bind(false), "primary")
	modal.footer.alignment = BoxContainer.ALIGNMENT_END
	hide()


func _label(value: String, font_size: int, color: Color = UI.COLOR_TEXT) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _detail_box(content: Control) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel_style(UI.COLOR_BG_CARD, UI.COLOR_BORDER, 1, 4, 10))
	box.add_child(content)
	return box


func open(initial_filter: String = "all") -> void:
	profile = SAVE_MANAGER.load_story_profile() if SAVE_MANAGER.get_active_mode() == SAVE_MANAGER.MODE_STORY else SAVE_MANAGER.get_current_endless_profile()
	current_filter = initial_filter if FILTERS.has(initial_filter) else "all"
	feedback_label.text = "" if not profile.is_empty() else "未找到当前档案，请先从存档入口进入营地。"
	detail_scroll.scroll_vertical = 0
	_refresh()
	show()
	modal.apply_layout()
	item_list.grab_focus()


func close_panel() -> void:
	if visible:
		hide()
		closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func _set_filter(filter_id: String) -> void:
	current_filter = filter_id
	_refresh()
	item_list.grab_focus()


func _refresh() -> void:
	modal.set_title("阮狗 · 营地商店")
	for key in filter_buttons:
		UI.apply_button_style(filter_buttons[key], "primary" if key == current_filter else "normal")
	filtered_ids.clear()
	item_list.clear()
	grid_buttons.clear()
	for child in inventory_grid.get_children():
		inventory_grid.remove_child(child)
		child.queue_free()
	for id in ITEMS.STONE_IDS:
		var count := ITEMS.get_count(profile, id)
		if current_filter == "stones" and not STONES.has(id):
			continue
		if current_filter == "equipment" and STONES.has(id):
			continue
		if current_filter == "owned" and count == 0:
			continue
		filtered_ids.append(id)
		item_list.add_item(str(ITEMS.get_definition(id)["title"]))
		var card := Button.new()
		card.custom_minimum_size = Vector2(154, 142)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.tooltip_text = str(ITEMS.get_definition(id).get("summary", ""))
		card.text = ""
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 4)
		card.add_child(content)
		var owned_badge := _label("已拥有" if count > 0 else "", 12, UI.COLOR_TEXT_GOLD)
		owned_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		owned_badge.offset_left = -62
		owned_badge.offset_top = 4
		owned_badge.offset_right = -5
		owned_badge.offset_bottom = 23
		owned_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		owned_badge.add_theme_color_override("font_outline_color", UI.COLOR_BG)
		owned_badge.add_theme_constant_override("outline_size", 3)
		card.add_child(owned_badge)
		var icon_slot := PanelContainer.new()
		icon_slot.custom_minimum_size = Vector2(78, 78)
		icon_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_slot.add_theme_stylebox_override("panel", UI.panel_style(UI.COLOR_BG_CARD, UI.COLOR_BORDER, 1, 3, 4))
		var icon_label := _label("图示", 14, UI.COLOR_TEXT_MUTED)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_slot.add_child(icon_label)
		content.add_child(icon_slot)
		var item_label := _label(str(ITEMS.get_definition(id).get("title", id)), 14, UI.COLOR_TEXT)
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_label.custom_minimum_size.y = 26
		content.add_child(item_label)
		var badge_row := HBoxContainer.new()
		badge_row.custom_minimum_size.y = 20
		badge_row.add_theme_constant_override("separation", 4)
		content.add_child(badge_row)
		var count_badge := _label("x%d" % count if count > 1 else "", 13, UI.COLOR_TEXT_GOLD)
		count_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_badge.add_theme_color_override("font_outline_color", UI.COLOR_BG)
		count_badge.add_theme_constant_override("outline_size", 3)
		badge_row.add_child(count_badge)
		card.pressed.connect(_select_id.bind(id))
		UI.apply_card_button_style(card, id == selected_id)
		inventory_grid.add_child(card)
		grid_buttons[id] = card
	if filtered_ids.is_empty():
		selected_id = ""
	else:
		if not filtered_ids.has(selected_id):
			selected_id = filtered_ids[0]
		item_list.select(filtered_ids.find(selected_id))
		item_list.ensure_current_is_visible()
	_update_details()


func _refresh_carried_slots() -> void:
	for child in carried_slots.get_children():
		carried_slots.remove_child(child)
		child.queue_free()
	var purchased: Array = profile.get("ruan_stone_purchased", [])
	var slot_count: int = maxi(1, ITEMS.get_carry_limit(profile))
	for index in range(slot_count):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(98, 46)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var item_id := str(purchased[index]) if index < purchased.size() else ""
		slot.add_theme_stylebox_override("panel", UI.card_style(item_id != "", STONES.has(item_id)))
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text = str(ITEMS.get_definition(item_id).get("title", item_id)) if item_id != "" else "空槽"
		label.add_theme_font_size_override("font_size", 12)
		slot.add_child(label)
		carried_slots.add_child(slot)


func _select_id(item_id: String) -> void:
	selected_id = item_id
	if filtered_ids.has(item_id):
		item_list.select(filtered_ids.find(item_id))
	_update_details()


func _select_index(index: int) -> void:
	if index >= 0 and index < filtered_ids.size():
		selected_id = filtered_ids[index]
		detail_scroll.scroll_vertical = 0
		_update_details()


func _update_details() -> void:
	if selected_id == "":
		detail_title.text = "尚未携带物品"
		description_label.text = "切换到「全部」挑选物品。资源不足时可继续挑战，通关会获得对应资源。"
		current_label.text = ""
		next_label.text = ""
		buy_button.disabled = true
		refund_button.disabled = true
		return
	var definition := ITEMS.get_definition(selected_id)
	var count := ITEMS.get_count(profile, selected_id)
	detail_title.text = str(definition["title"])
	detail_type.text = "阮石 / 特殊道具" if STONES.has(selected_id) else "装备 / 一般"
	item_placeholder.text = "阮石" if STONES.has(selected_id) else "装备"
	description_label.text = str(definition["summary"])
	description_label.add_theme_color_override("font_color", UI.COLOR_TEXT_GOLD)
	description_label.add_theme_font_size_override("font_size", 20)
	current_label.text = "当前效果\n" + ITEMS.get_effect_text(selected_id, count)
	next_label.text = ITEMS.get_effect_text(selected_id, count + 1)
	var at_limit := ITEMS.get_carried_count(profile) >= ITEMS.get_carry_limit(profile)
	var cost := ITEMS.get_next_cost(profile, selected_id)
	buy_button.disabled = profile.is_empty() or at_limit or ITEMS.get_currency(profile) < cost
	buy_button.text = "携带已满" if at_limit else ("%s不足 · 需 %d" % [ITEMS.get_currency_name(profile), cost] if ITEMS.get_currency(profile) < cost else "购买 1 份 · %d %s" % [cost, ITEMS.get_currency_name(profile)])
	refund_button.disabled = count <= 0
	refund_button.text = "退还 1 份 · %d %s" % [cost, ITEMS.get_currency_name(profile)]


func _trade(refund_one: bool) -> void:
	if selected_id == "":
		return
	var result := SERVICE.trade(selected_id, refund_one)
	if not bool(result.get("success", false)):
		var messages := {"save_failed": "存档写入失败，本次交易未保存，资源与物品保持原状。", "profile_missing": "未找到当前档案。", "carry_limit_reached": "携带位已满，请先退还其他物品。", "not_enough_bones": "资源不足，无法购买该物品。", "not_carried": "当前未携带该物品，无法退还。"}
		feedback_label.text = str(messages.get(str(result.get("reason", "")), "交易未完成，请重新打开商店重试。"))
		feedback_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.57))
		return
	profile = result["profile"]
	var cost := ITEMS.get_next_cost(profile, selected_id)
	feedback_label.text = "%s 1 份%s，%s %d %s。" % ["已退还" if refund_one else "已携带", ITEMS.get_definition(selected_id)["title"], "返还" if refund_one else "花费", cost, ITEMS.get_currency_name(profile)]
	feedback_label.add_theme_color_override("font_color", UI.COLOR_TEXT_GOOD)
	_refresh()
	profile_changed.emit()

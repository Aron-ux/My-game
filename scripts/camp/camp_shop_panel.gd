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
	modal.configure(Vector2(1100, 650), 0.88, 0.91, Vector2(640, 440))
	modal.set_title("携带物品")
	modal.set_hint("在阮狗处使用当前存档资源购买；物品跨战斗保留，可逐份退还。")
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	modal.set_body(body)
	status_label = _label("", 18, UI.COLOR_TEXT_GOLD)
	body.add_child(status_label)
	carried_label = _label("", 14)
	carried_label.max_lines_visible = 2
	carried_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(carried_label)
	carried_slots = HBoxContainer.new()
	carried_slots.name = "CarriedEquipmentSlots"
	carried_slots.add_theme_constant_override("separation", 8)
	body.add_child(carried_slots)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	body.add_child(filters)
	for key in FILTERS:
		var button := Button.new()
		button.text = FILTERS[key]
		button.custom_minimum_size = Vector2(90, 36)
		button.pressed.connect(_set_filter.bind(str(key)))
		filters.add_child(button)
		filter_buttons[key] = button
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	body.add_child(columns)
	inventory_grid = GridContainer.new()
	inventory_grid.name = "InventoryGrid"
	inventory_grid.columns = 3
	inventory_grid.custom_minimum_size = Vector2(390, 0)
	inventory_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_grid.add_theme_constant_override("h_separation", 8)
	inventory_grid.add_theme_constant_override("v_separation", 8)
	columns.add_child(inventory_grid)
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
	detail_scroll = ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_stretch_ratio = 1.45
	columns.add_child(detail_scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 18)
	detail_scroll.add_child(details)
	detail_title = _label("", 24, UI.COLOR_TEXT_GOLD)
	details.add_child(detail_title)
	description_label = _label("", 16)
	details.add_child(description_label)
	current_label = _label("", 17)
	details.add_child(current_label)
	next_label = _label("", 17, UI.COLOR_TEXT_GOOD)
	details.add_child(next_label)
	details.add_child(_label("携带物品由队伍共享。阮石响应直接普攻，触发条件与叠加结果以此处说明为准。", 14, UI.COLOR_TEXT_MUTED))
	feedback_label = _label("", 15, UI.COLOR_TEXT_GOLD)
	feedback_label.custom_minimum_size.y = 24
	body.add_child(feedback_label)
	modal.add_footer_button("关闭", close_panel)
	refund_button = modal.add_footer_button("退还 1 份 · 5 骨", _trade.bind(true))
	buy_button = modal.add_footer_button("购买 1 份 · 5 骨", _trade.bind(false), "primary")
	hide()


func _label(value: String, font_size: int, color: Color = UI.COLOR_TEXT) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


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
	var currency_name := ITEMS.get_currency_name(profile)
	var currency := ITEMS.get_currency(profile)
	status_label.text = "%s %d    携带 %d / %d    通关可提升携带上限" % [currency_name, currency, ITEMS.get_carried_count(profile), ITEMS.get_carry_limit(profile)]
	_refresh_carried_slots()
	carried_label.text = "当前携带：" + ITEMS.get_carried_summary_text(profile.get("ruan_stone_purchased", []))
	carried_label.tooltip_text = carried_label.text
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
		item_list.add_item(str(ITEMS.get_definition(id)["title"]) + ("  ×%d" % count if count > 0 else ""))
		var card := Button.new()
		card.custom_minimum_size = Vector2(118, 84)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.tooltip_text = str(ITEMS.get_definition(id).get("summary", ""))
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 5)
		card.add_child(content)
		var item_label := _label(str(ITEMS.get_definition(id).get("title", id)), 14, UI.COLOR_TEXT)
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(item_label)
		var count_label := _label("携带 ×%d" % count if count > 0 else "未携带", 10, UI.COLOR_TEXT_GOLD if count > 0 else UI.COLOR_TEXT_MUTED)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(count_label)
		card.pressed.connect(_select_id.bind(id))
		UI.apply_card_button_style(card, id == selected_id, STONES.has(id))
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
	description_label.text = str(definition["summary"])
	current_label.text = "已携带 %d 份\n%s" % [count, ITEMS.get_effect_text(selected_id, count)]
	next_label.text = "再携带 1 份后\n" + ITEMS.get_effect_text(selected_id, count + 1)
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

extends CanvasLayer

const UI := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const SHOP_ROLE_IDS := ["swordsman", "gunner", "mage"]
const SHOP_ROLE_NAMES := {"swordsman": "剑士", "gunner": "枪手", "mage": "法师"}
const MERCHANT_STAT_COST := 100
const SHOP_ITEMS := [
	{"id": "power", "name": "大力", "text": "选择角色攻击力 +1"},
	{"id": "lightness", "name": "轻盈", "text": "选择角色基础移动速度 +1.5"},
	{"id": "agility", "name": "灵活", "text": "选择角色基础闪避 +0.5%"},
	{"id": "strength", "name": "强壮", "text": "选择角色血量 +20"},
	{"id": "quickness", "name": "敏捷", "text": "选择角色攻击速度 +2%"},
	{"id": "hardness", "name": "坚硬", "text": "选择角色护甲 +2"},
	{"id": "wisdom", "name": "智慧", "text": "选择角色大招获取效率 +1%"}
]

var flow
var root: Control
var status: Label
var skip_button: Button
var shop_button: Button
var shop: PanelContainer
var shop_backdrop: ColorRect
var contents: VBoxContainer
var shop_open := false
var shop_render_signature := ""
var shop_rebuild_pending := false
var shop_grid: GridContainer
var shop_detail_title: Label
var shop_detail_type: Label
var shop_item_placeholder: Label
var shop_detail_text: Label
var shop_price: Label
var selected_item_id := "power"
var selected_role_id := ""
var role_picker: Control
var role_buttons: Dictionary = {}
var purchase_button: Button
var first_aid_button: Button

func _ready() -> void:
	layer = 9
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	column.position = Vector2(-305, 125)
	column.custom_minimum_size = Vector2(285, 0)
	column.add_theme_constant_override("separation", 8)
	root.add_child(column)
	status = Label.new()
	status.add_theme_font_override("font", UI.get_reading_font())
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", UI.COLOR_TEXT_GOLD)
	column.add_child(status)
	shop_button = _button("靠近阮狗 · 打开商店")
	shop_button.pressed.connect(func() -> void:
		shop_open = not shop_open
		refresh()
	)
	column.add_child(shop_button)
	skip_button = _button("跳过整备，进入下一波")
	skip_button.pressed.connect(flow.skip_preparation)
	column.add_child(skip_button)
	shop_backdrop = ColorRect.new()
	shop_backdrop.name = "ShopBackdrop"
	shop_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_backdrop.color = Color(0.02, 0.015, 0.01, 0.72)
	shop_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shop_backdrop)
	shop_backdrop.hide()
	shop = PanelContainer.new()
	shop.add_theme_stylebox_override("panel", UI.panel_style())
	shop.custom_minimum_size = Vector2(980, 590)
	shop.set_anchors_preset(Control.PRESET_CENTER)
	shop.position = Vector2(-490, -295)
	root.add_child(shop)
	contents = VBoxContainer.new()
	contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contents.add_theme_constant_override("separation", 12)
	shop.add_child(contents)
	var title := Label.new()
	title.text = "阮狗 · 整备商店"
	title.add_theme_font_override("font", UI.get_reading_font())
	title.add_theme_color_override("font_color", UI.COLOR_TEXT_GOLD)
	contents.add_child(title)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	contents.add_child(body)
	var item_scroll := ScrollContainer.new()
	item_scroll.custom_minimum_size.x = 560
	item_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(item_scroll)
	var catalog := VBoxContainer.new()
	catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog.add_theme_constant_override("separation", 10)
	item_scroll.add_child(catalog)
	var catalog_header := PanelContainer.new()
	catalog_header.custom_minimum_size.y = 48
	catalog_header.add_theme_stylebox_override("panel", UI.panel_style(UI.COLOR_BG_SOFT, UI.COLOR_BORDER_GOLD, 2, 5, 10))
	catalog.add_child(catalog_header)
	var catalog_title := Label.new()
	catalog_title.text = "商品"
	catalog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catalog_title.add_theme_font_size_override("font_size", 21)
	catalog_title.add_theme_color_override("font_color", UI.COLOR_TEXT_GOLD)
	catalog_header.add_child(catalog_title)
	shop_grid = GridContainer.new()
	shop_grid.name = "ShopGrid"
	shop_grid.columns = 3
	shop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_grid.add_theme_constant_override("h_separation", 10)
	shop_grid.add_theme_constant_override("v_separation", 10)
	catalog.add_child(shop_grid)
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size.x = 340
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", UI.panel_style(UI.COLOR_BG_SOFT, UI.COLOR_BORDER_GOLD, 2, 6, 14))
	body.add_child(detail_panel)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(detail_scroll)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x = 300
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 12)
	detail_scroll.add_child(detail)
	var product_head := HBoxContainer.new()
	product_head.add_theme_constant_override("separation", 10)
	detail.add_child(product_head)
	var placeholder_panel := PanelContainer.new()
	placeholder_panel.custom_minimum_size = Vector2(120, 110)
	placeholder_panel.add_theme_stylebox_override("panel", UI.panel_style(UI.COLOR_BG_CARD, UI.COLOR_BORDER, 1, 4, 6))
	product_head.add_child(placeholder_panel)
	shop_item_placeholder = Label.new()
	shop_item_placeholder.text = "道具图示"
	shop_item_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_item_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shop_item_placeholder.add_theme_color_override("font_color", UI.COLOR_TEXT_MUTED)
	placeholder_panel.add_child(shop_item_placeholder)
	var product_labels := VBoxContainer.new()
	product_labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	product_labels.alignment = BoxContainer.ALIGNMENT_CENTER
	product_head.add_child(product_labels)
	shop_detail_title = Label.new()
	shop_detail_title.add_theme_font_override("font", UI.get_reading_font())
	shop_detail_title.add_theme_font_size_override("font_size", 24)
	shop_detail_title.add_theme_color_override("font_color", UI.COLOR_TEXT_GOLD)
	product_labels.add_child(shop_detail_title)
	shop_detail_type = Label.new()
	shop_detail_type.add_theme_font_size_override("font_size", 14)
	shop_detail_type.add_theme_color_override("font_color", UI.COLOR_TEXT_MUTED)
	product_labels.add_child(shop_detail_type)
	shop_detail_text = Label.new()
	shop_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var description_panel := PanelContainer.new()
	description_panel.add_theme_stylebox_override("panel", UI.panel_style(UI.COLOR_BG_CARD, UI.COLOR_BORDER, 1, 4, 10))
	description_panel.add_child(shop_detail_text)
	detail.add_child(description_panel)
	shop_price = Label.new()
	shop_price.add_theme_color_override("font_color", UI.COLOR_TEXT_GOLD)
	detail.add_child(shop_price)
	role_picker = Control.new()
	role_picker.name = "RolePicker"
	role_picker.custom_minimum_size = Vector2(244, 82)
	detail.add_child(role_picker)
	var role_scope_hint := Label.new()
	role_scope_hint.text = "强化只对单一角色生效"
	role_scope_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_scope_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	role_scope_hint.add_theme_font_override("font", UI.get_reading_font())
	role_scope_hint.add_theme_font_size_override("font_size", 13)
	role_scope_hint.add_theme_color_override("font_color", UI.COLOR_TEXT_GOLD)
	role_scope_hint.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	role_scope_hint.add_theme_constant_override("shadow_offset_x", 1)
	role_scope_hint.add_theme_constant_override("shadow_offset_y", 1)
	role_scope_hint.custom_minimum_size.y = 22
	detail.add_child(role_scope_hint)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 10)
	contents.add_child(footer)
	purchase_button = _button("购买")
	purchase_button.pressed.connect(_purchase_selected)
	footer.add_child(purchase_button)
	first_aid_button = _button("急救")
	first_aid_button.pressed.connect(flow.claim_first_aid)
	footer.add_child(first_aid_button)
	var close_button := _button("关闭")
	close_button.pressed.connect(close_shop)
	footer.add_child(close_button)
	refresh()

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.add_theme_font_override("font", UI.get_reading_font())
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", UI.panel_style(UI.COLOR_BG, UI.COLOR_BORDER_GOLD, 1, 5, 12))
	return button

func refresh() -> void:
	if root == null:
		return
	if flow.main.game_over or flow.phase == "complete":
		hide_all()
		return
	root.show()
	var preparing: bool = flow.phase == "preparation"
	status.text = "整备阶段 · %.0f 秒" % flow.remaining
	status.visible = preparing
	var near: bool = preparing and is_instance_valid(flow.merchant) and flow.main.player.global_position.distance_to(flow.merchant.global_position) <= 120.0
	skip_button.visible = preparing
	shop_button.visible = preparing
	shop_button.disabled = not near or flow.claimed or flow.merchant_health <= 0
	shop_button.text = "阮狗已离场" if flow.merchant_health <= 0 else ("本轮商店已关闭" if flow.claimed else ("阮狗 · 打开商店" if near else "靠近阮狗 · 打开商店"))
	if not preparing or not near or flow.merchant_health <= 0:
		shop_open = false
	shop.visible = shop_open
	shop_backdrop.visible = shop_open
	if preparing and shop_open:
		var signature := "%d:%s:%s:%d:%d:%d:%s:%s" % [int(flow.main.gold), str(flow.claimed), str(near), int(flow.merchant_health), flow.main.player.roles.size(), int(flow.main.endless_tier), str(flow.main.player.roles), selected_item_id]
		if signature != shop_render_signature:
			shop_render_signature = signature
			_request_shop_rebuild(near)

func _request_shop_rebuild(near: bool) -> void:
	if shop_rebuild_pending:
		return
	shop_rebuild_pending = true
	call_deferred("_rebuild_shop_deferred", near)

func _rebuild_shop_deferred(near: bool) -> void:
	shop_rebuild_pending = false
	if not is_instance_valid(contents):
		return
	for child in shop_grid.get_children():
		child.queue_free()
	for child in role_picker.get_children():
		child.free()
	role_buttons.clear()
	for role_id_value in SHOP_ROLE_IDS:
		var role_id := str(role_id_value)
		var role_name := str(SHOP_ROLE_NAMES[role_id])
		var role_available := false
		for role_value in flow.main.player.roles:
			var role: Dictionary = role_value
			if str(role.get("id", "")) == role_id:
				role_available = true
				role_name = str(role.get("name", role_name))
				break
		var role_button := _create_role_button(role_id, role_name)
		role_button.disabled = not role_available
		role_picker.add_child(role_button)
		role_button.position = Vector2(14.0 + SHOP_ROLE_IDS.find(role_id) * 80.0, 13.0)
		role_button.pivot_offset = Vector2(28.0, 28.0)
		role_button.rotation = deg_to_rad(45.0)
		role_button.set_deferred("rotation", deg_to_rad(45.0))
		role_buttons[role_id] = role_button
		if role_available and selected_role_id == role_id:
			role_button.set_pressed_no_signal(true)
	if flow.main.player.roles.is_empty():
		selected_role_id = ""
	elif not role_buttons.has(selected_role_id) or bool((role_buttons.get(selected_role_id) as BaseButton).disabled):
		selected_role_id = ""
		for role_id_value in SHOP_ROLE_IDS:
			var available_button := role_buttons.get(str(role_id_value)) as BaseButton
			if available_button != null and not available_button.disabled:
				selected_role_id = str(role_id_value)
				break
	if selected_role_id != "":
		(role_buttons.get(selected_role_id) as BaseButton).set_pressed_no_signal(true)
	for item in SHOP_ITEMS:
		var card := Button.new()
		card.custom_minimum_size = Vector2(154, 142)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.text = ""
		card.pressed.connect(_select_shop_item.bind(str(item["id"])))
		UI.apply_card_button_style(card, selected_item_id == str(item["id"]))
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 6)
		card.add_child(content)
		var icon_slot := PanelContainer.new()
		icon_slot.custom_minimum_size = Vector2(82, 82)
		icon_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_slot.add_theme_stylebox_override("panel", UI.panel_style(UI.COLOR_BG_CARD, UI.COLOR_BORDER, 1, 3, 4))
		var icon_label := Label.new()
		icon_label.text = "图示"
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.add_theme_color_override("font_color", UI.COLOR_TEXT_MUTED)
		icon_slot.add_child(icon_label)
		content.add_child(icon_slot)
		var item_label := Label.new()
		item_label.text = str(item["name"])
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_label.custom_minimum_size.y = 30
		item_label.add_theme_font_size_override("font_size", 14)
		content.add_child(item_label)
		shop_grid.add_child(card)
	_update_shop_details(near)

func _select_shop_item(item_id: String) -> void:
	selected_item_id = item_id
	shop_render_signature = ""
	refresh()

func _create_role_button(role_id: String, role_name: String) -> Button:
	var button := Button.new()
	button.name = "Role_%s" % role_id
	button.custom_minimum_size = Vector2(56, 56)
	button.size = Vector2(56, 56)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pivot_offset = Vector2(28, 28)
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = role_name
	var normal := UI.panel_style(UI.COLOR_BG_CARD, UI.COLOR_BORDER_GOLD, 2, 3, 0)
	var hover := UI.panel_style(UI.COLOR_BG_SOFT, UI.COLOR_BORDER_GOLD, 3, 3, 0)
	var pressed := UI.panel_style(Color(0.30, 0.22, 0.08, 0.98), UI.COLOR_BORDER_GOLD, 3, 3, 0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	var role_label := Label.new()
	role_label.text = role_name
	role_label.position = Vector2.ZERO
	role_label.size = Vector2(56, 56)
	role_label.rotation = deg_to_rad(-45.0)
	role_label.pivot_offset = Vector2(28, 28)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	role_label.add_theme_font_override("font", UI.get_reading_bold_font())
	role_label.add_theme_font_size_override("font_size", 15)
	role_label.add_theme_color_override("font_color", UI.COLOR_TEXT)
	role_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	role_label.add_theme_constant_override("shadow_offset_x", 1)
	role_label.add_theme_constant_override("shadow_offset_y", 1)
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(role_label)
	button.pressed.connect(_select_role.bind(role_id))
	return button

func _select_role(role_id: String) -> void:
	if not role_buttons.has(role_id):
		return
	selected_role_id = role_id
	for other_role_id in role_buttons:
		var role_button := role_buttons[other_role_id] as BaseButton
		if role_button != null:
			role_button.set_pressed_no_signal(str(other_role_id) == role_id)
	_update_shop_details(true)

func _purchase_selected() -> void:
	if selected_item_id != "" and selected_role_id != "":
		flow.purchase_stat(selected_item_id, selected_role_id)
		shop_render_signature = ""
		refresh()

func _update_shop_details(near: bool) -> void:
	var selected: Dictionary = {}
	for item in SHOP_ITEMS:
		if str(item["id"]) == selected_item_id:
			selected = item
			break
	shop_detail_title.text = str(selected.get("name", "商品"))
	shop_detail_type.text = "属性强化 / 整备道具"
	shop_item_placeholder.text = "属性"
	shop_detail_text.text = str(selected.get("text", ""))
	shop_price.text = "价格：%d 金币" % MERCHANT_STAT_COST
	role_picker.visible = not flow.main.player.roles.is_empty()
	role_picker.mouse_filter = Control.MOUSE_FILTER_STOP if role_picker.visible else Control.MOUSE_FILTER_IGNORE
	purchase_button.disabled = not near or flow.claimed or flow.merchant_health <= 0 or int(flow.main.gold) < MERCHANT_STAT_COST or selected_role_id == ""
	purchase_button.text = "本轮已关闭" if flow.claimed else ("金币不足" if int(flow.main.gold) < MERCHANT_STAT_COST else "购买")
	first_aid_button.text = "急救 · 免费恢复全队至满血" if flow.get_first_aid_ratio() >= 1.0 else "急救 · 免费恢复损失生命值的 %.0f%%" % (flow.get_first_aid_ratio() * 100.0)
	first_aid_button.disabled = not near or flow.claimed or flow.merchant_health <= 0

func close_shop() -> void:
	shop_open = false
	shop_render_signature = ""
	if shop != null:
		shop.hide()
	if shop_backdrop != null:
		shop_backdrop.hide()

func _unhandled_input(event: InputEvent) -> void:
	if shop_open and event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()

func hide_all() -> void:
	if root != null:
		root.hide()

extends CanvasLayer

const UI := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
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
var contents: VBoxContainer
var shop_open := false
var shop_render_signature := ""
var shop_rebuild_pending := false

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
	shop = PanelContainer.new()
	shop.add_theme_stylebox_override("panel", UI.panel_style())
	shop.custom_minimum_size = Vector2(430, 0)
	shop.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	shop.position = Vector2(-455, 300)
	root.add_child(shop)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 400)
	shop.add_child(scroll)
	contents = VBoxContainer.new()
	contents.custom_minimum_size.x = 400
	contents.add_theme_constant_override("separation", 6)
	scroll.add_child(contents)
	var title := Label.new()
	title.text = "阮狗 · 整备商店"
	title.add_theme_font_override("font", UI.get_reading_font())
	title.add_theme_color_override("font_color", UI.COLOR_TEXT_GOLD)
	contents.add_child(title)
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
	if preparing and shop_open:
		var signature := "%d:%s:%s:%d:%d:%d" % [int(flow.main.gold), str(flow.claimed), str(near), int(flow.merchant_health), flow.main.player.roles.size(), int(flow.main.endless_tier)]
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
	for child in contents.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "阮狗 · 整备商店"
	title.add_theme_font_override("font", UI.get_reading_font())
	title.add_theme_color_override("font_color", UI.COLOR_TEXT_GOLD)
	contents.add_child(title)
	if flow.claimed:
		var locked := Label.new()
		locked.text = "已使用急救，本轮整备不能再购买。"
		locked.add_theme_font_override("font", UI.get_reading_font())
		contents.add_child(locked)
		return
	if not near:
		return
	for item in SHOP_ITEMS:
		var row := VBoxContainer.new()
		var label := Label.new()
		label.text = "%s  ·  %s  ·  100金币" % [item["name"], item["text"]]
		label.add_theme_font_override("font", UI.get_reading_font())
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		var roles := HBoxContainer.new()
		for role in flow.main.player.roles:
			var role_id := str(role.get("id", ""))
			var button := _button("%s购买" % str(role.get("name", role_id)))
			button.custom_minimum_size = Vector2(92, 34)
			button.disabled = int(flow.main.gold) < MERCHANT_STAT_COST
			button.pressed.connect(flow.purchase_stat.bind(str(item["id"]), role_id))
			roles.add_child(button)
		row.add_child(roles)
		contents.add_child(row)
	var first_aid_text := "急救 · 免费恢复全队至满血" if flow.get_first_aid_ratio() >= 1.0 else "急救 · 免费恢复全队已损失生命值的 %.0f%%" % (flow.get_first_aid_ratio() * 100.0)
	var first_aid := _button(first_aid_text)
	first_aid.disabled = not near or flow.merchant_health <= 0
	first_aid.pressed.connect(flow.claim_first_aid)
	contents.add_child(first_aid)

func close_shop() -> void:
	shop_open = false
	shop_render_signature = ""
	if shop != null:
		shop.hide()

func hide_all() -> void:
	if root != null:
		root.hide()

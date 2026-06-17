extends CanvasLayer

signal close_requested

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const PLAYER_EQUIPMENT_FLOW := preload("res://scripts/player/player_equipment_flow.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const ARCHIVE_ORNAMENT_LAYER := preload("res://scripts/ui/hud/archive_ornament_layer.gd")
const WHITE_KEY_SHADER := preload("res://shaders/white_key.gdshader")
const ARCHIVE_PORTRAIT_BACKDROP := preload("res://scripts/ui/hud/archive_portrait_backdrop.gd")

const GLOBAL_UNIT_MOVE_SPEED_SCALE := 0.7
const PANEL_MAX_SIZE := Vector2(1380.0, 780.0)
const PANEL_MIN_SIZE := Vector2(720.0, 430.0)
const PANEL_WIDTH_RATIO := 0.94
const PANEL_HEIGHT_RATIO := 0.96
const PANEL_EDGE_MARGIN := Vector2(14.0, 10.0)

const ROLE_TEXTURE_PATHS := {
	"swordsman": "人设草图/剑士草图.jpg",
	"gunner": "人设草图/枪手草图.jpg",
	"mage": "人设草图/术师草图.jpg"
}

const ROLE_PIXEL_TEXTURE_PATHS := {
	"swordsman": "res://assets/players/sword/剑-run.png",
	"gunner": "res://assets/players/gun/gun-run.png",
	"mage": "res://assets/players/wizard/wizard-run.png"
}

const ROLE_PIXEL_FRAME_RECTS := {
	"swordsman": Rect2(529.0, 21.0, 95.0, 89.0),
	"gunner": Rect2(542.0, 25.0, 69.0, 74.0),
	"mage": Rect2(314.0, 78.0, 133.0, 93.0)
}

const ROLE_PIXEL_MODULATE := {
	"swordsman": Color(1.0, 0.88, 0.52, 1.0),
	"gunner": Color(1.0, 0.56, 0.44, 1.0),
	"mage": Color(0.72, 0.92, 1.0, 1.0)
}

const ROLE_PIXEL_INACTIVE_MODULATE := {
	"swordsman": Color(0.72, 0.58, 0.34, 0.84),
	"gunner": Color(0.70, 0.36, 0.30, 0.84),
	"mage": Color(0.42, 0.64, 0.76, 0.84)
}

const ROLE_TAGLINES := {
	"swordsman": "近战 · 均衡 · 连击",
	"gunner": "远程 · 爆发 · 弹幕",
	"mage": "奥术 · 范围 · 控场"
}

var role_texture_rect: TextureRect
var role_title_label: Label
var role_subtitle_label: Label
var role_nav_list: VBoxContainer
var role_button_row: HBoxContainer
var stats_label: RichTextLabel
var equipment_list: HBoxContainer
var blessing_list: VBoxContainer
var card_label: RichTextLabel
var panel_title_label: Label
var panel_role_pill_label: Label
var panel_status_label: Label
var ornament_layer: Control
var backdrop: ColorRect
var panel: Panel
var panel_margin: MarginContainer
var gift_popup: PopupMenu
var blessing_popup: PopupMenu
var cached_player: Node
var viewed_role_index: int = 0
var pending_gift_equipment_id: String = ""
var pending_gift_from_role_id: String = ""
var gift_target_role_ids: Array[String] = []
var pending_compose_blessing_id: String = ""
var pending_compose_role_id: String = ""
var pending_compose_is_skill_bound: bool = false
var ui_white_key_material: ShaderMaterial
var role_pixel_texture_cache: Dictionary = {}


func _archive_panel_style(
		bg_color: Color,
		border_color: Color = Color(0.82, 0.57, 0.22, 0.96),
		border_width: int = 1,
		corner_radius: int = 12,
		content_margin: float = 0.0,
		shadow_size: int = 8
) -> StyleBoxFlat:
	var style := SURVIVORS_THEME.panel_style(bg_color, border_color, border_width, corner_radius, content_margin)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0.0, 3.0)
	style.anti_aliasing = true
	return style

func _archive_card_style(selected: bool = false, accented: bool = false, disabled: bool = false) -> StyleBoxFlat:
	var bg := Color(0.055, 0.073, 0.10, 0.96)
	var border := Color(0.43, 0.49, 0.60, 0.86)
	var border_width := 1
	if accented:
		bg = Color(0.055, 0.12, 0.075, 0.98)
		border = Color(0.42, 0.95, 0.50, 0.96)
		border_width = 2
	if selected:
		bg = Color(0.18, 0.12, 0.045, 0.98)
		border = Color(1.0, 0.78, 0.28, 1.0)
		border_width = 2
	if disabled:
		bg = bg.darkened(0.28)
		border = border.darkened(0.30)
	return _archive_panel_style(bg, border, border_width, 12, 8.0, 5)

func _archive_card_hover_style(selected: bool = false, accented: bool = false) -> StyleBoxFlat:
	var style := _archive_card_style(selected, accented, false)
	style.bg_color = style.bg_color.lightened(0.08)
	style.border_color = style.border_color.lightened(0.12)
	return style

func _apply_archive_button_style(button: Button, selected: bool = false, accented: bool = false, disabled: bool = false) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _archive_card_style(selected, accented, disabled))
	button.add_theme_stylebox_override("hover", _archive_card_hover_style(selected, accented))
	var pressed := _archive_card_style(selected, accented, disabled)
	pressed.bg_color = pressed.bg_color.darkened(0.08)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", _archive_card_hover_style(true, accented))
	var font_color := SURVIVORS_THEME.COLOR_TEXT
	if accented:
		font_color = SURVIVORS_THEME.COLOR_TEXT_GOOD
	if selected:
		font_color = SURVIVORS_THEME.COLOR_TEXT_GOLD
	if disabled:
		font_color = Color(0.58, 0.62, 0.70, 0.8)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color.lightened(0.10))
	button.add_theme_color_override("font_pressed_color", font_color.darkened(0.08))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.64, 0.70))

func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.012, 0.018, 0.80)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	panel = Panel.new()
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	panel_margin = MarginContainer.new()
	panel_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_margin.add_theme_constant_override("margin_left", 16)
	panel_margin.add_theme_constant_override("margin_top", 12)
	panel_margin.add_theme_constant_override("margin_right", 16)
	panel_margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(panel_margin)

	ornament_layer = ARCHIVE_ORNAMENT_LAYER.new()
	ornament_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	ornament_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(ornament_layer)

	var root_layout := VBoxContainer.new()
	root_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_layout.add_theme_constant_override("separation", 10)
	panel_margin.add_child(root_layout)

	_build_archive_header(root_layout)

	var content_layout := HBoxContainer.new()
	content_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_layout.add_theme_constant_override("separation", 10)
	root_layout.add_child(content_layout)

	_build_role_sidebar(content_layout)
	_build_role_detail_column(content_layout)
	_build_build_detail_column(content_layout)
	_build_archive_footer(root_layout)

	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	_layout_panel.call_deferred()

	gift_popup = PopupMenu.new()
	gift_popup.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	gift_popup.index_pressed.connect(_on_gift_popup_index_pressed)
	add_child(gift_popup)

	blessing_popup = PopupMenu.new()
	blessing_popup.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	blessing_popup.index_pressed.connect(_on_blessing_popup_index_pressed)
	add_child(blessing_popup)

	hide_panel()

func _build_archive_header(root_layout: VBoxContainer) -> void:
	var header := PanelContainer.new()
	header.custom_minimum_size = Vector2(0.0, 52.0)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_stylebox_override("panel", _archive_panel_style(Color(0.025, 0.035, 0.055, 0.98), Color(0.95, 0.68, 0.24, 1.0), 2, 12, 10.0, 10))
	root_layout.add_child(header)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	header.add_child(row)

	var archive_label := Label.new()
	archive_label.text = "构筑档案"
	archive_label.custom_minimum_size = Vector2(170.0, 0.0)
	archive_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	archive_label.add_theme_font_size_override("font_size", 22)
	archive_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	row.add_child(archive_label)

	panel_title_label = Label.new()
	panel_title_label.text = "角色构筑"
	panel_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel_title_label.add_theme_font_size_override("font_size", 28)
	panel_title_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	row.add_child(panel_title_label)

	panel_role_pill_label = Label.new()
	panel_role_pill_label.custom_minimum_size = Vector2(190.0, 0.0)
	panel_role_pill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_role_pill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel_role_pill_label.add_theme_font_size_override("font_size", 18)
	panel_role_pill_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOOD)
	row.add_child(panel_role_pill_label)

	panel_status_label = Label.new()
	panel_status_label.custom_minimum_size = Vector2(160.0, 0.0)
	panel_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel_status_label.add_theme_font_size_override("font_size", 16)
	panel_status_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	row.add_child(panel_status_label)

	var close_button := Button.new()
	close_button.text = "C 关闭"
	close_button.custom_minimum_size = Vector2(86.0, 34.0)
	SURVIVORS_THEME.apply_button_style(close_button, "normal", false)
	close_button.pressed.connect(_request_close)
	row.add_child(close_button)

func _build_role_sidebar(content_layout: HBoxContainer) -> void:
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(150.0, 0.0)
	sidebar.size_flags_horizontal = Control.SIZE_FILL
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_stylebox_override("panel", _archive_panel_style(Color(0.018, 0.030, 0.046, 0.98), Color(0.84, 0.58, 0.22, 0.96), 2, 12, 8.0, 9))
	content_layout.add_child(sidebar)

	var side_box := VBoxContainer.new()
	side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_box.add_theme_constant_override("separation", 8)
	sidebar.add_child(side_box)

	var title := Label.new()
	title.text = "队伍"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	side_box.add_child(title)

	role_nav_list = VBoxContainer.new()
	role_nav_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_nav_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	role_nav_list.add_theme_constant_override("separation", 10)
	side_box.add_child(role_nav_list)

	role_button_row = HBoxContainer.new()
	role_button_row.visible = false
	side_box.add_child(role_button_row)

func _build_role_detail_column(content_layout: HBoxContainer) -> void:
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(410.0, 0.0)
	detail_panel.size_flags_horizontal = Control.SIZE_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _archive_panel_style(Color(0.035, 0.048, 0.067, 0.97), Color(0.86, 0.62, 0.27, 0.96), 2, 14, 10.0, 10))
	content_layout.add_child(detail_panel)

	var detail_box := VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 8)
	detail_panel.add_child(detail_box)

	var hero_frame := PanelContainer.new()
	hero_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_frame.custom_minimum_size = Vector2(0.0, 178.0)
	hero_frame.add_theme_stylebox_override("panel", _archive_panel_style(Color(0.025, 0.035, 0.052, 0.94), Color(0.76, 0.52, 0.20, 0.92), 1, 12, 8.0, 7))
	detail_box.add_child(hero_frame)

	var portrait_backdrop := ARCHIVE_PORTRAIT_BACKDROP.new()
	portrait_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_frame.add_child(portrait_backdrop)

	var hero_box := VBoxContainer.new()
	hero_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_box.add_theme_constant_override("separation", 3)
	hero_frame.add_child(hero_box)

	role_texture_rect = TextureRect.new()
	role_texture_rect.custom_minimum_size = Vector2(0.0, 116.0)
	role_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	role_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	role_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_box.add_child(role_texture_rect)

	role_title_label = Label.new()
	role_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_title_label.add_theme_font_size_override("font_size", 23)
	role_title_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	hero_box.add_child(role_title_label)

	role_subtitle_label = Label.new()
	role_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_subtitle_label.add_theme_font_size_override("font_size", 14)
	role_subtitle_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	hero_box.add_child(role_subtitle_label)

	var stats_section := _make_panel_section("核心属性")
	stats_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_section.custom_minimum_size = Vector2(0.0, 176.0)
	detail_box.add_child(stats_section)

	var stats_body := _get_section_body(stats_section)
	stats_label = RichTextLabel.new()
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_label.custom_minimum_size = Vector2(0.0, 118.0)
	stats_label.bbcode_enabled = true
	stats_label.fit_content = false
	stats_label.scroll_active = true
	SURVIVORS_THEME.apply_rich_label_font(stats_label, 15)
	stats_body.add_child(stats_label)

	var equipment_section := _make_panel_section("装备")
	equipment_section.size_flags_vertical = Control.SIZE_FILL
	equipment_section.custom_minimum_size = Vector2(0.0, 88.0)
	detail_box.add_child(equipment_section)

	var equipment_body := _get_section_body(equipment_section)
	var equipment_hint := Label.new()
	equipment_hint.text = "右键道具可赠与其他角色"
	equipment_hint.add_theme_font_size_override("font_size", 12)
	equipment_hint.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	equipment_body.add_child(equipment_hint)

	var equipment_scroll := ScrollContainer.new()
	equipment_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_scroll.custom_minimum_size = Vector2(0.0, 42.0)
	equipment_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	equipment_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	equipment_body.add_child(equipment_scroll)

	equipment_list = HBoxContainer.new()
	equipment_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_list.add_theme_constant_override("separation", 8)
	equipment_scroll.add_child(equipment_list)

func _build_build_detail_column(content_layout: HBoxContainer) -> void:
	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 10)
	content_layout.add_child(right_column)

	var blessing_section := _make_panel_section("祝福清单")
	blessing_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blessing_section.custom_minimum_size = Vector2(0.0, 245.0)
	right_column.add_child(blessing_section)
	var blessing_body := _get_section_body(blessing_section)

	var blessing_header := HBoxContainer.new()
	blessing_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blessing_header.add_theme_constant_override("separation", 8)
	blessing_body.add_child(blessing_header)

	var owned_label := Label.new()
	owned_label.text = "已装备（生效中）"
	owned_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owned_label.add_theme_font_size_override("font_size", 14)
	owned_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	blessing_header.add_child(owned_label)

	var compose_label := Label.new()
	compose_label.text = "I x3 → II x1"
	compose_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	compose_label.add_theme_font_size_override("font_size", 14)
	compose_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	blessing_header.add_child(compose_label)

	var blessing_scroll := ScrollContainer.new()
	blessing_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blessing_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blessing_scroll.custom_minimum_size = Vector2(0.0, 172.0)
	blessing_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	blessing_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	blessing_body.add_child(blessing_scroll)

	blessing_list = VBoxContainer.new()
	blessing_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blessing_list.add_theme_constant_override("separation", 6)
	blessing_scroll.add_child(blessing_list)

	var card_section := _make_panel_section("技能与配方")
	card_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_section.custom_minimum_size = Vector2(0.0, 225.0)
	right_column.add_child(card_section)
	var card_body := _get_section_body(card_section)

	card_label = RichTextLabel.new()
	card_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_label.custom_minimum_size = Vector2(0.0, 170.0)
	card_label.bbcode_enabled = true
	card_label.fit_content = false
	card_label.scroll_active = true
	SURVIVORS_THEME.apply_rich_label_font(card_label, 15)
	card_body.add_child(card_label)

func _build_archive_footer(root_layout: VBoxContainer) -> void:
	var footer := HBoxContainer.new()
	footer.custom_minimum_size = Vector2(0.0, 22.0)
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_layout.add_child(footer)

	var hint := Label.new()
	hint.text = "长按查看提示：祝福行右键合成；装备行右键赠与；属性为当前战斗中的实时生效值。"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	footer.add_child(hint)

func show_for_player(player: Node) -> void:
	cached_player = player
	if cached_player != null and is_instance_valid(cached_player):
		viewed_role_index = clamp(int(cached_player.get("active_role_index")), 0, max(0, _get_roles().size() - 1))
	refresh()
	visible = true
	_layout_panel.call_deferred()

func hide_panel() -> void:
	visible = false
	if gift_popup != null:
		gift_popup.hide()
	if blessing_popup != null:
		blessing_popup.hide()

func _request_close() -> void:
	close_requested.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_CHARACTER_PANEL):
		close_requested.emit()
		get_viewport().set_input_as_handled()

func refresh() -> void:
	if cached_player == null or not is_instance_valid(cached_player):
		return
	var roles: Array = _get_roles()
	if roles.is_empty():
		return
	viewed_role_index = clamp(viewed_role_index, 0, roles.size() - 1)
	var role_data: Dictionary = roles[viewed_role_index]
	var role_id: String = str(role_data.get("id", "swordsman"))
	var role_name: String = str(role_data.get("name", "角色"))
	var is_active := viewed_role_index == int(cached_player.get("active_role_index"))
	role_title_label.text = "%s  Lv.%d" % [role_name, int(cached_player.get("level"))]
	role_subtitle_label.text = "%s%s" % [str(ROLE_TAGLINES.get(role_id, "构筑角色")), " · 当前站场" if is_active else " · 查看中"]
	_apply_role_texture(role_texture_rect, role_id, true)
	panel_role_pill_label.text = "%s · %s" % [role_name, "当前" if is_active else "查看"]
	panel_status_label.text = "战斗暂停中"
	_refresh_role_buttons()
	_refresh_role_cards()
	stats_label.text = _build_stats_text(role_data)
	_refresh_equipment_list(role_id)
	_refresh_blessing_list(role_id)
	card_label.text = _build_card_text()

func _make_panel_section(title: String) -> PanelContainer:
	var section := PanelContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_stylebox_override("panel", _archive_panel_style(Color(0.040, 0.055, 0.078, 0.96), Color(0.48, 0.55, 0.66, 0.86), 1, 10, 10.0, 6))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	section.add_child(box)
	var title_label := Label.new()
	title_label.text = "◇ %s" % title
	title_label.add_theme_font_size_override("font_size", 21)
	title_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	box.add_child(title_label)
	return section

func _get_section_body(section: PanelContainer) -> VBoxContainer:
	return section.get_child(0) as VBoxContainer

func _on_viewport_size_changed() -> void:
	_layout_panel.call_deferred()

func _layout_panel() -> void:
	if panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var available := Vector2(
		max(1.0, viewport_size.x - PANEL_EDGE_MARGIN.x * 2.0),
		max(1.0, viewport_size.y - PANEL_EDGE_MARGIN.y * 2.0)
	)
	var target_size := Vector2(
		clamp(viewport_size.x * PANEL_WIDTH_RATIO, min(PANEL_MIN_SIZE.x, available.x), min(PANEL_MAX_SIZE.x, available.x)),
		clamp(viewport_size.y * PANEL_HEIGHT_RATIO, min(PANEL_MIN_SIZE.y, available.y), min(PANEL_MAX_SIZE.y, available.y))
	)
	panel.size = target_size
	panel.position = Vector2(
		floor((viewport_size.x - target_size.x) * 0.5),
		max(PANEL_EDGE_MARGIN.y, floor((viewport_size.y - target_size.y) * 0.5))
	)
	panel.add_theme_stylebox_override("panel", _archive_panel_style(Color(0.014, 0.024, 0.038, 0.98), Color(0.95, 0.68, 0.23, 1.0), 2, 16, 0.0, 14))

func _refresh_role_buttons() -> void:
	if role_button_row == null:
		return
	for child in role_button_row.get_children():
		role_button_row.remove_child(child)
		child.queue_free()

func _refresh_role_cards() -> void:
	if role_nav_list == null:
		return
	for child in role_nav_list.get_children():
		role_nav_list.remove_child(child)
		child.queue_free()
	var roles: Array = _get_roles()
	var active_index: int = int(cached_player.get("active_role_index"))
	for index in range(roles.size()):
		var role: Dictionary = roles[index]
		role_nav_list.add_child(_make_role_card(role, index, active_index))

func _make_role_card(role: Dictionary, index: int, active_index: int) -> PanelContainer:
	var role_id := str(role.get("id", "swordsman"))
	var selected := index == viewed_role_index
	var active := index == active_index
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 124.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.tooltip_text = "点击查看 %s 构筑" % str(role.get("name", role_id))
	card.add_theme_stylebox_override("panel", _archive_card_style(selected, active, false))
	card.gui_input.connect(_on_role_card_gui_input.bind(index))

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var texture_rect := TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(0.0, 60.0)
	texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_apply_role_texture(texture_rect, role_id, active or selected)
	box.add_child(texture_rect)

	var name_label := Label.new()
	name_label.text = str(role.get("name", role_id))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD if selected else SURVIVORS_THEME.COLOR_TEXT)
	box.add_child(name_label)

	var status_label := Label.new()
	status_label.text = "当前" if active else "待命"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOOD if active else SURVIVORS_THEME.COLOR_TEXT_MUTED)
	box.add_child(status_label)
	return card

func _on_role_card_gui_input(event: InputEvent, role_index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_view_role(role_index)

func _view_role(role_index: int) -> void:
	viewed_role_index = role_index
	refresh()

func _refresh_equipment_list(role_id: String) -> void:
	for child in equipment_list.get_children():
		equipment_list.remove_child(child)
		child.queue_free()
	var equipment_levels: Dictionary = cached_player._get_role_equipment_levels(role_id) if cached_player.has_method("_get_role_equipment_levels") else {}
	var has_any := false
	for equipment_id in PLAYER_EQUIPMENT_FLOW.EQUIPMENT_DEFINITIONS.keys():
		var count: int = int(equipment_levels.get(str(equipment_id), 0))
		if count <= 0:
			continue
		has_any = true
		var definition: Dictionary = PLAYER_EQUIPMENT_FLOW.EQUIPMENT_DEFINITIONS.get(str(equipment_id), {})
		var button := Button.new()
		button.text = "%s\nLv.%d" % [str(definition.get("title", equipment_id)), count]
		button.tooltip_text = "%s\n当前角色持有 %d 个；右键可赠与其中 1 个。" % [
			str(definition.get("description", "")),
			count
		]
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size = Vector2(74.0, 42.0)
		button.size_flags_horizontal = Control.SIZE_FILL
		_apply_archive_button_style(button, false, count >= PLAYER_EQUIPMENT_FLOW.EQUIPMENT_MAX_LEVEL, false)
		button.gui_input.connect(_on_equipment_gui_input.bind(str(equipment_id), role_id))
		equipment_list.add_child(button)
	if not has_any:
		var empty_label := Label.new()
		empty_label.text = "暂无道具"
		empty_label.custom_minimum_size = Vector2(0.0, 42.0)
		empty_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
		equipment_list.add_child(empty_label)

func _on_equipment_gui_input(event: InputEvent, equipment_id: String, from_role_id: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_show_gift_popup(equipment_id, from_role_id)

func _show_gift_popup(equipment_id: String, from_role_id: String) -> void:
	pending_gift_equipment_id = equipment_id
	pending_gift_from_role_id = from_role_id
	gift_target_role_ids.clear()
	gift_popup.clear()
	var roles: Array = _get_roles()
	for role_data in roles:
		var target_role_id: String = str(role_data.get("id", ""))
		if target_role_id == "" or target_role_id == from_role_id:
			continue
		var target_levels: Dictionary = cached_player._get_role_equipment_levels(target_role_id) if cached_player.has_method("_get_role_equipment_levels") else {}
		var item_index: int = gift_popup.item_count
		gift_target_role_ids.append(target_role_id)
		gift_popup.add_item("赠与 %s" % str(role_data.get("name", target_role_id)))
		if int(target_levels.get(equipment_id, 0)) >= PLAYER_EQUIPMENT_FLOW.EQUIPMENT_MAX_LEVEL:
			gift_popup.set_item_disabled(item_index, true)
	if gift_popup.item_count <= 0:
		return
	gift_popup.position = Vector2i(get_viewport().get_mouse_position())
	gift_popup.popup()

func _on_gift_popup_index_pressed(index: int) -> void:
	if cached_player == null or not is_instance_valid(cached_player):
		return
	if index < 0 or index >= gift_target_role_ids.size():
		return
	var target_role_id: String = gift_target_role_ids[index]
	if cached_player.has_method("transfer_role_equipment_item"):
		cached_player.transfer_role_equipment_item(pending_gift_equipment_id, pending_gift_from_role_id, target_role_id)
	refresh()

func _refresh_blessing_list(role_id: String) -> void:
	for child in blessing_list.get_children():
		blessing_list.remove_child(child)
		child.queue_free()
	var role_levels: Dictionary = cached_player.get_role_blessing_levels(role_id) if cached_player.has_method("get_role_blessing_levels") else {}
	var skill_levels: Dictionary = cached_player.get_skill_blessing_levels() if cached_player.has_method("get_skill_blessing_levels") else {}
	var has_any := false
	for blessing_id in PLAYER_BLESSING_SYSTEM.DEFINITIONS.keys():
		var definition: Dictionary = PLAYER_BLESSING_SYSTEM.DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("binding", PLAYER_BLESSING_SYSTEM.ROLE_BOUND)) != PLAYER_BLESSING_SYSTEM.ROLE_BOUND:
			continue
		if _add_blessing_row(str(blessing_id), definition, role_levels, role_id, false):
			has_any = true
	var skill_header_added := false
	for blessing_id in PLAYER_BLESSING_SYSTEM.DEFINITIONS.keys():
		var definition: Dictionary = PLAYER_BLESSING_SYSTEM.DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("binding", PLAYER_BLESSING_SYSTEM.ROLE_BOUND)) != PLAYER_BLESSING_SYSTEM.SKILL_BOUND:
			continue
		if not _has_blessing_levels(skill_levels, str(blessing_id)):
			continue
		if not skill_header_added:
			var header := Label.new()
			header.text = "技能类祝福"
			header.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
			blessing_list.add_child(header)
			skill_header_added = true
		if _add_blessing_row(str(blessing_id), definition, skill_levels, "", true):
			has_any = true
	if not has_any:
		var empty_label := Label.new()
		empty_label.text = "暂无祝福"
		empty_label.custom_minimum_size = Vector2(0.0, 34.0)
		empty_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
		blessing_list.add_child(empty_label)

func _add_blessing_row(blessing_id: String, definition: Dictionary, levels: Dictionary, role_id: String, skill_bound: bool) -> bool:
	if not _has_blessing_levels(levels, blessing_id):
		return false
	var blessing_levels: Dictionary = levels.get(blessing_id, {})
	var tier_one_level: int = int(blessing_levels.get(1, 0))
	var tier_two_level: int = int(blessing_levels.get(2, 0))
	var can_compose := false
	if cached_player != null:
		if skill_bound and cached_player.has_method("can_compose_skill_blessing"):
			can_compose = bool(cached_player.can_compose_skill_blessing(blessing_id))
		elif not skill_bound and cached_player.has_method("can_compose_role_blessing"):
			can_compose = bool(cached_player.can_compose_role_blessing(role_id, blessing_id))
	var button := Button.new()
	button.text = "%s      I x%d      II x%d%s" % [
		str(definition.get("title", blessing_id)),
		tier_one_level,
		tier_two_level,
		"      右键合成" if can_compose else ""
	]
	button.tooltip_text = "%s\n祝福可无限重复选择；I x3 可手动合成 II x1；II 从角色 Lv.12 后独立出现，并随角色等级提高更常见。" % str(definition.get("description", ""))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, 38.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_archive_button_style(button, false, can_compose, false)
	button.gui_input.connect(_on_blessing_gui_input.bind(blessing_id, role_id, skill_bound))
	blessing_list.add_child(button)
	return true

func _has_blessing_levels(levels: Dictionary, blessing_id: String) -> bool:
	var blessing_levels: Dictionary = levels.get(blessing_id, {})
	return int(blessing_levels.get(1, 0)) > 0 or int(blessing_levels.get(2, 0)) > 0

func _on_blessing_gui_input(event: InputEvent, blessing_id: String, role_id: String, skill_bound: bool) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_show_blessing_compose_popup(blessing_id, role_id, skill_bound)

func _show_blessing_compose_popup(blessing_id: String, role_id: String, skill_bound: bool) -> void:
	pending_compose_blessing_id = blessing_id
	pending_compose_role_id = role_id
	pending_compose_is_skill_bound = skill_bound
	blessing_popup.clear()
	var can_compose := false
	if cached_player != null:
		if skill_bound and cached_player.has_method("can_compose_skill_blessing"):
			can_compose = bool(cached_player.can_compose_skill_blessing(blessing_id))
		elif not skill_bound and cached_player.has_method("can_compose_role_blessing"):
			can_compose = bool(cached_player.can_compose_role_blessing(role_id, blessing_id))
	blessing_popup.add_item("合成 II x1")
	blessing_popup.set_item_disabled(0, not can_compose)
	blessing_popup.position = Vector2i(get_viewport().get_mouse_position())
	blessing_popup.popup()

func _on_blessing_popup_index_pressed(index: int) -> void:
	if cached_player == null or not is_instance_valid(cached_player) or index != 0:
		return
	if pending_compose_is_skill_bound:
		if cached_player.has_method("compose_skill_blessing"):
			cached_player.compose_skill_blessing(pending_compose_blessing_id)
	else:
		if cached_player.has_method("compose_role_blessing"):
			cached_player.compose_role_blessing(pending_compose_role_id, pending_compose_blessing_id)
	refresh()

func _build_stats_text(role_data: Dictionary) -> String:
	var role_id: String = str(role_data.get("id", ""))
	var bonus: Dictionary = cached_player._get_role_equipment_bonus_summary(role_id) if cached_player.has_method("_get_role_equipment_bonus_summary") else {}
	var active_bonus: Dictionary = cached_player._get_role_equipment_bonus_summary(str(cached_player._get_active_role().get("id", ""))) if cached_player.has_method("_get_role_equipment_bonus_summary") else {}
	var damage: float = float(cached_player._get_role_damage(role_id)) if cached_player.has_method("_get_role_damage") else float(role_data.get("damage", 0.0))
	var base_speed: float = float(cached_player.get("speed")) - float(active_bonus.get("speed_bonus", 0.0))
	var move_speed: float = float(role_data.get("move_speed", (base_speed + float(bonus.get("speed_bonus", 0.0))) * float(role_data.get("speed_scale", 1.0))))
	if role_data.has("move_speed"):
		move_speed += float(bonus.get("speed_bonus", 0.0))
	if cached_player.has_method("_get_role_attribute_move_speed_multiplier"):
		move_speed *= float(cached_player._get_role_attribute_move_speed_multiplier(role_id))
	if not role_data.has("move_speed"):
		move_speed *= GLOBAL_UNIT_MOVE_SPEED_SCALE
	var max_health: float = float(cached_player._get_role_max_health(role_id)) if cached_player.has_method("_get_role_max_health") else float(cached_player.get("max_health")) - float(active_bonus.get("max_health_bonus", 0.0)) + float(bonus.get("max_health_bonus", 0.0))
	var current_health: float = float(cached_player._get_role_current_health(role_id)) if cached_player.has_method("_get_role_current_health") else float(cached_player.get("current_health"))
	var current_health_text := "%.0f / %.0f" % [current_health, max_health]
	var energy_gain: float = 1.0
	if cached_player.has_method("_get_role_total_ultimate_energy_gain_multiplier"):
		energy_gain = float(cached_player._get_role_total_ultimate_energy_gain_multiplier(role_id))
	var pickup_radius: float = float(cached_player.get("pickup_radius"))
	if cached_player.has_method("_get_attribute_pickup_range_bonus"):
		pickup_radius += float(cached_player._get_attribute_pickup_range_bonus())
	var attribute_dodge: float = float(cached_player._get_attribute_dodge_chance()) if cached_player.has_method("_get_attribute_dodge_chance") else 0.0
	var blessing_dodge: float = float(cached_player._get_role_blessing_stat_bonus(role_id, "dodge")) if cached_player.has_method("_get_role_blessing_stat_bonus") else 0.0
	var ultimate_dodge: float = 0.0
	if role_id == str(cached_player._get_active_role().get("id", "")) and float(cached_player.get("ultimate_haste_remaining")) > 0.0:
		ultimate_dodge = float(cached_player.get("ultimate_haste_dodge_chance"))
	var dodge_chance: float = clamp(float(bonus.get("dodge_chance", 0.0)) + blessing_dodge + attribute_dodge + ultimate_dodge, 0.0, 1.0)
	var health_regen: float = float(bonus.get("regen_per_second", 0.0))
	if cached_player.has_method("_get_attribute_health_regen_per_second"):
		health_regen += float(cached_player._get_attribute_health_regen_per_second())
	var mana_regen: float = float(cached_player._get_attribute_mana_regen_per_second()) if cached_player.has_method("_get_attribute_mana_regen_per_second") else 0.0
	var extra_damage_taken_ratio: float = 0.0
	if role_id == "gunner":
		extra_damage_taken_ratio = 0.25
	var swordsman_trait_level: float = float(cached_player._get_attribute_level("swordsman_trait")) if cached_player.has_method("_get_attribute_level") else 0.0
	var gunner_trait_level: float = float(cached_player._get_attribute_level("gunner_trait")) if cached_player.has_method("_get_attribute_level") else 0.0
	var mage_trait_level: float = float(cached_player._get_attribute_level("mage_trait")) if cached_player.has_method("_get_attribute_level") else 0.0
	var lines: Array[String] = []
	lines.append("[color=#f3d35a][b]核心属性[/b][/color]")
	lines.append("生命        [color=#ffffff]%s[/color]" % current_health_text)
	lines.append("大招能量    [color=#ffffff]%.0f / %.0f[/color]    回能 [color=#74f0a7]x%.2f +%.2f/s[/color]" % [
		float(cached_player._get_role_mana(role_id)) if cached_player.has_method("_get_role_mana") else 0.0,
		float(cached_player.get("max_mana")),
		energy_gain,
		mana_regen
	])
	lines.append("攻击力      [color=#ffffff]%.1f[/color]    普攻间隔 [color=#ffffff]%.2fs[/color]" % [
		damage,
		float(cached_player._get_effective_attack_interval(role_id)) if cached_player.has_method("_get_effective_attack_interval") else 0.0
	])
	lines.append("移动速度    [color=#ffffff]%.1f[/color]    拾取范围 [color=#ffffff]%.1f[/color]" % [move_speed, pickup_radius])
	lines.append("范围倍率    [color=#74f0a7]x%.2f[/color]    冷却倍率 [color=#74f0a7]x%.2f[/color]" % [
		float(bonus.get("skill_range_multiplier", 1.0)),
		float(bonus.get("cooldown_multiplier", 1.0))
	])
	lines.append("闪避        [color=#74f0a7]%.1f%%[/color]    回血 [color=#74f0a7]%.1f/s[/color]    承伤 [color=#ff9b74]+%.0f%%[/color]" % [
		dodge_chance * 100.0,
		health_regen,
		extra_damage_taken_ratio * 100.0
	])
	lines.append("")
	lines.append("[color=#f3d35a][b]英雄特性[/b][/color]")
	lines.append("剑士 Lv.%s    枪手 Lv.%s    法师 Lv.%s" % [
		_format_panel_attribute_level(swordsman_trait_level),
		_format_panel_attribute_level(gunner_trait_level),
		_format_panel_attribute_level(mage_trait_level)
	])
	lines.append("[color=#bfc8dc]特性影响对应英雄的核心机制与定位加成。[/color]")
	return "\n".join(lines)

func _format_panel_attribute_level(level: float) -> String:
	if cached_player != null and cached_player.has_method("_format_attribute_level"):
		return str(cached_player._format_attribute_level(level))
	if is_equal_approx(level, roundf(level)):
		return str(int(roundf(level)))
	return "%.1f" % level

func _build_card_text() -> String:
	if cached_player != null and cached_player.has_method("get_skill_graph_text"):
		var roles: Array = _get_roles()
		var role_id := ""
		if viewed_role_index >= 0 and viewed_role_index < roles.size():
			role_id = str((roles[viewed_role_index] as Dictionary).get("id", ""))
		return str(cached_player.get_skill_graph_text(role_id))
	var lines: Array[String] = []
	var skill_state: Dictionary = cached_player.get("blessing_skill_state")
	var unlocked_skills: Dictionary = skill_state.get("unlocked_skills", {})
	var skill_titles := {
		"blade_storm": "剑刃风暴",
		"infinite_reload": "无限装填",
		"surging_wave": "波涛汹涌"
	}
	for skill_id in skill_titles.keys():
		if not bool(unlocked_skills.get(skill_id, false)):
			continue
		var tier: int = 1
		if cached_player.has_method("_get_blessing_skill_tier"):
			tier = int(cached_player._get_blessing_skill_tier(str(skill_id)))
		lines.append("%s%s" % [str(skill_titles.get(skill_id, skill_id)), "II" if tier >= 2 else "I"])
	if lines.is_empty():
		lines.append("暂无祝福技能")
	return "\n".join(lines)


func _apply_role_texture(target: TextureRect, role_id: String, highlighted: bool) -> void:
	if target == null:
		return
	var texture := _load_role_texture(role_id)
	target.texture = texture
	target.material = null if texture is AtlasTexture else (_get_ui_white_key_material() if texture != null else null)
	target.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if highlighted:
		target.modulate = ROLE_PIXEL_MODULATE.get(role_id, Color.WHITE)
	else:
		target.modulate = ROLE_PIXEL_INACTIVE_MODULATE.get(role_id, Color(0.56, 0.66, 0.78, 0.80))

func _get_ui_white_key_material() -> ShaderMaterial:
	if ui_white_key_material != null:
		return ui_white_key_material
	if cached_player != null and cached_player.has_method("_create_white_key_material"):
		var player_material: ShaderMaterial = cached_player._create_white_key_material(0.93, 0.12, 0.04)
		if player_material != null:
			ui_white_key_material = player_material
			return ui_white_key_material
	var material := ShaderMaterial.new()
	material.shader = WHITE_KEY_SHADER
	material.set_shader_parameter("value_threshold", 0.93)
	material.set_shader_parameter("saturation_threshold", 0.12)
	material.set_shader_parameter("edge_softness", 0.04)
	ui_white_key_material = material
	return ui_white_key_material

func _load_role_texture(role_id: String) -> Texture2D:
	var pixel_texture := _load_role_pixel_frame(role_id)
	if pixel_texture != null:
		return pixel_texture
	if cached_player != null and cached_player.has_method("_get_cached_runtime_texture"):
		var texture: Texture2D = cached_player._get_cached_runtime_texture(str(ROLE_TEXTURE_PATHS.get(role_id, ROLE_TEXTURE_PATHS["swordsman"])))
		if texture != null:
			return texture
	return null

func _load_role_pixel_frame(role_id: String) -> Texture2D:
	if role_pixel_texture_cache.has(role_id):
		return role_pixel_texture_cache[role_id] as Texture2D
	var path := str(ROLE_PIXEL_TEXTURE_PATHS.get(role_id, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var atlas_source := load(path) as Texture2D
	if atlas_source == null:
		return null
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = atlas_source
	atlas_texture.region = ROLE_PIXEL_FRAME_RECTS.get(role_id, Rect2(Vector2.ZERO, atlas_source.get_size()))
	role_pixel_texture_cache[role_id] = atlas_texture
	return atlas_texture

func _get_roles() -> Array:
	if cached_player == null or not is_instance_valid(cached_player):
		return []
	var roles_variant: Variant = cached_player.get("roles")
	if roles_variant is Array:
		return roles_variant
	return []

extends Panel

const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const EDGE_PADDING := 14.0

var title_label: Label
var category_label: Label
var description_label: RichTextLabel
var stats_label: RichTextLabel
var status_label: Label
var note_label: Label
var body: HBoxContainer
var anchor := Rect2()
var hide_ticket := 0
var compact := false

func _ready() -> void:
	set_as_top_level(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 100
	add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(Color(0.035, 0.045, 0.070, 0.98), SURVIVORS_THEME.COLOR_BORDER_GOLD, 1, 6, 14.0))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14.0
	content.offset_top = 12.0
	content.offset_right = -14.0
	content.offset_bottom = -12.0
	title_label = _make_label(21, SURVIVORS_THEME.COLOR_TEXT_GOLD)
	content.add_child(title_label)
	category_label = _make_label(13, SURVIVORS_THEME.COLOR_TEXT_MUTED)
	content.add_child(category_label)
	body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	content.add_child(body)
	description_label = _make_rich_label()
	body.add_child(description_label)
	stats_label = _make_rich_label()
	body.add_child(stats_label)
	status_label = _make_label(15, SURVIVORS_THEME.COLOR_TEXT_GOOD)
	content.add_child(status_label)
	note_label = _make_label(13, SURVIVORS_THEME.COLOR_TEXT_MUTED)
	content.add_child(note_label)
	mouse_exited.connect(request_hide)

func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", SURVIVORS_THEME.get_reading_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_rich_label() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("normal_font", SURVIVORS_THEME.get_reading_font())
	label.add_theme_font_override("bold_font", SURVIVORS_THEME.get_reading_font())
	label.add_theme_font_size_override("normal_font_size", 15)
	label.add_theme_font_size_override("bold_font_size", 15)
	label.add_theme_constant_override("normal_line_separation", 4)
	label.add_theme_constant_override("table_h_separation", 14)
	label.add_theme_constant_override("table_v_separation", 4)
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.add_theme_color_override("default_color", SURVIVORS_THEME.COLOR_TEXT)
	return label

func show_item(item: Dictionary, cursor: Vector2, anchor_rect: Rect2 = Rect2(), detail_rect: Rect2 = Rect2()) -> void:
	hide_ticket += 1
	anchor = anchor_rect
	var card_detail := detail_rect.has_area()
	var rows: Array = item.get("effect_rows", [])
	var detail := _get_detail_text(item)
	var role_effect_text := _format_role_effects(item)
	if role_effect_text != "" and not detail.contains("对应效果"):
		detail += "\n\n" + role_effect_text
	title_label.text = str(item.get("card_title", item.get("title", item.get("name", "选项")))).trim_prefix("升级：")
	category_label.text = _get_category_text(item)
	category_label.visible = category_label.text != ""
	if card_detail:
		title_label.text += " · " + category_label.text
		category_label.visible = false
	var stats_text := _format_rows(rows)
	stats_label.visible = card_detail and not rows.is_empty()
	stats_label.text = stats_text
	description_label.text = _escape(detail)
	if not card_detail and stats_text != "":
		description_label.text += "\n\n" + stats_text
	note_label.text = str(item.get("effect_note", ""))
	note_label.visible = note_label.text != ""
	if card_detail and note_label.visible:
		detail += "\n" + note_label.text
		description_label.text = _escape(detail)
		note_label.visible = false
	update_status(str(item.get("status_text", "")), bool(item.get("status_ready", false)))
	description_label.scroll_to_line(0)
	stats_label.scroll_to_line(0)
	var viewport_size := SURVIVORS_THEME.viewport_size(self)
	compact = viewport_size.x < 900.0 or viewport_size.y < 560.0
	var width := minf(detail_rect.size.x if card_detail else 400.0, viewport_size.x - EDGE_PADDING * 2.0)
	var text_width := (width - 52.0) * 0.5 if stats_label.visible else width - 28.0
	var font := SURVIVORS_THEME.get_reading_font()
	var description_height := font.get_multiline_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, text_width, 15).y + 12.0
	var rows_height := float(rows.size() + (1 if _has_comparison(rows) else 0)) * 29.0
	var body_height := maxf(description_height, rows_height) if stats_label.visible else description_height + (rows_height + 24.0 if not rows.is_empty() else 0.0)
	var note_height := font.get_multiline_string_size(note_label.text, HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 13).y + 7.0 if note_label.visible else 0.0
	var wanted_height := (64.0 if card_detail else 105.0) + body_height + note_height + (29.0 if status_label.visible else 0.0)
	var max_height := detail_rect.size.y if card_detail else minf(440.0, viewport_size.y - EDGE_PADDING * 2.0)
	custom_minimum_size = Vector2(width, minf(maxf(145.0, wanted_height), max_height))
	size = custom_minimum_size
	visible = false
	# Containers settle their minimum size on the following frame.
	_settle_layout.call_deferred(cursor, detail_rect, hide_ticket)

func _settle_layout(cursor: Vector2, detail_rect: Rect2, ticket: int) -> void:
	await get_tree().process_frame
	if ticket != hide_ticket:
		return
	size = custom_minimum_size
	visible = true
	_reposition(cursor, detail_rect)

func update_status(text_value: String, ready: bool = false) -> void:
	status_label.text = text_value
	status_label.visible = text_value != ""
	status_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOOD if ready else Color(1.0, 0.76, 0.49))

func hide_detail() -> void:
	hide_ticket += 1
	visible = false

func request_hide() -> void:
	var ticket := hide_ticket
	await get_tree().create_timer(0.18, true).timeout
	if ticket == hide_ticket and not _is_mouse_inside_panel() and not anchor.has_point(get_viewport().get_mouse_position()):
		hide_detail()

func _get_detail_text(item: Dictionary) -> String:
	for key in ["detail_description", "exact_description", "description", "preview_description"]:
		var value := str(item.get(key, ""))
		if value != "":
			return value
	return str(item.get("effect_summary", item.get("title", "")))

func _format_role_effects(item: Dictionary) -> String:
	var parts: Array[String] = []
	for effect in item.get("role_effects", []):
		if effect is Dictionary:
			parts.append("%s｜%s" % [str(effect.get("role_name", "")), str(effect.get("title", ""))])
			for line in effect.get("lines", []):
				parts.append(str(line))
	return "\n".join(parts)

func _get_category_text(item: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["role_name", "slot_label", "card_type_label"]:
		var part := str(item.get(key, ""))
		if part != "" and not parts.has(part):
			parts.append(part)
	if str(item.get("blessing_binding", "")) == "role":
		parts.append("全队共享")
	if item.has("skill_level_next"):
		parts.append("Lv.%d → Lv.%d" % [int(item.get("skill_level", 0)), int(item["skill_level_next"])])
	elif str(item.get("unlock_skill", "")) != "":
		parts.append("未学习 → Lv.1")
	elif int(item.get("current_level", 0)) > 0:
		parts.append("Lv.%d / %d" % [int(item["current_level"]), int(item.get("max_level", 10))])
	return " · ".join(parts)

func _has_comparison(rows: Array) -> bool:
	return not rows.is_empty() and (rows[0] as Dictionary).has("before")

func _format_rows(rows: Array) -> String:
	if rows.is_empty():
		return ""
	var comparison := _has_comparison(rows)
	var result := "[table=%d]" % (3 if comparison else 2)
	if comparison:
		result += "[cell]属性[/cell][cell]当前[/cell][cell]升级后[/cell]"
	for row in rows:
		result += "[cell]%s[/cell]" % _escape(str(row.get("label", "")))
		if comparison:
			result += "[cell]%s[/cell][cell][color=#ACEDB9]%s[/color][/cell]" % [_escape(str(row.get("before", ""))), _escape(str(row.get("after", "")))]
		else:
			result += "[cell][color=#FFE08A]%s[/color][/cell]" % _escape(str(row.get("value", "")))
	return result + "[/table]"

func _escape(value: String) -> String:
	return value.replace("[", "[lb]")

func _reposition(cursor: Vector2, detail_rect: Rect2) -> void:
	var viewport_size := SURVIVORS_THEME.viewport_size(self)
	var desired := cursor + Vector2(18.0, 18.0)
	if detail_rect.has_area():
		desired = detail_rect.position
	elif anchor.has_area():
		desired = Vector2(anchor.get_center().x - size.x * 0.5, anchor.position.y - size.y - 12.0)
		if desired.y < EDGE_PADDING:
			desired.y = anchor.end.y + 12.0
	desired.x = clampf(desired.x, EDGE_PADDING, maxf(EDGE_PADDING, viewport_size.x - size.x - EDGE_PADDING))
	desired.y = clampf(desired.y, EDGE_PADDING, maxf(EDGE_PADDING, viewport_size.y - size.y - EDGE_PADDING))
	global_position = desired.floor()

func _is_mouse_inside_panel() -> bool:
	return visible and get_global_rect().has_point(get_viewport().get_mouse_position())

extends RefCounted

const TEXT_CREATE := "\u521b\u5efa\u5b58\u6863"
const TEXT_SURVIVED := "\u5df2\u575a\u6301%s"
const TEXT_DELETE_TITLE := "\u5220\u9664\u5B58\u6863"
const TEXT_DIFFICULTY_EASY := "\u7b80\u5355"
const TEXT_DIFFICULTY_NORMAL := "\u666e\u901a"
const TEXT_DIFFICULTY_HARD := "\u56f0\u96be"
const TEXT_DIFFICULTY_HELL := "\u5730\u72f1"

static func build_slot_card(slot_payload: Dictionary, slot_pressed_callback: Callable, delete_pressed_callback: Callable) -> Control:
	var slot_id: int = int(slot_payload.get("slot_id", 0))
	var has_profile: bool = bool(slot_payload.get("has_profile", false))
	var survival_time: float = float(slot_payload.get("survival_time", 0.0))
	var profile: Dictionary = slot_payload.get("profile", {})

	var root := Control.new()
	root.custom_minimum_size = Vector2(0, 180)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var card_button := Button.new()
	card_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_button.clip_contents = true
	card_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_button.custom_minimum_size = Vector2(0, 180)
	card_button.flat = false
	_apply_card_style(card_button)
	card_button.pressed.connect(slot_pressed_callback.bind(slot_id, has_profile, bool(slot_payload.get("has_run", false))))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	card_button.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var slot_title := Label.new()
	slot_title.text = "\u5b58\u6863 %d" % slot_id
	slot_title.add_theme_font_size_override("font_size", 24)
	content.add_child(slot_title)

	var detail := Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_size_override("font_size", 17)
	if has_profile:
		var difficulty_name := get_difficulty_label(str(profile.get("difficulty", "normal")))
		var survived_text := TEXT_SURVIVED % format_survival_time(survival_time)
		detail.text = "%s\n%s" % [difficulty_name, survived_text]
	else:
		detail.text = TEXT_CREATE
	content.add_child(detail)

	var action_hint := Label.new()
	action_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_hint.add_theme_font_size_override("font_size", 17)
	action_hint.text = TEXT_CREATE if not has_profile else ("\u7ee7\u7eed" if bool(slot_payload.get("has_run", false)) else "\u5f00\u59cb")
	content.add_child(action_hint)

	root.add_child(card_button)

	if has_profile:
		root.add_child(_build_delete_button(slot_id, delete_pressed_callback))

	return root

static func format_survival_time(total_seconds: float) -> String:
	var seconds_int: int = max(0, int(floor(total_seconds)))
	var minutes: int = int(seconds_int / 60)
	var seconds: int = seconds_int % 60
	return "%d\u5206%d\u79d2" % [minutes, seconds]

static func get_difficulty_label(difficulty_id: String) -> String:
	match difficulty_id:
		"easy":
			return TEXT_DIFFICULTY_EASY
		"hard":
			return TEXT_DIFFICULTY_HARD
		"hell":
			return TEXT_DIFFICULTY_HELL
		_:
			return TEXT_DIFFICULTY_NORMAL

static func _apply_card_style(card_button: Button) -> void:
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.14, 0.18, 0.26, 0.98)
	normal_style.border_color = Color(0.78, 0.84, 0.96, 0.94)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(12)
	card_button.add_theme_stylebox_override("normal", normal_style)
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.2, 0.26, 0.38, 1.0)
	hover_style.border_color = Color(0.98, 0.88, 0.5, 0.98)
	card_button.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.1, 0.14, 0.22, 1.0)
	pressed_style.border_color = Color(1.0, 0.82, 0.36, 0.98)
	card_button.add_theme_stylebox_override("pressed", pressed_style)
	var focus_style := hover_style.duplicate()
	card_button.add_theme_stylebox_override("focus", focus_style)

static func _build_delete_button(slot_id: int, delete_pressed_callback: Callable) -> Button:
	var delete_button := Button.new()
	delete_button.text = "\u00D7"
	delete_button.focus_mode = Control.FOCUS_NONE
	delete_button.tooltip_text = TEXT_DELETE_TITLE
	delete_button.mouse_filter = Control.MOUSE_FILTER_STOP
	delete_button.anchor_left = 1.0
	delete_button.anchor_top = 0.0
	delete_button.anchor_right = 1.0
	delete_button.anchor_bottom = 0.0
	delete_button.offset_left = -42.0
	delete_button.offset_top = 10.0
	delete_button.offset_right = -10.0
	delete_button.offset_bottom = 42.0
	delete_button.add_theme_font_size_override("font_size", 24)
	_apply_delete_style(delete_button)
	delete_button.pressed.connect(delete_pressed_callback.bind(slot_id))
	return delete_button

static func _apply_delete_style(delete_button: Button) -> void:
	var delete_style := StyleBoxFlat.new()
	delete_style.bg_color = Color(0.84, 0.18, 0.18, 0.96)
	delete_style.border_color = Color(1.0, 0.78, 0.78, 0.98)
	delete_style.set_border_width_all(2)
	delete_style.set_corner_radius_all(14)
	delete_button.add_theme_stylebox_override("normal", delete_style)
	var delete_hover := delete_style.duplicate()
	delete_hover.bg_color = Color(0.94, 0.24, 0.24, 1.0)
	delete_button.add_theme_stylebox_override("hover", delete_hover)
	var delete_pressed := delete_style.duplicate()
	delete_pressed.bg_color = Color(0.66, 0.12, 0.12, 1.0)
	delete_button.add_theme_stylebox_override("pressed", delete_pressed)

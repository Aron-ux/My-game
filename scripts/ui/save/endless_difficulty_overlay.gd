extends Control

signal difficulty_selected(difficulty_id: String)
signal closed

const TEXT_CHOOSE_DIFFICULTY := "\u9009\u62e9\u96be\u5ea6"
const TEXT_CLOSE := "\u5173\u95ed"
const TEXT_DIFFICULTY_EASY := "\u7b80\u5355"
const TEXT_DIFFICULTY_NORMAL := "\u666e\u901a"
const TEXT_DIFFICULTY_HARD := "\u56f0\u96be"
const TEXT_DIFFICULTY_HELL := "\u5730\u72f1"
const TEXT_NOT_OPEN := "\u672a\u5f00\u653e"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_overlay()
	visible = false

func open() -> void:
	visible = true

func close_overlay() -> void:
	visible = false
	closed.emit()

func _build_overlay() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.58)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 420)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)

	var title := Label.new()
	title.text = TEXT_CHOOSE_DIFFICULTY
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = TEXT_CLOSE
	close_button.custom_minimum_size = Vector2(100, 40)
	close_button.pressed.connect(close_overlay)
	header.add_child(close_button)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 18)
	content.add_child(cards)

	cards.add_child(_build_difficulty_card(TEXT_DIFFICULTY_EASY, "easy", false))
	cards.add_child(_build_difficulty_card(TEXT_DIFFICULTY_NORMAL, "normal", true))
	cards.add_child(_build_difficulty_card(TEXT_DIFFICULTY_HARD, "hard", false))
	cards.add_child(_build_difficulty_card(TEXT_DIFFICULTY_HELL, "hell", false))

func _build_difficulty_card(title_text: String, difficulty_id: String, available: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 260)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	content.add_child(title)

	var state := Label.new()
	state.text = "" if available else TEXT_NOT_OPEN
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.add_theme_font_size_override("font_size", 18)
	content.add_child(state)

	var choose_button := Button.new()
	choose_button.text = "\u9009\u62e9" if available else TEXT_NOT_OPEN
	choose_button.custom_minimum_size = Vector2(0, 44)
	choose_button.disabled = not available
	choose_button.pressed.connect(func(): difficulty_selected.emit(difficulty_id))
	content.add_child(choose_button)

	return panel

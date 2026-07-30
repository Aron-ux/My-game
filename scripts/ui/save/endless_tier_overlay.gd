extends Control

signal tier_selected(tier: int, continue_existing: bool)
signal closed

const SURVIVORS_MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

var modal: Control
var progress_label: Label
var tier_label: Label
var description_label: Label
var minus_button: Button
var plus_button: Button
var start_button: Button
var selected_tier := 1
var highest_cleared_tier := 0
var run_tier := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_overlay()
	visible = false


func open(profile: Dictionary, run_data: Dictionary = {}) -> void:
	highest_cleared_tier = max(0, int(profile.get("highest_cleared_tier", 0)))
	run_tier = int(run_data.get("run_tier", 0))
	selected_tier = run_tier if run_tier > 0 else clampi(
		int(profile.get("selected_tier", 1)),
		1,
		highest_cleared_tier + 1
	)
	_refresh()
	visible = true
	if modal != null and modal.has_method("apply_layout"):
		modal.apply_layout()
	if start_button != null:
		start_button.grab_focus()


func close_overlay() -> void:
	visible = false
	closed.emit()


func _build_overlay() -> void:
	modal = SURVIVORS_MODAL.new()
	modal.configure(Vector2(620.0, 380.0), 0.52, 0.54, Vector2(340.0, 280.0))
	modal.set_title("选择无尽 N 层")
	modal.set_hint("每层固定 12 分钟；击败最终 Boss 后结算并返回营地。")
	add_child(modal)

	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 18)
	modal.set_body(body)

	progress_label = _make_label("", 18, SURVIVORS_THEME.COLOR_TEXT_MUTED)
	body.add_child(progress_label)

	var selector := HBoxContainer.new()
	selector.alignment = BoxContainer.ALIGNMENT_CENTER
	selector.add_theme_constant_override("separation", 18)
	body.add_child(selector)

	minus_button = _make_button("−")
	minus_button.pressed.connect(_change_tier.bind(-1))
	selector.add_child(minus_button)

	tier_label = _make_label("N1", 42, SURVIVORS_THEME.COLOR_TEXT_GOLD)
	tier_label.custom_minimum_size = Vector2(180.0, 64.0)
	selector.add_child(tier_label)

	plus_button = _make_button("+")
	plus_button.pressed.connect(_change_tier.bind(1))
	selector.add_child(plus_button)

	description_label = _make_label("", 17, SURVIVORS_THEME.COLOR_TEXT)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(description_label)

	modal.clear_footer()
	modal.add_footer_button("关闭", Callable(self, "close_overlay"), "normal")
	start_button = modal.add_footer_button("开始挑战", Callable(self, "_confirm"), "primary")


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(64.0, 52.0)
	button.add_theme_font_size_override("font_size", 28)
	SURVIVORS_THEME.apply_button_style(button)
	return button


func _change_tier(delta: int) -> void:
	if run_tier > 0:
		return
	selected_tier = clampi(selected_tier + delta, 1, highest_cleared_tier + 1)
	_refresh()


func _refresh() -> void:
	var has_run := run_tier > 0
	var cleared_text := "尚未通关" if highest_cleared_tier == 0 else "最高已通关：N%d" % highest_cleared_tier
	progress_label.text = "%s    可挑战至：N%d" % [cleared_text, highest_cleared_tier + 1]
	tier_label.text = "N%d" % selected_tier
	minus_button.disabled = has_run or selected_tier <= 1
	plus_button.disabled = has_run or selected_tier >= highest_cleared_tier + 1
	start_button.text = "继续 N%d" % run_tier if has_run else "开始 N%d" % selected_tier
	description_label.text = (
		"该层已有进行中的战局，只能继续；主动结束或失败后可重新选层。"
		if has_run
		else "本次从 Lv.1 开始，局内等级、技能、天赋、祝福与临时装备在结算后重置。"
	)


func _confirm() -> void:
	tier_selected.emit(selected_tier, run_tier > 0)

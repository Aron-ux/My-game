extends CanvasLayer

const BGM_PLAYER_SCRIPT := preload("res://scripts/bgm_player.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const SURVIVORS_MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

signal resume_requested
signal restart_requested
signal main_menu_requested
signal end_run_requested
signal hud_layout_changed(layout_key: String)

var modal: Control
var volume_slider: HSlider
var volume_value_label: Label
var mute_checkbox: CheckBox
var performance_trace_checkbox: CheckBox
var hud_layout_option: OptionButton
var end_run_button: Button
var end_run_confirm_dialog: ConfirmationDialog
var endless_mode_enabled: bool = false

func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	modal = SURVIVORS_MODAL.new()
	modal.configure(Vector2(440.0, 570.0), 0.36, 0.74, Vector2(280.0, 320.0))
	modal.set_title("暂停")
	modal.set_hint("")
	add_child(modal)
	_build_content()
	hide_ui()

func show_ui() -> void:
	_refresh_audio_controls()
	visible = true
	if modal != null and modal.has_method("apply_layout"):
		modal.apply_layout()

func hide_ui() -> void:
	visible = false
	if end_run_confirm_dialog != null:
		end_run_confirm_dialog.hide()

func set_endless_mode_enabled(enabled: bool) -> void:
	endless_mode_enabled = enabled
	if end_run_button != null:
		end_run_button.visible = enabled

func _build_content() -> void:
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	modal.set_body(content)

	content.add_child(_make_action_button("继续游戏", Callable(self, "_on_resume_pressed"), "primary"))
	content.add_child(_make_action_button("重新开始", Callable(self, "_on_restart_pressed")))
	end_run_button = _make_action_button("结束本轮并返回营地", Callable(self, "_on_end_run_pressed"))
	end_run_button.visible = endless_mode_enabled
	content.add_child(end_run_button)
	content.add_child(_make_action_button("返回主菜单", Callable(self, "_on_main_menu_pressed")))

	var volume_label := Label.new()
	volume_label.text = "背景音乐音量"
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SURVIVORS_THEME.apply_label_font(volume_label, 16, SURVIVORS_THEME.COLOR_TEXT_MUTED)
	content.add_child(volume_label)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.custom_minimum_size = Vector2(0.0, 32.0)
	volume_slider.value_changed.connect(_on_volume_changed)
	content.add_child(volume_slider)

	volume_value_label = Label.new()
	volume_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SURVIVORS_THEME.apply_label_font(volume_value_label, 15, SURVIVORS_THEME.COLOR_TEXT)
	content.add_child(volume_value_label)

	mute_checkbox = CheckBox.new()
	mute_checkbox.text = "静音"
	mute_checkbox.toggled.connect(_on_mute_toggled)
	content.add_child(mute_checkbox)

	performance_trace_checkbox = CheckBox.new()
	performance_trace_checkbox.text = "记录性能日志"
	performance_trace_checkbox.toggled.connect(_on_performance_trace_toggled)
	content.add_child(performance_trace_checkbox)

	var hud_layout_label := Label.new()
	hud_layout_label.text = "HUD 布局"
	hud_layout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SURVIVORS_THEME.apply_label_font(hud_layout_label, 16, SURVIVORS_THEME.COLOR_TEXT_MUTED)
	content.add_child(hud_layout_label)

	hud_layout_option = OptionButton.new()
	hud_layout_option.custom_minimum_size = Vector2(0.0, 38.0)
	hud_layout_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for layout_key in GAME_SETTINGS.get_hud_layout_options():
		hud_layout_option.add_item(GAME_SETTINGS.get_hud_layout_label(layout_key))
		hud_layout_option.set_item_metadata(hud_layout_option.item_count - 1, layout_key)
	hud_layout_option.item_selected.connect(_on_hud_layout_selected)
	content.add_child(hud_layout_option)

func _make_action_button(text_value: String, callback: Callable, kind: String = "normal") -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	SURVIVORS_THEME.apply_button_style(button, kind)
	button.pressed.connect(callback)
	return button

func _refresh_audio_controls() -> void:
	if volume_slider != null:
		volume_slider.value = BGM_PLAYER_SCRIPT.load_music_volume()
	if volume_value_label != null:
		volume_value_label.text = "%d%%" % int(round(BGM_PLAYER_SCRIPT.load_music_volume() * 100.0))
	if mute_checkbox != null:
		mute_checkbox.set_pressed_no_signal(BGM_PLAYER_SCRIPT.load_music_muted())
	if performance_trace_checkbox != null:
		performance_trace_checkbox.set_pressed_no_signal(GAME_SETTINGS.load_performance_trace_enabled())
	if hud_layout_option != null:
		_select_option_by_metadata(hud_layout_option, GAME_SETTINGS.load_hud_layout())

func _apply_saved_music_volume() -> void:
	var parent_scene := get_parent()
	if parent_scene == null:
		return

	var game_bgm = parent_scene.get_node_or_null("GameBGM")
	if game_bgm != null and game_bgm.has_method("apply_saved_volume"):
		game_bgm.apply_saved_volume()

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_restart_pressed() -> void:
	restart_requested.emit()

func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()

func _on_end_run_pressed() -> void:
	if not endless_mode_enabled:
		return
	if end_run_confirm_dialog == null:
		end_run_confirm_dialog = ConfirmationDialog.new()
		end_run_confirm_dialog.title = "结束本轮"
		end_run_confirm_dialog.dialog_text = "当前战斗进度会被清除，并返回无尽营地。确定结束本轮吗？"
		end_run_confirm_dialog.ok_button_text = "结束并返营"
		end_run_confirm_dialog.cancel_button_text = "继续战斗"
		end_run_confirm_dialog.confirmed.connect(func(): end_run_requested.emit())
		add_child(end_run_confirm_dialog)
	end_run_confirm_dialog.popup_centered(Vector2i(440, 190))

func _on_volume_changed(value: float) -> void:
	BGM_PLAYER_SCRIPT.save_music_volume(value)
	volume_value_label.text = "%d%%" % int(round(value * 100.0))
	_apply_saved_music_volume()

func _on_mute_toggled(toggled_on: bool) -> void:
	BGM_PLAYER_SCRIPT.save_music_muted(toggled_on)
	_apply_saved_music_volume()

func _on_performance_trace_toggled(toggled_on: bool) -> void:
	GAME_SETTINGS.save_performance_trace_enabled(toggled_on)

func _select_option_by_metadata(option: OptionButton, metadata: String) -> void:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == metadata:
			option.select(index)
			return

func _on_hud_layout_selected(index: int) -> void:
	if hud_layout_option == null:
		return
	GAME_SETTINGS.save_hud_layout(str(hud_layout_option.get_item_metadata(index)))
	var saved_layout := GAME_SETTINGS.load_hud_layout()
	_select_option_by_metadata(hud_layout_option, saved_layout)
	hud_layout_changed.emit(saved_layout)

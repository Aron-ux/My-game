extends Control

const GAME_SCENE_PATH := "res://scenes/main.tscn"
const SAVE_SELECT_SCENE_PATH := "res://scenes/save_select.tscn"
const BACKGROUND_TEXTURE := preload("res://assets/demo.jpg")
const BGM_PLAYER_SCRIPT := preload("res://scripts/bgm_player.gd")
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")

var background: TextureRect
var continue_button: Button
var settings_overlay: CenterContainer
var volume_slider: HSlider
var volume_value_label: Label
var mute_checkbox: CheckBox

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = BACKGROUND_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var button_margin := MarginContainer.new()
	button_margin.anchor_left = 0.0
	button_margin.anchor_top = 1.0
	button_margin.anchor_right = 0.0
	button_margin.anchor_bottom = 1.0
	button_margin.offset_left = 24.0
	button_margin.offset_top = -304.0
	button_margin.offset_right = 264.0
	button_margin.offset_bottom = -24.0
	add_child(button_margin)

	var button_column := VBoxContainer.new()
	button_column.alignment = BoxContainer.ALIGNMENT_END
	button_column.add_theme_constant_override("separation", 12)
	button_margin.add_child(button_column)

	continue_button = Button.new()
	continue_button.text = "继续游戏"
	continue_button.custom_minimum_size = Vector2(220, 56)
	continue_button.add_theme_font_size_override("font_size", 24)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.visible = SAVE_MANAGER.has_continue_target()
	button_column.add_child(continue_button)

	var start_button := Button.new()
	start_button.text = "主线模式"
	start_button.custom_minimum_size = Vector2(220, 56)
	start_button.add_theme_font_size_override("font_size", 24)
	start_button.pressed.connect(_on_start_pressed)
	button_column.add_child(start_button)

	var challenge_button := Button.new()
	challenge_button.text = "挑战模式"
	challenge_button.custom_minimum_size = Vector2(220, 56)
	challenge_button.add_theme_font_size_override("font_size", 24)
	challenge_button.disabled = true
	button_column.add_child(challenge_button)

	var endless_button := Button.new()
	endless_button.text = "无尽模式"
	endless_button.custom_minimum_size = Vector2(220, 56)
	endless_button.add_theme_font_size_override("font_size", 24)
	endless_button.disabled = true
	button_column.add_child(endless_button)

	var developer_button := Button.new()
	developer_button.text = "进入开发者模式"
	developer_button.custom_minimum_size = Vector2(220, 56)
	developer_button.add_theme_font_size_override("font_size", 24)
	developer_button.pressed.connect(_on_developer_mode_pressed)
	button_column.add_child(developer_button)

	var settings_button := Button.new()
	settings_button.text = "设置"
	settings_button.custom_minimum_size = Vector2(220, 56)
	settings_button.add_theme_font_size_override("font_size", 24)
	settings_button.pressed.connect(_on_settings_pressed)
	button_column.add_child(settings_button)

	var quit_button := Button.new()
	quit_button.text = "退出"
	quit_button.custom_minimum_size = Vector2(220, 56)
	quit_button.add_theme_font_size_override("font_size", 24)
	quit_button.pressed.connect(_on_quit_pressed)
	button_column.add_child(quit_button)

	_build_settings_panel()
	_fit_to_viewport()
	_refresh_audio_controls()
	_apply_saved_music_volume()
	_start_menu_bgm()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and background != null:
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _fit_to_viewport() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if background != null:
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_settings_panel() -> void:
	settings_overlay = CenterContainer.new()
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(settings_overlay)

	var settings_panel := PanelContainer.new()
	settings_panel.custom_minimum_size = Vector2(520, 280)
	settings_overlay.add_child(settings_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	settings_panel.add_child(content)

	var title_label := Label.new()
	title_label.text = "设置"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	content.add_child(title_label)

	var volume_label := Label.new()
	volume_label.text = "背景音乐音量"
	content.add_child(volume_label)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.value_changed.connect(_on_volume_changed)
	content.add_child(volume_slider)

	volume_value_label = Label.new()
	volume_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(volume_value_label)

	mute_checkbox = CheckBox.new()
	mute_checkbox.text = ""
	mute_checkbox.toggled.connect(_on_mute_toggled)
	content.add_child(mute_checkbox)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(180, 44)
	close_button.pressed.connect(_on_close_settings_pressed)
	content.add_child(close_button)

	settings_overlay.visible = false

func _refresh_audio_controls() -> void:
	if continue_button != null:
		continue_button.visible = SAVE_MANAGER.has_continue_target()
	if volume_slider != null:
		volume_slider.value = BGM_PLAYER_SCRIPT.load_music_volume()
	if volume_value_label != null:
		volume_value_label.text = "%d%%" % int(round(BGM_PLAYER_SCRIPT.load_music_volume() * 100.0))
	if mute_checkbox != null:
		mute_checkbox.button_pressed = BGM_PLAYER_SCRIPT.load_music_muted()

func _apply_saved_music_volume() -> void:
	var menu_bgm = get_node_or_null("MenuBGM")
	if menu_bgm != null and menu_bgm.has_method("apply_saved_volume"):
		menu_bgm.apply_saved_volume()

func _start_menu_bgm() -> void:
	var menu_bgm = get_node_or_null("MenuBGM")
	if menu_bgm != null and menu_bgm.has_method("start_music"):
		menu_bgm.start_music()

func _on_continue_pressed() -> void:
	DEVELOPER_MODE.deactivate()
	var target_scene := SAVE_MANAGER.request_continue_to_last_target()
	if target_scene == "":
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(target_scene)

func _on_start_pressed() -> void:
	DEVELOPER_MODE.deactivate()
	get_tree().paused = false
	get_tree().change_scene_to_file(SAVE_SELECT_SCENE_PATH)

func _on_developer_mode_pressed() -> void:
	DEVELOPER_MODE.activate()
	SAVE_MANAGER.clear_save()
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_settings_pressed() -> void:
	if settings_overlay != null:
		_refresh_audio_controls()
		settings_overlay.visible = true

func _on_close_settings_pressed() -> void:
	if settings_overlay != null:
		settings_overlay.visible = false

func _on_volume_changed(value: float) -> void:
	BGM_PLAYER_SCRIPT.save_music_volume(value)
	volume_value_label.text = "%d%%" % int(round(value * 100.0))
	_apply_saved_music_volume()

func _on_mute_toggled(toggled_on: bool) -> void:
	BGM_PLAYER_SCRIPT.save_music_muted(toggled_on)
	_apply_saved_music_volume()

func _on_quit_pressed() -> void:
	get_tree().quit()

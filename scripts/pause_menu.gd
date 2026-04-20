extends CanvasLayer

const BGM_PLAYER_SCRIPT := preload("res://scripts/bgm_player.gd")

signal resume_requested
signal restart_requested
signal main_menu_requested

var panel: PanelContainer
var volume_slider: HSlider
var volume_value_label: Label
var mute_checkbox: CheckBox

func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.72)
	root.add_child(dimmer)

	var center_container := CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center_container)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 420)
	center_container.add_child(panel)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var title_label := Label.new()
	title_label.text = "暂停"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	content.add_child(title_label)

	var resume_button := Button.new()
	resume_button.text = "继续游戏"
	resume_button.custom_minimum_size = Vector2(220, 50)
	resume_button.add_theme_font_size_override("font_size", 22)
	resume_button.pressed.connect(_on_resume_pressed)
	content.add_child(resume_button)

	var restart_button := Button.new()
	restart_button.text = "重新开始"
	restart_button.custom_minimum_size = Vector2(220, 50)
	restart_button.add_theme_font_size_override("font_size", 22)
	restart_button.pressed.connect(_on_restart_pressed)
	content.add_child(restart_button)

	var main_menu_button := Button.new()
	main_menu_button.text = "返回主菜单"
	main_menu_button.custom_minimum_size = Vector2(220, 50)
	main_menu_button.add_theme_font_size_override("font_size", 22)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	content.add_child(main_menu_button)

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

	hide_ui()

func show_ui() -> void:
	_refresh_audio_controls()
	visible = true

func hide_ui() -> void:
	visible = false

func _refresh_audio_controls() -> void:
	if volume_slider != null:
		volume_slider.value = BGM_PLAYER_SCRIPT.load_music_volume()
	if volume_value_label != null:
		volume_value_label.text = "%d%%" % int(round(BGM_PLAYER_SCRIPT.load_music_volume() * 100.0))
	if mute_checkbox != null:
		mute_checkbox.button_pressed = BGM_PLAYER_SCRIPT.load_music_muted()

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

func _on_volume_changed(value: float) -> void:
	BGM_PLAYER_SCRIPT.save_music_volume(value)
	volume_value_label.text = "%d%%" % int(round(value * 100.0))
	_apply_saved_music_volume()

func _on_mute_toggled(toggled_on: bool) -> void:
	BGM_PLAYER_SCRIPT.save_music_muted(toggled_on)
	_apply_saved_music_volume()

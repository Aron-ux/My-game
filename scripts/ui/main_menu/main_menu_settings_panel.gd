extends CenterContainer

const BGM_PLAYER_SCRIPT := preload("res://scripts/bgm_player.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")

const TEXT_SETTINGS := "\u8bbe\u7f6e"
const TEXT_VOLUME_SETTINGS := "\u97f3\u91cf\u8bbe\u7f6e"
const TEXT_KEY_SETTINGS := "\u6309\u952e\u8bbe\u7f6e"
const TEXT_MUSIC_VOLUME := "\u80cc\u666f\u97f3\u4e50\u97f3\u91cf"
const TEXT_CLOSE := "\u5173\u95ed"
const TEXT_RESET_DEFAULTS := "\u6062\u590d\u9ed8\u8ba4\u952e\u4f4d"
const TEXT_KEY_HELP := "\u70b9\u51fb\u53f3\u4fa7\u6309\u94ae\u540e\uff0c\u6309\u4e0b\u65b0\u6309\u952e\u3002"
const TEXT_WAITING_KEY := "\u6309\u4e0b\u65b0\u6309\u952e\uff0cESC \u53d6\u6d88"
const TEXT_KEY_CANCELLED := "\u5df2\u53d6\u6d88\u952e\u4f4d\u8bbe\u7f6e"
const TEXT_KEY_SAVED := "\u952e\u4f4d\u5df2\u4fdd\u5b58"

const KEYBIND_LABELS := {
	"move_up": "\u4e0a",
	"move_down": "\u4e0b",
	"move_left": "\u5de6",
	"move_right": "\u53f3",
	"ultimate": "\u5927\u62db",
	"switch_prev": "\u5207\u6362\u4e0a\u4e00\u4e2a\u4eba",
	"switch_next": "\u5207\u6362\u4e0b\u4e00\u4e2a\u4eba",
	"toggle_attack_mode": "\u5207\u6362\u653b\u51fb\u65b9\u5f0f",
	"character_panel": "\u89d2\u8272\u9762\u677f"
}

var settings_title_label: Label
var volume_page: VBoxContainer
var keybind_page: VBoxContainer
var volume_slider: HSlider
var volume_value_label: Label
var mute_checkbox: CheckBox
var keybind_buttons: Dictionary = {}
var keybind_status_label: Label
var waiting_for_key_action: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_panel()
	visible = false
	_show_volume_settings()
	_refresh_audio_controls()
	_refresh_keybind_controls()

func open() -> void:
	waiting_for_key_action = ""
	_refresh_audio_controls()
	_refresh_keybind_controls()
	_show_volume_settings()
	visible = true

func close_panel() -> void:
	waiting_for_key_action = ""
	visible = false

func handle_unhandled_input(event: InputEvent) -> bool:
	if waiting_for_key_action == "":
		return false
	if event is not InputEventKey:
		return false

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false

	if key_event.keycode == KEY_ESCAPE:
		waiting_for_key_action = ""
		if keybind_status_label != null:
			keybind_status_label.text = TEXT_KEY_CANCELLED
		_refresh_keybind_controls()
		get_viewport().set_input_as_handled()
		return true

	_save_keybind(waiting_for_key_action, key_event.keycode)
	waiting_for_key_action = ""
	if keybind_status_label != null:
		keybind_status_label.text = TEXT_KEY_SAVED
	_refresh_keybind_controls()
	get_viewport().set_input_as_handled()
	return true

func _build_panel() -> void:
	var settings_panel := PanelContainer.new()
	settings_panel.custom_minimum_size = Vector2(780, 520)
	add_child(settings_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	settings_panel.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)

	settings_title_label = Label.new()
	settings_title_label.text = TEXT_SETTINGS
	settings_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title_label.add_theme_font_size_override("font_size", 30)
	header.add_child(settings_title_label)

	var close_button := Button.new()
	close_button.text = TEXT_CLOSE
	close_button.custom_minimum_size = Vector2(108, 40)
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	content.add_child(body)

	var category_column := VBoxContainer.new()
	category_column.custom_minimum_size = Vector2(190, 360)
	category_column.add_theme_constant_override("separation", 14)
	body.add_child(category_column)

	var volume_category_button := Button.new()
	volume_category_button.text = TEXT_VOLUME_SETTINGS
	volume_category_button.custom_minimum_size = Vector2(170, 52)
	volume_category_button.add_theme_font_size_override("font_size", 20)
	volume_category_button.pressed.connect(_show_volume_settings)
	category_column.add_child(volume_category_button)

	var keybind_category_button := Button.new()
	keybind_category_button.text = TEXT_KEY_SETTINGS
	keybind_category_button.custom_minimum_size = Vector2(170, 52)
	keybind_category_button.add_theme_font_size_override("font_size", 20)
	keybind_category_button.pressed.connect(_show_keybind_settings)
	category_column.add_child(keybind_category_button)

	var page_root := Control.new()
	page_root.custom_minimum_size = Vector2(520, 360)
	body.add_child(page_root)

	volume_page = _build_volume_page()
	volume_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_root.add_child(volume_page)

	keybind_page = _build_keybind_page()
	keybind_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_root.add_child(keybind_page)

func _build_volume_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)

	var title := Label.new()
	title.text = TEXT_VOLUME_SETTINGS
	title.add_theme_font_size_override("font_size", 24)
	page.add_child(title)

	var volume_label := Label.new()
	volume_label.text = TEXT_MUSIC_VOLUME
	volume_label.add_theme_font_size_override("font_size", 18)
	page.add_child(volume_label)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.custom_minimum_size = Vector2(420, 36)
	volume_slider.value_changed.connect(_on_volume_changed)
	page.add_child(volume_slider)

	volume_value_label = Label.new()
	volume_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	volume_value_label.add_theme_font_size_override("font_size", 18)
	page.add_child(volume_value_label)

	mute_checkbox = CheckBox.new()
	mute_checkbox.text = ""
	mute_checkbox.toggled.connect(_on_mute_toggled)
	page.add_child(mute_checkbox)

	return page

func _build_keybind_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = TEXT_KEY_SETTINGS
	title.add_theme_font_size_override("font_size", 24)
	page.add_child(title)

	var help_label := Label.new()
	help_label.text = TEXT_KEY_HELP
	help_label.add_theme_font_size_override("font_size", 15)
	page.add_child(help_label)

	for action_id in GAME_SETTINGS.ACTION_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		page.add_child(row)

		var label := Label.new()
		label.text = str(KEYBIND_LABELS.get(action_id, action_id))
		label.custom_minimum_size = Vector2(210, 34)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 17)
		row.add_child(label)

		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 34)
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_on_keybind_button_pressed.bind(action_id))
		row.add_child(button)
		keybind_buttons[action_id] = button

	var reset_button := Button.new()
	reset_button.text = TEXT_RESET_DEFAULTS
	reset_button.custom_minimum_size = Vector2(180, 38)
	reset_button.pressed.connect(_on_reset_keybinds_pressed)
	page.add_child(reset_button)

	keybind_status_label = Label.new()
	keybind_status_label.text = ""
	keybind_status_label.add_theme_font_size_override("font_size", 15)
	page.add_child(keybind_status_label)

	return page

func _show_volume_settings() -> void:
	if settings_title_label != null:
		settings_title_label.text = TEXT_VOLUME_SETTINGS
	if volume_page != null:
		volume_page.visible = true
	if keybind_page != null:
		keybind_page.visible = false

func _show_keybind_settings() -> void:
	if settings_title_label != null:
		settings_title_label.text = TEXT_KEY_SETTINGS
	if volume_page != null:
		volume_page.visible = false
	if keybind_page != null:
		keybind_page.visible = true
	_refresh_keybind_controls()

func _refresh_audio_controls() -> void:
	if volume_slider != null:
		volume_slider.set_value_no_signal(BGM_PLAYER_SCRIPT.load_music_volume())
	if volume_value_label != null:
		volume_value_label.text = "%d%%" % int(round(BGM_PLAYER_SCRIPT.load_music_volume() * 100.0))
	if mute_checkbox != null:
		mute_checkbox.set_pressed_no_signal(BGM_PLAYER_SCRIPT.load_music_muted())

func _refresh_keybind_controls() -> void:
	for action_id in GAME_SETTINGS.ACTION_ORDER:
		var button := keybind_buttons.get(action_id) as Button
		if button == null:
			continue
		if waiting_for_key_action == action_id:
			button.text = TEXT_WAITING_KEY
		else:
			button.text = GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(action_id))

func _save_keybind(action_id: String, new_keycode: int) -> void:
	var key_map: Dictionary = GAME_SETTINGS.load_key_map()
	var old_keycode: int = int(key_map.get(action_id, GAME_SETTINGS.DEFAULT_KEYS.get(action_id, KEY_NONE)))
	for other_action in GAME_SETTINGS.ACTION_ORDER:
		if other_action == action_id:
			continue
		if int(key_map.get(other_action, KEY_NONE)) == new_keycode:
			key_map[other_action] = old_keycode
	key_map[action_id] = new_keycode
	GAME_SETTINGS.save_key_map(key_map)

func _apply_saved_music_volume() -> void:
	var menu_bgm = get_node_or_null("../MenuBGM")
	if menu_bgm != null and menu_bgm.has_method("apply_saved_volume"):
		menu_bgm.apply_saved_volume()

func _on_keybind_button_pressed(action_id: String) -> void:
	waiting_for_key_action = action_id
	if keybind_status_label != null:
		keybind_status_label.text = TEXT_WAITING_KEY
	_refresh_keybind_controls()

func _on_reset_keybinds_pressed() -> void:
	waiting_for_key_action = ""
	GAME_SETTINGS.reset_default_keybinds()
	if keybind_status_label != null:
		keybind_status_label.text = TEXT_KEY_SAVED
	_refresh_keybind_controls()

func _on_volume_changed(value: float) -> void:
	BGM_PLAYER_SCRIPT.save_music_volume(value)
	if volume_value_label != null:
		volume_value_label.text = "%d%%" % int(round(value * 100.0))
	_apply_saved_music_volume()

func _on_mute_toggled(toggled_on: bool) -> void:
	BGM_PLAYER_SCRIPT.save_music_muted(toggled_on)
	_apply_saved_music_volume()

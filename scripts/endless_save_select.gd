extends Control

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const GAME_SCENE_PATH := "res://scenes/main.tscn"
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const ENDLESS_DIFFICULTY_OVERLAY := preload("res://scripts/ui/save/endless_difficulty_overlay.gd")
const ENDLESS_SLOT_CARD_FACTORY := preload("res://scripts/ui/save/endless_slot_card_factory.gd")

const TEXT_TITLE := "\u65e0\u5c3d\u6a21\u5f0f"
const TEXT_SUBTITLE := "\u9009\u62e9\u4e00\u4e2a\u5b58\u6863\u4f4d\u8fdb\u5165\u65e0\u5c3d\u6218\u6597"
const TEXT_BACK := "\u8fd4\u56de\u4e3b\u83dc\u5355"
const TEXT_CLOSE := "\u5173\u95ed"
const TEXT_DELETE_CONFIRM := "\u786E\u5B9A\u8981\u5220\u9664\u8FD9\u4E2A\u5B58\u6863\u5417"
const TEXT_DELETE_TITLE := "\u5220\u9664\u5B58\u6863"

var difficulty_overlay: Control
var delete_confirm_dialog: ConfirmationDialog
var pending_slot_id: int = -1
var pending_delete_slot_id: int = -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	delete_confirm_dialog = null

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.05, 0.07, 0.12, 1.0)
	add_child(background)

	var title := Label.new()
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 18.0
	title.offset_bottom = 62.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text = TEXT_TITLE
	title.add_theme_font_size_override("font_size", 34)
	add_child(title)

	var subtitle := Label.new()
	subtitle.anchor_left = 0.0
	subtitle.anchor_right = 1.0
	subtitle.offset_top = 62.0
	subtitle.offset_bottom = 94.0
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.text = TEXT_SUBTITLE
	subtitle.add_theme_font_size_override("font_size", 18)
	add_child(subtitle)

	var back_button := Button.new()
	back_button.text = TEXT_BACK
	back_button.anchor_left = 0.0
	back_button.anchor_top = 0.0
	back_button.offset_left = 28.0
	back_button.offset_top = 24.0
	back_button.offset_right = 188.0
	back_button.offset_bottom = 68.0
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 36)
	root_margin.add_theme_constant_override("margin_top", 110)
	root_margin.add_theme_constant_override("margin_right", 36)
	root_margin.add_theme_constant_override("margin_bottom", 32)
	add_child(root_margin)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 26)
	root_margin.add_child(grid)

	for slot_payload in SAVE_MANAGER.list_endless_slots():
		grid.add_child(ENDLESS_SLOT_CARD_FACTORY.build_slot_card(
			slot_payload,
			Callable(self, "_on_slot_pressed"),
			Callable(self, "_on_delete_pressed")
		))

	difficulty_overlay = ENDLESS_DIFFICULTY_OVERLAY.new()
	difficulty_overlay.difficulty_selected.connect(_on_difficulty_selected)
	difficulty_overlay.closed.connect(_on_difficulty_overlay_closed)
	add_child(difficulty_overlay)

func _ensure_delete_confirm_dialog() -> void:
	if delete_confirm_dialog != null and is_instance_valid(delete_confirm_dialog):
		return
	delete_confirm_dialog = ConfirmationDialog.new()
	delete_confirm_dialog.title = TEXT_DELETE_TITLE
	delete_confirm_dialog.dialog_text = TEXT_DELETE_CONFIRM
	delete_confirm_dialog.ok_button_text = TEXT_DELETE_TITLE
	delete_confirm_dialog.cancel_button_text = TEXT_CLOSE
	delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(delete_confirm_dialog)

func _on_slot_pressed(slot_id: int, has_profile: bool, has_run: bool) -> void:
	if not has_profile:
		pending_slot_id = slot_id
		if difficulty_overlay != null and difficulty_overlay.has_method("open"):
			difficulty_overlay.open()
		return

	SAVE_MANAGER.set_active_endless_slot(slot_id)
	if has_run:
		SAVE_MANAGER.request_continue()
	else:
		SAVE_MANAGER.clear_save(slot_id, SAVE_MANAGER.MODE_ENDLESS)
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_delete_pressed(slot_id: int) -> void:
	pending_delete_slot_id = slot_id
	_ensure_delete_confirm_dialog()
	if delete_confirm_dialog != null:
		delete_confirm_dialog.popup_centered(Vector2i(420, 180))

func _on_delete_confirmed() -> void:
	if pending_delete_slot_id < 1:
		return
	SAVE_MANAGER.delete_endless_profile(pending_delete_slot_id)
	pending_delete_slot_id = -1
	_hide_difficulty_overlay()
	_build_ui()

func _on_difficulty_selected(difficulty_id: String) -> void:
	if pending_slot_id < 1:
		return
	SAVE_MANAGER.create_or_load_endless_profile(pending_slot_id, difficulty_id)
	SAVE_MANAGER.clear_save(pending_slot_id, SAVE_MANAGER.MODE_ENDLESS)
	_hide_difficulty_overlay()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _hide_difficulty_overlay() -> void:
	pending_slot_id = -1
	if difficulty_overlay != null and difficulty_overlay.has_method("close_overlay"):
		difficulty_overlay.close_overlay()

func _on_difficulty_overlay_closed() -> void:
	pending_slot_id = -1

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

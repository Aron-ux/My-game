extends CanvasLayer

signal upgrade_selected(option_id: String, attribute_option_id: String)
signal upgrade_refresh_requested

const SURVIVORS_MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const SURVIVORS_CARD_LIST := preload("res://scripts/ui/components/survivors_card_list.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const SURVIVORS_HOVER_DETAIL := preload("res://scripts/ui/components/survivors_hover_detail.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const BUILD_CARD_TEXTURE := preload("res://assets/UI/card/card.png")
const BUILD_CARD_SCENE := preload("res://assets/UI/card/card.tscn")
const BUILD_REFRESH_TEXTURE := preload("res://assets/UI/循环.png")
const TRAIT_HEAD_SCENES := {
	"level_trait_swordsman": preload("res://assets/UI/facility/swordhead.tscn"),
	"level_trait_gunner": preload("res://assets/UI/facility/gunhead.tscn"),
	"level_trait_mage": preload("res://assets/UI/facility/witchhead.tscn")
}
const BUILD_CARD_DISPLAY_SCALE := 1.0
const BUILD_CARD_VISUAL_OFFSET := Vector2(52.0, 98.0)
const TRAIT_BUTTON_SCALE := 2.0
const BUILD_DETAIL_HIDE_DELAY := 0.3
const BUILD_CARD_SELECT_ANIM_TIME := 0.32
const BUILD_CARD_SELECT_SHAKE_TIME := 0.10
const BUILD_CARD_SELECT_RING_TIME := 0.26
const BUILD_CARD_SELECT_RING_ALPHA := 0.36
const BUILD_CARD_SELECT_RING_WIDTH := 5.0
const BUILD_REFRESH_BUTTON_VISUAL_OFFSET := Vector2(-5.0, -43.0)
const TRAIT_BUTTON_VISUAL_OFFSETS := {
	"level_trait_mage": Vector2(0.0, -10.0)
}

class BuildCardSelectRing:
	extends Control

	var ring_center := Vector2.ZERO:
		set(value):
			ring_center = value
			queue_redraw()
	var ring_radius := 0.0:
		set(value):
			ring_radius = value
			queue_redraw()
	var ring_alpha := BUILD_CARD_SELECT_RING_ALPHA:
		set(value):
			ring_alpha = value
			queue_redraw()
	var ring_width := BUILD_CARD_SELECT_RING_WIDTH:
		set(value):
			ring_width = value
			queue_redraw()

	func _draw() -> void:
		if ring_radius <= 0.0 or ring_alpha <= 0.0:
			return
		draw_arc(ring_center, ring_radius, 0.0, TAU, 96, Color(1.0, 0.82, 0.18, ring_alpha), ring_width, true)

const BLESSING_SLOT_ORDER := ["body", "combat", "skill"]
const SMALL_BOSS_SLOT_ORDER := ["equipment", "card"]
const BLESSING_UNIFIED_SECTION_TITLE := "祝福三选一"
const DEFAULT_SLOT_LABELS := {
	"body": "战斗",
	"combat": "连携",
	"skill": "技能",
	"equipment": "道具",
	"card": "技能奖励"
}

var modal: Control
var selection_label: Label
var card_list: Control
var hover_detail: Control
var build_root: Control
var build_dimmer: ColorRect
var build_card_layer: Control
var trait_button_layer: Control
var build_refresh_button: Button
var build_detail_hide_timer: Timer
var build_card_entries: Array = []
var trait_button_entries: Array = []
var build_card_hover_tweens: Dictionary = {}
var active_build_detail_control: Control
var active_build_detail_option_id := ""
var build_selection_in_progress := false

var current_mode: String = "direct"
var current_options: Array = []
var current_attribute_options: Array = []
var current_offer_context: Dictionary = {}
var option_groups: Dictionary = {}
var pending_blessing_option_id: String = ""
var pending_blessing_title: String = ""
var pending_attribute_option_id: String = ""
var pending_attribute_title: String = ""
var preferred_attribute_option_id: String = ""
var pending_equipment_option_id: String = ""
var pending_equipment_title: String = ""
var pending_card_option_id: String = ""
var pending_card_title: String = ""

func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	modal = SURVIVORS_MODAL.new()
	modal.configure(Vector2(680.0, 430.0), 0.54, 0.60, Vector2(320.0, 240.0))
	add_child(modal)

	selection_label = Label.new()
	selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	modal.content.add_child(selection_label)
	modal.content.move_child(selection_label, min(2, modal.content.get_child_count() - 1))

	card_list = SURVIVORS_CARD_LIST.new()
	card_list.item_selected.connect(_on_card_list_item_selected)
	card_list.item_hovered.connect(_on_card_item_hovered)
	card_list.item_unhovered.connect(_on_card_item_unhovered)
	modal.set_body(card_list)

	_ensure_build_overlay()

	hover_detail = SURVIVORS_HOVER_DETAIL.new()
	add_child(hover_detail)

	build_detail_hide_timer = Timer.new()
	build_detail_hide_timer.one_shot = true
	build_detail_hide_timer.wait_time = BUILD_DETAIL_HIDE_DELAY
	build_detail_hide_timer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	build_detail_hide_timer.timeout.connect(_on_build_detail_hide_timer_timeout)
	add_child(build_detail_hide_timer)

	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

	hide_ui()

func _on_viewport_size_changed() -> void:
	if visible:
		_apply_responsive_state()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_CHARACTER_PANEL):
		var main := get_tree().current_scene
		if main != null and main.has_method("_toggle_character_panel"):
			main._toggle_character_panel()
			get_viewport().set_input_as_handled()

func show_options(options: Array, attribute_options: Array = [], offer_context: Dictionary = {}) -> void:
	current_mode = "blessing"
	current_options = options
	current_attribute_options = attribute_options
	current_offer_context = offer_context.duplicate(true)
	option_groups = _group_options(options, BLESSING_SLOT_ORDER)
	_reset_pending_selection()
	build_selection_in_progress = false
	visible = true
	if modal != null:
		modal.visible = false
	_clear_modal_footer()
	_ensure_build_overlay()
	_select_default_attribute_option()
	_rebuild_build_overlay()

func show_menu(title: String, options: Array) -> void:
	current_mode = "direct"
	current_options = options
	current_attribute_options = []
	current_offer_context = {}
	option_groups = {}
	_reset_pending_selection()
	build_selection_in_progress = false
	visible = true
	if build_root != null:
		build_root.visible = false
	if modal != null:
		modal.visible = true
	modal.configure(Vector2(640.0, 390.0), 0.50, 0.55, Vector2(300.0, 220.0))
	modal.set_title(title)
	modal.set_hint("卡面显示简短摘要；鼠标移到卡片上查看完整说明。")
	selection_label.visible = false
	_prepare_modal_layout()
	_clear_modal_footer()
	_rebuild_direct_list()

func show_small_boss_reward_menu(title: String, options: Array) -> void:
	current_mode = "small_boss_pair"
	current_options = options
	current_attribute_options = []
	current_offer_context = {}
	option_groups = _group_small_boss_reward_options(options)
	_reset_pending_selection()
	build_selection_in_progress = false
	visible = true
	if build_root != null:
		build_root.visible = false
	if modal != null:
		modal.visible = true
	modal.configure(Vector2(660.0, 420.0), 0.52, 0.58, Vector2(320.0, 230.0))
	modal.set_title(title)
	modal.set_hint(_get_small_boss_reward_menu_hint())
	selection_label.visible = true
	_prepare_modal_layout()
	_clear_modal_footer()
	_rebuild_small_boss_list()
	_update_small_boss_reward_hint()

func hide_ui() -> void:
	visible = false
	if build_root != null:
		build_root.visible = false
	build_selection_in_progress = false
	_reset_pending_selection()
	if hover_detail != null and hover_detail.has_method("hide_detail"):
		hover_detail.hide_detail()
	_clear_active_build_detail()
	# Do not clear the card list while hiding. Reward chains can hide the current
	# panel and open the next panel in the same frame (for example consecutive
	# level-ups or multi-step skill rewards). Clearing a hidden ScrollContainer
	# immediately before repopulating it can leave Godot's internal scrollbar
	# range at 0, making the next panel impossible to scroll. Each show/rebuild
	# path clears and repopulates the list while visible, which keeps the
	# scrollbar range valid.
	_clear_modal_footer()

func _apply_responsive_state() -> void:
	if current_mode == "blessing" and build_root != null and build_root.visible:
		_layout_build_overlay()
	_prepare_modal_layout()
	_refresh_selected_cards()

func _ensure_build_overlay() -> void:
	if build_root != null:
		return
	build_root = Control.new()
	build_root.name = "BuildUpgradeOverlay"
	build_root.visible = false
	build_root.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	build_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(build_root)

	build_dimmer = ColorRect.new()
	build_dimmer.color = Color(0.0, 0.0, 0.0, 0.62)
	build_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_fill_rect(build_dimmer)
	build_root.add_child(build_dimmer)

	build_card_layer = Control.new()
	build_card_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_fill_rect(build_card_layer)
	build_root.add_child(build_card_layer)

	trait_button_layer = Control.new()
	trait_button_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	build_root.add_child(trait_button_layer)

	build_refresh_button = Button.new()
	build_refresh_button.text = ""
	build_refresh_button.tooltip_text = "刷新"
	build_refresh_button.focus_mode = Control.FOCUS_NONE
	build_refresh_button.pressed.connect(_on_refresh_pressed)
	var refresh_icon := TextureRect.new()
	refresh_icon.name = "RefreshIcon"
	refresh_icon.texture = BUILD_REFRESH_TEXTURE
	refresh_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	refresh_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	refresh_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	refresh_icon.offset_left = -5.0
	refresh_icon.offset_top = -4.0
	refresh_icon.offset_right = 3.0
	refresh_icon.offset_bottom = 4.0
	build_refresh_button.add_child(refresh_icon)
	build_root.add_child(build_refresh_button)
	_apply_refresh_button_style()

func _fill_rect(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0

func _rebuild_build_overlay() -> void:
	if build_root == null:
		return
	build_root.visible = true
	if build_dimmer != null:
		build_dimmer.visible = true
	if build_card_layer != null:
		for child in build_card_layer.get_children():
			build_card_layer.remove_child(child)
			child.queue_free()
	if trait_button_layer != null:
		for child in trait_button_layer.get_children():
			trait_button_layer.remove_child(child)
			child.queue_free()
	build_card_entries = []
	trait_button_entries = []

	var displayed_options := current_options.slice(0, min(3, current_options.size()))
	for raw_option in displayed_options:
		if raw_option is not Dictionary:
			continue
		var option: Dictionary = raw_option
		var button := _make_build_card_button(option)
		build_card_layer.add_child(button)
		build_card_entries.append({
			"button": button,
			"option": option
		})

	for raw_trait_option in _get_trait_options():
		var option: Dictionary = raw_trait_option
		var button := _make_trait_button(option)
		trait_button_layer.add_child(button)
		trait_button_entries.append({
			"button": button,
			"option": option
		})

	_update_trait_button_styles()
	_update_build_refresh_button()
	_layout_build_overlay()

func _make_build_card_button(option: Dictionary) -> TextureButton:
	var button := BUILD_CARD_SCENE.instantiate() as TextureButton
	if button == null:
		button = TextureButton.new()
		button.texture_normal = BUILD_CARD_TEXTURE
		button.texture_hover = BUILD_CARD_TEXTURE
		button.texture_pressed = BUILD_CARD_TEXTURE
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(_on_build_card_mouse_entered.bind(button, option))
	button.mouse_exited.connect(_on_build_card_mouse_exited.bind(button))
	button.gui_input.connect(_on_build_item_gui_input.bind(button, option))
	button.pressed.connect(_on_build_card_pressed.bind(button, option))
	if button.get_node_or_null("HoverFrame") == null:
		button.add_child(_make_build_card_hover_frame())
	button.set_meta("build_card_base_scale", button.scale)
	_populate_build_card_scene(button, option)
	return button

func _populate_build_card_scene(button: TextureButton, option: Dictionary) -> void:
	var title_label := button.get_node_or_null("Margin/Content/TitleLabel") as Label
	if title_label != null:
		title_label.text = str(option.get("title", option.get("name", "选项")))
	var summary_label := button.get_node_or_null("Margin/Content/SummaryLabel") as Label
	if summary_label != null:
		summary_label.text = _get_summary_text(option)

func _make_build_card_hover_frame() -> Panel:
	var panel := Panel.new()
	panel.name = "HoverFrame"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_rect(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.92, 0.62, 0.08)
	style.border_color = Color(1.0, 0.82, 0.28, 0.96)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_build_card_select_ring(rect: Rect2) -> BuildCardSelectRing:
	var ring := BuildCardSelectRing.new()
	ring.name = "SelectRing"
	ring.position = Vector2.ZERO
	ring.size = SURVIVORS_THEME.viewport_size(self)
	ring.z_index = 45
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.ring_center = rect.get_center()
	ring.ring_radius = 1.0
	ring.ring_alpha = BUILD_CARD_SELECT_RING_ALPHA
	ring.ring_width = BUILD_CARD_SELECT_RING_WIDTH
	return ring

func _get_build_card_diagonal_radius(rect: Rect2) -> float:
	return rect.size.length() * 0.5

func _make_trait_button(option: Dictionary) -> Button:
	var option_id := str(option.get("id", ""))
	var button := Button.new()
	button.text = ""
	button.tooltip_text = str(option.get("title", option.get("name", "特性训练")))
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_contents = true
	var head_scene: PackedScene = TRAIT_HEAD_SCENES.get(option_id)
	if head_scene != null:
		var head := head_scene.instantiate() as Node2D
		if head != null:
			head.name = "TraitHead"
			head.set_meta("base_scale", head.scale)
			button.add_child(head)
	button.mouse_entered.connect(_on_build_item_mouse_entered.bind(button, option))
	button.mouse_exited.connect(_on_build_item_mouse_exited.bind(button, option))
	button.gui_input.connect(_on_build_item_gui_input.bind(button, option))
	button.pressed.connect(_on_trait_button_pressed.bind(option))
	return button

func _layout_build_overlay() -> void:
	if build_root == null:
		return
	var viewport := SURVIVORS_THEME.viewport_size(self)
	var card_count := build_card_entries.size()
	var base_card_y: float = clamp(viewport.y * 0.055, 42.0, 64.0)
	var card_y: float = base_card_y + BUILD_CARD_VISUAL_OFFSET.y
	if card_count > 0:
		var fit_scale := _get_build_card_fit_scale(viewport, card_y)
		for entry in build_card_entries:
			var button := (entry as Dictionary).get("button") as Control
			if button != null:
				button.scale = _get_build_card_base_scale(button) * BUILD_CARD_DISPLAY_SCALE * fit_scale

		var card_sizes: Array[Vector2] = []
		var total_card_width := 0.0
		for entry in build_card_entries:
			var button := (entry as Dictionary).get("button") as Control
			var card_size := _get_build_card_visual_size(button)
			card_sizes.append(card_size)
			total_card_width += card_size.x
		var card_gap: float = clamp(viewport.x * 0.030, 26.0, 56.0)
		var max_gap: float = (viewport.x - 40.0 - total_card_width) / float(max(1, card_count - 1))
		if card_count > 1:
			card_gap = clamp(min(card_gap, max_gap), 12.0, 56.0)
		var total_width := total_card_width + card_gap * float(max(0, card_count - 1))
		var x := (viewport.x - total_width) * 0.5 + BUILD_CARD_VISUAL_OFFSET.x
		for index in range(card_count):
			var entry: Dictionary = build_card_entries[index]
			var button := entry.get("button") as Control
			if button == null:
				continue
			var card_size: Vector2 = card_sizes[index]
			button.position = Vector2(x, card_y)
			if button.size.x <= 0.0 or button.size.y <= 0.0:
				button.size = _get_build_card_base_size(button)
			button.pivot_offset = button.size * 0.5
			button.set_meta("build_card_layout_position", button.position)
			button.set_meta("build_card_layout_scale", button.scale)
			x += card_size.x + card_gap

	var trait_count := trait_button_entries.size()
	var icon_size: float = clamp(viewport.y * 0.115, 92.0, 122.0) * TRAIT_BUTTON_SCALE
	var icon_gap: float = clamp(viewport.x * 0.035, 36.0, 54.0) * TRAIT_BUTTON_SCALE
	var middle_trait_center_x := viewport.x * 0.5
	if trait_button_layer != null:
		trait_button_layer.visible = trait_count > 0
		var trait_sizes: Array[Vector2] = []
		var trait_width := 0.0
		var trait_height := 0.0
		for entry in trait_button_entries:
			var button := (entry as Dictionary).get("button") as Button
			var trait_size := _get_trait_button_size(button, icon_size)
			trait_sizes.append(trait_size)
			trait_width += trait_size.x
			trait_height = max(trait_height, trait_size.y)
		trait_width += icon_gap * float(max(0, trait_count - 1))
		var cards_bottom := base_card_y + _get_cards_height()
		var trait_y: float = cards_bottom + clamp(viewport.y * 0.045, 38.0, 56.0)
		trait_button_layer.position = Vector2((viewport.x - trait_width) * 0.5, trait_y)
		trait_button_layer.size = Vector2(trait_width, trait_height)
		var trait_x := 0.0
		for index in range(trait_count):
			var entry: Dictionary = trait_button_entries[index]
			var button := entry.get("button") as Button
			if button == null:
				continue
			var trait_size: Vector2 = trait_sizes[index]
			var option: Dictionary = entry.get("option", {})
			var option_id := str(option.get("id", ""))
			var visual_offset: Vector2 = TRAIT_BUTTON_VISUAL_OFFSETS.get(option_id, Vector2.ZERO)
			button.position = Vector2(trait_x, (trait_height - trait_size.y) * 0.5) + visual_offset
			button.custom_minimum_size = trait_size
			button.size = trait_size
			_layout_trait_head(button, option_id == pending_attribute_option_id)
			if index == int(trait_count / 2):
				middle_trait_center_x = trait_button_layer.position.x + button.position.x + trait_size.x * 0.5
			trait_x += trait_size.x + icon_gap

	if build_refresh_button != null:
		var refresh_size: float = clamp(viewport.y * 0.055, 50.0, 62.0)
		var trait_bottom := trait_button_layer.position.y + trait_button_layer.size.y if trait_button_layer != null and trait_button_layer.visible else base_card_y + _get_cards_height()
		var refresh_y: float = min(viewport.y - refresh_size - 28.0, trait_bottom + clamp(viewport.y * 0.060, 48.0, 66.0))
		build_refresh_button.position = Vector2(middle_trait_center_x - refresh_size * 0.5, refresh_y) + BUILD_REFRESH_BUTTON_VISUAL_OFFSET
		build_refresh_button.size = Vector2(refresh_size, refresh_size)
		build_refresh_button.custom_minimum_size = Vector2(refresh_size, refresh_size)

func _get_cards_bottom() -> float:
	var bottom := 0.0
	for entry in build_card_entries:
		var button := (entry as Dictionary).get("button") as Control
		if button != null:
			bottom = max(bottom, button.position.y + _get_build_card_visual_size(button).y)
	return bottom

func _get_cards_height() -> float:
	var height := 0.0
	for entry in build_card_entries:
		var button := (entry as Dictionary).get("button") as Control
		height = max(height, _get_build_card_visual_size(button).y)
	return height

func _get_build_card_visual_size(button: Control) -> Vector2:
	var base_size := _get_build_card_base_size(button)
	if button == null:
		return base_size
	return Vector2(base_size.x * absf(button.scale.x), base_size.y * absf(button.scale.y))

func _get_build_card_design_visual_size(button: Control) -> Vector2:
	var base_size := _get_build_card_base_size(button)
	if button == null:
		return base_size
	var base_scale := _get_build_card_base_scale(button)
	return Vector2(base_size.x * absf(base_scale.x) * BUILD_CARD_DISPLAY_SCALE, base_size.y * absf(base_scale.y) * BUILD_CARD_DISPLAY_SCALE)

func _get_build_card_base_scale(button: Control) -> Vector2:
	if button != null and button.has_meta("build_card_base_scale"):
		var value: Variant = button.get_meta("build_card_base_scale")
		if value is Vector2:
			return value
	return button.scale if button != null else Vector2.ONE

func _get_build_card_fit_scale(viewport: Vector2, card_y: float) -> float:
	var card_count := build_card_entries.size()
	if card_count <= 0:
		return 1.0
	var total_width := 0.0
	for entry in build_card_entries:
		var button := (entry as Dictionary).get("button") as Control
		var visual_size := _get_build_card_design_visual_size(button)
		total_width += visual_size.x
	var gap: float = clamp(viewport.x * 0.030, 26.0, 56.0)
	var design_width: float = total_width + gap * float(max(0, card_count - 1))
	var available_width: float = max(1.0, viewport.x - 40.0)
	var fit_x: float = min(1.0, available_width / max(1.0, design_width))
	return clamp(fit_x, 0.45, 1.0)

func _get_build_card_base_size(button: Control) -> Vector2:
	if button == null:
		return BUILD_CARD_TEXTURE.get_size()
	if button.size.x > 0.0 and button.size.y > 0.0:
		return button.size
	if button.custom_minimum_size.x > 0.0 and button.custom_minimum_size.y > 0.0:
		return button.custom_minimum_size
	if button is TextureButton:
		var texture_button := button as TextureButton
		if texture_button.texture_normal != null:
			return texture_button.texture_normal.get_size()
	return BUILD_CARD_TEXTURE.get_size()

func _apply_refresh_button_style() -> void:
	if build_refresh_button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.52, 1.0, 0.30)
	normal.border_color = Color(0.08, 0.52, 1.0, 0.0)
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(64)
	build_refresh_button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.15, 0.62, 1.0, 0.38)
	build_refresh_button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.05, 0.42, 0.90, 0.30)
	build_refresh_button.add_theme_stylebox_override("pressed", pressed)
	var focus := StyleBoxEmpty.new()
	build_refresh_button.add_theme_stylebox_override("focus", focus)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.08, 0.24, 0.38, 0.30)
	build_refresh_button.add_theme_stylebox_override("disabled", disabled)
	build_refresh_button.add_theme_color_override("font_color", Color(0.66, 1.0, 1.0, 1.0))
	build_refresh_button.add_theme_color_override("font_hover_color", Color(0.82, 1.0, 1.0, 1.0))
	build_refresh_button.add_theme_color_override("font_pressed_color", Color(0.45, 0.86, 0.92, 1.0))
	build_refresh_button.add_theme_color_override("font_disabled_color", Color(0.45, 0.52, 0.56, 0.76))

func _update_build_refresh_button() -> void:
	if build_refresh_button == null:
		return
	var refresh_limit := int(current_offer_context.get("refresh_limit", 0))
	var refresh_remaining := int(current_offer_context.get("refresh_remaining", 0))
	build_refresh_button.visible = refresh_limit > 0
	build_refresh_button.disabled = refresh_remaining <= 0
	build_refresh_button.tooltip_text = "刷新 %d/%d" % [refresh_remaining, refresh_limit] if refresh_limit > 0 else "刷新"

func _get_trait_options() -> Array:
	var trait_options: Array = []
	for raw_option in current_attribute_options:
		if raw_option is not Dictionary:
			continue
		var option: Dictionary = raw_option
		if TRAIT_HEAD_SCENES.has(str(option.get("id", ""))):
			trait_options.append(option)
	return trait_options

func _select_default_attribute_option() -> void:
	var trait_options := _get_trait_options()
	if trait_options.is_empty():
		pending_attribute_option_id = ""
		pending_attribute_title = ""
		return
	var selected_option: Dictionary = trait_options[0]
	for raw_option in trait_options:
		var option: Dictionary = raw_option
		if str(option.get("id", "")) == preferred_attribute_option_id:
			selected_option = option
			break
	_set_attribute_selection(selected_option, preferred_attribute_option_id == "")

func _set_attribute_selection(option: Dictionary, persist: bool = true) -> void:
	pending_attribute_option_id = str(option.get("id", ""))
	pending_attribute_title = str(option.get("title", "英雄特性"))
	if persist:
		preferred_attribute_option_id = pending_attribute_option_id
	_update_trait_button_styles()

func _update_trait_button_styles() -> void:
	for entry in trait_button_entries:
		if entry is not Dictionary:
			continue
		var button := entry.get("button") as Button
		var option: Dictionary = entry.get("option", {})
		if button == null:
			continue
		var selected := str(option.get("id", "")) == pending_attribute_option_id
		_apply_trait_button_style(button, selected)

func _apply_trait_button_style(button: Button, selected: bool) -> void:
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.add_theme_stylebox_override("disabled", empty)
	button.modulate = Color(1.0, 1.0, 1.0, 1.0) if selected else Color(0.72, 0.76, 0.80, 0.88)
	_layout_trait_head(button, selected)

func _layout_trait_head(button: Button, selected: bool) -> void:
	var head := button.get_node_or_null("TraitHead") as Node2D
	if head == null:
		return
	var sprite := head.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		head.position = button.size * 0.5
		return
	var target_diameter: float = max(1.0, min(button.size.x, button.size.y))
	var texture_size := sprite.texture.get_size()
	var fit_scale: float = target_diameter / max(1.0, max(texture_size.x, texture_size.y))
	var base_scale: Vector2 = Vector2.ONE
	if head.has_meta("base_scale"):
		var value: Variant = head.get_meta("base_scale")
		if value is Vector2:
			base_scale = value
	head.position = button.size * 0.5
	head.scale = base_scale * fit_scale

func _get_trait_button_size(button: Button, fallback_size: float) -> Vector2:
	return Vector2(fallback_size, fallback_size)

func _on_build_card_pressed(card: TextureButton, option: Dictionary) -> void:
	if build_selection_in_progress:
		return
	build_selection_in_progress = true
	pending_blessing_option_id = str(option.get("id", ""))
	pending_blessing_title = str(option.get("title", "祝福"))
	_hide_build_item_detail()
	_set_build_overlay_input_enabled(false, card)
	await _play_build_card_select_animation(card)
	upgrade_selected.emit(pending_blessing_option_id, pending_attribute_option_id)

func _on_trait_button_pressed(option: Dictionary) -> void:
	if build_selection_in_progress:
		return
	_set_attribute_selection(option, true)

func _on_build_card_mouse_entered(card: TextureButton, item: Dictionary) -> void:
	_animate_build_card_hover(card, true)
	_on_build_item_mouse_entered(card, item)

func _on_build_card_mouse_exited(card: TextureButton) -> void:
	_animate_build_card_hover(card, false)
	_on_build_item_mouse_exited(card, {})

func _animate_build_card_hover(card: TextureButton, hovered: bool) -> void:
	if card == null:
		return
	if build_selection_in_progress:
		return
	var key := card.get_instance_id()
	var old_tween := build_card_hover_tweens.get(key) as Tween
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var layout_position: Vector2 = card.position
	if card.has_meta("build_card_layout_position"):
		var position_value: Variant = card.get_meta("build_card_layout_position")
		if position_value is Vector2:
			layout_position = position_value
	var layout_scale: Vector2 = card.scale
	if card.has_meta("build_card_layout_scale"):
		var scale_value: Variant = card.get_meta("build_card_layout_scale")
		if scale_value is Vector2:
			layout_scale = scale_value
	card.z_index = 20 if hovered else 0
	var target_position := layout_position + Vector2(0.0, -10.0) if hovered else layout_position
	var target_scale := layout_scale
	var target_modulate := Color(1.08, 1.08, 1.08, 1.0) if hovered else Color(1.0, 1.0, 1.0, 1.0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", target_position, 0.12)
	tween.tween_property(card, "scale", target_scale, 0.12)
	tween.tween_property(card, "modulate", target_modulate, 0.12)
	build_card_hover_tweens[key] = tween

func _play_build_card_select_animation(card: TextureButton) -> void:
	if card == null or not is_instance_valid(card):
		return
	var key := card.get_instance_id()
	var old_tween := build_card_hover_tweens.get(key) as Tween
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var layout_position: Vector2 = card.position
	if card.has_meta("build_card_layout_position"):
		var position_value: Variant = card.get_meta("build_card_layout_position")
		if position_value is Vector2:
			layout_position = position_value
	var layout_scale: Vector2 = card.scale
	if card.has_meta("build_card_layout_scale"):
		var scale_value: Variant = card.get_meta("build_card_layout_scale")
		if scale_value is Vector2:
			layout_scale = scale_value
	card.position = layout_position
	card.scale = layout_scale
	card.modulate = Color(1.0, 1.0, 1.0, 1.0)
	card.z_index = 50
	_hide_unselected_build_overlay_parts(card)
	var card_rect := _get_build_card_scaled_rect(card, layout_position, layout_scale)
	var ring := _make_build_card_select_ring(card_rect)
	if build_card_layer != null:
		build_card_layer.add_child(ring)
		build_card_layer.move_child(ring, build_card_layer.get_child_count() - 1)
	var target_radius := _get_build_card_diagonal_radius(card_rect)
	var ring_tween := create_tween()
	ring_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	ring_tween.set_parallel(true)
	ring_tween.set_trans(Tween.TRANS_QUAD)
	ring_tween.set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "ring_radius", target_radius, BUILD_CARD_SELECT_RING_TIME)
	ring_tween.tween_property(ring, "ring_alpha", 0.0, BUILD_CARD_SELECT_RING_TIME)
	var card_tween := create_tween()
	card_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	card_tween.set_trans(Tween.TRANS_SINE)
	card_tween.set_ease(Tween.EASE_OUT)
	var shake_step := BUILD_CARD_SELECT_SHAKE_TIME / 4.0
	card_tween.tween_property(card, "position", layout_position + Vector2(6.0, 0.0), shake_step)
	card_tween.tween_property(card, "position", layout_position + Vector2(-6.0, 0.0), shake_step)
	card_tween.tween_property(card, "position", layout_position + Vector2(3.0, 0.0), shake_step)
	card_tween.tween_property(card, "position", layout_position, shake_step)
	card_tween.tween_property(card, "modulate", Color(1.0, 1.0, 1.0, 0.0), BUILD_CARD_SELECT_ANIM_TIME)
	var hold_timer := get_tree().create_timer(BUILD_CARD_SELECT_SHAKE_TIME + BUILD_CARD_SELECT_ANIM_TIME, true)
	await hold_timer.timeout
	if ring != null and is_instance_valid(ring):
		ring.queue_free()

func _hide_unselected_build_overlay_parts(selected_card: Control) -> void:
	if build_dimmer != null:
		build_dimmer.visible = false
	if trait_button_layer != null:
		trait_button_layer.visible = false
	if build_refresh_button != null:
		build_refresh_button.visible = false
	for entry in build_card_entries:
		if entry is not Dictionary:
			continue
		var card := entry.get("button") as Control
		if card != null and card != selected_card:
			card.visible = false

func _get_build_card_scaled_rect(card: Control, card_position: Vector2, card_scale: Vector2) -> Rect2:
	var base_size := _get_build_card_base_size(card)
	var pivot := card.pivot_offset
	var visual_size := Vector2(base_size.x * absf(card_scale.x), base_size.y * absf(card_scale.y))
	var visual_position := card_position + pivot - Vector2(pivot.x * card_scale.x, pivot.y * card_scale.y)
	return Rect2(visual_position, visual_size)

func _set_build_overlay_input_enabled(enabled: bool, selected_card: BaseButton = null) -> void:
	for entry in build_card_entries:
		if entry is not Dictionary:
			continue
		var card := entry.get("button") as BaseButton
		if card != null:
			card.disabled = not enabled and card != selected_card
	for entry in trait_button_entries:
		if entry is not Dictionary:
			continue
		var button := entry.get("button") as BaseButton
		if button != null:
			button.disabled = not enabled
	if build_refresh_button != null:
		build_refresh_button.disabled = not enabled or int(current_offer_context.get("refresh_remaining", 0)) <= 0

func _on_build_item_mouse_entered(control: Control, item: Dictionary) -> void:
	if control == active_build_detail_control:
		_cancel_build_detail_hide()

func _on_build_item_mouse_exited(control: Control, item: Dictionary) -> void:
	if control == active_build_detail_control:
		_schedule_build_detail_hide()

func _on_build_item_gui_input(event: InputEvent, control: Control, item: Dictionary) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_toggle_build_item_detail(control, item)
			get_viewport().set_input_as_handled()

func _toggle_build_item_detail(control: Control, item: Dictionary) -> void:
	var option_id := str(item.get("id", ""))
	if hover_detail != null and hover_detail.visible and control == active_build_detail_control and option_id == active_build_detail_option_id:
		_hide_build_item_detail()
		return
	_show_build_item_detail(control, item)

func _show_build_item_detail(control: Control, item: Dictionary) -> void:
	active_build_detail_control = control
	active_build_detail_option_id = str(item.get("id", ""))
	_cancel_build_detail_hide()
	if hover_detail != null and hover_detail.has_method("show_item"):
		hover_detail.show_item(item, get_viewport().get_mouse_position(), Rect2(control.global_position, control.size))

func _hide_build_item_detail() -> void:
	if hover_detail != null and hover_detail.has_method("hide_detail"):
		hover_detail.hide_detail()
	_clear_active_build_detail()

func _clear_active_build_detail() -> void:
	active_build_detail_control = null
	active_build_detail_option_id = ""
	_cancel_build_detail_hide()

func _schedule_build_detail_hide() -> void:
	if build_detail_hide_timer == null:
		return
	build_detail_hide_timer.start(BUILD_DETAIL_HIDE_DELAY)

func _cancel_build_detail_hide() -> void:
	if build_detail_hide_timer != null:
		build_detail_hide_timer.stop()

func _on_build_detail_hide_timer_timeout() -> void:
	if active_build_detail_control == null:
		return
	var viewport := get_viewport()
	if viewport != null and active_build_detail_control.get_global_rect().has_point(viewport.get_mouse_position()):
		return
	_hide_build_item_detail()

func _get_summary_text(item: Dictionary) -> String:
	for key in ["summary", "short_description", "preview_description"]:
		var value := str(item.get(key, ""))
		if value != "":
			return _first_line(value)
	return _first_line(str(item.get("description", "")))

func _first_line(text_value: String) -> String:
	var normalized := text_value.replace("\r", "")
	var newline_index := normalized.find("\n")
	if newline_index >= 0:
		return normalized.substr(0, newline_index)
	return normalized

func _prepare_modal_layout() -> void:
	if modal != null and modal.has_method("apply_layout"):
		modal.apply_layout()
	var compact := false
	if modal != null:
		compact = bool(modal.get("compact"))
	if selection_label != null:
		selection_label.add_theme_font_size_override("font_size", 11 if compact else 13)
	if card_list != null and card_list.has_method("set_compact"):
		card_list.set_compact(compact)

func _configure_level_up_footer() -> void:
	_clear_modal_footer()
	if modal == null or not modal.has_method("add_footer_button"):
		return
	var refresh_limit := int(current_offer_context.get("refresh_limit", 0))
	if refresh_limit <= 0:
		return
	var refresh_remaining := int(current_offer_context.get("refresh_remaining", 0))
	var label := str(current_offer_context.get("refresh_button_label", ""))
	if label == "":
		label = "刷新祝福 %d/%d" % [refresh_remaining, refresh_limit] if refresh_remaining > 0 else "刷新已用完"
	var button: Button = modal.add_footer_button(label, Callable(self, "_on_refresh_pressed"), "normal")
	button.disabled = refresh_remaining <= 0

func _clear_modal_footer() -> void:
	if modal != null and modal.has_method("clear_footer"):
		modal.clear_footer()

func _on_refresh_pressed() -> void:
	if current_mode != "blessing":
		return
	if int(current_offer_context.get("refresh_remaining", 0)) <= 0:
		return
	current_offer_context["refresh_remaining"] = 0
	_configure_level_up_footer()
	_update_build_refresh_button()
	upgrade_refresh_requested.emit()

func _rebuild_level_up_list() -> void:
	card_list.clear()
	_add_unified_blessing_options()
	if not current_attribute_options.is_empty():
		card_list.add_section("英雄特性训练")
		card_list.columns = 2
		card_list.add_card_grid(current_attribute_options, 2)
	_refresh_selected_cards()
	if card_list.has_method("reset_scroll_to_top"):
		card_list.reset_scroll_to_top()

func _rebuild_small_boss_list() -> void:
	card_list.clear()
	_add_option_sections(SMALL_BOSS_SLOT_ORDER)
	_refresh_selected_cards()

func _rebuild_direct_list() -> void:
	card_list.clear()
	for raw_option in current_options:
		if raw_option is not Dictionary:
			continue
		card_list.add_card(raw_option)
	_refresh_selected_cards()

func _add_option_sections(slot_order: Array) -> void:
	for slot_id_value in slot_order:
		var slot_id := str(slot_id_value)
		var grouped_options: Array = option_groups.get(slot_id, [])
		if grouped_options.is_empty():
			continue
		var label := str(grouped_options[0].get("slot_label", DEFAULT_SLOT_LABELS.get(slot_id, slot_id)))
		card_list.add_section(label)
		for raw_option in grouped_options:
			if raw_option is not Dictionary:
				continue
			var option: Dictionary = raw_option
			card_list.add_card(option, false, bool(option.get("evolved", false)))

func _add_unified_blessing_options() -> void:
	if current_options.is_empty():
		return
	card_list.add_section(BLESSING_UNIFIED_SECTION_TITLE)
	for raw_option in current_options:
		if raw_option is not Dictionary:
			continue
		var option: Dictionary = raw_option
		card_list.add_card(option, false, bool(option.get("evolved", false)))

func _on_card_item_hovered(item: Dictionary, anchor_rect: Rect2) -> void:
	if hover_detail != null and hover_detail.has_method("show_item"):
		hover_detail.show_item(item, get_viewport().get_mouse_position(), anchor_rect)

func _on_card_item_unhovered() -> void:
	if hover_detail != null:
		if hover_detail.has_method("request_hide"):
			hover_detail.request_hide()
		elif hover_detail.has_method("hide_detail"):
			hover_detail.hide_detail()

func _on_card_list_item_selected(option_id: String, option: Dictionary) -> void:
	if current_mode == "direct":
		upgrade_selected.emit(option_id, "")
		return
	if current_mode == "small_boss_pair":
		_select_small_boss_reward_option(option)
		return
	var slot_id := str(option.get("slot", ""))
	if slot_id == "" or _is_attribute_option(option_id):
		_select_attribute_option(option)
	else:
		_select_blessing_option(option)

func _is_attribute_option(option_id: String) -> bool:
	for raw_option in current_attribute_options:
		if raw_option is Dictionary and str((raw_option as Dictionary).get("id", "")) == option_id:
			return true
	return false

func _select_attribute_option(option: Dictionary) -> void:
	_set_attribute_selection(option, true)
	_update_selection_hint()
	_refresh_selected_cards()

func _select_blessing_option(option: Dictionary) -> void:
	pending_blessing_option_id = str(option.get("id", ""))
	pending_blessing_title = str(option.get("title", "祝福"))
	_update_selection_hint()
	_refresh_selected_cards()
	upgrade_selected.emit(pending_blessing_option_id, pending_attribute_option_id)

func _select_small_boss_reward_option(option: Dictionary) -> void:
	var slot_id := str(option.get("slot", ""))
	if slot_id == "equipment":
		pending_equipment_option_id = str(option.get("id", ""))
		pending_equipment_title = str(option.get("title", "道具"))
	elif slot_id == "card":
		pending_card_option_id = str(option.get("id", ""))
		pending_card_title = str(option.get("title", "技能奖励"))
	_update_small_boss_reward_hint()
	_refresh_selected_cards()
	if _is_small_boss_reward_selection_complete():
		upgrade_selected.emit(pending_equipment_option_id, pending_card_option_id)

func _try_emit_combined_selection() -> void:
	if pending_blessing_option_id == "":
		return
	if not current_attribute_options.is_empty() and pending_attribute_option_id == "":
		return
	upgrade_selected.emit(pending_blessing_option_id, pending_attribute_option_id)

func _update_selection_hint() -> void:
	if current_mode != "blessing":
		return
	var attribute_text := pending_attribute_title if pending_attribute_title != "" else "未选英雄特性"
	var blessing_text := pending_blessing_title if pending_blessing_title != "" else "未选祝福"
	selection_label.text = "当前：%s | %s" % [attribute_text, blessing_text]

func _update_small_boss_reward_hint() -> void:
	if current_mode != "small_boss_pair":
		return
	var parts: Array[String] = []
	if _small_boss_reward_slot_required("equipment"):
		parts.append(pending_equipment_title if pending_equipment_title != "" else "未选道具")
	if _small_boss_reward_slot_required("card"):
		parts.append(pending_card_title if pending_card_title != "" else "未选技能奖励")
	if parts.is_empty():
		selection_label.text = "当前：无可选奖励"
	else:
		selection_label.text = "当前：%s" % " | ".join(parts)

func _refresh_selected_cards() -> void:
	if card_list == null:
		return
	var ids: Array[String] = []
	if pending_attribute_option_id != "":
		ids.append(pending_attribute_option_id)
	if pending_blessing_option_id != "":
		ids.append(pending_blessing_option_id)
	if pending_equipment_option_id != "":
		ids.append(pending_equipment_option_id)
	if pending_card_option_id != "":
		ids.append(pending_card_option_id)
	card_list.set_selected_ids(ids)

func _group_options(options: Array, slot_order: Array) -> Dictionary:
	var groups := {}
	for slot_id_value in slot_order:
		groups[str(slot_id_value)] = []
	for raw_option in options:
		if raw_option is not Dictionary:
			continue
		var option: Dictionary = raw_option
		var slot_id := str(option.get("slot", ""))
		if not groups.has(slot_id):
			groups[slot_id] = []
		groups[slot_id].append(option)
	return groups

func _group_small_boss_reward_options(options: Array) -> Dictionary:
	var groups := {
		"equipment": [],
		"card": []
	}
	for raw_option in options:
		if raw_option is not Dictionary:
			continue
		var option: Dictionary = raw_option.duplicate(true)
		if str(option.get("slot", "")) == "equipment":
			option["slot"] = "equipment"
			option["slot_label"] = "閬撳叿"
			groups["equipment"].append(option)
		else:
			option["slot"] = "card"
			option["slot_label"] = "技能奖励"
			groups["card"].append(option)
	return groups

func _get_small_boss_reward_menu_hint() -> String:
	var labels: Array[String] = []
	if _small_boss_reward_slot_required("equipment"):
		labels.append("道具选 1 个")
	if _small_boss_reward_slot_required("card"):
		labels.append("技能奖励选 1 个")
	if labels.is_empty():
		return "当前没有可选奖励；鼠标移到卡片上查看完整说明。"
	return "%s；鼠标移到卡片上查看完整说明。" % "，".join(labels)

func _small_boss_reward_slot_required(slot_id: String) -> bool:
	return not (option_groups.get(slot_id, []) as Array).is_empty()

func _is_small_boss_reward_selection_complete() -> bool:
	if _small_boss_reward_slot_required("equipment") and pending_equipment_option_id == "":
		return false
	if _small_boss_reward_slot_required("card") and pending_card_option_id == "":
		return false
	return _small_boss_reward_slot_required("equipment") or _small_boss_reward_slot_required("card")

func _reset_pending_selection() -> void:
	pending_blessing_option_id = ""
	pending_blessing_title = ""
	pending_attribute_option_id = ""
	pending_attribute_title = ""
	pending_equipment_option_id = ""
	pending_equipment_title = ""
	pending_card_option_id = ""
	pending_card_title = ""

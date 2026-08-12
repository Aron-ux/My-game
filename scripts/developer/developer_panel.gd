extends PanelContainer

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const DEVELOPER_OPTION_PROVIDER := preload("res://scripts/developer/developer_option_provider.gd")
const PERFORMANCE_MONITOR := preload("res://scripts/game/performance_monitor.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

signal level_up_requested
signal boss_spawn_requested(archetype_id: String)
signal small_boss_spawn_requested(archetype_id: String)
signal normal_enemy_batch_spawn_requested(archetype_id: String, count: int)
signal enemy_spawn_requested(kind: String, archetype_id: String, count: int)
signal skill_unlock_requested(skill_id: String, tier: int)
signal skill_talent_grant_requested(talent_id: String)
signal blessing_grant_requested(blessing_id: String, tier: int)
signal all_blessings_grant_requested
signal ruan_stone_action_requested(action_id: String)
signal enemy_detail_display_toggled(enabled: bool)
signal glutton_skill_test_requested(skill_id: String)
signal endless_tier_test_requested(tier: int)

var level_button: Button
var invincibility_button: Button
var no_cooldown_button: Button
var enemy_detail_button: Button
var endless_tier_spin: SpinBox
var enemy_menu_popup: PanelContainer
var enemy_list: VBoxContainer
var glutton_skill_list: VBoxContainer
var skill_list: VBoxContainer
var blessing_list: VBoxContainer
var ruan_stone_list: VBoxContainer
var performance_label: Label
var enemy_detail_display_enabled: bool = false
var cached_skill_options: Array = []
var skill_options_initialized: bool = false


func _ready() -> void:
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = -280.0
	offset_top = 96.0
	offset_right = -18.0
	offset_bottom = 720.0

	add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(Color(0.16, 0.08, 0.08, 0.84), Color(1.0, 0.54, 0.42, 0.92), 2, 10, 12.0))

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	add_child(content)

	var title := Label.new()
	title.text = "开发者选项"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	content.add_child(title)

	_build_top_buttons(content)
	_build_scroll_content(content)
	refresh_mode_buttons()


func refresh_mode_buttons() -> void:
	if invincibility_button != null:
		invincibility_button.text = "停用无敌模式" if DEVELOPER_MODE.is_ignore_damage_enabled() else "启用无敌模式"
	if no_cooldown_button != null:
		no_cooldown_button.text = "关闭无 CD" if DEVELOPER_MODE.is_no_cooldown_enabled() else "开启无 CD"


	_refresh_enemy_detail_button_text()


func set_invincibility_enabled(enabled: bool) -> void:
	DEVELOPER_MODE.set_ignore_damage_enabled(enabled)
	refresh_mode_buttons()


func set_enemy_detail_display_enabled(enabled: bool) -> void:
	enemy_detail_display_enabled = enabled
	_refresh_enemy_detail_button_text()


func set_boss_options(_options: Array) -> void:
	pass


func set_normal_enemy_options(_options: Array) -> void:
	pass


func set_enemy_options(options: Array) -> void:
	_populate_enemy_option_list(options)


func set_skill_options(options: Array) -> void:
	if skill_options_initialized and cached_skill_options == options:
		return
	skill_options_initialized = true
	cached_skill_options = options.duplicate(true)
	_populate_option_list(skill_list, options, "暂无技能选项", Callable(self, "_on_skill_button_pressed"))


func set_blessing_options(options: Array) -> void:
	_populate_option_list(blessing_list, options, "暂无祝福选项", Callable(self, "_on_blessing_button_pressed"))


func set_ruan_stone_options(options: Array) -> void:
	_populate_option_list(ruan_stone_list, options, "暂无阮石调试选项", Callable(self, "_on_ruan_stone_button_pressed"))


func update_performance_metrics(metrics: Dictionary) -> void:
	if performance_label != null:
		performance_label.text = PERFORMANCE_MONITOR.format_metrics(metrics)


func set_performance_metrics_visible(visible: bool) -> void:
	if performance_label != null:
		performance_label.visible = visible


func _build_top_buttons(parent: Control) -> void:
	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 6)
	parent.add_child(tier_row)
	endless_tier_spin = SpinBox.new()
	endless_tier_spin.min_value = 1
	endless_tier_spin.max_value = 9999
	endless_tier_spin.value = DEVELOPER_MODE.get_test_endless_tier()
	endless_tier_spin.custom_minimum_size = Vector2(92.0, 40.0)
	tier_row.add_child(endless_tier_spin)
	var tier_button := _build_button("应用测试 N 层", Vector2(122.0, 40.0), 14, "primary")
	tier_button.pressed.connect(func(): endless_tier_test_requested.emit(int(endless_tier_spin.value)))
	tier_row.add_child(tier_button)

	level_button = _build_button("角色等级 +1", Vector2(220, 40), 16, "primary")
	level_button.pressed.connect(_on_level_button_pressed)
	parent.add_child(level_button)

	invincibility_button = _build_button("", Vector2(220, 40), 16)
	invincibility_button.pressed.connect(_on_invincibility_button_pressed)
	parent.add_child(invincibility_button)

	no_cooldown_button = _build_button("", Vector2(220, 40), 16)
	no_cooldown_button.pressed.connect(_on_no_cooldown_button_pressed)
	parent.add_child(no_cooldown_button)

	enemy_detail_button = _build_button("", Vector2(220, 40), 16)
	enemy_detail_button.pressed.connect(_on_enemy_detail_button_pressed)
	parent.add_child(enemy_detail_button)
	_refresh_enemy_detail_button_text()


func _build_scroll_content(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(230.0, 480.0)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var menu_content := VBoxContainer.new()
	menu_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_content.add_theme_constant_override("separation", 8)
	scroll.add_child(menu_content)

	_build_enemy_menu_button(menu_content)
	glutton_skill_list = _add_menu_section(menu_content, "Glutton Skill Test")
	_populate_glutton_skill_list()
	ruan_stone_list = _add_menu_section(menu_content, "阮狗石头调试")
	blessing_list = _add_menu_section(menu_content, "添加祝福")
	skill_list = _add_menu_section(menu_content, "添加技能 / 等级天赋")

	performance_label = Label.new()
	performance_label.text = "Performance: collecting..."
	performance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	performance_label.add_theme_font_size_override("font_size", 13)
	performance_label.modulate = Color(0.8, 0.95, 1.0, 0.95)
	menu_content.add_child(performance_label)


func _build_enemy_menu_button(parent: Control) -> void:
	var button := _build_button("添加敌人  <", Vector2(220.0, 40.0), 16, "primary")
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_toggle_enemy_menu)
	parent.add_child(button)
	_ensure_enemy_menu_popup()


func _build_button(text: String, minimum_size: Vector2, font_size: int, style: String = "") -> Button:
	var button := Button.new()
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", font_size)
	button.text = text
	SURVIVORS_THEME.apply_button_style(button, style)
	return button


func _refresh_enemy_detail_button_text() -> void:
	if enemy_detail_button == null:
		return
	enemy_detail_button.text = "关闭怪物详细显示" if enemy_detail_display_enabled else "开启怪物详细显示"


func _ensure_enemy_menu_popup() -> void:
	if enemy_menu_popup != null:
		return
	enemy_menu_popup = PanelContainer.new()
	enemy_menu_popup.visible = false
	enemy_menu_popup.anchor_left = 0.0
	enemy_menu_popup.anchor_top = 0.0
	enemy_menu_popup.anchor_right = 0.0
	enemy_menu_popup.anchor_bottom = 0.0
	enemy_menu_popup.offset_left = -250.0
	enemy_menu_popup.offset_top = 24.0
	enemy_menu_popup.offset_right = -10.0
	enemy_menu_popup.offset_bottom = 540.0
	enemy_menu_popup.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(Color(0.08, 0.06, 0.05, 0.9), Color(1.0, 0.72, 0.42, 0.92), 2, 10, 10.0))
	add_child(enemy_menu_popup)

	var popup_content := VBoxContainer.new()
	popup_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_content.add_theme_constant_override("separation", 8)
	enemy_menu_popup.add_child(popup_content)

	var back_button := _build_button("返回一级菜单", Vector2(220.0, 36.0), 15)
	back_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back_button.pressed.connect(_hide_enemy_menu)
	popup_content.add_child(back_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(230.0, 440.0)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	popup_content.add_child(scroll)

	enemy_list = VBoxContainer.new()
	enemy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_list.add_theme_constant_override("separation", 6)
	scroll.add_child(enemy_list)


func _toggle_enemy_menu() -> void:
	_ensure_enemy_menu_popup()
	enemy_menu_popup.visible = not enemy_menu_popup.visible


func _hide_enemy_menu() -> void:
	if enemy_menu_popup != null:
		enemy_menu_popup.visible = false


func _populate_enemy_option_list(options: Array) -> void:
	_ensure_enemy_menu_popup()
	_populate_option_list(enemy_list, options, "暂无敌人选项", Callable(self, "_on_enemy_button_pressed"))


func _populate_glutton_skill_list() -> void:
	var options: Array = [
		{"id": "war_stomp", "title": "War Stomp", "description": "Force the 7 second war stomp state."},
		{"id": "death_twine", "title": "Death Twine", "description": "Force the player-targeted entangle skill."},
		{"id": "wood_spike", "title": "Wood Spike", "description": "Force five random wood spike warnings."}
	]
	_populate_option_list(glutton_skill_list, options, "No glutton skill test options", Callable(self, "_on_glutton_skill_button_pressed"))


func _add_menu_section(parent: Control, title: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)

	var toggle_button := Button.new()
	toggle_button.custom_minimum_size = Vector2(220.0, 36.0)
	toggle_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle_button.add_theme_font_size_override("font_size", 15)
	toggle_button.text = "%s  >" % title
	SURVIVORS_THEME.apply_button_style(toggle_button)
	section.add_child(toggle_button)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	list.visible = false
	section.add_child(list)
	toggle_button.pressed.connect(_toggle_section.bind(list, toggle_button, title))
	return list


func _toggle_section(list: VBoxContainer, toggle_button: Button, title: String) -> void:
	list.visible = not list.visible
	toggle_button.text = "%s  %s" % [title, "v" if list.visible else ">"]


func _populate_option_list(list: VBoxContainer, options: Array, empty_text: String, callback: Callable) -> void:
	if list == null:
		return
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()

	for option_data in options:
		if not (option_data is Dictionary):
			continue
		var option: Dictionary = option_data
		var button := Button.new()
		button.custom_minimum_size = Vector2(220.0, 58.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 14)
		var title: String = str(option.get("title", option.get("id", "未命名选项")))
		var option_id: String = str(option.get("id", ""))
		button.text = "%s\n%s" % [title, option_id]
		button.tooltip_text = str(option.get("description", ""))
		button.disabled = not bool(option.get("enabled", true))
		SURVIVORS_THEME.apply_card_button_style(button, false, false, button.disabled)
		button.pressed.connect(callback.bind(option_id))
		list.add_child(button)

	if list.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = empty_text
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty_label)


func _on_level_button_pressed() -> void:
	level_up_requested.emit()


func _on_invincibility_button_pressed() -> void:
	DEVELOPER_MODE.set_ignore_damage_enabled(not DEVELOPER_MODE.is_ignore_damage_enabled())
	refresh_mode_buttons()


func _on_no_cooldown_button_pressed() -> void:
	DEVELOPER_MODE.set_no_cooldown_enabled(not DEVELOPER_MODE.is_no_cooldown_enabled())
	refresh_mode_buttons()


func _on_enemy_detail_button_pressed() -> void:
	enemy_detail_display_enabled = not enemy_detail_display_enabled
	_refresh_enemy_detail_button_text()
	enemy_detail_display_toggled.emit(enemy_detail_display_enabled)


func _on_enemy_button_pressed(option_id: String) -> void:
	var parts := option_id.split(":")
	if parts.size() < 2:
		return
	var kind := str(parts[0])
	var archetype_id := str(parts[1])
	var count := 1
	enemy_spawn_requested.emit(kind, archetype_id, count)


func _on_boss_button_pressed(archetype_id: String) -> void:
	if archetype_id != "":
		boss_spawn_requested.emit(archetype_id)


func _on_small_boss_button_pressed(archetype_id: String) -> void:
	if archetype_id != "":
		small_boss_spawn_requested.emit(archetype_id)


func _on_normal_enemy_button_pressed(archetype_id: String) -> void:
	if archetype_id == "":
		return
	normal_enemy_batch_spawn_requested.emit(archetype_id, 1)


func _on_skill_button_pressed(option_id: String) -> void:
	if option_id.begins_with(DEVELOPER_OPTION_PROVIDER.SKILL_TALENT_OPTION_PREFIX):
		skill_talent_grant_requested.emit(option_id.trim_prefix(DEVELOPER_OPTION_PROVIDER.SKILL_TALENT_OPTION_PREFIX))
		return
	var parts: PackedStringArray = option_id.split(":")
	if parts.size() < 2:
		return
	var skill_id: String = str(parts[0])
	var tier: int = max(1, int(parts[1]))
	if skill_id != "":
		skill_unlock_requested.emit(skill_id, tier)


func _on_blessing_button_pressed(option_id: String) -> void:
	if option_id == DEVELOPER_OPTION_PROVIDER.ALL_BLESSINGS_OPTION_ID:
		all_blessings_grant_requested.emit()
		return
	var parts: PackedStringArray = option_id.split(":")
	if parts.size() < 2:
		return
	var blessing_id: String = str(parts[0])
	var tier: int = max(1, int(parts[1]))
	if blessing_id != "":
		blessing_grant_requested.emit(blessing_id, tier)


func _on_ruan_stone_button_pressed(option_id: String) -> void:
	if option_id.begins_with(DEVELOPER_OPTION_PROVIDER.RUAN_STONE_OPTION_PREFIX):
		ruan_stone_action_requested.emit(option_id.trim_prefix(DEVELOPER_OPTION_PROVIDER.RUAN_STONE_OPTION_PREFIX))


func _on_glutton_skill_button_pressed(option_id: String) -> void:
	if option_id == "":
		return
	glutton_skill_test_requested.emit(option_id)

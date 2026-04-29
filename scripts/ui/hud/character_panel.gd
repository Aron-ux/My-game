extends CanvasLayer

signal close_requested

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const BUILD_DATABASE := preload("res://scripts/build/build_database.gd")
const PLAYER_EQUIPMENT_FLOW := preload("res://scripts/player/player_equipment_flow.gd")

const ROLE_TEXTURE_PATHS := {
	"swordsman": "人设草图/剑士草图.jpg",
	"gunner": "人设草图/枪手草图.jpg",
	"mage": "人设草图/术师草图.jpg"
}

var role_texture_rect: TextureRect
var role_title_label: Label
var role_button_row: HBoxContainer
var stats_label: RichTextLabel
var equipment_list: VBoxContainer
var card_label: RichTextLabel
var gift_popup: PopupMenu
var cached_player: Node
var viewed_role_index: int = 0
var pending_gift_equipment_id: String = ""
var pending_gift_from_role_id: String = ""
var gift_target_role_ids: Array[String] = []

func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.0, 0.0, 0.0, 0.76)
	root.add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1120.0, 650.0)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(panel)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 22)
	panel.add_child(layout)

	var left_column := VBoxContainer.new()
	left_column.custom_minimum_size = Vector2(360.0, 610.0)
	left_column.add_theme_constant_override("separation", 14)
	layout.add_child(left_column)

	role_title_label = Label.new()
	role_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_title_label.add_theme_font_size_override("font_size", 28)
	left_column.add_child(role_title_label)

	role_texture_rect = TextureRect.new()
	role_texture_rect.custom_minimum_size = Vector2(340.0, 460.0)
	role_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	role_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left_column.add_child(role_texture_rect)

	role_button_row = HBoxContainer.new()
	role_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	role_button_row.add_theme_constant_override("separation", 8)
	left_column.add_child(role_button_row)

	var close_button := Button.new()
	close_button.text = "关闭 (%s)" % GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_CHARACTER_PANEL))
	close_button.custom_minimum_size = Vector2(180.0, 42.0)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	left_column.add_child(close_button)

	var right_column := VBoxContainer.new()
	right_column.custom_minimum_size = Vector2(700.0, 610.0)
	right_column.add_theme_constant_override("separation", 8)
	layout.add_child(right_column)

	var title := Label.new()
	title.text = "角色面板"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_column.add_child(title)

	stats_label = RichTextLabel.new()
	stats_label.custom_minimum_size = Vector2(700.0, 230.0)
	stats_label.bbcode_enabled = true
	stats_label.fit_content = false
	stats_label.scroll_active = true
	right_column.add_child(stats_label)

	var equipment_title := Label.new()
	equipment_title.text = "道具背包（右键道具可赠与）"
	equipment_title.add_theme_font_size_override("font_size", 22)
	right_column.add_child(equipment_title)

	var equipment_scroll := ScrollContainer.new()
	equipment_scroll.custom_minimum_size = Vector2(700.0, 150.0)
	right_column.add_child(equipment_scroll)

	equipment_list = VBoxContainer.new()
	equipment_list.add_theme_constant_override("separation", 6)
	equipment_scroll.add_child(equipment_list)

	card_label = RichTextLabel.new()
	card_label.custom_minimum_size = Vector2(700.0, 160.0)
	card_label.bbcode_enabled = true
	card_label.fit_content = false
	card_label.scroll_active = true
	right_column.add_child(card_label)

	gift_popup = PopupMenu.new()
	gift_popup.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	gift_popup.index_pressed.connect(_on_gift_popup_index_pressed)
	add_child(gift_popup)

	hide_panel()

func show_for_player(player: Node) -> void:
	cached_player = player
	if cached_player != null and is_instance_valid(cached_player):
		viewed_role_index = clamp(int(cached_player.get("active_role_index")), 0, max(0, _get_roles().size() - 1))
	refresh()
	visible = true

func hide_panel() -> void:
	visible = false
	if gift_popup != null:
		gift_popup.hide()

func refresh() -> void:
	if cached_player == null or not is_instance_valid(cached_player):
		return
	var roles: Array = _get_roles()
	if roles.is_empty():
		return
	viewed_role_index = clamp(viewed_role_index, 0, roles.size() - 1)
	var role_data: Dictionary = roles[viewed_role_index]
	var role_id: String = str(role_data.get("id", "swordsman"))
	var role_name: String = str(role_data.get("name", "角色"))
	role_title_label.text = "%s  Lv.%d%s" % [
		role_name,
		int(cached_player.get("level")),
		"（站场）" if viewed_role_index == int(cached_player.get("active_role_index")) else "（查看）"
	]
	role_texture_rect.texture = _load_role_texture(role_id)
	_refresh_role_buttons()
	stats_label.text = _build_stats_text(role_data)
	_refresh_equipment_list(role_id)
	card_label.text = _build_card_text()

func _refresh_role_buttons() -> void:
	for child in role_button_row.get_children():
		role_button_row.remove_child(child)
		child.queue_free()
	var roles: Array = _get_roles()
	var active_index: int = int(cached_player.get("active_role_index"))
	for index in range(roles.size()):
		var role: Dictionary = roles[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(104.0, 38.0)
		button.text = "%s%s" % [str(role.get("name", "角色")), "*" if index == active_index else ""]
		button.disabled = index == viewed_role_index
		button.pressed.connect(_view_role.bind(index))
		role_button_row.add_child(button)

func _view_role(role_index: int) -> void:
	viewed_role_index = role_index
	refresh()

func _refresh_equipment_list(role_id: String) -> void:
	for child in equipment_list.get_children():
		equipment_list.remove_child(child)
		child.queue_free()
	var equipment_levels: Dictionary = cached_player._get_role_equipment_levels(role_id) if cached_player.has_method("_get_role_equipment_levels") else {}
	var has_any := false
	for equipment_id in PLAYER_EQUIPMENT_FLOW.EQUIPMENT_DEFINITIONS.keys():
		var count: int = int(equipment_levels.get(str(equipment_id), 0))
		if count <= 0:
			continue
		has_any = true
		var definition: Dictionary = PLAYER_EQUIPMENT_FLOW.EQUIPMENT_DEFINITIONS.get(str(equipment_id), {})
		for _copy_index in range(count):
			var button := Button.new()
			button.text = str(definition.get("title", equipment_id))
			button.tooltip_text = "%s\n当前角色持有 %d 个；右键可赠与其中 1 个。" % [
				str(definition.get("description", "")),
				count
			]
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size = Vector2(660.0, 34.0)
			button.gui_input.connect(_on_equipment_gui_input.bind(str(equipment_id), role_id))
			equipment_list.add_child(button)
	if not has_any:
		var empty_label := Label.new()
		empty_label.text = "暂无道具"
		empty_label.custom_minimum_size = Vector2(660.0, 34.0)
		equipment_list.add_child(empty_label)

func _on_equipment_gui_input(event: InputEvent, equipment_id: String, from_role_id: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_show_gift_popup(equipment_id, from_role_id)

func _show_gift_popup(equipment_id: String, from_role_id: String) -> void:
	pending_gift_equipment_id = equipment_id
	pending_gift_from_role_id = from_role_id
	gift_target_role_ids.clear()
	gift_popup.clear()
	var roles: Array = _get_roles()
	for role_data in roles:
		var target_role_id: String = str(role_data.get("id", ""))
		if target_role_id == "" or target_role_id == from_role_id:
			continue
		var target_levels: Dictionary = cached_player._get_role_equipment_levels(target_role_id) if cached_player.has_method("_get_role_equipment_levels") else {}
		var item_index: int = gift_popup.item_count
		gift_target_role_ids.append(target_role_id)
		gift_popup.add_item("赠与 %s" % str(role_data.get("name", target_role_id)))
		if int(target_levels.get(equipment_id, 0)) >= PLAYER_EQUIPMENT_FLOW.EQUIPMENT_MAX_LEVEL:
			gift_popup.set_item_disabled(item_index, true)
	if gift_popup.item_count <= 0:
		return
	gift_popup.position = Vector2i(get_viewport().get_mouse_position())
	gift_popup.popup()

func _on_gift_popup_index_pressed(index: int) -> void:
	if cached_player == null or not is_instance_valid(cached_player):
		return
	if index < 0 or index >= gift_target_role_ids.size():
		return
	var target_role_id: String = gift_target_role_ids[index]
	if cached_player.has_method("transfer_role_equipment_item"):
		cached_player.transfer_role_equipment_item(pending_gift_equipment_id, pending_gift_from_role_id, target_role_id)
	refresh()

func _build_stats_text(role_data: Dictionary) -> String:
	var role_id: String = str(role_data.get("id", ""))
	var bonus: Dictionary = cached_player._get_role_equipment_bonus_summary(role_id) if cached_player.has_method("_get_role_equipment_bonus_summary") else {}
	var active_bonus: Dictionary = cached_player._get_role_equipment_bonus_summary(str(cached_player._get_active_role().get("id", ""))) if cached_player.has_method("_get_role_equipment_bonus_summary") else {}
	var base_global_damage: float = float(cached_player.get("global_damage_multiplier")) - float(active_bonus.get("damage_multiplier_bonus", 0.0))
	var damage: float = (float(role_data.get("damage", 0.0)) + float(cached_player.get("role_upgrade_levels").get(role_id, {}).get("damage_bonus", 0.0))) * max(0.01, base_global_damage + float(bonus.get("damage_multiplier_bonus", 0.0)))
	var base_speed: float = float(cached_player.get("speed")) - float(active_bonus.get("speed_bonus", 0.0))
	var move_speed: float = (base_speed + float(bonus.get("speed_bonus", 0.0))) * float(role_data.get("speed_scale", 1.0))
	if cached_player.has_method("_get_role_attribute_move_speed_multiplier"):
		move_speed *= float(cached_player._get_role_attribute_move_speed_multiplier(role_id))
	if cached_player.has_method("_get_role_attribute_flat_move_speed_bonus"):
		move_speed += float(cached_player._get_role_attribute_flat_move_speed_bonus(role_id))
	var max_health: float = float(cached_player.get("max_health")) - float(active_bonus.get("max_health_bonus", 0.0)) + float(bonus.get("max_health_bonus", 0.0))
	var current_health_text := "%.0f / %.0f" % [float(cached_player.get("current_health")), max_health]
	if viewed_role_index != int(cached_player.get("active_role_index")):
		current_health_text = "- / %.0f" % max_health
	var base_energy: float = float(cached_player.get("energy_gain_multiplier")) - float(active_bonus.get("energy_gain_bonus", 0.0))
	var energy_gain: float = base_energy + float(bonus.get("energy_gain_bonus", 0.0))
	var lines: Array[String] = []
	lines.append("[font_size=22][b]核心数值[/b][/font_size]")
	lines.append("生命 %s    大招能量 %.0f / %.0f" % [
		current_health_text,
		float(cached_player._get_role_mana(role_id)) if cached_player.has_method("_get_role_mana") else 0.0,
		float(cached_player.get("max_mana"))
	])
	lines.append("伤害 %.1f    攻击间隔 %.2fs    移速 %.1f    吸取范围 %.1f" % [
		damage,
		float(cached_player._get_effective_attack_interval(role_id)) if cached_player.has_method("_get_effective_attack_interval") else 0.0,
		move_speed,
		float(cached_player.get("pickup_radius"))
	])
	lines.append("能量获取 x%.2f    技能范围 x%.2f    CD x%.2f    闪避 %.0f%%    回血 %.1f/s" % [
		energy_gain,
		float(bonus.get("skill_range_multiplier", 1.0)),
		float(bonus.get("cooldown_multiplier", 1.0)),
		float(bonus.get("dodge_chance", 0.0)) * 100.0,
		float(bonus.get("regen_per_second", 0.0))
	])
	lines.append("")
	lines.append("[font_size=22][b]角色成长[/b][/font_size]")
	lines.append("体能 Lv.%d    身法 Lv.%d" % [
		int(cached_player._get_role_attribute_level(role_id, "vitality")) if cached_player.has_method("_get_role_attribute_level") else 0,
		int(cached_player._get_role_attribute_level(role_id, "agility")) if cached_player.has_method("_get_role_attribute_level") else 0
	])
	return "\n".join(lines)

func _build_card_text() -> String:
	var lines: Array[String] = []
	lines.append("[font_size=22][b]已有码牌 / Build[/b][/font_size]")
	var parts: Array[String] = []
	var card_levels: Dictionary = cached_player.get("card_pick_levels")
	for card_id in card_levels.keys():
		var level: int = int(card_levels.get(card_id, 0))
		if level <= 0:
			continue
		var config: Dictionary = BUILD_DATABASE.get_core_card(str(card_id))
		parts.append("%s Lv.%d" % [str(config.get("title", card_id)), level])
	var reward_levels: Dictionary = cached_player.get("special_reward_levels")
	for reward_id in reward_levels.keys():
		var level: int = int(reward_levels.get(reward_id, 0))
		if level <= 0:
			continue
		var reward: Dictionary = BUILD_DATABASE.get_small_boss_reward(str(reward_id))
		parts.append("%s Lv.%d" % [str(reward.get("title", reward_id)), level])
	lines.append("\n".join(parts) if not parts.is_empty() else "暂无 Build 卡牌")
	return "\n".join(lines)

func _load_role_texture(role_id: String) -> Texture2D:
	if cached_player != null and cached_player.has_method("_get_cached_runtime_texture"):
		var texture: Texture2D = cached_player._get_cached_runtime_texture(str(ROLE_TEXTURE_PATHS.get(role_id, ROLE_TEXTURE_PATHS["swordsman"])))
		if texture != null:
			return texture
	return null

func _get_roles() -> Array:
	if cached_player == null or not is_instance_valid(cached_player):
		return []
	var roles_variant: Variant = cached_player.get("roles")
	if roles_variant is Array:
		return roles_variant
	return []

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.075, 0.065, 0.96)
	style.border_color = Color(0.78, 0.68, 0.42, 0.95)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style

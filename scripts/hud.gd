extends CanvasLayer

var level_label: Label
var role_label: Label
var experience_bar: ProgressBar
var experience_label: Label
var health_bar: ProgressBar
var health_label: Label
var mana_bar: ProgressBar
var mana_label: Label
var ultimate_label: Label
var advanced_label: Label
var time_label: Label
var boss_panel: Control
var boss_name_label: Label
var boss_health_bar: ProgressBar
var boss_health_label: Label
var difficulty_label: Label
var team_panel: PanelContainer
var team_role_labels: Array[Label] = []
var switch_cd_label: Label
var switch_power_label: Label
var relay_label: Label
var advanced_visible: bool = false

func _ready() -> void:
	layer = 1

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	time_label = Label.new()
	time_label.anchor_left = 0.0
	time_label.anchor_right = 1.0
	time_label.offset_left = 0.0
	time_label.offset_right = 0.0
	time_label.offset_top = 12.0
	time_label.offset_bottom = 52.0
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 24)
	time_label.text = "时间 00:00"
	root.add_child(time_label)

	boss_panel = Control.new()
	boss_panel.anchor_left = 0.0
	boss_panel.anchor_right = 1.0
	boss_panel.offset_left = 308.0
	boss_panel.offset_right = -308.0
	boss_panel.offset_top = 10.0
	boss_panel.offset_bottom = 82.0
	boss_panel.visible = false
	root.add_child(boss_panel)

	boss_name_label = Label.new()
	boss_name_label.anchor_left = 0.0
	boss_name_label.anchor_right = 1.0
	boss_name_label.offset_top = 0.0
	boss_name_label.offset_bottom = 28.0
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 22)
	boss_name_label.text = "Boss"
	boss_panel.add_child(boss_name_label)

	boss_health_bar = ProgressBar.new()
	boss_health_bar.anchor_left = 0.0
	boss_health_bar.anchor_right = 1.0
	boss_health_bar.offset_left = 0.0
	boss_health_bar.offset_right = 0.0
	boss_health_bar.offset_top = 32.0
	boss_health_bar.offset_bottom = 56.0
	boss_health_bar.show_percentage = false
	boss_panel.add_child(boss_health_bar)

	boss_health_label = Label.new()
	boss_health_label.anchor_left = 0.0
	boss_health_label.anchor_right = 1.0
	boss_health_label.offset_top = 56.0
	boss_health_label.offset_bottom = 78.0
	boss_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_health_label.add_theme_font_size_override("font_size", 15)
	boss_health_label.text = "0 / 0"
	boss_panel.add_child(boss_health_label)

	level_label = Label.new()
	level_label.position = Vector2(20, 18)
	level_label.size = Vector2(120, 24)
	level_label.text = "等级 1"
	root.add_child(level_label)

	role_label = Label.new()
	role_label.position = Vector2(150, 18)
	role_label.size = Vector2(140, 24)
	role_label.text = "角色 剑士"
	root.add_child(role_label)

	experience_bar = ProgressBar.new()
	experience_bar.position = Vector2(20, 48)
	experience_bar.custom_minimum_size = Vector2(260, 20)
	experience_bar.show_percentage = false
	root.add_child(experience_bar)

	experience_label = Label.new()
	experience_label.position = Vector2(20, 74)
	experience_label.size = Vector2(220, 24)
	experience_label.text = "0 / 30 XP"
	root.add_child(experience_label)

	health_bar = ProgressBar.new()
	health_bar.position = Vector2(20, 108)
	health_bar.custom_minimum_size = Vector2(260, 20)
	health_bar.show_percentage = false
	root.add_child(health_bar)

	health_label = Label.new()
	health_label.position = Vector2(20, 134)
	health_label.size = Vector2(220, 24)
	health_label.text = "HP 100 / 100"
	root.add_child(health_label)

	mana_bar = ProgressBar.new()
	mana_bar.position = Vector2(20, 168)
	mana_bar.custom_minimum_size = Vector2(260, 20)
	mana_bar.show_percentage = false
	root.add_child(mana_bar)

	mana_label = Label.new()
	mana_label.position = Vector2(20, 194)
	mana_label.size = Vector2(260, 24)
	mana_label.text = "符能 0 / 100"
	root.add_child(mana_label)

	ultimate_label = Label.new()
	ultimate_label.position = Vector2(20, 220)
	ultimate_label.size = Vector2(340, 28)
	ultimate_label.text = "符印 0 / 2 | 符卡 未就绪"
	ultimate_label.add_theme_font_size_override("font_size", 16)
	root.add_child(ultimate_label)

	difficulty_label = Label.new()
	difficulty_label.position = Vector2(20, 254)
	difficulty_label.size = Vector2(320, 24)
	difficulty_label.text = "刷新 1.50秒 | 威胁 x1.00"
	difficulty_label.visible = false
	root.add_child(difficulty_label)

	advanced_label = Label.new()
	advanced_label.position = Vector2(20, 288)
	advanced_label.size = Vector2(520, 180)
	advanced_label.text = ""
	advanced_label.visible = false
	root.add_child(advanced_label)

	_build_team_panel(root)

func _build_team_panel(root: Control) -> void:
	team_panel = PanelContainer.new()
	team_panel.anchor_left = 1.0
	team_panel.anchor_top = 0.0
	team_panel.anchor_right = 1.0
	team_panel.anchor_bottom = 0.0
	team_panel.offset_left = -280.0
	team_panel.offset_top = 18.0
	team_panel.offset_right = -18.0
	team_panel.offset_bottom = 210.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.82)
	style.border_color = Color(1.0, 0.88, 0.45, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	team_panel.add_theme_stylebox_override("panel", style)
	root.add_child(team_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	team_panel.add_child(content)

	var title := Label.new()
	title.text = "当前队伍"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	content.add_child(title)

	for role_name in ["剑士", "枪手", "术师"]:
		var label := Label.new()
		label.text = role_name
		label.add_theme_font_size_override("font_size", 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(label)
		team_role_labels.append(label)

	switch_cd_label = Label.new()
	switch_cd_label.text = "切人CD 0.0秒"
	switch_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_cd_label.add_theme_font_size_override("font_size", 16)
	content.add_child(switch_cd_label)

	switch_power_label = Label.new()
	switch_power_label.text = "切换增益 无"
	switch_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_power_label.add_theme_font_size_override("font_size", 15)
	switch_power_label.modulate = Color(0.86, 0.9, 0.98, 0.92)
	content.add_child(switch_power_label)

	relay_label = Label.new()
	relay_label.text = "接力窗口 无"
	relay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relay_label.add_theme_font_size_override("font_size", 15)
	relay_label.modulate = Color(0.8, 0.92, 1.0, 0.92)
	content.add_child(relay_label)

func update_display(level: int, current_experience: int, required_experience: int) -> void:
	level_label.text = "等级 %d" % level
	experience_bar.max_value = max(required_experience, 1)
	experience_bar.value = current_experience
	experience_label.text = "%d / %d XP" % [current_experience, required_experience]

func update_health(current_health: float, max_health: float) -> void:
	health_bar.max_value = max(max_health, 1.0)
	health_bar.value = current_health
	health_label.text = "HP %.0f / %.0f" % [current_health, max_health]

func update_mana(current_mana: float, max_mana: float) -> void:
	mana_bar.max_value = max(max_mana, 1.0)
	mana_bar.value = current_mana
	mana_label.text = "符能 %.0f / %.0f" % [current_mana, max_mana]

func update_stats(summary: Dictionary) -> void:
	role_label.text = "角色 %s" % summary.get("role_name", "剑士")
	var active_role_index := int(summary.get("active_role_index", 0))
	var team_roles: Array = summary.get("team_roles", ["剑士", "枪手", "术师"])
	for index in range(team_role_labels.size()):
		var label := team_role_labels[index]
		var role_name := str(team_roles[index]) if index < team_roles.size() else "-"
		if index == active_role_index:
			label.text = "> %s <" % role_name
			label.modulate = Color(1.0, 0.92, 0.45, 1.0)
		else:
			label.text = role_name
			label.modulate = Color(0.86, 0.86, 0.86, 1.0)

	var switch_cooldown := float(summary.get("switch_cooldown", 0.0))
	if switch_cooldown > 0.0:
		switch_cd_label.text = "切人CD %.1f秒" % switch_cooldown
	else:
		switch_cd_label.text = "切人CD 已就绪"

	var switch_power_name := str(summary.get("switch_power_label", ""))
	var switch_power_remaining := float(summary.get("switch_power_remaining", 0.0))
	var entry_blessing_name := str(summary.get("entry_blessing_label", ""))
	var entry_blessing_remaining := float(summary.get("entry_blessing_remaining", 0.0))
	var switch_buff_parts: Array[String] = []
	if switch_power_remaining > 0.0 and switch_power_name != "":
		switch_buff_parts.append("%s %.1f秒" % [switch_power_name, switch_power_remaining])
	if entry_blessing_remaining > 0.0 and entry_blessing_name != "":
		switch_buff_parts.append("%s %.1f秒" % [entry_blessing_name, entry_blessing_remaining])
	if not switch_buff_parts.is_empty():
		switch_power_label.text = "切换增益 %s" % " / ".join(switch_buff_parts)
		switch_power_label.modulate = Color(1.0, 0.9, 0.5, 0.98)
	else:
		switch_power_label.text = "切换增益 无"
		switch_power_label.modulate = Color(0.86, 0.9, 0.98, 0.92)

	var relay_window := float(summary.get("relay_window_remaining", 0.0))
	var relay_name := str(summary.get("relay_label", ""))
	var relay_pending := bool(summary.get("relay_bonus_pending", false))
	if relay_pending and relay_window > 0.0 and relay_name != "":
		relay_label.text = "接力窗口 %s %.1f秒" % [relay_name, relay_window]
		relay_label.modulate = Color(1.0, 0.92, 0.56, 0.98)
	else:
		relay_label.text = "接力窗口 无"
		relay_label.modulate = Color(0.8, 0.92, 1.0, 0.92)

	var current_energy: float = float(summary.get("current_mana", 0.0))
	var required_energy: float = float(summary.get("ultimate_energy_cost", 100.0))
	var current_seals: int = int(summary.get("ultimate_seals", 0))
	var max_seals: int = int(summary.get("ultimate_seal_max", 2))
	var ultimate_ready: bool = bool(summary.get("ultimate_ready", false))
	if ultimate_ready:
		ultimate_label.text = "符印 %d / %d | 符卡 已就绪" % [current_seals, max_seals]
		ultimate_label.modulate = Color(1.0, 0.9, 0.5, 1.0)
	else:
		ultimate_label.text = "符印 %d / %d | 释放大招需 %.0f 符能" % [current_seals, max_seals, required_energy]
		ultimate_label.modulate = Color(0.88, 0.92, 0.98, 0.96)
	var max_energy: float = max(float(summary.get("max_mana", 1.0)), 1.0)
	if mana_bar.max_value != max_energy:
		mana_bar.max_value = max_energy
	if mana_bar.value != current_energy:
		mana_bar.value = current_energy

	advanced_label.text = "移速 %.0f\n伤害 %.0f\n攻速 %.1f秒\n拾取范围 %.0f" % [
		summary.get("move_speed", 0.0),
		summary.get("bullet_damage", 0.0),
		summary.get("fire_interval", 0.0),
		summary.get("pickup_radius", 0.0)
	]
	advanced_label.text += "\n%s %d | %s %d | %s %d" % [
		str(summary.get("body_slot_label", "战斗")),
		int(summary.get("body_build_level", 0)),
		str(summary.get("combat_slot_label", "连携")),
		int(summary.get("combat_build_level", 0)),
		str(summary.get("skill_slot_label", "大招")),
		int(summary.get("skill_build_level", 0))
	]
	advanced_label.text += "\n属性 生命 %d | 机动 %d | 攻击 %d" % [
		int(summary.get("attribute_vitality_level", 0)),
		int(summary.get("attribute_agility_level", 0)),
		int(summary.get("attribute_power_level", 0))
	]
	advanced_label.text += "\n受伤倍率 x%.2f | 切人基准 %.1f秒" % [
		float(summary.get("damage_taken_multiplier", 1.0)),
		float(summary.get("switch_cooldown_base", 8.0))
	]
	var role_detail := str(summary.get("role_detail_summary", ""))
	var role_route := str(summary.get("role_route_summary", ""))
	var role_core := str(summary.get("role_core_summary", ""))
	var slot_resonance := str(summary.get("slot_resonance_summary", ""))
	if role_core != "":
		advanced_label.text += "\n%s" % role_core
	if role_route != "":
		advanced_label.text += "\n路线 %s" % role_route
	if role_detail != "":
		advanced_label.text += "\n专属 %s" % role_detail
	if slot_resonance != "":
		advanced_label.text += "\n%s" % slot_resonance

func update_time(seconds_elapsed: float) -> void:
	var total_seconds: int = int(floor(seconds_elapsed))
	var minutes: int = int(total_seconds / 60)
	var seconds: int = total_seconds % 60
	time_label.text = "时间 %02d:%02d" % [minutes, seconds]

func show_boss_ui(boss_name: String, current_health: float, max_health: float) -> void:
	if boss_panel != null:
		boss_panel.visible = true
	if time_label != null:
		time_label.visible = false
	update_boss_ui(boss_name, current_health, max_health)

func update_boss_ui(boss_name: String, current_health: float, max_health: float) -> void:
	if boss_panel == null:
		return
	boss_name_label.text = boss_name
	boss_health_bar.max_value = max(max_health, 1.0)
	boss_health_bar.value = clamp(current_health, 0.0, boss_health_bar.max_value)
	boss_health_label.text = "%.0f / %.0f" % [max(current_health, 0.0), max_health]

func hide_boss_ui() -> void:
	if boss_panel != null:
		boss_panel.visible = false
	if time_label != null:
		time_label.visible = true

func update_difficulty(current_spawn_interval: float, power_multiplier: float) -> void:
	difficulty_label.text = "刷新 %.2f秒 | 威胁 x%.2f" % [current_spawn_interval, power_multiplier]

func toggle_advanced_display() -> void:
	advanced_visible = not advanced_visible
	difficulty_label.visible = advanced_visible
	advanced_label.visible = advanced_visible


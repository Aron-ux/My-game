extends Control

signal character_selected(index: int)
signal close_requested

const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const PLAYER_EQUIPMENT_FLOW := preload("res://scripts/player/player_equipment_flow.gd")
const ROLE_IDS := ["swordsman", "gunner", "mage"]
const ROLE_TRAITS := {
	"swordsman": [
		{"title": "战意", "type": "普攻回复", "description": "普通攻击命中时，有 30% 概率触发战意回复。", "details": [{"title": "回复效果", "text": "恢复自身最大生命值 3% 与已损失生命值 3% 的生命。"}, {"title": "判定规则", "text": "触发后冷却 1 秒；同一次攻击最多判定 4 次。"}]},
		{"title": "骑士荣耀", "type": "濒死保护", "description": "受到致命伤害时保留 1 点生命，并进入战意状态。", "details": [{"title": "持续时间", "text": "战意状态持续 1.5 秒，结束后进入 80 秒冷却。"}]},
		{"title": "嗜血", "type": "技能后状态", "description": "登场技命中后进入 3 秒嗜血状态；无敌斩结束后进入 4.5 秒嗜血状态。", "details": [{"title": "状态效果", "text": "嗜血期间获得等时长无敌。无敌斩结束触发的嗜血期间，回复效果提高至 1.5 倍。"}, {"title": "切换规则", "text": "切换离开剑士后，嗜血状态清除。"}]},
	],
	"gunner": [
		{"title": "猎杀安全区", "type": "范围效果", "description": "枪手基础闪避率为 15%，并拥有半径 115 的猎杀安全区。", "details": [{"title": "区域内效果", "text": "安全区内的敌人承受枪手伤害降至 40%。"}]},
		{"title": "瞬杀", "type": "未受伤时积累", "description": "未受伤时每 2 秒获得 1 层瞬杀，最多 10 层。", "details": [{"title": "叠加效果", "text": "每层提高 3% 伤害、3% 移速和 1.5% 闪避率。"}, {"title": "受到伤害", "text": "瞬杀层数清空，并进入 15 秒冷却。"}]},
	],
	"mage": [
		{"title": "奥数充能", "type": "击杀充能", "description": "击杀敌人时有 10% 概率获得 1 层奥数充能，最多 10 层。", "details": [{"title": "每层效果", "text": "法师自身大招回能效率提高 2%；法师自身获得的大招能量中有 10% 同步给另外两名角色。"}, {"title": "切换继承", "text": "切换角色后，奥数充能由下一名登场角色继承，并持续与切换前相同的剩余时间。"}]},
		{"title": "奥法盈余", "type": "技能后状态", "description": "释放登场技后立即获得 5 秒奥法盈余；释放大招后，在演出结束时获得 5 秒奥法盈余。", "details": [{"title": "持续效果", "text": "全队大招回能效率和切人回能效率各提高 20%。"}, {"title": "自然结束", "text": "奥法盈余自然结束时，如果法师仍在场，额外获得 3 层奥数充能。"}]},
	],
}
const PAGE_NAMES := ["EquipmentPage", "CharacterPage", "ArtifactPage"]
const TAB_NAMES := ["EquipmentTab", "CharacterTab", "ArtifactTab"]
const INVENTORY_FILTERS := ["all", "equipment", "materials", "skills"]

@export var role_portraits: Array[Texture2D] = []
@onready var page_host: Control = $MenuFrame/PageHost
@onready var tab_bar: HBoxContainer = $C
@onready var portrait: TextureRect = $MenuFrame/PageHost/CharacterPage/CharacterColumns/CharacterPanel/CharacterBackground/CharacterPortrait
@onready var equipment_portrait: TextureRect = $MenuFrame/PageHost/EquipmentPage/EquipmentColumns/CharacterEquipmentPanel/CharacterEquipmentContent/CharacterStage/EquipmentCharacterPortrait
@onready var character_slots: Control = $CharacterSelectSlots
@onready var trait_list: VBoxContainer = $MenuFrame/PageHost/CharacterPage/CharacterColumns/CharacterInfoPanel/CharacterInfoContent/TraitScroll/TraitList
@onready var equipment_inventory_grid: GridContainer = $MenuFrame/PageHost/EquipmentPage/EquipmentColumns/EquipmentInventoryPanel/InventoryContent/EquipmentInventoryGrid
@onready var inventory_tabs: HBoxContainer = $MenuFrame/PageHost/EquipmentPage/EquipmentColumns/EquipmentInventoryPanel/InventoryContent/InventoryTabs
@onready var stat_labels := {
	"health": $MenuFrame/PageHost/EquipmentPage/EquipmentColumns/CharacterEquipmentPanel/CharacterEquipmentContent/CharacterStatsCenter/CharacterStats/HPStat/Value,
	"energy": $MenuFrame/PageHost/EquipmentPage/EquipmentColumns/CharacterEquipmentPanel/CharacterEquipmentContent/CharacterStatsCenter/CharacterStats/MPStat/Value,
	"attack": $MenuFrame/PageHost/EquipmentPage/EquipmentColumns/CharacterEquipmentPanel/CharacterEquipmentContent/CharacterStatsCenter/CharacterStats/AttackStat/Value,
	"armor": $MenuFrame/PageHost/EquipmentPage/EquipmentColumns/CharacterEquipmentPanel/CharacterEquipmentContent/CharacterStatsCenter/CharacterStats/DefenseStat/Value,
	"reduction": $MenuFrame/PageHost/EquipmentPage/EquipmentColumns/CharacterEquipmentPanel/CharacterEquipmentContent/CharacterStatsCenter/CharacterStats/LuckStat/Value,
	"resistance": $MenuFrame/PageHost/EquipmentPage/EquipmentColumns/CharacterEquipmentPanel/CharacterEquipmentContent/CharacterStatsCenter/CharacterStats/ResistStat/Value,
	"crit": $MenuFrame/PageHost/EquipmentPage/EquipmentColumns/CharacterEquipmentPanel/CharacterEquipmentContent/CharacterStatsCenter/CharacterStats/CritStat/Value,
	"dodge": $MenuFrame/PageHost/EquipmentPage/EquipmentColumns/CharacterEquipmentPanel/CharacterEquipmentContent/CharacterStatsCenter/CharacterStats/DodgeStat/Value,
	"move_speed": $MenuFrame/PageHost/EquipmentPage/EquipmentColumns/CharacterEquipmentPanel/CharacterEquipmentContent/CharacterStatsCenter/CharacterStats/LifestealStat/Value,
	"regen": $MenuFrame/PageHost/EquipmentPage/EquipmentColumns/CharacterEquipmentPanel/CharacterEquipmentContent/CharacterStatsCenter/CharacterStats/RegenStat/Value,
}

var selected_character_index := 0
var cached_player: Node
var inventory_filter := "all"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_trait_list_inset()
	for index in TAB_NAMES.size():
		(tab_bar.get_node(TAB_NAMES[index]) as BaseButton).pressed.connect(_select_page.bind(index))
	for index in character_slots.get_child_count():
		(character_slots.get_child(index) as BaseButton).pressed.connect(_select_character_slot.bind(index))
	var character_stage := $MenuFrame/PageHost/EquipmentPage/EquipmentColumns/CharacterEquipmentPanel/CharacterEquipmentContent/CharacterStage
	character_stage.get_node("PreviousCharacter").pressed.connect(_step_character.bind(-1))
	character_stage.get_node("NextCharacter").pressed.connect(_step_character.bind(1))
	inventory_tabs.get_node("EquipmentInventoryTab").pressed.connect(_set_inventory_filter.bind("all"))
	inventory_tabs.get_node("ItemInventoryTab").pressed.connect(_set_inventory_filter.bind("equipment"))
	inventory_tabs.get_node("CostumeInventoryTab").pressed.connect(_set_inventory_filter.bind("materials"))
	inventory_tabs.get_node("BookInventoryTab").pressed.connect(_set_inventory_filter.bind("skills"))
	_set_inventory_filter("all")
	_select_page(1)
	_select_character_slot(0)
	hide_panel()

func _add_trait_list_inset() -> void:
	if trait_list == null or trait_list.get_parent() == null:
		return
	var scroll := trait_list.get_parent() as ScrollContainer
	if scroll == null or scroll.get_meta("trait_inset_added", false):
		return
	var inset := MarginContainer.new()
	inset.name = "TraitInset"
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_theme_constant_override("margin_left", 6)
	inset.add_theme_constant_override("margin_right", 6)
	scroll.remove_child(trait_list)
	scroll.add_child(inset)
	scroll.move_child(inset, 0)
	trait_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_child(trait_list)
	scroll.set_meta("trait_inset_added", true)

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_C or event.keycode == KEY_ESCAPE:
		request_close()
		get_viewport().set_input_as_handled()

func show_for_player(player: Node) -> void:
	cached_player = player
	_connect_player_refresh_signals()
	show()
	var active_role_id := ""
	if cached_player != null and cached_player.has_method("_get_active_role_id"):
		active_role_id = str(cached_player._get_active_role_id())
	var active_index := ROLE_IDS.find(active_role_id)
	_select_page(1)
	_select_character_slot(active_index if active_index >= 0 else 0)

func _connect_player_refresh_signals() -> void:
	if cached_player == null:
		return
	for signal_name in ["health_changed", "mana_changed", "stats_changed", "active_role_changed"]:
		if cached_player.has_signal(signal_name):
			var callback := Callable(self, "_on_cached_player_changed")
			if not cached_player.is_connected(signal_name, callback):
				cached_player.connect(signal_name, callback)

func _on_cached_player_changed(_first: Variant = null, _second: Variant = null) -> void:
	_update_role_equipment_inventory()
	_update_equipment_stats()

func hide_panel() -> void:
	hide()

func request_close() -> void:
	close_requested.emit()

func _select_page(index: int) -> void:
	for page_index in PAGE_NAMES.size():
		(page_host.get_node(PAGE_NAMES[page_index]) as Control).visible = page_index == index
	character_slots.visible = index == 1
	_update_tab_state(index)

func _update_tab_state(index: int) -> void:
	for tab_index in TAB_NAMES.size():
		var tab := tab_bar.get_node(TAB_NAMES[tab_index]) as Button
		tab.modulate = Color.WHITE if tab_index == index else Color(0.58, 0.58, 0.58, 1.0)

func _select_character_slot(index: int) -> void:
	if index < 0 or index >= character_slots.get_child_count():
		return
	selected_character_index = index
	for slot_index in character_slots.get_child_count():
		(character_slots.get_child(slot_index) as BaseButton).set_pressed_no_signal(slot_index == selected_character_index)
	_update_trait_cards()
	_emit_current_character()
	_update_role_equipment_inventory()
	_update_equipment_stats()

func _step_character(direction: int) -> void:
	var character_count := character_slots.get_child_count()
	if character_count == 0:
		return
	_select_character_slot(posmod(selected_character_index + direction, character_count))

func _emit_current_character() -> void:
	var selected_portrait := role_portraits[selected_character_index] if selected_character_index < role_portraits.size() else null
	portrait.texture = selected_portrait
	equipment_portrait.texture = selected_portrait
	character_selected.emit(selected_character_index)

func _update_equipment_stats() -> void:
	if cached_player == null:
		return
	var role_id: String = get_selected_role_id()
	var role: Dictionary = {}
	for candidate in cached_player.get("roles") if cached_player.get("roles") is Array else []:
		if candidate is Dictionary and str(candidate.get("id", "")) == role_id:
			role = candidate
			break
	if role.is_empty():
		return

	var max_health := float(cached_player._get_role_max_health(role_id)) if cached_player.has_method("_get_role_max_health") else float(role.get("base_health", 0.0))
	var current_health := float(cached_player._get_role_current_health(role_id)) if cached_player.has_method("_get_role_current_health") else max_health
	var attack := float(cached_player._get_role_damage(role_id)) if cached_player.has_method("_get_role_damage") else float(role.get("damage", 0.0))
	var armor := float(cached_player.get_role_armor(role_id)) if cached_player.has_method("get_role_armor") else float(role.get("armor", 0.0))
	var reduction := float(cached_player._get_role_damage_reduction_rate(role_id)) if cached_player.has_method("_get_role_damage_reduction_rate") else 0.0
	var resistance := float(cached_player.get_status_resistance(role_id)) if cached_player.has_method("get_status_resistance") else float(role.get("status_resistance", 0.0))
	var crit := float(cached_player._get_role_critical_chance(role_id)) if cached_player.has_method("_get_role_critical_chance") else 0.0
	var dodge := float(cached_player._get_role_dodge_chance(role_id)) if cached_player.has_method("_get_role_dodge_chance") else float(role.get("base_dodge", 0.0))
	var move_speed := float(cached_player._get_role_move_speed(role_id)) if cached_player.has_method("_get_role_move_speed") else float(role.get("move_speed", 0.0))
	var equipment_bonus: Dictionary = cached_player._get_role_equipment_bonus_summary(role_id) if cached_player.has_method("_get_role_equipment_bonus_summary") else {}
	var regen := float(equipment_bonus.get("regen_per_second", 0.0))
	if cached_player.has_method("_get_attribute_health_regen_per_second"):
		regen += float(cached_player._get_attribute_health_regen_per_second())
	var blessing_regen := max_health * PLAYER_BLESSING_SYSTEM.get_divine_grace_regen_ratio_per_tick(cached_player) / PLAYER_BLESSING_SYSTEM.DIVINE_GRACE_REGEN_INTERVAL
	regen += blessing_regen
	var energy_gain := 1.0
	if cached_player.has_method("_get_role_total_ultimate_energy_gain_multiplier"):
		energy_gain = float(cached_player._get_role_total_ultimate_energy_gain_multiplier(role_id))

	_set_stat_text("health", "生命值  %.0f / %.0f" % [current_health, max_health])
	_set_stat_text("energy", "回能效率  %.0f%%" % [energy_gain * 100.0])
	_set_stat_text("attack", "攻击   %.0f" % attack)
	_set_stat_text("armor", "防御   %.0f" % armor)
	_set_stat_text("reduction", "减伤   %.1f%%" % [reduction * 100.0])
	_set_stat_text("resistance", "抗性  %.1f%%" % [resistance * 100.0])
	_set_stat_text("crit", "暴击   %.1f%%" % [crit * 100.0])
	_set_stat_text("dodge", "闪避   %.1f%%" % [dodge * 100.0])
	_set_stat_text("move_speed", "移动速度   %.0f" % move_speed)
	_set_stat_text("regen", "生命回复   %.2f" % regen)

func _update_role_equipment_inventory() -> void:
	var equipment_levels: Dictionary = {}
	if cached_player != null:
		var role_id := get_selected_role_id()
		if cached_player.has_method("_get_role_equipment_levels"):
			equipment_levels = cached_player._get_role_equipment_levels(role_id)
		else:
			var role_equipment_value: Variant = cached_player.get("role_equipment_levels")
			if role_equipment_value is Dictionary:
				var role_levels: Variant = role_equipment_value.get(role_id, {})
				if role_levels is Dictionary:
					equipment_levels = role_levels

	var equipment_ids: Array[String] = []
	if inventory_filter == "all" or inventory_filter == "equipment":
		for equipment_id in PLAYER_EQUIPMENT_FLOW.EQUIPMENT_DEFINITIONS.keys():
			if int(equipment_levels.get(str(equipment_id), 0)) > 0:
				equipment_ids.append(str(equipment_id))
	equipment_ids.sort()

	for index in equipment_inventory_grid.get_child_count():
		var slot := equipment_inventory_grid.get_child(index) as PanelContainer
		var item_label := slot.get_node_or_null("ItemLabel") as Label
		if item_label == null:
			item_label = Label.new()
			item_label.name = "ItemLabel"
			item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			item_label.add_theme_font_size_override("font_size", 12)
			slot.add_child(item_label)
		item_label.text = ""
		slot.tooltip_text = ""
		if index >= equipment_ids.size():
			continue
		var equipment_id := equipment_ids[index]
		var definition: Dictionary = PLAYER_EQUIPMENT_FLOW.EQUIPMENT_DEFINITIONS.get(equipment_id, {})
		var count := int(equipment_levels.get(equipment_id, 0))
		item_label.text = "%s\n× %d" % [str(definition.get("title", equipment_id)), count]
		slot.tooltip_text = str(definition.get("description", ""))

func _set_inventory_filter(filter_id: String) -> void:
	if not INVENTORY_FILTERS.has(filter_id):
		return
	inventory_filter = filter_id
	var tab_names := ["EquipmentInventoryTab", "ItemInventoryTab", "CostumeInventoryTab", "BookInventoryTab"]
	for index in tab_names.size():
		var tab := inventory_tabs.get_node(tab_names[index]) as Button
		tab.modulate = Color.WHITE if INVENTORY_FILTERS[index] == inventory_filter else Color(0.58, 0.58, 0.58, 1.0)
	_update_role_equipment_inventory()

func _set_stat_text(stat_id: String, value: String) -> void:
	var label: Label = stat_labels.get(stat_id)
	if label != null:
		label.text = value

func _update_trait_cards() -> void:
	var role_id: String = ROLE_IDS[selected_character_index] if selected_character_index < ROLE_IDS.size() else ROLE_IDS[0]
	var traits: Array = ROLE_TRAITS.get(role_id, [])
	trait_list.custom_minimum_size = Vector2.ZERO
	while trait_list.get_child_count() < traits.size():
		var card := PanelContainer.new()
		card.name = "Trait%02d" % (trait_list.get_child_count() + 1)
		card.custom_minimum_size = Vector2(0, 0)
		card.add_theme_stylebox_override("panel", trait_list.get_child(0).get_theme_stylebox("panel"))
		trait_list.add_child(card)
	for index in trait_list.get_child_count():
		var card := trait_list.get_child(index) as PanelContainer
		card.custom_minimum_size = Vector2(0, 0)
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var old_text := card.get_node_or_null("Text")
		if old_text != null:
			card.remove_child(old_text)
			old_text.queue_free()
		var old_content := card.get_node_or_null("Content")
		if old_content != null:
			card.remove_child(old_content)
			old_content.queue_free()
		card.visible = index < traits.size()
		if index >= traits.size():
			continue
		var data: Dictionary = traits[index]
		var content := VBoxContainer.new()
		content.name = "Content"
		content.add_theme_constant_override("separation", 3)
		card.add_child(content)
		var title := Label.new()
		title.text = str(data.get("title", "特性"))
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52, 1.0))
		content.add_child(title)
		var effect_type := Label.new()
		effect_type.text = "◆ %s" % str(data.get("type", "效果"))
		effect_type.add_theme_font_size_override("font_size", 13)
		effect_type.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0, 1.0))
		content.add_child(effect_type)
		var body := Label.new()
		body.text = str(data.get("description", ""))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", 14)
		content.add_child(body)
		for detail_value in data.get("details", []):
			if detail_value is not Dictionary:
				continue
			var detail: Dictionary = detail_value
			var detail_title := Label.new()
			detail_title.text = str(detail.get("title", "效果说明"))
			detail_title.add_theme_font_size_override("font_size", 14)
			detail_title.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0, 1.0))
			content.add_child(detail_title)
			var detail_body := Label.new()
			detail_body.text = str(detail.get("text", ""))
			detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail_body.add_theme_font_size_override("font_size", 14)
			content.add_child(detail_body)

func get_selected_role_id() -> String:
	return ROLE_IDS[selected_character_index] if selected_character_index < ROLE_IDS.size() else ROLE_IDS[0]

func get_selected_character_index() -> int:
	return selected_character_index

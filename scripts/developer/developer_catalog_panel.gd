extends VBoxContainer

const BASIC := preload("res://scripts/player/player_swordsman_basic_build.gd")
const THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
signal action_requested(request: Dictionary)

var kind := ""
var catalog: Array = []
var selected_id := ""
var search: LineEdit
var role_filter: OptionButton
var list: VBoxContainer
var details: VBoxContainer
var tier: OptionButton
var amount: SpinBox
var description: Label
var selected_tier := 1
var role_id := ""
var operation_amount := 1

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	search = LineEdit.new()
	search.placeholder_text = "搜索名称"
	add_child(search)
	search.text_changed.connect(func(_text): _rebuild_list())
	role_filter = OptionButton.new()
	role_filter.visible = kind == "skill"
	add_child(role_filter)
	role_filter.item_selected.connect(func(index):
		role_id = str(role_filter.get_item_metadata(index))
		selected_id = ""
		_rebuild_list()
	)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(175, 310)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(detail_scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	detail_scroll.add_child(details)
	_rebuild_list()

func set_catalog(options: Array) -> void:
	if catalog == options:
		return
	catalog = options.duplicate(true)
	if not is_node_ready():
		return
	if kind == "skill":
		role_filter.clear()
		var seen: Array = []
		for option in catalog:
			var role: String = str(option.get("role_id", ""))
			if seen.has(role):
				continue
			seen.append(role)
			role_filter.add_item(str(option.get("role_name", role)))
			role_filter.set_item_metadata(role_filter.item_count - 1, role)
		if not seen.has(role_id):
			role_id = str(seen[0]) if not seen.is_empty() else ""
		role_filter.select(seen.find(role_id))
	_rebuild_list()

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _rebuild_list() -> void:
	if list == null:
		return
	_clear(list)
	var visible_options: Array = []
	for option in catalog:
		if kind == "skill" and str(option.get("role_id", "")) != role_id:
			continue
		if not search.text.is_empty() and not str(option["title"]).contains(search.text):
			continue
		visible_options.append(option)
	var selection_visible := false
	for option in visible_options:
		selection_visible = selection_visible or option["id"] == selected_id
	if not selection_visible:
		selected_id = str(visible_options[0]["id"]) if not visible_options.is_empty() else ""
	for option in visible_options:
		var button := Button.new()
		button.text = str(option["title"])
		button.custom_minimum_size = Vector2(165, 38)
		button.toggle_mode = true
		button.button_pressed = option["id"] == selected_id
		THEME.apply_button_style(button, "primary" if button.button_pressed else "")
		button.pressed.connect(func():
			selected_id = str(option["id"])
			_rebuild_list()
		)
		list.add_child(button)
	_show_detail()

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(label)
	return label

func _button(text: String, request: Dictionary, enabled: bool = true) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.custom_minimum_size.y = 34
	THEME.apply_button_style(button)
	details.add_child(button)
	button.pressed.connect(func(): action_requested.emit(request))

func _selected() -> Dictionary:
	for option in catalog:
		if option["id"] == selected_id:
			return option
	return {}

func _show_detail() -> void:
	amount = null
	_clear(details)
	var option := _selected()
	if option.is_empty():
		_label("没有匹配的内容")
		return
	_label(str(option["title"]))
	if kind == "skill":
		_show_skill(option)
		return
	if kind == "blessing":
		tier = OptionButton.new()
		for entry in option["tiers"]:
			tier.add_item("%s 阶 · 当前 ×%d" % [["I", "II", "III", "IV"][int(entry["tier"]) - 1], entry["count"]], int(entry["tier"]))
		tier.select(maxi(0, tier.get_item_index(selected_tier)))
		selected_tier = tier.get_selected_id()
		details.add_child(tier)
		tier.item_selected.connect(func(_index):
			selected_tier = tier.get_selected_id()
			_show_detail()
		)
		for entry in option["tiers"]:
			if int(entry["tier"]) == selected_tier:
				_label(str(entry["description"]))
	else:
		_label("当前持有：×%d\n每份效果：%s" % [option["count"], option["description"]])
	_label("操作数量（仅本局调试）")
	amount = SpinBox.new()
	amount.min_value = 1
	amount.max_value = 999
	amount.value = operation_amount
	amount.value_changed.connect(func(value): operation_amount = int(value))
	details.add_child(amount)
	for entry in [["添加", "add"], ["减少", "remove"], ["清空此项", "clear"]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 34
		THEME.apply_button_style(button)
		details.add_child(button)
		button.pressed.connect(func():
			action_requested.emit({"kind": kind, "id": selected_id, "tier": selected_tier, "operation": entry[1], "amount": int(amount.value)})
		)
	if kind == "blessing":
		var bulk := Button.new()
		bulk.text = "按此阶级与数量添加全部现行祝福"
		bulk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		THEME.apply_button_style(bulk)
		details.add_child(bulk)
		bulk.pressed.connect(func():
			action_requested.emit({"kind": "all_blessings", "tier": selected_tier, "operation": "add", "amount": int(amount.value)})
		)

func _show_skill(option: Dictionary) -> void:
	var unlocked: bool = bool(option["unlocked"])
	var maximum: int = int(option["max_level"])
	_label("LV%d / %d" % [option["level"], maximum] if unlocked else "尚未解锁")
	_label(str(option["description"]))
	var base := {"kind": "skill", "id": selected_id, "role_id": option["role_id"]}
	if not unlocked:
		_button("解锁技能", base.merged({"operation": "unlock"}))
		return
	if maximum <= 1:
		return
	amount = SpinBox.new()
	amount.min_value = int(option["min_level"])
	amount.max_value = maximum
	amount.value = int(option["level"])
	details.add_child(amount)
	var apply := Button.new()
	apply.text = "设置为指定等级"
	THEME.apply_button_style(apply, "primary")
	details.add_child(apply)
	apply.pressed.connect(func():
		action_requested.emit(base.merged({"operation": "set", "amount": int(amount.value)}))
	)
	_button("等级 +1", base.merged({"operation": "add"}), int(option["level"]) < maximum)
	_button("重置当前技能 build", base.merged({"operation": "reset"}))
	if preload("res://scripts/player/player_skill_level_system.gd").is_custom_basic(selected_id):
		var build = preload("res://scripts/player/player_skill_level_system.gd").basic_build(selected_id)
		for stage in build.STAGES:
			_label("LV%d 强化" % stage)
			for branch in build.OPTIONS[stage]:
				var selected: bool = str(option["choices"].get(str(stage), "")) == branch["key"]
				_button(("%s（已选）" if selected else "%s") % branch["title"], base.merged({"operation": "branch", "stage": stage, "choice": branch["key"]}), int(option["level"]) >= stage and not selected)
				_label(str(branch["description"]))

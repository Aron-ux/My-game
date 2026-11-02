extends CanvasLayer

signal closed
signal close_requested

const LAYOUT_PATH := "res://data/catgirlsurvivor/village_menu_layout.json"
const ART_PATH := "res://assets/ui/catgirlsurvivor/"
const TAB_NAMES := ["CharacterTab", "EquipmentTab", "ArtifactTab", "SkillTab", "SettingTab"]
const TAB_LABELS := ["角色", "装备", "神器", "技能", "设置"]
const TAB_HANDLERS := [
	"CharacterTabHandler",
	"EquipmentTabHandler",
	"ArtifactTabHandler",
	"SkillTabHandler",
	"SettingTabHandler"
]
const TAB_SPRITES := [
	"character_on",
	"equipment_on",
	"artifacts_on",
	"skill_on",
	"setting_on"
]

var selected_tab := 0
var backdrop: ColorRect
var menu_root: Control
var tabs: Array[TextureButton] = []
var pages: Array[Control] = []
var _scale_factor := 1.0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_menu()
	get_viewport().size_changed.connect(_layout)
	_layout()


func open_menu() -> void:
	selected_tab = 0
	_refresh_tab_state()
	visible = true
	_layout()


func close_menu() -> void:
	visible = false
	close_requested.emit()
	closed.emit()


func show_for_player(_player: Node = null) -> void:
	open_menu()


func hide_panel() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				close_menu()
			KEY_LEFT, KEY_Q:
				_select_tab(selected_tab - 1)
			KEY_RIGHT, KEY_E:
				_select_tab(selected_tab + 1)
			_:
				return
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				_select_tab(selected_tab - 1)
			JOY_BUTTON_RIGHT_SHOULDER:
				_select_tab(selected_tab + 1)
			JOY_BUTTON_B:
				close_menu()
			_:
				return
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.7:
		if event.axis == JOY_AXIS_LEFT_X:
			_select_tab(selected_tab + (1 if event.axis_value > 0 else -1))
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()


func _build_menu() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	if not parsed is Dictionary:
		push_error("Cat village menu layout could not be read.")
		return

	backdrop = ColorRect.new()
	backdrop.name = "UnityMenuBackdrop"
	backdrop.color = Color(0, 0, 0, 0.68)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	menu_root = Control.new()
	menu_root.name = "VillageMenuPageReplica"
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_root.size = Vector2(640, 360)
	menu_root.position = -menu_root.size * 0.5
	add_child(menu_root)

	var anchor := _find_node(parsed, "Anchor")
	if anchor.is_empty():
		return
	for child in anchor.get("children", []):
		match str(child.get("name", "")):
			"Bg":
				_build_node(child, menu_root)
			"Top":
				_build_node(child, menu_root)
			"Handlers":
				_build_pages(child)

	_build_tabs()
	_layout()


func _build_tabs() -> void:
	var tab_parent := Control.new()
	tab_parent.name = "ReplicaTabButtons"
	tab_parent.position = Vector2(160, 10)
	tab_parent.size = Vector2(320, 34)
	menu_root.add_child(tab_parent)

	for index in TAB_NAMES.size():
		var tab := TextureButton.new()
		tab.name = TAB_NAMES[index]
		tab.position = Vector2(index * 68.75, 1)
		tab.size = Vector2(45, 32)
		tab.stretch_mode = TextureButton.STRETCH_SCALE
		tab.texture_normal = _texture_by_name(TAB_SPRITES[index])
		tab.texture_hover = tab.texture_normal
		tab.texture_pressed = tab.texture_normal
		tab.focus_mode = Control.FOCUS_ALL
		tab.tooltip_text = TAB_LABELS[index]
		tab.pressed.connect(_select_tab.bind(index))
		tab_parent.add_child(tab)
		tabs.append(tab)


func _build_pages(handlers: Dictionary) -> void:
	for index in TAB_HANDLERS.size():
		var handler := _find_node(handlers, TAB_HANDLERS[index])
		if handler.is_empty():
			continue
		var content: Array = handler.get("children", [])
		if content.is_empty():
			continue
		var page_data: Dictionary = content[0]
		var page := Control.new()
		page.name = TAB_HANDLERS[index] + "Replica"
		page.position = Vector2(0, 22)
		page.size = Vector2(640, 302)
		menu_root.add_child(page)
		for child in page_data.get("children", []):
			_build_node(child, page)
		pages.append(page)


func _build_node(data: Dictionary, parent: Control) -> Control:
	if str(data.get("name", "")) == "TabButtons":
		return parent
	var rect: Dictionary = data.get("rect_transform", {})
	var size_delta := _vector(rect.get("size_delta", {}))
	var anchor_min := _vector(rect.get("anchor_min", {}))
	var anchor_max := _vector(rect.get("anchor_max", {}))
	var pivot := _vector(rect.get("pivot", {"x": 0.5, "y": 0.5}))
	var anchored := _vector(rect.get("anchored_position", {}))
	var control := Control.new()
	control.name = str(data.get("name", "UnityNode"))
	control.anchor_left = anchor_min.x
	control.anchor_right = anchor_max.x
	control.anchor_top = 1.0 - anchor_max.y
	control.anchor_bottom = 1.0 - anchor_min.y
	control.offset_left = anchored.x - pivot.x * size_delta.x
	control.offset_right = anchored.x + (1.0 - pivot.x) * size_delta.x
	control.offset_top = -anchored.y - pivot.y * size_delta.y
	control.offset_bottom = -anchored.y + (1.0 - pivot.y) * size_delta.y
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.visible = bool(data.get("active", true))
	parent.add_child(control)

	var is_button := false
	for component in data.get("components", []):
		var script_name := str(component.get("script", ""))
		if script_name == "Image":
			var texture := _texture_for_component(component)
			if texture != null:
				var image := TextureRect.new()
				image.name = "UnityImage"
				image.texture = texture
				image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				image.stretch_mode = TextureRect.STRETCH_SCALE
				image.mouse_filter = Control.MOUSE_FILTER_IGNORE
				control.add_child(image)
		elif script_name == "TextMeshProUGUI":
			var text_value := str(component.get("m_Text", ""))
			if not text_value.is_empty():
				var label := Label.new()
				label.name = "UnityText"
				label.text = _display_text(text_value)
				label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				label.add_theme_font_size_override("font_size", 11)
				label.add_theme_color_override("font_color", Color.WHITE)
				control.add_child(label)
		elif script_name in ["Button", "CGSButton", "Selectable", "CGSSelectable",
				"VilageMenuTabButton"]:
			is_button = true

	if is_button:
		var button := Button.new()
		button.name = "UnityInteraction"
		button.text = ""
		button.flat = true
		button.focus_mode = Control.FOCUS_ALL
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = str(data.get("name", ""))
		button.pressed.connect(_on_reconstructed_control_pressed.bind(str(data.get("name", ""))))
		control.add_child(button)
		control.mouse_filter = Control.MOUSE_FILTER_STOP

	for child in data.get("children", []):
		_build_node(child, control)
	return control


func _display_text(value: String) -> String:
	return value.replace("<sprite name=\"PS_leftShoulder_icon\">", "LB") \
		.replace("<sprite name=\"PS_rightShoulder_icon\">", "RB") \
		.replace("<sprite name=\"PS_buttonSouth_Icon\">", "A") \
		.replace("<sprite name=\"PS_buttonEast_Icon\">", "B")


func _on_reconstructed_control_pressed(_node_name: String) -> void:
	pass


func _texture_for_component(component: Dictionary) -> Texture2D:
	var sprite_id := int(component.get("m_Sprite", 0))
	var sprite_name := str(component.get("m_Sprite_name", ""))
	if sprite_id <= 0 or sprite_name.is_empty():
		return null
	var safe_name := sprite_name.replace(" ", "_")
	var path := ART_PATH + str(sprite_id) + "_" + safe_name + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _texture_by_name(sprite_name: String) -> Texture2D:
	var dir := DirAccess.open(ART_PATH)
	if dir == null:
		return null
	dir.list_dir_begin()
	var file := dir.get_next()
	while not file.is_empty():
		if file.ends_with("_" + sprite_name + ".png"):
			dir.list_dir_end()
			return load(ART_PATH + file) as Texture2D
		file = dir.get_next()
	dir.list_dir_end()
	return null


func _select_tab(index: int) -> void:
	selected_tab = posmod(index, TAB_HANDLERS.size())
	_refresh_tab_state()


func _refresh_tab_state() -> void:
	for index in tabs.size():
		tabs[index].modulate = Color.WHITE if index == selected_tab else Color(0.58, 0.58, 0.58, 1)
	for index in pages.size():
		pages[index].visible = index == selected_tab


func _layout() -> void:
	if menu_root == null:
		return
	var viewport := get_viewport().get_visible_rect().size
	_scale_factor = minf(viewport.x / 640.0, viewport.y / 360.0)
	menu_root.scale = Vector2.ONE * _scale_factor
	menu_root.position = (viewport - menu_root.size * _scale_factor) * 0.5


func _vector(value: Dictionary) -> Vector2:
	return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))


func _find_node(data: Dictionary, target: String) -> Dictionary:
	if str(data.get("name", "")) == target:
		return data
	for child in data.get("children", []):
		var found := _find_node(child, target)
		if not found.is_empty():
			return found
	return {}

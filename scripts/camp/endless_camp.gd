extends Node2D

const GAME_SCENE_PATH := "res://scenes/main.tscn"
const MOVEMENT_TUTORIAL_SCENE_PATH := "res://scenes/movement_tutorial.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

const INTERACTABLE_TEXT := {
	"swordsman": {
		"name": "\u5251\u58eb",
		"prompt": "\u5251\u58eb\u6682\u672a\u5f00\u653e\u5bf9\u8bdd"
	},
	"gunner": {
		"name": "\u67aa\u624b",
		"prompt": "\u67aa\u624b\u6682\u672a\u5f00\u653e\u5bf9\u8bdd"
	},
	"mage": {
		"name": "\u672f\u5e08",
		"prompt": "\u672f\u5e08\u6682\u672a\u5f00\u653e\u5bf9\u8bdd"
	},
	"blacksmith": {
		"name": "\u94c1\u5320",
		"prompt": "\u6253\u5f00\u94c1\u5320\u5546\u5e97"
	},
	"ruan_dog": {
		"name": "阮狗",
		"prompt": "和阮狗说话"
	},
	"endless_portal": {
		"name": "\u65e0\u5c3d\u4f20\u9001\u95e8",
		"prompt": "\u8fdb\u5165\u65e0\u5c3d\u6218\u6597"
	}
}
const DIALOGUE_LINES := {
	"ruan_dog": [
		"汪。你就是今天负责出发的人？",
		"营地里没什么秘密，只有还没被闻出来的线索。",
		"出发前记得检查装备。活着回来，再给我带根骨头。"
	]
}

@onready var prompt_label: Label = $CanvasLayer/PromptLabel
@onready var message_label: Label = $CanvasLayer/MessageLabel
@onready var dialogue_panel: PanelContainer = $CanvasLayer/DialoguePanel
@onready var dialogue_title: Label = $CanvasLayer/DialoguePanel/MarginContainer/DialogueContent/TextContent/Title
@onready var dialogue_body: Label = $CanvasLayer/DialoguePanel/MarginContainer/DialogueContent/TextContent/Body
@onready var dialogue_hint: Label = $CanvasLayer/DialoguePanel/MarginContainer/DialogueContent/TextContent/Hint
@onready var shop_panel: PanelContainer = $CanvasLayer/ShopPanel
@onready var shop_title: Label = $CanvasLayer/ShopPanel/MarginContainer/ShopContent/Title
@onready var shop_body: Label = $CanvasLayer/ShopPanel/MarginContainer/ShopContent/Body
@onready var tutorial_prompt_panel: PanelContainer = $CanvasLayer/TutorialPromptPanel
@onready var tutorial_prompt_title: Label = $CanvasLayer/TutorialPromptPanel/MarginContainer/TutorialPromptContent/Title
@onready var tutorial_prompt_body: Label = $CanvasLayer/TutorialPromptPanel/MarginContainer/TutorialPromptContent/Body
@onready var tutorial_yes_button: Button = $CanvasLayer/TutorialPromptPanel/MarginContainer/TutorialPromptContent/ButtonRow/YesButton
@onready var tutorial_no_button: Button = $CanvasLayer/TutorialPromptPanel/MarginContainer/TutorialPromptContent/ButtonRow/NoButton
@onready var camp_player: Node2D = $CampPlayer
@onready var characters_root: Node2D = $Characters

var focused_interactables: Array[Node] = []
var camp_role_id: String = "swordsman"
var active_dialogue_lines: Array[String] = []
var active_dialogue_index: int = 0

func _ready() -> void:
	get_tree().paused = false
	camp_role_id = _resolve_camp_role_id()
	_apply_camp_player_role(camp_role_id)
	_apply_character_stand_visibility(camp_role_id)
	_setup_ui()
	_apply_interactable_texts()
	_connect_interactables()
	_update_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if dialogue_panel.visible and event.keycode == KEY_ESCAPE:
			_close_dialogue()
			_mark_input_handled()
			return
		if tutorial_prompt_panel.visible and event.keycode == KEY_ESCAPE:
			_close_tutorial_prompt()
			_mark_input_handled()
			return
		if shop_panel.visible and event.keycode == KEY_ESCAPE:
			_close_shop()
			_mark_input_handled()
			return
		if GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_INTERACT):
			_handle_interact()
			_mark_input_handled()
			return
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _setup_ui() -> void:
	prompt_label.text = ""
	prompt_label.visible = false
	message_label.text = ""
	message_label.visible = false
	dialogue_panel.visible = false
	dialogue_title.text = ""
	dialogue_body.text = ""
	dialogue_hint.text = ""
	dialogue_panel.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(SURVIVORS_THEME.COLOR_BG, SURVIVORS_THEME.COLOR_BORDER_GOLD, 2, 16, 16.0))
	shop_panel.visible = false
	shop_title.text = "\u94c1\u5320"
	shop_body.text = "\u5546\u5e97\u6682\u65e0\u5546\u54c1"
	shop_panel.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(SURVIVORS_THEME.COLOR_BG, SURVIVORS_THEME.COLOR_BORDER_GOLD, 2, 16, 16.0))
	tutorial_prompt_panel.visible = false
	tutorial_prompt_title.text = "\u65b0\u624b\u6559\u5b66"
	tutorial_prompt_body.text = "\u662f\u5426\u8fdb\u5165\u65b0\u624b\u6559\u5b66\uff1f"
	tutorial_yes_button.pressed.connect(_enter_movement_tutorial)
	tutorial_no_button.pressed.connect(_enter_endless_battle_direct)

func _resolve_camp_role_id() -> String:
	var run_data: Dictionary = SAVE_MANAGER.load_run(-1, SAVE_MANAGER.MODE_ENDLESS)
	if run_data.is_empty():
		return "swordsman"
	var roles: Array = run_data.get("roles", [])
	if roles.is_empty():
		return "swordsman"
	var active_role_index: int = clampi(int(run_data.get("active_role_index", 0)), 0, roles.size() - 1)
	var role_data: Variant = roles[active_role_index]
	if role_data is Dictionary:
		var role_id := str((role_data as Dictionary).get("id", "swordsman"))
		if INTERACTABLE_TEXT.has(role_id):
			return role_id
	return "swordsman"

func _apply_camp_player_role(role_id: String) -> void:
	if camp_player != null and camp_player.has_method("set_role_visual"):
		camp_player.set_role_visual(role_id)

func _apply_character_stand_visibility(role_id: String) -> void:
	var stand_name := _get_character_stand_name(role_id)
	if stand_name == "" or characters_root == null:
		return
	var stand := characters_root.get_node_or_null(stand_name) as Node2D
	if stand != null:
		stand.visible = false
		var interactable := stand.get_node_or_null("Interactable")
		if interactable != null:
			interactable.set("enabled", false)

func _get_character_stand_name(role_id: String) -> String:
	match role_id:
		"swordsman":
			return "Swordsman"
		"gunner":
			return "Gunner"
		"mage":
			return "Mage"
		_:
			return ""

func _apply_interactable_texts() -> void:
	for node in get_tree().get_nodes_in_group("camp_interactable"):
		var interactable_id := str(node.get("interactable_id"))
		var text_data: Dictionary = INTERACTABLE_TEXT.get(interactable_id, {})
		if text_data.is_empty():
			continue
		node.set("display_name", str(text_data.get("name", interactable_id)))
		node.set("prompt_text", str(text_data.get("prompt", "")))
		var label := node.get_parent().get_node_or_null("NameLabel") as Label
		if label != null:
			label.text = str(text_data.get("name", interactable_id))

func _connect_interactables() -> void:
	for node in get_tree().get_nodes_in_group("camp_interactable"):
		if not node.has_signal("focus_changed") or not node.has_signal("interacted"):
			continue
		if not node.is_connected("focus_changed", Callable(self, "_on_interactable_focus_changed")):
			node.connect("focus_changed", Callable(self, "_on_interactable_focus_changed"))
		if not node.is_connected("interacted", Callable(self, "_on_interactable_interacted")):
			node.connect("interacted", Callable(self, "_on_interactable_interacted"))

func _handle_interact() -> void:
	if dialogue_panel.visible:
		_advance_dialogue()
		return
	if tutorial_prompt_panel.visible:
		return
	if shop_panel.visible:
		_close_shop()
		return
	var interactable: Node = _get_best_interactable()
	if interactable == null or not interactable.has_method("try_interact"):
		return
	interactable.try_interact()

func _on_interactable_focus_changed(interactable: Node, focused: bool) -> void:
	if focused:
		if not focused_interactables.has(interactable):
			focused_interactables.append(interactable)
	else:
		focused_interactables.erase(interactable)
	_update_prompt()

func _on_interactable_interacted(interactable: Node) -> void:
	var kind := str(interactable.get("interaction_kind"))
	match kind:
		"portal":
			_open_tutorial_prompt()
		"shop":
			_open_shop()
		"dialogue":
			_open_dialogue(interactable)
		_:
			_show_message("\u73b0\u5728\u8fd8\u4e0d\u80fd\u4ea4\u4e92")

func _get_best_interactable() -> Node:
	for index in range(focused_interactables.size() - 1, -1, -1):
		var interactable: Node = focused_interactables[index]
		if interactable == null or not is_instance_valid(interactable):
			focused_interactables.remove_at(index)
			continue
		if interactable.has_method("can_interact") and bool(interactable.can_interact()):
			return interactable
	return null

func _update_prompt() -> void:
	if dialogue_panel.visible or shop_panel.visible or tutorial_prompt_panel.visible:
		prompt_label.visible = false
		prompt_label.text = ""
		return
	var interactable: Node = _get_best_interactable()
	if interactable == null:
		prompt_label.visible = false
		prompt_label.text = ""
		return
	var key_name := GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_INTERACT))
	var text := str(interactable.get_prompt_text()) if interactable.has_method("get_prompt_text") else str(interactable.get("display_name"))
	prompt_label.text = "[%s] %s" % [key_name, text]
	prompt_label.visible = true

func _open_dialogue(interactable: Node) -> void:
	var interactable_id := str(interactable.get("interactable_id"))
	var lines_value: Variant = DIALOGUE_LINES.get(interactable_id, [])
	if not (lines_value is Array) or (lines_value as Array).is_empty():
		_show_message("\u73b0\u5728\u8fd8\u4e0d\u80fd\u4ea4\u4e92")
		return
	active_dialogue_lines.clear()
	for line in lines_value:
		active_dialogue_lines.append(str(line))
	active_dialogue_index = 0
	_close_shop()
	_close_tutorial_prompt()
	_show_message("")
	dialogue_title.text = str(interactable.get("display_name"))
	dialogue_panel.visible = true
	_set_camp_player_movement_enabled(false)
	_show_dialogue_line()
	_update_prompt()

func _advance_dialogue() -> void:
	if not dialogue_panel.visible:
		return
	active_dialogue_index += 1
	if active_dialogue_index >= active_dialogue_lines.size():
		_close_dialogue()
		return
	_show_dialogue_line()

func _show_dialogue_line() -> void:
	dialogue_body.text = active_dialogue_lines[active_dialogue_index]
	var key_name := GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_INTERACT))
	var action_text := "结束" if active_dialogue_index == active_dialogue_lines.size() - 1 else "下一句"
	dialogue_hint.text = "[%s] %s  ·  [Esc] 结束" % [key_name, action_text]

func _close_dialogue() -> void:
	if not dialogue_panel.visible:
		return
	dialogue_panel.visible = false
	active_dialogue_lines.clear()
	active_dialogue_index = 0
	dialogue_title.text = ""
	dialogue_body.text = ""
	dialogue_hint.text = ""
	_set_camp_player_movement_enabled(true)
	_update_prompt()

func _set_camp_player_movement_enabled(enabled: bool) -> void:
	if camp_player == null:
		return
	camp_player.set_physics_process(enabled)
	if not enabled and camp_player.has_method("stop_movement"):
		camp_player.stop_movement()

func _open_shop() -> void:
	shop_panel.visible = true
	_show_message("")
	_update_prompt()

func _close_shop() -> void:
	shop_panel.visible = false
	_update_prompt()

func _open_tutorial_prompt() -> void:
	_close_shop()
	_show_message("")
	tutorial_prompt_panel.visible = true
	tutorial_yes_button.grab_focus()
	_update_prompt()

func _close_tutorial_prompt() -> void:
	tutorial_prompt_panel.visible = false
	_update_prompt()

func _enter_movement_tutorial() -> void:
	_close_tutorial_prompt()
	get_tree().paused = false
	get_tree().change_scene_to_file(MOVEMENT_TUTORIAL_SCENE_PATH)

func _show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = text != ""

func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()

func _enter_endless_battle_direct() -> void:
	_close_tutorial_prompt()
	if SAVE_MANAGER.has_save(-1, SAVE_MANAGER.MODE_ENDLESS):
		SAVE_MANAGER.request_continue()
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

extends Area2D

signal focus_changed(interactable: Node, focused: bool)
signal interacted(interactable: Node)

@export var interactable_id: String = ""
@export var display_name: String = ""
@export var prompt_text: String = ""
@export var interaction_kind: String = "dialogue"
@export var enabled: bool = true

var _player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func can_interact() -> bool:
	return enabled and _player_inside

func get_prompt_text() -> String:
	if prompt_text != "":
		return prompt_text
	if display_name != "":
		return display_name
	return interactable_id

func try_interact() -> bool:
	if not can_interact():
		return false
	interacted.emit(self)
	return true

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("camp_player"):
		return
	_player_inside = true
	focus_changed.emit(self, true)

func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("camp_player"):
		return
	_player_inside = false
	focus_changed.emit(self, false)

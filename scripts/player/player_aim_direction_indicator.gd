extends Node2D

## World-space visual hint for the direction the player's skills are aimed.
## This node is visual only: it never changes facing_direction or attack logic.

const DIRECTION_DECORATION := preload("res://assets/UI/cursor/direction_pointer.svg")
const INDICATOR_DISTANCE := 92.0
const INDICATOR_SCALE := Vector2(0.24, 0.50)
const INDICATOR_ALPHA := 0.50

var owner_player: Node2D
var direction_sprite: Sprite2D

func setup(player: Node2D) -> void:
	owner_player = player
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 72
	top_level = false
	direction_sprite = Sprite2D.new()
	direction_sprite.name = "DirectionDecoration"
	direction_sprite.texture = DIRECTION_DECORATION
	direction_sprite.scale = INDICATOR_SCALE
	direction_sprite.modulate = Color(1.0, 0.95, 0.72, INDICATOR_ALPHA)
	direction_sprite.position = Vector2.ZERO
	add_child(direction_sprite)
	set_process(true)

func _process(delta: float) -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		visible = false
		return

	var tree := get_tree()
	var paused := tree != null and tree.paused
	var main := owner_player.get_parent()
	var blocked_by_ui := false
	if main != null:
		var character_panel = main.get("character_panel")
		var camp_menu = main.get("cat_village_menu")
		var level_up_ui = main.get("level_up_ui")
		var pause_menu = main.get("pause_menu")
		blocked_by_ui = (
			_is_visible_control(character_panel)
			or _is_visible_control(camp_menu)
			or _is_visible_control(level_up_ui)
			or _is_visible_control(pause_menu)
		)

	visible = not owner_player.is_dead and not paused and not blocked_by_ui
	if not visible:
		return

	var mouse_direction := owner_player.get_global_mouse_position() - owner_player.global_position
	if mouse_direction.length_squared() <= 16.0:
		mouse_direction = owner_player.get("facing_direction") as Vector2
	if mouse_direction.length_squared() <= 0.001:
		mouse_direction = Vector2.RIGHT

	position = mouse_direction.normalized() * INDICATOR_DISTANCE
	rotation = mouse_direction.angle()

func _is_visible_control(value: Variant) -> bool:
	return value is CanvasItem and is_instance_valid(value) and bool(value.visible)

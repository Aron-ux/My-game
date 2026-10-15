extends Node2D

const GROUP_NAME := "experience_vacuum_pickups"
const ORBIT_SPEED := 1.4

var pooled: bool = false
@onready var orbit: Node2D = $Orbit


func _ready() -> void:
	if not pooled:
		add_to_group(GROUP_NAME)
		_register_runtime_pickup()


func _exit_tree() -> void:
	var scene := _get_current_scene()
	if scene != null and scene.has_method("unregister_runtime_pickup"):
		scene.unregister_runtime_pickup(GROUP_NAME, self)


func _process(delta: float) -> void:
	if not pooled:
		orbit.rotation += ORBIT_SPEED * delta


func collect(player: Node2D) -> void:
	if pooled or not is_instance_valid(player):
		return
	var scene := _get_current_scene()
	if scene == null:
		return
	# Snapshot only the crystals already on the field. Future drops keep their
	# normal pickup range, and each crystal keeps its existing experience value.
	var gems: Array = scene.get_runtime_pickups("exp_gems") if scene.has_method("get_runtime_pickups") else get_tree().get_nodes_in_group("exp_gems")
	for gem in gems:
		if not is_instance_valid(gem) or gem.is_queued_for_deletion() or bool(gem.get("pooled")):
			continue
		if gem.has_method("set_attraction_target"):
			gem.set_attraction_target(player)
	recycle()


func reset_pickup(new_position: Vector2) -> void:
	pooled = false
	global_position = new_position
	orbit.rotation = 0.0
	show()
	set_process(true)
	add_to_group(GROUP_NAME)
	_register_runtime_pickup()


func recycle() -> void:
	if pooled:
		return
	pooled = true
	remove_from_group(GROUP_NAME)
	var scene := _get_current_scene()
	if scene != null and scene.has_method("unregister_runtime_pickup"):
		scene.unregister_runtime_pickup(GROUP_NAME, self)
	if scene != null and scene.has_method("release_runtime_pickup"):
		scene.release_runtime_pickup(GROUP_NAME, self)
	else:
		queue_free()


func get_save_data() -> Dictionary:
	return {"position": [global_position.x, global_position.y]}


func apply_save_data(data: Dictionary) -> void:
	var saved_position: Array = data.get("position", [0.0, 0.0])
	reset_pickup(Vector2(float(saved_position[0]), float(saved_position[1])))


func _register_runtime_pickup() -> void:
	var scene := _get_current_scene()
	if scene != null and scene.has_method("register_runtime_pickup"):
		scene.register_runtime_pickup(GROUP_NAME, self)


func _get_current_scene() -> Node:
	return get_tree().current_scene if is_inside_tree() else null

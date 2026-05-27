extends SceneTree

func _init() -> void:
	var scene := load("res://scenes/endless_camp.tscn") as PackedScene
	if scene == null:
		push_error("Failed to load endless camp scene.")
		quit(1)
		return
	var instance := scene.instantiate()
	if instance == null:
		push_error("Failed to instantiate endless camp scene.")
		quit(1)
		return
	var portal := instance.get_node_or_null("Portal/Interactable")
	var blacksmith := instance.get_node_or_null("Blacksmith/Interactable")
	var player := instance.get_node_or_null("CampPlayer")
	instance.queue_free()
	if portal == null or blacksmith == null or player == null:
		push_error("Endless camp scene is missing required interaction nodes.")
		quit(1)
		return
	print("ENDLESS_CAMP_SMOKE_OK")
	quit()

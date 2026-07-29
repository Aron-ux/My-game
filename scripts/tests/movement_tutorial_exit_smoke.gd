extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/movement_tutorial.tscn") as PackedScene
	if packed == null:
		push_error("Failed to load movement tutorial scene.")
		quit(1)
		return
	var tutorial := packed.instantiate()
	root.add_child(tutorial)
	current_scene = tutorial
	await process_frame
	tutorial.set("current_step", 5)
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	tutorial.call("_unhandled_input", escape_event)
	await process_frame
	print("MOVEMENT_TUTORIAL_EXIT_SMOKE_OK")
	quit(0)

extends SceneTree

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/endless_camp.tscn") as PackedScene
	if scene == null:
		_fail("Failed to load endless camp scene.")
		return
	var instance := scene.instantiate()
	if instance == null:
		_fail("Failed to instantiate endless camp scene.")
		return
	root.add_child(instance)
	await process_frame
	var portal := instance.get_node_or_null("Portal/Interactable")
	var blacksmith := instance.get_node_or_null("Blacksmith/Interactable")
	var player := instance.get_node_or_null("CampPlayer") as CharacterBody2D
	var ruan_dog := instance.get_node_or_null("RuanDog") as Node2D
	var dog_interactable := instance.get_node_or_null("RuanDog/Interactable") as Area2D
	var dog_visual := instance.get_node_or_null("RuanDog/Visual") as Sprite2D
	var dialogue_panel := instance.get_node_or_null("CanvasLayer/DialoguePanel") as PanelContainer
	var dialogue_title := instance.get_node_or_null("CanvasLayer/DialoguePanel/MarginContainer/DialogueContent/TextContent/Title") as Label
	var dialogue_body := instance.get_node_or_null("CanvasLayer/DialoguePanel/MarginContainer/DialogueContent/TextContent/Body") as Label
	var dialogue_portrait := instance.get_node_or_null("CanvasLayer/DialoguePanel/MarginContainer/DialogueContent/Portrait") as TextureRect
	var prompt_label := instance.get_node_or_null("CanvasLayer/PromptLabel") as Label
	if portal == null or blacksmith == null or player == null:
		failures.append("Endless camp scene is missing required interaction nodes.")
	if ruan_dog == null or dog_interactable == null or dog_visual == null:
		failures.append("Endless camp scene is missing Ruan Dog or its interaction nodes.")
	elif dog_interactable.position.x >= 0.0:
		failures.append("Ruan Dog interaction area must stay in front of its left-facing sprite.")
	if dog_visual == null or dog_visual.texture == null:
		failures.append("Ruan Dog world sprite is missing its pixel-art texture.")
	if dialogue_panel == null or dialogue_title == null or dialogue_body == null or dialogue_portrait == null:
		failures.append("Endless camp scene is missing the dialogue UI.")
	elif dialogue_portrait.texture == null:
		failures.append("Dialogue UI is missing the Ruan Dog portrait.")
	if dog_interactable != null and dialogue_panel != null and dialogue_title != null and dialogue_body != null and prompt_label != null and player != null:
		player.global_position = dog_interactable.global_position
		for _frame in range(3):
			await physics_frame
			await process_frame
		if not bool(dog_interactable.call("can_interact")) or not prompt_label.visible or not prompt_label.text.contains("阮狗"):
			failures.append("Standing in front of Ruan Dog did not enable the interaction prompt.")
		var interact_event := InputEventKey.new()
		interact_event.keycode = GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_INTERACT)
		interact_event.pressed = true
		instance.call("_unhandled_input", interact_event)
		var first_line := dialogue_body.text
		if not dialogue_panel.visible or dialogue_title.text != "阮狗" or first_line == "":
			failures.append("Ruan Dog interaction did not open the first dialogue line.")
		if player.is_physics_processing():
			failures.append("Camp player movement must stop while dialogue is open.")
		instance.call("_unhandled_input", interact_event)
		if dialogue_body.text == first_line:
			failures.append("Advancing Ruan Dog dialogue did not change the line.")
		instance.call("_unhandled_input", interact_event)
		if not dialogue_panel.visible:
			failures.append("Ruan Dog dialogue closed before its final line.")
		instance.call("_unhandled_input", interact_event)
		if dialogue_panel.visible or not player.is_physics_processing():
			failures.append("Finishing dialogue did not restore camp movement.")
		instance.call("_unhandled_input", interact_event)
		var escape_event := InputEventKey.new()
		escape_event.keycode = KEY_ESCAPE
		escape_event.pressed = true
		instance.call("_unhandled_input", escape_event)
		if dialogue_panel.visible or not player.is_physics_processing():
			failures.append("Escape did not close dialogue and restore camp movement.")
	instance.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENDLESS_CAMP_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

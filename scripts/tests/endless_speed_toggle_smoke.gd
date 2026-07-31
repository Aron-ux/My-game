extends SceneTree

const GAME_SESSION_FLOW := preload("res://scripts/game/game_session_flow.gd")
const HUD := preload("res://scripts/hud.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.time_scale = 1.0
	var main := MainStub.new()
	root.add_child(main)
	main.hud = HUD.new()
	main.add_child(main.hud)
	await process_frame

	var speed_button := main.hud.find_child("EndlessSpeedToggle", true, false) as Button
	assert(speed_button != null)
	main.hud.set_endless_mode_enabled(false)
	assert(not speed_button.visible)

	main.endless_mode_active = true
	main.hud.set_endless_mode_enabled(true)
	assert(speed_button.visible)
	main.hud.endless_speed_toggled.connect(func(enabled: bool): GAME_SESSION_FLOW.set_endless_speed_enabled(main, enabled))
	main.hud._on_endless_speed_toggled(true)
	assert(main.endless_speed_enabled)
	assert(is_equal_approx(Engine.time_scale, 2.0))
	assert(speed_button.button_pressed)
	assert(speed_button.text == "速度 ×2")

	GAME_SESSION_FLOW.reset_game_speed(main)
	assert(not main.endless_speed_enabled)
	assert(is_equal_approx(Engine.time_scale, 1.0))
	assert(not speed_button.button_pressed)
	assert(speed_button.text == "速度 ×1")

	main.endless_mode_active = false
	GAME_SESSION_FLOW.set_endless_speed_enabled(main, true)
	assert(not main.endless_speed_enabled)
	assert(is_equal_approx(Engine.time_scale, 1.0))

	print("ENDLESS_SPEED_TOGGLE_SMOKE_OK")
	quit(0)

class MainStub:
	extends Node

	var hud: CanvasLayer
	var endless_mode_active: bool = false
	var endless_speed_enabled: bool = false
	var game_over: bool = false

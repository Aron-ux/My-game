extends SceneTree

func _init() -> void:
	var hud_script := load("res://scripts/hud.gd")
	if hud_script == null:
		push_error("Cannot load hud.gd")
		quit(1)
		return
	var hud = hud_script.new()
	root.add_child(hud)
	await process_frame
	if not hud.has_method("configure_minimap") or not hud.has_method("update_minimap"):
		push_error("HUD missing minimap methods")
		quit(1)
		return
	hud.configure_minimap(Rect2(Vector2(-100.0, -100.0), Vector2(200.0, 200.0)))
	hud.update_minimap({
		"bounds": Rect2(Vector2(-100.0, -100.0), Vector2(200.0, 200.0)),
		"player_position": Vector2.ZERO,
		"enemies": [{"position": Vector2(50.0, 50.0), "kind": "boss"}],
		"boss_position": Vector2(80.0, 0.0),
		"gems": [{"position": Vector2(-50.0, 0.0)}],
		"hearts": [{"position": Vector2(0.0, -50.0)}]
	})
	await process_frame
	print("MAP_UI_SMOKE_OK")
	quit(0)

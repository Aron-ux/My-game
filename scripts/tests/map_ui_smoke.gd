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
	hud.show_boss_ui("Final", 37080.0, 12360.0, {}, {"enemy_kind": "boss", "shield_health": 24720.0, "shield_max_health": 24720.0})
	await process_frame
	var boss_health_bar := hud.get("boss_health_bar") as ProgressBar
	var boss_shield_bar := hud.get("boss_shield_bar") as ProgressBar
	var boss_health_label := hud.get("boss_health_label") as Label
	var boss_fill := boss_health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if boss_health_bar == null or boss_shield_bar == null or boss_health_label == null or boss_fill == null:
		push_error("Boss health UI controls missing")
		quit(1)
		return
	if not is_equal_approx(float(boss_health_bar.value), 12360.0) or not boss_shield_bar.visible or not is_equal_approx(float(boss_shield_bar.value), 24720.0):
		push_error("Boss shield health UI did not split over-health into shield")
		quit(1)
		return
	if not boss_health_label.text.contains("护盾"):
		push_error("Boss shield label should expose shield amount")
		quit(1)
		return
	if boss_fill.bg_color.r < 0.8 or boss_fill.bg_color.g > 0.2:
		push_error("Boss base health fill should be red")
		quit(1)
		return
	hud.show_boss_ui("Small Boss", 5000.0, 10000.0)
	await process_frame
	if boss_shield_bar.visible or not is_equal_approx(float(boss_health_bar.value), 5000.0):
		push_error("Small boss health UI should use plain red health without shield")
		quit(1)
		return
	print("MAP_UI_SMOKE_OK")
	quit(0)

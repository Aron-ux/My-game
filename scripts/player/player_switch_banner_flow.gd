extends RefCounted


static func show_switch_banner(owner, prefix: String, title: String, color: Color) -> void:
	if not owner.SHOW_GAMEPLAY_TEXT_HINTS:
		return
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return

	var layer := CanvasLayer.new()
	layer.layer = 7
	current_scene.add_child(layer)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -170.0
	panel.offset_right = 170.0
	panel.offset_top = 68.0
	panel.offset_bottom = 122.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.8)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = color
	label.text = "%s  %s" % [prefix, title]
	panel.add_child(label)

	panel.scale = Vector2(0.84, 0.84)
	var tween := panel.create_tween()
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.12)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.48).set_delay(0.18)
	tween.tween_callback(layer.queue_free)

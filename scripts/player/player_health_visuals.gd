extends RefCounted

const PLAYER_VISUAL_STATE := preload("res://scripts/player/player_visual_state.gd")

const HEALTH_SEGMENT_VALUE := 20.0
const HEALTH_BAR_MIN_VISUAL_HEIGHT := 8.0
const HEALTH_BAR_BORDER_WIDTH := 2.5
const HEALTH_BAR_INNER_PADDING := 1.4
const HEALTH_BAR_SEGMENT_LINE_WIDTH := 1.25
const HEALTH_BAR_SEGMENT_COLOR := Color(0.0, 0.0, 0.0, 0.58)
const DURATION_STATUS_BAR_WIDTH := 62.0
const DURATION_STATUS_BAR_HEIGHT := 6.0
const DURATION_STATUS_BAR_Y_OFFSET := -68.0
const DURATION_STATUS_LABEL_Y_OFFSET := -24.0
const DURATION_STATUS_INNER_PADDING := 1.0

static func setup_hurt_core_visual(owner, hurt_core_radius: float, outline_width: float) -> void:
	var hurt_core := owner.get_node_or_null("HurtCore") as Node2D
	if hurt_core == null:
		return
	var fill := hurt_core.get_node_or_null("Fill") as Polygon2D
	if fill != null:
		fill.polygon = owner._build_circle_polygon(hurt_core_radius)
	var outline := hurt_core.get_node_or_null("Outline") as Line2D
	if outline != null:
		var ring_points: PackedVector2Array = owner._build_circle_polygon(hurt_core_radius + outline_width * 0.35)
		if ring_points.size() > 0:
			ring_points.append(ring_points[0])
		outline.points = ring_points
		outline.width = outline_width

static func update_hurt_core_visual(owner, role_data: Dictionary, hurt_core_offset: Vector2) -> void:
	var hurt_core := owner.get_node_or_null("HurtCore") as Node2D
	if hurt_core == null:
		return
	if role_data.is_empty():
		role_data = owner._get_active_role()
	var role_id: String = str(role_data.get("id", ""))
	var body_center_offset: Vector2 = PLAYER_VISUAL_STATE.get_role_body_center_offset(role_id)
	hurt_core.position = body_center_offset + hurt_core_offset
	hurt_core.z_index = 60
	var role_color: Color = role_data.get("color", Color(1.0, 0.5, 0.4, 1.0))
	var fill := hurt_core.get_node_or_null("Fill") as Polygon2D
	if fill != null:
		fill.color = Color(1.0, 1.0, 1.0, 0.94)
		fill.visible = true
	var outline := hurt_core.get_node_or_null("Outline") as Line2D
	if outline != null:
		outline.default_color = Color(role_color.r, role_color.g, role_color.b, 1.0)
		outline.visible = true


static func toggle_hurt_core_visual(owner) -> void:
	owner.hurt_core_visual_visible = not owner.hurt_core_visual_visible
	apply_hurt_core_visibility(owner)


static func apply_hurt_core_visibility(owner) -> void:
	var hurt_core := owner.get_node_or_null("HurtCore") as Node2D
	if hurt_core != null:
		hurt_core.visible = owner.hurt_core_visual_visible

static func setup_player_health_bar(owner) -> void:
	if owner.get_node_or_null("PlayerHealthBar") != null:
		return

	var bar_root := Node2D.new()
	bar_root.name = "PlayerHealthBar"
	bar_root.z_index = 70
	owner.add_child(bar_root)

	var background := Polygon2D.new()
	background.name = "Background"
	background.color = Color(0.0, 0.0, 0.0, 0.92)
	bar_root.add_child(background)

	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.color = Color(0.92, 0.08, 0.06, 1.0)
	bar_root.add_child(fill)

	var grid_lines := Node2D.new()
	grid_lines.name = "GridLines"
	bar_root.add_child(grid_lines)

	var border := Line2D.new()
	border.name = "Border"
	border.default_color = Color(0.0, 0.0, 0.0, 1.0)
	border.width = HEALTH_BAR_BORDER_WIDTH
	border.closed = true
	bar_root.add_child(border)

	var level_label := Label.new()
	level_label.name = "LevelLabel"
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.custom_minimum_size = Vector2(48.0, 18.0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35, 1.0))
	level_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	level_label.add_theme_constant_override("shadow_offset_x", 1)
	level_label.add_theme_constant_override("shadow_offset_y", 1)
	bar_root.add_child(level_label)

	update_player_health_bar(owner, owner._get_active_role(), 5.0, 44.0)

static func update_player_health_bar(owner, role_data: Dictionary, bar_height: float, bar_y_offset: float) -> void:
	var bar_root := owner.get_node_or_null("PlayerHealthBar") as Node2D
	if bar_root == null:
		return
	if role_data.is_empty():
		role_data = owner._get_active_role()

	var role_id: String = str(role_data.get("id", ""))
	var body_center_offset: Vector2 = PLAYER_VISUAL_STATE.get_role_body_center_offset(role_id)
	var bar_width: float = owner._get_role_health_bar_width(role_id)
	var visual_height: float = max(bar_height, HEALTH_BAR_MIN_VISUAL_HEIGHT)
	var half_width: float = bar_width * 0.5
	var half_height: float = visual_height * 0.5
	var inner_half_width: float = max(0.0, half_width - HEALTH_BAR_INNER_PADDING)
	var inner_half_height: float = max(0.0, half_height - HEALTH_BAR_INNER_PADDING)
	var health_ratio: float = clamp(owner.current_health / max(owner.max_health, 1.0), 0.0, 1.0)
	bar_root.position = body_center_offset + Vector2(0.0, bar_y_offset)

	var background := bar_root.get_node_or_null("Background") as Polygon2D
	if background != null:
		background.polygon = PackedVector2Array([
			Vector2(-half_width, -half_height),
			Vector2(half_width, -half_height),
			Vector2(half_width, half_height),
			Vector2(-half_width, half_height)
		])

	var fill := bar_root.get_node_or_null("Fill") as Polygon2D
	if fill != null:
		var fill_width: float = max(0.0, inner_half_width * 2.0 * health_ratio)
		fill.polygon = PackedVector2Array([
			Vector2(-inner_half_width, -inner_half_height),
			Vector2(-inner_half_width + fill_width, -inner_half_height),
			Vector2(-inner_half_width + fill_width, inner_half_height),
			Vector2(-inner_half_width, inner_half_height)
		])

	var grid_lines := bar_root.get_node_or_null("GridLines") as Node2D
	if grid_lines != null:
		_update_health_bar_grid(
			grid_lines,
			float(owner.max_health),
			inner_half_width,
			inner_half_height
		)

	var border := bar_root.get_node_or_null("Border") as Line2D
	if border != null:
		border.width = HEALTH_BAR_BORDER_WIDTH
		border.points = PackedVector2Array([
			Vector2(-half_width, -half_height),
			Vector2(half_width, -half_height),
			Vector2(half_width, half_height),
			Vector2(-half_width, half_height)
		])

	var level_label := bar_root.get_node_or_null("LevelLabel") as Label
	if level_label != null:
		level_label.text = "Lv.%d" % _get_owner_level(owner)
		level_label.position = Vector2(half_width + 7.0, -9.5)
		level_label.size = Vector2(48.0, 18.0)


static func setup_player_duration_status_bar(owner) -> void:
	if owner.get_node_or_null("PlayerDurationStatusBar") != null:
		return

	var bar_root := Node2D.new()
	bar_root.name = "PlayerDurationStatusBar"
	bar_root.z_index = 76
	bar_root.visible = false
	owner.add_child(bar_root)

	var label := Label.new()
	label.name = "StatusLabel"
	label.text = ""
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(72.0, 18.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-36.0, DURATION_STATUS_LABEL_Y_OFFSET)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.96))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	bar_root.add_child(label)

	var background := Polygon2D.new()
	background.name = "Background"
	background.color = Color(0.08, 0.08, 0.08, 0.86)
	bar_root.add_child(background)

	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.color = Color(0.56, 0.56, 0.56, 0.95)
	bar_root.add_child(fill)

	var border := Line2D.new()
	border.name = "Border"
	border.default_color = Color(0.0, 0.0, 0.0, 0.92)
	border.width = 1.5
	border.closed = true
	bar_root.add_child(border)


static func update_player_duration_status_bar(owner) -> void:
	setup_player_duration_status_bar(owner)
	var bar_root := owner.get_node_or_null("PlayerDurationStatusBar") as Node2D
	if bar_root == null:
		return
	var status_data: Dictionary = _get_primary_duration_status(owner)
	if status_data.is_empty():
		bar_root.visible = false
		return

	var role_data: Dictionary = owner._get_active_role()
	var role_id: String = str(role_data.get("id", ""))
	var body_center_offset: Vector2 = PLAYER_VISUAL_STATE.get_role_body_center_offset(role_id)
	bar_root.position = body_center_offset + Vector2(0.0, DURATION_STATUS_BAR_Y_OFFSET)
	bar_root.visible = true
	var label := bar_root.get_node_or_null("StatusLabel") as Label
	if label != null:
		label.text = str(status_data.get("label", ""))

	var progress: float = clamp(
		float(status_data.get("remaining", 0.0)) / max(0.001, float(status_data.get("duration", 1.0))),
		0.0,
		1.0
	)
	var half_width: float = DURATION_STATUS_BAR_WIDTH * 0.5
	var half_height: float = DURATION_STATUS_BAR_HEIGHT * 0.5
	var inner_half_width: float = max(0.0, half_width - DURATION_STATUS_INNER_PADDING)
	var inner_half_height: float = max(0.0, half_height - DURATION_STATUS_INNER_PADDING)

	var background := bar_root.get_node_or_null("Background") as Polygon2D
	if background != null:
		background.polygon = PackedVector2Array([
			Vector2(-half_width, -half_height),
			Vector2(half_width, -half_height),
			Vector2(half_width, half_height),
			Vector2(-half_width, half_height)
		])

	var fill := bar_root.get_node_or_null("Fill") as Polygon2D
	if fill != null:
		var fill_color: Variant = status_data.get("color", Color(0.56, 0.56, 0.56, 0.95))
		fill.color = fill_color if fill_color is Color else Color(0.56, 0.56, 0.56, 0.95)
		var fill_width: float = inner_half_width * 2.0 * progress
		fill.polygon = PackedVector2Array([
			Vector2(-inner_half_width, -inner_half_height),
			Vector2(-inner_half_width + fill_width, -inner_half_height),
			Vector2(-inner_half_width + fill_width, inner_half_height),
			Vector2(-inner_half_width, inner_half_height)
		])

	var border := bar_root.get_node_or_null("Border") as Line2D
	if border != null:
		border.points = PackedVector2Array([
			Vector2(-half_width, -half_height),
			Vector2(half_width, -half_height),
			Vector2(half_width, half_height),
			Vector2(-half_width, half_height)
		])


static func _get_primary_duration_status(owner) -> Dictionary:
	var statuses: Variant = owner.get("active_duration_statuses")
	if statuses is not Dictionary:
		return {}
	var best_status: Dictionary = {}
	var best_remaining: float = -1.0
	var best_priority: int = -999999
	for status_value in (statuses as Dictionary).values():
		if status_value is not Dictionary:
			continue
		var remaining: float = float((status_value as Dictionary).get("remaining", 0.0))
		var priority: int = int((status_value as Dictionary).get("priority", 0))
		if priority > best_priority or (priority == best_priority and remaining > best_remaining):
			best_priority = priority
			best_remaining = remaining
			best_status = (status_value as Dictionary)
	return best_status


static func _update_health_bar_grid(
		grid_root: Node2D,
		max_health: float,
		inner_half_width: float,
		inner_half_height: float
	) -> void:
	var segment_count: int = int(floor(max_health / HEALTH_SEGMENT_VALUE))
	var required_line_count: int = max(0, segment_count)
	var children: Array[Node] = grid_root.get_children()
	while children.size() < required_line_count:
		var new_line := Line2D.new()
		new_line.width = HEALTH_BAR_SEGMENT_LINE_WIDTH
		new_line.default_color = HEALTH_BAR_SEGMENT_COLOR
		grid_root.add_child(new_line)
		children = grid_root.get_children()

	for child_index in range(children.size()):
		var line := children[child_index] as Line2D
		if line == null:
			continue
		if child_index >= required_line_count:
			line.visible = false
			continue
		var segment_hp: float = float(child_index + 1) * HEALTH_SEGMENT_VALUE
		if segment_hp >= max_health:
			line.visible = false
			continue
		var segment_ratio: float = segment_hp / max(max_health, 1.0)
		var line_x: float = -inner_half_width + inner_half_width * 2.0 * segment_ratio
		line.visible = true
		line.width = HEALTH_BAR_SEGMENT_LINE_WIDTH
		line.default_color = HEALTH_BAR_SEGMENT_COLOR
		line.points = PackedVector2Array([
			Vector2(line_x, -inner_half_height),
			Vector2(line_x, inner_half_height)
		])


static func _get_owner_level(owner) -> int:
	var level_value: Variant = owner.get("level")
	if level_value == null:
		return 1
	return max(1, int(level_value))


static func get_hurtbox_center(owner) -> Vector2:
	var hurt_core := owner.get_node_or_null("HurtCore") as Node2D
	if hurt_core != null:
		return hurt_core.global_position
	return owner.global_position

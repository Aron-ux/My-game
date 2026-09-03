extends RefCounted

const PLAYER_VISUAL_STATE := preload("res://scripts/player/player_visual_state.gd")

const HEALTH_SEGMENT_VALUE := 50.0
const HEALTH_BAR_MIN_VISUAL_HEIGHT := 8.0
const HEALTH_BAR_BORDER_WIDTH := 2.5
const HEALTH_BAR_INNER_PADDING := 1.4
const HEALTH_BAR_SEGMENT_LINE_WIDTH := 1.25
const HEALTH_BAR_SEGMENT_COLOR := Color(0.0, 0.0, 0.0, 0.58)
const HEALTH_BAR_TEMP_FILL_COLOR := Color(0.56, 0.04, 0.03, 0.90)
const HEALTH_BAR_FAST_LERP_SPEED := 16.0
const HEALTH_BAR_HEAL_LERP_SPEED := 7.0
const HEALTH_BAR_DAMAGE_TRAIL_DELAY := 0.16
const HEALTH_BAR_DAMAGE_TRAIL_LERP_SPEED := 5.8
const HEALTH_BAR_HEAL_FLASH_DURATION := 0.32
const DURATION_STATUS_BAR_WIDTH := 62.0
const DURATION_STATUS_BAR_HEIGHT := 6.0
const DURATION_STATUS_BAR_Y_OFFSET := -68.0
const DURATION_STATUS_LABEL_Y_OFFSET := -24.0
const DURATION_STATUS_INNER_PADDING := 1.0

const META_HEALTH_BAR_ROLE_ID := "health_bar_role_id"
const META_HEALTH_BAR_MAX_HEALTH := "health_bar_max_health"
const META_HEALTH_BAR_TARGET_RATIO := "health_bar_target_ratio"
const META_HEALTH_BAR_DISPLAY_RATIO := "health_bar_display_ratio"
const META_HEALTH_BAR_TRAIL_RATIO := "health_bar_trail_ratio"
const META_HEALTH_BAR_DAMAGE_STARTED := "health_bar_damage_started"
const META_HEALTH_BAR_HEAL_STARTED := "health_bar_heal_started"
const META_HEALTH_BAR_HEAL_FROM_RATIO := "health_bar_heal_from_ratio"
const META_HEALTH_BAR_HEAL_TO_RATIO := "health_bar_heal_to_ratio"
const META_HEALTH_BAR_LAST_UPDATE_TIME := "health_bar_last_update_time"
const META_HEALTH_BAR_TEMP_ROLE_ID := "health_bar_temp_role_id"
const META_HEALTH_BAR_TEMP_MAX_HEALTH := "health_bar_temp_max_health"
const META_HEALTH_BAR_TEMP_TARGET_RATIO := "health_bar_temp_target_ratio"
const META_HEALTH_BAR_TEMP_DISPLAY_RATIO := "health_bar_temp_display_ratio"
const META_HEALTH_BAR_TEMP_LAST_UPDATE_TIME := "health_bar_temp_last_update_time"

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
	var existing_bar_root := owner.get_node_or_null("PlayerHealthBar") as Node2D
	if existing_bar_root != null:
		_ensure_temporary_health_fill(existing_bar_root)
		return

	var bar_root := Node2D.new()
	bar_root.name = "PlayerHealthBar"
	bar_root.z_index = 70
	owner.add_child(bar_root)

	var background := Polygon2D.new()
	background.name = "Background"
	background.color = Color(0.0, 0.0, 0.0, 0.92)
	bar_root.add_child(background)

	var damage_trail := Polygon2D.new()
	damage_trail.name = "DamageTrail"
	damage_trail.color = Color(1.0, 0.46, 0.18, 0.68)
	damage_trail.visible = false
	bar_root.add_child(damage_trail)

	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.color = Color(0.92, 0.08, 0.06, 1.0)
	bar_root.add_child(fill)

	var temporary_fill := Polygon2D.new()
	temporary_fill.name = "TemporaryHealthFill"
	temporary_fill.color = HEALTH_BAR_TEMP_FILL_COLOR
	temporary_fill.visible = false
	bar_root.add_child(temporary_fill)

	var heal_flash := Polygon2D.new()
	heal_flash.name = "HealFlash"
	heal_flash.color = Color(0.40, 1.0, 0.58, 0.0)
	heal_flash.visible = false
	bar_root.add_child(heal_flash)

	var grid_lines := Node2D.new()
	grid_lines.name = "GridLines"
	bar_root.add_child(grid_lines)

	var temporary_grid_lines := Node2D.new()
	temporary_grid_lines.name = "TemporaryGridLines"
	bar_root.add_child(temporary_grid_lines)

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
	var temporary_health_ratio: float = max(0.0, float(owner.current_temporary_health) / max(owner.max_health, 1.0))
	var animation_state: Dictionary = _update_health_bar_animation_state(bar_root, role_id, float(owner.max_health), health_ratio)
	var temporary_animation_state: Dictionary = _update_temporary_health_bar_animation_state(bar_root, role_id, float(owner.max_health), temporary_health_ratio)
	var display_ratio: float = float(animation_state.get("display_ratio", health_ratio))
	var trail_ratio: float = float(animation_state.get("trail_ratio", display_ratio))
	var heal_from_ratio: float = float(animation_state.get("heal_from_ratio", display_ratio))
	var heal_to_ratio: float = float(animation_state.get("heal_to_ratio", display_ratio))
	var heal_alpha: float = float(animation_state.get("heal_alpha", 0.0))
	var temporary_display_ratio: float = float(temporary_animation_state.get("display_ratio", temporary_health_ratio))
	bar_root.position = body_center_offset + Vector2(0.0, bar_y_offset)

	var background := bar_root.get_node_or_null("Background") as Polygon2D
	if background != null:
		background.polygon = PackedVector2Array([
			Vector2(-half_width, -half_height),
			Vector2(half_width, -half_height),
			Vector2(half_width, half_height),
			Vector2(-half_width, half_height)
		])

	var damage_trail := bar_root.get_node_or_null("DamageTrail") as Polygon2D
	if damage_trail != null:
		damage_trail.visible = trail_ratio > display_ratio + 0.002
		damage_trail.color = Color(1.0, 0.46, 0.18, 0.68)
		_set_health_bar_fill_polygon(damage_trail, trail_ratio, inner_half_width, inner_half_height)

	var fill := bar_root.get_node_or_null("Fill") as Polygon2D
	if fill != null:
		_set_health_bar_fill_polygon(fill, display_ratio, inner_half_width, inner_half_height)

	var temporary_fill := _ensure_temporary_health_fill(bar_root)
	var temporary_start_ratio: float = display_ratio
	var temporary_end_ratio: float = min(1.0, display_ratio + temporary_display_ratio)
	# Keep temporary health visible inside the fixed bar even when normal HP is full.
	if temporary_display_ratio > 0.002 and temporary_end_ratio <= temporary_start_ratio + 0.0001:
		temporary_start_ratio = max(0.0, 1.0 - temporary_display_ratio)
		temporary_end_ratio = 1.0
	if temporary_fill != null:
		temporary_fill.visible = temporary_display_ratio > 0.002
		temporary_fill.color = HEALTH_BAR_TEMP_FILL_COLOR
		_set_health_bar_segment_polygon(
			temporary_fill,
			temporary_start_ratio,
			temporary_end_ratio,
			inner_half_width,
			inner_half_height
		)

	var heal_flash := bar_root.get_node_or_null("HealFlash") as Polygon2D
	if heal_flash != null:
		var band_to_ratio: float = max(heal_from_ratio, min(heal_to_ratio, display_ratio))
		heal_flash.visible = heal_alpha > 0.01 and band_to_ratio > heal_from_ratio + 0.002
		heal_flash.color = Color(0.40, 1.0, 0.58, 0.58 * heal_alpha)
		_set_health_bar_band_polygon(heal_flash, heal_from_ratio, band_to_ratio, inner_half_width, inner_half_height)

	var grid_lines := bar_root.get_node_or_null("GridLines") as Node2D
	if grid_lines != null:
		_update_health_bar_grid(
			grid_lines,
			float(owner.max_health),
			inner_half_width,
			inner_half_height
		)
	var temporary_grid_lines := bar_root.get_node_or_null("TemporaryGridLines") as Node2D
	if temporary_grid_lines != null:
		_update_temporary_health_bar_grid(
			temporary_grid_lines,
			temporary_start_ratio,
			temporary_end_ratio,
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
		var temporary_overflow_ratio: float = max(0.0, display_ratio + temporary_display_ratio - 1.0)
		level_label.position = Vector2(half_width + 7.0 + bar_width * temporary_overflow_ratio, -9.5)
		level_label.size = Vector2(48.0, 18.0)


static func _update_health_bar_animation_state(bar_root: Node2D, role_id: String, max_health: float, target_ratio: float) -> Dictionary:
	var now: float = Time.get_ticks_msec() * 0.001
	var previous_role_id: String = str(bar_root.get_meta(META_HEALTH_BAR_ROLE_ID, ""))
	var previous_max_health: float = float(bar_root.get_meta(META_HEALTH_BAR_MAX_HEALTH, max_health))
	if previous_role_id != role_id or not is_equal_approx(previous_max_health, max_health) or not bar_root.has_meta(META_HEALTH_BAR_TARGET_RATIO):
		_reset_health_bar_animation_state(bar_root, role_id, max_health, target_ratio, now)
		return {
			"display_ratio": target_ratio,
			"trail_ratio": target_ratio,
			"heal_from_ratio": target_ratio,
			"heal_to_ratio": target_ratio,
			"heal_alpha": 0.0
		}

	var last_update_time: float = float(bar_root.get_meta(META_HEALTH_BAR_LAST_UPDATE_TIME, now))
	var delta: float = clamp(now - last_update_time, 0.0, 0.08)
	var old_target_ratio: float = float(bar_root.get_meta(META_HEALTH_BAR_TARGET_RATIO, target_ratio))
	var display_ratio: float = float(bar_root.get_meta(META_HEALTH_BAR_DISPLAY_RATIO, old_target_ratio))
	var trail_ratio: float = float(bar_root.get_meta(META_HEALTH_BAR_TRAIL_RATIO, old_target_ratio))
	var damage_started: float = float(bar_root.get_meta(META_HEALTH_BAR_DAMAGE_STARTED, -999.0))
	var heal_started: float = float(bar_root.get_meta(META_HEALTH_BAR_HEAL_STARTED, -999.0))
	var heal_from_ratio: float = float(bar_root.get_meta(META_HEALTH_BAR_HEAL_FROM_RATIO, display_ratio))
	var heal_to_ratio: float = float(bar_root.get_meta(META_HEALTH_BAR_HEAL_TO_RATIO, target_ratio))

	if target_ratio < old_target_ratio - 0.001:
		trail_ratio = max(trail_ratio, old_target_ratio, display_ratio)
		damage_started = now
	elif target_ratio > old_target_ratio + 0.001:
		heal_from_ratio = min(display_ratio, old_target_ratio)
		heal_to_ratio = target_ratio
		heal_started = now
		damage_started = -999.0
		trail_ratio = display_ratio

	var display_speed := HEALTH_BAR_HEAL_LERP_SPEED if target_ratio > display_ratio else HEALTH_BAR_FAST_LERP_SPEED
	display_ratio = _approach_ratio(display_ratio, target_ratio, display_speed, delta)
	if now - damage_started >= HEALTH_BAR_DAMAGE_TRAIL_DELAY:
		trail_ratio = _approach_ratio(trail_ratio, target_ratio, HEALTH_BAR_DAMAGE_TRAIL_LERP_SPEED, delta)
	else:
		trail_ratio = max(trail_ratio, display_ratio)
	if trail_ratio < display_ratio:
		trail_ratio = display_ratio

	var heal_alpha := 0.0
	if heal_started > 0.0:
		var heal_progress: float = clamp((now - heal_started) / HEALTH_BAR_HEAL_FLASH_DURATION, 0.0, 1.0)
		heal_alpha = 1.0 - heal_progress

	bar_root.set_meta(META_HEALTH_BAR_ROLE_ID, role_id)
	bar_root.set_meta(META_HEALTH_BAR_MAX_HEALTH, max_health)
	bar_root.set_meta(META_HEALTH_BAR_TARGET_RATIO, target_ratio)
	bar_root.set_meta(META_HEALTH_BAR_DISPLAY_RATIO, display_ratio)
	bar_root.set_meta(META_HEALTH_BAR_TRAIL_RATIO, trail_ratio)
	bar_root.set_meta(META_HEALTH_BAR_DAMAGE_STARTED, damage_started)
	bar_root.set_meta(META_HEALTH_BAR_HEAL_STARTED, heal_started)
	bar_root.set_meta(META_HEALTH_BAR_HEAL_FROM_RATIO, heal_from_ratio)
	bar_root.set_meta(META_HEALTH_BAR_HEAL_TO_RATIO, heal_to_ratio)
	bar_root.set_meta(META_HEALTH_BAR_LAST_UPDATE_TIME, now)

	return {
		"display_ratio": display_ratio,
		"trail_ratio": trail_ratio,
		"heal_from_ratio": heal_from_ratio,
		"heal_to_ratio": heal_to_ratio,
		"heal_alpha": heal_alpha
	}


static func _reset_health_bar_animation_state(bar_root: Node2D, role_id: String, max_health: float, target_ratio: float, now: float) -> void:
	bar_root.set_meta(META_HEALTH_BAR_ROLE_ID, role_id)
	bar_root.set_meta(META_HEALTH_BAR_MAX_HEALTH, max_health)
	bar_root.set_meta(META_HEALTH_BAR_TARGET_RATIO, target_ratio)
	bar_root.set_meta(META_HEALTH_BAR_DISPLAY_RATIO, target_ratio)
	bar_root.set_meta(META_HEALTH_BAR_TRAIL_RATIO, target_ratio)
	bar_root.set_meta(META_HEALTH_BAR_DAMAGE_STARTED, -999.0)
	bar_root.set_meta(META_HEALTH_BAR_HEAL_STARTED, -999.0)
	bar_root.set_meta(META_HEALTH_BAR_HEAL_FROM_RATIO, target_ratio)
	bar_root.set_meta(META_HEALTH_BAR_HEAL_TO_RATIO, target_ratio)
	bar_root.set_meta(META_HEALTH_BAR_LAST_UPDATE_TIME, now)


static func _update_temporary_health_bar_animation_state(bar_root: Node2D, role_id: String, max_health: float, target_ratio: float) -> Dictionary:
	var now: float = Time.get_ticks_msec() * 0.001
	var previous_role_id: String = str(bar_root.get_meta(META_HEALTH_BAR_TEMP_ROLE_ID, ""))
	var previous_max_health: float = float(bar_root.get_meta(META_HEALTH_BAR_TEMP_MAX_HEALTH, max_health))
	if previous_role_id != role_id or not is_equal_approx(previous_max_health, max_health) or not bar_root.has_meta(META_HEALTH_BAR_TEMP_TARGET_RATIO):
		_reset_temporary_health_bar_animation_state(bar_root, role_id, max_health, target_ratio, now)
		return {
			"display_ratio": target_ratio
		}

	var last_update_time: float = float(bar_root.get_meta(META_HEALTH_BAR_TEMP_LAST_UPDATE_TIME, now))
	var delta: float = clamp(now - last_update_time, 0.0, 0.08)
	var old_target_ratio: float = float(bar_root.get_meta(META_HEALTH_BAR_TEMP_TARGET_RATIO, target_ratio))
	var display_ratio: float = float(bar_root.get_meta(META_HEALTH_BAR_TEMP_DISPLAY_RATIO, old_target_ratio))
	var display_speed := HEALTH_BAR_HEAL_LERP_SPEED if target_ratio > display_ratio else HEALTH_BAR_FAST_LERP_SPEED
	display_ratio = _approach_ratio(display_ratio, target_ratio, display_speed, delta)

	bar_root.set_meta(META_HEALTH_BAR_TEMP_ROLE_ID, role_id)
	bar_root.set_meta(META_HEALTH_BAR_TEMP_MAX_HEALTH, max_health)
	bar_root.set_meta(META_HEALTH_BAR_TEMP_TARGET_RATIO, target_ratio)
	bar_root.set_meta(META_HEALTH_BAR_TEMP_DISPLAY_RATIO, display_ratio)
	bar_root.set_meta(META_HEALTH_BAR_TEMP_LAST_UPDATE_TIME, now)

	return {
		"display_ratio": display_ratio
	}


static func _reset_temporary_health_bar_animation_state(bar_root: Node2D, role_id: String, max_health: float, target_ratio: float, now: float) -> void:
	bar_root.set_meta(META_HEALTH_BAR_TEMP_ROLE_ID, role_id)
	bar_root.set_meta(META_HEALTH_BAR_TEMP_MAX_HEALTH, max_health)
	bar_root.set_meta(META_HEALTH_BAR_TEMP_TARGET_RATIO, target_ratio)
	bar_root.set_meta(META_HEALTH_BAR_TEMP_DISPLAY_RATIO, target_ratio)
	bar_root.set_meta(META_HEALTH_BAR_TEMP_LAST_UPDATE_TIME, now)


static func _approach_ratio(current_ratio: float, target_ratio: float, speed: float, delta: float) -> float:
	if is_equal_approx(current_ratio, target_ratio):
		return target_ratio
	return lerpf(current_ratio, target_ratio, clamp(delta * speed, 0.0, 1.0))


static func _set_health_bar_fill_polygon(fill: Polygon2D, ratio: float, inner_half_width: float, inner_half_height: float) -> void:
	var fill_width: float = max(0.0, inner_half_width * 2.0 * clamp(ratio, 0.0, 1.0))
	fill.polygon = PackedVector2Array([
		Vector2(-inner_half_width, -inner_half_height),
		Vector2(-inner_half_width + fill_width, -inner_half_height),
		Vector2(-inner_half_width + fill_width, inner_half_height),
		Vector2(-inner_half_width, inner_half_height)
	])


static func _set_health_bar_band_polygon(fill: Polygon2D, start_ratio: float, end_ratio: float, inner_half_width: float, inner_half_height: float) -> void:
	var start_x: float = -inner_half_width + inner_half_width * 2.0 * clamp(start_ratio, 0.0, 1.0)
	var end_x: float = -inner_half_width + inner_half_width * 2.0 * clamp(end_ratio, 0.0, 1.0)
	if end_x <= start_x:
		fill.polygon = PackedVector2Array()
		return
	fill.polygon = PackedVector2Array([
		Vector2(start_x, -inner_half_height),
		Vector2(end_x, -inner_half_height),
		Vector2(end_x, inner_half_height),
		Vector2(start_x, inner_half_height)
	])


static func _set_health_bar_segment_polygon(fill: Polygon2D, start_ratio: float, end_ratio: float, inner_half_width: float, inner_half_height: float) -> void:
	var safe_start_ratio: float = max(0.0, start_ratio)
	var safe_end_ratio: float = max(safe_start_ratio, end_ratio)
	var start_x: float = -inner_half_width + inner_half_width * 2.0 * safe_start_ratio
	var end_x: float = -inner_half_width + inner_half_width * 2.0 * safe_end_ratio
	if end_x <= start_x:
		fill.polygon = PackedVector2Array()
		return
	fill.polygon = PackedVector2Array([
		Vector2(start_x, -inner_half_height),
		Vector2(end_x, -inner_half_height),
		Vector2(end_x, inner_half_height),
		Vector2(start_x, inner_half_height)
	])


static func _ensure_temporary_health_fill(bar_root: Node2D) -> Polygon2D:
	var temporary_fill := bar_root.get_node_or_null("TemporaryHealthFill") as Polygon2D
	if temporary_fill != null:
		var heal_flash := bar_root.get_node_or_null("HealFlash") as Node
		if heal_flash != null and temporary_fill.get_index() > heal_flash.get_index():
			bar_root.move_child(temporary_fill, heal_flash.get_index())
		return temporary_fill
	temporary_fill = Polygon2D.new()
	temporary_fill.name = "TemporaryHealthFill"
	temporary_fill.color = HEALTH_BAR_TEMP_FILL_COLOR
	temporary_fill.visible = false
	bar_root.add_child(temporary_fill)
	var heal_flash_node := bar_root.get_node_or_null("HealFlash") as Node
	if heal_flash_node != null:
		bar_root.move_child(temporary_fill, heal_flash_node.get_index())
	return temporary_fill


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


static func _update_temporary_health_bar_grid(
	grid_root: Node2D,
	start_ratio: float,
	end_ratio: float,
	max_health: float,
	inner_half_width: float,
	inner_half_height: float
) -> void:
	var safe_max_health: float = max(max_health, 1.0)
	var start_health: float = max(0.0, start_ratio * safe_max_health)
	var end_health: float = max(start_health, end_ratio * safe_max_health)
	var required_line_count: int = max(0, int(ceil((end_health - start_health) / HEALTH_SEGMENT_VALUE)) - 1)
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
		var boundary_health: float = start_health + float(child_index + 1) * HEALTH_SEGMENT_VALUE
		if child_index >= required_line_count or boundary_health >= end_health - 0.001:
			line.visible = false
			continue
		var segment_ratio: float = boundary_health / safe_max_health
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

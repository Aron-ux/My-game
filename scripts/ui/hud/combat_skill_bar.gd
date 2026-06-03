extends Control

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const SURVIVORS_HOVER_DETAIL := preload("res://scripts/ui/components/survivors_hover_detail.gd")
const SKILL_CD_SLOT_COUNT := 6
const SKILL_CD_SLOT_SIZE := 52.0
const BUFF_SLOT_SIZE := SKILL_CD_SLOT_SIZE * 0.35
const BUFF_SLOT_GAP := 5
const ULTIMATE_WIDGET_SIZE := 108.0
const ULTIMATE_WIDGET_GAP := 18.0
const SWITCH_WIDGET_WIDTH := 176.0
const SWITCH_WIDGET_HEIGHT := 72.0
const SWITCH_WIDGET_GAP := 18.0
const SKILL_PANEL_WIDTH := 382.0
const COOLDOWN_REDRAW_EPSILON: float = 0.01
const ENERGY_REDRAW_EPSILON: float = 0.0001
const ENERGY_READY_RATIO_EPSILON: float = 0.001
const SWITCH_HEAD_SIZE_MULTIPLIER := 2.5
const SWITCH_PORTRAIT_ANIMATION_DURATION := 0.22
const SWITCH_COOLDOWN_MASK_RADIUS_SCALE := 0.34
const SWITCH_COOLDOWN_MASK_RADIUS_EXTRA := 0.2
const SWITCH_COOLDOWN_MASK_OFFSET := Vector2(0.0, 2.0)
const SWITCH_PORTRAIT_CONTENT_DIAMETER_SCALE := 1.0
const SWITCH_PORTRAIT_CONTENT_OFFSET := Vector2(0.0, 0.0)
const SWITCH_PORTRAIT_SIDE_CONTENT_OFFSET := Vector2(1.0, 2.0)
const SWITCH_PORTRAIT_SWORDSMAN_CONTENT_OFFSET := Vector2(-1.0, -2.5)
const SWITCH_PORTRAIT_GUNNER_CONTENT_OFFSET := Vector2(0.0, -1.0)
const SWITCH_PORTRAIT_MAGE_CONTENT_OFFSET := Vector2(0.0, -2.5)
const SWITCH_PORTRAIT_SOFT_OUTLINE_STEPS := 5
const SWITCH_PORTRAIT_SOFT_OUTLINE_SPACING := 2.0
const SWITCH_PORTRAIT_ALPHA_CROP_THRESHOLD := 0.02
const SWITCH_ROLE_ORDER := ["swordsman", "gunner", "mage"]
const SWITCH_HEAD_SCENES := {
	"swordsman": preload("res://assets/UI/facility/swordchange.tscn"),
	"gunner": preload("res://assets/UI/facility/gunchange.tscn"),
	"mage": preload("res://assets/UI/facility/witchchange.tscn")
}

class SkillCooldownIcon:
	extends Control

	class CooldownOverlay:
		extends Control

		var cooldown_ratio: float = 0.0

		func set_ratio(new_ratio: float) -> void:
			var resolved_ratio: float = clamp(new_ratio, 0.0, 1.0)
			if abs(resolved_ratio - cooldown_ratio) <= COOLDOWN_REDRAW_EPSILON:
				return
			cooldown_ratio = resolved_ratio
			queue_redraw()

		func _draw() -> void:
			if cooldown_ratio <= 0.01:
				return
			var shade := Color(0.0, 0.0, 0.0, 0.68)
			var inner_rect := Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0))
			if cooldown_ratio >= 0.99:
				draw_rect(inner_rect, shade, true)
				return

			var center := inner_rect.get_center()
			var radius: float = max(inner_rect.size.x, inner_rect.size.y) * 0.82
			var angle_total: float = TAU * cooldown_ratio
			var steps: int = max(8, int(ceil(32.0 * cooldown_ratio)))
			var points := PackedVector2Array()
			points.append(center)
			for step in range(steps + 1):
				var progress: float = float(step) / float(steps)
				var angle: float = -PI * 0.5 + angle_total * progress
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
			draw_colored_polygon(points, shade)

	var icon_color: Color = Color(0.28, 0.3, 0.34, 1.0)
	var cooldown_ratio: float = 0.0
	var unlocked: bool = false
	var cooldown_overlay: CooldownOverlay

	func _ready() -> void:
		clip_contents = true
		cooldown_overlay = CooldownOverlay.new()
		cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		cooldown_overlay.offset_left = 0.0
		cooldown_overlay.offset_top = 0.0
		cooldown_overlay.offset_right = 0.0
		cooldown_overlay.offset_bottom = 0.0
		add_child(cooldown_overlay)
		cooldown_overlay.set_ratio(cooldown_ratio if unlocked else 0.0)

	func set_state(new_unlocked: bool, new_color: Color, new_cooldown_ratio: float) -> void:
		var resolved_ratio: float = clamp(new_cooldown_ratio, 0.0, 1.0)
		var visual_changed: bool = unlocked != new_unlocked or icon_color != new_color
		var ratio_changed: bool = abs(resolved_ratio - cooldown_ratio) > COOLDOWN_REDRAW_EPSILON
		if not visual_changed and not ratio_changed:
			return
		unlocked = new_unlocked
		icon_color = new_color
		cooldown_ratio = resolved_ratio
		if cooldown_overlay != null:
			cooldown_overlay.set_ratio(cooldown_ratio if unlocked else 0.0)
		if visual_changed:
			queue_redraw()

	func _draw() -> void:
		var outer_rect := Rect2(Vector2.ZERO, size)
		var inner_rect := outer_rect.grow(-5.0)
		var frame_color := Color(0.88, 0.9, 0.96, 0.9) if unlocked else Color(0.34, 0.36, 0.42, 0.82)
		var base_color := icon_color if unlocked else Color(0.12, 0.13, 0.16, 0.92)

		draw_rect(outer_rect, Color(0.04, 0.05, 0.07, 0.86), true)
		draw_rect(inner_rect, base_color, true)
		if not unlocked:
			draw_rect(inner_rect, Color(0.0, 0.0, 0.0, 0.42), true)
		draw_rect(outer_rect.grow(-1.0), frame_color, false, 2.0)

class BuffStatusIcon:
	extends Control

	var fill_ratio: float = 1.0
	var buff_color: Color = Color(0.36, 0.76, 1.0, 0.92)
	var base_color: Color = Color(0.62, 0.06, 0.05, 0.92)
	var icon_text: String = ""
	var icon_id: String = ""
	var stack_count: int = 0
	var cooldown_mode: bool = false

	func set_state(new_ratio: float, new_color: Color, new_text: String = "", new_stack_count: int = 0, new_cooldown_mode: bool = false, new_base_color: Color = Color(0.62, 0.06, 0.05, 0.92), new_icon_id: String = "") -> void:
		var resolved_ratio: float = clamp(new_ratio, 0.0, 1.0)
		var resolved_stack_count: int = max(0, new_stack_count)
		if abs(resolved_ratio - fill_ratio) <= ENERGY_REDRAW_EPSILON and buff_color == new_color and base_color == new_base_color and icon_text == new_text and stack_count == resolved_stack_count and cooldown_mode == new_cooldown_mode and icon_id == new_icon_id:
			return
		fill_ratio = resolved_ratio
		buff_color = new_color
		base_color = new_base_color
		icon_text = new_text
		icon_id = new_icon_id
		stack_count = resolved_stack_count
		cooldown_mode = new_cooldown_mode
		queue_redraw()

	func _draw() -> void:
		var outer_rect := Rect2(Vector2.ZERO, size)
		var bottom_base_height: float = max(5.0, size.y * 0.34)
		var bottom_base_rect := Rect2(Vector2(0.0, size.y - bottom_base_height), Vector2(size.x, bottom_base_height))
		if cooldown_mode:
			draw_rect(outer_rect, Color(buff_color.r, buff_color.g, buff_color.b, 0.16), true)
			var cooldown_fill_ratio: float = 1.0 - fill_ratio
			var cooldown_fill_height: float = size.y * cooldown_fill_ratio
			var cooldown_fill_rect := Rect2(Vector2(0.0, size.y - cooldown_fill_height), Vector2(size.x, cooldown_fill_height))
			draw_rect(cooldown_fill_rect, buff_color, true)
		else:
			draw_rect(outer_rect, Color(buff_color.r, buff_color.g, buff_color.b, 0.16), true)
			draw_rect(bottom_base_rect, base_color, true)
			var fill_height: float = size.y * fill_ratio
			var fill_rect := Rect2(Vector2(0.0, size.y - fill_height), Vector2(size.x, fill_height))
			draw_rect(fill_rect, buff_color, true)
		if icon_text != "":
			var font: Font = get_theme_default_font()
			var text_font_size: int = max(8, int(round(size.y * 0.72)))
			var text_size: Vector2 = font.get_string_size(icon_text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, text_font_size)
			var text_baseline_y: float = max(text_size.y * 0.78, (size.y + text_size.y) * 0.5 - 4.0)
			var text_position: Vector2 = Vector2((size.x - text_size.x) * 0.5, text_baseline_y)
			draw_string(font, text_position + Vector2(0.7, 0.7), icon_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_font_size, Color(0.0, 0.0, 0.0, 0.72))
			draw_string(font, text_position, icon_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_font_size, Color(0.92, 0.98, 1.0, 1.0))
		if icon_id == "healing_block":
			var center: Vector2 = size * 0.5
			var radius: float = min(size.x, size.y) * 0.34
			draw_arc(center, radius, 0.0, TAU, 36, Color(0.0, 0.0, 0.0, 1.0), 1.8)
			draw_line(
				center + Vector2(radius * 0.72, -radius * 0.72),
				center + Vector2(-radius * 0.72, radius * 0.72),
				Color(0.0, 0.0, 0.0, 1.0),
				2.0
			)
		draw_rect(outer_rect.grow(-0.5), Color(0.0, 0.0, 0.0, 0.92), false, 1.0)
		if stack_count > 0:
			var stack_text: String = str(stack_count)
			var stack_font: Font = get_theme_default_font()
			var stack_font_size: int = max(7, int(round(size.y * 0.42)))
			var stack_text_size: Vector2 = stack_font.get_string_size(stack_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, stack_font_size)
			var stack_position: Vector2 = Vector2(size.x - stack_text_size.x - 0.4, size.y - 0.4)
			for outline_offset in [Vector2(-0.7, 0.0), Vector2(0.7, 0.0), Vector2(0.0, -0.7), Vector2(0.0, 0.7)]:
				draw_string(stack_font, stack_position + outline_offset, stack_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, stack_font_size, Color(0.0, 0.0, 0.0, 0.96))
			draw_string(stack_font, stack_position, stack_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, stack_font_size, Color(1.0, 1.0, 1.0, 1.0))

class SwitchPortraitDisplay:
	extends Control

	class CirclePlate:
		extends Control

		var active: bool = false
		var draw_fill: bool = true
		var energy_ratio: float = 0.0

		func set_visual_state(new_active: bool, new_energy_ratio: float) -> void:
			var resolved_energy_ratio: float = clamp(new_energy_ratio, 0.0, 1.0)
			if resolved_energy_ratio >= 1.0 - ENERGY_READY_RATIO_EPSILON:
				resolved_energy_ratio = 1.0
			if active == new_active and abs(resolved_energy_ratio - energy_ratio) <= ENERGY_REDRAW_EPSILON:
				return
			active = new_active
			energy_ratio = resolved_energy_ratio
			queue_redraw()

		func set_draw_fill(new_draw_fill: bool) -> void:
			if draw_fill == new_draw_fill:
				return
			draw_fill = new_draw_fill
			queue_redraw()

		func _draw() -> void:
			var center: Vector2 = size * 0.5
			var radius: float = min(size.x, size.y) * 0.5 * SWITCH_COOLDOWN_MASK_RADIUS_SCALE + SWITCH_COOLDOWN_MASK_RADIUS_EXTRA
			var base_color := Color(0.04, 0.045, 0.052, 0.94)
			var inner_color := Color(0.15, 0.13, 0.12, 0.92) if active else Color(0.08, 0.08, 0.09, 0.82)
			if draw_fill:
				_draw_soft_outline(center, radius, active)
				draw_circle(center, radius + 4.0, base_color)
				draw_circle(center, radius, inner_color)
			_draw_energy_ring(center, radius + 1.5)

		func _draw_soft_outline(center: Vector2, radius: float, is_active: bool) -> void:
			var glow_color := Color(0.36, 0.78, 1.0, 0.30) if is_active else Color(0.12, 0.16, 0.2, 0.16)
			for step in range(SWITCH_PORTRAIT_SOFT_OUTLINE_STEPS):
				var progress: float = float(step + 1) / float(SWITCH_PORTRAIT_SOFT_OUTLINE_STEPS)
				var outline_radius: float = radius + 4.0 + progress * SWITCH_PORTRAIT_SOFT_OUTLINE_SPACING * float(SWITCH_PORTRAIT_SOFT_OUTLINE_STEPS)
				var alpha: float = glow_color.a * (1.0 - progress)
				draw_arc(center, outline_radius, 0.0, TAU, 72, Color(glow_color.r, glow_color.g, glow_color.b, alpha), 2.0)

		func _draw_energy_ring(center: Vector2, radius: float) -> void:
			if not active or energy_ratio <= 0.001:
				return
			var pulse: float = 0.0
			if energy_ratio >= 0.999:
				pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0056)
			var ring_width: float = 3.0 + pulse * 1.2
			var ring_color := Color(0.28, 0.72, 1.0, 0.88)
			if energy_ratio >= 0.999:
				ring_color = Color(0.72, 0.92, 1.0, 0.78 + pulse * 0.22)
				_draw_full_energy_ring(center, radius, ring_color, ring_width)
				_draw_full_energy_ring(center, radius + 4.0 + pulse * 2.0, Color(0.55, 0.86, 1.0, 0.24 + pulse * 0.22), 2.0 + pulse)
				return
			var end_angle: float = -PI * 0.5 + TAU * clamp(energy_ratio, 0.0, 0.995)
			draw_arc(center, radius, -PI * 0.5, end_angle, 72, ring_color, ring_width)

		func _draw_full_energy_ring(center: Vector2, radius: float, ring_color: Color, ring_width: float) -> void:
			var overlap: float = 0.035
			for index in range(4):
				var start_angle: float = -PI * 0.5 + float(index) * PI * 0.5 - overlap
				var end_angle: float = start_angle + PI * 0.5 + overlap * 2.0
				draw_arc(center, radius, start_angle, end_angle, 28, ring_color, ring_width)

	class CooldownMask:
		extends Control

		var cooldown_ratio: float = 0.0
		var active: bool = false

		func set_state(new_active: bool, new_cooldown_ratio: float) -> void:
			var resolved_ratio: float = clamp(new_cooldown_ratio, 0.0, 1.0)
			if active == new_active and abs(resolved_ratio - cooldown_ratio) <= COOLDOWN_REDRAW_EPSILON:
				return
			active = new_active
			cooldown_ratio = resolved_ratio
			queue_redraw()

		func _draw() -> void:
			if not active or cooldown_ratio <= 0.01:
				return
			var center: Vector2 = size * 0.5 + SWITCH_COOLDOWN_MASK_OFFSET
			var radius: float = min(size.x, size.y) * 0.5 * SWITCH_COOLDOWN_MASK_RADIUS_SCALE + SWITCH_COOLDOWN_MASK_RADIUS_EXTRA
			var shade := Color(0.0, 0.0, 0.0, 0.62)
			if cooldown_ratio >= 0.99:
				draw_circle(center, radius, shade)
				return
			var angle_total: float = TAU * cooldown_ratio
			var steps: int = max(6, int(ceil(32.0 * cooldown_ratio)))
			var points := PackedVector2Array()
			points.append(center)
			for step in range(steps + 1):
				var progress: float = float(step) / float(steps)
				var angle: float = -PI * 0.5 + angle_total * progress
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
			draw_colored_polygon(points, shade)

	var cooldown_ratio: float = 0.0
	var energy_ratio: float = 0.0
	var ready_pulse_time: float = 0.0
	var active: bool = false
	var role_id: String = ""
	var circle_back_plate: CirclePlate
	var circle_front_plate: CirclePlate
	var head_node: Node2D
	var head_sprite: Sprite2D
	var head_texture_rect: TextureRect
	var cooldown_mask: CooldownMask
	var base_visual_scale: float = 1.0

	func _process(delta: float) -> void:
		if energy_ratio < 0.999:
			return
		ready_pulse_time += delta
		_update_head_visual()
		for plate in [circle_back_plate, circle_front_plate]:
			if plate != null:
				plate.queue_redraw()

	func set_role_scene(new_role_id: String, head_scene: PackedScene) -> void:
		if role_id == new_role_id and head_node != null:
			return
		role_id = new_role_id
		_ensure_circle_plates()
		if head_node != null:
			head_node.queue_free()
			head_node = null
			head_sprite = null
			head_texture_rect = null
		if head_scene != null:
			head_node = head_scene.instantiate() as Node2D
			if head_node != null:
				add_child(head_node)
				head_sprite = head_node.find_child("Sprite2D", true, false) as Sprite2D
				head_texture_rect = head_node.find_child("TextureRect", true, false) as TextureRect
				_crop_texture_rect_to_visible_content()
				if head_sprite != null:
					head_sprite.centered = true
					head_sprite.position = Vector2.ZERO
				_fit_head_node()
		_ensure_cooldown_mask()
		_update_head_visual()

	func set_state(new_cooldown_ratio: float, new_energy_ratio: float, new_active: bool) -> void:
		var resolved_cooldown_ratio: float = clamp(new_cooldown_ratio, 0.0, 1.0)
		var resolved_energy_ratio: float = clamp(new_energy_ratio, 0.0, 1.0)
		if resolved_energy_ratio >= 1.0 - ENERGY_READY_RATIO_EPSILON:
			resolved_energy_ratio = 1.0
		var ready_changed: bool = resolved_energy_ratio >= 0.999 and energy_ratio < 0.999
		if active == new_active and not ready_changed and abs(resolved_cooldown_ratio - cooldown_ratio) <= COOLDOWN_REDRAW_EPSILON and abs(resolved_energy_ratio - energy_ratio) <= ENERGY_REDRAW_EPSILON:
			return
		cooldown_ratio = resolved_cooldown_ratio
		energy_ratio = resolved_energy_ratio
		active = new_active
		_update_head_visual()
		if cooldown_mask != null:
			cooldown_mask.set_state(active, cooldown_ratio)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_fit_head_node()

	func _fit_head_node() -> void:
		if head_node == null:
			return
		var circle_radius: float = min(size.x, size.y) * 0.5 * SWITCH_COOLDOWN_MASK_RADIUS_SCALE + SWITCH_COOLDOWN_MASK_RADIUS_EXTRA
		var content_size: Vector2 = Vector2.ONE * circle_radius * 2.0 * SWITCH_PORTRAIT_CONTENT_DIAMETER_SCALE
		var content_position: Vector2 = size * 0.5 - content_size * 0.5 + SWITCH_COOLDOWN_MASK_OFFSET + SWITCH_PORTRAIT_CONTENT_OFFSET
		if role_id == "swordsman" or role_id == "mage":
			content_position += SWITCH_PORTRAIT_SIDE_CONTENT_OFFSET
		if role_id == "swordsman":
			content_position += SWITCH_PORTRAIT_SWORDSMAN_CONTENT_OFFSET
		elif role_id == "gunner":
			content_position += SWITCH_PORTRAIT_GUNNER_CONTENT_OFFSET
		elif role_id == "mage":
			content_position += SWITCH_PORTRAIT_MAGE_CONTENT_OFFSET
		var texture_size: Vector2 = Vector2(96.0, 96.0)
		for plate in [circle_back_plate, circle_front_plate]:
			if plate == null:
				continue
			plate.position = Vector2.ZERO
			plate.size = size
			plate.custom_minimum_size = size
		if head_texture_rect != null:
			head_node.position = content_position
			head_node.scale = Vector2.ONE
			head_texture_rect.anchor_left = 0.0
			head_texture_rect.anchor_top = 0.0
			head_texture_rect.anchor_right = 0.0
			head_texture_rect.anchor_bottom = 0.0
			head_texture_rect.position = Vector2.ZERO
			head_texture_rect.size = content_size
			head_texture_rect.custom_minimum_size = content_size
			head_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			head_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			head_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif head_sprite != null and head_sprite.texture != null:
			head_node.position = size * 0.5
			texture_size = head_sprite.texture.get_size()
			var max_dimension: float = max(texture_size.x, texture_size.y)
			base_visual_scale = min(content_size.x, content_size.y) / max(max_dimension, 1.0)
		if cooldown_mask != null:
			cooldown_mask.position = Vector2.ZERO
			cooldown_mask.size = size
			cooldown_mask.custom_minimum_size = size
		_update_head_visual()

	func _crop_texture_rect_to_visible_content() -> void:
		if head_texture_rect == null or head_texture_rect.texture == null:
			return
		var source_texture: Texture2D = head_texture_rect.texture
		var image: Image = source_texture.get_image()
		if image == null or image.is_empty():
			return
		var min_x: int = image.get_width()
		var min_y: int = image.get_height()
		var max_x: int = -1
		var max_y: int = -1
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x, y).a <= SWITCH_PORTRAIT_ALPHA_CROP_THRESHOLD:
					continue
				min_x = min(min_x, x)
				min_y = min(min_y, y)
				max_x = max(max_x, x)
				max_y = max(max_y, y)
		if max_x < min_x or max_y < min_y:
			return
		var crop_region: Rect2 = Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
		var cropped_texture: AtlasTexture = AtlasTexture.new()
		cropped_texture.atlas = source_texture
		cropped_texture.region = crop_region
		head_texture_rect.texture = cropped_texture

	func _ensure_circle_plates() -> void:
		if circle_back_plate != null and circle_front_plate != null:
			return
		if circle_back_plate == null:
			circle_back_plate = CirclePlate.new()
			circle_back_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
			circle_back_plate.z_index = -1
			circle_back_plate.set_draw_fill(true)
			add_child(circle_back_plate)
		if circle_front_plate == null:
			circle_front_plate = CirclePlate.new()
			circle_front_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
			circle_front_plate.z_index = 14
			circle_front_plate.set_draw_fill(false)
			add_child(circle_front_plate)
		for plate in [circle_back_plate, circle_front_plate]:
			plate.position = Vector2.ZERO
			plate.size = size
			plate.custom_minimum_size = size

	func _ensure_cooldown_mask() -> void:
		if cooldown_mask != null:
			return
		cooldown_mask = CooldownMask.new()
		cooldown_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown_mask.z_index = 10
		add_child(cooldown_mask)
		cooldown_mask.position = Vector2.ZERO
		cooldown_mask.size = size
		cooldown_mask.custom_minimum_size = size
		cooldown_mask.set_state(active, cooldown_ratio)

	func _update_head_visual() -> void:
		if head_node == null:
			return
		var pulse: float = 0.0
		if energy_ratio >= 0.999:
			pulse = 0.04 + 0.04 * sin(ready_pulse_time * 5.6)
		var target_alpha: float = 1.0 if active else 0.58
		for plate in [circle_back_plate, circle_front_plate]:
			if plate != null:
				plate.set_visual_state(active, energy_ratio)
		if head_texture_rect != null:
			head_node.scale = Vector2.ONE
			head_texture_rect.modulate = Color(1.0, 1.0, 1.0, target_alpha)
			return
		var target_scale: float = 1.0 + pulse
		head_node.scale = Vector2.ONE * base_visual_scale * target_scale
		head_node.modulate = Color(1.0, 1.0, 1.0, target_alpha)


class UltimateEnergyDisplay:
	extends Control

	var fill_ratio: float = 0.0
	var skill_name: String = ""
	var ready_pulse_time: float = 0.0

	func _process(delta: float) -> void:
		if fill_ratio < 0.999:
			return
		ready_pulse_time += delta
		queue_redraw()

	func set_state(new_ratio: float) -> void:
		var resolved_ratio: float = clamp(new_ratio, 0.0, 1.0)
		if resolved_ratio >= 1.0 - ENERGY_READY_RATIO_EPSILON:
			resolved_ratio = 1.0
		var ready_changed: bool = resolved_ratio >= 0.999 and fill_ratio < 0.999
		if not ready_changed and abs(resolved_ratio - fill_ratio) <= ENERGY_REDRAW_EPSILON:
			return
		fill_ratio = resolved_ratio
		queue_redraw()

	func set_skill_name(new_skill_name: String) -> void:
		if skill_name == new_skill_name:
			return
		skill_name = new_skill_name
		queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = min(size.x, size.y) * 0.5 - 4.0
		var inner_radius: float = radius - 5.0
		draw_circle(center, radius, Color(0.0, 0.0, 0.0, 0.94))
		draw_circle(center, inner_radius, Color(0.08, 0.1, 0.16, 0.98))
		_draw_fill(center, inner_radius, fill_ratio)
		if fill_ratio >= 0.999:
			_draw_ready_highlight(center, radius, inner_radius)
		draw_arc(center, radius, 0.0, TAU, 32, Color(0.0, 0.0, 0.0, 1.0), 3.0)

		if skill_name != "":
			var font := get_theme_default_font()
			var font_size := 14
			var text_size := font.get_string_size(skill_name, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
			var text_position := center - text_size * 0.5 + Vector2(0.0, 3.0)
			draw_string(font, text_position + Vector2(1.0, 1.0), skill_name, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.95))
			draw_string(font, text_position, skill_name, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, Color(1.0, 0.96, 0.72, 1.0))

	func _draw_ready_highlight(center: Vector2, radius: float, inner_radius: float) -> void:
		var pulse: float = 0.5 + 0.5 * sin(ready_pulse_time * 5.6)
		var halo_radius: float = radius + 3.0 + pulse * 4.0
		draw_circle(center, inner_radius, Color(0.32, 0.76, 1.0, 0.12 + pulse * 0.10))
		draw_arc(center, halo_radius, 0.0, TAU, 64, Color(0.72, 0.92, 1.0, 0.42 + pulse * 0.36), 2.0 + pulse * 1.4)
		draw_arc(center, inner_radius - 1.0, 0.0, TAU, 64, Color(1.0, 0.96, 0.72, 0.35 + pulse * 0.28), 1.5)

	func _draw_fill(center: Vector2, radius: float, ratio: float) -> void:
		if ratio <= 0.0:
			return
		if ratio >= 0.999:
			draw_circle(center, radius, Color(0.24, 0.68, 1.0, 0.72))
			return

		var top_y: float = center.y + radius - radius * 2.0 * ratio
		var min_y: float = center.y - radius
		var max_y: float = center.y + radius
		var line_y: float = clamp(top_y, min_y, max_y)
		var y_ratio: float = clamp((line_y - center.y) / radius, -1.0, 1.0)
		var right_angle: float = asin(y_ratio)
		var left_angle: float = PI - right_angle
		var points := PackedVector2Array()
		var steps: int = 28
		for step in range(steps + 1):
			var progress: float = float(step) / float(steps)
			var angle: float = left_angle + (right_angle - left_angle) * progress
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, Color(0.22, 0.64, 1.0, 0.62))

		var line_offset: float = line_y - center.y
		if abs(line_offset) <= radius:
			var half_width_at_line: float = sqrt(max(radius * radius - line_offset * line_offset, 0.0))
			draw_line(
				Vector2(center.x - half_width_at_line, line_y),
				Vector2(center.x + half_width_at_line, line_y),
				Color(0.72, 0.9, 1.0, 0.75),
				2.0
			)

var switch_cd_left_key_label: Label
var switch_cd_right_key_label: Label
var switch_cd_time_label: Label
var switch_cd_portraits: Dictionary = {}
var switch_cd_active_role_id: String = ""
var switch_cd_layout_initialized: bool = false
var switch_cd_layout_tween: Tween
var switch_cd_widget: Control
var skill_cd_slots: Array = []
var buff_status_bar: HBoxContainer
var buff_status_slots: Array = []
var ultimate_energy_widget: UltimateEnergyDisplay
var ultimate_key_label: Label
var ultimate_current_energy: float = 0.0
var ultimate_required_energy: float = 100.0
var ultimate_display: Dictionary = {}
var experience_bar: ProgressBar
var experience_label: Label
var hover_detail: Control
var action_key_labels_ready: bool = false

func _ready() -> void:
	anchor_left = 0.5
	anchor_top = 1.0
	anchor_right = 0.5
	anchor_bottom = 1.0
	var total_width: float = SWITCH_WIDGET_WIDTH + SWITCH_WIDGET_GAP + SKILL_PANEL_WIDTH + ULTIMATE_WIDGET_GAP + ULTIMATE_WIDGET_SIZE
	offset_left = -total_width * 0.5
	offset_top = -128.0
	offset_right = total_width * 0.5
	offset_bottom = -10.0
	_build_widgets()
	hover_detail = SURVIVORS_HOVER_DETAIL.new()
	add_child(hover_detail)

func update_experience(current_experience: int, required_experience: int) -> void:
	if experience_bar != null:
		var resolved_required: int = max(required_experience, 1)
		if int(experience_bar.max_value) != resolved_required:
			experience_bar.max_value = resolved_required
		if int(experience_bar.value) != current_experience:
			experience_bar.value = current_experience
	if experience_label != null:
		var next_text: String = "%d / %d XP" % [current_experience, required_experience]
		if experience_label.text != next_text:
			experience_label.text = next_text

func update_switch_cooldown(role_id: String, cooldown_remaining: float, cooldown_duration: float, switch_energy: float = 0.0, switch_energy_required: float = 100.0, switch_energy_by_role: Dictionary = {}) -> void:
	_refresh_switch_key_labels()
	if switch_cd_portraits.is_empty():
		return
	var duration: float = max(cooldown_duration, 0.01)
	var ratio: float = clamp(cooldown_remaining / duration, 0.0, 1.0)
	var energy_values: Dictionary = switch_energy_by_role
	if energy_values.is_empty():
		energy_values = {role_id: switch_energy}
	_layout_switch_portraits(role_id, switch_cd_layout_initialized and switch_cd_active_role_id != role_id)
	switch_cd_active_role_id = role_id
	switch_cd_layout_initialized = true
	for switch_role_id in SWITCH_ROLE_ORDER:
		var switch_role_id_string: String = str(switch_role_id)
		var portrait: SwitchPortraitDisplay = switch_cd_portraits.get(switch_role_id_string, null) as SwitchPortraitDisplay
		if portrait == null:
			continue
		var role_energy: float = float(energy_values.get(switch_role_id_string, 0.0))
		var energy_ratio: float = clamp(max(role_energy, 0.0) / max(switch_energy_required, 1.0), 0.0, 1.0)
		if role_energy >= switch_energy_required or energy_ratio >= 1.0 - ENERGY_READY_RATIO_EPSILON:
			energy_ratio = 1.0
		portrait.set_state(ratio, energy_ratio, switch_role_id_string == role_id)
	if switch_cd_time_label != null:
		var next_text: String = "%.1f" % cooldown_remaining if cooldown_remaining > 0.05 else ""
		if switch_cd_time_label.text != next_text:
			switch_cd_time_label.text = next_text

func update_ultimate_energy(current_energy: float, required_energy: float, display_data: Dictionary = {}, force_ready: bool = false) -> void:
	_refresh_action_key_labels()
	ultimate_current_energy = max(current_energy, 0.0)
	ultimate_required_energy = max(required_energy, 1.0)
	ultimate_display = display_data.duplicate(true)
	if ultimate_energy_widget != null:
		ultimate_energy_widget.set_skill_name(str(ultimate_display.get("name", "大招")))
		var energy_ratio: float = ultimate_current_energy / ultimate_required_energy
		if force_ready or ultimate_current_energy >= ultimate_required_energy or energy_ratio >= 1.0 - ENERGY_READY_RATIO_EPSILON:
			energy_ratio = 1.0
		ultimate_energy_widget.set_state(energy_ratio)

func update_skill_cooldown_slots(slot_data_list: Array) -> void:
	for index in range(skill_cd_slots.size()):
		var slot_nodes: Dictionary = skill_cd_slots[index]
		var slot_view: SkillCooldownIcon = slot_nodes["view"] as SkillCooldownIcon
		var label: Label = slot_nodes["label"] as Label
		if index >= slot_data_list.size():
			slot_view.set_state(false, Color(0.12, 0.13, 0.16, 1.0), 0.0)
			if slot_view.tooltip_text != "":
				slot_view.tooltip_text = ""
			if label.text != "":
				label.text = ""
			if str(slot_nodes.get("title", "")) != "":
				slot_nodes["title"] = ""
			if str(slot_nodes.get("description", "")) != "":
				slot_nodes["description"] = ""
			if str(slot_nodes.get("slot_label", "")) != "":
				slot_nodes["slot_label"] = ""
			continue

		var slot_data: Dictionary = slot_data_list[index]
		var slot_color: Color = Color(1.0, 1.0, 1.0, 1.0)
		var color_value: Variant = slot_data.get("color", slot_color)
		if color_value is Color:
			slot_color = color_value
		var duration: float = max(float(slot_data.get("duration", 1.0)), 0.01)
		var remaining: float = clamp(float(slot_data.get("remaining", 0.0)), 0.0, duration)
		var ratio: float = remaining / duration
		slot_view.set_state(true, slot_color, ratio)
		var slot_name: String = str(slot_data.get("name", "OK"))
		if label.text != slot_name:
			label.text = slot_name
		if slot_view.tooltip_text != "":
			slot_view.tooltip_text = ""
		if str(slot_nodes.get("title", "")) != slot_name:
			slot_nodes["title"] = slot_name
		var next_description: String = _build_slot_tooltip(slot_data, duration, remaining)
		if str(slot_nodes.get("description", "")) != next_description:
			slot_nodes["description"] = next_description
		var next_slot_label: String = str(slot_data.get("slot_label", "技能冷却"))
		if str(slot_nodes.get("slot_label", "")) != next_slot_label:
			slot_nodes["slot_label"] = next_slot_label

func update_buff_slots(buff_data_list: Array) -> void:
	if buff_status_bar == null:
		return
	buff_status_bar.visible = not buff_data_list.is_empty()
	for index in range(buff_status_slots.size()):
		var slot_nodes: Dictionary = buff_status_slots[index]
		var slot_view: BuffStatusIcon = slot_nodes["view"] as BuffStatusIcon
		if index >= buff_data_list.size():
			slot_view.visible = false
			slot_view.tooltip_text = ""
			slot_nodes["title"] = ""
			slot_nodes["description"] = ""
			continue
		var buff_data: Dictionary = buff_data_list[index]
		var duration: float = max(float(buff_data.get("duration", 1.0)), 0.001)
		var remaining: float = clamp(float(buff_data.get("remaining", duration)), 0.0, duration)
		var ratio: float = remaining / duration
		var slot_color: Color = Color(0.36, 0.76, 1.0, 0.92)
		var color_value: Variant = buff_data.get("color", slot_color)
		if color_value is Color:
			slot_color = color_value
		var icon_text: String = str(buff_data.get("text", ""))
		var stack_count: int = int(buff_data.get("stacks", 0))
		var cooldown_mode: bool = bool(buff_data.get("cooldown", false))
		var icon_id: String = str(buff_data.get("icon_id", ""))
		var base_color: Color = Color(0.62, 0.06, 0.05, 0.92)
		var base_color_value: Variant = buff_data.get("base_color", base_color)
		if base_color_value is Color:
			base_color = base_color_value
		slot_view.visible = true
		slot_view.set_state(ratio, slot_color, icon_text, stack_count, cooldown_mode, base_color, icon_id)
		slot_view.tooltip_text = ""
		slot_nodes["title"] = str(buff_data.get("name", "Buff"))
		var time_label: String = "\u51B7\u5374 %.1f / %.1f \u79D2" if cooldown_mode else "\u5269\u4F59 %.1f / %.1f \u79D2"
		slot_nodes["description"] = "%s\n%s" % [str(buff_data.get("description", "")), time_label % [remaining, duration]]

func _build_widgets() -> void:
	switch_cd_widget = Control.new()
	switch_cd_widget.position = Vector2(0.0, 0.0)
	switch_cd_widget.custom_minimum_size = Vector2(SWITCH_WIDGET_WIDTH, SWITCH_WIDGET_HEIGHT)
	switch_cd_widget.size = Vector2(SWITCH_WIDGET_WIDTH, SWITCH_WIDGET_HEIGHT)
	add_child(switch_cd_widget)

	var left_arrow_box := Control.new()
	left_arrow_box.position = Vector2(0.0, 0.0)
	left_arrow_box.custom_minimum_size = Vector2(38.0, SWITCH_WIDGET_HEIGHT)
	left_arrow_box.z_index = 3
	switch_cd_widget.add_child(left_arrow_box)

	var left_arrow_label := Label.new()
	left_arrow_label.text = "<"
	left_arrow_label.position = Vector2(0.0, 17.0)
	left_arrow_label.custom_minimum_size = Vector2(38.0, 32.0)
	left_arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_arrow_label.add_theme_font_size_override("font_size", 28)
	left_arrow_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 1.0))
	left_arrow_box.add_child(left_arrow_label)

	switch_cd_left_key_label = Label.new()
	switch_cd_left_key_label.position = Vector2(0.0, 47.0)
	switch_cd_left_key_label.custom_minimum_size = Vector2(38.0, 22.0)
	switch_cd_left_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_cd_left_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	switch_cd_left_key_label.add_theme_font_size_override("font_size", 16)
	left_arrow_box.add_child(switch_cd_left_key_label)

	for switch_role_id in SWITCH_ROLE_ORDER:
		var switch_role_id_string: String = str(switch_role_id)
		var portrait := SwitchPortraitDisplay.new()
		portrait.size = Vector2(56.0, 56.0) * SWITCH_HEAD_SIZE_MULTIPLIER
		portrait.custom_minimum_size = Vector2(56.0, 56.0) * SWITCH_HEAD_SIZE_MULTIPLIER
		var scene_value: Variant = SWITCH_HEAD_SCENES.get(switch_role_id_string, null)
		if scene_value is PackedScene:
			portrait.set_role_scene(switch_role_id_string, scene_value)
		switch_cd_widget.add_child(portrait)
		switch_cd_portraits[switch_role_id_string] = portrait

	switch_cd_time_label = Label.new()
	switch_cd_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	switch_cd_time_label.position = Vector2(22.0, 75.0)
	switch_cd_time_label.custom_minimum_size = Vector2(132.0, 40.0)
	switch_cd_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_cd_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	switch_cd_time_label.add_theme_font_size_override("font_size", 15)
	switch_cd_time_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	switch_cd_time_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	switch_cd_time_label.add_theme_constant_override("shadow_offset_x", 1)
	switch_cd_time_label.add_theme_constant_override("shadow_offset_y", 1)
	switch_cd_time_label.text = ""
	switch_cd_widget.add_child(switch_cd_time_label)

	var right_arrow_box := Control.new()
	right_arrow_box.position = Vector2(SWITCH_WIDGET_WIDTH - 38.0, 0.0)
	right_arrow_box.custom_minimum_size = Vector2(38.0, SWITCH_WIDGET_HEIGHT)
	right_arrow_box.z_index = 3
	switch_cd_widget.add_child(right_arrow_box)

	var right_arrow_label := Label.new()
	right_arrow_label.text = ">"
	right_arrow_label.position = Vector2(0.0, 17.0)
	right_arrow_label.custom_minimum_size = Vector2(38.0, 32.0)
	right_arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_arrow_label.add_theme_font_size_override("font_size", 28)
	right_arrow_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 1.0))
	right_arrow_box.add_child(right_arrow_label)

	switch_cd_right_key_label = Label.new()
	switch_cd_right_key_label.position = Vector2(0.0, 47.0)
	switch_cd_right_key_label.custom_minimum_size = Vector2(38.0, 22.0)
	switch_cd_right_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_cd_right_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	switch_cd_right_key_label.add_theme_font_size_override("font_size", 16)
	right_arrow_box.add_child(switch_cd_right_key_label)

	var skill_cd_panel := HBoxContainer.new()
	skill_cd_panel.position = Vector2(SWITCH_WIDGET_WIDTH + SWITCH_WIDGET_GAP, 10.0)
	skill_cd_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_cd_panel.add_theme_constant_override("separation", 14)
	add_child(skill_cd_panel)

	buff_status_bar = HBoxContainer.new()
	buff_status_bar.position = skill_cd_panel.position + Vector2(0.0, -BUFF_SLOT_SIZE - 6.0)
	buff_status_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	buff_status_bar.add_theme_constant_override("separation", BUFF_SLOT_GAP)
	buff_status_bar.visible = false
	add_child(buff_status_bar)

	for index in range(SKILL_CD_SLOT_COUNT):
		var buff_icon: BuffStatusIcon = BuffStatusIcon.new()
		buff_icon.custom_minimum_size = Vector2(BUFF_SLOT_SIZE, BUFF_SLOT_SIZE)
		buff_icon.size = Vector2(BUFF_SLOT_SIZE, BUFF_SLOT_SIZE)
		buff_icon.visible = false
		buff_icon.mouse_entered.connect(_on_buff_slot_hovered.bind(buff_icon, index))
		buff_icon.mouse_exited.connect(_on_skill_slot_unhovered)
		buff_status_bar.add_child(buff_icon)
		buff_status_slots.append({
			"view": buff_icon,
			"title": "",
			"description": ""
		})

	for index in range(SKILL_CD_SLOT_COUNT):
		var slot_icon := SkillCooldownIcon.new()
		slot_icon.custom_minimum_size = Vector2(SKILL_CD_SLOT_SIZE, SKILL_CD_SLOT_SIZE)
		slot_icon.set_state(false, Color(0.12, 0.13, 0.16, 1.0), 0.0)
		slot_icon.tooltip_text = ""
		slot_icon.mouse_entered.connect(_on_skill_slot_hovered.bind(slot_icon, index))
		slot_icon.mouse_exited.connect(_on_skill_slot_unhovered)
		skill_cd_panel.add_child(slot_icon)

		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.text = ""
		slot_icon.add_child(label)

		skill_cd_slots.append({
			"view": slot_icon,
			"label": label,
			"title": "",
			"description": "",
			"slot_label": ""
		})

	ultimate_energy_widget = UltimateEnergyDisplay.new()
	ultimate_energy_widget.position = Vector2(SWITCH_WIDGET_WIDTH + SWITCH_WIDGET_GAP + SKILL_PANEL_WIDTH + ULTIMATE_WIDGET_GAP, -18.0)
	ultimate_energy_widget.size = Vector2(ULTIMATE_WIDGET_SIZE, ULTIMATE_WIDGET_SIZE)
	ultimate_energy_widget.custom_minimum_size = Vector2(ULTIMATE_WIDGET_SIZE, ULTIMATE_WIDGET_SIZE)
	ultimate_energy_widget.set_state(0.0)
	ultimate_energy_widget.tooltip_text = ""
	ultimate_energy_widget.mouse_entered.connect(_on_ultimate_energy_hovered)
	ultimate_energy_widget.mouse_exited.connect(_on_skill_slot_unhovered)
	add_child(ultimate_energy_widget)

	ultimate_key_label = Label.new()
	ultimate_key_label.position = ultimate_energy_widget.position + Vector2(0.0, ULTIMATE_WIDGET_SIZE - 4.0)
	ultimate_key_label.custom_minimum_size = Vector2(ULTIMATE_WIDGET_SIZE, 24.0)
	ultimate_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ultimate_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ultimate_key_label.add_theme_font_size_override("font_size", 16)
	ultimate_key_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 1.0))
	ultimate_key_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	ultimate_key_label.add_theme_constant_override("shadow_offset_x", 1)
	ultimate_key_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(ultimate_key_label)

	experience_bar = ProgressBar.new()
	experience_bar.position = Vector2(SWITCH_WIDGET_WIDTH + SWITCH_WIDGET_GAP, 78.0)
	experience_bar.custom_minimum_size = Vector2(SKILL_PANEL_WIDTH, 14.0)
	experience_bar.show_percentage = false
	var exp_fill := StyleBoxFlat.new()
	exp_fill.bg_color = Color(1.0, 0.82, 0.16, 0.95)
	exp_fill.set_corner_radius_all(5)
	var exp_background := StyleBoxFlat.new()
	exp_background.bg_color = Color(0.12, 0.1, 0.04, 0.82)
	exp_background.border_color = Color(0.92, 0.72, 0.16, 0.9)
	exp_background.set_border_width_all(1)
	exp_background.set_corner_radius_all(5)
	experience_bar.add_theme_stylebox_override("fill", exp_fill)
	experience_bar.add_theme_stylebox_override("background", exp_background)
	add_child(experience_bar)

	experience_label = Label.new()
	experience_label.position = Vector2(SWITCH_WIDGET_WIDTH + SWITCH_WIDGET_GAP, 72.0)
	experience_label.custom_minimum_size = Vector2(SKILL_PANEL_WIDTH, 26.0)
	experience_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	experience_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	experience_label.add_theme_font_size_override("font_size", 13)
	experience_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.62, 1.0))
	experience_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	experience_label.add_theme_constant_override("shadow_offset_x", 1)
	experience_label.add_theme_constant_override("shadow_offset_y", 1)
	experience_label.text = "0 / 30 XP"
	add_child(experience_label)

	_refresh_action_key_labels()
	_layout_switch_portraits("gunner", false)

func set_switch_widget_visible(visible_value: bool) -> void:
	if switch_cd_widget == null:
		return
	switch_cd_widget.visible = visible_value

func _layout_switch_portraits(active_role_id: String, animate: bool) -> void:
	var active_index: int = SWITCH_ROLE_ORDER.find(active_role_id)
	if active_index < 0:
		active_index = 1
	var role_count: int = SWITCH_ROLE_ORDER.size()
	var left_role_id: String = str(SWITCH_ROLE_ORDER[(active_index + role_count - 1) % role_count])
	var top_role_id: String = str(SWITCH_ROLE_ORDER[active_index])
	var right_role_id: String = str(SWITCH_ROLE_ORDER[(active_index + 1) % role_count])
	if switch_cd_layout_tween != null and switch_cd_layout_tween.is_valid():
		switch_cd_layout_tween.kill()
	switch_cd_layout_tween = create_tween() if animate else null
	if switch_cd_layout_tween != null:
		switch_cd_layout_tween.set_parallel(true)
		switch_cd_layout_tween.set_trans(Tween.TRANS_CUBIC)
		switch_cd_layout_tween.set_ease(Tween.EASE_OUT)
	_place_switch_portrait(left_role_id, Vector2(-44.0, -24.0), Vector2(54.0, 54.0) * SWITCH_HEAD_SIZE_MULTIPLIER, 0, animate)
	_place_switch_portrait(top_role_id, Vector2(-2.0, -52.0), Vector2(72.0, 72.0) * SWITCH_HEAD_SIZE_MULTIPLIER, 1, animate)
	_place_switch_portrait(right_role_id, Vector2(85.0, -24.0), Vector2(54.0, 54.0) * SWITCH_HEAD_SIZE_MULTIPLIER, 0, animate)

func _place_switch_portrait(role_id: String, next_position: Vector2, next_size: Vector2, z_index_value: int, animate: bool) -> void:
	var portrait: SwitchPortraitDisplay = switch_cd_portraits.get(role_id, null) as SwitchPortraitDisplay
	if portrait == null:
		return
	portrait.custom_minimum_size = next_size
	portrait.z_index = z_index_value
	if animate and switch_cd_layout_tween != null:
		switch_cd_layout_tween.tween_property(portrait, "position", next_position, SWITCH_PORTRAIT_ANIMATION_DURATION)
		switch_cd_layout_tween.tween_property(portrait, "size", next_size, SWITCH_PORTRAIT_ANIMATION_DURATION)
		switch_cd_layout_tween.tween_callback(Callable(portrait, "_fit_head_node")).set_delay(SWITCH_PORTRAIT_ANIMATION_DURATION)
		return
	portrait.position = next_position
	portrait.size = next_size
	portrait._fit_head_node()

func _build_slot_tooltip(slot_data: Dictionary, duration: float, remaining: float) -> String:
	var description := str(slot_data.get("description", ""))
	var status := "剩余 %.1f / %.1f 秒" % [remaining, duration] if remaining > 0.05 else "冷却就绪"
	if description == "":
		description = status
	else:
		description = "%s\n%s" % [description, status]
	return description

func _on_skill_slot_hovered(slot_icon: Control, index: int) -> void:
	if index < 0 or index >= skill_cd_slots.size():
		return
	var slot_nodes: Dictionary = skill_cd_slots[index]
	var title := str(slot_nodes.get("title", ""))
	if title == "":
		title = "技能"
	var description := str(slot_nodes.get("description", ""))
	if description == "":
		return
	var item := {
		"title": title,
		"slot_label": str(slot_nodes.get("slot_label", "技能冷却")),
		"description": description
	}
	if hover_detail != null and hover_detail.has_method("show_item"):
		hover_detail.show_item(item, get_viewport().get_mouse_position(), Rect2(slot_icon.global_position, slot_icon.size))

func _on_buff_slot_hovered(slot_icon: Control, index: int) -> void:
	if index < 0 or index >= buff_status_slots.size():
		return
	var slot_nodes: Dictionary = buff_status_slots[index]
	var title := str(slot_nodes.get("title", ""))
	var description := str(slot_nodes.get("description", ""))
	if title == "" or description == "":
		return
	var item := {
		"title": title,
		"slot_label": "Buff",
		"description": description
	}
	if hover_detail != null and hover_detail.has_method("show_item"):
		hover_detail.show_item(item, get_viewport().get_mouse_position(), Rect2(slot_icon.global_position, slot_icon.size))

func _on_ultimate_energy_hovered() -> void:
	if ultimate_energy_widget == null:
		return
	var ultimate_key := ""
	if ultimate_key_label != null:
		ultimate_key = ultimate_key_label.text
	if ultimate_key == "":
		ultimate_key = GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_ULTIMATE))
	var status := "已充满，可以按 %s 释放大招。" % ultimate_key if ultimate_current_energy >= ultimate_required_energy else "还需 %.0f 点能量。" % max(0.0, ultimate_required_energy - ultimate_current_energy)
	var ultimate_name := str(ultimate_display.get("name", "大招"))
	var ultimate_description := str(ultimate_display.get("description", "当前英雄的大招。"))
	var item := {
		"title": ultimate_name,
		"slot_label": "大招 / 能量",
		"description": "%s\n\n能量 %.0f / %.0f。\n%s\n攻击命中与战斗节奏会积累大招能量，充满后释放当前角色的大招。" % [
			ultimate_description,
			ultimate_current_energy,
			ultimate_required_energy,
			status
		]
	}
	if hover_detail != null and hover_detail.has_method("show_item"):
		hover_detail.show_item(item, get_viewport().get_mouse_position(), Rect2(ultimate_energy_widget.global_position, ultimate_energy_widget.size))

func _on_skill_slot_unhovered() -> void:
	if hover_detail != null:
		if hover_detail.has_method("request_hide"):
			hover_detail.request_hide()
		elif hover_detail.has_method("hide_detail"):
			hover_detail.hide_detail()

func _refresh_switch_key_labels() -> void:
	_refresh_action_key_labels()

func _refresh_action_key_labels(force: bool = false) -> void:
	if action_key_labels_ready and not force:
		return
	if switch_cd_left_key_label != null:
		switch_cd_left_key_label.text = GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_SWITCH_PREV))
	if switch_cd_right_key_label != null:
		switch_cd_right_key_label.text = GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_SWITCH_NEXT))
	if ultimate_key_label != null:
		ultimate_key_label.text = GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_ULTIMATE))
	action_key_labels_ready = true

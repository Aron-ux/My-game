extends Control

const ENERGY_REDRAW_EPSILON: float = 0.0001

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

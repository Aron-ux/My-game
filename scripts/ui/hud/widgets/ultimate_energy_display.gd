extends Control

const ENERGY_REDRAW_EPSILON: float = 0.0001
const ENERGY_READY_RATIO_EPSILON: float = 0.001

var fill_ratio: float = 0.0
var skill_name: String = ""
var ready_pulse_time: float = 0.0

func _ready() -> void:
	_update_processing()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_update_processing()

func _update_processing() -> void:
	set_process(fill_ratio >= 0.999 and is_visible_in_tree())

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
	_update_processing()
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

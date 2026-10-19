extends "res://assets/enemies/pixel_sheet_visual.gd"

# Rows: 0 run, 1 run_enraged.
const ROW_RUN := 0
const ROW_ENRAGED := 1

var enraged := false


func _loop_row() -> int:
	return ROW_ENRAGED if enraged else ROW_RUN


func _wants_fx() -> bool:
	return enraged


func _draw_fx(canvas: Node2D) -> void:
	if not enraged:
		return
	# Heat shimmer: embers circling the raised quills.
	for index in 6:
		var angle := anim_time * 1.6 + float(index) * TAU / 6.0
		var point := Vector2(cos(angle) * 36.0, sin(angle) * 12.0 - 20.0)
		var flicker := 0.55 + 0.45 * sin(anim_time * 9.0 + float(index) * 2.1)
		draw_pixel(canvas, point, Color(1.0, 0.45 + 0.25 * flicker, 0.18, 0.75 * flicker), 3.0)

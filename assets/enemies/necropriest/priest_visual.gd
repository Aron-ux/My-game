extends "res://assets/enemies/pixel_sheet_visual.gd"

# Rows: 0 idle (floating), 1 cast (staff raised, used for prayer and mark).
const ROW_CAST := 1


func play_cast() -> void:
	play_once(ROW_CAST)

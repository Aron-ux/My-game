extends "res://assets/enemies/pixel_sheet_visual.gd"

# variant: vine (move/throw), tree (walk/throw), young (run), seed (fly/landed/hatching).
const ROW_THROW := 1
const SEED_ROW_FLY := 0
const SEED_ROW_LANDED := 1
const SEED_ROW_HATCHING := 2
const SEED_HATCH_WINDOW := 0.8

@export var variant := "vine"


func play_cast() -> void:
	if variant == "vine" or variant == "tree":
		play_once(ROW_THROW)


func _loop_row() -> int:
	if variant != "seed":
		return 0
	var state := _seed_state()
	if not bool(state.get("landed", false)):
		return SEED_ROW_FLY
	return SEED_ROW_HATCHING if float(state.get("land_remaining", 2.0)) <= SEED_HATCH_WINDOW else SEED_ROW_LANDED


func _apply_frame() -> void:
	super._apply_frame()
	if variant != "seed" or sprite == null or _loop_row() != SEED_ROW_HATCHING:
		return
	# The husk cracks open in step with the real hatch countdown instead of looping.
	var remaining := float(_seed_state().get("land_remaining", 0.0))
	var column := clampi(int((1.0 - remaining / SEED_HATCH_WINDOW) * columns), 0, columns - 1)
	sprite.frame = SEED_ROW_HATCHING * columns + column
	flash.frame = sprite.frame


func _seed_state() -> Dictionary:
	var owner_node := get_parent()
	var state: Variant = owner_node.get("plant_state") if owner_node != null else null
	return state if state is Dictionary else {}

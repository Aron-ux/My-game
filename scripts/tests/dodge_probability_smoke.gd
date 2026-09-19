extends SceneTree

const FLOW := preload("res://scripts/player/player_equipment_flow.gd")

func _init() -> void:
	assert(is_zero_approx(FLOW.calculate_dodge_chance([])))
	assert(is_equal_approx(FLOW.calculate_dodge_chance([0.15, 0.15, 0.35, 0.30, 0.15]), 0.720573125))
	assert(is_equal_approx(FLOW.calculate_dodge_chance([0.10, 0.10]), 0.19))
	assert(is_equal_approx(FLOW.calculate_dodge_chance([0.50, 0.50, 0.50]), 0.875))
	assert(is_equal_approx(FLOW.calculate_dodge_chance([1.0]), 1.0))
	print("DODGE_PROBABILITY_SMOKE_OK")
	quit()

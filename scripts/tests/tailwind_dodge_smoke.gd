extends SceneTree

const BLESSINGS := preload("res://scripts/player/player_blessing_system.gd")

func _init() -> void:
	assert(is_equal_approx(BLESSINGS._sum_stat_bonus({"tailwind": {3: 1}}, "dodge_chance"), 0.12))
	assert(is_equal_approx(BLESSINGS._sum_stat_bonus({"tailwind": {4: 1}}, "dodge_chance"), 0.24))
	assert(is_equal_approx(BLESSINGS._sum_stat_bonus({"tailwind": {3: 2}}, "dodge_chance"), 1.0 - 0.88 * 0.88))
	assert(is_equal_approx(BLESSINGS._sum_stat_bonus({"tailwind": {3: 1, 4: 1}}, "dodge_chance"), 1.0 - 0.88 * 0.76))
	assert(is_zero_approx(BLESSINGS._sum_stat_bonus({"tailwind": {3: 1, 4: 1}}, "dodge")))
	assert(is_equal_approx(BLESSINGS._sum_stat_bonus({"tailwind": {3: 1, 4: 1}}, "move_speed_percent"), 0.14))
	print("TAILWIND_DODGE_SMOKE_OK")
	quit()

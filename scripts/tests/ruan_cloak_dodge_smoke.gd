extends SceneTree

const STATS := preload("res://scripts/player/player_ruan_stone_stat_flow.gd")

class Owner extends RefCounted:
	var purchased: Array = []
	func get_purchased_ruan_stones() -> Array:
		return purchased

func _init() -> void:
	var owner := Owner.new()
	assert(is_equal_approx(STATS.get_dodge_miss_multiplier(owner), 1.0))
	owner.purchased = ["tattered_cloak"]
	assert(is_equal_approx(STATS.get_dodge_miss_multiplier(owner), 0.9))
	assert(is_equal_approx(STATS.get_speed_bonus(owner), 10.0))
	owner.purchased.append("tattered_cloak")
	assert(is_equal_approx(STATS.get_dodge_miss_multiplier(owner), 0.81))
	assert(is_equal_approx(STATS.get_speed_bonus(owner), 20.0))
	print("RUAN_CLOAK_DODGE_SMOKE_OK")
	quit()

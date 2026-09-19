extends SceneTree

const ARMOR := preload("res://scripts/combat/armor_rules.gd")

func _init() -> void:
	assert(is_equal_approx(ARMOR.get_damage_multiplier(0.0), 1.0))
	assert(is_equal_approx(ARMOR.get_damage_multiplier(100.0), 0.5))
	assert(is_equal_approx(ARMOR.get_damage_multiplier(-100.0), 1.5))
	assert(is_equal_approx(ARMOR.get_damage_multiplier(-200.0), 1.6666666666666667))
	assert(is_equal_approx(ARMOR.apply_damage(100.0, 100.0), 50.0))
	print("ARMOR_RULES_SMOKE_OK")
	quit()

extends SceneTree

const DATABASE := preload("res://scripts/player/roles/role_database.gd")
const RULES := preload("res://scripts/player/roles/role_attribute_rules.gd")

func _init() -> void:
	var expected_armor := {"swordsman": 10.0, "gunner": -15.0, "mage": 0.0, "mechanic": 0.0}
	for role in DATABASE.ROLE_DATA:
		assert(is_zero_approx(float(role["base_damage_reduction_rate"])))
		assert(is_zero_approx(RULES.get_role_base_damage_reduction_rate(str(role["id"]))))
		assert(is_equal_approx(float(role["armor"]), float(expected_armor[role["id"]])))
	print("ROLE_BASE_DEFENSE_SMOKE_OK")
	quit()

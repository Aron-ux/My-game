extends RefCounted


static func get_damage_multiplier(armor: float) -> float:
	if armor >= 0.0:
		return 100.0 / (100.0 + armor)
	return 2.0 - 100.0 / (100.0 - armor)


static func apply_damage(amount: float, armor: float) -> float:
	return amount * get_damage_multiplier(armor)

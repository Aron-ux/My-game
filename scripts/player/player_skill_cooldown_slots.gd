extends RefCounted

static func get_role_color(role_id: String) -> Color:
	match role_id:
		"swordsman":
			return Color(1.0, 0.72, 0.24, 1.0)
		"gunner":
			return Color(0.34, 0.82, 1.0, 1.0)
		"mage":
			return Color(0.78, 0.46, 1.0, 1.0)
		_:
			return Color(1.0, 0.74, 0.34, 1.0)

static func build_slots(role_id: String, attack_remaining: float, attack_interval: float, extra_slots: Array) -> Array:
	var slots: Array = [
		{
			"name": "\u666e\u653b",
			"remaining": attack_remaining,
			"duration": max(attack_interval, 0.01),
			"color": get_role_color(role_id)
		}
	]
	slots.append_array(extra_slots)
	return slots

extends RefCounted

static func build_for_roles(roles: Array, default_value: Variant) -> Dictionary:
	var result: Dictionary = {}
	for role_data in roles:
		if role_data is Dictionary:
			var role_id: String = str(role_data.get("id", ""))
			if role_id != "":
				result[role_id] = default_value
	return result

static func get_mana(values: Dictionary, role_id: String, max_mana: float) -> float:
	return clamp(float(values.get(role_id, 0.0)), 0.0, max_mana)

static func set_mana(values: Dictionary, role_id: String, value: float, max_mana: float) -> float:
	var clamped_value: float = clamp(value, 0.0, max_mana)
	values[role_id] = clamped_value
	return clamped_value

static func add_mana(values: Dictionary, role_id: String, amount: float, max_mana: float) -> float:
	return set_mana(values, role_id, get_mana(values, role_id, max_mana) + amount, max_mana)

static func get_lock_remaining(values: Dictionary, role_id: String) -> float:
	return max(0.0, float(values.get(role_id, 0.0)))

static func set_lock_remaining(values: Dictionary, role_id: String, value: float) -> float:
	var clamped_value: float = max(0.0, value)
	values[role_id] = clamped_value
	return clamped_value

static func tick_locks(values: Dictionary, roles: Array, delta: float) -> void:
	if delta <= 0.0:
		return
	for role_data in roles:
		if not (role_data is Dictionary):
			continue
		var role_id: String = str(role_data.get("id", ""))
		if role_id == "":
			continue
		var remaining: float = get_lock_remaining(values, role_id)
		if remaining > 0.0:
			values[role_id] = max(0.0, remaining - delta)

static func apply_saved_mana(values: Dictionary, saved_values: Dictionary, max_mana: float) -> void:
	for role_id in values.keys():
		values[role_id] = clamp(float(saved_values.get(role_id, values[role_id])), 0.0, max_mana)

static func apply_saved_locks(values: Dictionary, saved_values: Dictionary) -> void:
	for role_id in values.keys():
		values[role_id] = max(0.0, float(saved_values.get(role_id, 0.0)))

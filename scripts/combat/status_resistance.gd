extends RefCounted

static func combine(sources: Array) -> float:
	var multiplier := 1.0
	for source in sources:
		multiplier *= 1.0 - clampf(float(source), 0.0, 1.0)
	return 1.0 - multiplier

static func total(unit, role_id: String = "") -> float:
	if unit == null:
		return 0.0
	var sources: Array = []
	if unit.has_method("_get_active_role"):
		if role_id == "":
			role_id = str(unit._get_active_role().get("id", ""))
		var base: float = 0.1 if role_id == "swordsman" else 0.0
		if unit.get("roles") is Array:
			for role in unit.roles:
				if str(role.get("id", "")) == role_id:
					base = float(role.get("status_resistance", base))
					break
		sources.append(base)
		if unit.get("role_special_states") is Dictionary:
			sources.append_array(unit.role_special_states.get(role_id, {}).get("status_resistance_sources", []))
	else:
		var base: Variant = unit.get("status_resistance")
		sources.append(float(base) if base != null else (0.2 if str(unit.get("enemy_kind")) in ["boss", "small_boss"] else 0.0))
		if unit.get("status_resistance_sources") is Array:
			sources.append_array(unit.status_resistance_sources)
	return combine(sources)

static func duration(unit, original: float) -> float:
	return maxf(0.0, original) * (1.0 - total(unit))

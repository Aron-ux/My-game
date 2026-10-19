extends RefCounted

# One entry per effect: repeated hits refresh; different effects multiply.
const META := &"movement_slow_sources"

static func apply(unit: Object, source_id: String, multiplier: float, duration: float, current_multiplier: float, current_remaining: float) -> Vector2:
	var sources := _sources(unit, current_multiplier, current_remaining)
	sources[source_id if source_id != "" else "default"] = {
		"multiplier": clampf(multiplier, 0.0, 1.0),
		"remaining": maxf(0.0, duration)
	}
	unit.set_meta(META, sources)
	return _combined(sources)

static func tick(unit: Object, delta: float, current_multiplier: float, current_remaining: float) -> Vector2:
	var sources := _sources(unit, current_multiplier, current_remaining)
	for key in sources.keys():
		var effect: Dictionary = sources[key]
		effect["remaining"] = maxf(0.0, float(effect["remaining"]) - maxf(0.0, delta))
		if float(effect["remaining"]) <= 0.0:
			sources.erase(key)
	unit.set_meta(META, sources)
	return _combined(sources)

static func clear(unit: Object) -> void:
	unit.remove_meta(META)

static func save(unit: Object) -> Dictionary:
	return (unit.get_meta(META, {}) as Dictionary).duplicate(true)

static func restore(unit: Object, data: Dictionary) -> void:
	unit.set_meta(META, data.duplicate(true))

static func _sources(unit: Object, multiplier: float, remaining: float) -> Dictionary:
	var sources: Dictionary = unit.get_meta(META, {})
	# Also supports existing saves which contain only the combined state.
	if sources.is_empty() and remaining > 0.0 and multiplier < 1.0:
		sources["default"] = {"multiplier": multiplier, "remaining": remaining}
	return sources

static func _combined(sources: Dictionary) -> Vector2:
	var multiplier := 1.0
	var remaining := 0.0
	for effect: Dictionary in sources.values():
		if float(effect.get("remaining", 0.0)) <= 0.0:
			continue
		multiplier *= clampf(float(effect["multiplier"]), 0.0, 1.0)
		remaining = maxf(remaining, float(effect["remaining"]))
	return Vector2(multiplier, remaining)

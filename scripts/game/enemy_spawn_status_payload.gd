extends RefCounted


static func apply_to_spawned_enemy(enemy: Node, request: Dictionary) -> void:
	if enemy == null or request.is_empty():
		return
	_apply_float_max(enemy, request, "skull_soldier_speed_multiplier", 1.0)
	_apply_float_max(enemy, request, "skull_soldier_speed_timer", 0.0)
	_apply_float_max(enemy, request, "skull_damage_immune_timer", 0.0)


static func _apply_float_max(enemy: Node, request: Dictionary, key: String, fallback: float) -> void:
	if not request.has(key):
		return
	enemy.set(key, max(float(enemy.get(key)), float(request.get(key, fallback))))

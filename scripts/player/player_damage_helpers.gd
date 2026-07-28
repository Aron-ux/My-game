extends RefCounted

static func get_enemy_meta_int(enemy: Node, key: String) -> int:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_meta(key):
		return 0
	return int(enemy.get_meta(key))

static func get_enemy_meta_float(enemy: Node, key: String) -> float:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_meta(key):
		return 0.0
	return float(enemy.get_meta(key))

static func apply_role_damage_lifesteal(_owner, _source_role_id: String, _damage_amount: float) -> void:
	return

static func get_gunner_distance_damage_multiplier(distance: float, trait_bonus: float = 0.0, safe_zone_radius: float = 115.0, inside_damage_bonus: float = 0.0, outside_damage_bonus: float = 0.0) -> float:
	var safe_distance: float = max(0.0, distance)
	var safe_radius: float = max(0.0, safe_zone_radius)
	if safe_distance <= safe_radius:
		return max(0.0, 0.4 + max(0.0, inside_damage_bonus))
	var outside_distance: float = safe_distance - safe_radius
	var multiplier: float = 1.0 + outside_distance / 100.0 * 0.05 + max(0.0, trait_bonus) + max(0.0, outside_damage_bonus)
	return max(0.4, multiplier)

static func get_enemy_hit_radius(enemy: Node) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return 12.0
	var enemy_contact_radius: Variant = enemy.get("contact_radius")
	if enemy_contact_radius == null:
		return 12.0
	return clamp(float(enemy_contact_radius) * 0.42, 10.0, 28.0)

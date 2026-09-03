extends RefCounted

const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_TARGETING := preload("res://scripts/player/player_targeting.gd")


static func resolve_target_position(owner, facing: Vector2, max_range: float) -> Vector2:
	return PLAYER_TARGETING.get_aim_target_position(owner, facing, max_range)


static func apply_impact(owner, center: Vector2, damage: float, radius: float) -> int:
	if owner == null or not is_instance_valid(owner):
		return 0
	return int(owner._damage_enemies_in_radius(center, radius, damage, 0.0, 1.0, 0.0, "swordsman"))


static func release_shockwave(owner, center: Vector2, damage: float, armor_shred: float) -> int:
	if owner == null or not is_instance_valid(owner) or not owner.has_method("_get_live_enemies"):
		return 0
	var hit_count := 0
	for enemy in owner._get_live_enemies():
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if not bool(PLAYER_DAMAGE_RESOLVER._is_live_enemy(enemy)):
			continue
		var hit_killed: bool = owner._deal_damage_to_enemy(enemy, damage, "swordsman", 0.0, 2.0, 1.0, 0.0, center)
		hit_count += 1
		if not hit_killed and float(enemy.get("current_health")) > 0.0:
			_shred_enemy_armor(enemy, armor_shred)
	return hit_count


static func _shred_enemy_armor(enemy, value: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.get("damage_reduction_value") == null:
		return
	enemy.damage_reduction_value = float(enemy.damage_reduction_value) - value

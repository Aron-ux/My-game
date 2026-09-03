extends RefCounted

const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")


static func fire_shot(owner, direction: Vector2, length: float, width: float, damage: float, armor_shred: float) -> int:
	if owner == null or not is_instance_valid(owner):
		return 0
	var center: Vector2 = owner.global_position + direction * (length * 0.5)
	var query_size: float = max(length, width) * 2.0
	var candidates: Array = PLAYER_DAMAGE_RESOLVER._get_candidate_enemies_for_bounds(
		owner,
		Rect2(center - Vector2.ONE * query_size * 0.5, Vector2.ONE * query_size)
	)
	var hit_count := 0
	for enemy in candidates:
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if not bool(PLAYER_DAMAGE_RESOLVER._is_live_enemy(enemy)):
			continue
		if not is_inside_beam((enemy as Node2D).global_position, center, direction, length, width):
			continue
		hit_count += 1
		var killed: bool = owner._deal_damage_to_enemy(enemy, damage, "gunner", 0.0, 2.0, 1.0, 0.0, owner.global_position)
		if not killed and float(enemy.get("current_health")) > 0.0:
			_shred_enemy_armor(enemy, armor_shred)
	return hit_count


static func is_inside_beam(enemy_position: Vector2, center: Vector2, direction: Vector2, length: float, width: float) -> bool:
	var offset: Vector2 = enemy_position - center
	var axis: float = offset.dot(direction)
	if absf(axis) > length * 0.5:
		return false
	var perpendicular: float = (offset - direction * axis).length()
	return perpendicular <= width * 0.5


static func _shred_enemy_armor(enemy, value: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.get("damage_reduction_value") == null:
		return
	enemy.damage_reduction_value = float(enemy.damage_reduction_value) - value

extends RefCounted

const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")

## 法师主动技能「黑暗契约」的来源识别工具。

const SOURCE_PREFIX := "mage_dark_contract:"
const ATTRACT_RADIUS := 100.0
const ATTRACT_SPEED := 200.0
const ATTRACT_TICK_INTERVAL := 1.0 / 3.0
const ATTRACT_TICK_DAMAGE_RATIO := 0.30
const COLLIDE_RADIUS := 40.0
const COLLIDE_DAMAGE_RATIO := 3.00
const BLAST_RADIUS := 75.0
const BLAST_DAMAGE_RATIO := 3.00


static func make_damage_source_id() -> String:
	return SOURCE_PREFIX + "1"


static func is_dark_contract_source(source_role_id: String) -> bool:
	return source_role_id.begins_with(SOURCE_PREFIX)


static func apply_sphere_tick(owner, data: Dictionary, position: Vector2, delta: float) -> Dictionary:
	if owner == null or not is_instance_valid(owner):
		return data
	var candidates: Array = PLAYER_DAMAGE_RESOLVER._get_candidate_enemies_for_bounds(
		owner,
		Rect2(position - Vector2.ONE * (ATTRACT_RADIUS + 24.0), Vector2.ONE * (ATTRACT_RADIUS + 24.0) * 2.0)
	)
	var collided_ids: Dictionary = data.get("collided_ids", {})
	var collide_distance_squared: float = COLLIDE_RADIUS * COLLIDE_RADIUS
	var attract_distance_squared: float = ATTRACT_RADIUS * ATTRACT_RADIUS
	var pull_step: float = ATTRACT_SPEED * delta
	for enemy in candidates:
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if not bool(PLAYER_DAMAGE_RESOLVER._is_live_enemy(enemy)) or str(enemy.get("enemy_kind")) == "boss":
			continue
		var enemy_node := enemy as Node2D
		var offset: Vector2 = position - enemy_node.global_position
		var distance_squared: float = offset.length_squared()
		if distance_squared <= collide_distance_squared:
			var enemy_id: int = enemy_node.get_instance_id()
			if not collided_ids.has(enemy_id):
				collided_ids[enemy_id] = true
				var damage: float = float(owner._get_role_damage("mage")) * COLLIDE_DAMAGE_RATIO
				owner._deal_damage_to_enemy(enemy_node, damage, make_damage_source_id(), 0.0, 2.0, 1.0, 0.0, position)
		if distance_squared <= attract_distance_squared and distance_squared > 0.001:
			var distance: float = sqrt(distance_squared)
			enemy_node.global_position += offset / distance * min(pull_step, distance)
	data["collided_ids"] = collided_ids
	var tick_elapsed: float = float(data.get("attract_tick_elapsed", 0.0)) + delta
	while tick_elapsed >= ATTRACT_TICK_INTERVAL:
		tick_elapsed -= ATTRACT_TICK_INTERVAL
		var tick_damage: float = float(owner._get_role_damage("mage")) * ATTRACT_TICK_DAMAGE_RATIO
		owner._damage_enemies_in_radius(position, ATTRACT_RADIUS, tick_damage, 0.0, 1.0, 0.0, make_damage_source_id())
	data["attract_tick_elapsed"] = tick_elapsed
	return data


static func apply_explosion(owner, position: Vector2) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var damage: float = float(owner._get_role_damage("mage")) * BLAST_DAMAGE_RATIO
	owner._damage_enemies_in_radius(position, BLAST_RADIUS, damage, 0.0, 1.0, 0.0, make_damage_source_id())

extends RefCounted

const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")
const PLAYER_SKILL_LEVEL_EFFECT_FLOW := preload("res://scripts/player/player_skill_level_effect_flow.gd")

## 法师主动技能「黑暗契约」的来源识别工具。

const SOURCE_PREFIX := "mage_dark_contract:"
const BASE_ATTRACT_RADIUS := 100.0
const TALENT_1_ATTRACT_RADIUS := 150.0
const BASE_ATTRACT_SPEED := 200.0
const TALENT_1_ATTRACT_SPEED := 250.0
const ATTRACT_TICK_INTERVAL := 1.0 / 3.0
const ATTRACT_TICK_DAMAGE_RATIO := 0.30
const COLLIDE_RADIUS := 40.0
const COLLIDE_DAMAGE_RATIO := 3.00
const BLAST_RADIUS := 75.0
const BLAST_DAMAGE_RATIO := 3.00
const LINGER_DURATION := 3.0
const LINGER_DAMAGE_PER_SECOND_RATIO := 1.50
const LINGER_ATTRACT_RADIUS := 150.0


static func make_damage_source_id() -> String:
	return SOURCE_PREFIX + "1"


static func is_dark_contract_source(source_role_id: String) -> bool:
	return source_role_id.begins_with(SOURCE_PREFIX)


static func has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)


static func get_attract_radius(owner) -> float:
	var radius: float = TALENT_1_ATTRACT_RADIUS if has_level_talent(owner, "mage_level_talent_dark_contract_1") else BASE_ATTRACT_RADIUS
	return radius + PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_dark_contract_attract_radius_bonus(owner)


static func get_attract_speed(owner) -> float:
	if has_level_talent(owner, "mage_level_talent_dark_contract_1"):
		return TALENT_1_ATTRACT_SPEED
	return BASE_ATTRACT_SPEED


static func get_collide_damage_ratio(owner) -> float:
	return COLLIDE_DAMAGE_RATIO + PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_dark_contract_damage_ratio_bonus(owner)


static func get_blast_damage_ratio(owner) -> float:
	return BLAST_DAMAGE_RATIO + PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_dark_contract_damage_ratio_bonus(owner)


static func apply_sphere_tick(owner, data: Dictionary, position: Vector2, delta: float) -> Dictionary:
	if owner == null or not is_instance_valid(owner):
		return data
	var attract_radius: float = get_attract_radius(owner)
	var attract_speed: float = get_attract_speed(owner)
	var candidates: Array = PLAYER_DAMAGE_RESOLVER._get_candidate_enemies_for_bounds(
		owner,
		Rect2(position - Vector2.ONE * (attract_radius + 24.0), Vector2.ONE * (attract_radius + 24.0) * 2.0)
	)
	var collided_ids: Dictionary = data.get("collided_ids", {})
	var collide_distance_squared: float = COLLIDE_RADIUS * COLLIDE_RADIUS
	var attract_distance_squared: float = attract_radius * attract_radius
	var pull_step: float = attract_speed * delta
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
				var damage: float = float(owner._get_role_damage("mage")) * get_collide_damage_ratio(owner)
				owner._deal_damage_to_enemy(enemy_node, damage, make_damage_source_id(), 0.0, 2.0, 1.0, 0.0, position)
		if distance_squared <= attract_distance_squared and distance_squared > 0.001:
			var distance: float = sqrt(distance_squared)
			enemy_node.global_position += offset / distance * min(pull_step, distance)
	data["collided_ids"] = collided_ids
	var tick_elapsed: float = float(data.get("attract_tick_elapsed", 0.0)) + delta
	while tick_elapsed >= ATTRACT_TICK_INTERVAL:
		tick_elapsed -= ATTRACT_TICK_INTERVAL
		var tick_damage: float = float(owner._get_role_damage("mage")) * ATTRACT_TICK_DAMAGE_RATIO
		owner._damage_enemies_in_radius(position, attract_radius, tick_damage, 0.0, 1.0, 0.0, make_damage_source_id())
	data["attract_tick_elapsed"] = tick_elapsed
	return data


static func apply_linger_tick(owner, data: Dictionary, position: Vector2, delta: float) -> Dictionary:
	## 黑暗契约II：球体暂留阶段，吸引150半径内敌人并造成每秒150%伤害
	if owner == null or not is_instance_valid(owner):
		return data
	var candidates: Array = PLAYER_DAMAGE_RESOLVER._get_candidate_enemies_for_bounds(
		owner,
		Rect2(position - Vector2.ONE * (LINGER_ATTRACT_RADIUS + 24.0), Vector2.ONE * (LINGER_ATTRACT_RADIUS + 24.0) * 2.0)
	)
	var attract_distance_squared: float = LINGER_ATTRACT_RADIUS * LINGER_ATTRACT_RADIUS
	var pull_step: float = get_attract_speed(owner) * delta
	for enemy in candidates:
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if not bool(PLAYER_DAMAGE_RESOLVER._is_live_enemy(enemy)) or str(enemy.get("enemy_kind")) == "boss":
			continue
		var enemy_node := enemy as Node2D
		var offset: Vector2 = position - enemy_node.global_position
		var distance_squared: float = offset.length_squared()
		if distance_squared <= attract_distance_squared and distance_squared > 0.001:
			var distance: float = sqrt(distance_squared)
			enemy_node.global_position += offset / distance * min(pull_step, distance)
	var linger_elapsed: float = float(data.get("linger_elapsed", 0.0)) + delta
	data["linger_elapsed"] = linger_elapsed
	# 每秒造成150%伤害
	var linger_damage_accum: float = float(data.get("linger_damage_accum", 0.0)) + delta
	while linger_damage_accum >= 1.0:
		linger_damage_accum -= 1.0
		var damage: float = float(owner._get_role_damage("mage")) * LINGER_DAMAGE_PER_SECOND_RATIO
		owner._damage_enemies_in_radius(position, LINGER_ATTRACT_RADIUS, damage, 0.0, 1.0, 0.0, make_damage_source_id())
	data["linger_damage_accum"] = linger_damage_accum
	return data


static func apply_explosion(owner, position: Vector2) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var damage: float = float(owner._get_role_damage("mage")) * get_blast_damage_ratio(owner)
	owner._damage_enemies_in_radius(position, BLAST_RADIUS, damage, 0.0, 1.0, 0.0, make_damage_source_id())

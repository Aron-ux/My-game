extends RefCounted

const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_TARGETING := preload("res://scripts/player/player_targeting.gd")

## 枪手主动技能「魔法榴弹」的来源识别与专属暴击加成。

const SOURCE_PREFIX := "gunner_magic_grenade:"
const CRIT_CHANCE_BONUS := 0.20
const GRENADE_COUNT := 3
const DAMAGE_RATIO := 3.00
const BLAST_RADIUS := 75.0
const SEARCH_RADIUS := 540.0
const SEARCH_MIN_DISTANCE := 60.0


static func make_damage_source_id() -> String:
	return SOURCE_PREFIX + "1"


static func is_magic_grenade_source(source_role_id: String) -> bool:
	return source_role_id.begins_with(SOURCE_PREFIX)


static func get_critical_chance_bonus(source_role_id: String) -> float:
	if source_role_id == "" or not is_magic_grenade_source(source_role_id):
		return 0.0
	return CRIT_CHANCE_BONUS


static func collect_targets(owner, origin: Vector2, facing: Vector2) -> Array:
	var fallback_targets := _build_fallback_targets(origin, facing)
	var bounds := Rect2(origin - Vector2.ONE * SEARCH_RADIUS, Vector2.ONE * SEARCH_RADIUS * 2.0)
	var candidates: Array = PLAYER_DAMAGE_RESOLVER._get_candidate_enemies_for_bounds(owner, bounds)
	if candidates.is_empty():
		return fallback_targets
	var front_enemies: Array = []
	var search_radius_squared: float = SEARCH_RADIUS * SEARCH_RADIUS
	var min_distance_squared: float = SEARCH_MIN_DISTANCE * SEARCH_MIN_DISTANCE
	for enemy in candidates:
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var offset: Vector2 = enemy.global_position - origin
		var distance_squared: float = offset.length_squared()
		if distance_squared < min_distance_squared or distance_squared > search_radius_squared:
			continue
		if facing.dot(offset.normalized()) < 0.12:
			continue
		front_enemies.append(enemy)
	if front_enemies.is_empty():
		return fallback_targets
	var centers: Array = PLAYER_TARGETING.get_random_enemy_cluster_centers(front_enemies, origin, GRENADE_COUNT)
	var targets: Array = []
	for center in centers:
		if origin.distance_to(center) < SEARCH_MIN_DISTANCE:
			continue
		targets.append(center)
		if targets.size() >= GRENADE_COUNT:
			break
	while targets.size() < GRENADE_COUNT:
		targets.append(fallback_targets[targets.size()])
	return targets


static func apply_explosion(owner, center: Vector2) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var damage: float = float(owner._get_role_damage("gunner")) * DAMAGE_RATIO
	owner._damage_enemies_in_radius(center, BLAST_RADIUS, damage, 0.0, 1.0, 0.0, make_damage_source_id())


static func _build_fallback_targets(origin: Vector2, facing: Vector2) -> Array:
	var targets: Array = []
	var base_distance := 300.0
	for index in range(GRENADE_COUNT):
		var lateral: float = (float(index) - float(GRENADE_COUNT - 1) * 0.5) * 90.0
		var offset: Vector2 = facing * (base_distance + float(index) * 60.0) + Vector2.UP.rotated(facing.angle()) * lateral
		targets.append(origin + offset)
	return targets

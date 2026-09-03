extends RefCounted

const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")

const IMPACT_DAMAGE_RATIO := 2.80
const BLAST_DAMAGE_RATIO := 1.60
const BLAST_CONE_RADIUS := 375.0
const BLAST_CONE_ANGLE := deg_to_rad(60.0)
const SOURCE_ROLE_ID := "gunner"


static func find_enemy_between(owner, start: Vector2, end: Vector2):
	if owner == null or not is_instance_valid(owner) or not owner.has_method("_get_live_enemies"):
		return null
	var axis := end - start
	var length: float = axis.length()
	if length <= 0.001:
		return null
	var direction: Vector2 = axis / length
	var closest: Node2D = null
	var closest_distance: float = INF
	for enemy in owner._get_live_enemies():
		if not bool(PLAYER_DAMAGE_RESOLVER._is_live_enemy(enemy)) or not (enemy is Node2D):
			continue
		var relative: Vector2 = enemy.global_position - start
		var along: float = clampf(relative.dot(direction), 0.0, length)
		var distance: float = enemy.global_position.distance_to(start + direction * along)
		var contact_radius: float = float(enemy.get("contact_radius")) if enemy.get("contact_radius") != null else 0.0
		if distance <= 28.0 + contact_radius and along < closest_distance:
			closest = enemy
			closest_distance = along
	return closest


static func apply_explosion(owner, center: Vector2, direction: Vector2, hit_enemy: Node2D) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var damage: float = float(owner._get_role_damage(SOURCE_ROLE_ID))
	if hit_enemy != null and is_instance_valid(hit_enemy) and owner.has_method("_deal_damage_to_enemy"):
		owner._deal_damage_to_enemy(hit_enemy, damage * IMPACT_DAMAGE_RATIO, SOURCE_ROLE_ID, 0.0, 2.0, 1.0, 0.0, center)
	owner._damage_enemies_in_cone(center, direction, BLAST_CONE_RADIUS, BLAST_CONE_ANGLE, damage * BLAST_DAMAGE_RATIO, 0.0, 1.0, 0.0, SOURCE_ROLE_ID)

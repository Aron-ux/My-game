extends RefCounted

const PLAYER_RESOURCE_FLOW := preload("res://scripts/player/player_resource_flow.gd")

const DAMAGE_RATIO := 1.60
const SELF_MAX_HEALTH_RATIO := 0.80
const HIT_TEMPORARY_HEALTH := 5.0
const TEMPORARY_HEALTH_DURATION := 5.0
const THRUST_LENGTH := 250.0
const THRUST_WIDTH := 58.0
const KNOCKBACK_DISTANCE := 100.0
const SOURCE_ROLE_ID := "swordsman"


static func apply(owner, direction: Vector2) -> int:
	if owner == null or not is_instance_valid(owner):
		return 0
	var axis := direction.normalized()
	if axis.length_squared() <= 0.001:
		axis = Vector2.RIGHT
	var center: Vector2 = owner.global_position + axis * (THRUST_LENGTH * 0.5)
	var damage: float = float(owner._get_role_damage(SOURCE_ROLE_ID)) * DAMAGE_RATIO
	var hits: int = owner._damage_enemies_in_oriented_rect(
		center,
		axis,
		THRUST_LENGTH,
		THRUST_WIDTH,
		damage,
		0.0,
		1.0,
		0.0,
		SOURCE_ROLE_ID,
		KNOCKBACK_DISTANCE
	)
	if hits > 0:
		PLAYER_RESOURCE_FLOW.add_temporary_health(
			owner,
			float(owner._get_role_max_health(SOURCE_ROLE_ID)) * SELF_MAX_HEALTH_RATIO,
			SOURCE_ROLE_ID,
			TEMPORARY_HEALTH_DURATION
		)
		PLAYER_RESOURCE_FLOW.add_temporary_health(
			owner,
			float(hits) * HIT_TEMPORARY_HEALTH,
			SOURCE_ROLE_ID,
			TEMPORARY_HEALTH_DURATION
		)
	return hits

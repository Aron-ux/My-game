extends RefCounted

const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

const TALENT_META_FIELD_1 := "mage_level_talent_meta_field_1"
const TALENT_META_FIELD_2 := "mage_level_talent_meta_field_2"

const AREA_MULTIPLIER := 1.25
const RADIUS_MULTIPLIER := sqrt(AREA_MULTIPLIER)
const ENEMY_PROJECTILE_SLOW_EFFECT := 0.30
const BACKGROUND_EFFECT_RATIO := 0.40
const PROJECTILE_AURA_SCAN_INTERVAL := 0.10
const PROJECTILE_BASE_SPEED_META := "mage_meta_field_base_speed"
const PROJECTILE_MULTIPLIER_META := "mage_meta_field_speed_multiplier"


static func has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)


static func get_radius_multiplier(owner) -> float:
	if has_level_talent(owner, TALENT_META_FIELD_1) or has_level_talent(owner, TALENT_META_FIELD_2):
		return RADIUS_MULTIPLIER
	return 1.0


static func should_persist_in_background(owner) -> bool:
	return has_level_talent(owner, TALENT_META_FIELD_2)


static func get_level_talent_effect_ratio(owner, active_role_id: String, transferred_role_id: String) -> float:
	if should_persist_in_background(owner) and active_role_id != "mage" and transferred_role_id == "":
		return BACKGROUND_EFFECT_RATIO
	return 1.0


static func get_scaled_slow_multiplier(base_multiplier: float, effect_ratio: float) -> float:
	var slow_effect: float = clamp(1.0 - base_multiplier, 0.0, 0.95)
	return 1.0 - slow_effect * clamp(effect_ratio, 0.0, 1.0)


static func get_enemy_projectile_speed_multiplier(owner, effect_ratio: float) -> float:
	if not has_level_talent(owner, TALENT_META_FIELD_1):
		return 1.0
	var slow_effect: float = ENEMY_PROJECTILE_SLOW_EFFECT * clamp(effect_ratio, 0.0, 1.0)
	return 1.0 - clamp(slow_effect, 0.0, 0.95)


static func apply_enemy_projectile_speed_aura(owner, center: Vector2, radius: float, speed_multiplier: float, tracked_projectiles: Dictionary) -> Dictionary:
	var result: Dictionary = _cleanup_tracked_projectiles(tracked_projectiles)
	if owner == null or not is_instance_valid(owner):
		_restore_all_projectiles(result)
		return {}
	if speed_multiplier >= 0.999:
		_restore_all_projectiles(result)
		return {}
	var tree: SceneTree = owner.get_tree() if owner.has_method("get_tree") else null
	if tree == null:
		_restore_all_projectiles(result)
		return {}
	var radius_squared: float = max(0.0, radius) * max(0.0, radius)
	var seen: Dictionary = {}
	for projectile in tree.get_nodes_in_group("enemy_projectiles"):
		if projectile == null or not is_instance_valid(projectile) or projectile is not Node2D:
			continue
		var projectile_node := projectile as Node2D
		if projectile_node.global_position.distance_squared_to(center) > radius_squared:
			continue
		seen[projectile_node.get_instance_id()] = true
		_apply_projectile_speed_multiplier(projectile_node, speed_multiplier)
		result[projectile_node.get_instance_id()] = weakref(projectile_node)
	for projectile_id in result.keys():
		if not seen.has(projectile_id):
			var projectile_ref: WeakRef = result.get(projectile_id)
			var projectile_node: Node = projectile_ref.get_ref() if projectile_ref != null else null
			_restore_projectile_speed(projectile_node)
			result.erase(projectile_id)
	return result


static func restore_projectile_speed_aura(tracked_projectiles: Dictionary) -> void:
	_restore_all_projectiles(tracked_projectiles)


static func _cleanup_tracked_projectiles(tracked_projectiles: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for projectile_id in tracked_projectiles.keys():
		var projectile_ref: WeakRef = tracked_projectiles.get(projectile_id)
		var projectile_node: Node = projectile_ref.get_ref() if projectile_ref != null else null
		if projectile_node != null and is_instance_valid(projectile_node) and not projectile_node.is_queued_for_deletion():
			result[projectile_id] = projectile_ref
	return result


static func _apply_projectile_speed_multiplier(projectile: Node, speed_multiplier: float) -> void:
	if projectile == null or not is_instance_valid(projectile) or projectile.get("speed") == null:
		return
	var base_speed: float = float(projectile.get_meta(PROJECTILE_BASE_SPEED_META, projectile.get("speed")))
	projectile.set_meta(PROJECTILE_BASE_SPEED_META, base_speed)
	projectile.set_meta(PROJECTILE_MULTIPLIER_META, speed_multiplier)
	projectile.set("speed", base_speed * speed_multiplier)


static func _restore_projectile_speed(projectile: Node) -> void:
	if projectile == null or not is_instance_valid(projectile) or projectile.get("speed") == null:
		return
	if not projectile.has_meta(PROJECTILE_BASE_SPEED_META):
		return
	projectile.set("speed", float(projectile.get_meta(PROJECTILE_BASE_SPEED_META)))
	projectile.remove_meta(PROJECTILE_BASE_SPEED_META)
	if projectile.has_meta(PROJECTILE_MULTIPLIER_META):
		projectile.remove_meta(PROJECTILE_MULTIPLIER_META)


static func _restore_all_projectiles(tracked_projectiles: Dictionary) -> void:
	for projectile_id in tracked_projectiles.keys():
		var projectile_ref: WeakRef = tracked_projectiles.get(projectile_id)
		var projectile_node: Node = projectile_ref.get_ref() if projectile_ref != null else null
		_restore_projectile_speed(projectile_node)
	tracked_projectiles.clear()

extends RefCounted

const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

const TALENT_FLAME_PATH_1 := "mage_level_talent_flame_path_1"
const FLAME_PATH_SOURCE := "mage_flame_path"
const SHRED_VALUE := 20.0


static func is_active(owner) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	var ability: Variant = owner.get("mage_flame_path_ability")
	return ability != null and ability.has_method("is_active") and bool(ability.is_active())


static func apply_damage_tick(owner, points: Array[Vector2], path_width: float, damage_per_second: float, interval: float) -> void:
	if owner == null or not is_instance_valid(owner) or points.size() < 2:
		return
	var hit_registry: Dictionary = {}
	var segment_step: int = maxi(1, ceili(float(points.size() - 1) / 48.0))
	var shapes: Array[Dictionary] = []
	for index in range(0, points.size() - 1, segment_step):
		var end_index: int = mini(points.size() - 1, index + segment_step)
		var start: Vector2 = points[index]
		var end: Vector2 = points[end_index]
		var axis: Vector2 = end - start
		var length: float = axis.length()
		if length <= 0.001:
			continue
		shapes.append({
			"type": "oriented_rect",
			"center": (start + end) * 0.5,
			"axis": axis / length,
			"length": length + path_width,
			"width": path_width,
			"damage_amount": damage_per_second * interval,
			"vulnerability_bonus": 0.0,
			"slow_multiplier": 1.0,
			"slow_duration": 0.0,
			"source_role_id": FLAME_PATH_SOURCE,
			"hit_registry": hit_registry
		})
	if owner.has_method("_damage_enemies_in_shapes_batched"):
		owner._damage_enemies_in_shapes_batched(shapes)
	elif owner.has_method("_damage_enemies_in_oriented_rect_unique"):
		for shape in shapes:
			owner._damage_enemies_in_oriented_rect_unique(
				shape["center"],
				shape["axis"],
				shape["length"],
				shape["width"],
				shape["damage_amount"],
				shape["vulnerability_bonus"],
				shape["slow_multiplier"],
				shape["slow_duration"],
				hit_registry,
				FLAME_PATH_SOURCE
			)
	# 火焰之径I：被灼烧的敌人减20减伤值
	if has_level_talent(owner, TALENT_FLAME_PATH_1):
		_apply_defense_shred(owner, hit_registry)


static func _apply_defense_shred(owner, hit_registry: Dictionary) -> void:
	for enemy_id in hit_registry.keys():
		var enemy = instance_from_id(enemy_id)
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.get("damage_reduction_value") == null:
			continue
		enemy.damage_reduction_value = float(enemy.damage_reduction_value) - SHRED_VALUE


static func has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)


static func is_flame_path_source(source_role_id: String) -> bool:
	return source_role_id == FLAME_PATH_SOURCE

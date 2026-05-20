extends RefCounted

const ENEMY_DEATH_EFFECTS := preload("res://scripts/enemies/enemy_death_effects.gd")
const ENEMY_SPATIAL_GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")

const ABSORB_INTERVAL := 0.18
const GEM_GRID_CELL_SIZE := 128.0
const AURA_EXECUTE_HITS := 6
const AURA_QUERY_PADDING := 96.0
const SHADOW_AURA_RADIUS_RATIO := 1.1

static var cached_exp_gem_grid_frame: int = -1
static var cached_exp_gem_grid: Dictionary = {}


static func update(enemy, delta: float) -> void:
	if enemy.glutton_absorb_radius <= 0.0:
		return
	enemy.glutton_absorb_elapsed += delta
	if enemy.glutton_absorb_elapsed < ABSORB_INTERVAL:
		return
	enemy.glutton_absorb_elapsed = 0.0
	absorb_nearby_pickups(enemy)
	damage_nearby_enemies(enemy)


static func absorb_nearby_pickups(enemy) -> void:
	var radius: float = enemy.glutton_absorb_radius
	var radius_squared: float = radius * radius
	for gem in _get_exp_gem_candidates(enemy, enemy.global_position, radius):
		if not is_instance_valid(gem) or gem is not Node2D:
			continue
		if enemy.global_position.distance_squared_to((gem as Node2D).global_position) > radius_squared:
			continue
		absorb_exp_gem(enemy, gem)
	for heart in _get_runtime_pickups(enemy, enemy.get_tree(), "heart_pickups"):
		if not is_instance_valid(heart) or heart is not Node2D:
			continue
		if enemy.global_position.distance_squared_to((heart as Node2D).global_position) > radius_squared:
			continue
		absorb_heart(enemy, heart)


static func damage_nearby_enemies(enemy) -> void:
	var damage: float = enemy.glutton_aura_damage
	if damage <= 0.0:
		return
	var radius: float = _get_aura_radius(enemy)
	for other in ENEMY_SPATIAL_GRID.get_neighbors(enemy, radius + AURA_QUERY_PADDING):
		if not _can_damage_enemy(enemy, other):
			continue
		if not _is_inside_aura(enemy, other, radius):
			continue
		var aura_hits: int = _register_aura_hit(enemy, other)
		var hit_damage: float = _get_aura_hit_damage(other, damage, aura_hits)
		if _will_kill_enemy(other, hit_damage):
			ENEMY_DEATH_EFFECTS.spawn_glutton_squash(other)
		other.set("drop_absorber", enemy)
		other.take_damage(hit_damage)
		if is_instance_valid(other):
			other.set("drop_absorber", null)


static func absorb_exp_gem(enemy, gem) -> int:
	if gem == null or not is_instance_valid(gem) or not gem.has_method("collect"):
		return 0
	var value: int = int(gem.collect())
	_apply_glutton_growth(enemy, 1)
	return value


static func absorb_heart(enemy, heart) -> float:
	if heart == null or not is_instance_valid(heart) or not heart.has_method("collect"):
		return 0.0
	var heal_amount: float = float(heart.collect())
	var heal_scale: float = max(0.0, enemy.glutton_heart_heal_scale)
	if heal_amount > 0.0 and heal_scale > 0.0:
		enemy.current_health = min(enemy.max_health, enemy.current_health + heal_amount * heal_scale)
		enemy._spawn_status_burst(Color(1.0, 0.36, 0.48, 0.16), 24.0 + enemy.scale.x * 5.0)
	return heal_amount


static func _apply_glutton_growth(enemy, absorbed_count: int) -> void:
	if absorbed_count <= 0:
		return
	for _index in range(absorbed_count):
		enemy.glutton_bonus_speed = min(enemy.glutton_max_bonus_speed, enemy.glutton_bonus_speed + enemy.glutton_speed_gain_per_gem)
		enemy.scale += Vector2.ONE * enemy.glutton_scale_gain_per_gem
	enemy._spawn_status_burst(Color(0.42, 0.88, 1.0, 0.18), 26.0 + enemy.scale.x * 6.0)


static func _can_damage_enemy(source, target) -> bool:
	if target == null or target == source or not is_instance_valid(target) or target is not Node2D:
		return false
	if target is Node and (target as Node).is_queued_for_deletion():
		return false
	if not _is_damageable_enemy_kind(target):
		return false
	if not target.has_method("take_damage"):
		return false
	return str(target.get("enemy_kind")) != "boss" and str(target.get("enemy_kind")) != "small_boss"


static func _is_damageable_enemy_kind(target) -> bool:
	var kind_value: Variant = target.get("enemy_kind")
	if kind_value == null:
		return false
	var kind: String = str(kind_value)
	return kind == "normal" or kind == "elite"


static func _is_inside_aura(source, target, aura_radius: float) -> bool:
	var target_radius: float = _get_target_contact_radius(target)
	var total_radius: float = aura_radius + target_radius
	return source.global_position.distance_squared_to((target as Node2D).global_position) <= total_radius * total_radius


static func _get_aura_radius(enemy) -> float:
	var shadow_radius := _get_shadow_world_radius(enemy)
	if shadow_radius > 0.0:
		return shadow_radius * SHADOW_AURA_RADIUS_RATIO
	if enemy.glutton_aura_radius > 0.0:
		return enemy.glutton_aura_radius
	return enemy.glutton_absorb_radius


static func _get_shadow_world_radius(enemy) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return 0.0
	var visual: Node = enemy.get_node_or_null("ProfileVisual")
	if visual != null and visual.has_method("get_shadow_world_radius"):
		return max(0.0, float(visual.call("get_shadow_world_radius")))
	return 0.0


static func _get_target_contact_radius(target) -> float:
	var radius_value: Variant = target.get("contact_radius")
	if radius_value != null:
		return max(0.0, float(radius_value))
	return 0.0


static func _register_aura_hit(source, target) -> int:
	var target_id: int = target.get_instance_id()
	var hits: int = int(source.glutton_aura_hits_by_enemy_id.get(target_id, 0)) + 1
	source.glutton_aura_hits_by_enemy_id[target_id] = hits
	return hits


static func _get_aura_hit_damage(target, base_damage: float, aura_hits: int) -> float:
	if aura_hits < AURA_EXECUTE_HITS:
		return base_damage
	var current_health: float = max(0.0, float(target.get("current_health")))
	var vulnerability_bonus: float = max(0.0, float(target.get("vulnerability_bonus")))
	return max(base_damage, (current_health + 1.0) / max(0.01, 1.0 + vulnerability_bonus))


static func _will_kill_enemy(target, raw_damage: float) -> bool:
	var current_health: float = float(target.get("current_health"))
	var vulnerability_bonus: float = float(target.get("vulnerability_bonus"))
	return current_health <= raw_damage * (1.0 + vulnerability_bonus)


static func _get_exp_gem_candidates(enemy, center: Vector2, radius: float) -> Array:
	var grid := _get_exp_gem_grid(enemy)
	if grid.is_empty():
		return []
	var min_cell: Vector2i = _exp_gem_grid_cell(center - Vector2.ONE * radius)
	var max_cell: Vector2i = _exp_gem_grid_cell(center + Vector2.ONE * radius)
	var candidates: Array = []
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(x, y)
			if not grid.has(cell):
				continue
			for gem in grid[cell] as Array:
				if is_instance_valid(gem):
					candidates.append(gem)
	return candidates


static func _get_exp_gem_grid(enemy) -> Dictionary:
	if enemy == null or not is_instance_valid(enemy):
		return {}
	if enemy is Node and not (enemy as Node).is_inside_tree():
		return {}
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		return {}
	var current_frame := Engine.get_physics_frames()
	if cached_exp_gem_grid_frame == current_frame:
		return cached_exp_gem_grid
	cached_exp_gem_grid = {}
	for gem in _get_runtime_pickups(enemy, tree, "exp_gems"):
		if not is_instance_valid(gem) or gem is not Node2D:
			continue
		var cell: Vector2i = _exp_gem_grid_cell((gem as Node2D).global_position)
		if not cached_exp_gem_grid.has(cell):
			cached_exp_gem_grid[cell] = []
		(cached_exp_gem_grid[cell] as Array).append(gem)
	cached_exp_gem_grid_frame = current_frame
	return cached_exp_gem_grid


static func _get_runtime_pickups(enemy, tree: SceneTree, group_name: String) -> Array:
	if tree == null:
		return []
	var scene: Node = tree.current_scene
	if scene != null and scene.has_method("get_runtime_pickups"):
		return scene.get_runtime_pickups(group_name)
	if enemy != null and enemy.has_method("get_tree"):
		if enemy is Node and not (enemy as Node).is_inside_tree():
			return []
		var enemy_tree: SceneTree = enemy.get_tree()
		if enemy_tree != null:
			return enemy_tree.get_nodes_in_group(group_name)
	return tree.get_nodes_in_group(group_name)


static func _exp_gem_grid_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / GEM_GRID_CELL_SIZE), floori(position.y / GEM_GRID_CELL_SIZE))

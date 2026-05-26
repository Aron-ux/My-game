extends RefCounted

const ENEMY_DEATH_EFFECTS := preload("res://scripts/enemies/enemy_death_effects.gd")
const ENEMY_DROPS := preload("res://scripts/enemies/enemy_drops.gd")
const ENEMY_SPATIAL_GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")
const ENEMY_GLUTTON_SKILL_BEHAVIOR := preload("res://scripts/enemies/enemy_glutton_skill_behavior.gd")

const ABSORB_INTERVAL := 0.18
const GEM_GRID_CELL_SIZE := 128.0
const AURA_EXECUTE_HITS := 6
const AURA_QUERY_PADDING := 96.0
const SHADOW_AURA_RADIUS_RATIO := 1.2
const PLAYER_TOUCH_SHADOW_RADIUS_RATIO := 0.8
const KILL_HEAL_MAX_HEALTH_RATIO := 0.01

static var cached_exp_gem_grid_frame: int = -1
static var cached_exp_gem_grid: Dictionary = {}


static func update(enemy, delta: float) -> void:
	ENEMY_GLUTTON_SKILL_BEHAVIOR.update(enemy, delta)
	if enemy.glutton_absorb_radius <= 0.0:
		return
	enemy.glutton_absorb_elapsed += delta
	if enemy.glutton_absorb_elapsed < ABSORB_INTERVAL:
		return
	enemy.glutton_absorb_elapsed = 0.0
	absorb_nearby_pickups(enemy)


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
	var aura_shape: Dictionary = _get_aura_shape(enemy)
	var query_radius: float = max(float(aura_shape.get("horizontal_radius", 0.0)), float(aura_shape.get("vertical_radius", 0.0)))
	if query_radius <= 0.0:
		return
	for other in ENEMY_SPATIAL_GRID.get_neighbors(enemy, query_radius + AURA_QUERY_PADDING):
		if not _can_damage_enemy(enemy, other):
			continue
		if not _is_inside_aura(other, aura_shape):
			continue
		var aura_hits: int = _register_aura_hit(enemy, other)
		var hit_damage: float = _get_aura_hit_damage(other, damage, aura_hits)
		var will_kill_enemy: bool = _will_kill_enemy(other, hit_damage)
		if will_kill_enemy:
			ENEMY_DEATH_EFFECTS.spawn_glutton_squash(other)
		other.set("drop_absorber", enemy)
		other.take_damage(hit_damage)
		if is_instance_valid(other):
			other.set("drop_absorber", null)
		if will_kill_enemy:
			_try_heal_from_killed_enemy(enemy, other)


static func absorb_exp_gem(enemy, gem) -> int:
	if gem == null or not is_instance_valid(gem) or not gem.has_method("collect"):
		return 0
	var value: int = int(gem.collect())
	_apply_glutton_growth(enemy, ENEMY_GLUTTON_SKILL_BEHAVIOR.get_growth_multiplier(enemy))
	return value


static func absorb_heart(enemy, heart) -> float:
	if heart == null or not is_instance_valid(heart) or not heart.has_method("collect"):
		return 0.0
	var heal_amount: float = float(heart.collect())
	var final_heal_amount: float = ENEMY_GLUTTON_SKILL_BEHAVIOR.get_heart_heal_amount(enemy, heal_amount)
	if final_heal_amount > 0.0:
		enemy.current_health = min(enemy.max_health, enemy.current_health + final_heal_amount)
		enemy._spawn_status_burst(Color(1.0, 0.36, 0.48, 0.16), 24.0 + enemy.scale.x * 5.0)
	return heal_amount


static func get_player_touch_radius(enemy) -> float:
	var touch_shape := get_player_touch_shape(enemy)
	if not touch_shape.is_empty():
		return max(float(touch_shape.get("horizontal_radius", 0.0)), float(touch_shape.get("vertical_radius", 0.0)))
	return max(0.0, float(enemy.contact_radius))


static func get_player_touch_shape(enemy) -> Dictionary:
	return ENEMY_GLUTTON_SKILL_BEHAVIOR.get_player_touch_shape(enemy)


static func get_passive_player_touch_shape(enemy) -> Dictionary:
	var shadow_ellipse := _get_shadow_world_ellipse(enemy)
	if not shadow_ellipse.is_empty():
		return {
			"center": shadow_ellipse.get("center", enemy.global_position),
			"horizontal_radius": float(shadow_ellipse.get("horizontal_radius", 0.0)) * PLAYER_TOUCH_SHADOW_RADIUS_RATIO,
			"vertical_radius": float(shadow_ellipse.get("vertical_radius", 0.0)) * PLAYER_TOUCH_SHADOW_RADIUS_RATIO
		}
	var fallback_radius: float = max(0.0, float(enemy.contact_radius))
	return {
		"center": enemy.global_position,
		"horizontal_radius": fallback_radius,
		"vertical_radius": fallback_radius
	}


static func get_debug_aura_shape(enemy) -> Dictionary:
	return ENEMY_GLUTTON_SKILL_BEHAVIOR.get_debug_stomp_shape(enemy)


static func get_debug_wood_spike_hitboxes(enemy) -> Array:
	return ENEMY_GLUTTON_SKILL_BEHAVIOR.get_active_wood_spike_hitboxes(enemy)


static func _apply_glutton_growth(enemy, absorbed_count: float) -> void:
	if absorbed_count <= 0.0:
		return
	enemy.glutton_growth_carry += absorbed_count
	var whole_count := int(floor(enemy.glutton_growth_carry))
	enemy.glutton_growth_carry -= float(whole_count)
	if whole_count <= 0:
		return
	for _index in range(whole_count):
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


static func _is_inside_aura(target, aura_shape: Dictionary) -> bool:
	if target == null or target is not Node2D:
		return false
	var center: Vector2 = aura_shape.get("center", Vector2.ZERO)
	var horizontal_radius: float = max(1.0, float(aura_shape.get("horizontal_radius", 0.0)))
	var vertical_radius: float = max(1.0, float(aura_shape.get("vertical_radius", 0.0)))
	var relative: Vector2 = (target as Node2D).global_position - center
	var ellipse_value: float = pow(relative.x / horizontal_radius, 2.0) + pow(relative.y / vertical_radius, 2.0)
	return ellipse_value <= 1.0


static func _get_aura_shape(enemy) -> Dictionary:
	return get_player_touch_shape(enemy)


static func _get_shadow_world_ellipse(enemy) -> Dictionary:
	if enemy == null or not is_instance_valid(enemy):
		return {}
	var visual: Node = enemy.get_node_or_null("ProfileVisual")
	if visual != null and visual.has_method("get_shadow_world_ellipse"):
		var ellipse: Variant = visual.call("get_shadow_world_ellipse")
		if ellipse is Dictionary and not (ellipse as Dictionary).is_empty():
			return ellipse
	if visual != null and visual.has_method("get_shadow_world_radius"):
		var radius: float = max(0.0, float(visual.call("get_shadow_world_radius")))
		if radius > 0.0:
			return {
				"center": enemy.global_position,
				"horizontal_radius": radius,
				"vertical_radius": radius
			}
	return {}


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


static func _try_heal_from_killed_enemy(enemy, killed_enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if killed_enemy == null:
		return
	var killed_kind: String = str(killed_enemy.get("enemy_kind"))
	var heal_chance: float = ENEMY_DROPS.get_heart_drop_chance(killed_kind)
	if randf() > heal_chance:
		return
	var heal_amount: float = max(0.0, float(enemy.max_health)) * KILL_HEAL_MAX_HEALTH_RATIO
	if heal_amount <= 0.0:
		return
	enemy.current_health = min(float(enemy.max_health), float(enemy.current_health) + heal_amount)
	enemy._spawn_status_burst(Color(1.0, 0.36, 0.48, 0.16), 24.0 + enemy.scale.x * 5.0)


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

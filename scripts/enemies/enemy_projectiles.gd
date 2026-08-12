extends RefCounted

const ENEMY_VISUAL_DATA := preload("res://scripts/enemies/enemy_visual_data.gd")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const NON_BOSS_PROJECTILE_SPEED_MULTIPLIER := 0.6
const DEFAULT_HIT_RADIUS := 16.0
const ENEMY_PROJECTILE_POOL_GROUP := "enemy_projectile_pool"

static func fire_shooter_pattern(enemy) -> void:
	var current_scene: Node = _get_enemy_current_scene(enemy)
	var split_volley_id := 0
	if _uses_split_volley_budget(enemy) and current_scene != null and current_scene.has_method("reserve_enemy_split_projectile_volley"):
		split_volley_id = int(current_scene.reserve_enemy_split_projectile_volley(enemy))
		if split_volley_id <= 0:
			return
	if not _fire_shooter_pattern_now(enemy, split_volley_id) and split_volley_id > 0:
		_release_split_volley(current_scene, split_volley_id)

static func fire_queued_split_shooter_pattern(request: Dictionary, current_scene: Node = null) -> void:
	var enemy = request.get("enemy", null)
	var split_volley_id: int = int(request.get("split_volley_id", 0))
	if current_scene == null:
		current_scene = _get_enemy_current_scene(enemy)
	if split_volley_id <= 0:
		return
	if not _fire_shooter_pattern_now(enemy, split_volley_id):
		_release_split_volley(current_scene, split_volley_id)

static func _fire_shooter_pattern_now(enemy, split_volley_id: int = 0) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.target == null or not is_instance_valid(enemy.target):
		return false
	var aim_direction: Vector2 = enemy._cached_direction_to_target
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	var start_position: Vector2 = enemy.global_position + aim_direction * (22.0 + enemy.scale.x * 4.0)
	var count: int = max(1, enemy.projectile_count)
	var spread_step: float = enemy.projectile_spread
	var offset_center: float = float(count - 1) * 0.5
	var spawned_count := 0
	for index in range(count):
		var shot_direction: Vector2 = aim_direction.rotated((float(index) - offset_center) * spread_step)
		var extra_config: Dictionary = {}
		if enemy.projectile_split_count > 0 and enemy.projectile_split_after > 0.0:
			extra_config = {
				"split_volley_id": split_volley_id,
				"split_count": enemy.projectile_split_count,
				"split_after_time": enemy.projectile_split_after,
				"split_pattern": enemy.projectile_split_pattern,
				"split_spread": enemy.projectile_split_spread,
				"split_speed": enemy.projectile_speed * enemy.projectile_split_speed_scale,
				"split_damage_scale": enemy.projectile_split_damage_scale,
				"split_lifetime": max(1.6, enemy.projectile_lifetime * enemy.projectile_split_lifetime_scale),
				"split_motion_mode": "straight",
				"split_size_scale": enemy.projectile_split_size_scale,
				"split_hit_radius_scale": enemy.projectile_split_hit_radius_scale,
				"split_visual_style": enemy.projectile_visual_style
			}
		var projectile = spawn_projectile(
			enemy,
			start_position,
			shot_direction,
			enemy.projectile_speed,
			enemy.projectile_damage,
			enemy.projectile_lifetime,
			get_projectile_color(enemy),
			"straight",
			extra_config
		)
		if projectile != null:
			spawned_count += 1
	if spawned_count <= 0:
		return false
	var projectile_color := get_projectile_color(enemy)
	enemy._spawn_status_burst(Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.18), 16.0 + enemy.scale.x * 4.0)
	return true

static func spawn_projectile(enemy, origin: Vector2, shot_direction: Vector2, shot_speed: float, shot_damage: float, shot_lifetime: float, color: Color, mode: String, extra_config: Dictionary = {}) -> Node:
	if enemy.projectile_scene == null:
		return null
	var current_scene: Node = _get_enemy_current_scene(enemy)
	if current_scene == null:
		return null
	if not _can_spawn_enemy_projectile(current_scene, enemy):
		return null
	var projectile = _take_projectile_from_pool(current_scene)
	if projectile == null:
		projectile = enemy.projectile_scene.instantiate()
	if projectile == null:
		return null
	var speed_multiplier := NON_BOSS_PROJECTILE_SPEED_MULTIPLIER if str(enemy.enemy_kind) != "boss" else 1.0
	if projectile.get_parent() == null:
		current_scene.add_child(projectile)
	elif projectile.get_parent() != current_scene:
		projectile.get_parent().remove_child(projectile)
		current_scene.add_child(projectile)
	var config := {
		"position": origin,
		"direction": shot_direction.normalized(),
		"speed": shot_speed * speed_multiplier,
		"damage": shot_damage,
		"lifetime": shot_lifetime,
		"hit_radius": DEFAULT_HIT_RADIUS,
		"visual_color": color,
		"visual_style": enemy.projectile_visual_style,
		"size_scale": 1.0,
		"motion_mode": mode,
		"split_on_return": false,
		"split_volley_id": 0,
		"split_count": 0,
		"split_after_time": 0.0,
		"split_pattern": "radial",
		"split_visual_style": "",
		"target": enemy.target,
		"source_enemy_instance_id": enemy.get_instance_id(),
		"source_enemy_kind": str(enemy.enemy_kind)
	}
	for key in extra_config.keys():
		if key in ["split_speed", "return_speed"]:
			config[key] = float(extra_config[key]) * speed_multiplier
		else:
			config[key] = extra_config[key]
	if projectile.has_method("reset_projectile"):
		projectile.reset_projectile(config)
	else:
		for key in config.keys():
			if key == "source_enemy_instance_id" or key == "source_enemy_kind":
				projectile.set_meta(key, config[key])
			else:
				projectile.set(key, config[key])
	return projectile

static func clear_projectiles_from_source(enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var current_scene: Node = _get_enemy_current_scene(enemy)
	if current_scene == null and enemy is Node:
		var tree: SceneTree = (enemy as Node).get_tree()
		current_scene = tree.current_scene if tree != null else null
	if current_scene == null:
		return

	var source_id: int = enemy.get_instance_id()
	var source_kind: String = str(enemy.enemy_kind)
	var projectiles: Array = []
	if current_scene.has_method("get_runtime_enemy_projectiles"):
		projectiles = current_scene.get_runtime_enemy_projectiles()
	elif current_scene.is_inside_tree() and current_scene.get_tree() != null:
		projectiles = current_scene.get_tree().get_nodes_in_group("enemy_projectiles")

	for projectile in projectiles:
		if projectile == null or not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			continue
		if not _is_projectile_from_source(projectile, source_id, source_kind):
			continue
		if projectile.has_method("recycle"):
			projectile.recycle()
		else:
			projectile.queue_free()

static func _is_projectile_from_source(projectile: Object, source_id: int, source_kind: String) -> bool:
	var projectile_source_id := 0
	if projectile.has_meta("source_enemy_instance_id"):
		projectile_source_id = int(projectile.get_meta("source_enemy_instance_id"))
	if source_id > 0 and projectile_source_id == source_id:
		return true
	if source_kind != "boss" or not projectile.has_meta("source_enemy_kind"):
		return false
	return str(projectile.get_meta("source_enemy_kind")) == "boss"

static func _take_projectile_from_pool(current_scene: Node):
	if current_scene == null or current_scene.get_tree() == null:
		return null
	if current_scene.has_method("take_runtime_enemy_projectile_from_pool"):
		return current_scene.take_runtime_enemy_projectile_from_pool()
	for projectile in current_scene.get_tree().get_nodes_in_group(ENEMY_PROJECTILE_POOL_GROUP):
		if projectile != null and is_instance_valid(projectile):
			return projectile
	return null

static func get_projectile_color(enemy) -> Color:
	if enemy != null and enemy.get("projectile_color") is Color:
		var profile_color: Color = enemy.get("projectile_color") as Color
		if profile_color.a >= 0.0:
			return profile_color
	return ENEMY_VISUAL_DATA.get_projectile_color(enemy.archetype_id)

static func _get_enemy_projectile_limit(enemy) -> int:
	var current_scene: Node = _get_enemy_current_scene(enemy)
	if current_scene != null and current_scene.has_method("_get_difficulty_limit"):
		return int(current_scene._get_difficulty_limit("enemy_projectile_limit", PERFORMANCE_GUARD.DEFAULT_ENEMY_PROJECTILE_LIMIT))
	return PERFORMANCE_GUARD.DEFAULT_ENEMY_PROJECTILE_LIMIT

static func _can_spawn_enemy_projectile(current_scene: Node, enemy) -> bool:
	var limit: int = _get_enemy_projectile_limit(enemy)
	if current_scene != null and current_scene.has_method("_can_spawn_runtime_group"):
		return bool(current_scene._can_spawn_runtime_group("enemy_projectiles", limit))
	return PERFORMANCE_GUARD.can_spawn_in_group(current_scene, "enemy_projectiles", limit)

static func _uses_split_volley_budget(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if str(enemy.enemy_kind) == "boss":
		return false
	return enemy.projectile_split_count > 0 and enemy.projectile_split_after > 0.0

static func _release_split_volley(current_scene: Node, split_volley_id: int) -> void:
	if current_scene != null and current_scene.has_method("release_enemy_split_projectile_volley"):
		current_scene.release_enemy_split_projectile_volley(split_volley_id)

static func _get_enemy_current_scene(enemy) -> Node:
	if enemy == null or not is_instance_valid(enemy):
		return null
	if enemy is Node and not (enemy as Node).is_inside_tree():
		return null
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		return null
	return tree.current_scene

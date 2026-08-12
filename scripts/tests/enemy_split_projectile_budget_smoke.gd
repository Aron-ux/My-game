extends SceneTree

const ENEMY_PROJECTILES := preload("res://scripts/enemies/enemy_projectiles.gd")
const ENEMY_PROJECTILE_BUDGET_FLOW := preload("res://scripts/game/enemy_projectile_budget_flow.gd")
const ENEMY_BULLET_SCENE := preload("res://scenes/enemy_bullet.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	randomize()
	var scene := RuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene

	var target := TargetStub.new()
	target.global_position = Vector2(240.0, 0.0)
	scene.add_child(target)

	_check_budget_queues_and_releases(scene, target)
	_check_dead_queued_shooter_is_skipped(scene, target)

	scene.queue_free()
	await process_frame
	current_scene = null

	if failures.is_empty():
		print("ENEMY_SPLIT_PROJECTILE_BUDGET_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_budget_queues_and_releases(scene: RuntimeRoot, target: Node2D) -> void:
	scene.reset_budget_state()
	var blocking_ids := _fill_split_budget(scene, target)
	var queued_enemy := SplitShooterStub.new()
	queued_enemy.target = target
	scene.add_child(queued_enemy)

	ENEMY_PROJECTILES.fire_shooter_pattern(queued_enemy)
	_assert_equal(scene.get_pending_enemy_split_projectile_request_count(), 1, "split shooter should queue when volley budget is full")
	_assert_equal(scene.get_runtime_enemy_projectiles().size(), 0, "queued split shooter should not spawn projectile nodes")

	ENEMY_PROJECTILES.fire_shooter_pattern(queued_enemy)
	_assert_equal(scene.get_pending_enemy_split_projectile_request_count(), 1, "same shooter should only keep one pending split request")

	scene.release_enemy_split_projectile_volley(blocking_ids[0])
	_assert_equal(scene.get_pending_enemy_split_projectile_request_count(), 0, "released volley slot should drain one pending request")
	_assert_equal(queued_enemy.burst_count, 1, "queued live shooter should fire after a volley slot opens")
	_assert_equal(scene.get_runtime_enemy_projectiles().size(), 1, "queued live shooter should create one mother projectile")
	var projectile = scene.get_runtime_enemy_projectiles()[0]
	if int(projectile.get("split_volley_id")) <= 0:
		failures.append("queued projectile should inherit a split volley id")
	if scene.get_active_enemy_split_projectile_volley_count() != scene.get_enemy_split_projectile_volley_limit():
		failures.append("queued fire should replace the released active volley slot")

	for active_projectile in scene.get_runtime_enemy_projectiles():
		if active_projectile != null and is_instance_valid(active_projectile) and active_projectile.has_method("recycle"):
			active_projectile.recycle()


func _check_dead_queued_shooter_is_skipped(scene: RuntimeRoot, target: Node2D) -> void:
	scene.reset_budget_state()
	var blocking_ids := _fill_split_budget(scene, target)
	var dead_enemy := SplitShooterStub.new()
	dead_enemy.target = target
	scene.add_child(dead_enemy)

	ENEMY_PROJECTILES.fire_shooter_pattern(dead_enemy)
	_assert_equal(scene.get_pending_enemy_split_projectile_request_count(), 1, "dead shooter setup should queue one request")
	dead_enemy.free()
	scene.release_enemy_split_projectile_volley(blocking_ids[0])
	_assert_equal(scene.get_pending_enemy_split_projectile_request_count(), 0, "dead queued shooter should be pruned")
	_assert_equal(scene.get_runtime_enemy_projectiles().size(), 0, "dead queued shooter should not spawn projectiles")


func _fill_split_budget(scene: RuntimeRoot, target: Node2D) -> Array[int]:
	var blocking_ids: Array[int] = []
	var limit := scene.get_enemy_split_projectile_volley_limit()
	for _index in range(limit):
		var enemy := SplitShooterStub.new()
		enemy.target = target
		scene.add_child(enemy)
		blocking_ids.append(scene.reserve_enemy_split_projectile_volley(enemy))
		enemy.queue_free()
	return blocking_ids


func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


class TargetStub:
	extends Node2D

	var damage_taken: float = 0.0

	func get_hurtbox_center() -> Vector2:
		return global_position

	func get_hurtbox_radius() -> float:
		return 8.0

	func take_damage(amount: float) -> void:
		damage_taken += amount


class SplitShooterStub:
	extends Node2D

	var target: Node2D
	var projectile_scene: PackedScene = ENEMY_BULLET_SCENE
	var _cached_direction_to_target: Vector2 = Vector2.RIGHT
	var projectile_count: int = 1
	var projectile_spread: float = 0.0
	var projectile_speed: float = 180.0
	var projectile_damage: float = 3.0
	var projectile_lifetime: float = 1.5
	var projectile_visual_style: String = ""
	var projectile_color: Color = Color(1.0, 0.4, 0.2, 1.0)
	var projectile_split_count: int = 4
	var projectile_split_after: float = 0.2
	var projectile_split_pattern: String = "radial"
	var projectile_split_spread: float = 1.2
	var projectile_split_speed_scale: float = 0.7
	var projectile_split_damage_scale: float = 0.45
	var projectile_split_lifetime_scale: float = 0.8
	var projectile_split_size_scale: float = 0.75
	var projectile_split_hit_radius_scale: float = 0.8
	var enemy_kind: String = "elite"
	var archetype_id: String = "elite_splitshot"
	var burst_count: int = 0

	func _spawn_status_burst(_color: Color, _radius: float) -> void:
		burst_count += 1


class RuntimeRoot:
	extends Node2D

	const BUDGET_FLOW := ENEMY_PROJECTILE_BUDGET_FLOW
	const PROJECTILES := ENEMY_PROJECTILES

	var active_projectiles: Dictionary = {}
	var pooled_projectiles: Dictionary = {}
	var active_enemy_split_projectile_volleys: Dictionary = {}
	var pending_enemy_split_projectile_requests: Array[Dictionary] = []
	var pending_enemy_split_projectile_by_enemy: Dictionary = {}
	var enemy_split_projectile_next_volley_id: int = 1
	var enemy_projectile_limit: int = 240

	func reset_budget_state() -> void:
		for projectile in get_runtime_enemy_projectiles():
			if projectile != null and is_instance_valid(projectile):
				projectile.queue_free()
		active_projectiles.clear()
		pooled_projectiles.clear()
		active_enemy_split_projectile_volleys.clear()
		pending_enemy_split_projectile_requests.clear()
		pending_enemy_split_projectile_by_enemy.clear()
		enemy_split_projectile_next_volley_id = 1

	func _get_difficulty_limit(key: String, fallback: int) -> int:
		if key == "enemy_projectile_limit":
			return enemy_projectile_limit
		return fallback

	func _can_spawn_runtime_group(group_name: String, fallback_limit: int) -> bool:
		if group_name == "enemy_projectiles":
			return get_runtime_enemy_projectiles().size() < fallback_limit
		return true

	func reserve_enemy_split_projectile_volley(enemy: Node) -> int:
		return BUDGET_FLOW.reserve_enemy_split_projectile_volley(self, enemy)

	func register_enemy_split_projectile_volley_projectile(volley_id: int) -> void:
		BUDGET_FLOW.register_enemy_split_projectile_volley_projectile(self, volley_id)

	func release_enemy_split_projectile_volley_projectile(volley_id: int) -> void:
		_fire_queued_enemy_split_projectile_requests(BUDGET_FLOW.release_enemy_split_projectile_volley_projectile(self, volley_id))

	func release_enemy_split_projectile_volley(volley_id: int) -> void:
		_fire_queued_enemy_split_projectile_requests(BUDGET_FLOW.release_enemy_split_projectile_volley(self, volley_id))

	func get_active_enemy_split_projectile_volley_count() -> int:
		return BUDGET_FLOW.get_active_enemy_split_projectile_volley_count(self)

	func get_pending_enemy_split_projectile_request_count() -> int:
		return BUDGET_FLOW.get_pending_enemy_split_projectile_request_count(self)

	func get_enemy_split_projectile_volley_limit() -> int:
		return BUDGET_FLOW.get_enemy_split_projectile_volley_limit(self)

	func _fire_queued_enemy_split_projectile_requests(requests: Array[Dictionary]) -> void:
		for request in requests:
			PROJECTILES.fire_queued_split_shooter_pattern(request, self)

	func register_runtime_enemy_projectile(projectile: Node, pooled: bool) -> void:
		var instance_id := projectile.get_instance_id()
		active_projectiles.erase(instance_id)
		pooled_projectiles.erase(instance_id)
		if pooled:
			pooled_projectiles[instance_id] = projectile
		else:
			active_projectiles[instance_id] = projectile

	func unregister_runtime_enemy_projectile(projectile: Node) -> void:
		var instance_id := projectile.get_instance_id()
		active_projectiles.erase(instance_id)
		pooled_projectiles.erase(instance_id)

	func get_runtime_enemy_projectiles() -> Array:
		return _valid_nodes(active_projectiles)

	func get_runtime_enemy_projectile_pool() -> Array:
		return _valid_nodes(pooled_projectiles)

	func take_runtime_enemy_projectile_from_pool() -> Node:
		for instance_id in pooled_projectiles.keys():
			var projectile = pooled_projectiles[instance_id]
			pooled_projectiles.erase(instance_id)
			if projectile != null and is_instance_valid(projectile):
				return projectile
		return null

	func _valid_nodes(nodes: Dictionary) -> Array:
		var result: Array = []
		for node in nodes.values():
			if node != null and is_instance_valid(node):
				result.append(node)
		return result

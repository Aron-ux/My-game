extends RefCounted

const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")

const DEFAULT_SPLIT_VOLLEY_LIMIT := 5
const ELEVATED_SPLIT_VOLLEY_LIMIT := 4
const HIGH_SPLIT_VOLLEY_LIMIT := 3
const CRITICAL_SPLIT_VOLLEY_LIMIT := 2
const MAX_PENDING_SPLIT_VOLLEY_REQUESTS := 16
const SPLIT_VOLLEY_REQUEST_TTL_MSEC := 2200


static func reserve_enemy_split_projectile_volley(main: Node, enemy: Node) -> int:
	if main == null:
		return 0
	_prune_pending_split_projectile_requests(main)
	if _can_start_split_volley(main):
		return _start_split_volley(main)
	_queue_split_projectile_request(main, enemy)
	return 0


static func register_enemy_split_projectile_volley_projectile(main: Node, volley_id: int) -> void:
	if main == null or volley_id <= 0:
		return
	if not main.active_enemy_split_projectile_volleys.has(volley_id):
		main.active_enemy_split_projectile_volleys[volley_id] = 0
	main.active_enemy_split_projectile_volleys[volley_id] = int(main.active_enemy_split_projectile_volleys[volley_id]) + 1
	main.enemy_split_projectile_next_volley_id = max(int(main.enemy_split_projectile_next_volley_id), volley_id + 1)


static func release_enemy_split_projectile_volley_projectile(main: Node, volley_id: int) -> Array[Dictionary]:
	if main == null or volley_id <= 0:
		return []
	if not main.active_enemy_split_projectile_volleys.has(volley_id):
		return []
	var remaining_count: int = int(main.active_enemy_split_projectile_volleys[volley_id]) - 1
	if remaining_count > 0:
		main.active_enemy_split_projectile_volleys[volley_id] = remaining_count
		return []
	main.active_enemy_split_projectile_volleys.erase(volley_id)
	return pop_ready_split_projectile_requests(main, 1)


static func release_enemy_split_projectile_volley(main: Node, volley_id: int) -> Array[Dictionary]:
	if main == null or volley_id <= 0:
		return []
	if main.active_enemy_split_projectile_volleys.erase(volley_id):
		return pop_ready_split_projectile_requests(main, 1)
	return []


static func pop_ready_split_projectile_requests(main: Node, max_count: int = 1) -> Array[Dictionary]:
	var ready_requests: Array[Dictionary] = []
	if main == null or max_count <= 0:
		return ready_requests
	_prune_pending_split_projectile_requests(main)
	while ready_requests.size() < max_count and not main.pending_enemy_split_projectile_requests.is_empty() and _can_start_split_volley(main):
		var request_index: int = randi() % main.pending_enemy_split_projectile_requests.size()
		var request: Dictionary = main.pending_enemy_split_projectile_requests[request_index]
		main.pending_enemy_split_projectile_requests.remove_at(request_index)
		main.pending_enemy_split_projectile_by_enemy.erase(int(request.get("enemy_id", 0)))
		if not _is_pending_request_still_valid(request):
			continue
		request["split_volley_id"] = _start_split_volley(main)
		ready_requests.append(request)
	return ready_requests


static func get_active_enemy_split_projectile_volley_count(main: Node) -> int:
	if main == null:
		return 0
	return main.active_enemy_split_projectile_volleys.size()


static func get_pending_enemy_split_projectile_request_count(main: Node) -> int:
	if main == null:
		return 0
	_prune_pending_split_projectile_requests(main)
	return main.pending_enemy_split_projectile_requests.size()


static func get_enemy_split_projectile_volley_limit(main: Node) -> int:
	if main == null:
		return DEFAULT_SPLIT_VOLLEY_LIMIT
	var projectile_limit: int = _get_enemy_projectile_limit(main)
	var active_projectiles: int = _get_active_enemy_projectile_count(main)
	var pressure_ratio := 0.0
	if projectile_limit > 0:
		pressure_ratio = float(active_projectiles) / float(projectile_limit)
	if pressure_ratio >= 0.85:
		return CRITICAL_SPLIT_VOLLEY_LIMIT
	if pressure_ratio >= 0.68:
		return HIGH_SPLIT_VOLLEY_LIMIT
	if pressure_ratio >= 0.52:
		return ELEVATED_SPLIT_VOLLEY_LIMIT
	return DEFAULT_SPLIT_VOLLEY_LIMIT


static func _can_start_split_volley(main: Node) -> bool:
	return get_active_enemy_split_projectile_volley_count(main) < get_enemy_split_projectile_volley_limit(main)


static func _start_split_volley(main: Node) -> int:
	var volley_id: int = max(1, int(main.enemy_split_projectile_next_volley_id))
	main.enemy_split_projectile_next_volley_id = volley_id + 1
	main.active_enemy_split_projectile_volleys[volley_id] = 0
	return volley_id


static func _queue_split_projectile_request(main: Node, enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var enemy_id: int = enemy.get_instance_id()
	if main.pending_enemy_split_projectile_by_enemy.has(enemy_id):
		return
	_prune_pending_split_projectile_requests(main)
	if main.pending_enemy_split_projectile_requests.size() >= MAX_PENDING_SPLIT_VOLLEY_REQUESTS:
		return
	var request := {
		"enemy": enemy,
		"enemy_id": enemy_id,
		"requested_at_msec": Time.get_ticks_msec()
	}
	main.pending_enemy_split_projectile_requests.append(request)
	main.pending_enemy_split_projectile_by_enemy[enemy_id] = true


static func _prune_pending_split_projectile_requests(main: Node) -> void:
	if main == null:
		return
	var now_msec: int = Time.get_ticks_msec()
	for index in range(main.pending_enemy_split_projectile_requests.size() - 1, -1, -1):
		var request: Dictionary = main.pending_enemy_split_projectile_requests[index]
		if _is_pending_request_expired(request, now_msec) or not _is_pending_request_still_valid(request):
			main.pending_enemy_split_projectile_requests.remove_at(index)
			main.pending_enemy_split_projectile_by_enemy.erase(int(request.get("enemy_id", 0)))


static func _is_pending_request_expired(request: Dictionary, now_msec: int) -> bool:
	return now_msec - int(request.get("requested_at_msec", now_msec)) > SPLIT_VOLLEY_REQUEST_TTL_MSEC


static func _is_pending_request_still_valid(request: Dictionary) -> bool:
	var enemy = request.get("enemy", null)
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy is Node and not (enemy as Node).is_inside_tree():
		return false
	if enemy.get("target") == null or not is_instance_valid(enemy.get("target")):
		return false
	return true


static func _get_active_enemy_projectile_count(main: Node) -> int:
	if main.has_method("get_runtime_enemy_projectiles"):
		return (main.get_runtime_enemy_projectiles() as Array).size()
	if main.get_tree() == null:
		return 0
	return PERFORMANCE_GUARD.get_group_count(main, "enemy_projectiles")


static func _get_enemy_projectile_limit(main: Node) -> int:
	var base_limit := PERFORMANCE_GUARD.DEFAULT_ENEMY_PROJECTILE_LIMIT
	if main.has_method("_get_difficulty_limit"):
		base_limit = int(main._get_difficulty_limit("enemy_projectile_limit", base_limit))
	return PERFORMANCE_GUARD.get_dynamic_limit(main, "enemy_projectiles", base_limit)

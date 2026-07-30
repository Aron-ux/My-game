extends RefCounted

const RUAN_STONE_SYSTEM := preload("res://scripts/player/ruan_stone_system.gd")
const ENEMY_SPATIAL_GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")
const RUAN_POISON_EFFECT := preload("res://scripts/player/ruan_poison_effect.gd")

const SECONDARY_QUERY_RADIUS := 260.0
const EVENT_RETENTION_MSEC := 8000
const MAX_TRACKED_EVENTS := 64


static func apply_basic_hit(owner, enemy: Node, triggering_damage: float, source_role_id: String, damage_event_id: String, killed: bool) -> void:
	if owner == null or enemy == null or triggering_damage <= 0.0:
		return
	var stone_id := str(owner.get("equipped_ruan_stone"))
	var levels: Variant = owner.get("ruan_stone_levels")
	if stone_id == "" or levels is not Dictionary:
		return
	var level: int = max(0, int((levels as Dictionary).get(stone_id, 0)))
	if level <= 0:
		return
	var event_key: String = _event_key(source_role_id, damage_event_id)
	if event_key == "":
		return
	var state: Dictionary = _get_event_state(owner, event_key)
	var target_id: int = enemy.get_instance_id()
	var hit_targets: Dictionary = state.get("hit_targets", {})
	var first_target_hit: bool = not hit_targets.has(target_id)
	hit_targets[target_id] = true
	state["hit_targets"] = hit_targets
	var values: Dictionary = RUAN_STONE_SYSTEM.get_effect_values(stone_id, level)
	match stone_id:
		RUAN_STONE_SYSTEM.STONE_THUNDER:
			if not bool(state.get("primary_proc", false)):
				state["primary_proc"] = true
				_apply_thunder(enemy, triggering_damage, values)
		RUAN_STONE_SYSTEM.STONE_FROST:
			if first_target_hit and not killed:
				_apply_frost(enemy, values)
		RUAN_STONE_SYSTEM.STONE_POISON:
			if first_target_hit and not killed:
				_apply_poison(enemy, triggering_damage, values)
		RUAN_STONE_SYSTEM.STONE_FLAME:
			if not bool(state.get("primary_proc", false)):
				state["primary_proc"] = true
				_apply_flame(enemy, triggering_damage, values)
		RUAN_STONE_SYSTEM.STONE_FURY:
			if first_target_hit and not killed:
				_apply_fury(enemy, values)
	_store_event_state(owner, event_key, state)


static func _apply_thunder(origin_enemy: Node, triggering_damage: float, values: Dictionary) -> void:
	if origin_enemy is not Node2D:
		return
	var current: Node2D = origin_enemy as Node2D
	var visited: Dictionary = {origin_enemy.get_instance_id(): true}
	var damage: float = triggering_damage * float(values.get("damage_ratio", 0.0))
	for _jump in range(max(0, int(values.get("jump_count", 0)))):
		var target: Node2D = _nearest_neighbor(current, visited)
		if target == null:
			break
		_deal_secondary_damage(target, damage)
		visited[target.get_instance_id()] = true
		current = target
		damage *= 0.85


static func _apply_frost(enemy: Node, values: Dictionary) -> void:
	if enemy.has_method("apply_slow"):
		enemy.apply_slow(1.0 - float(values.get("slow_ratio", 0.0)), float(values.get("duration", 0.0)))


static func _apply_poison(enemy: Node, triggering_damage: float, values: Dictionary) -> void:
	var effect: Node = enemy.get_node_or_null("RuanPoisonEffect")
	if effect == null:
		effect = RUAN_POISON_EFFECT.new()
		effect.name = "RuanPoisonEffect"
		enemy.add_child(effect)
	effect.apply_stack(
		triggering_damage * float(values.get("total_damage_ratio", 0.0)),
		float(values.get("duration", 3.0)),
		int(values.get("max_stacks", 3))
	)


static func _apply_flame(origin_enemy: Node, triggering_damage: float, values: Dictionary) -> void:
	if origin_enemy is not Node2D:
		return
	var candidates: Array = []
	for candidate in ENEMY_SPATIAL_GRID.get_neighbors(origin_enemy as Node2D, SECONDARY_QUERY_RADIUS):
		if candidate == origin_enemy or not _is_live_enemy(candidate) or candidate is not Node2D:
			continue
		if (origin_enemy as Node2D).global_position.distance_squared_to((candidate as Node2D).global_position) > SECONDARY_QUERY_RADIUS * SECONDARY_QUERY_RADIUS:
			continue
		candidates.append(candidate)
	candidates.sort_custom(func(a, b) -> bool:
		return (origin_enemy as Node2D).global_position.distance_squared_to((a as Node2D).global_position) < (origin_enemy as Node2D).global_position.distance_squared_to((b as Node2D).global_position)
	)
	var damage: float = triggering_damage * float(values.get("damage_ratio", 0.0))
	for index in range(min(int(values.get("target_count", 0)), candidates.size())):
		_deal_secondary_damage(candidates[index], damage)


static func _apply_fury(enemy: Node, values: Dictionary) -> void:
	if enemy.has_method("apply_vulnerability"):
		enemy.apply_vulnerability(float(values.get("vulnerability_ratio", 0.0)), float(values.get("duration", 0.0)))


static func _nearest_neighbor(origin: Node2D, visited: Dictionary) -> Node2D:
	var nearest: Node2D
	var nearest_distance: float = INF
	for candidate in ENEMY_SPATIAL_GRID.get_neighbors(origin, SECONDARY_QUERY_RADIUS):
		if not _is_live_enemy(candidate) or candidate is not Node2D or visited.has(candidate.get_instance_id()):
			continue
		var distance: float = origin.global_position.distance_squared_to((candidate as Node2D).global_position)
		if distance > SECONDARY_QUERY_RADIUS * SECONDARY_QUERY_RADIUS:
			continue
		if distance < nearest_distance:
			nearest = candidate as Node2D
			nearest_distance = distance
	return nearest


static func _deal_secondary_damage(enemy: Node, damage: float) -> void:
	if damage <= 0.0 or not _is_live_enemy(enemy):
		return
	if enemy.has_method("take_batched_damage"):
		enemy.take_batched_damage(damage)
	elif enemy.has_method("take_damage"):
		enemy.take_damage(damage)


static func _is_live_enemy(enemy: Variant) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Node):
		return false
	var health: Variant = (enemy as Node).get("current_health")
	return health == null or float(health) > 0.0


static func _event_key(source_role_id: String, damage_event_id: String) -> String:
	var marker_separator: int = source_role_id.find(":")
	if marker_separator >= 0:
		return source_role_id.substr(marker_separator + 1)
	return damage_event_id


static func _get_event_state(owner, event_key: String) -> Dictionary:
	var events: Variant = owner.get("ruan_stone_proc_events")
	if events is not Dictionary:
		return {}
	var state: Dictionary = (events as Dictionary).get(event_key, {})
	state["expires_at"] = Time.get_ticks_msec() + EVENT_RETENTION_MSEC
	return state


static func _store_event_state(owner, event_key: String, state: Dictionary) -> void:
	var events: Dictionary = owner.get("ruan_stone_proc_events")
	events[event_key] = state
	var now: int = Time.get_ticks_msec()
	for key in events.keys():
		if int((events[key] as Dictionary).get("expires_at", 0)) <= now:
			events.erase(key)
	while events.size() > MAX_TRACKED_EVENTS:
		events.erase(events.keys()[0])

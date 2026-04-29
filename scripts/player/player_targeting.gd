extends RefCounted

static func get_enemy_nodes(owner) -> Array:
	return owner.get_tree().get_nodes_in_group("enemies")


static func get_owner_closest_enemy(owner) -> Node2D:
	return get_closest_enemy(get_enemy_nodes(owner), owner.global_position)


static func get_owner_farthest_enemy(owner) -> Node2D:
	return get_farthest_enemy(get_enemy_nodes(owner), owner.global_position)


static func get_owner_enemy_targets(owner, count: int, prefer_farthest: bool = false) -> Array:
	return get_enemy_targets(get_enemy_nodes(owner), owner.global_position, count, prefer_farthest)


static func get_owner_low_health_enemy(owner) -> Node2D:
	return get_low_health_enemy(get_enemy_nodes(owner))


static func get_owner_enemy_in_aim_cone(owner, max_angle_degrees: float, max_distance: float = INF) -> Node2D:
	return get_enemy_in_aim_cone(get_enemy_nodes(owner), owner.global_position, owner.facing_direction, max_angle_degrees, max_distance)


static func get_owner_enemy_cluster_center(owner) -> Vector2:
	return get_enemy_cluster_center(get_enemy_nodes(owner))


static func get_owner_random_enemy_cluster_centers(owner, count: int) -> Array:
	return get_random_enemy_cluster_centers(get_enemy_nodes(owner), owner.global_position, count)


static func get_closest_enemy(enemies: Array, origin: Vector2) -> Node2D:
	var closest_enemy: Node2D
	var closest_distance: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance: float = origin.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy
	return closest_enemy

static func get_farthest_enemy(enemies: Array, origin: Vector2) -> Node2D:
	var farthest_enemy: Node2D
	var farthest_distance: float = 0.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance: float = origin.distance_to(enemy.global_position)
		if distance > farthest_distance:
			farthest_distance = distance
			farthest_enemy = enemy
	return farthest_enemy

static func get_enemy_targets(enemies: Array, origin: Vector2, count: int, prefer_farthest: bool = false) -> Array:
	var valid_enemies: Array = []
	for enemy in enemies:
		if is_instance_valid(enemy):
			valid_enemies.append(enemy)

	if prefer_farthest:
		valid_enemies.sort_custom(func(a, b): return origin.distance_to(a.global_position) > origin.distance_to(b.global_position))
	else:
		valid_enemies.sort_custom(func(a, b): return origin.distance_to(a.global_position) < origin.distance_to(b.global_position))

	return valid_enemies.slice(0, min(count, valid_enemies.size()))

static func get_low_health_enemy(enemies: Array) -> Node2D:
	var selected_enemy: Node2D
	var lowest_ratio: float = 1.1
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_health: float = float(enemy.get("current_health"))
		var enemy_max_health: float = max(float(enemy.get("max_health")), 1.0)
		var ratio: float = enemy_health / enemy_max_health
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			selected_enemy = enemy
	return selected_enemy

static func get_enemy_in_aim_cone(enemies: Array, origin: Vector2, facing_direction: Vector2, max_angle_degrees: float, max_distance: float = INF) -> Node2D:
	var selected_enemy: Node2D
	var best_score: float = -INF
	var max_dot: float = cos(deg_to_rad(max_angle_degrees))
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - origin
		var distance: float = to_enemy.length()
		if distance <= 0.001 or distance > max_distance:
			continue
		var direction_dot: float = facing_direction.dot(to_enemy.normalized())
		if direction_dot < max_dot:
			continue
		var score: float = direction_dot * 1000.0 - distance
		if score > best_score:
			best_score = score
			selected_enemy = enemy
	return selected_enemy

static func get_enemy_cluster_center(enemies: Array) -> Vector2:
	if enemies.is_empty():
		return Vector2.ZERO

	var best_center := Vector2.ZERO
	var best_score: int = 0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var center: Vector2 = enemy.global_position
		var score: int = 0
		for other_enemy in enemies:
			if not is_instance_valid(other_enemy):
				continue
			if center.distance_to(other_enemy.global_position) <= 90.0:
				score += 1
		if score > best_score:
			best_score = score
			best_center = center
	return best_center

static func get_random_enemy_cluster_centers(enemies: Array, fallback_position: Vector2, count: int) -> Array:
	if enemies.is_empty():
		return [fallback_position]

	var scored_centers: Array = []
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var center: Vector2 = enemy.global_position
		var score: int = 0
		for other_enemy in enemies:
			if not is_instance_valid(other_enemy):
				continue
			if center.distance_to(other_enemy.global_position) <= 120.0:
				score += 1
		scored_centers.append({
			"center": center,
			"score": score
		})

	scored_centers.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	var candidate_pool: Array = scored_centers.slice(0, min(6, scored_centers.size()))
	var picked_centers: Array = []
	while picked_centers.size() < count and not candidate_pool.is_empty():
		var chosen_index: int = randi() % candidate_pool.size()
		var chosen_center: Vector2 = candidate_pool[chosen_index]["center"]
		candidate_pool.remove_at(chosen_index)
		var too_close := false
		for picked_center in picked_centers:
			if chosen_center.distance_to(picked_center) < 48.0:
				too_close = true
				break
		if too_close:
			continue
		picked_centers.append(chosen_center)

	if picked_centers.is_empty():
		picked_centers.append(get_enemy_cluster_center(enemies))
	while picked_centers.size() < count:
		picked_centers.append(picked_centers[picked_centers.size() - 1])
	return picked_centers

static func get_enemy_nearest_to_position(enemies: Array, position: Vector2) -> Node2D:
	var selected_enemy: Node2D
	var best_distance: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance: float = position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			selected_enemy = enemy
	return selected_enemy

static func get_enemy_near_position(enemies: Array, position: Vector2, max_distance: float) -> Node2D:
	var selected_enemy: Node2D
	var best_distance: float = max_distance
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance := position.distance_to(enemy.global_position)
		if distance > best_distance:
			continue
		best_distance = distance
		selected_enemy = enemy
	return selected_enemy

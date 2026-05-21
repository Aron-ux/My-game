extends RefCounted

const MAX_DIRECT_SEPARATION_NEIGHBORS := 36
const MAX_VELOCITY_SEPARATION_NEIGHBORS := 36
const BODY_COLLISION_RADIUS_SCALE := 0.3
const DIRECT_SEPARATION_OVERLAP_SCALE := 0.28
const DIRECT_SEPARATION_PER_NEIGHBOR_LIMIT := 7.0
const DIRECT_SEPARATION_TOTAL_LIMIT := 14.0
const DIRECT_SEPARATION_PRESSURE_INTERVAL := 1
const SEPARATION_VELOCITY_MIN_PUSH := 18.0
const SEPARATION_VELOCITY_RADIUS_SCALE := 0.7
const CLUSTER_ESCAPE_OVERLAP_SCALE := 0.22
const CLUSTER_ESCAPE_MIN_PUSH := 0.0

static func apply_body_collision_separation(enemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	if should_skip_direct_separation(enemy):
		return
	var self_body_radius: float = get_body_collision_radius(enemy)
	var push: Vector2 = Vector2.ZERO
	var cluster_center: Vector2 = Vector2.ZERO
	var total_overlap: float = 0.0
	var max_overlap: float = 0.0
	var processed: int = 0
	for other in enemy.ENEMY_SPATIAL_GRID.get_neighbors(enemy, max(144.0, self_body_radius * 5.0)):
		if other == null or other == enemy or not is_instance_valid(other) or not (other is Node2D):
			continue
		var other_radius: float = get_body_collision_radius(other)
		var offset: Vector2 = enemy.global_position - (other as Node2D).global_position
		var distance_sq: float = offset.length_squared()
		var min_distance: float = self_body_radius + other_radius
		var min_distance_sq: float = min_distance * min_distance
		if distance_sq >= min_distance_sq:
			continue
		if distance_sq <= 0.001:
			offset = Vector2.RIGHT.rotated(float((enemy.get_instance_id() + processed * 37) % 360) * PI / 180.0)
			distance_sq = 1.0
		var distance: float = sqrt(distance_sq)
		var overlap: float = min_distance - distance
		push += offset / distance * min(overlap * DIRECT_SEPARATION_OVERLAP_SCALE, DIRECT_SEPARATION_PER_NEIGHBOR_LIMIT)
		cluster_center += (other as Node2D).global_position
		total_overlap += overlap
		max_overlap = max(max_overlap, overlap)
		processed += 1
		if processed >= MAX_DIRECT_SEPARATION_NEIGHBORS:
			break
	if processed > 0 and push.length() < CLUSTER_ESCAPE_MIN_PUSH:
		push += _get_cluster_escape_push(enemy, cluster_center / float(processed), total_overlap, max_overlap)
	if push.length_squared() > 0.001:
		enemy.global_position += push.limit_length(DIRECT_SEPARATION_TOTAL_LIMIT)


static func get_separation_velocity(enemy) -> Vector2:
	var current_frame := Engine.get_physics_frames()
	if should_refresh_separation(enemy, current_frame):
		enemy.cached_separation_velocity = compute_separation_velocity(enemy)
		enemy.separation_refresh_frame = current_frame + get_separation_refresh_interval(enemy)
	return enemy.cached_separation_velocity


static func compute_separation_velocity(enemy) -> Vector2:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return Vector2.ZERO
	var push: Vector2 = Vector2.ZERO
	var cluster_center: Vector2 = Vector2.ZERO
	var total_overlap: float = 0.0
	var max_overlap: float = 0.0
	var processed: int = 0
	var self_body_radius: float = get_body_collision_radius(enemy)
	for other in enemy.ENEMY_SPATIAL_GRID.get_neighbors(enemy, max(128.0, self_body_radius * 4.5)):
		if other == null or other == enemy or not is_instance_valid(other) or not (other is Node2D):
			continue
		var offset: Vector2 = enemy.global_position - (other as Node2D).global_position
		var other_radius: float = get_body_collision_radius(other)
		var radius: float = max(12.0, self_body_radius + other_radius)
		var radius_sq: float = radius * radius
		var distance_sq: float = offset.length_squared()
		if distance_sq > radius_sq:
			continue
		if distance_sq <= 0.001:
			offset = Vector2.RIGHT.rotated(float(enemy.get_instance_id() % 360) * PI / 180.0)
			distance_sq = 1.0
		var distance: float = sqrt(distance_sq)
		var max_push: float = max(SEPARATION_VELOCITY_MIN_PUSH, radius * SEPARATION_VELOCITY_RADIUS_SCALE)
		var strength: float = (radius - distance) / radius
		push += offset.normalized() * strength * max_push
		cluster_center += (other as Node2D).global_position
		total_overlap += radius - distance
		max_overlap = max(max_overlap, radius - distance)
		processed += 1
		if processed >= MAX_VELOCITY_SEPARATION_NEIGHBORS:
			break
	if processed > 0 and push.length() < SEPARATION_VELOCITY_MIN_PUSH:
		push += _get_cluster_escape_push(enemy, cluster_center / float(processed), total_overlap, max_overlap) * 0.35
	return push


static func _get_cluster_escape_push(enemy, cluster_center: Vector2, total_overlap: float, max_overlap: float) -> Vector2:
	var direction: Vector2 = enemy.global_position - cluster_center
	if direction.length_squared() <= 0.001 and enemy.target != null and is_instance_valid(enemy.target):
		direction = enemy.global_position - enemy.target.global_position
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT.rotated(float(enemy.get_instance_id() % 360) * PI / 180.0)
	var average_overlap: float = total_overlap
	if total_overlap > 0.0:
		average_overlap = max_overlap
	return direction.normalized() * max(CLUSTER_ESCAPE_MIN_PUSH, average_overlap * CLUSTER_ESCAPE_OVERLAP_SCALE)


static func get_body_collision_radius(enemy) -> float:
	var visual_scale_multiplier: float = get_body_collision_visual_scale_multiplier(enemy)
	if float(enemy.body_collision_radius) > 0.0:
		return max(6.0, float(enemy.body_collision_radius) * visual_scale_multiplier * BODY_COLLISION_RADIUS_SCALE)
	return clamp(float(enemy.contact_radius) * 0.82, 24.0, 42.0) * visual_scale_multiplier * BODY_COLLISION_RADIUS_SCALE


static func get_body_collision_visual_scale_multiplier(enemy) -> float:
	var current_scale: float = max(abs(enemy.scale.x), abs(enemy.scale.y))
	var reference_scale: float = max(0.001, float(enemy.body_collision_reference_scale))
	return max(0.25, current_scale / reference_scale)


static func should_refresh_separation(enemy, current_frame: int) -> bool:
	if str(enemy.enemy_kind) != "normal" or str(enemy.secondary_behavior_id) != "":
		return true
	if int(enemy.separation_refresh_frame) < 0:
		enemy.separation_refresh_frame = current_frame + int(enemy.get_instance_id() % get_separation_refresh_interval(enemy))
		return true
	if bool(enemy._has_timed_behavior_traits()) and not bool(enemy._is_scene_under_enemy_pressure()):
		return true
	return current_frame >= int(enemy.separation_refresh_frame)


static func get_separation_refresh_interval(enemy) -> int:
	if str(enemy.enemy_kind) == "normal" and str(enemy.secondary_behavior_id) == "" and bool(enemy._is_scene_under_enemy_pressure()):
		return 1
	return 2


static func should_skip_direct_separation(enemy) -> bool:
	if str(enemy.enemy_kind) != "normal" or str(enemy.secondary_behavior_id) != "":
		return false
	if not bool(enemy._is_scene_under_enemy_pressure()):
		return false
	var current_frame := Engine.get_physics_frames()
	return int((current_frame + int(enemy.get_instance_id())) % DIRECT_SEPARATION_PRESSURE_INTERVAL) != 0

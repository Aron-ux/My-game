extends RefCounted

const ENEMY_SPATIAL_GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")
const ENEMY_GEOMETRY := preload("res://scripts/enemies/enemy_geometry.gd")

const SUMMON_COLOR := Color(0.35, 1.0, 0.95, 0.82)
const DEATH_SPACE_WARNING_COLOR := Color(1.0, 0.14, 0.08, 0.9)
const DEATH_SPACE_WARNING_FILL_COLOR := Color(1.0, 0.14, 0.08, 0.22)
const SUMMON_RING_START_RADIUS := 230.0
const SUMMON_AREA_RADIUS := 583.2
const SUMMON_AREA_DURATION := 7.0
const AGING_AURA_RADIUS := 300.0
const AGING_AURA_TICK_INTERVAL := 1.0
const AGING_AURA_CURRENT_HEALTH_DRAIN_RATIO := 0.05
const SUMMON_AREA_VERTEX_VISUAL_SCALE := 1.0
const SUMMON_AREA_LINE_COLOR := Color(0.08, 0.42, 0.38, 0.92)
const SUMMON_AREA_COLLISION_LAYER := 1 << 6
const DEATH_RING_DURATION := 0.72
const DEATH_RING_TARGET_RADIUS := 2400.0
const TOMB_TEXTURE := preload("res://assets/enemies/skulltomb/tomb.png")
const AREA_SCENE_PATHS := [
	"res://assets/enemies/skulltomb/area.tscn",
	"res://assets/enemies/area.tscn",
	"res://assets/area.tscn"
]
const SKULL_SOLDIER_ARCHETYPES := ["dasher", "elite_ram_trail"]
const SKULL_SHOT_ARCHETYPES := ["shooter", "shotgunner", "elite_splitshot"]
const SKULLTOMB_SUMMON_SPAWN_INTERVAL := 0.14
const SKULLTOMB_VERTEX_SPAWN_JITTER := 24.0
const ELITE_RAM_TRAIL_BASE_DASH_DISTANCE := 130.0
const SKULLTOMB_CHARGE_DISTANCE_MULTIPLIER := 2.0
const SKULLTOMB_CHARGE_DECISION_INTERVAL := 1.0
const SKULLTOMB_CHARGE_DECISION_CHANCE := 0.5
const SKULLTOMB_CHARGE_WARNING_ALPHA := 0.3
const SKULLTOMB_CHARGE_WARNING_FILL_ALPHA := 0.6
const SUMMON_AREA_MARKER_SEGMENTS := 24
const DEATH_RING_SEGMENT_COUNT := 36

static var death_ring_unit_points: PackedVector2Array = PackedVector2Array()


static func update(enemy, delta: float) -> void:
	if enemy.rebirth_timer > 0.0:
		_update_rebirth(enemy, delta)
		return
	_update_aging_aura(enemy, delta)
	_update_summon_area(enemy, delta)
	_update_pending_spawns(enemy, delta)
	_update_charge(enemy, delta)
	_update_summon_channel(enemy, delta)

static func _update_aging_aura(enemy, delta: float) -> void:
	if delta <= 0.0:
		return
	if enemy.target == null or not is_instance_valid(enemy.target) or enemy.target is not Node2D:
		enemy.skulltomb_aging_aura_elapsed = 0.0
		return
	if bool(enemy.target.get("is_dead")):
		enemy.skulltomb_aging_aura_elapsed = 0.0
		return
	if enemy.target.has_method("_is_status_immune") and enemy.target._is_status_immune():
		enemy.skulltomb_aging_aura_elapsed = 0.0
		return
	var target_node := enemy.target as Node2D
	if enemy.global_position.distance_squared_to(target_node.global_position) > AGING_AURA_RADIUS * AGING_AURA_RADIUS:
		enemy.skulltomb_aging_aura_elapsed = 0.0
		return
	if enemy.target.has_method("apply_aging"):
		enemy.target.apply_aging(AGING_AURA_TICK_INTERVAL + 0.12)
	enemy.skulltomb_aging_aura_elapsed += delta
	while enemy.skulltomb_aging_aura_elapsed >= AGING_AURA_TICK_INTERVAL:
		enemy.skulltomb_aging_aura_elapsed -= AGING_AURA_TICK_INTERVAL
		_apply_aging_aura_tick(enemy)


static func _apply_aging_aura_tick(enemy) -> void:
	if enemy.target == null or not is_instance_valid(enemy.target):
		return
	var current_health: float = max(0.0, float(enemy.target.get("current_health")))
	if current_health <= 1.0:
		return
	var next_health: float = max(1.0, current_health * (1.0 - AGING_AURA_CURRENT_HEALTH_DRAIN_RATIO))
	if is_equal_approx(next_health, current_health):
		return
	enemy.target.set("current_health", next_health)
	if enemy.target.has_method("_save_active_role_health"):
		enemy.target._save_active_role_health()
	var target_max_health: float = max(1.0, float(enemy.target.get("max_health")))
	if enemy.target.has_signal("health_changed"):
		enemy.target.health_changed.emit(next_health, target_max_health)
	if enemy.target.has_method("_update_player_health_bar") and enemy.target.has_method("_get_active_role"):
		enemy.target._update_player_health_bar(enemy.target._get_active_role())

static func handle_lethal_damage(enemy) -> bool:
	if enemy.rebirth_lives_remaining <= 0:
		return false
	_clear_summon_area(enemy)
	enemy.rebirth_lives_remaining -= 1
	enemy.current_health = enemy.max_health
	enemy.rebirth_timer = enemy.rebirth_delay
	enemy.velocity = Vector2.ZERO
	enemy.throttled_motion_delta = 0.0
	enemy.motion_refresh_frame = -1
	enemy.separation_refresh_frame = -1
	_hide_profile_visual(enemy)
	_spawn_tomb(enemy)
	_spawn_death_ring(enemy)
	_apply_death_buffs(enemy)
	return true


static func _update_summon_channel(enemy, delta: float) -> void:
	if enemy.skulltomb_charge_windup_remaining > 0.0 or enemy.dash_remaining > 0.0:
		return
	if enemy.skulltomb_summon_windup_remaining > 0.0:
		enemy.skulltomb_summon_windup_remaining = max(0.0, enemy.skulltomb_summon_windup_remaining - delta)
		_update_channel_ring(enemy)
		if enemy.skulltomb_summon_windup_remaining <= 0.0:
			_clear_channel_ring(enemy)
			_finish_summon(enemy)
		return
	enemy.skulltomb_summon_timer -= delta
	if enemy.skulltomb_summon_timer > 0.0:
		return
	enemy.skulltomb_summon_timer += max(0.5, enemy.skulltomb_summon_interval)
	enemy.skulltomb_summon_target_center = _get_death_space_center(enemy)
	enemy.skulltomb_summon_windup_remaining = max(0.15, enemy.skulltomb_summon_windup)
	_update_channel_ring(enemy)


static func _update_charge(enemy, delta: float) -> void:
	if enemy.target == null or not is_instance_valid(enemy.target):
		return
	if enemy.dash_remaining > 0.0:
		_clamp_charge_progress(enemy)
		_clamp_enemy_to_map(enemy)
		_push_enemies_during_charge(enemy)
		return
	if enemy.skulltomb_summon_windup_remaining > 0.0:
		return
	if enemy.skulltomb_charge_windup_remaining > 0.0:
		enemy.skulltomb_charge_windup_remaining = max(0.0, enemy.skulltomb_charge_windup_remaining - delta)
		_update_charge_warning(enemy)
		if enemy.skulltomb_charge_windup_remaining <= 0.0:
			_begin_charge(enemy)
		return
	if enemy.skulltomb_charge_active:
		enemy.skulltomb_charge_active = false
		enemy.skulltomb_charge_timer = max(0.5, float(enemy.skulltomb_charge_interval))
		enemy.skulltomb_charge_decision_timer = SKULLTOMB_CHARGE_DECISION_INTERVAL
		return
	enemy.skulltomb_charge_timer = max(0.0, float(enemy.skulltomb_charge_timer) - delta)
	if enemy.skulltomb_charge_timer > 0.0:
		return
	enemy.skulltomb_charge_decision_timer = max(0.0, float(enemy.skulltomb_charge_decision_timer) - delta)
	if enemy.skulltomb_charge_decision_timer > 0.0:
		return
	enemy.skulltomb_charge_decision_timer = SKULLTOMB_CHARGE_DECISION_INTERVAL
	if not _should_start_charge():
		return
	enemy.skulltomb_charge_active = true
	enemy.skulltomb_charge_windup_remaining = max(0.18, enemy.skulltomb_charge_windup_duration)
	enemy.dash_direction = enemy._cached_direction_to_target if enemy._cached_direction_to_target != Vector2.ZERO else Vector2.RIGHT
	_update_charge_warning(enemy)
static func _update_charge_warning(enemy) -> void:
	if enemy.dash_warning_rect == null or not is_instance_valid(enemy.dash_warning_rect):
		return
	var progress: float = 1.0 - clamp(enemy.skulltomb_charge_windup_remaining / max(0.001, enemy.skulltomb_charge_windup_duration), 0.0, 1.0)
	var target_position: Vector2 = _get_charge_target_position(enemy)
	var dash_length: float = enemy.global_position.distance_to(target_position)
	var dash_width: float = max(24.0, enemy.contact_radius * 0.9)
	enemy.dash_warning_rect.visible = true
	var fill_length: float = max(4.0, dash_length * progress)
	enemy.dash_warning_rect.position = enemy.dash_direction * (fill_length * 0.5)
	enemy.dash_warning_rect.rotation = enemy.dash_direction.angle()
	enemy.dash_warning_rect.polygon = PackedVector2Array([
		Vector2(-fill_length * 0.5, -dash_width * 0.5),
		Vector2(fill_length * 0.5, -dash_width * 0.5),
		Vector2(fill_length * 0.5, dash_width * 0.5),
		Vector2(-fill_length * 0.5, dash_width * 0.5)
	])
	enemy.dash_warning_rect.color = Color(1.0, 0.14, 0.08, lerpf(SKULLTOMB_CHARGE_WARNING_ALPHA, SKULLTOMB_CHARGE_WARNING_FILL_ALPHA, progress))


static func _begin_charge(enemy) -> void:
	var target_position: Vector2 = _get_charge_target_position(enemy)
	enemy.skulltomb_charge_target_position = target_position
	var dash_distance: float = enemy.global_position.distance_to(target_position)
	enemy.dash_speed_multiplier = 5.175 * enemy.skulltomb_charge_speed_multiplier
	var dash_speed_per_second: float = max(0.001, enemy.speed * enemy.dash_speed_multiplier * 0.7)
	enemy.dash_remaining = max(0.12, dash_distance / dash_speed_per_second)
	enemy.dash_duration = enemy.dash_remaining
	enemy.dash_warning_rect.visible = false
	enemy._spawn_dash_trail(enemy.dash_direction, dash_distance)
	_clamp_enemy_to_map(enemy)
	_push_enemies_during_charge(enemy)


static func _get_charge_distance(enemy) -> float:
	var requested_distance: float = float(enemy.skulltomb_charge_distance)
	if requested_distance <= 0.0:
		requested_distance = ELITE_RAM_TRAIL_BASE_DASH_DISTANCE * SKULLTOMB_CHARGE_DISTANCE_MULTIPLIER
	return enemy.global_position.distance_to(_get_charge_target_position(enemy, requested_distance))

static func _get_charge_target_position(enemy, requested_distance: float = -1.0) -> Vector2:
	if requested_distance < 0.0:
		requested_distance = float(enemy.skulltomb_charge_distance)
		if requested_distance <= 0.0:
			requested_distance = ELITE_RAM_TRAIL_BASE_DASH_DISTANCE * SKULLTOMB_CHARGE_DISTANCE_MULTIPLIER
	var scene: Node = _get_current_scene(enemy)
	if scene == null or not scene.has_method("get_map_bounds"):
		return enemy.global_position + enemy.dash_direction * requested_distance
	var bounds_value: Variant = scene.call("get_map_bounds")
	if bounds_value is not Rect2:
		return enemy.global_position + enemy.dash_direction * requested_distance
	var rect: Rect2 = bounds_value as Rect2
	var margin: float = max(enemy.contact_radius, 24.0)
	var safe_rect: Rect2 = rect.grow(-margin)
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return enemy.global_position + enemy.dash_direction * requested_distance
	var target_position: Vector2 = enemy.global_position + enemy.dash_direction * requested_distance
	return Vector2(
		clamp(target_position.x, safe_rect.position.x, safe_rect.position.x + safe_rect.size.x),
		clamp(target_position.y, safe_rect.position.y, safe_rect.position.y + safe_rect.size.y)
	)


static func _clamp_charge_progress(enemy) -> void:
	var target_position: Vector2 = enemy.skulltomb_charge_target_position
	if target_position == Vector2.ZERO:
		return
	var remaining: Vector2 = target_position - enemy.global_position
	if remaining.dot(enemy.dash_direction) <= 0.0 or remaining.length_squared() <= 4.0:
		enemy.global_position = target_position
		enemy.dash_remaining = 0.0


static func _push_enemies_during_charge(enemy) -> void:
	var scene: Node = _get_current_scene(enemy)
	if scene == null:
		return
	var dash_length: float = _get_charge_distance(enemy)
	var half_width: float = max(18.0, enemy.contact_radius * 0.7)
	for other in _get_charge_candidates(scene, enemy, dash_length, half_width):
		if other == null or other == enemy or not is_instance_valid(other) or other is not Node2D:
			continue
		var offset: Vector2 = (other as Node2D).global_position - enemy.global_position
		var forward: float = offset.dot(enemy.dash_direction)
		if forward < 0.0 or forward > dash_length:
			continue
		var lateral: float = abs(offset.dot(enemy.dash_direction.orthogonal()))
		if lateral > half_width:
			continue
		var push_direction: Vector2 = enemy.dash_direction
		(other as Node2D).global_position += push_direction * float(enemy.skulltomb_charge_push_distance)


static func _get_charge_candidates(scene: Node, enemy, dash_length: float, half_width: float) -> Array:
	if scene == null or enemy == null or not is_instance_valid(enemy):
		return []
	var query_radius: float = max(half_width, dash_length * 0.5 + half_width)
	var query_center: Vector2 = enemy.global_position + enemy.dash_direction * (dash_length * 0.5)
	return ENEMY_SPATIAL_GRID.get_neighbors_at(scene, query_center, query_radius)


static func _should_start_charge(random_value: float = -1.0) -> bool:
	var resolved_value: float = randf() if random_value < 0.0 else random_value
	return resolved_value < SKULLTOMB_CHARGE_DECISION_CHANCE

static func _clamp_enemy_to_map(enemy) -> void:
	var scene: Node = _get_current_scene(enemy)
	if scene == null or not scene.has_method("get_map_bounds"):
		return
	var bounds_value: Variant = scene.call("get_map_bounds")
	if bounds_value is not Rect2:
		return
	var rect: Rect2 = bounds_value as Rect2
	var margin: float = max(enemy.contact_radius, 24.0)
	var safe_rect: Rect2 = rect.grow(-margin)
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return
	enemy.global_position = Vector2(
		clamp(enemy.global_position.x, safe_rect.position.x, safe_rect.position.x + safe_rect.size.x),
		clamp(enemy.global_position.y, safe_rect.position.y, safe_rect.position.y + safe_rect.size.y)
	)


static func _finish_summon(enemy) -> void:
	var scene := _get_current_scene(enemy)
	if scene == null:
		return
	_start_summon_area(enemy)
	var soldier_count := _count_skull_soldiers(scene)
	var missing_count: int = max(0, enemy.skulltomb_min_soldiers - soldier_count)
	enemy.skulltomb_pending_spawns.clear()
	enemy.skulltomb_spawn_elapsed = 0.0
	enemy.skulltomb_spawn_vertex_index = 0
	for index in range(missing_count):
		enemy.skulltomb_pending_spawns.append({
			"type": "soldier",
			"index": index
		})
	for index in range(10):
		enemy.skulltomb_pending_spawns.append({
			"type": "shooter",
			"index": index
		})
	_apply_summon_buffs(scene, enemy.skulltomb_buff_duration)
	enemy._spawn_status_burst(SUMMON_COLOR, 38.0 + enemy.scale.x * 8.0)


static func _update_pending_spawns(enemy, delta: float) -> void:
	if enemy.skulltomb_pending_spawns.is_empty():
		return
	var scene := _get_current_scene(enemy)
	if scene == null:
		enemy.skulltomb_pending_spawns.clear()
		return
	enemy.skulltomb_spawn_elapsed += delta
	while enemy.skulltomb_spawn_elapsed >= SKULLTOMB_SUMMON_SPAWN_INTERVAL and not enemy.skulltomb_pending_spawns.is_empty():
		enemy.skulltomb_spawn_elapsed -= SKULLTOMB_SUMMON_SPAWN_INTERVAL
		var spawn_data: Dictionary = enemy.skulltomb_pending_spawns.pop_front()
		var spawn_position: Vector2 = _get_vertex_spawn_position(enemy, enemy.skulltomb_spawn_vertex_index)
		enemy.skulltomb_spawn_vertex_index = posmod(enemy.skulltomb_spawn_vertex_index + 1, 3)
		if str(spawn_data.get("type", "")) == "soldier":
			_spawn_skull_soldier(enemy, scene, int(spawn_data.get("index", 0)), spawn_position)
		else:
			_spawn_skull_shooter(enemy, scene, int(spawn_data.get("index", 0)), spawn_position)


static func _update_rebirth(enemy, delta: float) -> void:
	enemy.rebirth_timer = max(0.0, enemy.rebirth_timer - delta)
	_update_death_ring(enemy)
	if enemy.rebirth_timer > 0.0:
		return
	_clear_tomb(enemy)
	_clear_death_ring(enemy)
	_show_profile_visual(enemy)
	enemy.current_health = enemy.max_health
	enemy._spawn_status_burst(SUMMON_COLOR, 42.0 + enemy.scale.x * 8.0)


static func _apply_summon_buffs(scene: Node, duration: float) -> void:
	for other in _get_runtime_enemies(scene):
		if not _is_skull_soldier(other):
			continue
		other.skull_soldier_speed_multiplier = max(float(other.skull_soldier_speed_multiplier), 2.0)
		other.skull_soldier_speed_timer = max(float(other.skull_soldier_speed_timer), duration)
		other.skull_damage_immune_timer = max(float(other.skull_damage_immune_timer), duration)
		if other.has_method("_spawn_status_burst"):
			other._spawn_status_burst(SUMMON_COLOR, 22.0 + other.scale.x * 4.0)


static func _apply_death_buffs(enemy) -> void:
	var scene := _get_current_scene(enemy)
	if scene == null:
		return
	if enemy.target != null and is_instance_valid(enemy.target) and enemy.target.has_method("apply_enemy_slow"):
		enemy.target.apply_enemy_slow(enemy.skulltomb_death_player_slow_multiplier, enemy.skulltomb_death_player_slow_duration)
	for other in _get_runtime_enemies(scene):
		if _is_skull_soldier(other):
			other.skull_soldier_speed_multiplier = max(float(other.skull_soldier_speed_multiplier), enemy.skulltomb_death_soldier_speed_multiplier)
			other.skull_soldier_speed_timer = max(float(other.skull_soldier_speed_timer), enemy.skulltomb_death_player_slow_duration)
		if _is_skull_shot(other):
			other.skullshot_attack_frequency_multiplier = max(float(other.skullshot_attack_frequency_multiplier), enemy.skulltomb_death_shot_frequency_multiplier)
			other.skullshot_attack_frequency_timer = max(float(other.skullshot_attack_frequency_timer), enemy.skulltomb_death_player_slow_duration)


static func _spawn_skull_soldier(enemy, scene: Node, index: int, spawn_position_override: Variant = null) -> void:
	if scene == null or not scene.has_method("queue_runtime_enemy_spawn"):
		return
	var spawn_position: Vector2 = spawn_position_override if spawn_position_override is Vector2 else _get_summon_position(enemy, index)
	var health_multiplier := _get_scene_health_multiplier(scene)
	var speed_multiplier := _get_scene_speed_multiplier(scene)
	var damage_multiplier := _get_scene_damage_multiplier(scene)
	scene.queue_runtime_enemy_spawn({
		"kind": "normal",
		"archetype": "dasher",
		"health_multiplier": health_multiplier,
		"speed_multiplier": speed_multiplier,
		"damage_multiplier": damage_multiplier,
		"spawn_position": spawn_position,
		"skull_soldier_speed_multiplier": 2.0,
		"skull_soldier_speed_timer": enemy.skulltomb_buff_duration,
		"skull_damage_immune_timer": enemy.skulltomb_buff_duration
	})


static func _spawn_skull_shooter(enemy, scene: Node, index: int, spawn_position_override: Variant = null) -> void:
	if scene == null or not scene.has_method("queue_runtime_enemy_spawn"):
		return
	var spawn_position: Vector2 = spawn_position_override if spawn_position_override is Vector2 else _get_summon_position(enemy, index + 10)
	var health_multiplier := _get_scene_health_multiplier(scene)
	var speed_multiplier := _get_scene_speed_multiplier(scene)
	var damage_multiplier := _get_scene_damage_multiplier(scene)
	scene.queue_runtime_enemy_spawn({
		"kind": "normal",
		"archetype": "shooter",
		"health_multiplier": health_multiplier,
		"speed_multiplier": speed_multiplier,
		"damage_multiplier": damage_multiplier,
		"spawn_position": spawn_position
	})


static func _get_summon_position(enemy, index: int) -> Vector2:
	var angle := randf() * TAU + float(index) * 0.42
	var max_spawn_radius: float = max(48.0, float(enemy.skulltomb_area_radius) - 72.0)
	var distance: float = min(max_spawn_radius, 110.0 + float(index % 8) * 54.0)
	return enemy.skulltomb_area_center + Vector2.RIGHT.rotated(angle) * distance


static func _get_vertex_spawn_position(enemy, vertex_index: int) -> Vector2:
	var vertices: PackedVector2Array = _get_summon_area_global_vertices(enemy)
	if vertices.is_empty():
		return enemy.skulltomb_area_center
	var resolved_index: int = posmod(vertex_index, vertices.size())
	var base_position: Vector2 = vertices[resolved_index]
	var jitter_direction: Vector2 = (enemy.skulltomb_area_center - base_position).normalized()
	if jitter_direction.length_squared() <= 0.001:
		jitter_direction = Vector2.DOWN
	return base_position + jitter_direction * SKULLTOMB_VERTEX_SPAWN_JITTER


static func _start_summon_area(enemy) -> void:
	_clear_summon_area(enemy)
	if enemy.skulltomb_summon_target_center != Vector2.ZERO:
		enemy.skulltomb_area_center = enemy.skulltomb_summon_target_center
	elif enemy.skulltomb_area_center == Vector2.ZERO:
		enemy.skulltomb_area_center = _get_death_space_center(enemy)
	enemy.skulltomb_summon_target_center = Vector2.ZERO
	enemy.skulltomb_area_radius = SUMMON_AREA_RADIUS
	enemy.skulltomb_area_remaining = SUMMON_AREA_DURATION
	enemy.skulltomb_area_damage_elapsed = 0.0
	_spawn_summon_area_visual(enemy)


static func _update_summon_area(enemy, delta: float) -> void:
	if enemy.skulltomb_area_remaining <= 0.0:
		return
	enemy.skulltomb_area_remaining = max(0.0, float(enemy.skulltomb_area_remaining) - delta)
	if enemy.skulltomb_area_remaining <= 0.0:
		_clear_summon_area(enemy)
		return
	if enemy.target == null or not is_instance_valid(enemy.target) or enemy.target is not Node2D:
		return
	var status_duration: float = float(enemy.skulltomb_area_remaining) + 0.12
	if enemy.target.has_method("apply_healing_block"):
		enemy.target.apply_healing_block(status_duration)
	if enemy.target.has_method("apply_confinement"):
		enemy.target.apply_confinement(enemy.skulltomb_area_center, enemy.skulltomb_area_radius, status_duration, _get_summon_area_global_vertices(enemy))

static func _spawn_summon_area_visual(enemy) -> void:
	var scene := _get_current_scene(enemy)
	if scene == null:
		return
	var root := Node2D.new()
	root.name = "SkulltombSummonArea"
	root.global_position = enemy.skulltomb_area_center
	root.z_index = enemy.z_index - 1
	scene.add_child(root)
	enemy.skulltomb_area_instance = root
	var vertices: PackedVector2Array = _build_triangle_vertices(enemy.skulltomb_area_radius)
	var line := Line2D.new()
	line.name = "SkulltombAreaTriangleLine"
	line.closed = true
	line.width = 8.0
	line.default_color = SUMMON_AREA_LINE_COLOR
	line.points = vertices
	line.z_index = 1
	root.add_child(line)
	_add_triangle_collision(root, vertices)
	for index in range(vertices.size()):
		var marker := _instantiate_area_scene()
		if marker == null:
			marker = _create_area_fallback_marker()
		marker.name = "SkulltombAreaVertex%d" % index
		marker.position = vertices[index]
		marker.scale *= Vector2.ONE * SUMMON_AREA_VERTEX_VISUAL_SCALE
		marker.z_index = 2
		root.add_child(marker)
		_play_area_marker_animation(marker)


static func _add_triangle_collision(root: Node2D, vertices: PackedVector2Array) -> void:
	var body := StaticBody2D.new()
	body.name = "SkulltombAreaCollision"
	body.collision_layer = SUMMON_AREA_COLLISION_LAYER
	body.collision_mask = 0
	var collision := CollisionPolygon2D.new()
	collision.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	collision.polygon = vertices
	body.add_child(collision)
	root.add_child(body)


static func _play_area_marker_animation(marker: Node2D) -> void:
	var sprite := marker.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.animation == StringName():
		sprite.animation = &"default"
	if not sprite.is_playing():
		sprite.play()


static func _instantiate_area_scene() -> Node2D:
	for path in AREA_SCENE_PATHS:
		if not ResourceLoader.exists(path, "PackedScene"):
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var node := packed.instantiate() as Node2D
		if node != null:
			return node
	return null


static func _clear_summon_area(enemy) -> void:
	if enemy.skulltomb_area_instance != null and is_instance_valid(enemy.skulltomb_area_instance):
		enemy.skulltomb_area_instance.queue_free()
	enemy.skulltomb_area_instance = null
	enemy.skulltomb_area_remaining = 0.0
	enemy.skulltomb_area_damage_elapsed = 0.0
	enemy.skulltomb_area_radius = 0.0
	enemy.skulltomb_summon_target_center = Vector2.ZERO


static func _build_triangle_vertices(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var start_angle := -PI * 0.5
	for index in range(3):
		points.append(Vector2.RIGHT.rotated(start_angle + TAU * float(index) / 3.0) * radius)
	return points


static func _get_death_space_center(enemy) -> Vector2:
	if enemy.target != null and is_instance_valid(enemy.target) and enemy.target is Node2D:
		return (enemy.target as Node2D).global_position
	return enemy.global_position


static func _get_summon_area_global_vertices(enemy) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in _build_triangle_vertices(enemy.skulltomb_area_radius):
		points.append(enemy.skulltomb_area_center + point)
	return points


static func _create_area_fallback_marker() -> Node2D:
	var marker := Node2D.new()
	var polygon := Polygon2D.new()
	polygon.color = Color(0.14, 0.85, 0.82, 0.32)
	polygon.polygon = ENEMY_GEOMETRY.build_circle_points(42.0, SUMMON_AREA_MARKER_SEGMENTS)
	marker.add_child(polygon)
	return marker


static func _get_scene_health_multiplier(scene: Node) -> float:
	if scene.has_method("_get_spawn_enemy_health_multiplier"):
		return float(scene._get_spawn_enemy_health_multiplier("normal"))
	return 1.0


static func _get_scene_speed_multiplier(scene: Node) -> float:
	if scene.has_method("_get_spawn_enemy_speed_multiplier"):
		return float(scene._get_spawn_enemy_speed_multiplier())
	return 1.0


static func _get_scene_damage_multiplier(scene: Node) -> float:
	if scene.has_method("_get_spawn_enemy_damage_multiplier"):
		return float(scene._get_spawn_enemy_damage_multiplier())
	return 1.0


static func _count_skull_soldiers(scene: Node) -> int:
	var count := 0
	for enemy in _get_runtime_enemies(scene):
		if _is_skull_soldier(enemy):
			count += 1
	return count


static func _is_skull_soldier(enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and str(enemy.get("archetype_id")) in SKULL_SOLDIER_ARCHETYPES


static func _is_skull_shot(enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and str(enemy.get("archetype_id")) in SKULL_SHOT_ARCHETYPES


static func _get_runtime_enemies(scene: Node) -> Array:
	if scene != null and scene.has_method("get_runtime_enemies"):
		return scene.get_runtime_enemies()
	if scene != null and scene.get_tree() != null:
		return scene.get_tree().get_nodes_in_group("enemies")
	return []


static func _spawn_tomb(enemy) -> void:
	_clear_tomb(enemy)
	if enemy.skulltomb_tomb_scene == null:
		return
	var scene := _get_current_scene(enemy)
	if scene == null:
		return
	var tomb := enemy.skulltomb_tomb_scene.instantiate() as Node2D
	if tomb == null:
		return
	tomb.name = "SkulltombTomb"
	tomb.global_position = enemy.global_position
	tomb.z_index = enemy.z_index
	scene.add_child(tomb)
	_ensure_tomb_visual(tomb)
	enemy.skulltomb_tomb_instance = tomb


static func _ensure_tomb_visual(tomb: Node2D) -> void:
	var animated_sprite := tomb.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null:
		if animated_sprite.animation == StringName():
			animated_sprite.animation = &"default"
		animated_sprite.play()
		return
	if tomb.get_child_count() > 0:
		return
	var sprite := Sprite2D.new()
	sprite.name = "TombSprite"
	sprite.texture = TOMB_TEXTURE
	sprite.centered = true
	sprite.scale = Vector2.ONE * 0.72
	tomb.add_child(sprite)


static func _spawn_death_ring(enemy) -> void:
	_clear_death_ring(enemy)
	var scene := _get_current_scene(enemy)
	if scene == null:
		return
	var ring := Line2D.new()
	ring.name = "SkulltombDeathRing"
	ring.closed = true
	ring.width = 5.0
	ring.default_color = Color(0.24, 1.0, 0.92, 0.74)
	ring.global_position = enemy.global_position
	ring.z_index = enemy.z_index + 1
	scene.add_child(ring)
	enemy.skulltomb_death_ring = ring
	_update_circle_points(ring, 20.0)


static func _update_death_ring(enemy) -> void:
	var ring := enemy.skulltomb_death_ring as Line2D
	if ring == null or not is_instance_valid(ring):
		return
	var elapsed: float = float(enemy.rebirth_delay) - float(enemy.rebirth_timer)
	var progress: float = clamp(elapsed / max(0.001, DEATH_RING_DURATION), 0.0, 1.0)
	_update_circle_points(ring, lerpf(20.0, DEATH_RING_TARGET_RADIUS, progress))
	ring.modulate.a = 1.0 - progress


static func _update_channel_ring(enemy) -> void:
	var ring := enemy.skulltomb_channel_ring as Line2D
	if ring == null or not is_instance_valid(ring):
		ring = Line2D.new()
		ring.name = "SkulltombChannelRing"
		ring.closed = true
		ring.width = 6.0
		ring.default_color = DEATH_SPACE_WARNING_COLOR
		ring.z_index = enemy.z_index + 1
		enemy.add_child(ring)
		enemy.skulltomb_channel_ring = ring
	var fill := enemy.skulltomb_channel_fill as Polygon2D
	if fill == null or not is_instance_valid(fill):
		fill = Polygon2D.new()
		fill.name = "SkulltombChannelFill"
		fill.color = DEATH_SPACE_WARNING_FILL_COLOR
		fill.z_index = enemy.z_index
		enemy.add_child(fill)
		enemy.skulltomb_channel_fill = fill
	var progress: float = 1.0 - clamp(float(enemy.skulltomb_summon_windup_remaining) / max(0.001, float(enemy.skulltomb_summon_windup)), 0.0, 1.0)
	var warning_radius: float = lerpf(max(18.0, enemy.contact_radius * 0.45), SUMMON_AREA_RADIUS, progress)
	var vertices: PackedVector2Array = _build_triangle_vertices(warning_radius)
	var center: Vector2 = enemy.skulltomb_summon_target_center if enemy.skulltomb_summon_target_center != Vector2.ZERO else enemy.skulltomb_area_center
	ring.position = enemy.to_local(center)
	ring.points = vertices
	ring.modulate.a = 0.4 + 0.45 * progress
	fill.position = enemy.to_local(center)
	fill.polygon = vertices
	fill.color = Color(DEATH_SPACE_WARNING_FILL_COLOR.r, DEATH_SPACE_WARNING_FILL_COLOR.g, DEATH_SPACE_WARNING_FILL_COLOR.b, 0.12 + 0.14 * progress)


static func _update_circle_points(ring: Line2D, radius: float) -> void:
	var unit_points: PackedVector2Array = _get_death_ring_unit_points()
	var points: PackedVector2Array = ring.points
	if points.size() != unit_points.size():
		points = PackedVector2Array()
		points.resize(unit_points.size())
	for index in range(unit_points.size()):
		points[index] = unit_points[index] * radius
	ring.points = points


static func _get_death_ring_unit_points() -> PackedVector2Array:
	if death_ring_unit_points.size() != DEATH_RING_SEGMENT_COUNT:
		death_ring_unit_points = ENEMY_GEOMETRY.build_circle_points(1.0, DEATH_RING_SEGMENT_COUNT)
	return death_ring_unit_points

static func _hide_profile_visual(enemy) -> void:
	var visual := enemy.get_node_or_null("ProfileVisual") as CanvasItem
	if visual != null:
		visual.hide()
	enemy.modulate.a = 0.0


static func _show_profile_visual(enemy) -> void:
	enemy.modulate.a = 1.0
	var visual := enemy.get_node_or_null("ProfileVisual") as CanvasItem
	if visual != null:
		visual.show()


static func _clear_tomb(enemy) -> void:
	if enemy.skulltomb_tomb_instance != null and is_instance_valid(enemy.skulltomb_tomb_instance):
		enemy.skulltomb_tomb_instance.queue_free()
	enemy.skulltomb_tomb_instance = null


static func _clear_channel_ring(enemy) -> void:
	if enemy.skulltomb_channel_ring != null and is_instance_valid(enemy.skulltomb_channel_ring):
		enemy.skulltomb_channel_ring.queue_free()
	enemy.skulltomb_channel_ring = null
	if enemy.skulltomb_channel_fill != null and is_instance_valid(enemy.skulltomb_channel_fill):
		enemy.skulltomb_channel_fill.queue_free()
	enemy.skulltomb_channel_fill = null


static func _clear_death_ring(enemy) -> void:
	if enemy.skulltomb_death_ring != null and is_instance_valid(enemy.skulltomb_death_ring):
		enemy.skulltomb_death_ring.queue_free()
	enemy.skulltomb_death_ring = null


static func _get_current_scene(enemy) -> Node:
	if enemy == null or not is_instance_valid(enemy):
		return null
	if enemy is Node and not (enemy as Node).is_inside_tree():
		return null
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		return null
	return tree.current_scene

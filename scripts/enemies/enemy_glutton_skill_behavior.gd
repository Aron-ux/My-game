extends RefCounted

const ENEMY_DEATH_EFFECTS := preload("res://scripts/enemies/enemy_death_effects.gd")
const ENEMY_SPATIAL_GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")

const SKILL_NONE := ""
const SKILL_WAR_STOMP := "war_stomp"
const SKILL_DEATH_TWINE := "death_twine"
const SKILL_WOOD_SPIKE := "wood_spike"

const THINK_MIN_INTERVAL := 2.6
const THINK_MAX_INTERVAL := 4.2
const WARNING_DURATION := 0.85
const WAR_STOMP_DURATION := 7.0
const WAR_STOMP_COOLDOWN := 13.0
const WAR_STOMP_CAST_LOCK_DURATION := 2.0
const TREE_ATTACK_CAST_DURATION := 0.62
const WAR_STOMP_CAST_SHAKE_STRENGTH := 7.5
const WAR_STOMP_CAST_SHAKE_DURATION := 0.12
const WAR_STOMP_CAST_SHAKE_INTERVAL := 0.08
const WAR_STOMP_SPEED_MULTIPLIER := 1.15
const WAR_STOMP_DAMAGE_REDUCTION := 0.3
const BASE_GROWTH_MULTIPLIER := 0.6
const WAR_STOMP_GROWTH_MULTIPLIER := 1.5
const WAR_STOMP_HEART_HEAL_RATIO := 0.02
const WAR_STOMP_KILL_HEAL_CHANCE := 0.10
const WAR_STOMP_KILL_HEAL_RATIO := 0.01
const WAR_STOMP_TICK_INTERVAL := 0.20
const WAR_STOMP_MONSTER_EXECUTE_HITS := 6
const WAR_STOMP_PLAYER_SHADOW_RATIO := 0.8
const WAR_STOMP_MONSTER_SHADOW_RATIO := 1.2

const MONSTER_QUERY_PADDING := 96.0
const TWINE_COUNT := 5
const TWINE_RADIUS := 110.0
const TWINE_SAFE_RADIUS := 86.0
const TWINE_SPAWN_MIN_RADIUS := 145.0
const TWINE_SPAWN_MAX_RADIUS := 255.0
const TWINE_MIN_CENTER_DISTANCE := 205.0
const TWINE_CAST_DURATION := 1.25
const TWINE_LOCK_DURATION := 2.0
const TWINE_DAMAGE_TICK_INTERVAL := 1.0
const TWINE_FILL_VISUAL_SCALE := 0.82
const TWINE_FILL_X_SPACING := 38.0
const TWINE_FILL_Y_SPACING := 32.0
const TWINE_FILL_RADIUS_RATIO := 0.88
const WOOD_SPIKE_RADIUS := 61.2
const WOOD_SPIKE_HITBOX_HORIZONTAL_RADIUS := 50.0
const WOOD_SPIKE_HITBOX_VERTICAL_RADIUS := 18.0
const WOOD_SPIKE_HITBOX_Y_OFFSET := 34.0
const WOOD_SPIKE_HITBOX_EXTRA_Y_OFFSET := 40.0
const WOOD_SPIKE_HITBOX_DURATION := 1.0
const WOOD_SPIKE_VISUAL_SCALE := 0.85
const WOOD_SPIKE_COUNT := 10
const WOOD_SPIKE_RANDOM_MIN_RADIUS := 36.0
const WOOD_SPIKE_RANDOM_MAX_RADIUS := 280.0
const WOOD_SPIKE_SAFE_RADIUS := 74.0
const WOOD_SPIKE_MIN_CENTER_DISTANCE := 96.0
const WOOD_SPIKE_MONSTER_KNOCKBACK_DISTANCE := 58.0
const WOOD_SPIKE_MONSTER_DAMAGE_MULTIPLIER := 1.0
const DEFAULT_EFFECT_LIFETIME := 1.0

const WARNING_COLOR := Color(1.0, 0.08, 0.04, 0.28)
const WARNING_OUTLINE_COLOR := Color(1.0, 0.05, 0.02, 0.86)
const STOMP_COLOR := Color(1.0, 0.24, 0.04, 0.18)
const STOMP_OUTLINE_COLOR := Color(1.0, 0.32, 0.02, 0.78)

const STING_SCENE := preload("res://assets/enemies/treeboss/sting.tscn")
const TWINE_SCENE := preload("res://assets/enemies/treeboss/twine.tscn")
const WOOD_SPIKE_OBSTACLE_COLLISION_LAYER := 1 << 6
const SPREAD_POSITION_ATTEMPTS := 48


static func update(enemy, delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	_tick_wood_spike_hitboxes(enemy, delta)
	_tick_war_stomp_cooldown(enemy, delta)
	_tick_war_stomp(enemy, delta)
	_tick_cast_state(enemy, delta)
	if enemy.glutton_skill_state != SKILL_NONE:
		return
	if is_war_stomp_active(enemy):
		return
	enemy.glutton_skill_think_timer -= delta
	if enemy.glutton_skill_think_timer > 0.0:
		return
	enemy.glutton_skill_think_timer = randf_range(THINK_MIN_INTERVAL, THINK_MAX_INTERVAL)
	_start_next_skill(enemy)


static func is_war_stomp_active(enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and float(enemy.glutton_war_stomp_remaining) > 0.0


static func get_war_stomp_speed_multiplier(enemy) -> float:
	return WAR_STOMP_SPEED_MULTIPLIER if is_war_stomp_active(enemy) else 1.0


static func get_war_stomp_duration() -> float:
	return WAR_STOMP_DURATION


static func should_hold_position_for_cast(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if float(enemy.glutton_war_stomp_cast_lock_remaining) > 0.0:
		return true
	if is_war_stomp_active(enemy):
		return false
	return str(enemy.glutton_skill_state) != SKILL_NONE


static func enforce_cast_position_lock(enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not bool(enemy.glutton_cast_lock_active):
		return
	enemy.global_position = enemy.glutton_cast_lock_position
	enemy.velocity = Vector2.ZERO


static func get_damage_taken_multiplier(enemy) -> float:
	return 1.0 - WAR_STOMP_DAMAGE_REDUCTION if is_war_stomp_active(enemy) else 1.0


static func get_growth_multiplier(enemy) -> float:
	var base_multiplier: float = BASE_GROWTH_MULTIPLIER
	if is_war_stomp_active(enemy):
		return base_multiplier * WAR_STOMP_GROWTH_MULTIPLIER
	return base_multiplier


static func get_heart_heal_amount(enemy, collected_heal_amount: float) -> float:
	if is_war_stomp_active(enemy):
		return max(0.0, float(enemy.max_health)) * WAR_STOMP_HEART_HEAL_RATIO
	return collected_heal_amount * max(0.0, float(enemy.glutton_heart_heal_scale))


static func get_player_touch_shape(enemy) -> Dictionary:
	if not is_war_stomp_active(enemy):
		return {}
	if not _has_active_stomp_indicator(enemy):
		return {}
	return _get_scaled_shadow_shape(enemy, WAR_STOMP_PLAYER_SHADOW_RATIO)


static func get_debug_stomp_shape(enemy) -> Dictionary:
	if not is_war_stomp_active(enemy):
		return {}
	return _get_scaled_shadow_shape(enemy, WAR_STOMP_MONSTER_SHADOW_RATIO)


static func reset(enemy) -> void:
	_clear_warnings(enemy)
	_clear_wood_spike_hitboxes(enemy)
	enemy.glutton_skill_state = SKILL_NONE
	enemy.glutton_skill_state_remaining = 0.0
	enemy.glutton_skill_action = ""
	enemy.glutton_skill_action_remaining = 0.0
	enemy.glutton_skill_think_timer = randf_range(THINK_MIN_INTERVAL, THINK_MAX_INTERVAL)
	enemy.glutton_cast_lock_active = false
	enemy.glutton_cast_lock_position = Vector2.ZERO
	enemy.glutton_recent_skill = ""
	enemy.glutton_war_stomp_remaining = 0.0
	enemy.glutton_war_stomp_cast_lock_remaining = 0.0
	enemy.glutton_war_stomp_cooldown_remaining = 0.0
	enemy.glutton_war_stomp_cast_shake_elapsed = 0.0
	enemy.glutton_war_stomp_tick_elapsed = 0.0
	enemy.glutton_war_stomp_hit_registry.clear()
	enemy.glutton_growth_carry = 0.0
	enemy.glutton_entangle_damage_remaining = 0.0
	enemy.glutton_entangle_damage_elapsed = 0.0


static func force_start_skill(enemy, skill_id: String) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	_clear_warnings(enemy)
	enemy.glutton_skill_state = SKILL_NONE
	enemy.glutton_skill_action = ""
	enemy.glutton_skill_warning_shapes = []
	enemy.glutton_cast_lock_active = false
	enemy.glutton_cast_lock_position = Vector2.ZERO
	enemy.glutton_war_stomp_remaining = 0.0
	enemy.glutton_war_stomp_cast_lock_remaining = 0.0
	enemy.glutton_war_stomp_cooldown_remaining = 0.0
	enemy.glutton_war_stomp_cast_shake_elapsed = 0.0
	enemy.glutton_war_stomp_hit_registry.clear()
	_clear_wood_spike_hitboxes(enemy)
	match skill_id:
		SKILL_WAR_STOMP:
			_start_war_stomp(enemy)
		SKILL_DEATH_TWINE:
			_start_death_twine(enemy)
		SKILL_WOOD_SPIKE:
			_start_wood_spike(enemy)
		_:
			return false
	return true


static func _start_next_skill(enemy) -> void:
	var skill_id: String = _choose_skill(enemy)
	match skill_id:
		SKILL_WAR_STOMP:
			_start_war_stomp(enemy)
		SKILL_DEATH_TWINE:
			_start_death_twine(enemy)
		SKILL_WOOD_SPIKE:
			_start_wood_spike(enemy)


static func _choose_skill(enemy) -> String:
	var target_distance: float = 9999.0
	if enemy.target != null and is_instance_valid(enemy.target):
		target_distance = enemy.global_position.distance_to(enemy.target.global_position)
	var nearby_enemies: int = _count_damageable_enemies(enemy, 220.0)
	var weights: Dictionary = {
		SKILL_WAR_STOMP: 1.0,
		SKILL_DEATH_TWINE: 1.0,
		SKILL_WOOD_SPIKE: 1.0
	}
	if target_distance < 150.0:
		weights[SKILL_WAR_STOMP] += 1.5
	elif target_distance > 300.0:
		weights[SKILL_DEATH_TWINE] += 1.5
		weights[SKILL_WOOD_SPIKE] += 2.0
	if nearby_enemies >= 6:
		weights[SKILL_WAR_STOMP] += 2.5
	var health_ratio: float = float(enemy.current_health) / max(1.0, float(enemy.max_health))
	if health_ratio < 0.45:
		weights[SKILL_WAR_STOMP] += 1.0
		weights[SKILL_WOOD_SPIKE] += 1.0
	if enemy.glutton_recent_skill != "":
		weights[enemy.glutton_recent_skill] = max(0.25, float(weights.get(enemy.glutton_recent_skill, 1.0)) * 0.25)
	if _is_war_stomp_on_cooldown(enemy):
		weights[SKILL_WAR_STOMP] = 0.0
	var total: float = 0.0
	for value in weights.values():
		total += float(value)
	var roll: float = randf() * max(0.001, total)
	for key in weights.keys():
		roll -= float(weights[key])
		if roll <= 0.0:
			return str(key)
	return SKILL_DEATH_TWINE


static func _start_war_stomp(enemy) -> void:
	enemy.glutton_recent_skill = SKILL_WAR_STOMP
	enemy.glutton_war_stomp_remaining = WAR_STOMP_DURATION
	enemy.glutton_war_stomp_cast_lock_remaining = WAR_STOMP_CAST_LOCK_DURATION
	enemy.glutton_war_stomp_cast_shake_elapsed = WAR_STOMP_CAST_SHAKE_INTERVAL
	enemy.glutton_war_stomp_tick_elapsed = WAR_STOMP_TICK_INTERVAL
	enemy.glutton_war_stomp_hit_registry.clear()
	_play_tree_attack(enemy, WAR_STOMP_CAST_LOCK_DURATION)
	_spawn_stomp_indicator(enemy)
	enemy._spawn_status_burst(Color(1.0, 0.38, 0.08, 0.24), _get_shadow_max_radius(enemy) * WAR_STOMP_MONSTER_SHADOW_RATIO)


static func _start_death_twine(enemy) -> void:
	if enemy.target == null or not is_instance_valid(enemy.target):
		return
	var shapes: Array = []
	for center in _get_spread_positions_near_target(
		enemy,
		TWINE_COUNT,
		TWINE_SPAWN_MIN_RADIUS,
		TWINE_SPAWN_MAX_RADIUS,
		TWINE_SAFE_RADIUS,
		TWINE_MIN_CENTER_DISTANCE
	):
		shapes.append({
			"center": center,
			"horizontal_radius": TWINE_RADIUS,
			"vertical_radius": TWINE_RADIUS
		})
	_start_warning_cast(enemy, SKILL_DEATH_TWINE, shapes, TWINE_CAST_DURATION)


static func _start_wood_spike(enemy) -> void:
	var shapes: Array = []
	for center in _get_spread_positions_near_target(
		enemy,
		WOOD_SPIKE_COUNT,
		WOOD_SPIKE_RANDOM_MIN_RADIUS,
		WOOD_SPIKE_RANDOM_MAX_RADIUS,
		WOOD_SPIKE_SAFE_RADIUS,
		WOOD_SPIKE_MIN_CENTER_DISTANCE
	):
		shapes.append({
			"center": center,
			"horizontal_radius": WOOD_SPIKE_RADIUS,
			"vertical_radius": WOOD_SPIKE_RADIUS
		})
	_start_warning_cast(enemy, SKILL_WOOD_SPIKE, shapes)


static func _start_warning_cast(enemy, skill_id: String, shapes: Array, cast_duration: float = TREE_ATTACK_CAST_DURATION) -> void:
	enemy.glutton_skill_state = skill_id
	enemy.glutton_skill_state_remaining = cast_duration
	enemy.glutton_skill_action = "warning"
	enemy.glutton_skill_action_remaining = cast_duration
	enemy.glutton_skill_warning_shapes = shapes.duplicate(true)
	enemy.glutton_cast_lock_active = true
	enemy.glutton_cast_lock_position = enemy.global_position
	enemy.glutton_recent_skill = skill_id
	_clear_warnings(enemy)
	for shape in shapes:
		enemy.glutton_warning_nodes.append(_spawn_warning_ellipse(enemy, shape, cast_duration))
	_play_tree_attack(enemy, cast_duration)


static func _tick_cast_state(enemy, delta: float) -> void:
	if enemy.glutton_skill_state == SKILL_NONE:
		_tick_entangle_damage(enemy, delta)
		return
	enemy.glutton_skill_state_remaining = max(0.0, float(enemy.glutton_skill_state_remaining) - delta)
	enemy.glutton_skill_action_remaining = max(0.0, float(enemy.glutton_skill_action_remaining) - delta)
	if enemy.glutton_skill_action == "warning" and enemy.glutton_skill_action_remaining <= 0.0:
		enemy.glutton_skill_action = "resolved"
		_resolve_skill_impact(enemy, str(enemy.glutton_skill_state), enemy.glutton_skill_warning_shapes)
	if enemy.glutton_skill_state_remaining <= 0.0:
		_clear_warnings(enemy)
		enemy.glutton_skill_state = SKILL_NONE
		enemy.glutton_skill_action = ""
		enemy.glutton_skill_warning_shapes = []
		enemy.glutton_cast_lock_active = false
	_tick_entangle_damage(enemy, delta)


static func _tick_war_stomp(enemy, delta: float) -> void:
	if enemy.glutton_war_stomp_remaining <= 0.0:
		return
	if enemy.glutton_war_stomp_cast_lock_remaining > 0.0:
		enemy.glutton_war_stomp_cast_lock_remaining = max(0.0, float(enemy.glutton_war_stomp_cast_lock_remaining) - delta)
		_tick_war_stomp_cast_shake(enemy, delta)
		_update_stomp_indicator(enemy)
		return
	_update_stomp_indicator(enemy)
	enemy.glutton_war_stomp_remaining = max(0.0, float(enemy.glutton_war_stomp_remaining) - delta)
	enemy.glutton_war_stomp_tick_elapsed += delta
	if enemy.glutton_war_stomp_tick_elapsed >= WAR_STOMP_TICK_INTERVAL:
		enemy.glutton_war_stomp_tick_elapsed = 0.0
		_resolve_war_stomp_tick(enemy)
	if enemy.glutton_war_stomp_remaining <= 0.0:
		enemy.glutton_war_stomp_hit_registry.clear()
		enemy.glutton_war_stomp_cast_shake_elapsed = 0.0
		enemy.glutton_war_stomp_cooldown_remaining = WAR_STOMP_COOLDOWN
		_clear_warnings(enemy)


static func _tick_war_stomp_cooldown(enemy, delta: float) -> void:
	if enemy.glutton_war_stomp_cooldown_remaining <= 0.0:
		return
	enemy.glutton_war_stomp_cooldown_remaining = max(0.0, float(enemy.glutton_war_stomp_cooldown_remaining) - delta)


static func _is_war_stomp_on_cooldown(enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and float(enemy.glutton_war_stomp_cooldown_remaining) > 0.0


static func _tick_war_stomp_cast_shake(enemy, delta: float) -> void:
	enemy.glutton_war_stomp_cast_shake_elapsed += delta
	while enemy.glutton_war_stomp_cast_shake_elapsed >= WAR_STOMP_CAST_SHAKE_INTERVAL:
		enemy.glutton_war_stomp_cast_shake_elapsed -= WAR_STOMP_CAST_SHAKE_INTERVAL
		_queue_target_camera_shake(enemy, WAR_STOMP_CAST_SHAKE_STRENGTH, WAR_STOMP_CAST_SHAKE_DURATION)


static func _resolve_skill_impact(enemy, skill_id: String, shapes: Array) -> void:
	match skill_id:
		SKILL_DEATH_TWINE:
			for shape in shapes:
				_spawn_twine_circle(enemy, shape)
				if _damage_player_in_shape(enemy, shape, 0.0, true):
					enemy.glutton_entangle_damage_remaining = TWINE_LOCK_DURATION
					enemy.glutton_entangle_damage_elapsed = 0.0
		SKILL_WOOD_SPIKE:
			for shape in shapes:
				_spawn_wood_spike(enemy, shape)


static func _resolve_war_stomp_tick(enemy) -> void:
	_ensure_stomp_indicator(enemy)
	var shape: Dictionary = _get_scaled_shadow_shape(enemy, WAR_STOMP_MONSTER_SHADOW_RATIO)
	_kill_or_damage_monsters_for_stomp(enemy, shape)
	_damage_player_in_shape(enemy, _get_scaled_shadow_shape(enemy, WAR_STOMP_PLAYER_SHADOW_RATIO), float(enemy.touch_damage), false)


static func _kill_or_damage_monsters_for_stomp(enemy, shape: Dictionary) -> void:
	var query_radius: float = max(float(shape.get("horizontal_radius", 0.0)), float(shape.get("vertical_radius", 0.0))) + MONSTER_QUERY_PADDING
	for other in ENEMY_SPATIAL_GRID.get_neighbors(enemy, query_radius):
		if not _can_damage_enemy(enemy, other):
			continue
		if not _is_inside_ellipse(other.global_position, shape):
			continue
		var other_id: int = other.get_instance_id()
		var hit_count: int = int(enemy.glutton_war_stomp_hit_registry.get(other_id, 0)) + 1
		enemy.glutton_war_stomp_hit_registry[other_id] = hit_count
		var damage: float = float(enemy.glutton_aura_damage)
		if hit_count >= WAR_STOMP_MONSTER_EXECUTE_HITS:
			damage = _get_execute_damage(other, damage)
		var will_kill: bool = _will_kill_enemy(other, damage)
		if will_kill:
			ENEMY_DEATH_EFFECTS.spawn_glutton_squash(other)
		other.set("drop_absorber", enemy)
		other.take_damage(damage)
		if is_instance_valid(other):
			other.set("drop_absorber", null)
		if will_kill and randf() <= WAR_STOMP_KILL_HEAL_CHANCE:
			_heal_enemy(enemy, float(enemy.max_health) * WAR_STOMP_KILL_HEAL_RATIO)


static func _damage_player_in_shape(enemy, shape: Dictionary, damage: float, lock_player: bool) -> bool:
	if enemy.target == null or not is_instance_valid(enemy.target) or not (enemy.target is Node2D):
		return false
	var target_node: Node2D = enemy.target
	if not _is_inside_ellipse(target_node.global_position, shape):
		return false
	if lock_player and enemy.target.has_method("_lock_player_actions"):
		enemy.target._lock_player_actions(TWINE_LOCK_DURATION)
		if enemy.target.has_method("_start_entangled_status"):
			enemy.target._start_entangled_status(TWINE_LOCK_DURATION)
	if enemy.target.has_method("take_damage"):
		enemy.target.take_damage(damage)
	return true


static func _tick_entangle_damage(enemy, delta: float) -> void:
	if enemy.glutton_entangle_damage_remaining <= 0.0:
		return
	enemy.glutton_entangle_damage_remaining = max(0.0, float(enemy.glutton_entangle_damage_remaining) - delta)
	enemy.glutton_entangle_damage_elapsed += delta
	while enemy.glutton_entangle_damage_elapsed >= TWINE_DAMAGE_TICK_INTERVAL:
		enemy.glutton_entangle_damage_elapsed -= TWINE_DAMAGE_TICK_INTERVAL
		if enemy.target != null and is_instance_valid(enemy.target) and enemy.target.has_method("take_damage"):
			enemy.target.take_damage(float(enemy.touch_damage) * 0.5)


static func _spawn_wood_spike(enemy, shape: Dictionary) -> void:
	var center: Vector2 = shape.get("center", enemy.global_position)
	var hitbox_shape: Dictionary = _get_wood_spike_bottom_hitbox(center)
	var spike_effect: Node2D = _spawn_scene_effect(enemy, STING_SCENE, center, Vector2.ONE * WOOD_SPIKE_VISUAL_SCALE, max(WOOD_SPIKE_HITBOX_DURATION, _get_scene_animation_lifetime(STING_SCENE, "sting")))
	if spike_effect != null:
		spike_effect.z_index = _get_wood_spike_z_index(enemy, center)
	var blocker: StaticBody2D = _spawn_wood_spike_blocker(enemy, hitbox_shape)
	enemy.glutton_active_wood_spike_hitboxes.append({
		"shape": hitbox_shape,
		"remaining": WOOD_SPIKE_HITBOX_DURATION,
		"hit_player": false,
		"blocker": blocker
	})
	_affect_monsters_with_wood_spike(enemy, hitbox_shape)
	_resolve_wood_spike_hitbox(enemy, enemy.glutton_active_wood_spike_hitboxes.size() - 1)


static func _tick_wood_spike_hitboxes(enemy, delta: float) -> void:
	if enemy.glutton_active_wood_spike_hitboxes.is_empty():
		return
	var next_hitboxes: Array = []
	for index in range(enemy.glutton_active_wood_spike_hitboxes.size()):
		var hitbox: Dictionary = enemy.glutton_active_wood_spike_hitboxes[index]
		hitbox["remaining"] = max(0.0, float(hitbox.get("remaining", 0.0)) - delta)
		if float(hitbox.get("remaining", 0.0)) <= 0.0:
			_free_hitbox_blocker(hitbox)
			continue
		next_hitboxes.append(hitbox)
	enemy.glutton_active_wood_spike_hitboxes = next_hitboxes
	for index in range(enemy.glutton_active_wood_spike_hitboxes.size()):
		_resolve_wood_spike_hitbox(enemy, index)


static func _resolve_wood_spike_hitbox(enemy, hitbox_index: int) -> void:
	if hitbox_index < 0 or hitbox_index >= enemy.glutton_active_wood_spike_hitboxes.size():
		return
	var hitbox: Dictionary = enemy.glutton_active_wood_spike_hitboxes[hitbox_index]
	if bool(hitbox.get("hit_player", false)):
		return
	var shape: Dictionary = hitbox.get("shape", {})
	if _damage_player_in_shape(enemy, shape, float(enemy.touch_damage), false):
		hitbox["hit_player"] = true
		enemy.glutton_active_wood_spike_hitboxes[hitbox_index] = hitbox


static func get_active_wood_spike_hitboxes(enemy) -> Array:
	if enemy == null or not is_instance_valid(enemy):
		return []
	var shapes: Array = []
	for hitbox in enemy.glutton_active_wood_spike_hitboxes:
		if hitbox is not Dictionary:
			continue
		var shape: Dictionary = hitbox.get("shape", {})
		if not shape.is_empty():
			shapes.append(shape)
	return shapes


static func _get_wood_spike_bottom_hitbox(center: Vector2) -> Dictionary:
	return {
		"center": center + Vector2(0.0, WOOD_SPIKE_HITBOX_Y_OFFSET * WOOD_SPIKE_VISUAL_SCALE + WOOD_SPIKE_HITBOX_EXTRA_Y_OFFSET),
		"horizontal_radius": WOOD_SPIKE_HITBOX_HORIZONTAL_RADIUS * WOOD_SPIKE_VISUAL_SCALE,
		"vertical_radius": WOOD_SPIKE_HITBOX_VERTICAL_RADIUS * WOOD_SPIKE_VISUAL_SCALE
	}


static func _get_wood_spike_z_index(enemy, center: Vector2) -> int:
	if center.y < enemy.global_position.y:
		return 0
	return 8


static func _affect_monsters_with_wood_spike(enemy, shape: Dictionary) -> void:
	var query_radius: float = max(float(shape.get("horizontal_radius", 0.0)), float(shape.get("vertical_radius", 0.0))) + MONSTER_QUERY_PADDING
	var center: Vector2 = shape.get("center", enemy.global_position)
	for other in ENEMY_SPATIAL_GRID.get_neighbors(enemy, query_radius):
		if not _can_damage_enemy(enemy, other):
			continue
		if not _is_inside_ellipse(other.global_position, shape):
			continue
		var knockback_direction: Vector2 = other.global_position - center
		if knockback_direction.length_squared() <= 0.001:
			knockback_direction = Vector2.RIGHT.rotated(randf() * TAU)
		other.global_position += knockback_direction.normalized() * WOOD_SPIKE_MONSTER_KNOCKBACK_DISTANCE
		other.take_damage(float(enemy.touch_damage) * WOOD_SPIKE_MONSTER_DAMAGE_MULTIPLIER)


static func _spawn_wood_spike_blocker(enemy, shape: Dictionary) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "WoodSpikeBlocker"
	body.global_position = shape.get("center", enemy.global_position)
	body.collision_layer = WOOD_SPIKE_OBSTACLE_COLLISION_LAYER
	body.collision_mask = 0
	var collision: CollisionPolygon2D = CollisionPolygon2D.new()
	collision.polygon = _build_ellipse_points(
		float(shape.get("horizontal_radius", 1.0)),
		float(shape.get("vertical_radius", 1.0)),
		32
	)
	body.add_child(collision)
	_add_to_scene(enemy, body)
	_fade_and_free(body, WOOD_SPIKE_HITBOX_DURATION)
	return body


static func _clear_wood_spike_hitboxes(enemy) -> void:
	for hitbox in enemy.glutton_active_wood_spike_hitboxes:
		if hitbox is Dictionary:
			_free_hitbox_blocker(hitbox)
	enemy.glutton_active_wood_spike_hitboxes.clear()


static func _free_hitbox_blocker(hitbox: Dictionary) -> void:
	var blocker: Variant = hitbox.get("blocker", null)
	if blocker != null and is_instance_valid(blocker) and blocker is Node:
		(blocker as Node).queue_free()


static func _count_damageable_enemies(enemy, radius: float) -> int:
	var count: int = 0
	for other in ENEMY_SPATIAL_GRID.get_neighbors(enemy, radius):
		if _can_damage_enemy(enemy, other):
			count += 1
	return count


static func _can_damage_enemy(source, target) -> bool:
	if target == null or target == source or not is_instance_valid(target) or target is not Node2D:
		return false
	if target is Node and (target as Node).is_queued_for_deletion():
		return false
	var kind: String = str(target.get("enemy_kind"))
	if kind != "normal" and kind != "elite":
		return false
	return target.has_method("take_damage")


static func _get_scaled_shadow_shape(enemy, ratio: float) -> Dictionary:
	var shadow: Dictionary = _get_shadow_world_ellipse(enemy)
	if shadow.is_empty():
		var fallback_radius: float = max(1.0, float(enemy.contact_radius))
		return {
			"center": enemy.global_position,
			"horizontal_radius": fallback_radius * ratio,
			"vertical_radius": fallback_radius * ratio
		}
	return {
		"center": shadow.get("center", enemy.global_position),
		"horizontal_radius": float(shadow.get("horizontal_radius", 0.0)) * ratio,
		"vertical_radius": float(shadow.get("vertical_radius", 0.0)) * ratio
	}


static func _scale_shape(shape: Dictionary, ratio: float) -> Dictionary:
	return {
		"center": shape.get("center", Vector2.ZERO),
		"horizontal_radius": float(shape.get("horizontal_radius", 0.0)) * ratio,
		"vertical_radius": float(shape.get("vertical_radius", 0.0)) * ratio
	}


static func _get_shadow_world_ellipse(enemy) -> Dictionary:
	var visual: Node = enemy.get_node_or_null("ProfileVisual")
	if visual != null and visual.has_method("get_shadow_world_ellipse"):
		var ellipse: Variant = visual.call("get_shadow_world_ellipse")
		if ellipse is Dictionary and not (ellipse as Dictionary).is_empty():
			return ellipse
	return {}


static func _get_shadow_max_radius(enemy) -> float:
	var shape: Dictionary = _get_scaled_shadow_shape(enemy, 1.0)
	return max(float(shape.get("horizontal_radius", 0.0)), float(shape.get("vertical_radius", 0.0)))


static func _is_inside_ellipse(point: Vector2, shape: Dictionary) -> bool:
	if shape.is_empty():
		return false
	var center: Vector2 = shape.get("center", Vector2.ZERO)
	var horizontal_radius: float = max(1.0, float(shape.get("horizontal_radius", 0.0)))
	var vertical_radius: float = max(1.0, float(shape.get("vertical_radius", 0.0)))
	var relative: Vector2 = point - center
	return pow(relative.x / horizontal_radius, 2.0) + pow(relative.y / vertical_radius, 2.0) <= 1.0


static func _get_execute_damage(target, minimum_damage: float) -> float:
	var current_health: float = max(0.0, float(target.get("current_health")))
	var vulnerability_bonus: float = max(0.0, float(target.get("vulnerability_bonus")))
	return max(minimum_damage, (current_health + 1.0) / max(0.01, 1.0 + vulnerability_bonus))


static func _will_kill_enemy(target, raw_damage: float) -> bool:
	return float(target.get("current_health")) <= raw_damage * (1.0 + float(target.get("vulnerability_bonus")))


static func _heal_enemy(enemy, amount: float) -> void:
	if amount <= 0.0:
		return
	enemy.current_health = min(float(enemy.max_health), float(enemy.current_health) + amount)
	enemy._spawn_status_burst(Color(1.0, 0.36, 0.48, 0.16), 24.0 + enemy.scale.x * 5.0)


static func _play_tree_attack(enemy, duration: float = TREE_ATTACK_CAST_DURATION) -> void:
	var visual: Node = enemy.get_node_or_null("ProfileVisual")
	if visual != null and visual.has_method("play_attack"):
		visual.call("play_attack", duration)


static func _queue_target_camera_shake(enemy, strength: float, duration: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.target == null or not is_instance_valid(enemy.target):
		return
	if enemy.target.has_method("_queue_camera_shake"):
		enemy.target._queue_camera_shake(strength, duration)


static func _spawn_warning_ellipse(enemy, shape: Dictionary, duration: float) -> Node2D:
	var root: Node2D = Node2D.new()
	root.name = "GluttonWarning"
	root.global_position = shape.get("center", enemy.global_position)
	root.z_index = 6
	var fill: Polygon2D = Polygon2D.new()
	fill.color = WARNING_COLOR
	fill.polygon = _build_ellipse_points(float(shape.get("horizontal_radius", 1.0)), float(shape.get("vertical_radius", 1.0)), 48)
	root.add_child(fill)
	var line: Line2D = Line2D.new()
	line.default_color = WARNING_OUTLINE_COLOR
	line.width = 4.0
	line.closed = true
	line.points = _build_ellipse_points(float(shape.get("horizontal_radius", 1.0)), float(shape.get("vertical_radius", 1.0)), 48)
	root.add_child(line)
	_add_to_scene(enemy, root)
	_fade_and_free(root, duration + 0.12)
	return root


static func _spawn_stomp_indicator(enemy) -> void:
	if _has_active_stomp_indicator(enemy):
		return
	var shape: Dictionary = _get_scaled_shadow_shape(enemy, WAR_STOMP_MONSTER_SHADOW_RATIO)
	var root: Node2D = Node2D.new()
	root.name = "GluttonWarStompRange"
	root.global_position = shape.get("center", enemy.global_position)
	root.z_index = 0
	root.set_meta("follow_glutton", enemy.get_instance_id())
	var fill: Polygon2D = Polygon2D.new()
	fill.color = STOMP_COLOR
	fill.polygon = _build_ellipse_points(float(shape.get("horizontal_radius", 1.0)), float(shape.get("vertical_radius", 1.0)), 48)
	root.add_child(fill)
	var line: Line2D = Line2D.new()
	line.default_color = STOMP_OUTLINE_COLOR
	line.width = 5.0
	line.closed = true
	line.points = _build_ellipse_points(float(shape.get("horizontal_radius", 1.0)), float(shape.get("vertical_radius", 1.0)), 48)
	root.add_child(line)
	_add_to_scene(enemy, root)
	enemy.glutton_warning_nodes.append(root)
	_fade_and_free(root, WAR_STOMP_CAST_LOCK_DURATION + WAR_STOMP_DURATION + 0.25)


static func _update_stomp_indicator(enemy) -> void:
	_ensure_stomp_indicator(enemy)
	var shape: Dictionary = _get_scaled_shadow_shape(enemy, WAR_STOMP_MONSTER_SHADOW_RATIO)
	var points: PackedVector2Array = _build_ellipse_points(float(shape.get("horizontal_radius", 1.0)), float(shape.get("vertical_radius", 1.0)), 48)
	for node in enemy.glutton_warning_nodes:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		if str(node.name) != "GluttonWarStompRange":
			continue
		(node as Node2D).global_position = shape.get("center", enemy.global_position)
		for child in node.get_children():
			if child is Polygon2D:
				(child as Polygon2D).polygon = points
			elif child is Line2D:
				(child as Line2D).points = points


static func _ensure_stomp_indicator(enemy) -> void:
	if not is_war_stomp_active(enemy):
		return
	if _has_active_stomp_indicator(enemy):
		return
	_spawn_stomp_indicator(enemy)


static func _has_active_stomp_indicator(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	for node in enemy.glutton_warning_nodes:
		if is_instance_valid(node) and node is Node2D and str(node.name) == "GluttonWarStompRange":
			return true
	return false


static func _spawn_twine_circle(enemy, shape: Dictionary) -> void:
	var center: Vector2 = shape.get("center", enemy.global_position)
	var horizontal_radius: float = float(shape.get("horizontal_radius", TWINE_RADIUS))
	var vertical_radius: float = float(shape.get("vertical_radius", horizontal_radius))
	var fill_horizontal: float = horizontal_radius * TWINE_FILL_RADIUS_RATIO
	var fill_vertical: float = vertical_radius * TWINE_FILL_RADIUS_RATIO
	var row_count: int = int(floor(fill_vertical * 2.0 / TWINE_FILL_Y_SPACING)) + 1
	var first_y: float = -float(row_count - 1) * TWINE_FILL_Y_SPACING * 0.5
	for row_index in range(row_count):
		var y: float = first_y + float(row_index) * TWINE_FILL_Y_SPACING
		var normalized_y: float = y / max(1.0, fill_vertical)
		if abs(normalized_y) > 1.0:
			continue
		var row_half_width: float = fill_horizontal * sqrt(max(0.0, 1.0 - normalized_y * normalized_y))
		var column_count: int = max(1, int(floor(row_half_width * 2.0 / TWINE_FILL_X_SPACING)) + 1)
		var first_x: float = -float(column_count - 1) * TWINE_FILL_X_SPACING * 0.5
		for column_index in range(column_count):
			var x: float = first_x + float(column_index) * TWINE_FILL_X_SPACING
			var normalized_x: float = x / max(1.0, fill_horizontal)
			if normalized_x * normalized_x + normalized_y * normalized_y > 1.0:
				continue
			var node: Node2D = _spawn_scene_effect(enemy, TWINE_SCENE, center + Vector2(x, y), Vector2.ONE * TWINE_FILL_VISUAL_SCALE, DEFAULT_EFFECT_LIFETIME)
			if node != null:
				node.rotation = randf_range(-0.22, 0.22)


static func _spawn_scene_effect(enemy, scene: PackedScene, position: Vector2, scale_value: Vector2, lifetime: float = DEFAULT_EFFECT_LIFETIME) -> Node2D:
	if scene == null:
		return null
	var node: Node = scene.instantiate()
	if node is not Node2D:
		return null
	var node2d: Node2D = node as Node2D
	node2d.global_position = position
	node2d.scale *= scale_value
	node2d.z_index = 8
	_add_to_scene(enemy, node2d)
	_play_scene_animation(node2d)
	_fade_and_free(node2d, lifetime)
	return node2d


static func _play_scene_animation(node: Node2D) -> void:
	var sprite: AnimatedSprite2D = node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	sprite.play()


static func _get_scene_animation_lifetime(scene: PackedScene, animation_name: String) -> float:
	if scene == null:
		return DEFAULT_EFFECT_LIFETIME
	var node: Node = scene.instantiate()
	if node == null:
		return DEFAULT_EFFECT_LIFETIME
	var lifetime: float = DEFAULT_EFFECT_LIFETIME
	var sprite: AnimatedSprite2D = node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null and sprite.sprite_frames != null:
		var resolved_animation: StringName = StringName(animation_name)
		if not sprite.sprite_frames.has_animation(resolved_animation):
			resolved_animation = sprite.animation
		if sprite.sprite_frames.has_animation(resolved_animation):
			var frame_count: int = sprite.sprite_frames.get_frame_count(resolved_animation)
			var animation_speed: float = max(0.01, sprite.sprite_frames.get_animation_speed(resolved_animation) * sprite.speed_scale)
			var duration_sum: float = 0.0
			for frame_index in range(frame_count):
				duration_sum += sprite.sprite_frames.get_frame_duration(resolved_animation, frame_index)
			lifetime = max(DEFAULT_EFFECT_LIFETIME, duration_sum / animation_speed + 0.08)
	node.queue_free()
	return lifetime


static func _get_spread_positions_near_target(enemy, count: int, min_radius: float, max_radius: float, safe_radius: float, min_center_distance: float) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count <= 0:
		return positions
	var target_position: Vector2 = _get_target_position(enemy)
	var base_angle: float = randf() * TAU
	var safe_min_radius: float = max(0.0, min_radius, safe_radius)
	var safe_max_radius: float = max(safe_min_radius + 1.0, max_radius)
	for index in range(count):
		var preferred_angle: float = base_angle + TAU * float(index) / float(max(1, count))
		var fallback_radius: float = lerp(safe_min_radius, safe_max_radius, 0.62 if index % 2 == 0 else 0.88)
		var best_position: Vector2 = _clamp_position_to_map(enemy, target_position + Vector2.RIGHT.rotated(preferred_angle) * fallback_radius)
		var best_score: float = -INF
		for _attempt in range(SPREAD_POSITION_ATTEMPTS):
			var angle_window: float = TAU / float(max(4, count)) * 0.52
			var angle: float = preferred_angle + randf_range(-angle_window, angle_window)
			var distance: float = randf_range(safe_min_radius, safe_max_radius)
			var candidate: Vector2 = _clamp_position_to_map(enemy, target_position + Vector2.RIGHT.rotated(angle) * distance)
			var score: float = _score_spread_position(candidate, target_position, positions, safe_radius, min_center_distance)
			if score > best_score:
				best_score = score
				best_position = candidate
			if score >= 1.0:
				break
		positions.append(best_position)
	return positions


static func _score_spread_position(candidate: Vector2, target_position: Vector2, existing_positions: Array[Vector2], safe_radius: float, min_center_distance: float) -> float:
	var target_distance: float = candidate.distance_to(target_position)
	if target_distance < safe_radius:
		return -1000.0 - (safe_radius - target_distance)
	var nearest_distance: float = INF
	for existing_position in existing_positions:
		nearest_distance = min(nearest_distance, candidate.distance_to(existing_position))
	if existing_positions.is_empty():
		nearest_distance = min_center_distance
	var spacing_score: float = nearest_distance / max(1.0, min_center_distance)
	var escape_score: float = min(target_distance / max(1.0, safe_radius), 2.0) * 0.12
	return spacing_score + escape_score


static func _get_target_position(enemy) -> Vector2:
	if enemy != null and is_instance_valid(enemy) and enemy.target != null and is_instance_valid(enemy.target) and enemy.target is Node2D:
		return enemy.target.global_position
	if enemy != null and is_instance_valid(enemy):
		return enemy.global_position
	return Vector2.ZERO


static func _clamp_position_to_map(enemy, position: Vector2) -> Vector2:
	var scene: Node = enemy.get_tree().current_scene if enemy.get_tree() != null else null
	if scene != null and scene.has_method("get_map_bounds"):
		var bounds: Variant = scene.call("get_map_bounds")
		if bounds is Rect2:
			var rect: Rect2 = bounds as Rect2
			position.x = clamp(position.x, rect.position.x + WOOD_SPIKE_RADIUS, rect.position.x + rect.size.x - WOOD_SPIKE_RADIUS)
			position.y = clamp(position.y, rect.position.y + WOOD_SPIKE_RADIUS, rect.position.y + rect.size.y - WOOD_SPIKE_RADIUS)
	return position


static func _add_to_scene(enemy, node: Node) -> void:
	var scene: Node = enemy.get_tree().current_scene if enemy.get_tree() != null else null
	if scene != null:
		scene.add_child(node)
	else:
		enemy.add_child(node)


static func _clear_warnings(enemy) -> void:
	for node in enemy.glutton_warning_nodes:
		if is_instance_valid(node):
			node.queue_free()
	enemy.glutton_warning_nodes.clear()


static func _fade_and_free(node: Node, duration: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tree: SceneTree = node.get_tree()
	if tree == null:
		return
	var node_ref: WeakRef = weakref(node)
	var tween: Tween = tree.create_tween()
	tween.tween_interval(max(0.01, duration))
	tween.tween_callback(func() -> void:
		var target_node: Node = node_ref.get_ref() as Node
		if target_node != null and is_instance_valid(target_node):
			target_node.queue_free()
	)


static func _build_ellipse_points(horizontal_radius: float, vertical_radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var safe_segments: int = max(12, segments)
	for index in range(safe_segments):
		var angle: float = TAU * float(index) / float(safe_segments)
		points.append(Vector2(cos(angle) * horizontal_radius, sin(angle) * vertical_radius))
	return points

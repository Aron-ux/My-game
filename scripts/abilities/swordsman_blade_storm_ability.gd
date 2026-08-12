extends RefCounted

const SWORD_TORNADO_EFFECT_SCENE := preload("res://effects/sword/tornado/tornado.tscn")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_COMBAT_RESULT_FLOW := preload("res://scripts/player/player_combat_result_flow.gd")
const PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW := preload("res://scripts/player/player_swordsman_trait_runtime_flow.gd")

const COOLDOWN := 22.0
const BASE_DURATION := 2.7
const TIER_TWO_DURATION := 1.5
const TIER_THREE_DURATION := 2.0
const BASE_TICK_INTERVAL := 0.3
const TIER_TWO_TICK_INTERVAL := 0.4
const TIER_THREE_TICK_INTERVAL := 0.2
const BASE_DAMAGE_RATIO := 0.8
const TIER_THREE_DAMAGE_RATIO := 1.05
const MAX_CATCH_UP_TICKS := 5
const ROTATION_SPEED := -TAU * 5.175
const BASE_RADIUS := 120.0
const BASE_VISUAL_SCALE := 0.48
const DIELANG_DURATION_BONUS := 0.24
const DIELANG_RADIUS_BONUS := 0.1
const BLADE_STORM_SKILL_ID := "blade_storm"
const BLADE_STORM_WIDTH_LEVEL := "trick"
const EXTRA_STORM_OFFSET := 150.0
const RING_VISUAL_EVERY_TICKS := 2
const TORNADO_EFFECT_POOL_LIMIT := 6
const LEVEL_TALENT_BLADE_STORM_1 := "swordsman_level_talent_blade_storm_1"
const TALENT_IDS := [
	"swordsman_blade_storm_stationary",
	"swordsman_blade_storm_retain",
	"swordsman_blade_storm_recall",
	"swordsman_blade_storm_rending_spin",
	"swordsman_blade_storm_after_howl",
	"swordsman_blade_storm_returning_gale",
	LEVEL_TALENT_BLADE_STORM_1
]

var cooldown_remaining: float = 0.0
var active_remaining: float = 0.0
var tick_remaining: float = 0.0
var ring_visual_tick_index: int = 0
var effects: Array[Node2D] = []
var tornado_effect_pool: Array[Node2D] = []
var storm_local_positions: Array[Vector2] = []
var storm_global_centers: Array[Vector2] = []
var cast_origin: Vector2 = Vector2.ZERO
var cast_direction: Vector2 = Vector2.RIGHT
var base_tick_count: int = 0
var cast_elapsed: float = 0.0
var recall_inside: Dictionary = {}
var recall_cooldowns: Dictionary = {}
var cast_talent_ids: Array[String] = []
var cast_talent_snapshot_valid: bool = false

func update(owner, delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)

	if active_remaining <= 0.0:
		return

	if owner == null or not is_instance_valid(owner):
		stop()
		return

	if str(owner._get_active_role().get("id", "")) != "swordsman" and not _has_talent(owner, "swordsman_blade_storm_retain"):
		stop(owner)
		return

	active_remaining = max(0.0, active_remaining - delta)
	cast_elapsed += delta
	_update_recall(owner, delta)
	tick_remaining -= delta
	_update_effect(owner, delta)
	var catch_up_ticks := 0
	while tick_remaining <= 0.0 and active_remaining > 0.0 and catch_up_ticks < MAX_CATCH_UP_TICKS:
		tick_remaining += _get_tick_interval(owner)
		_trigger_tick(owner)
		catch_up_ticks += 1
	if catch_up_ticks >= MAX_CATCH_UP_TICKS and tick_remaining <= 0.0:
		tick_remaining = _get_tick_interval(owner)
	if active_remaining <= 0.0:
		_finish(owner)

func can_trigger(owner, role_id: String) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	if bool(owner.get("is_dead")) or bool(owner.get("level_up_active")):
		return false
	if role_id != "swordsman":
		return false
	if not _has_required_unlock(owner):
		return false
	return active_remaining <= 0.0 and cooldown_remaining <= 0.0

func try_trigger(owner) -> bool:
	if not can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		return false
	cast_talent_ids = _capture_talents(owner)
	cast_talent_snapshot_valid = true
	active_remaining = _get_duration(owner)
	cooldown_remaining = _get_cooldown(owner)
	tick_remaining = 0.0
	ring_visual_tick_index = 0
	base_tick_count = 0
	cast_elapsed = 0.0
	recall_inside.clear()
	recall_cooldowns.clear()
	cast_origin = owner.global_position
	cast_direction = owner.facing_direction.normalized() if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	_ensure_effect(owner)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -66.0), "\u5251\u5203\u98ce\u66b4", Color(0.42, 0.9, 1.0, 1.0))
	owner._spawn_ring_effect(owner.global_position, _get_radius(owner) * 0.95, Color(0.42, 0.9, 1.0, 0.28), 8.0, 0.2)
	return true

func stop(owner = null) -> void:
	active_remaining = 0.0
	tick_remaining = 0.0
	for effect in effects:
		if effect != null and is_instance_valid(effect):
			_release_tornado_effect(effect)
	effects.clear()
	recall_inside.clear()
	recall_cooldowns.clear()
	cast_talent_ids.clear()
	cast_talent_snapshot_valid = false

func is_active() -> bool:
	return active_remaining > 0.0

func _finish(owner) -> void:
	var centers: Array[Vector2] = _get_storm_centers(owner).duplicate()
	var radius: float = _get_radius(owner)
	if _has_talent(owner, "swordsman_blade_storm_after_howl"):
		var blood_surge_multiplier := PLAYER_COMBAT_RESULT_FLOW.get_swordsman_blood_surge_multiplier(owner)
		var damage_amount: float = _get_damage(owner) * 0.90 * blood_surge_multiplier
		if str(owner._get_active_role().get("id", "")) != "swordsman":
			damage_amount *= 0.70
		var total_hits := 0
		for center in centers:
			total_hits += int(owner._damage_enemies_in_radius(center, radius, damage_amount, 0.0, 1.0, 0.0, "swordsman"))
			owner._spawn_ring_effect(center, radius, Color(0.46, 0.9, 1.0, 0.62), 7.0, 0.16)
		if total_hits > 0 and blood_surge_multiplier > 1.0:
			PLAYER_COMBAT_RESULT_FLOW.consume_swordsman_blood_surge(owner)
	if _has_talent(owner, "swordsman_blade_storm_returning_gale"):
		var state: Dictionary = owner._get_role_special_state("swordsman")
		state["returning_gale_remaining"] = 1.0
		state["returning_gale_role_id"] = str(owner._get_active_role().get("id", ""))
		owner.role_special_states["swordsman"] = state
	stop(owner)

func get_cooldown_slot(owner = null) -> Dictionary:
	var duration := _get_cooldown(owner)
	return {
		"name": "\u5251\u5203\u98ce\u66b4",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(0.34, 0.92, 1.0, 1.0),
		"description": "剑刃风暴：剑士荡阵进化。开启环绕剑刃持续切割周围敌人，冷却期间无法再次触发。"
	}

func get_save_data() -> Dictionary:
	return {
		"cooldown_remaining": cooldown_remaining,
		"active_remaining": active_remaining,
		"tick_remaining": tick_remaining,
		"cast_origin": [cast_origin.x, cast_origin.y],
		"cast_direction": [cast_direction.x, cast_direction.y],
		"ring_visual_tick_index": ring_visual_tick_index,
		"base_tick_count": base_tick_count,
		"cast_elapsed": cast_elapsed,
		"talent_ids": cast_talent_ids.duplicate(),
		"talent_snapshot_valid": cast_talent_snapshot_valid
	}

func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	active_remaining = clamp(float(data.get("active_remaining", 0.0)), 0.0, max(BASE_DURATION, max(TIER_TWO_DURATION, TIER_THREE_DURATION)) + 3.0 * DIELANG_DURATION_BONUS)
	tick_remaining = clamp(float(data.get("tick_remaining", 0.0)), 0.0, BASE_TICK_INTERVAL)
	cast_origin = _decode_vector2(data.get("cast_origin", Vector2.ZERO), Vector2.ZERO)
	cast_direction = _decode_vector2(data.get("cast_direction", Vector2.RIGHT), Vector2.RIGHT)
	ring_visual_tick_index = max(0, int(data.get("ring_visual_tick_index", 0)))
	base_tick_count = max(0, int(data.get("base_tick_count", 0)))
	cast_elapsed = max(0.0, float(data.get("cast_elapsed", 0.0)))
	cast_talent_ids = _normalize_talent_ids(data.get("talent_ids", []))
	cast_talent_snapshot_valid = bool(data.get("talent_snapshot_valid", data.has("talent_ids")))

func restore_effect_if_active(owner) -> void:
	if active_remaining > 0.0:
		_ensure_effect(owner)

func _trigger_tick(owner) -> void:
	var radius: float = _get_radius(owner)
	var blood_surge_multiplier := PLAYER_COMBAT_RESULT_FLOW.get_swordsman_blood_surge_multiplier(owner)
	var damage_amount: float = _get_damage(owner) * blood_surge_multiplier
	if str(owner._get_active_role().get("id", "")) != "swordsman":
		damage_amount *= 0.70
	var slow_multiplier: float = 0.70 if _has_talent(owner, "swordsman_blade_storm_stationary") else 1.0
	var slow_duration: float = 0.40 if slow_multiplier < 1.0 else 0.0
	var should_spawn_ring_visual := ring_visual_tick_index % RING_VISUAL_EVERY_TICKS == 0
	ring_visual_tick_index += 1
	base_tick_count += 1
	var centers: Array[Vector2] = _get_storm_centers(owner)
	var total_hits := 0
	if owner.has_method("_damage_enemies_in_multiple_radii_batched"):
		total_hits = int(owner._damage_enemies_in_multiple_radii_batched(centers, radius, damage_amount, 0.08, slow_multiplier, slow_duration, "swordsman"))
	else:
		for center in centers:
			total_hits += int(owner._damage_enemies_in_radius(center, radius, damage_amount, 0.08, slow_multiplier, slow_duration, "swordsman"))
	if total_hits > 0 and blood_surge_multiplier > 1.0:
		PLAYER_COMBAT_RESULT_FLOW.consume_swordsman_blood_surge(owner)
	if _has_talent(owner, "swordsman_blade_storm_rending_spin") and base_tick_count % 3 == 0:
		for center in centers:
			owner._damage_enemies_in_radius(center, radius * 1.35, damage_amount * 0.50, 0.08, slow_multiplier, slow_duration, "swordsman")
			owner._spawn_ring_effect(center, radius * 1.35, Color(0.34, 0.82, 1.0, 0.28), 5.0, 0.14)
	if should_spawn_ring_visual:
		for center in centers:
			owner._spawn_ring_effect(center, radius * 0.88, Color(0.38, 0.86, 1.0, 0.14), 5.0, 0.14)

func _update_recall(owner, delta: float) -> void:
	if not _has_talent(owner, "swordsman_blade_storm_recall") or not owner.has_method("_get_live_enemies"):
		return
	for enemy_id in recall_cooldowns.keys():
		recall_cooldowns[enemy_id] = max(0.0, float(recall_cooldowns[enemy_id]) - delta)
	var centers: Array[Vector2] = _get_storm_centers(owner)
	var radius: float = _get_radius(owner)
	for raw_enemy in owner._get_live_enemies():
		if raw_enemy is not Node2D or not is_instance_valid(raw_enemy):
			continue
		var enemy := raw_enemy as Node2D
		var enemy_id := enemy.get_instance_id()
		var nearest_center := Vector2.ZERO
		var nearest_distance := INF
		for center in centers:
			var distance := center.distance_to(enemy.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_center = center
		var inside := nearest_distance <= radius
		if bool(recall_inside.get(enemy_id, false)) and not inside and float(recall_cooldowns.get(enemy_id, 0.0)) <= 0.0:
			var target := nearest_center + nearest_center.direction_to(enemy.global_position) * radius * 0.70
			var displacement: Vector2 = enemy.global_position.direction_to(target) * min(90.0, enemy.global_position.distance_to(target))
			enemy.global_position += displacement
			recall_cooldowns[enemy_id] = 0.75
			recall_inside[enemy_id] = true
		else:
			recall_inside[enemy_id] = inside

func _ensure_effect(owner) -> void:
	if owner == null or not is_instance_valid(owner) or SWORD_TORNADO_EFFECT_SCENE == null:
		return
	var desired_count: int = 1 + _get_extra_storm_count(owner)
	while effects.size() < desired_count:
		var instance := _acquire_tornado_effect(owner)
		if instance == null:
			return
		instance.name = "SwordsmanBladeStormEffect"
		instance.z_index = 18
		effects.append(instance)
		var sprite := instance.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite != null:
			sprite.centered = true
			sprite.position = Vector2.ZERO
			sprite.scale = Vector2.ONE * BASE_VISUAL_SCALE * _get_size_multiplier(owner) * _get_range_multiplier(owner)
			sprite.modulate = Color(1.0, 1.0, 1.0, 0.96)
			if sprite.sprite_frames != null:
				sprite.play()
	for effect in effects:
		if effect != null and is_instance_valid(effect):
			effect.visible = true

func _acquire_tornado_effect(owner) -> Node2D:
	while not tornado_effect_pool.is_empty():
		var pooled_effect: Variant = tornado_effect_pool.pop_back()
		if not is_instance_valid(pooled_effect) or not (pooled_effect is Node2D):
			continue
		var effect := pooled_effect as Node2D
		if effect.is_queued_for_deletion():
			continue
		var parent := effect.get_parent()
		if parent != owner:
			if parent != null:
				parent.remove_child(effect)
			owner.add_child(effect)
		effect.show()
		effect.position = Vector2.ZERO
		effect.rotation = 0.0
		effect.scale = Vector2.ONE
		effect.modulate = Color.WHITE
		effect.set_meta("blade_storm_released", false)
		return effect
	var instance := SWORD_TORNADO_EFFECT_SCENE.instantiate() as Node2D
	if instance != null:
		owner.add_child(instance)
		instance.set_meta("blade_storm_released", false)
	return instance

func _release_tornado_effect(effect: Node2D) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	if bool(effect.get_meta("blade_storm_released", false)):
		return
	effect.set_meta("blade_storm_released", true)
	effect.hide()
	var sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.stop()
	if tornado_effect_pool.size() < TORNADO_EFFECT_POOL_LIMIT and not tornado_effect_pool.has(effect):
		tornado_effect_pool.append(effect)
	else:
		effect.queue_free()

func _update_effect(owner, delta: float) -> void:
	_ensure_effect(owner)
	var centers: Array[Vector2] = _get_storm_centers(owner)
	var remain_ratio: float = clamp(active_remaining / max(_get_duration(owner), 0.001), 0.0, 1.0)
	for index in range(effects.size()):
		var effect := effects[index] as Node2D
		if effect == null or not is_instance_valid(effect):
			continue
		effect.position = centers[index] - owner.global_position if index < centers.size() else Vector2.ZERO
		effect.rotation = wrapf(effect.rotation + ROTATION_SPEED * delta, 0.0, TAU)
		effect.modulate.a = 0.52 + 0.44 * remain_ratio

func _get_damage(owner) -> float:
	var tier: int = _get_tier(owner)
	var ratio: float = BASE_DAMAGE_RATIO + PLAYER_BUILD_SYSTEM.get_blade_storm_damage_ratio_bonus(owner)
	if tier >= 3:
		ratio = TIER_THREE_DAMAGE_RATIO + PLAYER_BUILD_SYSTEM.get_blade_storm_damage_ratio_bonus(owner)
	elif tier >= 2:
		ratio = BASE_DAMAGE_RATIO * 1.18 + PLAYER_BUILD_SYSTEM.get_blade_storm_damage_ratio_bonus(owner)
	return float(owner._get_role_damage("swordsman")) * ratio

func _get_duration(owner) -> float:
	var tier: int = _get_tier(owner)
	var duration := BASE_DURATION
	if tier >= 3:
		duration = TIER_THREE_DURATION
	elif tier >= 2:
		duration = TIER_TWO_DURATION
	if owner != null and owner.has_method("_get_blessing_skill_duration_multiplier"):
		duration *= float(owner._get_blessing_skill_duration_multiplier(BLADE_STORM_SKILL_ID))
	if owner != null and owner.has_method("_get_blessing_skill_duration_flat_bonus"):
		duration += float(owner._get_blessing_skill_duration_flat_bonus(BLADE_STORM_SKILL_ID))
	return duration

func _get_tick_interval(owner) -> float:
	var tier: int = _get_tier(owner)
	if tier >= 3:
		return TIER_THREE_TICK_INTERVAL
	if tier >= 2:
		return TIER_TWO_TICK_INTERVAL
	return BASE_TICK_INTERVAL

func _get_size_multiplier(owner) -> float:
	return 1.20 if _has_talent(owner, LEVEL_TALENT_BLADE_STORM_1) else 1.0

func _get_range_multiplier(owner) -> float:
	var range_multiplier: float = 1.0
	if owner != null and owner.has_method("_get_equipment_skill_range_multiplier"):
		range_multiplier *= float(owner._get_equipment_skill_range_multiplier())
	if owner != null and owner.has_method("_get_invoker_magic_range_multiplier"):
		range_multiplier *= float(owner._get_invoker_magic_range_multiplier(BLADE_STORM_SKILL_ID))
	range_multiplier *= PLAYER_BUILD_SYSTEM.get_blade_storm_radius_multiplier(owner)
	return range_multiplier

func _get_radius(owner) -> float:
	return BASE_RADIUS * _get_size_multiplier(owner) * _get_range_multiplier(owner)

func _get_extra_storm_count(owner) -> int:
	return min(4, _get_trick_bonus(owner)) if owner != null else 0

func _get_trick_bonus(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_quantity_count"):
		return int(owner._get_blessing_skill_quantity_count(BLADE_STORM_SKILL_ID))
	return 0

func _has_required_unlock(owner) -> bool:
	if owner == null or not owner.has_method("_is_blessing_skill_unlocked"):
		return false
	return bool(owner._is_blessing_skill_unlocked(BLADE_STORM_SKILL_ID))

func _get_storm_local_positions(owner) -> Array[Vector2]:
	storm_local_positions.clear()
	storm_local_positions.append(Vector2.ZERO)
	var extra_count := _get_extra_storm_count(owner)
	if extra_count <= 0:
		return storm_local_positions
	var direction: Vector2 = cast_direction if _has_talent(owner, "swordsman_blade_storm_stationary") else owner.facing_direction
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var side: Vector2 = owner._get_downward_perpendicular(direction).normalized()
	if side.length_squared() <= 0.001:
		side = Vector2.DOWN
	var distance: float = EXTRA_STORM_OFFSET * _get_size_multiplier(owner) * _get_range_multiplier(owner)
	if extra_count >= 1:
		storm_local_positions.append(direction * distance)
	if extra_count >= 2:
		storm_local_positions.append(-direction * distance)
	if extra_count >= 3:
		storm_local_positions.append(-side * distance)
	if extra_count >= 4:
		storm_local_positions.append(side * distance)
	return storm_local_positions

func _get_storm_centers(owner) -> Array[Vector2]:
	storm_global_centers.clear()
	var center_origin: Vector2 = cast_origin if _has_talent(owner, "swordsman_blade_storm_stationary") else owner.global_position
	for local_position in _get_storm_local_positions(owner):
		storm_global_centers.append(center_origin + local_position)
	return storm_global_centers

func _has_talent(owner, talent_id: String) -> bool:
	if cast_talent_snapshot_valid:
		return cast_talent_ids.has(talent_id)
	return _owner_has_talent(owner, talent_id)

func _capture_talents(owner) -> Array[String]:
	var result: Array[String] = []
	for talent_id in TALENT_IDS:
		if _owner_has_talent(owner, talent_id):
			result.append(talent_id)
	return result

func _owner_has_talent(owner, talent_id: String) -> bool:
	if talent_id == LEVEL_TALENT_BLADE_STORM_1:
		return PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW.has_level_talent(owner, talent_id)
	return owner != null and owner.has_method("_has_skill_talent") and bool(owner._has_skill_talent(talent_id))

func _normalize_talent_ids(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for talent_id in value:
			var normalized := str(talent_id)
			if TALENT_IDS.has(normalized) and not result.has(normalized):
				result.append(normalized)
	return result

func _decode_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback

func _get_cooldown(owner) -> float:
	var cooldown_multiplier: float = PLAYER_BUILD_SYSTEM.get_blade_storm_cooldown_multiplier(owner)
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		cooldown_multiplier *= float(owner._get_equipment_cooldown_multiplier())
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_mage_arcane_charge_skill_cooldown_multiplier"):
		cooldown_multiplier *= float(owner._get_mage_arcane_charge_skill_cooldown_multiplier("swordsman"))
	return COOLDOWN * cooldown_multiplier

func _get_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return int(owner._get_blessing_skill_tier(BLADE_STORM_SKILL_ID))
	return 1

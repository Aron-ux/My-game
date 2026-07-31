extends RefCounted

const MAGE_GATHERING_EFFECT_SCENE := preload("res://effects/wizard/wave/gathering/gatering.tscn")
const MAGE_WAVE_EFFECT_SCENE := preload("res://effects/wizard/wave/wave.tscn")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")

const TIER_ONE_COOLDOWN := 20.0
const TIER_TWO_COOLDOWN := 16.0
const TIER_THREE_COOLDOWN := 16.0
const WAVE_REPEAT_INTERVAL := 0.3
const BASE_SCALE_MULTIPLIER := 1.5
const HUICHAO_WIDTH_BONUS := 0.12
const WAVE_SPEED := 115.0
const WAVE_LIFETIME := 4.0
const WAVE_HIT_RADIUS := 29.932
const WAVE_VISUAL_SCALE := 5.2
const WAVE_WIDTH_MULTIPLIER := 0.7
const TIDAL_SURGE_RANGE_MULTIPLIER := 0.7
const SURGE_SKILL_ID := "surging_wave"
const TALENT_IDS := [
	"mage_surge_four",
	"mage_surge_back",
	"mage_surge_wake",
	"mage_surge_vortex",
	"mage_surge_rapid",
	"mage_surge_heavy"
]

var cooldown_remaining: float = 0.0
var next_wave_token: int = 1
var cast_talent_ids: Array[String] = []
var cast_talent_snapshot_valid: bool = false

func update(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)

func can_trigger(owner, role_id: String) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	if bool(owner.get("is_dead")) or bool(owner.get("level_up_active")):
		return false
	if role_id != "mage":
		return false
	if not _has_required_unlock(owner):
		return false
	return cooldown_remaining <= 0.0

func try_trigger(owner, base_direction: Vector2) -> bool:
	if not can_trigger(owner, "mage"):
		return false

	cast_talent_ids = _capture_talents(owner)
	cast_talent_snapshot_valid = true
	cooldown_remaining = _get_cooldown(owner)
	var direction := base_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	owner.facing_direction = direction

	var gather_origin: Vector2 = owner.global_position + direction * 18.0
	var damage_amount: float = float(owner._get_role_damage("mage")) * _get_damage_multiplier(owner)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -64.0), "\u6CE2\u6D9B\u6C79\u6D8C", Color(0.62, 0.9, 1.0, 1.0))
	owner._spawn_ring_effect(owner.global_position, 112.0, Color(0.56, 0.86, 1.0, 0.34), 8.0, 0.22)

	var gather_duration: float = float(owner._get_scene_animation_duration(MAGE_GATHERING_EFFECT_SCENE, 0.16))
	for gather_direction in _get_all_directions():
		owner._spawn_mage_gathering_scene_effect(gather_origin, gather_direction, 1.55 * _get_visual_range_multiplier(owner) * owner._get_equipment_skill_range_multiplier())

	if owner.get_tree() == null:
		return true
	var wave_scales: Array[float] = _get_wave_scales(owner)
	var wake_budget := {"remaining": 24}
	for repeat_index in range(wave_scales.size()):
		var wave_scale: float = float(wave_scales[repeat_index])
		var fire_delay: float = gather_duration + float(repeat_index) * WAVE_REPEAT_INTERVAL
		var is_base_wave := repeat_index == 0
		var group_damage_scale := 0.55 if is_base_wave and _has_talent(owner, "mage_surge_four") else 1.0
		var lifetime_scale := 0.75 if is_base_wave and _has_talent(owner, "mage_surge_four") else 1.0
		if owner.has_method("_schedule_repeating_sequence"):
			owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
				if is_instance_valid(owner):
					_fire_direction_group(owner, gather_origin, damage_amount * wave_scale * group_damage_scale, _get_wave_directions(owner, wave_scale, is_base_wave), wave_scale, lifetime_scale, is_base_wave, wake_budget)
			, fire_delay)
		else:
			_fire_direction_group(owner, gather_origin, damage_amount * wave_scale * group_damage_scale, _get_wave_directions(owner, wave_scale, is_base_wave), wave_scale, lifetime_scale, is_base_wave, wake_budget)
		if is_base_wave and _has_talent(owner, "mage_surge_back"):
			var reverse_direction := -direction
			var reverse_delay := fire_delay + 0.8
			var reverse_callback := func(_index: int) -> void:
				if is_instance_valid(owner):
					_spawn_wave(owner, owner.global_position, reverse_direction, damage_amount * 0.70, 1.0, 0.75)
			if owner.has_method("_schedule_repeating_sequence"):
				owner._schedule_repeating_sequence(0.0, 1, reverse_callback, reverse_delay)
			else:
				reverse_callback.call(0)
	return true

func get_cooldown_slot(owner = null) -> Dictionary:
	var duration := _get_cooldown(owner)
	return {
		"name": "\u6CE2\u6D9B\u6C79\u6D8C",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(0.62, 0.84, 1.0, 1.0),
		"description": "波涛涌动：法师荡阵进化。向多方向释放冲击波组，覆盖大范围敌人。"
	}

func get_save_data() -> Dictionary:
	return {
		"cooldown_remaining": cooldown_remaining,
		"next_wave_token": next_wave_token,
		"talent_ids": cast_talent_ids.duplicate(),
		"talent_snapshot_valid": cast_talent_snapshot_valid
	}

func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = max(0.0, float(data.get("cooldown_remaining", 0.0)))
	next_wave_token = max(1, int(data.get("next_wave_token", 1)))
	cast_talent_ids = _normalize_talent_ids(data.get("talent_ids", []))
	cast_talent_snapshot_valid = bool(data.get("talent_snapshot_valid", data.has("talent_ids")))

func _fire_direction_group(owner, origin: Vector2, damage_amount: float, directions: Array, effect_scale: float, lifetime_scale: float = 1.0, is_base_wave: bool = false, wake_budget: Dictionary = {}) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var wake_counts: Array[int] = _allocate_wake_points(directions.size(), int(wake_budget.get("remaining", 0))) if is_base_wave and _has_talent(owner, "mage_surge_wake") else []
	for index in range(directions.size()):
		var wake_points := wake_counts[index] if index < wake_counts.size() else 0
		_spawn_wave(owner, origin, directions[index], damage_amount, effect_scale, lifetime_scale, wake_points)
		if wake_points > 0:
			wake_budget["remaining"] = max(0, int(wake_budget.get("remaining", 0)) - wake_points)

func _spawn_wave(owner, origin: Vector2, fire_direction: Vector2, damage_amount: float, effect_scale: float = 1.0, lifetime_scale: float = 1.0, wake_points: int = 0) -> Node2D:
	var wave = owner._spawn_directional_bullet_from_scene(
		MAGE_WAVE_EFFECT_SCENE,
		fire_direction,
		damage_amount,
		Color(0.56, 0.88, 1.0, 1.0),
		"mage",
		origin + fire_direction * 18.0
	)
	if wave == null:
		return null
	var wave_token := next_wave_token
	next_wave_token += 1
	wave.set_meta("mage_surge_token", wave_token)
	wave.set_meta("mage_surge_talent_ids", cast_talent_ids.duplicate())
	wave.z_as_relative = false
	wave.z_index = 30
	var distance_scale: float = max(0.05, effect_scale)
	var range_multiplier: float = float(owner._get_role_attribute_range_multiplier("mage")) * float(owner._get_role_equipment_skill_range_multiplier("mage")) * float(owner._get_role_attribute_range_multiplier("mage")) * _get_visual_range_multiplier(owner)
	var speed_multiplier := 1.0
	var width_multiplier := 1.0
	var talent_lifetime_scale := 1.0
	wave.set_meta("mage_surge_rapid", false)
	if _has_talent(owner, "mage_surge_vortex"):
		speed_multiplier *= 0.85
		width_multiplier *= 1.30
		wave.slow_multiplier = 0.80
		wave.slow_duration = 1.0
	elif _has_talent(owner, "mage_surge_rapid"):
		speed_multiplier *= 1.30
		talent_lifetime_scale *= 0.85
		wave.set_meta("mage_surge_rapid", true)
	wave.speed = _get_wave_speed(owner) * speed_multiplier
	wave.lifetime = _get_lifetime(owner) * distance_scale * lifetime_scale * talent_lifetime_scale
	wave.hit_radius = WAVE_HIT_RADIUS * range_multiplier * WAVE_WIDTH_MULTIPLIER * width_multiplier
	wave.pierce_count = 999
	wave.visual_scale_multiplier = WAVE_VISUAL_SCALE * range_multiplier * WAVE_WIDTH_MULTIPLIER * width_multiplier
	wave.enemy_hit_radius_scale = 0.62
	wave.enemy_hit_radius_min = 12.0
	wave.enemy_hit_radius_max = 72.0 * _get_scale_multiplier(owner) * WAVE_WIDTH_MULTIPLIER * width_multiplier
	if _has_talent(owner, "mage_surge_heavy"):
		_schedule_heavy_wave_stage(owner, wave, wave_token)
	if wake_points > 0:
		_start_wake_trail(owner, wave, wave_token, wake_points, damage_amount, wave.hit_radius)
	return wave

func _allocate_wake_points(wave_count: int, remaining_budget: int) -> Array[int]:
	var result: Array[int] = []
	if wave_count <= 0 or remaining_budget <= 0:
		return result
	var total: int = min(24, remaining_budget)
	var base: int = min(8, floori(float(total) / float(wave_count)))
	var remainder: int = total - base * wave_count
	for index in range(wave_count):
		result.append(base + (1 if index < remainder and base < 8 else 0))
	return result

func _schedule_heavy_wave_stage(owner, wave: Node2D, wave_token: int) -> void:
	var delay: float = max(0.0, float(wave.get("lifetime")) - 0.4)
	var callback := func(_index: int) -> void:
		if wave == null or not is_instance_valid(wave) or int(wave.get_meta("mage_surge_token", -1)) != wave_token or bool(wave.get_meta("player_projectile_released", false)):
			return
		wave.speed *= 0.80
		wave.damage *= 1.20
		wave.hit_radius *= 1.35
		wave.visual_scale_multiplier *= 1.35
	if owner.has_method("_schedule_repeating_sequence"):
		owner._schedule_repeating_sequence(0.0, 1, callback, delay)

func _start_wake_trail(owner, wave: Node2D, wave_token: int, point_count: int, damage_amount: float, radius: float) -> void:
	if not owner.has_method("_schedule_repeating_sequence") or point_count <= 0:
		return
	var areas: Array[Dictionary] = []
	var hit_enemy_ids: Dictionary = {}
	var lifetime: float = float(wave.get("lifetime"))
	var sample_interval := lifetime / float(point_count + 1)
	owner._schedule_repeating_sequence(sample_interval, point_count, func(_index: int) -> void:
		if wave == null or not is_instance_valid(wave) or int(wave.get_meta("mage_surge_token", -1)) != wave_token or bool(wave.get_meta("player_projectile_released", false)):
			return
		areas.append({"center": wave.global_position, "remaining": 1.2, "damage": float(wave.get("damage"))})
		owner._spawn_ring_effect(wave.global_position, radius, Color(0.42, 0.82, 1.0, 0.22), 4.0, 1.2)
	)
	var scan_count := int(ceil((lifetime + 1.2) / 0.2))
	owner._schedule_repeating_sequence(0.2, scan_count, func(_index: int) -> void:
		if owner == null or not is_instance_valid(owner) or not owner.has_method("_get_live_enemies"):
			return
		for area in areas:
			area["remaining"] = max(0.0, float(area.get("remaining", 0.0)) - 0.2)
		for enemy in owner._get_live_enemies():
			if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
				continue
			var enemy_node := enemy as Node2D
			var enemy_id := enemy_node.get_instance_id()
			if hit_enemy_ids.has(enemy_id):
					continue
			for area in areas:
				if float(area.get("remaining", 0.0)) > 0.0 and enemy_node.global_position.distance_squared_to(area.get("center", Vector2.ZERO)) <= radius * radius:
					_try_apply_wake_hit(owner, enemy_node, hit_enemy_ids, float(area.get("damage", damage_amount)) * 0.20)
					break
	)

func _try_apply_wake_hit(owner, enemy: Node2D, hit_enemy_ids: Dictionary, damage_amount: float) -> bool:
	if owner == null or enemy == null or not is_instance_valid(enemy) or hit_enemy_ids.has(enemy.get_instance_id()):
		return false
	hit_enemy_ids[enemy.get_instance_id()] = true
	if owner.has_method("_deal_damage_to_enemy"):
		owner._deal_damage_to_enemy(enemy, damage_amount, "mage")
	return true

func _get_wave_speed(owner) -> float:
	return WAVE_SPEED + PLAYER_BUILD_SYSTEM.get_surging_wave_speed_bonus(owner)

func _get_scale_multiplier(owner) -> float:
	var quantity_bonus := float(_get_quantity_extra_count(owner)) * HUICHAO_WIDTH_BONUS
	return BASE_SCALE_MULTIPLIER * (1.0 + quantity_bonus)

func _get_visual_range_multiplier(owner) -> float:
	var range_multiplier: float = 1.0
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_kebiru_magic_range_multiplier"):
		range_multiplier *= float(owner._get_kebiru_magic_range_multiplier(SURGE_SKILL_ID))
	return _get_scale_multiplier(owner) * TIDAL_SURGE_RANGE_MULTIPLIER * range_multiplier

func _get_cardinal_directions() -> Array[Vector2]:
	return [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]

func _get_diagonal_directions() -> Array[Vector2]:
	return [
		Vector2(1.0, 1.0).normalized(),
		Vector2(-1.0, 1.0).normalized(),
		Vector2(-1.0, -1.0).normalized(),
		Vector2(1.0, -1.0).normalized()
	]

func _get_all_directions() -> Array[Vector2]:
	var directions := _get_cardinal_directions()
	directions.append_array(_get_diagonal_directions())
	return directions

func _get_wave_directions(owner, effect_scale: float = 1.0, is_base_wave: bool = false) -> Array[Vector2]:
	var quantity_count := _get_quantity_extra_count(owner)
	if is_base_wave and _has_talent(owner, "mage_surge_four"):
		var base_direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
		var total_count: int = min(8, 4 + quantity_count)
		var result: Array[Vector2] = []
		for index in range(total_count):
			result.append(base_direction.normalized().rotated(TAU * float(index) / float(total_count)))
		return result
	if quantity_count <= 0 or effect_scale < 0.99:
		var direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
		return [direction.normalized()]
	var directions: Array[Vector2] = []
	var total_count: int = min(8, 1 + quantity_count)
	for index in range(total_count):
		directions.append(Vector2.RIGHT.rotated(TAU * float(index) / float(total_count)))
	return directions

func _get_cooldown(owner) -> float:
	var tier: int = _get_tier(owner)
	var base_cooldown := TIER_ONE_COOLDOWN
	if tier >= 3:
		base_cooldown = TIER_THREE_COOLDOWN
	elif tier >= 2:
		base_cooldown = TIER_TWO_COOLDOWN
	var cooldown_multiplier: float = PLAYER_BUILD_SYSTEM.get_surging_wave_cooldown_multiplier(owner)
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		cooldown_multiplier *= float(owner._get_equipment_cooldown_multiplier())
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_kebiru_magic_cooldown_multiplier"):
		cooldown_multiplier *= float(owner._get_kebiru_magic_cooldown_multiplier(SURGE_SKILL_ID))
	return base_cooldown * cooldown_multiplier

func _has_required_unlock(owner) -> bool:
	if owner == null or not owner.has_method("_is_blessing_skill_unlocked"):
		return false
	return bool(owner._is_blessing_skill_unlocked(SURGE_SKILL_ID))

func _get_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return int(owner._get_blessing_skill_tier(SURGE_SKILL_ID))
	return 1

func _get_wave_scales(owner) -> Array[float]:
	var result: Array[float] = [1.0]
	if owner == null or not owner.has_method("_get_blessing_skill_combo_scales"):
		return result
	for scale in owner._get_blessing_skill_combo_scales(SURGE_SKILL_ID) as Array:
		result.append(max(0.05, float(scale)))
	return result

func _get_quantity_extra_count(owner) -> int:
	if owner == null or not owner.has_method("_get_blessing_skill_quantity_count"):
		return 0
	return int(owner._get_blessing_skill_quantity_count(SURGE_SKILL_ID))

func _get_lifetime_multiplier(owner) -> float:
	var tier: int = _get_tier(owner)
	var multiplier := 1.0
	if tier >= 3:
		multiplier = 1.6
	elif tier >= 2:
		multiplier = 4.0 / 3.0
	if owner != null and owner.has_method("_get_blessing_skill_duration_multiplier"):
		multiplier *= float(owner._get_blessing_skill_duration_multiplier(SURGE_SKILL_ID))
	return multiplier

func _get_lifetime(owner) -> float:
	var lifetime := WAVE_LIFETIME * _get_lifetime_multiplier(owner)
	if owner != null and owner.has_method("_get_blessing_skill_duration_flat_bonus"):
		lifetime += float(owner._get_blessing_skill_duration_flat_bonus(SURGE_SKILL_ID))
	lifetime += PLAYER_BUILD_SYSTEM.get_surging_wave_duration_bonus(owner)
	return lifetime

func _get_damage_multiplier(owner) -> float:
	var tier: int = _get_tier(owner)
	var multiplier: float = 1.2
	if tier >= 3:
		multiplier = 2.0
	elif tier >= 2:
		multiplier = 1.5
	return multiplier + PLAYER_BUILD_SYSTEM.get_surging_wave_damage_multiplier_bonus(owner)

func _has_talent(owner, talent_id: String) -> bool:
	if cast_talent_snapshot_valid:
		return cast_talent_ids.has(talent_id)
	return owner != null and owner.has_method("_has_skill_talent") and bool(owner._has_skill_talent(talent_id))

func _capture_talents(owner) -> Array[String]:
	var result: Array[String] = []
	for talent_id in TALENT_IDS:
		if owner != null and owner.has_method("_has_skill_talent") and bool(owner._has_skill_talent(talent_id)):
			result.append(talent_id)
	return result

func _normalize_talent_ids(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for talent_id in value:
			var normalized := str(talent_id)
			if TALENT_IDS.has(normalized) and not result.has(normalized):
				result.append(normalized)
	return result

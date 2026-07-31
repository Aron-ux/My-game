extends RefCounted

const CRESCENT_SCENE := preload("res://effects/sword/fan/fan.tscn")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_COMBAT_RESULT_FLOW := preload("res://scripts/player/player_combat_result_flow.gd")

const SKILL_ID := "crescent_wave"
const COOLDOWN := 6.0
const SLASH_LENGTH := 122.0
const SLASH_WIDTH := 52.0
const WAVE_LENGTH := 430.0
const WAVE_WIDTH := 74.0
const FULL_MOON_WAVE_LENGTH := 280.0
const FULL_MOON_WAVE_WIDTH := 150.0
const TIER_TWO_WIDTH_MULTIPLIER := 1.2
const TIER_TWO_DAMAGE_MULTIPLIER := 1.45
const TIER_TWO_SPEED_MULTIPLIER := 1.3
const TIER_THREE_WIDTH_MULTIPLIER := 1.4
const TIER_THREE_DAMAGE_MULTIPLIER := 1.65
const TIER_THREE_SPEED_MULTIPLIER := 1.6
const BASE_WAVE_SPEED := 650.0
const FULL_MOON_WAVE_SPEED := 500.0
const COMBO_INTERVAL := 0.16
const VISUAL_AND_HIT_SCALE := 0.6
const FAN_SCENE_SIZE := Vector2(1024.0, 1024.0)
const FAN_SCENE_VISIBLE_BOUNDS := Rect2(485.0, 405.0, 117.0, 50.0)
const FAN_WAVE_BASE_VISIBLE_SIZE := Vector2(138.0, 74.0)
const SLASH_DAMAGE_RATIO := 1.3
const WAVE_DAMAGE_RATIO := 1.3
const WAVE_DAMAGE_SAMPLE_INTERVAL := 0.08
const CRESCENT_PROJECTILE_POOL_LIMIT := 16
const TALENT_IDS := [
	"swordsman_crescent_afterimage",
	"swordsman_crescent_twin_moons",
	"swordsman_crescent_full_moon",
	"swordsman_crescent_frost_trail",
	"swordsman_crescent_return",
	"swordsman_crescent_eclipse"
]

var cooldown_remaining: float = 0.0
var crescent_projectile_pool: Array[Node2D] = []
var crescent_projectile_spawn_serial: int = 0
var active_crescent_projectiles: Array[Dictionary] = []
var cast_talent_ids: Array[String] = []
var cast_talent_snapshot_valid: bool = false
var pending_saved_projectiles: Array[Dictionary] = []


func update(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)
	_update_crescent_projectiles(delta)


func can_trigger(owner, role_id: String) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	if bool(owner.get("is_dead")) or bool(owner.get("level_up_active")):
		return false
	if role_id != "swordsman":
		return false
	if not _has_required_unlock(owner):
		return false
	return cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		return false
	cast_talent_ids = _capture_talents(owner)
	cast_talent_snapshot_valid = true
	cooldown_remaining = _get_cooldown(owner)
	var base_direction: Vector2 = owner._get_live_mouse_aim_direction(owner.facing_direction)
	if base_direction.length_squared() <= 0.001:
		base_direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	owner.facing_direction = base_direction.normalized()
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -68.0), "\u6708\u7259\u5251\u6c14", Color(0.54, 0.92, 1.0, 1.0))
	var directions: Array[Vector2] = _get_cast_directions(owner, owner.facing_direction)
	var combo_scales: Array[float] = _get_combo_scales(owner)
	_cast_direction_group(owner, directions, 1.0)
	_schedule_combos(owner, [owner.facing_direction], combo_scales)
	if _has_talent(owner, "swordsman_crescent_afterimage"):
		var afterimage_direction: Vector2 = owner.facing_direction
		owner._schedule_repeating_sequence(0.25, 1, func(_index: int) -> void:
			if owner != null and is_instance_valid(owner) and not bool(owner.get("is_dead")):
				_cast_afterimage(owner, afterimage_direction)
		, 0.25)
	return true


func get_cooldown_slot(owner = null) -> Dictionary:
	var duration: float = _get_cooldown(owner)
	return {
		"name": "\u6708\u7259\u5251\u6c14",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(0.48, 0.9, 1.0, 1.0),
		"description": "\u5251\u58eb\u5411\u524d\u65a9\u51fb\u540e\u91ca\u653e\u4e00\u9053\u6708\u7259\u5251\u6c14\uff0c\u5bf9\u524d\u65b9\u957f\u77e9\u5f62\u533a\u57df\u9020\u6210\u4f24\u5bb3\u3002"
	}


func get_save_data() -> Dictionary:
	var projectiles: Array[Dictionary] = []
	for data in active_crescent_projectiles:
		projectiles.append(_serialize_projectile(data))
	return {
		"cooldown_remaining": cooldown_remaining,
		"talent_ids": cast_talent_ids.duplicate(),
		"talent_snapshot_valid": cast_talent_snapshot_valid,
		"projectiles": projectiles
	}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	for projectile_data in active_crescent_projectiles:
		_free_projectile(projectile_data.get("projectile", null) as Node2D)
	active_crescent_projectiles.clear()
	cast_talent_ids = _normalize_talent_ids(data.get("talent_ids", []))
	cast_talent_snapshot_valid = bool(data.get("talent_snapshot_valid", data.has("talent_ids")))
	pending_saved_projectiles.clear()
	var saved_projectiles: Variant = data.get("projectiles", [])
	if saved_projectiles is Array:
		for saved_data in saved_projectiles:
			if saved_data is Dictionary:
				pending_saved_projectiles.append((saved_data as Dictionary).duplicate(true))


func restore_effect_if_active(owner) -> void:
	for saved_data in pending_saved_projectiles:
		var origin := _decode_vector2(saved_data.get("origin", []), owner.global_position)
		var direction := _decode_vector2(saved_data.get("direction", []), Vector2.RIGHT).normalized()
		var talents := _normalize_talent_ids(saved_data.get("talent_ids", cast_talent_ids))
		var previous_count := active_crescent_projectiles.size()
		_spawn_crescent_projectile(
			owner,
			origin,
			direction,
			max(1.0, float(saved_data.get("length", 1.0))),
			max(1.0, float(saved_data.get("width", 1.0))),
			max(0.05, float(saved_data.get("visual_scale", VISUAL_AND_HIT_SCALE))),
			max(0.0, float(saved_data.get("damage_amount", 0.0))),
			bool(saved_data.get("allow_return", true)),
			bool(saved_data.get("allow_eclipse", true)),
			talents
		)
		if active_crescent_projectiles.size() <= previous_count:
			continue
		var restored: Dictionary = active_crescent_projectiles.back()
		restored["duration"] = max(0.001, float(saved_data.get("duration", restored.get("duration", 0.1))))
		restored["elapsed"] = clamp(float(saved_data.get("elapsed", 0.0)), 0.0, float(restored["duration"]))
		restored["damage_elapsed"] = max(0.0, float(saved_data.get("damage_elapsed", 0.0)))
		restored["last_damage_progress"] = clamp(float(saved_data.get("last_damage_progress", 0.0)), 0.0, 1.0)
		restored["returned"] = bool(saved_data.get("returned", false))
		active_crescent_projectiles[active_crescent_projectiles.size() - 1] = restored
	pending_saved_projectiles.clear()
	_update_crescent_projectiles(0.0)


func _schedule_combos(owner, directions: Array[Vector2], combo_scales: Array[float]) -> void:
	if combo_scales.is_empty():
		return
	owner._schedule_repeating_sequence(COMBO_INTERVAL, combo_scales.size(), func(index: int) -> void:
		if is_instance_valid(owner) and index >= 0 and index < combo_scales.size():
			_cast_direction_group(owner, directions, float(combo_scales[index]))
	, COMBO_INTERVAL)


func _cast_direction_group(owner, directions: Array[Vector2], damage_scale: float) -> void:
	for index in range(directions.size()):
		var twin_moon: bool = _has_talent(owner, "swordsman_crescent_twin_moons") and index == 1
		_cast_once(owner, directions[index], damage_scale * (0.55 if twin_moon else 1.0), not twin_moon)


func _cast_once(owner, direction: Vector2, damage_scale: float, include_slash: bool = true) -> void:
	var width_multiplier: float = _get_width_multiplier(owner)
	var visual_hit_multiplier: float = width_multiplier * VISUAL_AND_HIT_SCALE
	var slash_width: float = SLASH_WIDTH * visual_hit_multiplier
	var slash_length: float = SLASH_LENGTH * visual_hit_multiplier
	var full_moon: bool = _has_talent(owner, "swordsman_crescent_full_moon")
	var wave_width: float = (FULL_MOON_WAVE_WIDTH if full_moon else WAVE_WIDTH) * visual_hit_multiplier
	var wave_length: float = (FULL_MOON_WAVE_LENGTH if full_moon else WAVE_LENGTH) * _get_range_multiplier(owner)
	var slash_center: Vector2 = owner.global_position + direction * (slash_length * 0.42)
	if include_slash:
		owner._spawn_sword_fan_scene_effect(slash_center, direction, visual_hit_multiplier)
	var damage_ratio_bonus: float = PLAYER_BUILD_SYSTEM.get_crescent_wave_damage_ratio_bonus(owner)
	var blood_surge_multiplier := PLAYER_COMBAT_RESULT_FLOW.get_swordsman_blood_surge_multiplier(owner)
	var base_damage: float = _get_damage(owner) * blood_surge_multiplier
	var slash_hits: int = owner._damage_enemies_in_oriented_rect(slash_center, direction, slash_length, slash_width, base_damage * (SLASH_DAMAGE_RATIO + damage_ratio_bonus) * damage_scale, 0.0, 1.0, 0.0, "swordsman") if include_slash else 0
	if slash_hits > 0 and blood_surge_multiplier > 1.0:
		PLAYER_COMBAT_RESULT_FLOW.consume_swordsman_blood_surge(owner)
	var wave_origin: Vector2 = owner.global_position + direction * max(24.0, slash_length * 0.72)
	_spawn_crescent_projectile(owner, wave_origin, direction, wave_length, wave_width, visual_hit_multiplier, base_damage * (WAVE_DAMAGE_RATIO + damage_ratio_bonus) * damage_scale)
	if slash_hits > 0 and not _uses_batched_damage(owner):
		owner._register_attack_result("swordsman", slash_hits, false)


func _cast_afterimage(owner, direction: Vector2) -> void:
	var full_moon: bool = _has_talent(owner, "swordsman_crescent_full_moon")
	var width_multiplier: float = _get_width_multiplier(owner)
	var visual_hit_multiplier: float = width_multiplier * VISUAL_AND_HIT_SCALE
	var wave_width: float = (FULL_MOON_WAVE_WIDTH if full_moon else WAVE_WIDTH) * visual_hit_multiplier
	var wave_length: float = (FULL_MOON_WAVE_LENGTH if full_moon else WAVE_LENGTH) * _get_range_multiplier(owner) * 0.60
	var damage_ratio_bonus: float = PLAYER_BUILD_SYSTEM.get_crescent_wave_damage_ratio_bonus(owner)
	var damage_amount: float = _get_damage(owner) * (WAVE_DAMAGE_RATIO + damage_ratio_bonus) * 0.45
	var origin: Vector2 = owner.global_position + direction * 24.0
	_spawn_crescent_projectile(owner, origin, direction, wave_length, wave_width, visual_hit_multiplier, damage_amount, false, false)


func _spawn_crescent_projectile(owner, origin: Vector2, direction: Vector2, length: float, width: float, visual_scale: float, damage_amount: float, allow_return: bool = true, allow_eclipse: bool = true, talent_ids: Array[String] = []) -> void:
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return
	var projectile: Node2D = _acquire_projectile(current_scene)
	if projectile == null:
		projectile = Node2D.new()
	crescent_projectile_spawn_serial += 1
	var spawn_token: int = crescent_projectile_spawn_serial
	projectile.name = "SwordsmanCrescentWave"
	projectile.global_position = origin
	projectile.rotation = direction.angle() + PI
	projectile.z_index = 14
	projectile.modulate = Color.WHITE
	projectile.scale = Vector2.ONE
	projectile.set_meta("crescent_projectile_released", false)
	projectile.set_meta("crescent_projectile_token", spawn_token)
	var snapshot_talents := talent_ids if not talent_ids.is_empty() else cast_talent_ids
	var visual_width_multiplier: float = FULL_MOON_WAVE_WIDTH / WAVE_WIDTH if _has_cast_talent(owner, snapshot_talents, "swordsman_crescent_full_moon") else 1.0
	_configure_crescent_visual(projectile, visual_scale, visual_width_multiplier)
	var duration: float = length / max(1.0, _get_wave_speed(owner))
	active_crescent_projectiles.append({
		"owner_ref": weakref(owner),
		"projectile": projectile,
		"token": spawn_token,
		"origin": origin,
		"direction": direction,
		"length": length,
		"width": width,
		"damage_amount": damage_amount,
		"visual_scale": visual_scale,
		"duration": duration,
		"elapsed": 0.0,
		"damage_elapsed": 0.0,
		"last_damage_progress": 0.0,
		"hit_registry": {},
		"returned": false,
		"allow_return": allow_return,
		"allow_eclipse": allow_eclipse,
		"talent_ids": snapshot_talents.duplicate()
	})


func _update_crescent_projectiles(delta: float) -> void:
	if active_crescent_projectiles.is_empty():
		return
	for index in range(active_crescent_projectiles.size() - 1, -1, -1):
		var data: Dictionary = active_crescent_projectiles[index]
		var owner_ref: WeakRef = data.get("owner_ref", null) as WeakRef
		var owner = owner_ref.get_ref() if owner_ref != null else null
		var projectile := data.get("projectile", null) as Node2D
		if owner == null or not is_instance_valid(owner) or projectile == null or not is_instance_valid(projectile):
			if projectile != null and is_instance_valid(projectile):
				_free_projectile(projectile)
			active_crescent_projectiles.remove_at(index)
			continue
		if int(projectile.get_meta("crescent_projectile_token", -1)) != int(data.get("token", -1)):
			active_crescent_projectiles.remove_at(index)
			continue
		var duration: float = max(0.001, float(data.get("duration", 0.1)))
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var progress: float = clamp(elapsed / duration, 0.0, 1.0)
		var origin: Vector2 = data.get("origin", Vector2.ZERO)
		var direction: Vector2 = data.get("direction", Vector2.RIGHT)
		var length: float = float(data.get("length", 1.0))
		var current_position: Vector2 = origin + direction * (length * progress)
		projectile.global_position = current_position
		var damage_elapsed: float = float(data.get("damage_elapsed", 0.0))
		var last_damage_progress: float = float(data.get("last_damage_progress", 0.0))
		damage_elapsed += max(0.0, progress - last_damage_progress) * duration
		if damage_elapsed >= WAVE_DAMAGE_SAMPLE_INTERVAL or progress >= 1.0:
			data["last_damage_progress"] = progress
			data["damage_elapsed"] = 0.0
			var sample_length: float = max(52.0 * VISUAL_AND_HIT_SCALE, length * WAVE_DAMAGE_SAMPLE_INTERVAL / duration + 52.0 * VISUAL_AND_HIT_SCALE)
			var hit_registry: Dictionary = data.get("hit_registry", {})
			var talent_ids: Array = data.get("talent_ids", [])
			var slow_multiplier: float = 0.80 if _has_cast_talent(owner, talent_ids, "swordsman_crescent_frost_trail") else 1.0
			var slow_duration: float = 0.6 if slow_multiplier < 1.0 else 0.0
			var hit_count: int = owner._damage_enemies_in_oriented_rect_unique(current_position, direction, sample_length, float(data.get("width", 1.0)), float(data.get("damage_amount", 0.0)), 0.0, slow_multiplier, slow_duration, hit_registry, "swordsman")
			if hit_count > 0 and PLAYER_COMBAT_RESULT_FLOW.get_swordsman_blood_surge_multiplier(owner) > 1.0:
				PLAYER_COMBAT_RESULT_FLOW.consume_swordsman_blood_surge(owner)
			data["hit_registry"] = hit_registry
			if hit_count > 0 and not _uses_batched_damage(owner):
				owner._register_attack_result("swordsman", hit_count, false)
		else:
			data["damage_elapsed"] = damage_elapsed
		if elapsed >= duration:
			var talent_ids: Array = data.get("talent_ids", [])
			if bool(data.get("allow_return", true)) and not bool(data.get("returned", false)) and _has_cast_talent(owner, talent_ids, "swordsman_crescent_return"):
				data["origin"] = current_position
				data["direction"] = -direction
				data["damage_amount"] = float(data.get("damage_amount", 0.0)) * 0.60
				data["elapsed"] = 0.0
				data["damage_elapsed"] = 0.0
				data["last_damage_progress"] = 0.0
				data["hit_registry"] = {}
				data["returned"] = true
				projectile.rotation = (-direction).angle() + PI
				active_crescent_projectiles[index] = data
				continue
			if bool(data.get("allow_eclipse", true)) and _has_cast_talent(owner, talent_ids, "swordsman_crescent_eclipse"):
				var eclipse_damage: float = float(data.get("damage_amount", 0.0)) * 0.70
				owner._damage_enemies_in_radius(current_position, 86.0, eclipse_damage, 0.0, 1.0, 0.0, "swordsman")
				owner._spawn_ring_effect(current_position, 86.0, Color(0.46, 0.84, 1.0, 0.58), 6.0, 0.14)
			_free_projectile(projectile)
			active_crescent_projectiles.remove_at(index)
			continue
		data["elapsed"] = elapsed
		active_crescent_projectiles[index] = data


func _configure_crescent_visual(projectile: Node2D, visual_scale: float, width_multiplier: float = 1.0) -> void:
	var sprite: AnimatedSprite2D = projectile.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	sprite.centered = true
	sprite.position = Vector2.ZERO
	sprite.offset = FAN_SCENE_SIZE * 0.5 - (FAN_SCENE_VISIBLE_BOUNDS.position + FAN_SCENE_VISIBLE_BOUNDS.size * 0.5)
	sprite.modulate = Color.WHITE
	var target_visible_size: Vector2 = FAN_WAVE_BASE_VISIBLE_SIZE * visual_scale
	target_visible_size.y *= width_multiplier
	sprite.scale = Vector2(
		target_visible_size.x / max(1.0, FAN_SCENE_VISIBLE_BOUNDS.size.x),
		target_visible_size.y / max(1.0, FAN_SCENE_VISIBLE_BOUNDS.size.y)
	)
	if sprite.sprite_frames != null:
		var animation_name: StringName = sprite.animation
		var animation_names: PackedStringArray = sprite.sprite_frames.get_animation_names()
		if animation_name == StringName() and animation_names.size() > 0:
			animation_name = StringName(animation_names[0])
		if animation_name != StringName():
			sprite.sprite_frames.set_animation_loop(animation_name, true)
			sprite.animation = animation_name
			sprite.frame = 0
			sprite.frame_progress = 0.0
			sprite.play(animation_name)


func _free_projectile(projectile: Node2D) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	if bool(projectile.get_meta("crescent_projectile_released", false)):
		return
	projectile.set_meta("crescent_projectile_released", true)
	projectile.hide()
	projectile.remove_from_group("temporary_effects")
	var sprite: AnimatedSprite2D = projectile.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.stop()
	var parent := projectile.get_parent()
	if parent != null:
		parent.remove_child(projectile)
	if crescent_projectile_pool.size() < CRESCENT_PROJECTILE_POOL_LIMIT and not crescent_projectile_pool.has(projectile):
		crescent_projectile_pool.append(projectile)
	else:
		projectile.queue_free()


func _free_projectile_if_token(projectile: Node2D, spawn_token: int) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	if int(projectile.get_meta("crescent_projectile_token", -1)) != spawn_token:
		return
	_free_projectile(projectile)


func _acquire_projectile(current_scene: Node) -> Node2D:
	while not crescent_projectile_pool.is_empty():
		var pooled_projectile: Variant = crescent_projectile_pool.pop_back()
		if not is_instance_valid(pooled_projectile) or not (pooled_projectile is Node2D):
			continue
		var projectile := pooled_projectile as Node2D
		if projectile.is_queued_for_deletion():
			continue
		current_scene.add_child(projectile)
		projectile.show()
		projectile.add_to_group("temporary_effects")
		return projectile
	var projectile: Node2D = CRESCENT_SCENE.instantiate() as Node2D if CRESCENT_SCENE != null else Node2D.new()
	if projectile != null:
		current_scene.add_child(projectile)
		projectile.add_to_group("temporary_effects")
	return projectile


func _apply_damage_shapes(owner, shapes: Array[Dictionary]) -> int:
	if owner != null and owner.has_method("_damage_enemies_in_shapes_batched"):
		return int(owner._damage_enemies_in_shapes_batched(shapes))
	var hits := 0
	for shape in shapes:
		hits += int(owner._damage_enemies_in_oriented_rect_unique(
			shape.get("center", Vector2.ZERO),
			shape.get("axis", Vector2.RIGHT),
			float(shape.get("length", 1.0)),
			float(shape.get("width", 1.0)),
			float(shape.get("damage_amount", 0.0)),
			float(shape.get("vulnerability_bonus", 0.0)),
			float(shape.get("slow_multiplier", 1.0)),
			float(shape.get("slow_duration", 0.0)),
			shape.get("hit_registry", {}),
			str(shape.get("source_role_id", ""))
		))
	return hits

func _uses_batched_damage(owner) -> bool:
	return owner != null and owner.has_method("_damage_enemies_in_shapes_batched")


func _get_cast_directions(owner, base_direction: Vector2) -> Array[Vector2]:
	var directions: Array[Vector2] = [base_direction.normalized()]
	if _has_talent(owner, "swordsman_crescent_twin_moons"):
		directions.append(base_direction.rotated(deg_to_rad(18.0)).normalized())
	var extra_count: int = 0
	if owner != null and owner.has_method("_get_blessing_skill_quantity_count"):
		extra_count = int(owner._get_blessing_skill_quantity_count(SKILL_ID))
	for index in range(extra_count):
		directions.append(base_direction.rotated(deg_to_rad(30.0 * float(index + 1))).normalized())
	return directions


func _get_combo_scales(owner) -> Array[float]:
	if owner == null or not owner.has_method("_get_blessing_skill_combo_scales"):
		return []
	return owner._get_blessing_skill_combo_scales(SKILL_ID) as Array[float]


func _has_required_unlock(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))


func _get_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return int(owner._get_blessing_skill_tier(SKILL_ID))
	return 1


func _get_cooldown(owner) -> float:
	var cooldown_multiplier: float = PLAYER_BUILD_SYSTEM.get_crescent_wave_cooldown_multiplier(owner)
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		cooldown_multiplier *= float(owner._get_equipment_cooldown_multiplier())
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_kebiru_magic_cooldown_multiplier"):
		cooldown_multiplier *= float(owner._get_kebiru_magic_cooldown_multiplier(SKILL_ID))
	return COOLDOWN * cooldown_multiplier


func _get_width_multiplier(owner) -> float:
	var tier: int = _get_tier(owner)
	var tier_multiplier := 1.0
	if tier >= 3:
		tier_multiplier = TIER_THREE_WIDTH_MULTIPLIER
	elif tier >= 2:
		tier_multiplier = TIER_TWO_WIDTH_MULTIPLIER
	return tier_multiplier * _get_external_range_multiplier(owner)


func _get_range_multiplier(owner) -> float:
	return _get_external_range_multiplier(owner)


func _get_external_range_multiplier(owner) -> float:
	var range_multiplier: float = 1.0
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_skill_range_multiplier"):
		range_multiplier *= float(owner._get_equipment_skill_range_multiplier())
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_kebiru_magic_range_multiplier"):
		range_multiplier *= float(owner._get_kebiru_magic_range_multiplier(SKILL_ID))
	return range_multiplier


func _get_wave_speed(owner) -> float:
	var tier: int = _get_tier(owner)
	var base_speed: float = FULL_MOON_WAVE_SPEED if _has_talent(owner, "swordsman_crescent_full_moon") else BASE_WAVE_SPEED
	var speed: float = base_speed
	if tier >= 3:
		speed = base_speed * TIER_THREE_SPEED_MULTIPLIER
	elif tier >= 2:
		speed = base_speed * TIER_TWO_SPEED_MULTIPLIER
	return speed + PLAYER_BUILD_SYSTEM.get_crescent_wave_speed_bonus(owner)


func _has_talent(owner, talent_id: String) -> bool:
	if cast_talent_snapshot_valid:
		return cast_talent_ids.has(talent_id)
	return owner != null and owner.has_method("_has_skill_talent") and bool(owner._has_skill_talent(talent_id))


func _has_cast_talent(owner, talent_ids: Array, talent_id: String) -> bool:
	return talent_ids.has(talent_id) if cast_talent_snapshot_valid or not talent_ids.is_empty() else _has_talent(owner, talent_id)


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


func _serialize_projectile(data: Dictionary) -> Dictionary:
	var origin: Vector2 = data.get("origin", Vector2.ZERO)
	var direction: Vector2 = data.get("direction", Vector2.RIGHT)
	return {
		"origin": [origin.x, origin.y],
		"direction": [direction.x, direction.y],
		"length": float(data.get("length", 1.0)),
		"width": float(data.get("width", 1.0)),
		"visual_scale": float(data.get("visual_scale", VISUAL_AND_HIT_SCALE)),
		"damage_amount": float(data.get("damage_amount", 0.0)),
		"duration": float(data.get("duration", 0.1)),
		"elapsed": float(data.get("elapsed", 0.0)),
		"damage_elapsed": float(data.get("damage_elapsed", 0.0)),
		"last_damage_progress": float(data.get("last_damage_progress", 0.0)),
		"returned": bool(data.get("returned", false)),
		"allow_return": bool(data.get("allow_return", true)),
		"allow_eclipse": bool(data.get("allow_eclipse", true)),
		"talent_ids": _normalize_talent_ids(data.get("talent_ids", cast_talent_ids))
	}


func _decode_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


func _get_damage(owner) -> float:
	var tier: int = _get_tier(owner)
	if tier >= 3:
		return float(owner._get_role_damage("swordsman")) * TIER_THREE_DAMAGE_MULTIPLIER
	if tier >= 2:
		return float(owner._get_role_damage("swordsman")) * TIER_TWO_DAMAGE_MULTIPLIER
	return float(owner._get_role_damage("swordsman"))

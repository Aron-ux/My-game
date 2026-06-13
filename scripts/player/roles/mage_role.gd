extends RefCounted

const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")

const MAGE_ATTACK_EFFECT_SCALE := 0.8
const BASIC_COMBO_INTERVAL := 0.16
const ULTIMATE_SKILL_ID := "mage_ultimate"
const ULTIMATE_COMBO_INTERVAL := 0.18
const ULTIMATE_DURATION := 4.0
const ULTIMATE_BOMBARD_INTERVAL := 0.25
const ULTIMATE_BASE_DAMAGE_RATIO := 1.14
const ULTIMATE_GUNNER_ULTIMATE_OUTPUT_RATIO := 0.75
const ULTIMATE_BOSS_TARGET_WEIGHT := 0.35
const ULTIMATE_EXTRA_BOMBARDS := 8
const ULTIMATE_TIER_TWO_EXTRA_BOMBARDS := 6
const ULTIMATE_TIER_THREE_EXTRA_BOMBARDS := 3
const ENTRY_ARCANE_SURPLUS_DURATION := 5.0
const ENTRY_ARCANE_SURPLUS_STATUS_ID := "mage_arcane_surplus"
const ENTRY_LIGHTNING_COUNT := 5
const ENTRY_LIGHTNING_DISTANCE := 124.0
const ENTRY_LIGHTNING_RADIUS := 52.0 * MAGE_ATTACK_EFFECT_SCALE
const ENTRY_LIGHTNING_DAMAGE_SCALE := 1.0

func perform_attack(owner) -> void:
	var contexts: Array = _build_attack_contexts(owner)
	if (contexts[0] as Array).is_empty():
		return
	var base_contexts: Array = _get_attack_context_subset(contexts, 0, 1)
	var trick_context_count: int = max(0, (contexts[0] as Array).size() - 1)
	var trick_contexts: Array = _get_attack_context_subset(contexts, 1, trick_context_count)
	var combo_scales: Array[float] = [1.0]
	combo_scales.append_array(_get_skill_effect_scales(owner, "combo_skill_extra"))
	_spawn_basic_attack_warning_group(owner, contexts)
	_start_basic_attack_combo_sequence(owner, base_contexts, combo_scales, false)
	if not (trick_contexts[0] as Array).is_empty():
		_start_basic_attack_combo_sequence(owner, trick_contexts, [1.0], false)
	owner._spawn_attack_aftershock((base_contexts[0] as Array)[0], str((base_contexts[3] as Array)[0]))

func _perform_combo_segment(owner, contexts: Array, combo_scale: float) -> void:
	var centers: Array = contexts[0]
	for index in range(centers.size()):
		_cast_attack_context(owner, contexts, index, combo_scale, index == 0)

func _start_basic_attack_combo_sequence(owner, contexts: Array, combo_scales: Array[float], spawn_warning: bool = true) -> void:
	if combo_scales.is_empty():
		return
	if owner.get_tree() == null:
		for combo_index in range(combo_scales.size()):
			_perform_combo_segment(owner, contexts, float(combo_scales[combo_index]))
		return

	var warning_duration: float = owner._get_scene_animation_duration(owner.MAGE_WARNING_EFFECT_SCENE, 0.2)
	var boom_duration: float = owner._get_scene_animation_duration(owner.MAGE_BOOM_EFFECT_SCENE, 0.3)
	if spawn_warning:
		_spawn_basic_attack_warning_group(owner, contexts)
	if not owner.has_method("_schedule_repeating_sequence"):
		for combo_index in range(combo_scales.size()):
			var combo_scale: float = float(combo_scales[combo_index])
			_spawn_basic_attack_boom_group(owner, contexts, combo_scale)
			_resolve_basic_attack_group(owner, contexts, combo_scale)
		return
	for combo_index in range(combo_scales.size()):
		var combo_scale: float = float(combo_scales[combo_index])
		var boom_delay: float = warning_duration + float(combo_index) * boom_duration
		var resolve_delay: float = boom_delay + boom_duration
		owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
			if is_instance_valid(owner):
				_spawn_basic_attack_boom_group(owner, contexts, combo_scale)
		, boom_delay)
		owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
			if is_instance_valid(owner):
				_resolve_basic_attack_group(owner, contexts, combo_scale)
		, resolve_delay)

func _perform_combo_segment_if_valid(owner, contexts: Array, combo_scale: float) -> void:
	if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
		return
	_perform_combo_segment(owner, contexts, combo_scale)

func _spawn_basic_attack_warning_group(owner, contexts: Array) -> void:
	var centers: Array = contexts[0]
	var radii: Array = contexts[1]
	for index in range(centers.size()):
		owner._spawn_mage_warning_scene_effect(centers[index], float(radii[index]))

func _spawn_basic_attack_boom_group(owner, contexts: Array, combo_scale: float) -> void:
	var centers: Array = contexts[0]
	var radii: Array = contexts[1]
	for index in range(centers.size()):
		owner._spawn_mage_boom_scene_effect(centers[index], float(radii[index]))

func _resolve_basic_attack_group(owner, contexts: Array, combo_scale: float) -> void:
	if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
		return
	var centers: Array = contexts[0]
	for index in range(centers.size()):
		_resolve_basic_attack_context(owner, contexts, index, combo_scale, index == 0)

func _resolve_basic_attack_context(owner, contexts: Array, index: int, combo_scale: float, advance_attack_chain: bool) -> void:
	var centers: Array = contexts[0]
	var radii: Array = contexts[1]
	var damages: Array = contexts[2]
	var role_ids: Array = contexts[3]
	var center: Vector2 = centers[index]
	var radius: float = float(radii[index])
	var damage_amount: float = float(damages[index]) * max(0.0, combo_scale)
	owner._resolve_basic_mage_bombardment_damage(center, radius, damage_amount, 0.0, 1.0, 0.0, 0, 0, 0, str(role_ids[index]), true, advance_attack_chain)

func _get_attack_context_subset(contexts: Array, start_index: int, count: int) -> Array:
	var source_centers: Array = contexts[0]
	var source_radii: Array = contexts[1]
	var source_damages: Array = contexts[2]
	var source_role_ids: Array = contexts[3]
	var centers: Array[Vector2] = []
	var radii: Array[float] = []
	var damages: Array[float] = []
	var role_ids: Array[String] = []
	var first_index: int = max(0, start_index)
	var end_index: int = min(source_centers.size(), first_index + max(0, count))
	for index in range(first_index, end_index):
		centers.append(source_centers[index])
		radii.append(float(source_radii[index]))
		damages.append(float(source_damages[index]))
		role_ids.append(str(source_role_ids[index]))
	return [centers, radii, damages, role_ids]

func _build_attack_contexts(owner) -> Array:
	var role_data: Dictionary = owner._get_active_role()
	var upgrade_data: Dictionary = owner.role_upgrade_levels[role_data["id"]]
	var special_data: Dictionary = owner._get_role_special_state("mage")
	var arcane_focus_level: float = 0.0
	var bombard_center: Vector2 = owner._get_mage_mouse_bombard_center(float(role_data["range"]) + float(upgrade_data.get("range_bonus", 0.0)))
	var centers: Array[Vector2] = [bombard_center]
	for target in owner._get_enemy_targets(_get_skill_effect_scales(owner, "quantity_skill_count").size(), false):
		if target != null and is_instance_valid(target):
			var target_center: Vector2 = target.global_position
			if target_center.distance_to(bombard_center) >= 32.0:
				centers.append(target_center)
	while centers.size() < 1 + _get_skill_effect_scales(owner, "quantity_skill_count").size():
		var angle: float = TAU * float(centers.size()) / float(max(2, 1 + _get_skill_effect_scales(owner, "quantity_skill_count").size()))
		centers.append(bombard_center + Vector2.RIGHT.rotated(angle) * 72.0)
	var context_centers: Array[Vector2] = []
	var context_radii: Array[float] = []
	var context_damages: Array[float] = []
	var context_role_ids: Array[String] = []
	var quantity_scales: Array[float] = [1.0]
	quantity_scales.append_array(_get_skill_effect_scales(owner, "quantity_skill_count"))
	for index in range(centers.size()):
		var center: Vector2 = centers[index]
		var effect_scale: float = float(quantity_scales[min(index, quantity_scales.size() - 1)])
		var context: Array = _build_attack_context(owner, role_data, upgrade_data, special_data, center, effect_scale, arcane_focus_level)
		context_centers.append(context[0])
		context_radii.append(float(context[1]))
		context_damages.append(float(context[2]))
		context_role_ids.append(str(context[3]))
	return [context_centers, context_radii, context_damages, context_role_ids]

func _build_attack_context(owner, role_data: Dictionary, upgrade_data: Dictionary, _special_data: Dictionary, bombard_center: Vector2, effect_scale: float, arcane_focus_level: float) -> Array:
	var target_enemy: Node2D = owner._get_enemy_near_position(bombard_center, 56.0 + float(upgrade_data.get("range_bonus", 0.0)) * 0.25)
	var radius: float = (44.0 + float(upgrade_data["range_bonus"]) * 0.55) * owner._get_story_style_range_multiplier(role_data["id"])
	radius *= owner._get_role_attribute_range_multiplier("mage")
	radius *= owner._get_mage_arcane_focus_range_multiplier(arcane_focus_level)
	radius *= _get_basic_attack_range_multiplier(owner)
	var damage_amount: float = owner._get_role_damage(role_data["id"]) * 0.96 * max(0.0, effect_scale)
	if target_enemy != null:
		damage_amount *= owner._get_priority_target_bonus(target_enemy)
	radius *= MAGE_ATTACK_EFFECT_SCALE
	return [bombard_center, radius, damage_amount, str(role_data["id"]), arcane_focus_level]

func _cast_attack_context(owner, contexts: Array, index: int, scale: float, advance_attack_chain: bool) -> void:
	var centers: Array = contexts[0]
	var radii: Array = contexts[1]
	var damages: Array = contexts[2]
	var role_ids: Array = contexts[3]
	var bombard_center: Vector2 = centers[index]
	var radius: float = float(radii[index])
	var damage_amount: float = float(damages[index]) * max(0.0, scale)
	owner._start_basic_mage_bombardment(bombard_center, radius, damage_amount, 0.0, 1.0, 0.0, 0, 0, 0, str(role_ids[index]), true, advance_attack_chain)

func _get_skill_effect_scales(owner, stat: String) -> Array[float]:
	if owner != null and owner.has_method("_get_skill_blessing_effect_scales_for_skill"):
		return owner._get_skill_blessing_effect_scales_for_skill("mage_basic_attack", stat)
	if owner != null and owner.has_method("_get_skill_blessing_effect_scales"):
		return owner._get_skill_blessing_effect_scales(stat)
	return []

func _get_basic_attack_range_multiplier(owner) -> float:
	if owner != null and owner.has_method("_get_basic_attack_range_multiplier"):
		return float(owner._get_basic_attack_range_multiplier("mage_basic_attack"))
	return 1.0

func _start_evolved_arcane_bombardment(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, third_tier: bool = false) -> void:
	owner._start_basic_mage_bombardment(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, true, false)
	var followup_count: int = 2 if third_tier else 1
	if owner.get_tree() == null or not owner.has_method("_schedule_repeating_sequence"):
		for followup_index in range(followup_count):
			owner._resolve_basic_mage_bombardment_damage(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, true, followup_index == followup_count - 1)
		return
	var first_damage_delay: float = owner._get_scene_animation_duration(owner.MAGE_WARNING_EFFECT_SCENE, 0.2) + owner._get_scene_animation_duration(owner.MAGE_BOOM_EFFECT_SCENE, 0.3)
	var boom_duration: float = owner._get_scene_animation_duration(owner.MAGE_BOOM_EFFECT_SCENE, 0.3)
	for followup_index in range(followup_count):
		var boom_delay: float = first_damage_delay + 0.06 + float(followup_index) * (boom_duration + 0.06)
		var resolve_delay: float = boom_delay + boom_duration
		owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
			if is_instance_valid(owner):
				owner._spawn_mage_boom_scene_effect(center, radius)
		, boom_delay)
		var advance_chain := followup_index == followup_count - 1
		owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
			if is_instance_valid(owner):
				owner._resolve_basic_mage_bombardment_damage(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, true, advance_chain)
		, resolve_delay)

func perform_background(owner) -> void:
	var special_data: Dictionary = owner._get_role_special_state("mage")
	var support_level: int = int(special_data.get("support_level", 0))
	var frost_level: int = int(special_data.get("frost_level", 0))
	var echo_level: int = int(special_data.get("echo_level", 0))
	var gravity_level: int = int(special_data.get("gravity_level", 0))
	var cluster_position: Vector2 = owner._get_enemy_cluster_center()
	if cluster_position == Vector2.ZERO:
		var target_enemy: Node2D = owner._get_closest_enemy()
		if target_enemy == null:
			return
		cluster_position = owner._get_enemy_aim_point(target_enemy, owner.global_position) if owner.has_method("_get_enemy_aim_point") else target_enemy.global_position

	var radius: float = (44.0 + support_level * 8.0 + echo_level * 4.0 + frost_level * 4.0) * MAGE_ATTACK_EFFECT_SCALE * owner._get_role_attribute_range_multiplier("mage")
	var damage_amount: float = owner._get_role_damage("mage") * (0.32 + support_level * 0.06)
	var vulnerability_bonus: float = 0.02 * frost_level
	var slow_multiplier: float = max(0.62, 0.84 - frost_level * 0.05)
	var slow_duration: float = 1.2 + support_level * 0.18
	owner._start_basic_mage_bombardment(cluster_position, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, "mage", true, false)

	if support_level > 0:
		var secondary_targets: Array = owner._get_enemy_targets(2, false)
		for secondary_target in secondary_targets:
			if secondary_target == null or not is_instance_valid(secondary_target):
				continue
			var secondary_center: Vector2 = owner._get_enemy_aim_point(secondary_target, cluster_position) if owner.has_method("_get_enemy_aim_point") else secondary_target.global_position
			if secondary_center.distance_to(cluster_position) < 40.0:
				continue
			owner._start_basic_mage_bombardment(
				secondary_center,
				(34.0 + support_level * 5.0) * MAGE_ATTACK_EFFECT_SCALE,
				owner._get_role_damage("mage") * (0.18 + support_level * 0.04),
				0.0,
				max(0.66, 0.86 - frost_level * 0.04),
				1.0,
				max(0, gravity_level - 1),
				min(echo_level, 1),
				frost_level,
				"mage",
				true,
				false
			)
			break

func perform_enter(owner, role_id: String, _assault_level: int, _assault_multiplier: float) -> int:
	owner._show_switch_banner("\u8FDB\u573A", "\u5BC6\u96C6\u96F7\u7FA4", Color(0.34, 0.72, 1.0, 1.0))
	var hit_count: int = _cast_entry_lightning_ring(owner, role_id)
	owner.mage_arcane_surplus_remaining = ENTRY_ARCANE_SURPLUS_DURATION
	owner._start_duration_status(ENTRY_ARCANE_SURPLUS_STATUS_ID, "\u5965\u6CD5\u76C8\u4F59", ENTRY_ARCANE_SURPLUS_DURATION, 18, Color(0.34, 0.72, 1.0, 0.95))
	return hit_count

func _cast_entry_lightning_ring(owner, role_id: String) -> int:
	var centers: Array[Vector2] = []
	var base_direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	for index in range(ENTRY_LIGHTNING_COUNT):
		var angle_offset: float = TAU * float(index) / float(ENTRY_LIGHTNING_COUNT)
		var direction: Vector2 = base_direction.rotated(angle_offset).normalized()
		centers.append(owner.global_position + direction * ENTRY_LIGHTNING_DISTANCE)
	for center in centers:
		owner._spawn_mage_warning_scene_effect(center, ENTRY_LIGHTNING_RADIUS)
	var damage_amount: float = owner._get_role_damage(role_id) * ENTRY_LIGHTNING_DAMAGE_SCALE
	if owner.get_tree() == null or not owner.has_method("_schedule_repeating_sequence"):
		return _resolve_entry_lightning_ring(owner, role_id, centers, damage_amount)
	var warning_duration: float = owner._get_scene_animation_duration(owner.MAGE_WARNING_EFFECT_SCENE, 0.2)
	owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
		if is_instance_valid(owner):
			_resolve_entry_lightning_ring(owner, role_id, centers, damage_amount)
	, warning_duration)
	return 0

func _resolve_entry_lightning_ring(owner, role_id: String, centers: Array[Vector2], damage_amount: float) -> int:
	var total_hits: int = 0
	for center in centers:
		owner._spawn_mage_boom_scene_effect(center, ENTRY_LIGHTNING_RADIUS)
		total_hits += owner._damage_enemies_in_radius(center, ENTRY_LIGHTNING_RADIUS, damage_amount, 0.0, 1.0, 0.0, role_id)
	return total_hits

func perform_exit(_owner, _role_id: String, _rearguard_level: int) -> int:
	return 0

func perform_ultimate(owner, cast_payload: Dictionary) -> void:
	var special_data: Dictionary = owner._get_role_special_state("mage")
	var storm_level: int = int(special_data.get("storm_level", 0))
	var center: Vector2 = owner._get_enemy_cluster_center()
	if center == Vector2.ZERO:
		center = owner.global_position
	var ultimate_tier: int = _get_ultimate_skill_tier(owner)
	var total_duration: float = _get_ultimate_duration(owner, cast_payload)
	var bombard_count: int = max(1, int(floor(total_duration / ULTIMATE_BOMBARD_INTERVAL)))
	var combo_scales: Array[float] = _get_ultimate_combo_scales(owner)
	var bombard_scales: Array[float] = _build_ultimate_segment_scales(bombard_count, combo_scales)
	var total_sequence_duration: float = 0.28 + float(bombard_scales.size() - 1) * ULTIMATE_BOMBARD_INTERVAL
	owner._queue_camera_shake(18.5, 0.58)
	owner._delay_level_up_requests(total_sequence_duration)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -34.0), "奥数轰炸", Color(0.82, 0.96, 1.0, 1.0))
	owner._spawn_ring_effect(center, 118.0 + storm_level * 10.0, Color(0.72, 0.96, 1.0, 0.82), 10.0, 0.22)
	_schedule_ultimate_bombardment_sequence(owner, bombard_scales, storm_level, _get_ultimate_damage_multiplier(owner, cast_payload), ultimate_tier, center, 0.0, total_sequence_duration)
	owner._apply_post_ultimate_bonuses("mage", total_sequence_duration)

func _schedule_ultimate_bombardment_sequence(owner, bombard_scales: Array[float], storm_level: int, cast_damage_multiplier: float, ultimate_tier: int, cast_center: Vector2, start_delay: float, surplus_delay: float = 0.0) -> void:
	var bombard_count: int = bombard_scales.size()
	var sequence_callback := func(pulse_index: int) -> void:
		_trigger_ultimate_bombardment(owner, bombard_scales, storm_level, cast_damage_multiplier, pulse_index, ultimate_tier, cast_center)
	if start_delay <= 0.0:
		owner._schedule_repeating_sequence(ULTIMATE_BOMBARD_INTERVAL, bombard_count, sequence_callback)
	else:
		owner._schedule_repeating_sequence(ULTIMATE_BOMBARD_INTERVAL, bombard_count, sequence_callback, start_delay)
	if surplus_delay <= 0.0 or not owner.has_method("_schedule_repeating_sequence"):
		owner.mage_arcane_surplus_remaining = max(owner.mage_arcane_surplus_remaining, ENTRY_ARCANE_SURPLUS_DURATION)
		owner._start_duration_status(ENTRY_ARCANE_SURPLUS_STATUS_ID, "\u5965\u6CD5\u76C8\u4F59", ENTRY_ARCANE_SURPLUS_DURATION, 18, Color(0.34, 0.72, 1.0, 0.95))
		return
	owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
		if not is_instance_valid(owner):
			return
		owner.mage_arcane_surplus_remaining = max(owner.mage_arcane_surplus_remaining, ENTRY_ARCANE_SURPLUS_DURATION)
		owner._start_duration_status(ENTRY_ARCANE_SURPLUS_STATUS_ID, "\u5965\u6CD5\u76C8\u4F59", ENTRY_ARCANE_SURPLUS_DURATION, 18, Color(0.34, 0.72, 1.0, 0.95))
	, surplus_delay)

func _trigger_ultimate_bombardment(owner, bombard_scales: Array[float], storm_level: int, cast_damage_multiplier: float, pulse_index: int, ultimate_tier: int = 1, cast_center: Vector2 = Vector2.ZERO) -> void:
	if owner.is_dead:
		return

	var pulse_count: int = bombard_scales.size()
	var effect_scale: float = 1.0
	if pulse_index >= 0 and pulse_index < pulse_count:
		effect_scale = float(bombard_scales[pulse_index])
	var cluster_center: Vector2 = _get_ultimate_bombard_lock_center(owner, cast_center)
	if cluster_center == Vector2.ZERO:
		cluster_center = owner.global_position
	var phase: float = float(pulse_index) / float(max(1, pulse_count - 1))
	var orbit_angle: float = phase * TAU * 1.6
	var main_center: Vector2 = cluster_center + Vector2.RIGHT.rotated(orbit_angle) * (12.0 + 8.0 * sin(orbit_angle * 1.4))
	var tier_damage_multiplier: float = 1.16 if ultimate_tier >= 2 else 1.0
	var pulse_radius: float = (72.0 + storm_level * 9.0) * owner._get_story_style_range_multiplier("mage") * owner._get_role_attribute_range_multiplier("mage")
	var pulse_damage: float = owner._get_role_damage("mage") * (ULTIMATE_BASE_DAMAGE_RATIO + storm_level * 0.08) * cast_damage_multiplier * max(0.0, effect_scale) * tier_damage_multiplier * ULTIMATE_GUNNER_ULTIMATE_OUTPUT_RATIO
	owner._queue_camera_shake(6.4 + float(storm_level) * 0.28, 0.12)
	if _should_spawn_ultimate_pulse_visual(pulse_index):
		owner._spawn_ring_effect(main_center, pulse_radius, Color(0.72, 0.96, 1.0, 0.76), 6.0, 0.18)
		owner._spawn_burst_effect(main_center, pulse_radius, Color(0.5, 0.92, 1.0, 0.24), 0.2)
	var shape_hits: int = owner._damage_enemies_in_radius(
		main_center,
		pulse_radius,
		pulse_damage,
		0.0,
		1.0,
		0.0,
		"mage"
	)
	if shape_hits > 0 and not _uses_batched_damage(owner):
		owner._register_attack_result("mage", shape_hits, false)

func _get_ultimate_bombard_lock_center(owner, fallback_center: Vector2) -> Vector2:
	var priority_boss: Node2D = null
	if owner != null and owner.has_method("_get_priority_boss_target") and randf() <= ULTIMATE_BOSS_TARGET_WEIGHT:
		priority_boss = owner._get_priority_boss_target(owner.global_position)
	if priority_boss != null and is_instance_valid(priority_boss):
		return owner._get_enemy_aim_point(priority_boss, owner.global_position) if owner.has_method("_get_enemy_aim_point") else priority_boss.global_position
	var cluster_center: Vector2 = owner._get_enemy_cluster_center()
	if cluster_center != Vector2.ZERO:
		return cluster_center
	var target_enemy: Node2D = owner._get_closest_enemy()
	if target_enemy != null and is_instance_valid(target_enemy):
		return owner._get_enemy_aim_point(target_enemy, owner.global_position) if owner.has_method("_get_enemy_aim_point") else target_enemy.global_position
	return fallback_center

func _get_ultimate_skill_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return max(1, int(owner._get_blessing_skill_tier(ULTIMATE_SKILL_ID)))
	return 1

func _get_ultimate_combo_scales(owner) -> Array[float]:
	if owner != null and owner.has_method("_get_blessing_skill_combo_scales"):
		return owner._get_blessing_skill_combo_scales(ULTIMATE_SKILL_ID) as Array[float]
	return []

func _get_ultimate_duration(owner, cast_payload: Dictionary) -> float:
	var duration: float = ULTIMATE_DURATION * float(cast_payload.get("duration_multiplier", 1.0))
	if owner != null and owner.has_method("_get_blessing_skill_duration_multiplier"):
		duration *= float(owner._get_blessing_skill_duration_multiplier(ULTIMATE_SKILL_ID))
	if owner != null and owner.has_method("_get_blessing_skill_duration_flat_bonus"):
		duration += float(owner._get_blessing_skill_duration_flat_bonus(ULTIMATE_SKILL_ID))
	return max(ULTIMATE_BOMBARD_INTERVAL, duration)

func _get_ultimate_damage_multiplier(owner, cast_payload: Dictionary) -> float:
	var multiplier: float = float(cast_payload.get("damage_multiplier", 1.0))
	if owner != null and owner.has_method("_get_blessing_ultimate_damage_multiplier"):
		multiplier *= float(owner._get_blessing_ultimate_damage_multiplier(ULTIMATE_SKILL_ID))
	return multiplier

func _should_spawn_ultimate_pulse_visual(pulse_index: int) -> bool:
	var fps: int = Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return pulse_index % 3 == 0
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return pulse_index % 2 == 0
	return true

func _build_ultimate_segment_scales(base_count: int, combo_scales: Array[float]) -> Array[float]:
	var result: Array[float] = []
	for _index in range(max(0, base_count)):
		result.append(1.0)
	for scale in combo_scales:
		result.append(max(0.05, float(scale)))
	return result

func _apply_damage_shapes(owner, shapes: Array[Dictionary]) -> int:
	if owner != null and owner.has_method("_damage_enemies_in_shapes_batched"):
		return int(owner._damage_enemies_in_shapes_batched(shapes))
	var hits := 0
	for shape in shapes:
		hits += int(owner._damage_enemies_in_radius(
			shape.get("center", Vector2.ZERO),
			float(shape.get("radius", 1.0)),
			float(shape.get("damage_amount", 0.0)),
			float(shape.get("vulnerability_bonus", 0.0)),
			float(shape.get("slow_multiplier", 1.0)),
			float(shape.get("slow_duration", 0.0)),
			str(shape.get("source_role_id", ""))
		))
	return hits

func _uses_batched_damage(owner) -> bool:
	return owner != null and owner.has_method("_damage_enemies_in_shapes_batched")

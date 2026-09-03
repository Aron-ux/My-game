extends RefCounted

const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_COMBAT_RESULT_FLOW := preload("res://scripts/player/player_combat_result_flow.gd")
const PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW := preload("res://scripts/player/player_swordsman_trait_runtime_flow.gd")
const PLAYER_SWORDSMAN_ULTIMATE_FLOW := preload("res://scripts/player/player_swordsman_ultimate_flow.gd")

const BASIC_COMBO_INTERVAL := 0.14
const ULTIMATE_SKILL_ID := "swordsman_ultimate"
const ULTIMATE_BASE_DURATION := 3.0
const ULTIMATE_SLASH_INTERVAL := 0.2
const ULTIMATE_BASE_SLASH_DAMAGE_SCALE := 1.0
const ULTIMATE_GUNNER_ULTIMATE_OUTPUT_RATIO := 0.75
const ULTIMATE_BOSS_TARGET_WEIGHT := 0.35
const ULTIMATE_CRITICAL_BONUS_CHANCE := 0.20
const ULTIMATE_EXTRA_SLASHES := 0
const ULTIMATE_TIER_TWO_EXTRA_SLASHES := 0
const ULTIMATE_TIER_TWO_VISUAL_HIT_SCALE := 1.18
const ULTIMATE_TIER_TWO_DAMAGE_MULTIPLIER := 1.0
const ULTIMATE_TIER_THREE_EXTRA_SLASHES := 0
const ULTIMATE_TIER_THREE_VISUAL_HIT_SCALE := 1.38
const ULTIMATE_TIER_THREE_DAMAGE_MULTIPLIER := 1.0
const ENTRY_INVULNERABILITY_DURATION := 3.0
const POST_ULTIMATE_BLOODTHIRST_DURATION := 4.5
const LEVEL_TALENT_BASIC_ATTACK_1 := "swordsman_level_talent_basic_attack_1"
const LEVEL_TALENT_BASIC_ATTACK_2 := "swordsman_level_talent_basic_attack_2"
const LEVEL_TALENT_BLADE_STORM_2 := "swordsman_level_talent_blade_storm_2"
var ultimate_pursuit_target: WeakRef = null
var ultimate_pursuit_hits: int = 0
var ultimate_pursuit_armed: bool = false
var basic_damage_event_serial: int = 0

func get_talent_basic_attack_interval_multiplier(owner) -> float:
	if owner == null or owner.get("role_special_states") is not Dictionary:
		return 1.0
	var state: Dictionary = owner.role_special_states.get("swordsman", {})
	return 1.0 / 1.15 if float(state.get("head_high_remaining", 0.0)) > 0.0 else 1.0
func _try_start_bloodthirst(owner, duration: float, heal_multiplier: float, force_refresh: bool = false) -> bool:
	if owner == null or (owner.has_method("_get_active_role_id") and str(owner._get_active_role_id()) != "swordsman"):
		return false
	if not force_refresh and owner.swordsman_entry_trait_share_remaining > 0.0:
		return false
	if not force_refresh and owner.swordsman_bloodthirst_cooldown_remaining > 0.0:
		return false
	owner.swordsman_entry_trait_share_remaining = max(0.0, duration)
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, duration)
	owner.swordsman_bloodthirst_heal_multiplier = max(owner.swordsman_bloodthirst_heal_multiplier, heal_multiplier)
	if force_refresh:
		owner.swordsman_bloodthirst_cooldown_remaining = 0.0
	return true

func perform_attack(owner) -> void:
	if owner != null and owner.has_method("is_swordsman_blade_storm_active") and owner.is_swordsman_blade_storm_active() and not _can_basic_attack_during_blade_storm(owner):
		return
	var base_direction: Vector2 = owner._get_attack_aim_direction(owner.facing_direction)
	var blood_surge_multiplier := PLAYER_COMBAT_RESULT_FLOW.get_swordsman_blood_surge_multiplier(owner)
	var basic_source_id := _create_basic_source_id(owner)
	var total_hits := _perform_combo_segment(owner, base_direction, 1.0, true, true, blood_surge_multiplier, basic_source_id)
	total_hits += _apply_basic_talent_followup(owner, base_direction, blood_surge_multiplier, basic_source_id)
	if total_hits > 0 and blood_surge_multiplier > 1.0:
		PLAYER_COMBAT_RESULT_FLOW.consume_swordsman_blood_surge(owner)
	_schedule_level_basic_rehit(owner, base_direction, basic_source_id)
	_schedule_reprise_segments(owner, base_direction, basic_source_id)

func _create_basic_source_id(owner) -> String:
	if owner != null and owner.has_method("_create_basic_attack_source_id"):
		return str(owner._create_basic_attack_source_id("swordsman"))
	basic_damage_event_serial += 1
	return "swordsman_basic:%s:%s" % [owner.get_instance_id() if owner != null else 0, basic_damage_event_serial]

func _apply_basic_talent_followup(owner, base_direction: Vector2, blood_surge_multiplier: float, basic_source_id: String) -> int:
	var total_hits := 0
	if _has_talent(owner, "swordsman_basic_back"):
		total_hits += _perform_attack_variant(owner, -base_direction, 0.45, false, false, false, blood_surge_multiplier, basic_source_id)
	if not _has_talent(owner, "swordsman_basic_cross"):
		pass
	elif owner.swordsman_attack_chain == 0:
		total_hits += _perform_attack_variant(owner, base_direction.rotated(PI * 0.5), 0.70, false, false, false, blood_surge_multiplier, basic_source_id)
	if owner.swordsman_attack_chain == 0 and _has_talent(owner, "swordsman_basic_sword_wheel"):
		total_hits += _perform_attack_variant(owner, base_direction.rotated(PI * 0.5), 0.35, false, false, false, blood_surge_multiplier, basic_source_id)
		total_hits += _perform_attack_variant(owner, base_direction.rotated(-PI * 0.5), 0.35, false, false, false, blood_surge_multiplier, basic_source_id)
	return total_hits

func _perform_combo_segment(owner, base_direction: Vector2, combo_scale: float, allow_trick_variants: bool = true, allow_followthrough: bool = true, blood_surge_multiplier: float = -1.0, basic_source_id: String = "") -> int:
	var consumes_blood_surge := blood_surge_multiplier < 0.0
	if consumes_blood_surge:
		blood_surge_multiplier = PLAYER_COMBAT_RESULT_FLOW.get_swordsman_blood_surge_multiplier(owner)
	var total_hits: int = 0
	if owner.has_method("_push_attack_result_context_tag"):
		owner._push_attack_result_context_tag("swordsman_basic_attack")
	total_hits += _perform_attack_variant(owner, base_direction, combo_scale, true, true, allow_followthrough, blood_surge_multiplier, basic_source_id)
	if _has_level_talent(owner, LEVEL_TALENT_BASIC_ATTACK_2):
		total_hits += _perform_attack_variant(owner, base_direction.rotated(deg_to_rad(30.0)), combo_scale, false, true, allow_followthrough, blood_surge_multiplier, basic_source_id)
	if allow_trick_variants:
		total_hits += _apply_trick_variants(owner, base_direction, blood_surge_multiplier, basic_source_id)
	if total_hits > 0 and not _uses_batched_basic_attack_damage(owner):
		var role_data: Dictionary = owner._get_active_role()
		owner._register_attack_result(role_data["id"], total_hits, false)
	if owner.has_method("_pop_attack_result_context_tag"):
		owner._pop_attack_result_context_tag("swordsman_basic_attack")
	if consumes_blood_surge and total_hits > 0 and blood_surge_multiplier > 1.0:
		PLAYER_COMBAT_RESULT_FLOW.consume_swordsman_blood_surge(owner)
	return total_hits

func _perform_attack_variant(owner, attack_direction: Vector2, effect_scale: float = 1.0, advance_chain: bool = true, spawn_aftershock: bool = true, allow_followthrough: bool = false, blood_surge_multiplier: float = 1.0, basic_source_id: String = "") -> int:
	var role_data: Dictionary = owner._get_active_role()
	var upgrade_data: Dictionary = owner.role_upgrade_levels[role_data["id"]]
	if attack_direction.length_squared() <= 0.001:
		attack_direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	attack_direction = attack_direction.normalized()
	var heart_level: float = 0.0
	var normal_attack_scale: float = owner._get_swordsman_normal_attack_scale(heart_level)
	var normal_attack_width_scale: float = owner._get_swordsman_normal_attack_width_scale(heart_level)
	var basic_range_multiplier: float = _get_basic_attack_range_multiplier(owner)
	if _has_talent(owner, "swordsman_basic_pursuit"):
		basic_range_multiplier *= 1.25
	var attack_range: float = (float(role_data["range"]) + float(upgrade_data.get("range_bonus", 0.0))) * owner._get_role_attribute_range_multiplier(role_data["id"]) * owner._get_role_equipment_skill_range_multiplier(role_data["id"]) * basic_range_multiplier
	var third_main_slash: bool = advance_chain and owner.swordsman_attack_chain == 2
	var opening_damage_multiplier: float = 1.20 if third_main_slash and _has_talent(owner, "swordsman_basic_opening") else 1.0
	var attack_damage: float = owner._get_role_damage(role_data["id"]) * 1.5 * max(0.0, effect_scale) * PLAYER_BUILD_SYSTEM.get_basic_attack_damage_multiplier(owner, "swordsman") * opening_damage_multiplier * blood_surge_multiplier
	var slash_axis: Vector2 = owner._get_downward_perpendicular(attack_direction)
	var slash_mirror: bool = attack_direction.x > 0.0
	var slash_length: float = (58.0 + float(upgrade_data.get("range_bonus", 0.0)) * 0.19) * owner._get_role_attribute_range_multiplier(role_data["id"]) * owner._get_role_equipment_skill_range_multiplier(role_data["id"]) * basic_range_multiplier
	var slash_width: float = 8.0 * normal_attack_width_scale * basic_range_multiplier
	if _has_talent(owner, "swordsman_basic_pursuit"):
		slash_width *= 1.20 / 1.25
	var slash_forward_distance: float = 42.0
	var slash_color: Color = Color(1.0, 0.74, 0.34, 0.95)
	slash_length *= normal_attack_scale
	var slash_visual_width: float = _get_slash_visual_width(slash_width)
	var slash_mirror_forward_offset: float = _get_slash_mirror_forward_offset(owner, slash_visual_width)
	var slash_center: Vector2 = owner.global_position + attack_direction * (slash_forward_distance + slash_mirror_forward_offset)
	var slash_effect_center: Vector2 = slash_center - attack_direction * slash_mirror_forward_offset if slash_mirror else slash_center

	owner._spawn_sword_slash_scene_effect(
		slash_effect_center,
		slash_axis,
		slash_length * 0.5,
		slash_color,
		0.16,
		slash_width,
		slash_mirror
	)
	var slash_hit_registry: Dictionary = {}
	var slash_rect_width: float = max(slash_visual_width, slash_center.distance_to(owner.global_position) * 2.0 + 16.0)
	var slash_animation_duration: float = owner._get_sword_slash_scene_animation_duration()
	var slow_multiplier: float = 0.75 if third_main_slash and _has_talent(owner, "swordsman_basic_opening") else 1.0
	var slow_duration: float = 1.0 if slow_multiplier < 1.0 else 0.0
	var damage_source_id := basic_source_id if basic_source_id != "" else str(role_data["id"])
	var enemies_hit: int = owner._damage_enemies_in_oriented_rect_unique(slash_center, slash_axis, slash_length, slash_rect_width, attack_damage, 0.0, slow_multiplier, slow_duration, slash_hit_registry, damage_source_id)
	if allow_followthrough:
		owner._schedule_swordsman_slash_followthrough(slash_center, slash_axis, slash_length, slash_rect_width, attack_damage, 0.0, slow_multiplier, slow_duration, slash_animation_duration, damage_source_id, slash_hit_registry)

	if advance_chain:
		owner.swordsman_attack_chain = (owner.swordsman_attack_chain + 1) % 3

	if spawn_aftershock:
		owner._spawn_attack_aftershock(owner.global_position + attack_direction * max(26.0, attack_range * 0.55), role_data["id"])

	return enemies_hit

func _schedule_reprise_segments(owner, base_direction: Vector2, basic_source_id: String) -> void:
	var combo_scales := _get_skill_effect_scales(owner, "combo_skill_extra")
	if combo_scales.is_empty():
		return
	owner._schedule_repeating_sequence(BASIC_COMBO_INTERVAL, combo_scales.size(), func(index: int) -> void:
		if index >= 0 and index < combo_scales.size():
			_perform_combo_segment_if_valid(owner, base_direction, float(combo_scales[index]), basic_source_id)
	, BASIC_COMBO_INTERVAL)

func _perform_combo_segment_if_valid(owner, base_direction: Vector2, combo_scale: float, basic_source_id: String) -> void:
	if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
		return
	if owner.has_method("is_swordsman_blade_storm_active") and owner.is_swordsman_blade_storm_active() and not _can_basic_attack_during_blade_storm(owner):
		return
	_perform_combo_segment(owner, base_direction, combo_scale, false, false, -1.0, basic_source_id)

func _schedule_level_basic_rehit(owner, base_direction: Vector2, basic_source_id: String) -> void:
	if not _has_level_talent(owner, LEVEL_TALENT_BASIC_ATTACK_1):
		return
	var callback := func(_index: int) -> void:
		_perform_combo_segment_if_valid(owner, base_direction, 0.60, basic_source_id)
	if owner.has_method("_schedule_repeating_sequence"):
		owner._schedule_repeating_sequence(0.10, 1, callback, 0.10)
	else:
		callback.call(0)

func _apply_trick_variants(owner, base_direction: Vector2, blood_surge_multiplier: float, basic_source_id: String) -> int:
	var total_hits := 0
	var index := 1
	for scale in _get_skill_effect_scales(owner, "quantity_skill_count"):
		var direction := base_direction.rotated(deg_to_rad(30.0 * float(index)))
		total_hits += _perform_attack_variant(owner, direction, float(scale), false, false, false, blood_surge_multiplier, basic_source_id)
		index += 1
	return total_hits

func _get_skill_effect_scales(owner, stat: String) -> Array[float]:
	if owner != null and owner.has_method("_get_skill_blessing_effect_scales_for_skill"):
		return owner._get_skill_blessing_effect_scales_for_skill("swordsman_basic_attack", stat)
	if owner != null and owner.has_method("_get_skill_blessing_effect_scales"):
		return owner._get_skill_blessing_effect_scales(stat)
	return []

func _get_basic_attack_range_multiplier(owner) -> float:
	var multiplier: float = 1.0
	if owner != null and owner.has_method("_get_basic_attack_range_multiplier"):
		multiplier *= float(owner._get_basic_attack_range_multiplier("swordsman_basic_attack"))
	multiplier *= PLAYER_BUILD_SYSTEM.get_basic_attack_range_multiplier(owner, "swordsman")
	if _has_level_talent(owner, LEVEL_TALENT_BASIC_ATTACK_2):
		multiplier *= 1.25
	return multiplier

func _uses_batched_basic_attack_damage(owner) -> bool:
	return owner != null and owner.has_method("_damage_enemies_in_oriented_rect_unique")

func perform_background(owner) -> void:
	var target_enemy: Node2D = owner._get_low_health_enemy()
	if target_enemy == null:
		target_enemy = owner._get_closest_enemy()
	if target_enemy == null:
		return

	var special_data: Dictionary = owner._get_role_special_state("swordsman")
	var crescent_level: int = int(special_data.get("crescent_level", 0))
	var thrust_level: int = int(special_data.get("thrust_level", 0))
	var blood_surge_multiplier := PLAYER_COMBAT_RESULT_FLOW.get_swordsman_blood_surge_multiplier(owner)
	var damage_amount: float = owner._get_role_damage("swordsman") * 0.44 * blood_surge_multiplier
	var hit_direction: Vector2 = owner.global_position.direction_to(target_enemy.global_position)
	var killed: bool = false
	owner._spawn_slash_effect(target_enemy.global_position - hit_direction * 10.0, hit_direction, 46.0, 12.0, Color(1.0, 0.74, 0.36, 0.65), 0.1)
	killed = owner._deal_damage_to_enemy(target_enemy, damage_amount, "swordsman")
	if blood_surge_multiplier > 1.0:
		PLAYER_COMBAT_RESULT_FLOW.consume_swordsman_blood_surge(owner)
	if crescent_level >= 2:
		owner._spawn_slash_effect(target_enemy.global_position, hit_direction.rotated(0.9), 42.0, 10.0, Color(1.0, 0.86, 0.48, 0.55), 0.1)
		owner._spawn_ring_effect(target_enemy.global_position, 34.0 + crescent_level * 5.0, Color(0.42, 0.84, 1.0, 0.32), 4.0, 0.12)
		owner._damage_enemies_in_radius(target_enemy.global_position, 34.0 + crescent_level * 5.0, damage_amount * 0.45, 0.0, 1.0, 0.0)
	if thrust_level >= 2:
		var bg_thrust_width: float = 14.0 + thrust_level * 2.0
		owner._spawn_thrust_effect(owner.global_position, target_enemy.global_position, Color(1.0, 0.24, 0.12, 0.82), bg_thrust_width, 0.12)
		owner._damage_enemies_in_line(owner.global_position, target_enemy.global_position, bg_thrust_width, damage_amount * 0.5, 0.04 * thrust_level, 1.0, 0.0, "swordsman")
	owner._register_attack_result("swordsman", 1, killed)

func perform_enter(owner, role_id: String, _assault_level: int, assault_multiplier: float) -> int:
	var previous_position: Vector2 = owner.global_position
	var travel_direction: Vector2 = owner._get_live_mouse_aim_direction(owner.facing_direction)
	if travel_direction.length_squared() <= 0.001:
		travel_direction = Vector2.RIGHT
	var dash_distance: float = 160.0
	owner.global_position += travel_direction * dash_distance
	if owner.has_method("_clamp_to_active_map_bounds"):
		owner._clamp_to_active_map_bounds()
	owner.facing_direction = travel_direction
	owner._show_switch_banner("\u8FDB\u573A", "\u7A81\u8FDB\u7834\u9635", Color(1.0, 0.84, 0.46, 1.0))
	var scar_width: float = 32.0 * (1.40 if _has_talent(owner, "swordsman_entry_through_ranks") else 1.0)
	var scar_end: Vector2 = owner.global_position + travel_direction * 84.0
	var scar_center: Vector2 = previous_position.lerp(scar_end, 0.5)
	var scar_length: float = previous_position.distance_to(scar_end)
	owner._spawn_sword_omnislash_scene_effect(scar_center, travel_direction, scar_length, scar_width * 1.08)
	_try_start_bloodthirst(owner, ENTRY_INVULNERABILITY_DURATION, 1.0)
	PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW.activate_charge_talents(owner)
	owner._push_attack_result_context_tag("suppress_swordsman_trait_heal")
	owner._push_attack_result_context_tag("suppress_greed_heal")
	var blood_surge_multiplier := PLAYER_COMBAT_RESULT_FLOW.get_swordsman_blood_surge_multiplier(owner)
	var entry_damage: float = owner._get_role_damage(role_id) * 1.5 * max(0.0, assault_multiplier) * blood_surge_multiplier
	var slow_multiplier: float = 0.70 if _has_talent(owner, "swordsman_entry_break_formation") else 1.0
	var slow_duration: float = 0.8 if slow_multiplier < 1.0 else 0.0
	var hits: int = owner._damage_enemies_in_line(previous_position, scar_end, scar_width, entry_damage, 0.1, slow_multiplier, slow_duration, role_id)
	if hits > 0 and blood_surge_multiplier > 1.0:
		PLAYER_COMBAT_RESULT_FLOW.consume_swordsman_blood_surge(owner)
	owner._pop_attack_result_context_tag("suppress_greed_heal")
	owner._pop_attack_result_context_tag("suppress_swordsman_trait_heal")
	if hits > 0 and _has_talent(owner, "swordsman_entry_long_charge"):
		owner._schedule_repeating_sequence(0.12, 1, func(_index: int) -> void:
			_perform_entry_talent_dash(owner, role_id, travel_direction, 120.0, assault_multiplier * 0.70, Vector2.ZERO, false, true)
		, 0.12)
	elif _has_talent(owner, "swordsman_entry_return_guard"):
		owner._schedule_repeating_sequence(0.18, 1, func(_index: int) -> void:
			_perform_entry_talent_dash(owner, role_id, travel_direction, 0.0, assault_multiplier * 0.70, previous_position, true, true)
		, 0.18)
	else:
		_finish_entry_talent_segment(owner, role_id, previous_position, scar_end, assault_multiplier)
	_apply_entry_hit_talents(owner, hits)
	return hits

func _perform_entry_talent_dash(owner, role_id: String, direction: Vector2, distance: float, damage_scale: float, fixed_destination: Vector2 = Vector2.ZERO, use_fixed_destination: bool = false, is_final: bool = false) -> void:
	if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
		return
	var start_position: Vector2 = owner.global_position
	var end_position: Vector2 = fixed_destination if use_fixed_destination else start_position + direction * distance
	owner.global_position = end_position
	if owner.has_method("_clamp_to_active_map_bounds"):
		owner._clamp_to_active_map_bounds()
	end_position = owner.global_position
	var dash_direction: Vector2 = start_position.direction_to(end_position)
	if dash_direction.length_squared() <= 0.001:
		return
	owner.facing_direction = dash_direction
	var scar_width: float = 34.0 * (1.40 if _has_talent(owner, "swordsman_entry_through_ranks") else 1.0)
	owner._spawn_sword_omnislash_scene_effect(start_position.lerp(end_position, 0.5), dash_direction, start_position.distance_to(end_position), scar_width)
	owner._push_attack_result_context_tag("suppress_swordsman_trait_heal")
	owner._push_attack_result_context_tag("suppress_greed_heal")
	var slow_multiplier: float = 0.70 if _has_talent(owner, "swordsman_entry_break_formation") else 1.0
	var slow_duration: float = 0.8 if slow_multiplier < 1.0 else 0.0
	var blood_surge_multiplier := PLAYER_COMBAT_RESULT_FLOW.get_swordsman_blood_surge_multiplier(owner)
	var hits: int = owner._damage_enemies_in_line(start_position, end_position, 32.0 * (1.40 if _has_talent(owner, "swordsman_entry_through_ranks") else 1.0), owner._get_role_damage(role_id) * 1.5 * max(0.0, damage_scale) * blood_surge_multiplier, 0.1, slow_multiplier, slow_duration, role_id)
	if hits > 0 and blood_surge_multiplier > 1.0:
		PLAYER_COMBAT_RESULT_FLOW.consume_swordsman_blood_surge(owner)
	owner._pop_attack_result_context_tag("suppress_greed_heal")
	owner._pop_attack_result_context_tag("suppress_swordsman_trait_heal")
	_apply_entry_hit_talents(owner, hits)
	if is_final:
		_finish_entry_talent_segment(owner, role_id, start_position, end_position, damage_scale)

func _apply_entry_hit_talents(owner, hits: int) -> void:
	if hits < 3 or not _has_talent(owner, "swordsman_entry_through_ranks"):
		return
	var state: Dictionary = owner._get_role_special_state("swordsman")
	state["entry_move_speed_remaining"] = 1.2
	owner.role_special_states["swordsman"] = state

func _finish_entry_talent_segment(owner, role_id: String, segment_start: Vector2, segment_end: Vector2, damage_scale: float) -> void:
	var entry_damage: float = owner._get_role_damage(role_id) * 1.5 * max(0.0, damage_scale)
	if _has_talent(owner, "swordsman_entry_sheathe"):
		owner._damage_enemies_in_radius(segment_end, 84.0, entry_damage * 0.45, 0.0, 1.0, 0.0, role_id)
		owner._spawn_ring_effect(segment_end, 84.0, Color(1.0, 0.78, 0.38, 0.56), 6.0, 0.16)
	if not _has_talent(owner, "swordsman_entry_hold_line"):
		return
	owner._schedule_repeating_sequence(0.5, 3, func(_index: int) -> void:
		if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
			return
		owner._damage_enemies_in_line(segment_start, segment_end, 24.0, entry_damage * 0.30, 0.0, 1.0, 0.0, role_id)
		owner._spawn_sword_omnislash_scene_effect(segment_start.lerp(segment_end, 0.5), segment_start.direction_to(segment_end), segment_start.distance_to(segment_end), 24.0)
	, 0.5)

func perform_exit(_owner, _role_id: String, _rearguard_level: int) -> int:
	return 0

func perform_ultimate(owner, cast_payload: Dictionary) -> void:
	var pursuit_level: int = 0
	var crescent_level: int = 0
	var thrust_level: int = 0
	var talent_snapshot := _snapshot_ultimate_talents(owner)
	var ultimate_tier: int = _get_ultimate_skill_tier(owner)
	var is_followup: bool = bool(cast_payload.get("ultimate_chain_followup", false))
	talent_snapshot["ultimate_chain_followup"] = is_followup
	var total_duration: float = 2.0 * ULTIMATE_SLASH_INTERVAL if is_followup else _get_ultimate_duration(owner, cast_payload)
	var slash_count: int = 2 if is_followup else max(1, int(floor(total_duration / ULTIMATE_SLASH_INTERVAL)))
	var combo_scales: Array[float] = _get_ultimate_combo_scales(owner)
	var slash_scales: Array[float] = []
	if is_followup:
		slash_scales.append(1.0)
		slash_scales.append(1.0)
	else:
		slash_scales = _build_ultimate_segment_scales(slash_count, combo_scales)
	var total_sequence_duration: float = float(max(0, slash_scales.size() - 1)) * ULTIMATE_SLASH_INTERVAL + 0.18
	var combo_start_index: int = max(0, slash_count - 1)
	var combo_end_index: int = combo_start_index + combo_scales.size()
	ultimate_pursuit_target = null
	ultimate_pursuit_hits = 0
	ultimate_pursuit_armed = false
	owner._queue_camera_shake(20.0, 0.62)
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, total_sequence_duration)
	owner.hidden_invulnerability_status_remaining = max(owner.hidden_invulnerability_status_remaining, total_sequence_duration)
	owner.swordsman_ultimate_crit_bonus_chance = max(owner.swordsman_ultimate_crit_bonus_chance, ULTIMATE_CRITICAL_BONUS_CHANCE)
	owner.swordsman_bloodthirst_heal_multiplier = max(owner.swordsman_bloodthirst_heal_multiplier, 1.0)
	PLAYER_SWORDSMAN_ULTIMATE_FLOW.begin_ultimate(owner, total_sequence_duration, is_followup)
	if owner.has_method("_lock_player_actions"):
		owner._lock_player_actions(total_sequence_duration)
	owner._delay_level_up_requests(total_sequence_duration)
	owner._set_active_role_visual_hidden(true)
	if owner.has_method("_schedule_repeating_sequence"):
		owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
			owner._set_active_role_visual_hidden(false)
		, total_sequence_duration)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -34.0), "无敌斩", Color(1.0, 0.92, 0.6, 1.0))
	owner._spawn_ring_effect(owner.global_position, 68.0, Color(1.0, 0.88, 0.52, 0.84), 8.0, 0.18)
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, total_sequence_duration)
	owner._push_attack_result_context_tag("suppress_swordsman_trait_heal")
	owner._push_attack_result_context_tag("suppress_greed_heal")
	_schedule_ultimate_sequence(owner, slash_scales, pursuit_level, crescent_level, thrust_level, _get_ultimate_damage_multiplier(owner, cast_payload), ultimate_tier, talent_snapshot, 0.0, combo_start_index, combo_end_index)
	owner._apply_post_ultimate_bonuses("swordsman", total_sequence_duration)
	if owner.has_method("_schedule_repeating_sequence"):
		owner._schedule_repeating_sequence(total_sequence_duration, 1, func(_index: int) -> void:
			if owner == null or not is_instance_valid(owner):
				return
			owner._pop_attack_result_context_tag("suppress_greed_heal")
			owner._pop_attack_result_context_tag("suppress_swordsman_trait_heal")
			owner.swordsman_ultimate_crit_bonus_chance = 0.0
			_activate_ultimate_triumph(owner, bool(talent_snapshot.get("swordsman_ultimate_triumph", false)))
			_try_start_bloodthirst(owner, POST_ULTIMATE_BLOODTHIRST_DURATION, 1.5, true)
			PLAYER_SWORDSMAN_ULTIMATE_FLOW.on_ultimate_finished(owner)
		, total_sequence_duration)
	else:
		owner._pop_attack_result_context_tag("suppress_greed_heal")
		owner._pop_attack_result_context_tag("suppress_swordsman_trait_heal")
		owner.swordsman_ultimate_crit_bonus_chance = 0.0
		_activate_ultimate_triumph(owner, bool(talent_snapshot.get("swordsman_ultimate_triumph", false)))
		_try_start_bloodthirst(owner, POST_ULTIMATE_BLOODTHIRST_DURATION, 1.5, true)
		PLAYER_SWORDSMAN_ULTIMATE_FLOW.on_ultimate_finished(owner)

func _activate_ultimate_triumph(owner, enabled: bool) -> void:
	if not enabled:
		return
	var state: Dictionary = owner._get_role_special_state("swordsman")
	state["ultimate_triumph_remaining"] = 2.0
	owner.role_special_states["swordsman"] = state

func _schedule_ultimate_sequence(owner, slash_scales: Array[float], pursuit_level: int, crescent_level: int, thrust_level: int, cast_damage_multiplier: float, ultimate_tier: int, talent_snapshot: Dictionary, start_delay: float, combo_start_index: int = -1, combo_end_index: int = -1) -> void:
	var slash_count: int = slash_scales.size()
	var sequence_callback := func(slash_index: int) -> void:
		var is_combo_segment := combo_start_index >= 0 and slash_index >= combo_start_index and slash_index < combo_end_index
		_execute_ultimate_slash(owner, slash_scales, pursuit_level, crescent_level, thrust_level, cast_damage_multiplier, slash_index, ultimate_tier, talent_snapshot, is_combo_segment)
	if start_delay <= 0.0:
		owner._schedule_repeating_sequence(ULTIMATE_SLASH_INTERVAL, slash_count, sequence_callback)
		return
	owner._schedule_repeating_sequence(ULTIMATE_SLASH_INTERVAL, slash_count, sequence_callback, start_delay)

func _execute_ultimate_slash(owner, slash_scales: Array[float], pursuit_level: int, crescent_level: int, thrust_level: int, cast_damage_multiplier: float, slash_index: int, ultimate_tier: int, talent_snapshot: Dictionary, is_combo_segment: bool = false) -> void:
	if owner.is_dead:
		return

	var slash_count: int = slash_scales.size()
	var effect_scale: float = 1.0
	if slash_index >= 0 and slash_index < slash_count:
		effect_scale = float(slash_scales[slash_index])
	var swordsman_is_active: bool = not owner.has_method("_get_active_role_id") or str(owner._get_active_role_id()) == "swordsman"
	var start_position: Vector2 = owner.global_position
	var cluster_center: Vector2 = owner._get_enemy_cluster_center()
	var target_enemy: Node2D = _get_ultimate_priority_boss_target(owner, start_position, bool(talent_snapshot.get("swordsman_ultimate_king", false)))
	var pursuit_strike: bool = false
	if bool(talent_snapshot.get("swordsman_ultimate_pursuit", false)) and not is_combo_segment and ultimate_pursuit_armed:
		target_enemy = _resolve_pursuit_target(owner, start_position)
		pursuit_strike = target_enemy != null
		ultimate_pursuit_armed = false
		ultimate_pursuit_hits = 0
		ultimate_pursuit_target = null
	var king_boss_target: bool = (
		bool(talent_snapshot.get("swordsman_ultimate_king", false))
		and target_enemy != null
		and str(target_enemy.get("enemy_kind")) in ["boss", "small_boss"]
	)
	if target_enemy == null:
		if slash_index == slash_count - 1:
			target_enemy = owner._get_low_health_enemy()
		elif slash_index % 2 == 0:
			target_enemy = owner._get_enemy_nearest_to_position(cluster_center if cluster_center != Vector2.ZERO else start_position + owner.facing_direction * 240.0)
		else:
			target_enemy = owner._get_farthest_enemy()

	var travel_direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	var target_position: Vector2 = cluster_center
	if target_enemy != null and is_instance_valid(target_enemy):
		target_position = _get_ultimate_target_position(owner, target_enemy, start_position)
		travel_direction = start_position.direction_to(target_position)
	elif cluster_center != Vector2.ZERO:
		target_position = cluster_center
		travel_direction = start_position.direction_to(target_position)
	if travel_direction.length_squared() <= 0.001:
		travel_direction = Vector2.RIGHT.rotated(float(slash_index) * TAU / float(max(1, slash_count)))

	var dash_distance: float = 96.0 + thrust_level * 10.0 + pursuit_level * 8.0
	if target_enemy != null and is_instance_valid(target_enemy):
		dash_distance = 600.0 + thrust_level * 48.0 + pursuit_level * 28.0
	elif cluster_center != Vector2.ZERO:
		dash_distance = 600.0 + thrust_level * 48.0 + pursuit_level * 28.0
	var end_position: Vector2 = start_position + travel_direction * dash_distance
	if swordsman_is_active:
		owner.global_position = end_position
		owner.facing_direction = travel_direction
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, 0.24)
	owner._queue_camera_shake(8.6 + float(slash_index) * 0.7, 0.15)
	var tier_visual_hit_scale: float = 1.0
	if ultimate_tier >= 3:
		tier_visual_hit_scale = ULTIMATE_TIER_THREE_VISUAL_HIT_SCALE
	elif ultimate_tier >= 2:
		tier_visual_hit_scale = ULTIMATE_TIER_TWO_VISUAL_HIT_SCALE
	var visual_hit_scale: float = tier_visual_hit_scale
	var tier_damage_multiplier: float = 1.0
	if ultimate_tier >= 3:
		tier_damage_multiplier = ULTIMATE_TIER_THREE_DAMAGE_MULTIPLIER
	elif ultimate_tier >= 2:
		tier_damage_multiplier = ULTIMATE_TIER_TWO_DAMAGE_MULTIPLIER
	var damage_multiplier: float = cast_damage_multiplier * max(0.0, effect_scale) * tier_damage_multiplier
	var blood_surge_multiplier := PLAYER_COMBAT_RESULT_FLOW.get_swordsman_blood_surge_multiplier(owner)
	damage_multiplier *= blood_surge_multiplier
	var final_judgement: bool = (
		bool(talent_snapshot.get("swordsman_ultimate_final_judgement", false))
		and not is_combo_segment
		and slash_index == slash_count - 1
	)
	if final_judgement:
		damage_multiplier *= 1.80
	var scar_width: float = (40.0 + thrust_level * 5.0) * visual_hit_scale
	if final_judgement:
		scar_width *= 1.40
	var scar_length_end: Vector2 = end_position + travel_direction * ((84.0 + thrust_level * 18.0) * visual_hit_scale)
	var scar_center: Vector2 = start_position.lerp(scar_length_end, 0.5)
	var scar_length: float = start_position.distance_to(scar_length_end)
	owner._spawn_sword_omnislash_scene_effect(scar_center, travel_direction, scar_length, scar_width * 1.12)

	var damage_scale: float = ULTIMATE_BASE_SLASH_DAMAGE_SCALE * damage_multiplier * ULTIMATE_GUNNER_ULTIMATE_OUTPUT_RATIO
	if king_boss_target:
		damage_scale *= 1.30
	var line_damage: float = owner._get_role_damage("swordsman") * damage_scale
	if pursuit_strike:
		line_damage *= 0.70
	if bool(talent_snapshot.get("ultimate_chain_followup", false)):
		PLAYER_SWORDSMAN_ULTIMATE_FLOW.begin_followup_damage_tracking(owner)
	var slash_hits: int = owner._damage_enemies_in_line(start_position, scar_length_end, scar_width, line_damage, 0.08 + pursuit_level * 0.02, 1.0, 0.0, "swordsman")
	if bool(talent_snapshot.get("ultimate_chain_followup", false)):
		var actual_damage: float = PLAYER_SWORDSMAN_ULTIMATE_FLOW.consume_followup_damage_total(owner)
		if actual_damage <= 0.0 and slash_hits > 0:
			actual_damage = line_damage * float(slash_hits)
		PLAYER_SWORDSMAN_ULTIMATE_FLOW.apply_followup_slash_heal(owner, slash_hits, actual_damage)
	if slash_hits > 0 and blood_surge_multiplier > 1.0:
		PLAYER_COMBAT_RESULT_FLOW.consume_swordsman_blood_surge(owner)
	if pursuit_strike and target_enemy != null and is_instance_valid(target_enemy):
		owner._deal_damage_to_enemy(target_enemy, owner._get_role_damage("swordsman") * damage_scale * 0.30, "swordsman")
	if slash_hits > 0 and not _uses_batched_ultimate_damage(owner):
		owner._register_attack_result("swordsman", slash_hits, false)
	if bool(talent_snapshot.get("swordsman_ultimate_blossom", false)):
		var blossom_hits: int = owner._damage_enemies_in_radius(scar_length_end, 70.0, line_damage * 0.30, 0.0, 1.0, 0.0, "swordsman")
		owner._spawn_ring_effect(scar_length_end, 70.0, Color(1.0, 0.72, 0.34, 0.66), 6.0, 0.14)
		if blossom_hits > 0 and not _uses_batched_ultimate_damage(owner):
			owner._register_attack_result("swordsman", blossom_hits, false)
	if bool(talent_snapshot.get("swordsman_ultimate_hold_ground", false)):
		owner._damage_enemies_in_radius(scar_length_end, 84.0, 0.0, 0.0, 0.50, 0.75, "swordsman")
		owner._spawn_ring_effect(scar_length_end, 84.0, Color(0.50, 0.82, 1.0, 0.44), 5.0, 0.14)
	if is_combo_segment:
		return
	_update_pursuit_tracking(target_enemy)

	owner._spawn_ring_effect(end_position, (34.0 + crescent_level * 8.0) * visual_hit_scale, Color(1.0, 0.84, 0.44, 0.76), 5.0, 0.12)

func _update_pursuit_tracking(target_enemy: Node2D) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy):
		ultimate_pursuit_target = null
		ultimate_pursuit_hits = 0
		return
	var previous = ultimate_pursuit_target.get_ref() if ultimate_pursuit_target != null else null
	if previous == target_enemy:
		ultimate_pursuit_hits += 1
	else:
		ultimate_pursuit_target = weakref(target_enemy)
		ultimate_pursuit_hits = 1
	if ultimate_pursuit_hits >= 3:
		ultimate_pursuit_armed = true

func _resolve_pursuit_target(owner, origin: Vector2) -> Node2D:
	var tracked = ultimate_pursuit_target.get_ref() if ultimate_pursuit_target != null else null
	if tracked != null and is_instance_valid(tracked):
		return tracked as Node2D
	if owner == null or not owner.has_method("_get_live_enemies"):
		return null
	for kind in ["boss", "small_boss", "elite", ""]:
		var best: Node2D = null
		var best_distance := INF
		for candidate in owner._get_live_enemies():
			if candidate is not Node2D or not is_instance_valid(candidate):
				continue
			var candidate_kind := str(candidate.get("enemy_kind"))
			if kind == "":
				if candidate_kind in ["boss", "small_boss", "elite"]:
					continue
			elif candidate_kind != kind:
				continue
			var distance := origin.distance_squared_to((candidate as Node2D).global_position)
			if distance < best_distance:
				best_distance = distance
				best = candidate as Node2D
		if best != null:
			return best
	return null

func _get_ultimate_skill_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return max(1, int(owner._get_blessing_skill_tier(ULTIMATE_SKILL_ID)))
	return 1

func _get_ultimate_priority_boss_target(owner, origin: Vector2, has_king: bool) -> Node2D:
	if owner == null or not is_instance_valid(owner) or not owner.has_method("_get_priority_boss_target"):
		return null
	if not has_king and randf() > ULTIMATE_BOSS_TARGET_WEIGHT:
		return null
	return owner._get_priority_boss_target(origin)

func _snapshot_ultimate_talents(owner) -> Dictionary:
	var result := {}
	for talent_id in [
		"swordsman_ultimate_king",
		"swordsman_ultimate_blossom",
		"swordsman_ultimate_pursuit",
		"swordsman_ultimate_hold_ground",
		"swordsman_ultimate_final_judgement",
		"swordsman_ultimate_triumph"
	]:
		result[talent_id] = _has_talent(owner, talent_id)
	return result

func _has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_skill_talent") and bool(owner._has_skill_talent(talent_id))

func _has_level_talent(owner, talent_id: String) -> bool:
	return PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW.has_level_talent(owner, talent_id)

func _can_basic_attack_during_blade_storm(owner) -> bool:
	return _has_level_talent(owner, LEVEL_TALENT_BLADE_STORM_2)

func _get_ultimate_target_position(owner, target_enemy: Node2D, origin: Vector2) -> Vector2:
	if target_enemy == null or not is_instance_valid(target_enemy):
		return origin
	if owner != null and owner.has_method("_get_enemy_aim_point"):
		return owner._get_enemy_aim_point(target_enemy, origin)
	return target_enemy.global_position

func _get_ultimate_combo_scales(owner) -> Array[float]:
	if owner != null and owner.has_method("_get_blessing_skill_combo_scales"):
		return owner._get_blessing_skill_combo_scales(ULTIMATE_SKILL_ID) as Array[float]
	return []

func _get_ultimate_duration(owner, cast_payload: Dictionary) -> float:
	var duration: float = ULTIMATE_BASE_DURATION * float(cast_payload.get("duration_multiplier", 1.0))
	if owner != null and owner.has_method("_get_blessing_skill_duration_multiplier"):
		duration *= float(owner._get_blessing_skill_duration_multiplier(ULTIMATE_SKILL_ID))
	if owner != null and owner.has_method("_get_blessing_skill_duration_flat_bonus"):
		duration += float(owner._get_blessing_skill_duration_flat_bonus(ULTIMATE_SKILL_ID))
	return max(ULTIMATE_SLASH_INTERVAL, duration)

func _get_ultimate_damage_multiplier(owner, cast_payload: Dictionary) -> float:
	var multiplier: float = float(cast_payload.get("damage_multiplier", 1.0))
	if owner != null and owner.has_method("_get_blessing_ultimate_damage_multiplier"):
		multiplier *= float(owner._get_blessing_ultimate_damage_multiplier(ULTIMATE_SKILL_ID))
	multiplier *= PLAYER_BUILD_SYSTEM.get_swordsman_ultimate_damage_multiplier(owner)
	return multiplier

func _get_ultimate_special_effect_multiplier(owner) -> float:
	if owner != null and owner.has_method("_get_blessing_ultimate_special_effect_multiplier"):
		return max(0.0, float(owner._get_blessing_ultimate_special_effect_multiplier(ULTIMATE_SKILL_ID)))
	return 1.0

func _build_ultimate_segment_scales(base_count: int, combo_scales: Array[float]) -> Array[float]:
	var result: Array[float] = []
	var normal_count: int = max(0, base_count - 1)
	for _index in range(normal_count):
		result.append(1.0)
	for scale in combo_scales:
		result.append(max(0.05, float(scale)))
	result.append(1.0)
	return result

func _apply_ultimate_damage_shapes(owner, shapes: Array[Dictionary]) -> int:
	if owner != null and owner.has_method("_damage_enemies_in_shapes_batched"):
		return int(owner._damage_enemies_in_shapes_batched(shapes))
	var hits := 0
	for shape in shapes:
		if str(shape.get("type", "")) == "line":
			hits += int(owner._damage_enemies_in_line(
				shape.get("start", Vector2.ZERO),
				shape.get("end", Vector2.ZERO),
				float(shape.get("width", 1.0)),
				float(shape.get("damage_amount", 0.0)),
				float(shape.get("vulnerability_bonus", 0.0)),
				float(shape.get("slow_multiplier", 1.0)),
				float(shape.get("slow_duration", 0.0)),
				str(shape.get("source_role_id", ""))
			))
		elif str(shape.get("type", "")) == "circle":
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

func _uses_batched_ultimate_damage(owner) -> bool:
	return owner != null and owner.has_method("_damage_enemies_in_shapes_batched")

func _get_slash_visual_width(slash_width: float) -> float:
	return max(18.0, slash_width * 2.0)

func _get_slash_mirror_forward_offset(owner, visual_width: float) -> float:
	var visible_bounds: Rect2 = owner.SWORD_SLASH_SCENE_VISIBLE_BOUNDS
	var visible_center_x: float = visible_bounds.position.x + visible_bounds.size.x * 0.5
	var mirrored_center_offset_px: float = owner.SWORD_SLASH_SCENE_SIZE.x - visible_center_x * 2.0
	if mirrored_center_offset_px <= 0.0:
		return 0.0
	return mirrored_center_offset_px * visual_width / max(1.0, visible_bounds.size.x)

extends RefCounted

const PLAYER_AUTHORED_EFFECTS := preload("res://scripts/player/player_authored_effects.gd")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")
const COOLDOWN := 20.0
const MANUAL_STOP_COOLDOWN := 0.5
const MANUAL_ACTIVE_REMAINING := 1.0
const BASE_DURATION := 3.0
const TIER_TWO_DURATION := 3.0
const TIER_THREE_DURATION := 3.0
const TICK_INTERVAL := 0.1
const MAX_CATCH_UP_TICKS := 6
const MAX_PENDING_BEAM_HIT_RESOLVES_PER_FRAME := 8
const MAX_VISUALS := 7
const EXTRA_VISUALS_PER_WIDTH_LEVEL := 3
const BEAM_LENGTH := 400.0
const BEAM_THICKNESS := 34.0
const BASE_WIDTH_MULTIPLIER := 5.0
const DIELANG_RANGE_BONUS := 0.42
const DIELANG_DURATION_BONUS := 0.67
const HUICHAO_WIDTH_BONUS := 0.36
const VISUAL_WIDTH_SPREAD_SCALE := 0.92
const BEAM_DAMAGE_SYNC_DELAY_FALLBACK := 0.2
const INFINITE_RELOAD_SKILL_ID := "infinite_reload"
const TIER_TWO_RANGE_MULTIPLIER := 2.0
const TIER_ONE_MOVE_SPEED_MULTIPLIER := 1.05
const TIER_TWO_MOVE_SPEED_MULTIPLIER := 1.5
const TIER_TWO_TICK_INTERVAL_MULTIPLIER := 0.58
const TIER_THREE_RANGE_MULTIPLIER := 2.5
const TIER_THREE_MOVE_SPEED_MULTIPLIER := 2.0
const TIER_THREE_TICK_INTERVAL_MULTIPLIER := 0.38
const BASE_DAMAGE_RATIO := 1.0
const TIER_TWO_DAMAGE_MULTIPLIER := 1.0
const TIER_THREE_DAMAGE_MULTIPLIER := 1.0
const ACTIVE_CAMERA_SHAKE_STRENGTH := 1.4
const ACTIVE_CAMERA_SHAKE_DURATION := 0.045
const TALENT_IDS := [
	"gunner_infinite_axis",
	"gunner_infinite_dual",
	"gunner_infinite_sweep",
	"gunner_infinite_sear",
	"gunner_infinite_overload",
	"gunner_infinite_recycle",
	"gunner_level_talent_infinite_reload_1",
	"gunner_level_talent_infinite_reload_2"
]
const LEVEL_TALENT_INFINITE_RELOAD_1 := "gunner_level_talent_infinite_reload_1"
const LEVEL_TALENT_INFINITE_RELOAD_2 := "gunner_level_talent_infinite_reload_2"
const LEVEL_TALENT_INFINITE_RELOAD_1_RANGE_BONUS := 50.0
const LEVEL_TALENT_INFINITE_RELOAD_2_RANGE_BONUS := 50.0
const LEVEL_TALENT_INFINITE_RELOAD_1_DODGE_VALUE_BONUS := 100.0
const LEVEL_TALENT_INFINITE_RELOAD_1_MIN_MANUAL_ACTIVE_TIME := 1.5
const LEVEL_TALENT_INFINITE_RELOAD_2_COOLDOWN_BONUS := 1.0
const LEVEL_TALENT_INFINITE_RELOAD_2_DURATION_BONUS := 1.0

var cooldown_remaining: float = 0.0
var active_remaining: float = 0.0
var manual_active_elapsed: float = 0.0
var tick_remaining: float = 0.0
var locked_aim_direction: Vector2 = Vector2.RIGHT
var effects: Array[Node2D] = []
var sweep_elapsed: float = 0.0
var hit_during_cast: bool = false
var last_tick_data: Dictionary = {}
var cast_talent_ids: Array[String] = []
var cast_talent_snapshot_valid: bool = false
var pending_beam_hits: Array[Dictionary] = []
var finish_pending: bool = false
var finish_effects_applied: bool = false

func update(owner, delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)
	if owner == null or not is_instance_valid(owner):
		stop()
		return
	if active_remaining > 0.0 and str(owner._get_active_role().get("id", "")) != "gunner":
		if _is_manual_cast(owner):
			_finish_manual_cast(owner)
		else:
			stop(owner)
		return
	_update_pending_beam_hits(owner, delta)
	if active_remaining <= 0.0:
		if finish_pending and pending_beam_hits.is_empty():
			_finish_cast(owner)
		return

	if _is_manual_cast(owner):
		manual_active_elapsed += max(0.0, delta)
		active_remaining = MANUAL_ACTIVE_REMAINING
	else:
		active_remaining = max(0.0, active_remaining - delta)
	if active_remaining > 0.0:
		_queue_active_camera_shake(owner)
	tick_remaining -= delta
	var catch_up_ticks := 0
	while tick_remaining <= 0.0 and active_remaining > 0.0 and catch_up_ticks < MAX_CATCH_UP_TICKS:
		tick_remaining += _get_tick_interval(owner)
		_trigger_tick(owner)
		catch_up_ticks += 1
	if catch_up_ticks >= MAX_CATCH_UP_TICKS and tick_remaining <= 0.0:
		tick_remaining = _get_tick_interval(owner)
	if active_remaining <= 0.0:
		_finish_cast(owner)

func can_trigger(owner, role_id: String) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	if bool(owner.get("is_dead")) or bool(owner.get("level_up_active")):
		return false
	if role_id != "gunner":
		return false
	if not _has_required_unlock(owner):
		return false
	return active_remaining <= 0.0 and cooldown_remaining <= 0.0 and not finish_pending

func try_trigger(owner) -> bool:
	if is_manual_toggle_enabled(owner):
		return false
	if not can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		return false
	return _start_cast(owner, false)

func toggle_manual(owner) -> bool:
	if not is_manual_toggle_enabled(owner):
		return false
	if active_remaining > 0.0 and _is_manual_cast(owner):
		if manual_active_elapsed < LEVEL_TALENT_INFINITE_RELOAD_1_MIN_MANUAL_ACTIVE_TIME:
			return false
		_finish_manual_cast(owner)
		return true
	if not can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		return false
	return _start_cast(owner, true)

func is_manual_toggle_enabled(owner) -> bool:
	return _owner_has_talent(owner, LEVEL_TALENT_INFINITE_RELOAD_1)

func is_blocking_actions(owner) -> bool:
	return active_remaining > 0.0 and _is_manual_cast(owner)

func is_movement_locked(owner) -> bool:
	return active_remaining > 0.0 and _is_manual_cast(owner)

func is_preventing_switch(owner) -> bool:
	return active_remaining > 0.0 and _is_manual_cast(owner) and manual_active_elapsed < LEVEL_TALENT_INFINITE_RELOAD_1_MIN_MANUAL_ACTIVE_TIME

func get_dodge_value_bonus(owner, role_id: String) -> float:
	if role_id != "gunner":
		return 0.0
	return LEVEL_TALENT_INFINITE_RELOAD_1_DODGE_VALUE_BONUS if active_remaining > 0.0 and _is_manual_cast(owner) else 0.0

func _start_cast(owner, manual_cast: bool) -> bool:
	cast_talent_ids = _capture_talents(owner)
	if manual_cast and not cast_talent_ids.has(LEVEL_TALENT_INFINITE_RELOAD_1):
		cast_talent_ids.append(LEVEL_TALENT_INFINITE_RELOAD_1)
	cast_talent_snapshot_valid = true
	pending_beam_hits.clear()
	finish_pending = false
	finish_effects_applied = false
	active_remaining = MANUAL_ACTIVE_REMAINING if manual_cast else _get_duration(owner)
	manual_active_elapsed = 0.0
	cooldown_remaining = 0.0 if manual_cast else _get_cooldown(owner)
	tick_remaining = 0.0
	locked_aim_direction = owner._get_live_mouse_aim_direction(owner.facing_direction)
	if locked_aim_direction.length_squared() <= 0.001:
		locked_aim_direction = Vector2.RIGHT
	owner.facing_direction = locked_aim_direction
	owner.gunner_attack_chain = 0
	sweep_elapsed = 0.0
	hit_during_cast = false
	last_tick_data.clear()
	_cleanup_effects()
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -64.0), "\u65E0\u9650\u88C5\u586B", Color(1.0, 0.6, 0.34, 1.0))
	owner._spawn_ring_effect(owner.global_position, 104.0, Color(1.0, 0.58, 0.32, 0.34), 8.0, 0.2)
	owner._spawn_burst_effect(owner.global_position, 92.0, Color(1.0, 0.54, 0.28, 0.16), 0.18)
	return true

func _finish_manual_cast(owner) -> void:
	active_remaining = 0.0
	manual_active_elapsed = 0.0
	tick_remaining = 0.0
	finish_pending = true
	finish_effects_applied = true
	cooldown_remaining = max(cooldown_remaining, MANUAL_STOP_COOLDOWN)
	if pending_beam_hits.is_empty():
		stop(owner)

func stop(owner = null) -> void:
	active_remaining = 0.0
	manual_active_elapsed = 0.0
	tick_remaining = 0.0
	locked_aim_direction = Vector2.RIGHT
	sweep_elapsed = 0.0
	hit_during_cast = false
	last_tick_data.clear()
	cast_talent_ids.clear()
	cast_talent_snapshot_valid = false
	pending_beam_hits.clear()
	finish_pending = false
	finish_effects_applied = false
	for effect in effects:
		if effect != null and is_instance_valid(effect):
			_release_visual_effect(effect)
	effects.clear()

func is_active() -> bool:
	return active_remaining > 0.0

func _queue_active_camera_shake(owner) -> void:
	if owner != null and owner.has_method("_queue_camera_shake"):
		owner._queue_camera_shake(ACTIVE_CAMERA_SHAKE_STRENGTH, ACTIVE_CAMERA_SHAKE_DURATION)

func register_effect(effect: Node2D, max_visuals: int = MAX_VISUALS) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	_cleanup_effects()
	effects.append(effect)
	while effects.size() > max_visuals:
		var oldest_effect: Node2D = effects.pop_front()
		if oldest_effect != null and is_instance_valid(oldest_effect):
			_release_visual_effect(oldest_effect)

func _release_visual_effect(effect: Node2D) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	PLAYER_AUTHORED_EFFECTS.release_gunner_intersect_effect(effect)

func get_cooldown_slot(owner = null) -> Dictionary:
	var duration: float = _get_cooldown(owner)
	var remaining: float = clamp(cooldown_remaining, 0.0, duration)
	var description: String = "\u65E0\u9650\u88C5\u586B\uFF1A\u67AA\u624B\u8361\u9635\u8FDB\u5316\u3002\u6301\u7EED\u9AD8\u901F\u91CA\u653E\u8D2F\u7A7F\u706B\u529B\uFF0C\u671F\u95F4\u53EF\u6B63\u5E38\u91CA\u653E\u5176\u4ED6\u6280\u80FD\u4E0E\u5927\u62DB\uFF0C\u51B7\u5374\u7ED3\u675F\u540E\u53EF\u518D\u6B21\u89E6\u53D1\u3002"
	if active_remaining > 0.0 and _is_manual_cast(owner) and manual_active_elapsed < LEVEL_TALENT_INFINITE_RELOAD_1_MIN_MANUAL_ACTIVE_TIME:
		duration = LEVEL_TALENT_INFINITE_RELOAD_1_MIN_MANUAL_ACTIVE_TIME
		remaining = max(0.0, duration - manual_active_elapsed)
		description = "\u65E0\u9650\u88C5\u586B\u5DF2\u5F00\u542F\uFF0C1.5\u79D2\u5185\u4E0D\u53EF\u5173\u95ED"
	return {
		"name": "\u65E0\u9650\u88C5\u586B",
		"remaining": remaining,
		"duration": duration,
		"color": Color(1.0, 0.56, 0.28, 1.0),
		"description": description
	}

func get_save_data() -> Dictionary:
	return {
		"cooldown_remaining": cooldown_remaining,
		"active_remaining": active_remaining,
		"manual_active_elapsed": manual_active_elapsed,
		"tick_remaining": tick_remaining,
		"locked_aim_direction": [locked_aim_direction.x, locked_aim_direction.y],
		"sweep_elapsed": sweep_elapsed,
		"hit_during_cast": hit_during_cast,
		"last_tick_data": _serialize_last_tick_data(),
		"talent_ids": cast_talent_ids.duplicate(),
		"talent_snapshot_valid": cast_talent_snapshot_valid
	}

func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN + LEVEL_TALENT_INFINITE_RELOAD_2_COOLDOWN_BONUS)
	active_remaining = clamp(float(data.get("active_remaining", 0.0)), 0.0, TIER_THREE_DURATION + 3.0 * DIELANG_DURATION_BONUS + LEVEL_TALENT_INFINITE_RELOAD_2_DURATION_BONUS)
	manual_active_elapsed = max(0.0, float(data.get("manual_active_elapsed", 0.0)))
	tick_remaining = clamp(float(data.get("tick_remaining", 0.0)), 0.0, TICK_INTERVAL)
	sweep_elapsed = max(0.0, float(data.get("sweep_elapsed", 0.0)))
	hit_during_cast = bool(data.get("hit_during_cast", false))
	last_tick_data = _deserialize_last_tick_data(data.get("last_tick_data", {}))
	cast_talent_ids = _normalize_talent_ids(data.get("talent_ids", []))
	cast_talent_snapshot_valid = bool(data.get("talent_snapshot_valid", data.has("talent_ids")))
	var direction_data: Array = data.get("locked_aim_direction", [locked_aim_direction.x, locked_aim_direction.y])
	if direction_data.size() >= 2:
		var restored_direction := Vector2(float(direction_data[0]), float(direction_data[1]))
		locked_aim_direction = restored_direction if absf(restored_direction.length_squared() - 1.0) <= 0.0001 else restored_direction.normalized()
	if locked_aim_direction.length_squared() <= 0.001:
		locked_aim_direction = Vector2.RIGHT
	_cleanup_effects()

func _serialize_last_tick_data() -> Dictionary:
	if last_tick_data.is_empty():
		return {}
	var origin: Vector2 = last_tick_data.get("origin", Vector2.ZERO)
	var direction: Vector2 = last_tick_data.get("direction", Vector2.RIGHT)
	return {
		"origin": [origin.x, origin.y],
		"direction": [direction.x, direction.y],
		"length": float(last_tick_data.get("length", 0.0)),
		"width": float(last_tick_data.get("width", 0.0)),
		"damage": float(last_tick_data.get("damage", 0.0))
	}

func _deserialize_last_tick_data(value: Variant) -> Dictionary:
	if value is not Dictionary or (value as Dictionary).is_empty():
		return {}
	var data := value as Dictionary
	var origin_data: Array = data.get("origin", [0.0, 0.0])
	var direction_data: Array = data.get("direction", [1.0, 0.0])
	return {
		"origin": Vector2(float(origin_data[0]), float(origin_data[1])) if origin_data.size() >= 2 else Vector2.ZERO,
		"direction": Vector2(float(direction_data[0]), float(direction_data[1])).normalized() if direction_data.size() >= 2 else Vector2.RIGHT,
		"length": max(0.0, float(data.get("length", 0.0))),
		"width": max(0.0, float(data.get("width", 0.0))),
		"damage": max(0.0, float(data.get("damage", 0.0)))
	}

func _trigger_tick(owner) -> void:
	var manual_cast := _is_manual_cast(owner)
	var axis_talent: bool = _has_talent(owner, "gunner_infinite_axis")
	var dual_talent: bool = _has_talent(owner, "gunner_infinite_dual") or _has_talent(owner, LEVEL_TALENT_INFINITE_RELOAD_2)
	var aim_direction: Vector2 = locked_aim_direction if axis_talent or manual_cast else owner._get_live_mouse_aim_direction(locked_aim_direction)
	if aim_direction.length_squared() <= 0.001:
		aim_direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	aim_direction = aim_direction.normalized()
	if _has_talent(owner, "gunner_infinite_sweep") and not manual_cast:
		sweep_elapsed += _get_tick_interval(owner)
		aim_direction = aim_direction.rotated(deg_to_rad(14.0) * sin(TAU * sweep_elapsed / 0.7))
	owner.facing_direction = aim_direction
	var range_multiplier: float = _get_range_multiplier(owner) * float(owner._get_role_attribute_range_multiplier("gunner")) * owner._get_equipment_skill_range_multiplier()
	var beam_length: float = (BEAM_LENGTH + PLAYER_BUILD_SYSTEM.get_infinite_reload_range_bonus(owner) + _get_level_talent_range_bonus(owner)) * range_multiplier
	var hit_width: float = BEAM_THICKNESS * BASE_WIDTH_MULTIPLIER * _get_width_multiplier(owner)
	var base_origin: Vector2 = owner.global_position + aim_direction * 20.0
	var damage_amount: float = float(owner._get_role_damage("gunner")) * BASE_DAMAGE_RATIO * _get_damage_multiplier(owner)
	var combo_scales: Array[float] = _get_combo_scales(owner)
	var damage_scale: float = _get_combined_damage_scale(combo_scales)
	if axis_talent:
		beam_length *= 1.25
		hit_width *= 0.55
		damage_amount *= 1.55
	last_tick_data = {
		"origin": base_origin,
		"direction": aim_direction,
		"length": beam_length,
		"width": hit_width * 2.0,
		"damage": damage_amount * damage_scale
	}
	if dual_talent:
		_trigger_dual_beams(owner, base_origin, aim_direction, beam_length, hit_width, damage_amount * damage_scale)
	else:
		_spawn_visuals(owner, base_origin, aim_direction, beam_length, hit_width)
		for combo_scale in combo_scales:
			var offset_origin: Vector2 = _get_random_origin_in_hit_width(owner, base_origin, aim_direction, hit_width)
			_spawn_visuals(owner, offset_origin, aim_direction, beam_length, hit_width)
		var beam_shapes := _build_piercing_beam_shapes(owner, base_origin, aim_direction, beam_length, hit_width * 2.0, damage_amount * damage_scale)
		_queue_piercing_beam_shapes(owner, beam_shapes)

func _finish_cast(owner) -> void:
	active_remaining = 0.0
	tick_remaining = 0.0
	finish_pending = true
	if not pending_beam_hits.is_empty():
		return
	if not finish_effects_applied:
		finish_effects_applied = true
		if owner != null and is_instance_valid(owner):
			if _has_talent(owner, "gunner_infinite_overload"):
				_trigger_terminal_overload(owner)
			if _has_talent(owner, "gunner_infinite_recycle") and hit_during_cast:
				var reduction: float = min(3.0, cooldown_remaining * 0.15)
				cooldown_remaining = max(0.0, cooldown_remaining - reduction)
	if pending_beam_hits.is_empty():
		stop(owner)

func _trigger_terminal_overload(owner) -> void:
	if last_tick_data.is_empty():
		return
	var origin: Vector2 = last_tick_data.get("origin", owner.global_position)
	var direction: Vector2 = last_tick_data.get("direction", Vector2.RIGHT)
	var beam_length := float(last_tick_data.get("length", BEAM_LENGTH)) * 1.15
	var hit_width := float(last_tick_data.get("width", BEAM_THICKNESS)) * 0.6
	var damage_amount := float(last_tick_data.get("damage", 0.0)) * 6.0
	_spawn_visuals(owner, origin, direction, beam_length, hit_width)
	var beam_shapes := _build_piercing_beam_shapes(owner, origin, direction, beam_length, hit_width, damage_amount)
	_queue_piercing_beam_shapes(owner, beam_shapes, true, false)


func _trigger_dual_beams(owner, base_origin: Vector2, aim_direction: Vector2, beam_length: float, hit_width: float, damage_amount: float) -> void:
	var perpendicular := aim_direction.orthogonal().normalized()
	var original_damage_width: float = hit_width * 2.0
	var lane_offset: float = original_damage_width * 0.35
	var shapes: Array[Dictionary] = []
	for side in [-1.0, 1.0]:
		var lane_origin: Vector2 = base_origin + perpendicular * lane_offset * side
		_spawn_visuals(owner, lane_origin, aim_direction, beam_length, hit_width * 0.65)
		shapes.append({
			"type": "oriented_rect",
			"center": lane_origin + aim_direction * (beam_length * 0.5),
			"axis": aim_direction,
			"length": beam_length,
			"width": original_damage_width * 0.65,
			"damage_amount": damage_amount * 0.60,
			"vulnerability_bonus": 0.06 if _has_talent(owner, "gunner_infinite_sear") else 0.0,
			"vulnerability_duration": 0.45 if _has_talent(owner, "gunner_infinite_sear") else 0.0,
			"slow_multiplier": 1.0,
			"slow_duration": 0.0,
			"source_position": lane_origin,
			"source_role_id": "gunner"
		})
	_queue_piercing_beam_shapes(owner, shapes)

func _apply_piercing_beam_damage(owner, base_origin: Vector2, aim_direction: Vector2, beam_length: float, hit_width: float, damage_amount: float) -> int:
	return _apply_piercing_beam_shapes(owner, _build_piercing_beam_shapes(owner, base_origin, aim_direction, beam_length, hit_width, damage_amount))

func _build_piercing_beam_shapes(owner, base_origin: Vector2, aim_direction: Vector2, beam_length: float, hit_width: float, damage_amount: float) -> Array[Dictionary]:
	var hit_center: Vector2 = base_origin + aim_direction * (beam_length * 0.5)
	var beam_shapes: Array[Dictionary] = [{
		"type": "oriented_rect",
		"center": hit_center,
		"axis": aim_direction,
		"length": beam_length,
		"width": hit_width,
		"damage_amount": damage_amount,
		"vulnerability_bonus": 0.06 if _has_talent(owner, "gunner_infinite_sear") else 0.0,
		"vulnerability_duration": 0.45 if _has_talent(owner, "gunner_infinite_sear") else 0.0,
		"slow_multiplier": 1.0,
		"slow_duration": 0.0,
		"source_position": hit_center,
		"source_role_id": "gunner"
	}]
	return beam_shapes

func _queue_piercing_beam_shapes(owner, beam_shapes: Array[Dictionary], register_attack_result: bool = true, counts_for_recycle: bool = true) -> void:
	if beam_shapes.is_empty():
		return
	var delay := _get_beam_damage_sync_delay(owner)
	if delay <= 0.0:
		_handle_beam_hit_result(owner, _apply_piercing_beam_shapes(owner, beam_shapes), register_attack_result, counts_for_recycle)
		return
	pending_beam_hits.append({
		"remaining": delay,
		"shapes": _duplicate_beam_shapes(beam_shapes),
		"register_attack_result": register_attack_result,
		"counts_for_recycle": counts_for_recycle
	})

func _update_pending_beam_hits(owner, delta: float) -> void:
	if pending_beam_hits.is_empty():
		return
	var ready_hits: Array[Dictionary] = []
	var waiting_hits: Array[Dictionary] = []
	for hit_data in pending_beam_hits:
		var remaining: float = float(hit_data.get("remaining", 0.0)) - max(0.0, delta)
		hit_data["remaining"] = remaining
		if remaining <= 0.0 and ready_hits.size() < MAX_PENDING_BEAM_HIT_RESOLVES_PER_FRAME:
			ready_hits.append(hit_data)
		else:
			waiting_hits.append(hit_data)
	pending_beam_hits = waiting_hits
	for hit_data in ready_hits:
		_resolve_pending_beam_hit(owner, hit_data)

func _resolve_pending_beam_hit(owner, hit_data: Dictionary) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var shapes: Array[Dictionary] = []
	var shape_values: Variant = hit_data.get("shapes", [])
	if shape_values is Array:
		for shape_value in shape_values:
			if shape_value is Dictionary:
				shapes.append((shape_value as Dictionary).duplicate(true) as Dictionary)
	var hit_count := _apply_piercing_beam_shapes(owner, shapes)
	_handle_beam_hit_result(
		owner,
		hit_count,
		bool(hit_data.get("register_attack_result", true)),
		bool(hit_data.get("counts_for_recycle", true))
	)

func _handle_beam_hit_result(owner, hit_count: int, register_attack_result: bool, counts_for_recycle: bool) -> void:
	if hit_count <= 0:
		return
	if register_attack_result and owner != null and is_instance_valid(owner) and not _uses_batched_damage(owner):
		owner._register_attack_result("gunner", hit_count, false)
	if counts_for_recycle:
		hit_during_cast = true

func _duplicate_beam_shapes(beam_shapes: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for shape in beam_shapes:
		result.append(shape.duplicate(true) as Dictionary)
	return result

func _get_beam_damage_sync_delay(owner) -> float:
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_gunner_intersect_gather_duration"):
		return max(0.0, float(owner._get_gunner_intersect_gather_duration()))
	return BEAM_DAMAGE_SYNC_DELAY_FALLBACK

func _apply_piercing_beam_shapes(owner, beam_shapes: Array[Dictionary]) -> int:
	if beam_shapes.is_empty():
		return 0
	if owner.has_method("_damage_enemies_in_shapes_batched"):
		return int(owner._damage_enemies_in_shapes_batched(beam_shapes))
	var hit_count := 0
	for shape in beam_shapes:
		hit_count += int(owner._damage_enemies_in_oriented_rect(
			shape.get("center", Vector2.ZERO),
			shape.get("axis", Vector2.RIGHT),
			float(shape.get("length", 1.0)),
			float(shape.get("width", 1.0)),
			float(shape.get("damage_amount", 0.0)),
			float(shape.get("vulnerability_bonus", 0.0)),
			float(shape.get("slow_multiplier", 1.0)),
			float(shape.get("slow_duration", 0.0)),
			str(shape.get("source_role_id", "gunner"))
		))
	return hit_count

func _get_random_origin_in_hit_width(owner, base_origin: Vector2, aim_direction: Vector2, hit_width: float) -> Vector2:
	var perpendicular: Vector2 = owner._get_downward_perpendicular(aim_direction).normalized()
	if perpendicular.length_squared() <= 0.001:
		perpendicular = aim_direction.orthogonal().normalized()
	return base_origin + perpendicular * randf_range(-hit_width * 0.5, hit_width * 0.5)

func _spawn_visuals(owner, base_origin: Vector2, aim_direction: Vector2, beam_length: float, hit_width: float) -> void:
	_cleanup_effects()
	var max_visuals: int = _get_max_visuals(owner)
	if effects.size() >= max_visuals:
		return
	var visual_beam_length: float = _get_effect_parameter_length(owner, beam_length)
	var perpendicular: Vector2 = owner._get_downward_perpendicular(aim_direction).normalized()
	if perpendicular.length_squared() <= 0.001:
		perpendicular = aim_direction.orthogonal().normalized()
	var visual_half_width: float = hit_width * 0.5 * VISUAL_WIDTH_SPREAD_SCALE
	var visual_count: int = _get_visuals_per_tick(owner)
	for visual_index in range(visual_count):
		if effects.size() >= max_visuals:
			break
		var offset := 0.0
		if visual_count <= 1:
			offset = randf_range(-visual_half_width, visual_half_width)
		else:
			var lane_width := visual_half_width * 2.0 / float(visual_count)
			var lane_min := -visual_half_width + lane_width * float(visual_index)
			offset = randf_range(lane_min, lane_min + lane_width)
		var visual_origin: Vector2 = base_origin + perpendicular * offset
		var effect := owner._spawn_gunner_intersect_scene_effect(visual_origin, aim_direction, visual_beam_length, BEAM_THICKNESS, visual_beam_length) as Node2D
		register_effect(effect, max_visuals)

func _get_effect_parameter_length(owner, target_visible_length: float) -> float:
	var visual_scale := 1.0
	if owner != null:
		visual_scale = float(owner.GUNNER_INTERSECT_VISUAL_SCALE)
	return target_visible_length / max(0.001, visual_scale)

func _cleanup_effects() -> void:
	var valid_effects: Array[Node2D] = []
	for effect in effects:
		if effect != null and is_instance_valid(effect) and not effect.is_queued_for_deletion() and not bool(effect.get_meta("gunner_intersect_released", false)):
			valid_effects.append(effect)
	effects = valid_effects

func _get_duration(owner) -> float:
	var tier: int = _get_tier(owner)
	var duration := BASE_DURATION
	if tier >= 3:
		duration = TIER_THREE_DURATION
	elif tier >= 2:
		duration = TIER_TWO_DURATION
	if _has_talent(owner, LEVEL_TALENT_INFINITE_RELOAD_2):
		duration += LEVEL_TALENT_INFINITE_RELOAD_2_DURATION_BONUS
	if owner != null and owner.has_method("_get_blessing_skill_duration_multiplier"):
		duration *= float(owner._get_blessing_skill_duration_multiplier(INFINITE_RELOAD_SKILL_ID))
	if owner != null and owner.has_method("_get_blessing_skill_duration_flat_bonus"):
		duration += float(owner._get_blessing_skill_duration_flat_bonus(INFINITE_RELOAD_SKILL_ID))
	return duration

func _get_range_multiplier(owner) -> float:
	var tier: int = _get_tier(owner)
	var tier_multiplier := 1.0
	if tier >= 3:
		tier_multiplier = TIER_THREE_RANGE_MULTIPLIER
	elif tier >= 2:
		tier_multiplier = TIER_TWO_RANGE_MULTIPLIER
	var invoker_multiplier: float = 1.0
	if owner != null and owner.has_method("_get_invoker_magic_range_multiplier"):
		invoker_multiplier = float(owner._get_invoker_magic_range_multiplier(INFINITE_RELOAD_SKILL_ID))
	return float(owner._get_infinite_reload_range_multiplier()) * tier_multiplier * invoker_multiplier

func _get_width_multiplier(_owner) -> float:
	return 1.0

func _get_max_visuals(_owner) -> int:
	return MAX_VISUALS

func _get_visuals_per_tick(owner) -> int:
	return 2 if _get_tier(owner) >= 2 else 1

func _has_required_unlock(owner) -> bool:
	if owner == null or not owner.has_method("_is_blessing_skill_unlocked"):
		return false
	return bool(owner._is_blessing_skill_unlocked(INFINITE_RELOAD_SKILL_ID))

func _get_cooldown(owner) -> float:
	var cooldown_multiplier: float = PLAYER_BUILD_SYSTEM.get_infinite_reload_cooldown_multiplier(owner)
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		cooldown_multiplier *= float(owner._get_equipment_cooldown_multiplier())
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_mage_arcane_charge_skill_cooldown_multiplier"):
		cooldown_multiplier *= float(owner._get_mage_arcane_charge_skill_cooldown_multiplier("gunner"))
	var cooldown: float = COOLDOWN * cooldown_multiplier
	if _has_talent(owner, LEVEL_TALENT_INFINITE_RELOAD_2):
		cooldown += LEVEL_TALENT_INFINITE_RELOAD_2_COOLDOWN_BONUS
	return cooldown

func _get_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return int(owner._get_blessing_skill_tier(INFINITE_RELOAD_SKILL_ID))
	return 1

func _get_tick_interval(owner) -> float:
	var tier: int = _get_tier(owner)
	if tier >= 3:
		return TICK_INTERVAL * TIER_THREE_TICK_INTERVAL_MULTIPLIER
	if tier >= 2:
		return TICK_INTERVAL * TIER_TWO_TICK_INTERVAL_MULTIPLIER
	return TICK_INTERVAL

func get_move_speed_multiplier(owner) -> float:
	if not is_active():
		return 1.0
	var tier: int = _get_tier(owner)
	var multiplier: float = TIER_ONE_MOVE_SPEED_MULTIPLIER
	if tier >= 3:
		multiplier = TIER_THREE_MOVE_SPEED_MULTIPLIER
	elif tier >= 2:
		multiplier = TIER_TWO_MOVE_SPEED_MULTIPLIER
	return multiplier + PLAYER_BUILD_SYSTEM.get_infinite_reload_move_speed_multiplier_bonus(owner)

func _get_damage_multiplier(owner) -> float:
	var tier: int = _get_tier(owner)
	var multiplier: float = 1.0
	if tier >= 3:
		multiplier = TIER_THREE_DAMAGE_MULTIPLIER
	elif tier >= 2:
		multiplier = TIER_TWO_DAMAGE_MULTIPLIER
	return multiplier + PLAYER_BUILD_SYSTEM.get_infinite_reload_damage_multiplier_bonus(owner)

func _get_combo_scales(owner) -> Array[float]:
	var result: Array[float] = []
	if owner == null or not owner.has_method("_get_blessing_skill_combo_scales"):
		return result
	for scale in owner._get_blessing_skill_combo_scales(INFINITE_RELOAD_SKILL_ID) as Array:
		result.append(float(scale))
	return result

func _get_combined_damage_scale(combo_scales: Array[float]) -> float:
	var damage_scale: float = 1.0
	for combo_scale in combo_scales:
		damage_scale += max(0.0, float(combo_scale))
	return damage_scale

func _get_level_talent_range_bonus(owner) -> float:
	var bonus := 0.0
	if _has_talent(owner, LEVEL_TALENT_INFINITE_RELOAD_1):
		bonus += LEVEL_TALENT_INFINITE_RELOAD_1_RANGE_BONUS
	if _has_talent(owner, LEVEL_TALENT_INFINITE_RELOAD_2):
		bonus += LEVEL_TALENT_INFINITE_RELOAD_2_RANGE_BONUS
	return bonus

func _is_manual_cast(owner) -> bool:
	if cast_talent_snapshot_valid:
		return cast_talent_ids.has(LEVEL_TALENT_INFINITE_RELOAD_1)
	return active_remaining > 0.0 and is_manual_toggle_enabled(owner)

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
	if owner == null or talent_id == "":
		return false
	if talent_id.begins_with("gunner_level_talent_"):
		if owner.has_method("_has_level_talent"):
			return bool(owner._has_level_talent(talent_id))
		return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)
	return owner.has_method("_has_skill_talent") and bool(owner._has_skill_talent(talent_id))

func _normalize_talent_ids(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for talent_id in value:
			var normalized := str(talent_id)
			if TALENT_IDS.has(normalized) and not result.has(normalized):
				result.append(normalized)
	return result

func _uses_batched_damage(owner) -> bool:
	return owner != null and owner.has_method("_damage_enemies_in_shapes_batched")

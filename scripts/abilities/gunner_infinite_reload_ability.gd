extends RefCounted

const BUILD := preload("res://scripts/player/player_gunner_infinite_reload_build.gd")
const RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_AUTHORED_EFFECTS := preload("res://scripts/player/player_authored_effects.gd")
const COOLDOWN := 36.0
const BASE_DURATION := 4.0
const TICK_INTERVAL := 0.25
const BEAM_LENGTH := 400.0
const BEAM_THICKNESS := 34.0
const BASE_WIDTH_MULTIPLIER := 5.0
const MAX_VISUALS := 14
const TURN_SPEED := 150.0
const MIN_TOGGLE_DURATION := 1.0
const SOURCE := "gunner_infinite_reload"
const INFINITE_RELOAD_SKILL_ID := "infinite_reload"

var cooldown_remaining := 0.0
var active_remaining := 0.0
var manual_active_elapsed := 0.0
var tick_remaining := 0.0
var locked_aim_direction := Vector2.RIGHT
var effects: Array[Node2D] = []
var pending_beam_hits: Array[Dictionary] = []
var finish_pending := false
var cast_snapshot: Dictionary = {}
var cooldown_credit := 0.0
var resolving_soul_impact := false

func update(owner, delta: float) -> void:
	delta = maxf(0.0, delta)
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if owner == null or not is_instance_valid(owner):
		stop()
		return
	_update_pending_beam_hits(owner, delta)
	if not is_active():
		if finish_pending and pending_beam_hits.is_empty():
			finish_pending = false
			cast_snapshot.clear()
		return
	if str(owner._get_active_role().get("id", "")) != "gunner":
		_finish_cast(owner)
		return
	var active_delta: float = delta if _choice("fire_control") else minf(delta, active_remaining)
	manual_active_elapsed += active_delta
	if _choice("aim"):
		var desired: Vector2 = _desired_direction(owner)
		if desired.length_squared() > 0.001:
			var turn: float = clampf(locked_aim_direction.angle_to(desired), -deg_to_rad(TURN_SPEED) * active_delta, deg_to_rad(TURN_SPEED) * active_delta)
			locked_aim_direction = locked_aim_direction.rotated(turn).normalized()
	owner.facing_direction = locked_aim_direction
	if owner.has_method("_queue_camera_shake"):
		owner._queue_camera_shake(1.4, 0.045)
	tick_remaining -= active_delta
	if not _choice("fire_control"):
		active_remaining = maxf(0.0, active_remaining - active_delta)
		if active_remaining <= 0.000001:
			active_remaining = 0.0
	# Immediate first shot, then interval ... t<duration: 16/20 ticks per 4s.
	while tick_remaining <= 0.00001 and (is_active() or tick_remaining < -0.00001):
		_trigger_tick(owner, maxf(0.0, -tick_remaining))
		tick_remaining += _tick_interval()
	if not is_active():
		_finish_cast(owner)
		cooldown_remaining = maxf(0.0, cooldown_remaining - (delta - active_delta))

func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and role_id == "gunner" and _has_required_unlock(owner) and not is_active() and cooldown_remaining <= 0.0 and not finish_pending

func try_trigger(owner) -> bool:
	if is_manual_toggle_enabled(owner) or not can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		return false
	return _start_cast(owner, false)

func toggle_manual(owner) -> bool:
	if is_active() and _choice("fire_control"):
		if manual_active_elapsed + 0.00001 < MIN_TOGGLE_DURATION:
			return false
		_finish_cast(owner)
		return true
	if not is_manual_toggle_enabled(owner) or not can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		return false
	return _start_cast(owner, true)

func is_manual_toggle_enabled(owner) -> bool:
	return _choice("fire_control") if is_active() else BUILD.has_choice(owner, "fire_control")

func is_blocking_actions(_owner) -> bool:
	return false

func is_movement_locked(_owner) -> bool:
	return false

func is_preventing_switch(_owner) -> bool:
	return is_active() and _choice("fire_control") and manual_active_elapsed < MIN_TOGGLE_DURATION

func get_dodge_value_bonus(_owner, _role_id: String) -> float:
	return 0.0

func get_dodge_chance_bonus(role_id: String) -> float:
	return 0.3 if role_id == "gunner" and is_active() and _choice("light_step") else 0.0

func is_soul_form_active() -> bool:
	return is_active() and _choice("soul_form")

func get_move_speed_multiplier(_owner) -> float:
	return 1.1 if is_active() and _choice("light_step") else 1.0

func _start_cast(owner, manual_cast: bool) -> bool:
	var selected: Array[String] = []
	for stage in BUILD.STAGES:
		for option in BUILD.OPTIONS[stage]:
			if BUILD.has_choice(owner, option["key"]):
				selected.append(option["key"])
	cast_snapshot = {"choices": selected, "damage_ratio": BUILD.damage_ratio(owner), "range_bonus": BUILD.range_bonus(owner), "cooldown": _get_cooldown(owner)}
	active_remaining = 1.0 if manual_cast else _get_duration(owner)
	manual_active_elapsed = 0.0
	cooldown_remaining = 0.0
	cooldown_credit = 0.0
	finish_pending = false
	locked_aim_direction = owner._get_live_mouse_aim_direction(owner.facing_direction).normalized()
	if locked_aim_direction.length_squared() <= 0.001:
		locked_aim_direction = Vector2.RIGHT
	owner.facing_direction = locked_aim_direction
	owner.gunner_attack_chain = 0
	tick_remaining = _tick_interval()
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -64.0), "无限装填", Color(1.0, 0.6, 0.34))
	owner._spawn_ring_effect(owner.global_position, 104.0, Color(1.0, 0.58, 0.32, 0.34), 8.0, 0.2)
	owner._spawn_burst_effect(owner.global_position, 92.0, Color(1.0, 0.54, 0.28, 0.16), 0.18)
	_trigger_tick(owner)
	return true

func _finish_cast(_owner) -> void:
	var manual := _choice("fire_control")
	active_remaining = 0.0
	manual_active_elapsed = 0.0
	tick_remaining = 0.0
	cooldown_remaining = 0.0 if manual else maxf(0.0, float(cast_snapshot.get("cooldown", COOLDOWN)) - cooldown_credit)
	# Queued beams carry their own choices, so manual mode can reopen immediately.
	finish_pending = not manual and not pending_beam_hits.is_empty()
	if not finish_pending:
		cast_snapshot.clear()

func stop(_owner = null) -> void:
	active_remaining = 0.0
	manual_active_elapsed = 0.0
	tick_remaining = 0.0
	cast_snapshot.clear()
	pending_beam_hits.clear()
	finish_pending = false
	cooldown_credit = 0.0
	resolving_soul_impact = false
	for effect in effects:
		_release_visual_effect(effect)
	effects.clear()

func is_active() -> bool:
	return active_remaining > 0.0

func _choice(key: String) -> bool:
	return (cast_snapshot.get("choices", []) as Array).has(key)

func _tick_interval() -> float:
	return 0.2 if _choice("dual_impact") else TICK_INTERVAL

func _desired_direction(owner) -> Vector2:
	return owner._get_live_mouse_aim_direction(locked_aim_direction)

func _trigger_tick(owner, overdue: float = 0.0) -> void:
	var direction := locked_aim_direction
	var length: float = (BEAM_LENGTH + float(cast_snapshot.get("range_bonus", 0.0))) * float(owner._get_role_attribute_range_multiplier("gunner")) * float(owner._get_equipment_skill_range_multiplier())
	if owner.has_method("_get_invoker_magic_range_multiplier"):
		length *= float(owner._get_invoker_magic_range_multiplier(INFINITE_RELOAD_SKILL_ID))
	var width := BEAM_THICKNESS * BASE_WIDTH_MULTIPLIER * 2.0
	var origin: Vector2 = owner.global_position + direction * 20.0
	var damage: float = float(owner._get_role_damage("gunner")) * float(cast_snapshot.get("damage_ratio", 0.4))
	if owner.has_method("_get_blessing_skill_combo_scales"):
		for scale in owner._get_blessing_skill_combo_scales(INFINITE_RELOAD_SKILL_ID):
			damage += float(owner._get_role_damage("gunner")) * float(cast_snapshot.get("damage_ratio", 0.4)) * maxf(0.0, float(scale))
			if not _choice("dual_impact"):
				var combo_origin: Vector2 = origin + direction.orthogonal() * randf_range(-width * 0.25, width * 0.25)
				_spawn_visuals(owner, combo_origin, direction, length, width * 0.5)
	var shapes: Array[Dictionary] = []
	var dual := _choice("dual_impact")
	for side in [-1.0, 1.0] if dual else [0.0]:
		var lane_origin: Vector2 = origin + direction.orthogonal() * width * 0.35 * side
		var lane_width: float = width * 0.65 if dual else width
		_spawn_visuals(owner, lane_origin, direction, length, lane_width * 0.5)
		shapes.append({"type": "oriented_rect", "center": lane_origin + direction * length * 0.5, "axis": direction, "length": length, "width": lane_width, "damage_amount": damage, "source_position": lane_origin, "soul_impact": _choice("soul_impact"), "soul_form": _choice("soul_form"), "manual": _choice("fire_control")})
	var delay: float = maxf(0.0, float(owner._get_gunner_intersect_gather_duration()) - overdue) if owner.has_method("_get_gunner_intersect_gather_duration") else maxf(0.0, 0.2 - overdue)
	if delay <= 0.0:
		_apply_piercing_beam_shapes(owner, shapes)
	else:
		pending_beam_hits.append({"remaining": delay, "shapes": shapes})

func _update_pending_beam_hits(owner, delta: float) -> void:
	var waiting: Array[Dictionary] = []
	var ready: Array[Dictionary] = []
	for hit in pending_beam_hits:
		hit["remaining"] = float(hit.get("remaining", 0.0)) - delta
		if float(hit["remaining"]) <= 0.0:
			ready.append(hit)
		else:
			waiting.append(hit)
	pending_beam_hits = waiting
	for hit in ready:
		var shapes: Array[Dictionary] = []
		for shape in hit.get("shapes", []):
			shapes.append(shape)
		_apply_piercing_beam_shapes(owner, shapes)

func _apply_piercing_beam_shapes(owner, shapes: Array[Dictionary]) -> int:
	var count := 0
	# Reuse spatial queries, but resolve lanes independently and sequentially.
	var candidates: Array = RESOLVER._get_candidate_enemies_for_shapes(owner, shapes).duplicate()
	for shape in shapes:
		for enemy in candidates:
			if not RESOLVER._is_live_enemy(enemy) or enemy is not Node2D or not RESOLVER._shape_hits_enemy_node(owner, shape, enemy):
				continue
			resolving_soul_impact = bool(shape.get("soul_impact", false))
			var killed: bool = RESOLVER.deal_damage_to_enemy(owner, enemy, float(shape["damage_amount"]), SOURCE, 0.0, 2.0, 1.0, 0.0, shape["source_position"])
			resolving_soul_impact = false
			count += 1
			if killed and bool(shape.get("soul_form", false)) and not bool(shape.get("manual", false)):
				if is_active():
					cooldown_credit += 0.3
				else:
					cooldown_remaining = maxf(0.0, cooldown_remaining - 0.3)
	return count

func resolve_soul_impact(enemy) -> bool:
	if not resolving_soul_impact or not RESOLVER._is_live_enemy(enemy) or not enemy.has_method("take_soul_impact_damage"):
		return false
	return bool(enemy.take_soul_impact_damage(maxf(0.0, float(enemy.get("current_health"))) * 0.01))

func get_cooldown_slot(owner = null) -> Dictionary:
	var duration: float = _get_cooldown(owner)
	var remaining := cooldown_remaining
	var text := BUILD.description(owner)
	if is_active() and _choice("fire_control"):
		duration = MIN_TOGGLE_DURATION
		remaining = maxf(0.0, duration - manual_active_elapsed)
		text += "\n已开启；" + ("至少开启1秒后可关闭。" if remaining > 0.0 else "再次按下关闭。")
	return {"name": "无限装填", "remaining": remaining, "duration": duration, "color": Color(1.0, 0.56, 0.28), "description": text, "toggle_mode": is_manual_toggle_enabled(owner)}

func _get_duration(owner) -> float:
	var duration := BASE_DURATION
	if owner.has_method("_get_blessing_skill_duration_multiplier"):
		duration *= float(owner._get_blessing_skill_duration_multiplier(INFINITE_RELOAD_SKILL_ID))
	if owner.has_method("_get_blessing_skill_duration_flat_bonus"):
		duration += float(owner._get_blessing_skill_duration_flat_bonus(INFINITE_RELOAD_SKILL_ID))
	return duration

func _get_cooldown(owner) -> float:
	if BUILD.has_choice(owner, "fire_control"):
		return 0.0
	var multiplier := 1.0
	if owner != null and is_instance_valid(owner):
		if owner.has_method("_get_equipment_cooldown_multiplier"):
			multiplier *= float(owner._get_equipment_cooldown_multiplier())
		if owner.has_method("_get_mage_arcane_charge_skill_cooldown_multiplier"):
			multiplier *= float(owner._get_mage_arcane_charge_skill_cooldown_multiplier("gunner"))
	return COOLDOWN * multiplier

func _has_required_unlock(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(INFINITE_RELOAD_SKILL_ID))

func register_effect(effect: Node2D, max_visuals: int = MAX_VISUALS) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	_cleanup_effects()
	effects.append(effect)
	while effects.size() > max_visuals:
		_release_visual_effect(effects.pop_front())

func _release_visual_effect(effect: Node2D) -> void:
	if effect != null and is_instance_valid(effect):
		PLAYER_AUTHORED_EFFECTS.release_gunner_intersect_effect(effect)

func _spawn_visuals(owner, origin: Vector2, direction: Vector2, length: float, width: float) -> void:
	_cleanup_effects()
	var parameter_length: float = length / maxf(0.001, float(owner.GUNNER_INTERSECT_VISUAL_SCALE))
	var perpendicular: Vector2 = owner._get_downward_perpendicular(direction).normalized()
	var visual_origin: Vector2 = origin + perpendicular * randf_range(-width * 0.46, width * 0.46)
	register_effect(owner._spawn_gunner_intersect_scene_effect(visual_origin, direction, parameter_length, BEAM_THICKNESS, parameter_length) as Node2D)

func _cleanup_effects() -> void:
	var valid: Array[Node2D] = []
	for effect in effects:
		if effect != null and is_instance_valid(effect) and not effect.is_queued_for_deletion() and not bool(effect.get_meta("gunner_intersect_released", false)):
			valid.append(effect)
	effects = valid

func get_save_data() -> Dictionary:
	var hits: Array = []
	for hit in pending_beam_hits:
		var saved := {"remaining": hit["remaining"], "shapes": []}
		for shape in hit["shapes"]:
			var copy: Dictionary = shape.duplicate(true)
			for key in ["center", "axis", "source_position"]:
				var point: Vector2 = copy[key]
				copy[key] = [point.x, point.y]
			saved["shapes"].append(copy)
		hits.append(saved)
	return {"build_version": 1, "cooldown_remaining": cooldown_remaining, "active_remaining": active_remaining, "manual_active_elapsed": manual_active_elapsed, "tick_remaining": tick_remaining, "locked_aim_direction": [locked_aim_direction.x, locked_aim_direction.y], "cast_snapshot": cast_snapshot.duplicate(true), "cooldown_credit": cooldown_credit, "pending_beam_hits": hits, "finish_pending": finish_pending}

func apply_save_data(data: Dictionary) -> void:
	stop()
	cooldown_remaining = maxf(0.0, float(data.get("cooldown_remaining", 0.0)))
	# Old casts have no build snapshot and must not resume obsolete mechanics.
	if int(data.get("build_version", 0)) != 1:
		return
	active_remaining = maxf(0.0, float(data.get("active_remaining", 0.0)))
	manual_active_elapsed = maxf(0.0, float(data.get("manual_active_elapsed", 0.0)))
	tick_remaining = maxf(0.0, float(data.get("tick_remaining", 0.0)))
	cast_snapshot = data.get("cast_snapshot", {}).duplicate(true)
	cooldown_credit = maxf(0.0, float(data.get("cooldown_credit", 0.0)))
	finish_pending = bool(data.get("finish_pending", false))
	var direction: Array = data.get("locked_aim_direction", [1.0, 0.0])
	if direction.size() >= 2:
		locked_aim_direction = Vector2(float(direction[0]), float(direction[1])).normalized()
	if locked_aim_direction.length_squared() <= 0.001:
		locked_aim_direction = Vector2.RIGHT
	for hit in data.get("pending_beam_hits", []):
		var restored: Dictionary = hit.duplicate(true)
		for shape in restored.get("shapes", []):
			for key in ["center", "axis", "source_position"]:
				var point: Array = shape.get(key, [0.0, 0.0])
				shape[key] = Vector2(float(point[0]), float(point[1]))
		pending_beam_hits.append(restored)

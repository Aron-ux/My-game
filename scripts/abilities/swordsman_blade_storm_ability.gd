extends RefCounted

const BUILD := preload("res://scripts/player/player_blade_storm_build.gd")
const GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")
const DAMAGE := preload("res://scripts/player/player_damage_resolver.gd")
const EFFECT := preload("res://effects/sword/tornado/tornado.tscn")
const COOLDOWN := 32.0
const BASE_DURATION := 2.7
const BASE_RADIUS := 150.0
const BASE_TICK_INTERVAL := 0.3
var cooldown_remaining := 0.0
var active_remaining := 0.0
var tick_remaining := 0.0
var breath_remaining := 0.0
var detached := false
var cast_origin := Vector2.ZERO
var cast_direction := Vector2.RIGHT
var cast_duration := 2.7
var cast_ratio := 0.8
var cast_radius := 150.0
var cast_choices: Dictionary = {}
var effect: Node2D
var serial := 0

func can_trigger(owner, role_id: String) -> bool:
	return owner != null and not owner.is_dead and not owner.level_up_active and role_id == "swordsman" and owner._is_blessing_skill_unlocked("blade_storm") and active_remaining <= 0.0 and cooldown_remaining <= 0.0

func try_trigger(owner) -> bool:
	if not can_trigger(owner, owner._get_active_role_id()):
		return false
	cast_choices = {}
	for stage in BUILD.STAGES:
		for option in BUILD.OPTIONS[stage]:
			if BUILD.has_choice(owner, option["key"]):
				cast_choices[option["key"]] = true
	cast_duration = BUILD.duration(owner)
	cast_ratio = BUILD.damage_ratio(owner)
	cast_radius = BUILD.radius(owner)
	if owner.has_method("_get_equipment_skill_range_multiplier"):
		cast_radius *= owner._get_equipment_skill_range_multiplier()
	active_remaining = cast_duration
	cooldown_remaining = _get_cooldown(owner)
	tick_remaining = BASE_TICK_INTERVAL
	detached = false
	cast_origin = owner.global_position
	_ensure_effect(owner)
	return true

func update(owner, delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	var had_breath := breath_remaining > 0.0
	breath_remaining = maxf(0.0, breath_remaining - delta)
	if had_breath and breath_remaining == 0.0:
		_refresh(owner)
	if active_remaining <= 0.0:
		return
	if owner == null or not is_instance_valid(owner) or owner.is_dead:
		stop()
		return
	if not detached and owner._get_active_role_id() != "swordsman":
		stop()
		return
	var remaining_delta := delta
	while remaining_delta > 0.00001 and active_remaining > 0.0:
		var step := minf(remaining_delta, minf(active_remaining, tick_remaining))
		if detached:
			cast_origin += cast_direction * 150.0 * step
		else:
			cast_origin = owner.global_position
		_apply_aura(owner, step)
		active_remaining = maxf(0.0, active_remaining - step)
		tick_remaining -= step
		remaining_delta -= step
		if tick_remaining <= 0.00001:
			_trigger_tick(owner)
			tick_remaining = BASE_TICK_INTERVAL
		if active_remaining <= 0.00001:
			if detached:
				stop()
			else:
				_finish_attached(owner)
	_update_effect(owner, delta)

func _finish_attached(owner) -> void:
	if cast_choices.has("breath"):
		breath_remaining = 15.0
		_refresh(owner)
	if cast_choices.has("tornado"):
		detached = true
		active_remaining = cast_duration
		tick_remaining = BASE_TICK_INTERVAL
		cast_direction = owner._get_attack_aim_direction(owner.facing_direction).normalized()
		if cast_direction.is_zero_approx():
			cast_direction = Vector2.RIGHT
	else:
		stop()

func _apply_aura(owner, delta: float) -> void:
	if not cast_choices.has("typhoon") and not cast_choices.has("gale"):
		return
	var scene: Node = owner.get_tree().current_scene
	var radius := 300.0 if cast_choices.has("gale") else 220.0
	for enemy in GRID.get_neighbors_at(scene, cast_origin, radius):
		if not is_instance_valid(enemy) or enemy.current_health <= 0.0:
			continue
		var distance: float = enemy.global_position.distance_to(cast_origin)
		if distance > radius:
			continue
		if cast_choices.has("typhoon"):
			enemy.global_position = enemy.global_position.move_toward(cast_origin, 60.0 * delta)
		if cast_choices.has("gale"):
			if enemy.has_method("apply_slow_from_source"):
				enemy.apply_slow_from_source(0.7, 0.4, "swordsman_blade_storm", true)
			else:
				enemy.apply_slow_silent(0.7, 0.4)

func _trigger_tick(owner) -> void:
	serial += 1
	var source := "swordsman_aux:storm"
	var windblade := cast_choices.has("windblade")
	if windblade:
		source = "swordsman_basic:windblade:%d:%d" % [owner.get_instance_id(), serial]
		owner._push_attack_result_context_tag("windblade_double_proc")
		owner._push_attack_result_context_tag("swordsman_basic_attack")
	var hits := 0
	var kills := 0
	var amount: float = owner._get_role_damage("swordsman") * cast_ratio
	for enemy in GRID.get_neighbors_at(owner.get_tree().current_scene, cast_origin, cast_radius):
		if not is_instance_valid(enemy) or enemy.current_health <= 0.0 or enemy.global_position.distance_squared_to(cast_origin) > cast_radius * cast_radius:
			continue
		var health_before: float = enemy.current_health
		if DAMAGE.deal_damage_to_enemy(owner, enemy, amount, source):
			kills += 1
		if cast_choices.has("rend") and is_instance_valid(enemy) and enemy.current_health > 0.0 and enemy.current_health < health_before:
			enemy.storm_armor_shred_timers.append(preload("res://scripts/combat/status_resistance.gd").duration(enemy, 15.0))
		hits += 1
	if hits > 0:
		owner._register_attack_result("swordsman", hits, kills > 0, kills)
	if windblade:
		owner._pop_attack_result_context_tag("windblade_double_proc")
		owner._pop_attack_result_context_tag("swordsman_basic_attack")

func is_active() -> bool:
	return active_remaining > 0.0 and not detached

func get_buff_slot() -> Dictionary:
	if breath_remaining <= 0.0:
		return {}
	return {
		"id": "blade_storm_breath",
		"name": "风息",
		"description": "移动速度+10%、闪避率+25%、冷却缩减+20%、基础攻击速度+0.3；切换角色后保留。",
		"text": "息",
		"color": Color(0.38, 0.94, 0.76, 0.96),
		"base_color": Color(0.08, 0.30, 0.24, 0.92),
		"remaining": breath_remaining,
		"duration": 15.0,
		"cooldown": false
	}

func stop(_owner = null) -> void:
	active_remaining = 0.0
	tick_remaining = BASE_TICK_INTERVAL
	detached = false
	if is_instance_valid(effect):
		effect.hide()

func get_stat_bonus(owner, role_id: String, stat: String) -> float:
	if owner._get_active_role_id() != role_id:
		return 0.0
	var gale := is_active() and cast_choices.has("gale") and role_id == "swordsman"
	var breath := breath_remaining > 0.0
	match stat:
		"armor": return 30.0 if gale else 0.0
		"move": return (0.15 if gale else 0.0) + (0.1 if breath else 0.0)
		"dodge": return 1.0 - (0.7 if gale else 1.0) * (0.75 if breath else 1.0)
		"speed": return 0.3 if breath else 0.0
		"cooldown": return 0.2 if breath else 0.0
	return 0.0

func _refresh(owner) -> void:
	if owner != null and owner.has_method("_update_fire_timer"):
		owner._update_fire_timer()

func _ensure_effect(owner) -> void:
	if not is_instance_valid(effect):
		effect = EFFECT.instantiate()
		owner.add_child(effect)
		effect.z_index = 18
	effect.show()
	var sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.scale = Vector2.ONE * 0.48 * cast_radius / 120.0
		sprite.play()
	_update_effect(owner)

func _update_effect(_owner, delta: float = 0.0) -> void:
	if is_instance_valid(effect) and active_remaining > 0.0:
		effect.global_position = cast_origin
		effect.rotation = wrapf(effect.rotation - TAU * 5.175 * delta, 0.0, TAU)

func _get_cooldown(owner) -> float:
	return COOLDOWN * float(owner._get_equipment_cooldown_multiplier()) * float(owner._get_mage_arcane_charge_skill_cooldown_multiplier("swordsman")) if owner != null else COOLDOWN

func get_cooldown_slot(owner = null) -> Dictionary:
	return {"name": "剑刃风暴", "remaining": cooldown_remaining, "duration": _get_cooldown(owner), "color": Color(0.34, 0.92, 1.0), "description": BUILD.description(owner)}

func get_save_data() -> Dictionary:
	return {"cooldown_remaining": cooldown_remaining, "active_remaining": active_remaining, "tick_remaining": tick_remaining, "breath_remaining": breath_remaining, "detached": detached, "cast_origin": [cast_origin.x, cast_origin.y], "cast_direction": [cast_direction.x, cast_direction.y], "cast_duration": cast_duration, "cast_ratio": cast_ratio, "cast_radius": cast_radius, "cast_choices": cast_choices.duplicate(), "serial": serial}

func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = maxf(0.0, float(data.get("cooldown_remaining", 0.0)))
	active_remaining = maxf(0.0, float(data.get("active_remaining", 0.0)))
	tick_remaining = clampf(float(data.get("tick_remaining", 0.3)), 0.00001, 0.3)
	breath_remaining = clampf(float(data.get("breath_remaining", 0.0)), 0.0, 15.0)
	detached = bool(data.get("detached", false))
	cast_origin = _vector(data.get("cast_origin", Vector2.ZERO))
	cast_direction = _vector(data.get("cast_direction", Vector2.RIGHT))
	cast_duration = maxf(0.3, float(data.get("cast_duration", 2.7)))
	cast_ratio = maxf(0.0, float(data.get("cast_ratio", 0.8)))
	cast_radius = maxf(1.0, float(data.get("cast_radius", 150.0)))
	cast_choices = data.get("cast_choices", {}).duplicate()
	serial = int(data.get("serial", 0))

func _vector(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2(float(value[0]), float(value[1]))

func restore_effect_if_active(owner) -> void:
	if active_remaining > 0.0:
		_ensure_effect(owner)

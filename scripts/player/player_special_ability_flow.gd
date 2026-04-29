extends RefCounted


static func trigger_dangzhen_sword_qichao_preview(owner, attack_direction: Vector2, _attack_damage: float, role_id: String) -> int:
	if owner.swordsman_dangzhen_fan_ability == null:
		return 0
	return owner.swordsman_dangzhen_fan_ability.try_trigger(owner, attack_direction, role_id)


static func execute_dangzhen_gunner_beam(owner, origin: Vector2, fire_direction: Vector2, damage_amount: float, role_id: String) -> int:
	if owner.gunner_dangzhen_beam_ability == null:
		return 0
	return owner.gunner_dangzhen_beam_ability.execute_beam(owner, origin, fire_direction, damage_amount, role_id)


static func trigger_dangzhen_gunner_qichao_preview(owner, shot_direction: Vector2, _attack_damage: float, role_id: String) -> int:
	if owner.gunner_dangzhen_beam_ability == null:
		return 0
	return owner.gunner_dangzhen_beam_ability.try_trigger(owner, shot_direction, role_id)


static func get_live_mouse_aim_direction(owner, fallback_direction: Vector2 = Vector2.RIGHT) -> Vector2:
	if owner.has_method("_get_attack_aim_direction"):
		return owner._get_attack_aim_direction(fallback_direction)
	var mouse_direction: Vector2 = owner.get_global_mouse_position() - owner.global_position
	if mouse_direction.length_squared() > 4.0:
		return mouse_direction.normalized()
	if owner.facing_direction.length_squared() > 0.001:
		return owner.facing_direction.normalized()
	if fallback_direction.length_squared() > 0.001:
		return fallback_direction.normalized()
	return Vector2.RIGHT


static func try_trigger_independent_mage_qichao(owner) -> void:
	if owner.is_dead or owner.level_up_active:
		return
	var active_role_id: String = str(owner._get_active_role().get("id", ""))
	if active_role_id != "mage":
		return
	if owner.mage_dangzhen_wave_ability == null or not owner.mage_dangzhen_wave_ability.can_trigger(owner, active_role_id):
		return
	var wave_direction: Vector2 = get_live_mouse_aim_direction(owner, owner.facing_direction)
	owner.mage_dangzhen_wave_ability.try_trigger(owner, wave_direction, active_role_id)


static func try_trigger_independent_sword_qichao(owner) -> void:
	if owner.is_dead or owner.level_up_active:
		return
	var active_role_id: String = str(owner._get_active_role().get("id", ""))
	if active_role_id != "swordsman":
		return
	if owner._get_card_level("battle_dangzhen_qichao") <= 0:
		return
	if owner.swordsman_dangzhen_fan_ability == null or not owner.swordsman_dangzhen_fan_ability.can_trigger(owner, active_role_id):
		return
	var attack_direction: Vector2 = get_live_mouse_aim_direction(owner, owner.facing_direction)
	var dangzhen_hits: int = trigger_dangzhen_sword_qichao_preview(owner, attack_direction, owner._get_role_damage(active_role_id), active_role_id)
	if dangzhen_hits > 0:
		owner._register_attack_result(active_role_id, dangzhen_hits, false)


static func try_trigger_independent_gunner_qichao(owner) -> void:
	if owner.is_dead or owner.level_up_active:
		return
	var active_role_id: String = str(owner._get_active_role().get("id", ""))
	if active_role_id != "gunner":
		return
	if is_gunner_infinite_reload_active(owner):
		return
	if owner.gunner_dangzhen_beam_ability == null or not owner.gunner_dangzhen_beam_ability.can_trigger(owner, active_role_id):
		return
	var shot_direction: Vector2 = get_live_mouse_aim_direction(owner, owner.facing_direction)
	var dangzhen_hits: int = trigger_dangzhen_gunner_qichao_preview(owner, shot_direction, owner._get_role_damage(active_role_id), active_role_id)
	if dangzhen_hits > 0:
		owner._register_attack_result(active_role_id, dangzhen_hits, false)


static func try_trigger_swordsman_blade_storm(owner) -> void:
	var active_role_id: String = str(owner._get_active_role().get("id", ""))
	if owner.swordsman_blade_storm_ability == null or not owner.swordsman_blade_storm_ability.can_trigger(owner, active_role_id):
		return
	start_swordsman_blade_storm(owner)


static func try_trigger_gunner_infinite_reload(owner) -> void:
	if owner.is_dead or owner.level_up_active:
		return
	if owner.gunner_infinite_reload_ability == null:
		return
	var active_role_id: String = str(owner._get_active_role().get("id", ""))
	if not owner.gunner_infinite_reload_ability.can_trigger(owner, active_role_id):
		return
	start_gunner_infinite_reload(owner)


static func start_swordsman_blade_storm(owner) -> void:
	if owner.swordsman_blade_storm_ability != null:
		owner.swordsman_blade_storm_ability.try_trigger(owner)
	return
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -66.0), "剑刃风暴", Color(0.42, 0.9, 1.0, 1.0))


static func trigger_swordsman_blade_storm_tick(owner) -> void:
	if owner.swordsman_blade_storm_ability != null:
		owner.swordsman_blade_storm_ability._trigger_tick(owner)


static func ensure_swordsman_blade_storm_effect(owner) -> void:
	if owner.swordsman_blade_storm_ability != null:
		owner.swordsman_blade_storm_ability.restore_effect_if_active(owner)


static func update_swordsman_blade_storm_effect(owner, delta: float) -> void:
	if owner.swordsman_blade_storm_ability != null:
		owner.swordsman_blade_storm_ability._update_effect(owner, delta)


static func stop_swordsman_blade_storm(owner) -> void:
	if owner.swordsman_blade_storm_ability != null:
		owner.swordsman_blade_storm_ability.stop()


static func cleanup_gunner_infinite_reload_effects(owner) -> void:
	if owner.gunner_infinite_reload_ability != null:
		owner.gunner_infinite_reload_ability._cleanup_effects()


static func register_gunner_infinite_reload_effect(owner, effect: Node2D) -> void:
	if owner.gunner_infinite_reload_ability != null:
		owner.gunner_infinite_reload_ability.register_effect(effect)


static func start_gunner_infinite_reload(owner) -> void:
	if owner.gunner_infinite_reload_ability != null:
		owner.gunner_infinite_reload_ability.try_trigger(owner)


static func trigger_gunner_infinite_reload_tick(owner) -> void:
	if owner.gunner_infinite_reload_ability != null:
		owner.gunner_infinite_reload_ability._trigger_tick(owner)


static func stop_gunner_infinite_reload(owner) -> void:
	if owner.gunner_infinite_reload_ability != null:
		owner.gunner_infinite_reload_ability.stop()


static func is_gunner_infinite_reload_active(owner) -> bool:
	return owner.gunner_infinite_reload_ability != null and owner.gunner_infinite_reload_ability.is_active()


static func try_trigger_mage_tidal_surge(owner) -> void:
	if owner.is_dead or owner.level_up_active:
		return
	var active_role_id: String = str(owner._get_active_role().get("id", ""))
	if owner.mage_tidal_surge_ability == null or not owner.mage_tidal_surge_ability.can_trigger(owner, active_role_id):
		return
	start_mage_tidal_surge(owner)


static func start_mage_tidal_surge(owner) -> void:
	if owner.mage_tidal_surge_ability == null:
		return
	var base_direction: Vector2 = get_live_mouse_aim_direction(owner, owner.facing_direction)
	owner.mage_tidal_surge_ability.try_trigger(owner, base_direction)

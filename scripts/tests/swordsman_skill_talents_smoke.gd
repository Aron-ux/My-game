extends SceneTree

const BladeStorm := preload("res://scripts/abilities/swordsman_blade_storm_ability.gd")
const CrescentWave := preload("res://scripts/abilities/swordsman_crescent_wave_ability.gd")
const SurvivalFlow := preload("res://scripts/player/player_survival_flow.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := TalentOwner.new()
	root.add_child(owner)
	owner.talents = {"swordsman_crescent_full_moon": true}
	var crescent = CrescentWave.new()
	if not is_equal_approx(crescent._get_wave_speed(owner), 500.0):
		failures.append("full moon should replace base wave speed with 500")

	owner.talents = {"swordsman_crescent_return": true}
	var projectile := Node2D.new()
	root.add_child(projectile)
	crescent.active_crescent_projectiles.append({
		"owner_ref": weakref(owner),
		"projectile": projectile,
		"token": -1,
		"origin": Vector2.ZERO,
		"direction": Vector2.RIGHT,
		"length": 100.0,
		"width": 20.0,
		"damage_amount": 40.0,
		"duration": 1.0,
		"elapsed": 0.0,
		"damage_elapsed": 0.0,
		"last_damage_progress": 0.0,
		"hit_registry": {},
		"returned": false
	})
	projectile.set_meta("crescent_projectile_token", -1)
	crescent._update_crescent_projectiles(1.0)
	var returned: Dictionary = crescent.active_crescent_projectiles[0]
	if not bool(returned.get("returned", false)):
		failures.append("crescent return should keep the projectile for one reverse trip")
	if not is_equal_approx(float(returned.get("damage_amount", 0.0)), 24.0):
		failures.append("crescent return should deal 60 percent damage")
	if not (returned.get("hit_registry", {}) as Dictionary).is_empty():
		failures.append("crescent return should use an independent hit registry")

	owner.talents = {"swordsman_blade_storm_stationary": true}
	owner.global_position = Vector2(300.0, 200.0)
	var blade = BladeStorm.new()
	blade.cast_origin = Vector2(40.0, 50.0)
	var centers: Array[Vector2] = blade._get_storm_centers(owner)
	if centers.is_empty() or centers[0] != Vector2(40.0, 50.0):
		failures.append("stationary blade storm should stay at its cast origin")

	_check_last_guard()
	owner.queue_free()
	if failures.is_empty():
		print("SWORDSMAN_SKILL_TALENTS_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_last_guard() -> void:
	var owner := TalentOwner.new()
	root.add_child(owner)
	owner.talents = {"swordsman_trait_last_guard": true}

	SurvivalFlow.take_damage(owner, 10.0)
	if owner.active_role_index != 1 or owner.swordsman_death_defiance_cooldown_remaining > 0.0:
		failures.append("last guard should not trigger on nonlethal damage")

	owner.current_health = 100.0
	owner.role_health_values["gunner"] = 100.0
	SurvivalFlow.take_damage(owner, 100.0)
	if owner.active_role_index != 0:
		failures.append("last guard should force switch to swordsman")
	if not is_equal_approx(float(owner.role_health_values.get("gunner", 0.0)), 30.0):
		failures.append("last guard should restore the rescued role to 30 percent health")
	if not is_zero_approx(float(owner.role_switch_energy_values.get("gunner", -1.0))):
		failures.append("last guard should clear the rescued role switch energy")
	if not is_equal_approx(owner.swordsman_death_defiance_cooldown_remaining, 80.0):
		failures.append("last guard should start the shared 80 second cooldown")
	owner.queue_free()


class TalentOwner:
	extends Node2D

	signal health_changed(current: float, maximum: float)

	const SWORDSMAN_DEATH_DEFIANCE_COOLDOWN := 80.0

	var talents: Dictionary = {}
	var role_special_states: Dictionary = {"swordsman": {"build_levels": {}}}
	var roles: Array = [{"id": "swordsman"}, {"id": "gunner"}, {"id": "mage"}]
	var active_role_index := 1
	var role_health_values := {"swordsman": 100.0, "gunner": 100.0, "mage": 100.0}
	var role_switch_energy_values := {"swordsman": 0.0, "gunner": 100.0, "mage": 0.0}
	var current_health := 100.0
	var max_health := 100.0
	var current_temporary_health := 0.0
	var is_dead := false
	var switch_invulnerability_remaining := 0.0
	var hurt_cooldown_remaining := 0.0
	var hurt_cooldown := 0.4
	var swordsman_death_defiance_cooldown_remaining := 0.0
	var swordsman_death_defiance_will_remaining := 0.0

	func _has_skill_talent(talent_id: String) -> bool:
		return bool(talents.get(talent_id, false))

	func _get_active_role() -> Dictionary:
		return roles[active_role_index]

	func _try_equipment_dodge() -> bool:
		return false

	func _get_effective_damage_taken_multiplier() -> float:
		return 1.0

	func _save_active_role_health() -> void:
		role_health_values[str(_get_active_role().get("id", ""))] = current_health

	func _has_full_switch_energy(role_id: String) -> bool:
		return float(role_switch_energy_values.get(role_id, 0.0)) >= 100.0

	func _set_role_switch_energy(role_id: String, value: float) -> void:
		role_switch_energy_values[role_id] = value

	func _get_role_current_health(role_id: String) -> float:
		return float(role_health_values.get(role_id, 0.0))

	func _get_role_max_health(_role_id: String) -> float:
		return 100.0

	func _try_switch_role(index: int, _ignore_cooldown: bool = false, _force: bool = false) -> bool:
		active_role_index = index
		return true

	func _play_player_hurt_feedback() -> void:
		pass

	func _damage_enemies_in_oriented_rect_unique(_center: Vector2, _axis: Vector2, _length: float, _width: float, _damage: float, _vulnerability: float, _slow: float, _slow_duration: float, _registry: Dictionary, _role_id: String) -> int:
		return 0

	func _register_attack_result(_role_id: String, _hits: int, _killed: bool) -> void:
		pass

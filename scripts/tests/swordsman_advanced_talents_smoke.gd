extends SceneTree

const BladeStorm := preload("res://scripts/abilities/swordsman_blade_storm_ability.gd")
const CrescentWave := preload("res://scripts/abilities/swordsman_crescent_wave_ability.gd")
const CombatResultFlow := preload("res://scripts/player/player_combat_result_flow.gd")
const SurvivalFlow := preload("res://scripts/player/player_survival_flow.gd")
const SwordsmanRole := preload("res://scripts/player/roles/swordsman_role.gd")


func _init() -> void:
	var owner := TalentOwner.new()
	root.add_child(owner)
	_check_trait_states(owner)
	_check_crescent_branches(owner)
	_check_blade_storm_recall(owner)
	_check_ultimate_pursuit()
	_check_ultimate_talent_snapshot(owner)
	print("SWORDSMAN_ADVANCED_TALENTS_SMOKE_OK")
	quit()


func _check_trait_states(owner: TalentOwner) -> void:
	owner.talents = {
		"swordsman_trait_blood_surge": true,
		"swordsman_trait_guard_stance": true,
		"swordsman_trait_head_high": true,
		"swordsman_trait_unyielding": true
	}
	owner.role_health_values["swordsman"] = 30.0
	CombatResultFlow._activate_swordsman_heal_talents(owner)
	var state: Dictionary = owner.role_special_states["swordsman"]
	assert(is_equal_approx(float(state["blood_surge_remaining"]), 2.0))
	assert(is_equal_approx(float(state["guard_stance_remaining"]), 2.0))
	assert(is_equal_approx(float(state["head_high_remaining"]), 2.0))
	assert(is_equal_approx(float(state["unyielding_remaining"]), 1.2))
	assert(is_equal_approx(SurvivalFlow._get_swordsman_talent_damage_taken_multiplier(owner), 0.60))
	assert(is_equal_approx(SurvivalFlow._get_swordsman_talent_move_multiplier(owner), 1.25))
	assert(is_equal_approx(SwordsmanRole.new().get_talent_basic_attack_interval_multiplier(owner), 1.0 / 1.15))
	owner.switch_power_remaining = 3.0
	owner.switch_power_role_id = "swordsman"
	owner.switch_power_label = "血战昂扬"
	assert(is_equal_approx(CombatResultFlow.get_swordsman_blood_surge_multiplier(owner) * 1.15, 1.35))
	CombatResultFlow.consume_swordsman_blood_surge(owner)
	assert(is_equal_approx(CombatResultFlow.get_swordsman_blood_surge_multiplier(owner), 1.0))


func _check_crescent_branches(owner: TalentOwner) -> void:
	owner.talents = {"swordsman_crescent_twin_moons": true}
	var directions: Array[Vector2] = CrescentWave.new()._get_cast_directions(owner, Vector2.RIGHT)
	assert(directions.size() == 2)
	assert(is_equal_approx(rad_to_deg(directions[1].angle()), 18.0))


func _check_blade_storm_recall(owner: TalentOwner) -> void:
	owner.talents = {"swordsman_blade_storm_recall": true}
	var enemy := Node2D.new()
	root.add_child(enemy)
	owner.live_enemies = [enemy]
	var blade = BladeStorm.new()
	blade.cast_origin = Vector2.ZERO
	enemy.global_position = Vector2(100.0, 0.0)
	blade._update_recall(owner, 0.1)
	enemy.global_position = Vector2(220.0, 0.0)
	blade._update_recall(owner, 0.1)
	assert(is_equal_approx(enemy.global_position.x, 130.0))
	enemy.queue_free()


func _check_ultimate_pursuit() -> void:
	var role = SwordsmanRole.new()
	var enemy := Node2D.new()
	root.add_child(enemy)
	role._update_pursuit_tracking(enemy)
	role._update_pursuit_tracking(enemy)
	role._update_pursuit_tracking(enemy)
	assert(role.ultimate_pursuit_armed)
	enemy.queue_free()

func _check_ultimate_talent_snapshot(owner: TalentOwner) -> void:
	var role = SwordsmanRole.new()
	owner.talents = {"swordsman_ultimate_triumph": true}
	var snapshot: Dictionary = role._snapshot_ultimate_talents(owner)
	owner.talents.clear()
	role._activate_ultimate_triumph(owner, bool(snapshot["swordsman_ultimate_triumph"]))
	assert(is_equal_approx(float(owner.role_special_states["swordsman"]["ultimate_triumph_remaining"]), 2.0))
	owner.role_special_states["swordsman"].erase("ultimate_triumph_remaining")
	owner.talents = {"swordsman_ultimate_triumph": true}
	role._activate_ultimate_triumph(owner, false)
	assert(not owner.role_special_states["swordsman"].has("ultimate_triumph_remaining"))


class TalentOwner:
	extends Node2D

	var talents: Dictionary = {}
	var role_special_states: Dictionary = {"swordsman": {}}
	var roles: Array = [{"id": "swordsman"}]
	var active_role_index := 0
	var role_health_values := {"swordsman": 100.0}
	var switch_power_remaining := 0.0
	var switch_power_role_id := ""
	var switch_power_label := ""
	var live_enemies: Array = []
	var facing_direction := Vector2.RIGHT

	func _has_skill_talent(talent_id: String) -> bool:
		return bool(talents.get(talent_id, false))

	func _get_active_role() -> Dictionary:
		return roles[active_role_index]

	func _get_role_current_health(role_id: String) -> float:
		return float(role_health_values.get(role_id, 0.0))

	func _get_role_max_health(_role_id: String) -> float:
		return 100.0

	func _get_live_enemies() -> Array:
		return live_enemies

	func _get_role_special_state(role_id: String) -> Dictionary:
		return role_special_states.get(role_id, {})

	func _get_downward_perpendicular(direction: Vector2) -> Vector2:
		return Vector2(-direction.y, direction.x)

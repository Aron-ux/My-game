extends SceneTree

const MAGE_META_FIELD_ABILITY := preload("res://scripts/abilities/mage_meta_field_ability.gd")
const MAGE_META_FIELD_TALENT_FLOW := preload("res://scripts/player/player_mage_meta_field_talent_flow.gd")
const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_level_talent_definitions()
	_check_radius_and_background_scaling()
	await _check_projectile_speed_aura()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("MAGE_META_FIELD_LEVEL_TALENTS_SMOKE_OK")
	quit(0)


func _check_level_talent_definitions() -> void:
	var definitions: Array = PLAYER_SKILL_TALENT_SYSTEM.LEVEL_TALENT_DEFINITIONS.get("mage", [])
	_expect(_has_candidate(definitions, MAGE_META_FIELD_TALENT_FLOW.TALENT_META_FIELD_1), "meta field I level talent should be registered")
	_expect(_has_candidate(definitions, MAGE_META_FIELD_TALENT_FLOW.TALENT_META_FIELD_2), "meta field II level talent should be registered")

	var locked_owner := MetaOwner.new()
	locked_owner.blessing_skill_state = {"unlocked": {}, "tiers": {}}
	var locked_candidates: Array = PLAYER_SKILL_TALENT_SYSTEM._collect_level_talent_candidates(locked_owner, definitions, {}, false)
	_expect(not _has_candidate(locked_candidates, MAGE_META_FIELD_TALENT_FLOW.TALENT_META_FIELD_1), "meta field level talents should require meta field unlock")

	var owner := MetaOwner.new()
	var candidates: Array = PLAYER_SKILL_TALENT_SYSTEM._collect_level_talent_candidates(owner, definitions, {}, false)
	_expect(_has_candidate(candidates, MAGE_META_FIELD_TALENT_FLOW.TALENT_META_FIELD_1), "meta field I should refresh after skill unlock")
	_expect(_has_candidate(candidates, MAGE_META_FIELD_TALENT_FLOW.TALENT_META_FIELD_2), "meta field II should refresh after skill unlock")

	owner.role_special_states["mage"] = {"level_talents": [MAGE_META_FIELD_TALENT_FLOW.TALENT_META_FIELD_1]}
	candidates = PLAYER_SKILL_TALENT_SYSTEM._collect_level_talent_candidates(owner, definitions, {}, false)
	_expect(not _has_candidate(candidates, MAGE_META_FIELD_TALENT_FLOW.TALENT_META_FIELD_2), "same-scope meta field II should be locked after picking I")


func _check_radius_and_background_scaling() -> void:
	var owner := MetaOwner.new()
	var ability := MAGE_META_FIELD_ABILITY.new()
	owner.set_level_talents([MAGE_META_FIELD_TALENT_FLOW.TALENT_META_FIELD_1])
	_expect(is_equal_approx(ability._get_radius(owner), 100.0 * sqrt(1.25)), "meta field I should increase area by 25 percent through sqrt radius multiplier")

	owner.active_role_id = "gunner"
	owner.set_level_talents([MAGE_META_FIELD_TALENT_FLOW.TALENT_META_FIELD_2])
	ability.active_remaining = 1.0
	_expect(is_equal_approx(ability.get_damage_taken_multiplier(owner), 0.80), "meta field II background damage reduction should keep 40 percent effect")
	_expect(is_equal_approx(ability.get_damage_reduction_value(owner), 128.0), "meta field II background fixed reduction should keep 40 percent effect")
	_expect(is_equal_approx(ability._get_slow_multiplier(owner), 0.80), "meta field II background enemy slow should keep 40 percent effect")
	_expect(is_equal_approx(ability._get_damage(owner), 4.0), "meta field II background damage should keep 40 percent effect")


func _check_projectile_speed_aura() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var owner := MetaOwner.new()
	owner.set_level_talents([MAGE_META_FIELD_TALENT_FLOW.TALENT_META_FIELD_1])
	scene.add_child(owner)
	var projectile := ProjectileStub.new()
	projectile.global_position = Vector2(40.0, 0.0)
	projectile.speed = 100.0
	scene.add_child(projectile)
	projectile.add_to_group("enemy_projectiles")
	await process_frame

	var ability := MAGE_META_FIELD_ABILITY.new()
	ability._update_enemy_projectile_speed_aura(owner)
	_expect(is_equal_approx(projectile.speed, 70.0), "meta field I should slow enemy projectiles inside field by 30 percent")
	ability.stop(owner)
	_expect(is_equal_approx(projectile.speed, 100.0), "meta field projectile slow should restore speed on stop")

	owner.active_role_id = "gunner"
	owner.set_level_talents([MAGE_META_FIELD_TALENT_FLOW.TALENT_META_FIELD_1, MAGE_META_FIELD_TALENT_FLOW.TALENT_META_FIELD_2])
	ability._update_enemy_projectile_speed_aura(owner)
	_expect(is_equal_approx(projectile.speed, 88.0), "meta field projectile slow should scale to 40 percent while mage is background if both talents are available later")
	ability.stop(owner)
	_expect(is_equal_approx(projectile.speed, 100.0), "background projectile slow should also restore speed on stop")

	projectile.queue_free()
	scene.queue_free()
	await process_frame
	current_scene = null


func _has_candidate(candidates: Array, talent_id: String) -> bool:
	for candidate_value in candidates:
		if candidate_value is Dictionary and str((candidate_value as Dictionary).get("id", "")) == talent_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


class MetaOwner:
	extends Node2D

	var active_role_id := "mage"
	var blessing_skill_state: Dictionary = {"unlocked": {"meta_field": true}, "tiers": {"meta_field": 1}}
	var role_special_states: Dictionary = {"mage": {"level_talents": []}}

	func set_level_talents(talent_ids: Array) -> void:
		role_special_states["mage"] = {"level_talents": talent_ids.duplicate()}

	func _has_level_talent(talent_id: String) -> bool:
		return (role_special_states["mage"].get("level_talents", []) as Array).has(talent_id)

	func _has_skill_talent(_talent_id: String) -> bool:
		return false

	func _get_active_role() -> Dictionary:
		return {"id": active_role_id}

	func _get_blessing_skill_tier(_skill_id: String) -> int:
		return 1

	func _get_equipment_skill_range_multiplier() -> float:
		return 1.0

	func _get_invoker_magic_range_multiplier(_skill_id: String) -> float:
		return 1.0

	func _get_role_damage(_role_id: String) -> float:
		return 100.0

	func _get_role_special_state(role_id: String) -> Dictionary:
		return role_special_states.get(role_id, {})


class ProjectileStub:
	extends Node2D

	var speed := 100.0

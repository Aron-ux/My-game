extends SceneTree

const MAGE_ROLE := preload("res://scripts/player/roles/mage_role.gd")
const MAGE_ENTRY_TALENT_FLOW := preload("res://scripts/player/player_mage_entry_talent_flow.gd")
const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_level_talent_definitions()
	_check_extra_ring_centers()
	await _check_kill_hooks_through_resolver()
	_check_pending_surplus_bonus()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("MAGE_ENTRY_LEVEL_TALENTS_SMOKE_OK")
	quit(0)


func _check_level_talent_definitions() -> void:
	var definitions: Array = PLAYER_SKILL_TALENT_SYSTEM.LEVEL_TALENT_DEFINITIONS.get("mage", [])
	_expect(_has_candidate(definitions, MAGE_ENTRY_TALENT_FLOW.TALENT_DENSE_LIGHTNING_1), "dense lightning I level talent should be registered")
	_expect(_has_candidate(definitions, MAGE_ENTRY_TALENT_FLOW.TALENT_DENSE_LIGHTNING_2), "dense lightning II level talent should be registered")

	var owner := TalentOwner.new()
	var candidates: Array = PLAYER_SKILL_TALENT_SYSTEM._collect_level_talent_candidates(owner, definitions, {}, false)
	_expect(_has_candidate(candidates, MAGE_ENTRY_TALENT_FLOW.TALENT_DENSE_LIGHTNING_1), "dense lightning I should refresh because hero_entry is a shared entry skill")
	_expect(_has_candidate(candidates, MAGE_ENTRY_TALENT_FLOW.TALENT_DENSE_LIGHTNING_2), "dense lightning II should refresh because hero_entry is a shared entry skill")


func _check_extra_ring_centers() -> void:
	var owner := TalentOwner.new()
	owner.set_level_talents([MAGE_ENTRY_TALENT_FLOW.TALENT_DENSE_LIGHTNING_1])
	var centers: Array[Vector2] = []
	for index in range(MAGE_ROLE.ENTRY_LIGHTNING_COUNT):
		centers.append(owner.global_position + Vector2.RIGHT.rotated(TAU * float(index) / float(MAGE_ROLE.ENTRY_LIGHTNING_COUNT)) * MAGE_ROLE.ENTRY_LIGHTNING_DISTANCE)
	MAGE_ENTRY_TALENT_FLOW.append_extra_ring_centers(owner, centers, Vector2.RIGHT, MAGE_ROLE.ENTRY_LIGHTNING_COUNT, MAGE_ROLE.ENTRY_LIGHTNING_DISTANCE)
	_expect(centers.size() == MAGE_ROLE.ENTRY_LIGHTNING_COUNT * 2, "dense lightning should add one extra outer ring in the same 5 directions")
	if centers.size() == MAGE_ROLE.ENTRY_LIGHTNING_COUNT * 2:
		_expect(is_equal_approx(centers[5].length(), MAGE_ROLE.ENTRY_LIGHTNING_DISTANCE * MAGE_ENTRY_TALENT_FLOW.EXTRA_RING_DISTANCE_MULTIPLIER), "dense lightning outer ring should use the configured outer distance")


func _check_kill_hooks_through_resolver() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var owner := TalentOwner.new()
	owner.set_level_talents([MAGE_ENTRY_TALENT_FLOW.TALENT_DENSE_LIGHTNING_1, MAGE_ENTRY_TALENT_FLOW.TALENT_DENSE_LIGHTNING_2])
	scene.add_child(owner)
	owner.fire_timer = Timer.new()
	owner.fire_timer.one_shot = true
	owner.add_child(owner.fire_timer)
	await process_frame
	owner.fire_timer.start(1.0)
	owner.mage_tidal_surge_ability.cooldown_remaining = 1.0
	owner.mage_meta_field_ability.cooldown_remaining = 0.1
	owner.mage_arcane_surplus_remaining = 3.0

	var enemy := KillEnemy.new()
	scene.add_child(enemy)
	PLAYER_DAMAGE_RESOLVER.deal_damage_to_enemy(owner, enemy, 2.0, MAGE_ENTRY_TALENT_FLOW.make_damage_source_id())
	_expect(is_equal_approx(owner.mage_tidal_surge_ability.cooldown_remaining, 0.8), "dense lightning I kill should cut mage tidal surge cooldown by 0.2s")
	_expect(is_equal_approx(owner.mage_meta_field_ability.cooldown_remaining, 0.0), "dense lightning I kill should clamp cooldown reduction at zero")
	_expect(owner.fire_timer.time_left <= 0.86 and owner.fire_timer.time_left >= 0.70, "dense lightning I kill should cut current basic attack cooldown by about 0.2s")
	_expect(is_equal_approx(owner.mage_arcane_surplus_remaining, 3.2), "dense lightning II kill should extend active arcane surplus by 0.2s")

	scene.queue_free()
	await process_frame
	current_scene = null


func _check_pending_surplus_bonus() -> void:
	var owner := TalentOwner.new()
	owner.set_level_talents([MAGE_ENTRY_TALENT_FLOW.TALENT_DENSE_LIGHTNING_2])
	owner.mage_arcane_surplus_remaining = 0.0
	MAGE_ENTRY_TALENT_FLOW.on_entry_lightning_killed(owner, MAGE_ENTRY_TALENT_FLOW.make_damage_source_id(), "mage")
	_expect(is_equal_approx(MAGE_ENTRY_TALENT_FLOW.consume_pending_arcane_surplus_bonus(owner), 0.2), "dense lightning II should store pending surplus duration when surplus is not active yet")
	_expect(is_equal_approx(MAGE_ENTRY_TALENT_FLOW.consume_pending_arcane_surplus_bonus(owner), 0.0), "pending surplus duration should be consumed only once")


func _has_candidate(candidates: Array, talent_id: String) -> bool:
	for candidate_value in candidates:
		if candidate_value is Dictionary and str((candidate_value as Dictionary).get("id", "")) == talent_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


class TalentOwner:
	extends Node2D

	var role_special_states: Dictionary = {"mage": {"level_talents": []}}
	var blessing_skill_state: Dictionary = {"unlocked": {"meta_field": true, "surging_wave": true}, "tiers": {"meta_field": 1, "surging_wave": 1}}
	var mage_tidal_surge_ability := CooldownStub.new()
	var mage_meta_field_ability := CooldownStub.new()
	var fire_timer: Timer
	var mage_arcane_surplus_remaining := 0.0

	func set_level_talents(talent_ids: Array) -> void:
		role_special_states["mage"] = {"level_talents": talent_ids.duplicate()}

	func _has_level_talent(talent_id: String) -> bool:
		return (role_special_states["mage"].get("level_talents", []) as Array).has(talent_id)

	func _get_role_special_state(role_id: String) -> Dictionary:
		return role_special_states.get(role_id, {})

	func _record_attack_result_instance(_role_id: String, _was_critical: bool, _killed: bool, _target_position: Variant = null, _raw_source_role_id: String = "") -> void:
		pass


class CooldownStub:
	extends RefCounted

	var cooldown_remaining := 0.0


class KillEnemy:
	extends Node2D

	var current_health := 1.0
	var max_health := 1.0
	var enemy_kind := "normal"
	var reward_tier := 1

	func take_damage(amount: float, _is_critical: bool = false) -> bool:
		current_health = max(0.0, current_health - amount)
		return current_health <= 0.0

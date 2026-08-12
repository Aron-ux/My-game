extends SceneTree

const MAGE_ULTIMATE_TALENT_FLOW := preload("res://scripts/player/player_mage_ultimate_talent_flow.gd")
const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_DAMAGE_JOB_QUEUE := preload("res://scripts/player/player_damage_job_queue.gd")
const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_level_talent_definitions()
	_check_flow_values()
	_check_job_queue_energy_bonus()
	await _check_resolver_energy_bonus()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("MAGE_ULTIMATE_LEVEL_TALENTS_SMOKE_OK")
	quit(0)


func _check_level_talent_definitions() -> void:
	var definitions: Array = PLAYER_SKILL_TALENT_SYSTEM.LEVEL_TALENT_DEFINITIONS.get("mage", [])
	_expect(_has_candidate(definitions, MAGE_ULTIMATE_TALENT_FLOW.TALENT_ARCANE_BOMBARDMENT_1), "arcane bombardment I level talent should be registered")
	_expect(_has_candidate(definitions, MAGE_ULTIMATE_TALENT_FLOW.TALENT_ARCANE_BOMBARDMENT_2), "arcane bombardment II level talent should be registered")

	var owner := TalentOwner.new()
	var candidates: Array = PLAYER_SKILL_TALENT_SYSTEM._collect_level_talent_candidates(owner, definitions, {}, false)
	_expect(_has_candidate(candidates, MAGE_ULTIMATE_TALENT_FLOW.TALENT_ARCANE_BOMBARDMENT_1), "arcane bombardment I should refresh because mage ultimate is inherent")
	_expect(_has_candidate(candidates, MAGE_ULTIMATE_TALENT_FLOW.TALENT_ARCANE_BOMBARDMENT_2), "arcane bombardment II should refresh because mage ultimate is inherent")


func _check_flow_values() -> void:
	var owner := TalentOwner.new()
	owner.set_level_talents([MAGE_ULTIMATE_TALENT_FLOW.TALENT_ARCANE_BOMBARDMENT_1])
	_expect(MAGE_ULTIMATE_TALENT_FLOW.get_extra_bombard_count(owner) == 3, "arcane bombardment I should add 3 bombardment rounds")
	_expect(is_equal_approx(MAGE_ULTIMATE_TALENT_FLOW.get_ultimate_energy_bonus_multiplier(owner, "mage_ultimate:0", "mage"), 1.0), "arcane bombardment I should add one extra copy of ultimate energy")

	owner.set_level_talents([MAGE_ULTIMATE_TALENT_FLOW.TALENT_ARCANE_BOMBARDMENT_2])
	_expect(is_equal_approx(MAGE_ULTIMATE_TALENT_FLOW.get_pulse_damage_multiplier(owner), 1.05), "arcane bombardment II should add 5 percent pulse damage")
	MAGE_ULTIMATE_TALENT_FLOW.on_ultimate_bombardment_killed(owner, "mage_ultimate:1", "mage")
	MAGE_ULTIMATE_TALENT_FLOW.on_ultimate_bombardment_killed(owner, "mage_ultimate:2", "mage")
	_expect(is_equal_approx(MAGE_ULTIMATE_TALENT_FLOW.get_pulse_damage_multiplier(owner), 1.051), "arcane bombardment II should add 0.05 percent permanent pulse damage per kill")


func _check_job_queue_energy_bonus() -> void:
	var owner := TalentOwner.new()
	owner.set_level_talents([MAGE_ULTIMATE_TALENT_FLOW.TALENT_ARCANE_BOMBARDMENT_1])
	var queue := PLAYER_DAMAGE_JOB_QUEUE.new()
	queue.configure(owner)
	var boss := BossEnemy.new()
	queue._deal_batched_damage_to_enemy(boss, 100.0, "mage_ultimate:queued", 0.0, 2.0, 1.0, 0.0, Vector2.ZERO, 0.0, false)
	_expect(owner.boss_energy_events.size() == 2, "queued arcane bombardment boss damage should add base and bonus ultimate energy")
	if owner.boss_energy_events.size() == 2:
		_expect(is_equal_approx(float(owner.boss_energy_events[0]), 7.0), "queued base boss energy should be recorded")
		_expect(is_equal_approx(float(owner.boss_energy_events[1]), 7.0), "queued bonus boss energy should be one extra copy")
	queue.free()
	boss.free()
	owner.free()


func _check_resolver_energy_bonus() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var owner := TalentOwner.new()
	owner.set_level_talents([MAGE_ULTIMATE_TALENT_FLOW.TALENT_ARCANE_BOMBARDMENT_1])
	scene.add_child(owner)

	var boss := BossEnemy.new()
	scene.add_child(boss)
	PLAYER_DAMAGE_RESOLVER.deal_damage_to_enemy(owner, boss, 100.0, "mage_ultimate:0")
	_expect(owner.boss_energy_events.size() == 2, "arcane bombardment I boss damage should add base and bonus ultimate energy")
	if owner.boss_energy_events.size() == 2:
		_expect(is_equal_approx(float(owner.boss_energy_events[0]), 7.0), "base boss energy should be recorded")
		_expect(is_equal_approx(float(owner.boss_energy_events[1]), 7.0), "bonus boss energy should be one extra copy")

	var enemy := KillEnemy.new()
	scene.add_child(enemy)
	PLAYER_DAMAGE_RESOLVER.deal_damage_to_enemy(owner, enemy, 2.0, "mage_ultimate:1")
	_expect(owner.kill_energy_events.size() == 2, "arcane bombardment I kill should add base and bonus ultimate energy")
	if owner.kill_energy_events.size() == 2:
		_expect(is_equal_approx(float(owner.kill_energy_events[0].get("amount", 0.0)), 10.0), "base kill energy should be recorded")
		_expect(is_equal_approx(float(owner.kill_energy_events[1].get("amount", 0.0)), 10.0), "bonus kill energy should be one extra copy")
		_expect(str(owner.kill_energy_events[1].get("bypass", "")) == "", "arcane bombardment bonus energy should keep normal ultimate lock behavior")
	_expect(owner.mage_proc_events.size() == 1, "arcane bombardment bonus energy should not trigger mage kill proc a second time")

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


class TalentOwner:
	extends Node2D

	var role_special_states: Dictionary = {"mage": {"level_talents": []}}
	var blessing_skill_state: Dictionary = {"unlocked": {"meta_field": true, "surging_wave": true}, "tiers": {"meta_field": 1, "surging_wave": 1}}
	var boss_energy_events: Array[float] = []
	var kill_energy_events: Array[Dictionary] = []
	var mage_proc_events: Array[Dictionary] = []

	func set_level_talents(talent_ids: Array) -> void:
		role_special_states["mage"] = {"level_talents": talent_ids.duplicate()}

	func _has_level_talent(talent_id: String) -> bool:
		return (role_special_states["mage"].get("level_talents", []) as Array).has(talent_id)

	func _get_role_special_state(role_id: String) -> Dictionary:
		return role_special_states.get(role_id, {})

	func _get_boss_damage_energy(_damage_amount: float) -> float:
		return 7.0

	func _add_boss_damage_energy(amount: float) -> void:
		boss_energy_events.append(amount)

	func _get_kill_energy_from_enemy(_enemy: Node) -> float:
		return 10.0

	func _add_kill_energy(amount: float, bypass_lock_role_id: String = "", source_role_id: String = "") -> void:
		kill_energy_events.append({"amount": amount, "bypass": bypass_lock_role_id, "source": source_role_id})

	func _try_apply_mage_kill_energy_proc(source_role_id: String, base_energy: float, bypass_lock_role_id: String = "") -> void:
		mage_proc_events.append({"source": source_role_id, "amount": base_energy, "bypass": bypass_lock_role_id})

	func _record_attack_result_instance(_role_id: String, _was_critical: bool, _killed: bool, _target_position: Variant = null, _raw_source_role_id: String = "") -> void:
		pass


class BossEnemy:
	extends Node2D

	var current_health := 999.0
	var max_health := 999.0
	var enemy_kind := "boss"

	func take_damage(amount: float, _is_critical: bool = false) -> bool:
		current_health = max(0.0, current_health - amount)
		return current_health <= 0.0


class KillEnemy:
	extends Node2D

	var current_health := 1.0
	var max_health := 1.0
	var enemy_kind := "normal"
	var reward_tier := 1

	func take_damage(amount: float, _is_critical: bool = false) -> bool:
		current_health = max(0.0, current_health - amount)
		return current_health <= 0.0

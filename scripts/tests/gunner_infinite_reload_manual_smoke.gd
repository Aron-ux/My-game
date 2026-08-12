extends SceneTree

const InfiniteReload := preload("res://scripts/abilities/gunner_infinite_reload_ability.gd")
const PlayerAbilityFlow := preload("res://scripts/player/player_ability_flow.gd")
const PlayerAttackLoopFlow := preload("res://scripts/player/player_attack_loop_flow.gd")
const PlayerCooldownFlow := preload("res://scripts/player/player_skill_cooldown_flow.gd")
const PlayerEquipmentFlow := preload("res://scripts/player/player_equipment_flow.gd")
const PlayerSurvivalFlow := preload("res://scripts/player/player_survival_flow.gd")
const PlayerUltimateFlow := preload("res://scripts/player/player_ultimate_flow.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := ManualOwner.new()
	root.add_child(owner)
	owner.blessing_skill_state = {
		"unlocked": {
			"shrapnel_field": true,
			"infinite_reload": true
		},
		"unlock_order": [
			"shrapnel_field",
			"infinite_reload"
		]
	}
	owner.level_talents = {
		"gunner_level_talent_infinite_reload_1": true,
		"gunner_level_talent_infinite_reload_2": true
	}

	var active_skill_ids := PlayerCooldownFlow.get_role_active_skill_ids(owner, "gunner")
	_expect(active_skill_ids == ["shrapnel_field", "infinite_reload"], "skill hotkey slots should follow active skill unlock order")
	_expect(not owner.gunner_infinite_reload_ability.try_trigger(owner), "manual infinite reload should not auto-cast")
	_expect(not PlayerAbilityFlow.try_handle_manual_skill_slot(owner, 1), "slot 1 should not toggle shrapnel")

	owner.mouse_aim_direction = Vector2.RIGHT
	_expect(PlayerAbilityFlow.try_handle_manual_skill_slot(owner, 2), "slot 2 should toggle infinite reload on")
	_expect(owner.gunner_infinite_reload_ability.is_active(), "manual infinite reload should become active")
	_expect(PlayerAbilityFlow.is_gunner_infinite_reload_blocking_actions(owner), "manual infinite reload should block other actions")
	_expect(is_equal_approx(PlayerEquipmentFlow.get_role_permanent_dodge_value(owner, "gunner"), 100.0), "manual infinite reload should add 100 dodge value for gunner")
	_expect(is_equal_approx(PlayerEquipmentFlow.get_role_permanent_dodge_value(owner, "swordsman"), 0.0), "manual infinite reload dodge value should not apply to other roles")
	_expect(PlayerSurvivalFlow.is_movement_locked(owner), "manual infinite reload should lock movement")
	_expect(not PlayerUltimateFlow.can_use_ultimate(owner), "manual infinite reload should block ultimate")

	owner.mouse_aim_direction = Vector2.UP
	owner.last_shapes.clear()
	owner.gunner_infinite_reload_ability._trigger_tick(owner)
	_expect(owner.last_shapes.size() == 2, "infinite reload II should fire dual parallel beams")
	_expect(owner.facing_direction.is_equal_approx(Vector2.RIGHT), "manual infinite reload should keep first aim direction")

	owner.attack_count = 0
	PlayerAttackLoopFlow.perform_active_attack(owner)
	_expect(owner.attack_count == 0, "manual infinite reload should block basic attack")

	_expect(PlayerAbilityFlow.try_handle_manual_skill_slot(owner, 2), "slot 2 should toggle infinite reload off")
	_expect(not owner.gunner_infinite_reload_ability.is_active(), "manual infinite reload should stop after closing")
	_expect(is_equal_approx(owner.gunner_infinite_reload_ability.cooldown_remaining, 0.5), "manual close should apply 0.5s cooldown")
	_expect(not PlayerAbilityFlow.is_gunner_infinite_reload_blocking_actions(owner), "manual infinite reload should stop blocking after closing")
	_expect(is_equal_approx(PlayerEquipmentFlow.get_role_permanent_dodge_value(owner, "gunner"), 0.0), "manual infinite reload dodge value should disappear after closing")
	_expect(not PlayerSurvivalFlow.is_movement_locked(owner), "manual infinite reload should release movement lock after closing")

	owner.queue_free()
	await process_frame
	if failures.is_empty():
		print("GUNNER_INFINITE_RELOAD_MANUAL_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


class ManualOwner:
	extends CharacterBody2D

	var level_talents: Dictionary = {}
	var talents: Dictionary = {}
	var blessing_skill_state: Dictionary = {}
	var roles: Array = [
		{"id": "swordsman"},
		{"id": "gunner"},
		{"id": "mage"}
	]
	var role_equipment_levels: Dictionary = {}
	var equipment_levels: Dictionary = {}
	var gunner_infinite_reload_ability = InfiniteReload.new()
	var is_dead := false
	var level_up_active := false
	var active_role_id := "gunner"
	var facing_direction := Vector2.RIGHT
	var mouse_aim_direction := Vector2.RIGHT
	var gunner_attack_chain := 0
	var last_shapes: Array[Dictionary] = []
	var attack_count := 0
	const GUNNER_INTERSECT_VISUAL_SCALE := 1.0

	func _get_active_role() -> Dictionary:
		return {"id": active_role_id}

	func _get_active_role_id() -> String:
		return active_role_id

	func _has_skill_talent(talent_id: String) -> bool:
		return bool(talents.get(talent_id, false))

	func _has_level_talent(talent_id: String) -> bool:
		return bool(level_talents.get(talent_id, false))

	func _is_blessing_skill_unlocked(skill_id: String) -> bool:
		return bool((blessing_skill_state.get("unlocked", {}) as Dictionary).get(skill_id, false))

	func _get_blessing_skill_tier(_skill_id: String) -> int:
		return 1

	func _get_blessing_skill_combo_scales(_skill_id: String) -> Array:
		return []

	func _get_blessing_skill_duration_multiplier(_skill_id: String) -> float:
		return 1.0

	func _get_blessing_skill_duration_flat_bonus(_skill_id: String) -> float:
		return 0.0

	func _get_role_damage(_role_id: String) -> float:
		return 10.0

	func _get_role_attribute_range_multiplier(_role_id: String) -> float:
		return 1.0

	func _get_equipment_skill_range_multiplier() -> float:
		return 1.0

	func _get_infinite_reload_range_multiplier() -> float:
		return 1.0

	func _get_equipment_cooldown_multiplier() -> float:
		return 1.0

	func _get_role_bonus_summary(_role_id: String) -> Dictionary:
		return {}

	func _get_role_blessing_stat_bonus(_role_id: String, _stat: String) -> float:
		return 0.0

	func _get_role_attribute_dodge_value(_role_id: String) -> float:
		return 0.0

	func _get_gunner_infinite_reload_dodge_value(role_id: String = "") -> float:
		return PlayerAbilityFlow.get_gunner_infinite_reload_dodge_value(self, role_id)

	func _get_live_mouse_aim_direction(fallback_direction: Vector2) -> Vector2:
		return mouse_aim_direction if mouse_aim_direction.length_squared() > 0.001 else fallback_direction

	func _get_downward_perpendicular(direction: Vector2) -> Vector2:
		return Vector2(-direction.y, direction.x)

	func _get_gunner_intersect_gather_duration() -> float:
		return 0.0

	func _damage_enemies_in_shapes_batched(shapes: Array[Dictionary]) -> int:
		last_shapes.clear()
		for shape in shapes:
			last_shapes.append(shape.duplicate(true))
		return shapes.size()

	func _perform_gunner_attack() -> void:
		attack_count += 1

	func is_gunner_infinite_reload_blocking_actions() -> bool:
		return PlayerAbilityFlow.is_gunner_infinite_reload_blocking_actions(self)

	func _has_elite_relic(_relic_id: String) -> bool:
		return false

	func _get_role_mana(_role_id: String) -> float:
		return 100.0

	func _spawn_combat_tag(_position: Vector2, _text: String, _color: Color) -> void:
		pass

	func _spawn_ring_effect(_position: Vector2, _radius: float, _color: Color, _segments: float, _duration: float) -> Node2D:
		var effect := Node2D.new()
		add_child(effect)
		return effect

	func _spawn_burst_effect(_position: Vector2, _radius: float, _color: Color, _duration: float) -> Node2D:
		var effect := Node2D.new()
		add_child(effect)
		return effect

	func _spawn_gunner_intersect_scene_effect(_center: Vector2, _direction: Vector2, _visual_length: float = 112.0, _visual_thickness: float = 18.0, _gather_visual_length: float = -1.0) -> Node2D:
		var effect := Node2D.new()
		add_child(effect)
		return effect

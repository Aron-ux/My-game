extends SceneTree

const GunnerFlashTalentFlow := preload("res://scripts/player/player_gunner_flash_talent_flow.gd")
const GunnerRole := preload("res://scripts/player/roles/gunner_role.gd")
const SurvivalFlow := preload("res://scripts/player/player_survival_flow.gd")


func _init() -> void:
	_check_dodge_adds_persistent_stacks()
	_check_damage_immunity_consumes_temporary_stacks()
	_check_damage_without_ten_stacks_keeps_persistent_stacks()
	_check_legacy_execution_uses_total_stacks_without_consuming_persistent()
	print("GUNNER_FLASH_LEVEL_TALENTS_SMOKE_OK")
	quit(0)


func _check_dodge_adds_persistent_stacks() -> void:
	var owner := FlashOwner.new()
	root.add_child(owner)
	owner.level_talents = {"gunner_level_talent_execution_2": true}
	owner.try_dodge_result = true
	for _index in range(7):
		SurvivalFlow.take_damage(owner, 10.0)
	assert(is_equal_approx(owner.current_health, 100.0))
	assert(int(owner._get_role_special_state("gunner").get("level_execution_dodge_persistent_stacks", 0)) == 5)
	assert(owner.last_tag == "闪避")
	owner.queue_free()


func _check_damage_immunity_consumes_temporary_stacks() -> void:
	var owner := FlashOwner.new()
	root.add_child(owner)
	owner.level_talents = {
		"gunner_level_talent_execution_1": true,
		"gunner_level_talent_execution_2": true
	}
	owner._get_role_special_state("gunner")["level_execution_dodge_persistent_stacks"] = 5
	owner.gunner_flash_stacks = 5
	owner.current_health = 42.0
	SurvivalFlow.take_damage(owner, 20.0)
	assert(is_equal_approx(owner.current_health, 42.0))
	assert(owner.gunner_flash_stacks == 0)
	assert(int(owner._get_role_special_state("gunner").get("level_execution_dodge_persistent_stacks", 0)) == 5)
	assert(is_equal_approx(owner.gunner_flash_cooldown_remaining, 15.0))
	assert(is_equal_approx(GunnerFlashTalentFlow.get_flat_dodge_chance_bonus(owner, "gunner"), 0.20))
	owner.active_role_id = "swordsman"
	assert(GunnerFlashTalentFlow.get_active_flash_stacks(owner) == 0)
	owner.active_role_id = "gunner"
	assert(GunnerFlashTalentFlow.get_active_flash_stacks(owner) == 5)
	assert(is_equal_approx(GunnerFlashTalentFlow.get_move_speed_multiplier(owner, "gunner"), 1.20))
	assert(owner.last_tag == "瞬杀")
	GunnerFlashTalentFlow.tick(owner, 1.0)
	assert(is_equal_approx(float(owner._get_role_special_state("gunner").get("level_execution_immunity_buff_remaining", 0.0)), 2.0))
	owner.queue_free()


func _check_damage_without_ten_stacks_keeps_persistent_stacks() -> void:
	var owner := FlashOwner.new()
	root.add_child(owner)
	owner.level_talents = {
		"gunner_level_talent_execution_1": true,
		"gunner_level_talent_execution_2": true
	}
	owner._get_role_special_state("gunner")["level_execution_dodge_persistent_stacks"] = 5
	owner.gunner_flash_stacks = 4
	SurvivalFlow.take_damage(owner, 12.0)
	assert(is_equal_approx(owner.current_health, 88.0))
	assert(owner.gunner_flash_stacks == 0)
	assert(int(owner._get_role_special_state("gunner").get("level_execution_dodge_persistent_stacks", 0)) == 5)
	assert(is_equal_approx(owner.gunner_flash_cooldown_remaining, 15.0))
	owner.queue_free()


func _check_legacy_execution_uses_total_stacks_without_consuming_persistent() -> void:
	var owner := FlashOwner.new()
	root.add_child(owner)
	owner.talents = {"gunner_trait_execution": true}
	owner.level_talents = {"gunner_level_talent_execution_2": true}
	owner._get_role_special_state("gunner")["level_execution_dodge_persistent_stacks"] = 5
	owner.gunner_flash_stacks = 5
	var role := GunnerRole.new()
	assert(is_equal_approx(role.consume_damage_event_multiplier(owner, "gunner"), 1.6))
	assert(owner.gunner_flash_stacks == 0)
	assert(int(owner._get_role_special_state("gunner").get("level_execution_dodge_persistent_stacks", 0)) == 5)
	owner.queue_free()


class FlashOwner:
	extends CharacterBody2D

	signal health_changed(current_health: float, max_health: float)

	var talents: Dictionary = {}
	var level_talents: Dictionary = {}
	var role_special_states: Dictionary = {"gunner": {}}
	var current_health: float = 100.0
	var max_health: float = 100.0
	var current_temporary_health: float = 0.0
	var hurt_cooldown: float = 0.55
	var hurt_cooldown_remaining: float = 0.0
	var switch_invulnerability_remaining: float = 0.0
	var is_dead: bool = false
	var gunner_role = null
	var gunner_flash_stacks: int = 0
	var gunner_flash_stack_elapsed: float = 0.0
	var gunner_flash_cooldown_remaining: float = 0.0
	var try_dodge_result: bool = false
	var active_role_id: String = "gunner"
	var last_tag: String = ""

	func _has_skill_talent(talent_id: String) -> bool:
		return bool(talents.get(talent_id, false))

	func _has_level_talent(talent_id: String) -> bool:
		return bool(level_talents.get(talent_id, false))

	func _get_active_role() -> Dictionary:
		return {"id": active_role_id}

	func _get_active_role_id() -> String:
		return active_role_id

	func _try_equipment_dodge() -> bool:
		return try_dodge_result

	func _get_effective_damage_taken_multiplier() -> float:
		return 1.0

	func _get_role_special_state(role_id: String) -> Dictionary:
		if not role_special_states.has(role_id) or role_special_states[role_id] is not Dictionary:
			role_special_states[role_id] = {}
		return role_special_states[role_id]

	func _break_gunner_flash_trait() -> void:
		gunner_flash_stacks = 0
		gunner_flash_stack_elapsed = 0.0
		gunner_flash_cooldown_remaining = 15.0

	func _save_active_role_health() -> void:
		pass

	func _play_player_hurt_feedback() -> void:
		pass

	func _spawn_forced_combat_tag(_position: Vector2, text: String, _color: Color) -> void:
		last_tag = text

	func _spawn_combat_tag(_position: Vector2, text: String, _color: Color) -> void:
		last_tag = text

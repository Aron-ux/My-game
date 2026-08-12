extends SceneTree

const GunnerHuntTalentFlow := preload("res://scripts/player/player_gunner_hunt_talent_flow.gd")
const PlayerEquipmentFlow := preload("res://scripts/player/player_equipment_flow.gd")
const PlayerRoleStatFlow := preload("res://scripts/player/player_role_stat_flow.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_outside_kill_stacks_only_for_hunt_sources()
	_check_caps_and_stat_integration()
	_check_switch_clear_keeps_execution_persistent_stacks()
	if failures.is_empty():
		print("GUNNER_HUNT_LEVEL_TALENTS_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_outside_kill_stacks_only_for_hunt_sources() -> void:
	var owner := HuntOwner.new()
	root.add_child(owner)
	owner.level_talents = {"gunner_level_talent_hunt_1": true}
	GunnerHuntTalentFlow.on_enemy_killed(owner, "gunner", Vector2(80.0, 0.0), "gunner")
	_expect_equal(GunnerHuntTalentFlow.get_hunt_1_stacks(owner), 0, "inside kill should not add hunt I stacks")
	GunnerHuntTalentFlow.on_enemy_killed(owner, "gunner", Vector2(140.0, 0.0), "gunner_no_hunt")
	_expect_equal(GunnerHuntTalentFlow.get_hunt_1_stacks(owner), 0, "gunner_no_hunt source should not add hunt I stacks")
	GunnerHuntTalentFlow.on_enemy_killed(owner, "swordsman", Vector2(140.0, 0.0), "swordsman")
	_expect_equal(GunnerHuntTalentFlow.get_hunt_1_stacks(owner), 0, "non-gunner kill should not add hunt I stacks")
	GunnerHuntTalentFlow.on_enemy_killed(owner, "gunner", Vector2(140.0, 0.0), "gunner")
	_expect_equal(GunnerHuntTalentFlow.get_hunt_1_stacks(owner), 1, "outside gunner kill should add hunt I stacks")
	owner.active_role_id = "mage"
	GunnerHuntTalentFlow.on_enemy_killed(owner, "gunner", Vector2(140.0, 0.0), "gunner")
	_expect_equal(GunnerHuntTalentFlow.get_hunt_1_stacks(owner), 1, "inactive gunner should not add hunt I stacks")
	owner.queue_free()


func _check_caps_and_stat_integration() -> void:
	var owner := HuntOwner.new()
	root.add_child(owner)
	owner.level_talents = {
		"gunner_level_talent_hunt_1": true,
		"gunner_level_talent_hunt_2": true
	}
	for _index in range(120):
		GunnerHuntTalentFlow.on_enemy_killed(owner, "gunner", Vector2(140.0, 0.0), "gunner")
	_expect_equal(GunnerHuntTalentFlow.get_hunt_1_stacks(owner), 50, "hunt I stacks should cap at 50 kills")
	_expect_equal(GunnerHuntTalentFlow.get_hunt_2_stacks(owner), 100, "hunt II stacks should cap at 100 kills")
	_expect_float(GunnerHuntTalentFlow.get_dodge_value(owner, "gunner"), 100.0, "hunt I should provide up to 100 dodge value")
	_expect_float(GunnerHuntTalentFlow.get_move_speed_bonus(owner, "gunner"), 50.0, "hunt I should provide up to 50 move speed")
	_expect_float(GunnerHuntTalentFlow.get_damage_multiplier(owner, "gunner"), 1.5, "hunt II should provide up to 50 percent damage")
	_expect_float(PlayerEquipmentFlow.get_role_permanent_dodge_value(owner, "gunner"), 100.0, "hunt I dodge value should enter permanent dodge value calculation")
	_expect_float(PlayerRoleStatFlow.get_role_move_speed(owner, "gunner"), 150.0, "hunt I move speed should enter role move speed")
	_expect_float(PlayerRoleStatFlow.get_role_damage(owner, "gunner"), 15.0, "hunt II damage should enter role damage")
	owner.queue_free()


func _check_switch_clear_keeps_execution_persistent_stacks() -> void:
	var owner := HuntOwner.new()
	root.add_child(owner)
	owner.level_talents = {
		"gunner_level_talent_hunt_1": true,
		"gunner_level_talent_hunt_2": true
	}
	owner._get_role_special_state("gunner")["level_execution_dodge_persistent_stacks"] = 5
	for _index in range(4):
		GunnerHuntTalentFlow.on_enemy_killed(owner, "gunner", Vector2(140.0, 0.0), "gunner")
	GunnerHuntTalentFlow.clear_switch_limited_state(owner)
	_expect_equal(GunnerHuntTalentFlow.get_hunt_1_stacks(owner), 0, "hunt I stacks should clear on switch")
	_expect_equal(GunnerHuntTalentFlow.get_hunt_2_stacks(owner), 0, "hunt II stacks should clear on switch")
	_expect_equal(int(owner._get_role_special_state("gunner").get("level_execution_dodge_persistent_stacks", 0)), 5, "switch clear should not remove execution II persistent stacks")
	owner.queue_free()


func _expect_equal(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: %s != %s" % [message, str(actual), str(expected)])


func _expect_float(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s: %.4f != %.4f" % [message, actual, expected])


class HuntOwner:
	extends CharacterBody2D

	var level_talents: Dictionary = {}
	var role_special_states: Dictionary = {"gunner": {}}
	var role_equipment_levels: Dictionary = {"gunner": {}}
	var equipment_levels: Dictionary = {}
	var active_role_id: String = "gunner"
	var roles: Array = [{"id": "gunner", "move_speed": 100.0, "damage": 10.0, "base_dodge": 0.0}]
	var base_speed: float = 100.0
	var speed: float = 100.0
	var equipment_speed_bonus: float = 0.0
	var global_damage_multiplier: float = 1.0
	var equipment_damage_multiplier_bonus: float = 0.0
	var entry_blessing_remaining: float = 0.0
	var entry_blessing_role_id: String = ""
	var entry_haste_move_speed_multiplier: float = 1.0
	var switch_power_remaining: float = 0.0
	var switch_power_role_id: String = ""
	var switch_power_damage_multiplier: float = 1.0
	var standby_entry_remaining: float = 0.0
	var standby_entry_role_id: String = ""
	var standby_entry_damage_multiplier: float = 1.0
	var borrow_fire_remaining: float = 0.0
	var borrow_fire_role_id: String = ""
	var borrow_fire_damage_multiplier: float = 1.0
	var frenzy_remaining: float = 0.0
	var frenzy_stacks: int = 0
	var ultimate_haste_remaining: float = 0.0
	var ultimate_haste_move_speed_multiplier: float = 1.0
	var enemy_move_slow_multiplier: float = 1.0
	var gunner_role = null

	func _has_level_talent(talent_id: String) -> bool:
		return bool(level_talents.get(talent_id, false))

	func _get_active_role() -> Dictionary:
		return {"id": active_role_id}

	func _get_active_role_id() -> String:
		return active_role_id

	func _get_gunner_safe_zone_radius() -> float:
		return 100.0

	func _get_role_special_state(role_id: String) -> Dictionary:
		if not role_special_states.has(role_id) or role_special_states[role_id] is not Dictionary:
			role_special_states[role_id] = {}
		return role_special_states[role_id]

	func _get_role_blessing_stat_bonus(_role_id: String, _stat: String) -> float:
		return 0.0

	func _get_role_attribute_move_speed_multiplier(_role_id: String) -> float:
		return 1.0

	func _get_role_attribute_dodge_value(_role_id: String) -> float:
		return 0.0

	func _get_role_equipment_bonus_summary(_role_id: String) -> Dictionary:
		return {}

	func _get_role_equipment_damage_multiplier_bonus(_role_id: String) -> float:
		return 0.0

	func _get_blazing_sun_flat_base_damage(_role_id: String) -> float:
		return 0.0

	func _get_gunner_infinite_reload_move_speed_multiplier() -> float:
		return 1.0

	func _get_gunner_flash_move_speed_multiplier() -> float:
		return 1.0

	func _get_gunner_flash_damage_multiplier() -> float:
		return 1.0

	func _get_gunner_flash_dodge_value(_role_id: String) -> float:
		return 0.0

	func _get_gunner_hunt_dodge_value(role_id: String = "") -> float:
		var resolved_role_id: String = role_id if role_id != "" else active_role_id
		return GunnerHuntTalentFlow.get_dodge_value(self, resolved_role_id)

	func _get_gunner_hunt_move_speed_bonus(role_id: String = "") -> float:
		var resolved_role_id: String = role_id if role_id != "" else active_role_id
		return GunnerHuntTalentFlow.get_move_speed_bonus(self, resolved_role_id)

	func _get_gunner_hunt_damage_multiplier(role_id: String = "") -> float:
		var resolved_role_id: String = role_id if role_id != "" else active_role_id
		return GunnerHuntTalentFlow.get_damage_multiplier(self, resolved_role_id)

	func _is_last_stand_active() -> bool:
		return false

	func _has_elite_relic(_relic_id: String) -> bool:
		return false

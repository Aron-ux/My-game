extends SceneTree

const PLAYER_SKILL_LEVEL_SYSTEM := preload("res://scripts/player/player_skill_level_system.gd")
const PLAYER_SKILL_LEVEL_EFFECT_FLOW := preload("res://scripts/player/player_skill_level_effect_flow.gd")
const PLAYER_GUNNER_FLASH_TALENT_FLOW := preload("res://scripts/player/player_gunner_flash_talent_flow.gd")
const PLAYER_GUNNER_MAGIC_GRENADE_FLOW := preload("res://scripts/player/player_gunner_magic_grenade_flow.gd")
const GUNNER_MAGIC_GRENADE_ABILITY := preload("res://scripts/abilities/gunner_magic_grenade_ability.gd")
const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_DAMAGE_JOB_QUEUE := preload("res://scripts/player/player_damage_job_queue.gd")
const ENEMY_SPATIAL_GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_progress_lines()
	_check_flat_bonuses()
	_check_magic_eye_armor()
	_check_magic_grenade_charge()
	_check_magic_grenade_level_nine()
	_check_magic_grenade_skill_talents()
	_check_magic_grenade_launch_count()
	_check_magic_grenade_target_spread()
	_check_magic_assistant_trigger()
	_check_magic_grenade_runtime_description()
	_check_milestone_counts()
	_check_preview_text()
	_check_upgrade_card_text()
	if failures.is_empty():
		print("GUNNER_SKILL_LEVEL_EFFECT_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_magic_eye_armor() -> void:
	var owner := _make_owner()
	var ability = preload("res://scripts/abilities/gunner_magic_eye_ability.gd").new()
	var flow = preload("res://scripts/player/player_gunner_magic_eye_flow.gd")
	var enemy := MagicEyeEnemyStub.new()
	_set_level(owner, "gunner_magic_eye", 1)
	_expect_approx(ability.get_armor_shred(owner), 5.0, "level 1 eye shreds 5 armor")
	flow._shred_enemy_armor(enemy, ability.get_armor_shred(owner))
	flow._shred_enemy_armor(enemy, ability.get_armor_shred(owner))
	_expect_approx(enemy.armor, -7.0, "eye stacks armor shred below zero")
	_expect_approx(enemy.damage_reduction_value, 17.0, "base eye must not change legacy reduction")
	_set_level(owner, "gunner_magic_eye", 10)
	_expect_approx(ability.get_armor_shred(owner), 11.75, "level 10 eye shreds 11.75 armor")
	enemy.free()
	owner.free()


class MagicEyeEnemyStub:
	extends Node
	var armor: float = 3.0
	var damage_reduction_value: float = 17.0


func _check_progress_lines() -> void:
	var gunner_lines: Array = PLAYER_SKILL_LEVEL_SYSTEM.ROLE_PROGRESS_ORDER.get("gunner", [])
	_expect(gunner_lines.has("gunner_trait"), "gunner should keep the gunner_trait line")
	_expect(gunner_lines.has("gunner_hunt"), "gunner should gain the separate gunner_hunt line")
	_expect_equal(str(PLAYER_SKILL_LEVEL_SYSTEM.PROGRESS_TITLES.get("gunner_trait", "")), "瞬杀", "gunner_trait should be titled 瞬杀")
	_expect_equal(str(PLAYER_SKILL_LEVEL_SYSTEM.PROGRESS_TITLES.get("gunner_hunt", "")), "猎杀", "gunner_hunt should be titled 猎杀")


func _check_flat_bonuses() -> void:
	var owner := _make_owner()
	_set_level(owner, "gunner_trait", 6)
	_set_level(owner, "gunner_hunt", 4)
	_set_level(owner, "gunner_entry", 3)
	_set_level(owner, "gunner_basic", 5)
	_set_level(owner, "gunner_shrapnel", 4)
	_set_level(owner, "gunner_infinite_reload", 3)
	_set_level(owner, "gunner_explosive_round", 2)
	_set_level(owner, "gunner_magic_grenade", 5)
	_set_level(owner, "gunner_magic_eye", 4)
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_flash_damage_bonus_per_stack(owner), 0.025, "瞬杀 level 6 should add 2.5% damage per stack")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_flash_speed_bonus_per_stack(owner), 0.025, "瞬杀 level 6 should add 2.5% move speed per stack")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_flash_dodge_chance_bonus_per_stack(owner), 0.0175, "level 6 adds 1.75 percent dodge chance per stack after five upgrades")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_hunt_radius_bonus(owner), -15.0, "猎杀 level 4 should shrink the circle by 15")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_hunt_outside_damage_bonus(owner), 0.03, "猎杀 level 4 should add 3% outside damage")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_entry_damage_ratio_bonus(owner), 0.20, "枪火典礼 level 3 should add 20% bullet damage")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_entry_bullet_speed_bonus(owner), 20.0, "枪火典礼 level 3 should add 20 bullet speed")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_basic_range_bonus(owner), 60.0, "枪手普攻 level 5 should add 60 range")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_basic_bullet_speed_bonus(owner), 40.0, "枪手普攻 level 5 should add 40 bullet speed")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_shrapnel_damage_ratio_bonus(owner), 0.06, "散弹 level 4 should add 6% damage")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_infinite_reload_range_bonus(owner), 40.0, "无限装填 level 3 should add 40 range")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_infinite_reload_damage_ratio_bonus(owner), 0.02, "无限装填 level 3 should add 2% tick ratio")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_infinite_reload_move_speed_bonus(owner), 0.01, "无限装填 level 3 should add 1% move speed")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_explosive_round_damage_ratio_bonus(owner), 0.10, "爆破弹 level 2 should add 10% damage")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_explosive_round_cone_radius_bonus(owner), 7.5, "爆破弹 level 2 should add 7.5 cone radius")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_magic_grenade_damage_ratio_bonus(owner), 1.25, "魔法榴弹 level 5 should add 125% damage")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_magic_grenade_crit_bonus(owner), 0.0, "魔法榴弹 level 5 should not add crit chance")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_magic_eye_damage_ratio_bonus(owner), 0.06, "魔眼 level 4 should add 6% damage")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_magic_eye_armor_shred_bonus(owner), 2.25, "魔眼 level 4 should add 2.25 armor shred")
	owner.free()


func _check_magic_grenade_charge() -> void:
	var owner := _make_owner()
	owner.level_talents["gunner_level_talent_magic_grenade_charge"] = true
	PLAYER_GUNNER_MAGIC_GRENADE_FLOW.add_charge_energy(owner, 1.0)
	_expect_approx(PLAYER_GUNNER_MAGIC_GRENADE_FLOW.get_charge_critical_bonus(owner), 0.0025, "one energy adds 0.25% magic grenade crit chance")
	_expect_approx(PLAYER_GUNNER_MAGIC_GRENADE_FLOW.get_charge_critical_damage_bonus(owner, "gunner_magic_grenade:1"), 0.007, "one energy adds 0.7% magic grenade critical damage")
	_expect_approx(PLAYER_GUNNER_MAGIC_GRENADE_FLOW.get_charge_critical_damage_bonus(owner, "gunner_basic:1"), 0.0, "charge critical damage only applies to magic grenades")
	owner.level_talents.clear()
	PLAYER_GUNNER_MAGIC_GRENADE_FLOW.add_charge_energy(owner, 1.0)
	_expect_approx(PLAYER_GUNNER_MAGIC_GRENADE_FLOW.get_charge_critical_bonus(owner), 0.0025, "charge energy does not accumulate without the talent")
	owner.free()


func _check_magic_grenade_level_nine() -> void:
	var owner := _make_owner()
	_set_level(owner, "gunner_magic_grenade", 8)
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_magic_grenade_damage_ratio_bonus(owner), 2.25, "level 8 damage upgrades should total 225 percentage points")
	var preview := PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "gunner", "gunner_magic_grenade")
	_expect(preview.contains("+50%"), "level 9 preview should show its damage increase")
	_set_level(owner, "gunner_magic_grenade", 9)
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_magic_grenade_damage_ratio_bonus(owner), 2.75, "level 9 should add 50 percentage points")
	_expect(PLAYER_SKILL_LEVEL_SYSTEM.is_progress_upgradeable(owner, "gunner_magic_grenade"), "level 9 should remain upgradeable to level 10")
	_set_level(owner, "gunner_magic_grenade", 10)
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_magic_grenade_damage_ratio_bonus(owner), 2.75, "level 10 should not add an undocumented damage increase")
	_expect(not PLAYER_SKILL_LEVEL_SYSTEM.is_progress_upgradeable(owner, "gunner_magic_grenade"), "level 10 should be the skill line cap")
	PLAYER_SKILL_LEVEL_SYSTEM._refresh_talent_slots(owner, "gunner", "gunner_magic_grenade", 10)
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_granted_talent_slots(owner, "gunner", "gunner_magic_grenade"), [1, 2], "level 10 should grant the second talent slot")
	owner.free()


func _check_magic_grenade_skill_talents() -> void:
	var owner := _make_owner()
	_set_level(owner, "gunner_magic_grenade", 5)
	var offer: Dictionary = PLAYER_SKILL_LEVEL_SYSTEM.build_talent_offer_for(owner, "gunner", "gunner_magic_grenade")
	for slot in [1, 2]:
		var option: Dictionary = offer["options"][int(slot) - 1]
		_expect(bool(option.get("talent_implemented", false)), "magic grenade slot %d should have a real talent definition" % int(slot))
		_expect(not str(option).contains("效果尚未实装"), "magic grenade slot %d should not show placeholder copy" % int(slot))
		_expect(str(option.get("card_highlight", "")) in ["魔法追弹", "幸运之弹"], "magic grenade slot %d should show its authored talent name" % int(slot))
	var selected_result: Dictionary = PLAYER_SKILL_LEVEL_SYSTEM.apply_option_with_result(owner, str(offer["options"][0]["id"]), offer)
	_expect(not selected_result.is_empty(), "magic grenade talent card should be selectable")
	_expect_equal(PLAYER_GUNNER_MAGIC_GRENADE_FLOW.get_grenade_count(owner), 6, "Magic Chase should add three grenades")
	_expect_approx(PLAYER_GUNNER_MAGIC_GRENADE_FLOW.get_damage_ratio(owner), 2.25, "Magic Chase should reduce base damage by 100 points while retaining level damage")
	PLAYER_SKILL_LEVEL_SYSTEM._record_talent_slot(owner, "gunner", "gunner_magic_grenade", 2, true)
	_expect_approx(PLAYER_GUNNER_MAGIC_GRENADE_FLOW.get_critical_chance_bonus(owner, "gunner_magic_grenade:1"), 0.40, "Lucky Round should raise magic grenade crit chance to 40%")
	_expect_approx(PLAYER_GUNNER_MAGIC_GRENADE_FLOW.get_blast_radius(owner), 125.0, "Lucky Round should raise blast radius to 125")
	owner.free()


func _check_magic_grenade_launch_count() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	root.get_tree().current_scene = scene
	var owner := _make_owner()
	scene.add_child(owner)
	owner.level_talents["gunner_level_talent_magic_grenade_1"] = true
	PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(owner, "magic_grenade", 1)
	for index in range(6):
		var enemy := GrenadeTargetStub.new()
		enemy.global_position = Vector2(280.0 + float(index) * 28.0, -20.0 + float(index % 2) * 40.0)
		enemy.add_to_group("enemies")
		scene.add_child(enemy)
	ENEMY_SPATIAL_GRID.cached_frame = -1
	var ability = GUNNER_MAGIC_GRENADE_ABILITY.new()
	_expect(ability._launch(owner, false), "Magic Chase cast should launch")
	_expect_equal(ability.active_grenades.size(), 6, "Magic Chase should create six grenades with enemies present")
	var distinct_targets: Array[Vector2] = []
	for entry in ability.active_grenades:
		var grenade: Node2D = entry.get("node")
		_expect(grenade != null and is_instance_valid(grenade), "each Magic Chase projectile should have a visual node")
		distinct_targets.append(entry.get("target", Vector2.ZERO))
	for first_index in range(distinct_targets.size()):
		for second_index in range(first_index + 1, distinct_targets.size()):
			_expect(
				distinct_targets[first_index].distance_to(distinct_targets[second_index]) > 1.0,
				"Magic Chase enemy targets should not fully overlap"
			)
	ability._clear_grenades()
	owner.free()
	scene.free()
	root.get_tree().current_scene = null
	ENEMY_SPATIAL_GRID.cached_frame = -1


func _check_magic_grenade_target_spread() -> void:
	var same_target := Vector2(240.0, 80.0)
	var targets := PLAYER_GUNNER_MAGIC_GRENADE_FLOW._spread_repeated_targets(
		[same_target, same_target, same_target, same_target, same_target, same_target],
		Vector2.ZERO
	)
	_expect_equal(targets.size(), 6, "Magic Chase should keep all six grenade targets")
	for first_index in range(targets.size()):
		for second_index in range(first_index + 1, targets.size()):
			_expect(
				(targets[first_index] as Vector2).distance_to(targets[second_index] as Vector2) > 1.0,
				"overlapping grenade targets should be spread apart"
			)


func _check_magic_assistant_trigger() -> void:
	var owner := _make_owner()
	owner.level_talents[PLAYER_GUNNER_MAGIC_GRENADE_FLOW.TALENT_MAGIC_GRENADE_ASSISTANT] = true
	var scene := Node2D.new()
	root.add_child(scene)
	root.get_tree().current_scene = scene
	scene.add_child(owner)
	var enemy := GrenadeTargetStub.new()
	scene.add_child(enemy)
	PLAYER_DAMAGE_RESOLVER.deal_damage_to_enemy(owner, enemy, 10.0, "gunner_basic:1")
	_expect_equal(owner.free_grenade_trigger_count, 1, "Magic Assistant should trigger from an actual gunner basic critical")
	PLAYER_DAMAGE_RESOLVER.deal_damage_to_enemy(owner, enemy, 10.0, "mage_basic:1")
	_expect_equal(owner.free_grenade_trigger_count, 1, "Magic Assistant should ignore other roles")
	var queue = PLAYER_DAMAGE_JOB_QUEUE.new()
	queue.configure(owner)
	queue._deal_batched_damage_to_enemy(enemy, 10.0, "gunner_basic:1", 0.0, 2.0, 1.0, 0.0, null, 0.0, false)
	_expect_equal(owner.free_grenade_trigger_count, 2, "Magic Assistant should trigger from queued gunner basic critical damage")
	queue._deal_batched_damage_to_enemy(enemy, 0.0, "gunner_basic:1", 0.0, 2.0, 1.0, 0.0, null, 0.0, false)
	_expect_equal(owner.free_grenade_trigger_count, 2, "Magic Assistant should not trigger from zero-damage queued hits")
	owner.free()
	scene.free()
	root.get_tree().current_scene = null


func _check_magic_grenade_runtime_description() -> void:
	var owner := _make_owner()
	owner.level_talents["gunner_level_talent_magic_grenade_charge"] = true
	owner.set_meta("gunner_magic_grenade_charge_energy", 10.0)
	var ability = GUNNER_MAGIC_GRENADE_ABILITY.new()
	var description := str(ability.get_cooldown_slot(owner).get("description", ""))
	_expect(description.contains("3 枚"), "magic grenade HUD description should report the current grenade count")
	var current_damage_percent := "%.0f%%" % (PLAYER_GUNNER_MAGIC_GRENADE_FLOW.get_damage_ratio(owner) * 100.0)
	_expect(description.contains(current_damage_percent), "magic grenade HUD description should report the current damage ratio")
	_expect(description.contains("22.5%"), "magic grenade HUD description should include charge crit chance")
	_expect(description.contains("10.0") and description.contains("7.00% 暴击伤害"), "magic grenade HUD description should show current charge energy and crit damage")
	_expect(not description.contains("LV4 可选择"), "magic grenade HUD description should not show stale fixed-level text")
	owner.free()


func _check_milestone_counts() -> void:
	var owner := _make_owner()
	var flash_table := {1: 0, 2: 1, 3: 1, 4: 2, 6: 3, 8: 4, 10: 5}
	for level in flash_table.keys():
		_set_level(owner, "gunner_trait", int(level))
		_expect_equal(
			PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_flash_max_stack_bonus(owner),
			int(flash_table[level]),
			"瞬杀 level %d max stack bonus" % int(level)
		)
	_set_level(owner, "gunner_trait", 10)
	_expect_equal(PLAYER_GUNNER_FLASH_TALENT_FLOW.get_base_flash_stack_capacity(owner), 15, "满级瞬杀 should raise the base stack capacity to 15")
	var split_table := {2: 0, 3: 1, 5: 1, 6: 2, 9: 3, 10: 3}
	for level in split_table.keys():
		_set_level(owner, "gunner_basic", int(level))
		_expect_equal(
			PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_basic_split_bullet_count(owner),
			int(split_table[level]),
			"枪手普攻 level %d split bullet count" % int(level)
		)
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_basic_split_angle_degrees(0), 20.0, "first split bullet should fly at +20 degrees")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_basic_split_angle_degrees(1), -20.0, "second split bullet should fly at -20 degrees")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_basic_split_angle_degrees(2), 40.0, "third split bullet should fly at +40 degrees")
	_set_level(owner, "gunner_shrapnel", 9)
	_expect_equal(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_shrapnel_extra_field_count(owner), 3, "散弹 level 9 should add three extra fields")
	_set_level(owner, "gunner_explosive_round", 6)
	_expect_equal(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_explosive_round_extra_shot_count(owner), 2, "爆破弹 level 6 should add two extra shots")
	_set_level(owner, "gunner_magic_grenade", 8)
	_expect_equal(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_magic_grenade_extra_count(owner), 1, "魔法榴弹 level 8 should add one extra grenade")
	owner.free()


func _check_preview_text() -> void:
	var owner := _make_owner()
	_set_level(owner, "gunner_hunt", 1)
	var hunt_preview := PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "gunner", "gunner_hunt")
	_expect(hunt_preview.contains("猎杀圈半径 -5"), "猎杀 preview should mention the circle shrink")
	_expect(hunt_preview.contains("圈外伤害 +1%"), "猎杀 preview should mention the outside damage")
	_set_level(owner, "gunner_trait", 1)
	var execution_preview := PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "gunner", "gunner_trait")
	_expect(execution_preview.contains("瞬杀最大层数 +1"), "瞬杀 level 1 preview should mention the level-2 stack cap")
	_set_level(owner, "gunner_basic", 2)
	var basic_preview := PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "gunner", "gunner_basic")
	_expect(basic_preview.contains("获得一枚分裂弹"), "枪手普攻 level 2 preview should mention the level-3 split bullet")
	_set_level(owner, "gunner_basic", 10)
	_expect_equal(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "gunner", "gunner_basic"), "", "maxed gunner skills should have no upgrade preview")
	owner.free()


func _check_upgrade_card_text() -> void:
	var owner := _make_owner()
	_set_level(owner, "gunner_hunt", 4)
	var options: Array = PLAYER_BUILD_SYSTEM._build_role_options(owner, "gunner", 1)
	var hunt_option := {}
	for option_value in options:
		var option: Dictionary = option_value
		if str(option.get("build_id", "")) == "skill_up_gunner_hunt":
			hunt_option = option
			break
	_expect(not hunt_option.is_empty(), "猎杀 upgrade card should be offered for the gunner slot")
	var hunt_title := str(hunt_option.get("title", ""))
	_expect(hunt_title.contains("升级") and hunt_title.contains("猎杀"), "猎杀 upgrade card title should name the skill, got %s" % hunt_title)
	_expect(str(hunt_option.get("card_title", "")).contains("猎杀"), "猎杀 upgrade card should use the skill name as card title")
	_expect_equal(int(hunt_option.get("skill_level", 0)), 4, "猎杀 upgrade card should expose the current skill level")
	var summary := str(hunt_option.get("summary", ""))
	_expect(summary.contains("猎杀圈半径 -5"), "猎杀 upgrade summary should preview the effect, got %s" % summary)
	owner.free()


func _set_level(owner, progress_id: String, level: int) -> void:
	var states: Dictionary = owner.role_special_states if owner.role_special_states is Dictionary else {}
	var role_state: Dictionary = states.get("gunner", {}) if states.get("gunner", {}) is Dictionary else {}
	var levels: Dictionary = role_state.get("skill_levels", {}) if role_state.get("skill_levels", {}) is Dictionary else {}
	if level <= 1:
		levels.erase(progress_id)
	else:
		levels[progress_id] = level
	role_state["skill_levels"] = levels
	states["gunner"] = role_state
	owner.role_special_states = states


func _make_owner() -> GunnerLevelOwnerStub:
	var owner := GunnerLevelOwnerStub.new()
	owner.roles = [
		{"id": "swordsman", "name": "剑士"},
		{"id": "gunner", "name": "枪手"},
		{"id": "mage", "name": "法师"}
	]
	for skill_id in ["shrapnel_field", "infinite_reload", "explosive_round", "magic_grenade", "magic_eye"]:
		PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(owner, str(skill_id), 1)
	return owner


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _expect_equal(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: %s != %s" % [message, str(actual), str(expected)])


func _expect_approx(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s: %.4f != %.4f" % [message, actual, expected])


class GunnerLevelOwnerStub:
	extends Node

	var roles: Array = []
	var role_special_states: Dictionary = {}
	var blessing_skill_state: Dictionary = {}
	var current_blessing_offer: Dictionary = {}
	var level_talents: Dictionary = {}
	var free_grenade_trigger_count: int = 0
	var global_position := Vector2.ZERO
	var facing_direction := Vector2.RIGHT

	func _has_level_talent(talent_id: String) -> bool:
		return bool(level_talents.get(talent_id, false))

	func _get_live_mouse_aim_direction(fallback_direction: Vector2) -> Vector2:
		return fallback_direction

	func _roll_critical_hit(_role_id: String, _bonus: float = 0.0) -> bool:
		return true

	func _get_critical_damage_multiplier(_role_id: String) -> float:
		return 2.0

	func _spawn_combat_tag(_position: Vector2, _text: String, _color: Color) -> void:
		pass

	func _try_trigger_gunner_magic_grenade_free() -> void:
		free_grenade_trigger_count += 1


class GrenadeTargetStub:
	extends Node2D

	var current_health: float = 1000.0
	var max_health: float = 1000.0

	func take_damage(amount: float, _is_critical: bool = false) -> bool:
		current_health = maxf(0.0, current_health - amount)
		return current_health <= 0.0

extends SceneTree

const PLAYER_SKILL_LEVEL_SYSTEM := preload("res://scripts/player/player_skill_level_system.gd")
const PLAYER_SKILL_LEVEL_EFFECT_FLOW := preload("res://scripts/player/player_skill_level_effect_flow.gd")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_flat_bonuses()
	_check_milestone_counts()
	_check_preview_text()
	_check_upgrade_card_text()
	if failures.is_empty():
		print("SWORDSMAN_SKILL_LEVEL_EFFECT_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_flat_bonuses() -> void:
	var owner := _make_owner()
	_set_level(owner, "swordsman_trait", 1)
	_set_level(owner, "swordsman_entry", 1)
	_set_level(owner, "swordsman_basic", 1)
	_set_level(owner, "swordsman_blade_storm", 1)
	_set_level(owner, "swordsman_crescent_wave", 1)
	_set_level(owner, "swordsman_knight_thrust", 1)
	_set_level(owner, "swordsman_king_blade", 1)
	_set_level(owner, "swordsman_judgement_sword", 1)
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_basic_attack_damage_ratio_bonus(owner), 0.0, "level 1 basic attack should have no damage bonus")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_basic_attack_range_multiplier(owner), 1.0, "level 1 basic attack should have no range bonus")
	_set_level(owner, "swordsman_trait", 4)
	_set_level(owner, "swordsman_entry", 3)
	_set_level(owner, "swordsman_basic", 5)
	_set_level(owner, "swordsman_blade_storm", 6)
	_set_level(owner, "swordsman_crescent_wave", 3)
	_set_level(owner, "swordsman_knight_thrust", 4)
	_set_level(owner, "swordsman_king_blade", 2)
	_set_level(owner, "swordsman_judgement_sword", 5)
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_battle_will_proc_chance_bonus(owner), 0.015, "trait level 4 should add 1.5% battle will chance")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_battle_will_heal_ratio_bonus(owner), 0.015, "trait level 4 should add 1.5% battle will healing")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_knight_glory_invulnerability_bonus(owner), 0.6, "trait level 4 should add 0.6s death defiance invulnerability")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_entry_damage_ratio_bonus(owner), 0.20, "entry level 3 should add 20% damage ratio")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_entry_distance_bonus(owner), 40.0, "entry level 3 should add 40 dash distance")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_basic_attack_damage_ratio_bonus(owner), 0.40, "basic level 5 should add 40% damage ratio")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_basic_attack_range_multiplier(owner), 1.40, "basic level 5 should add 40% range")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_blade_storm_damage_ratio_bonus(owner), 0.10, "blade storm level 6 should add 10% tick ratio")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_blade_storm_radius_bonus(owner), 37.5, "blade storm level 6 should add 37.5 radius")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_crescent_wave_damage_ratio_bonus(owner), 0.30, "crescent level 3 should add 30% damage ratio")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_crescent_wave_speed_bonus(owner), 20.0, "crescent level 3 should add 20 speed")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_knight_thrust_damage_ratio_bonus(owner), 0.15, "knight thrust level 4 should add 15% damage ratio")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_knight_thrust_temp_health_bonus(owner), 3.0, "knight thrust level 4 should add 3 temporary health")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_king_blade_damage_ratio_bonus(owner), 0.10, "king blade level 2 should add 10% damage ratio")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_king_blade_range_multiplier(owner), 1.10, "king blade level 2 should add 10% range")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_judgement_sword_fall_ratio_bonus(owner), 2.0, "judgement level 5 should add 200% fall ratio")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_judgement_sword_shockwave_ratio_bonus(owner), 0.40, "judgement level 5 should add 40% shockwave ratio")
	owner.free()


func _check_milestone_counts() -> void:
	var owner := _make_owner()
	var expectations := {
		"swordsman_basic": {1: 0, 2: 1, 3: 1, 4: 2, 6: 3, 8: 4, 9: 4, 10: 4},
		"swordsman_crescent_wave": {1: 0, 2: 1, 3: 1, 4: 2, 6: 3, 8: 4, 10: 4},
		"swordsman_knight_thrust": {2: 0, 3: 1, 5: 1, 6: 2, 9: 3, 10: 3}
	}
	for progress_id in expectations.keys():
		var table: Dictionary = expectations[progress_id]
		for level in table.keys():
			_set_level(owner, str(progress_id), int(level))
			var actual := 0
			match str(progress_id):
				"swordsman_basic":
					actual = PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_basic_attack_extra_slash_count(owner)
				"swordsman_crescent_wave":
					actual = PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_crescent_wave_extra_wave_count(owner)
				"swordsman_knight_thrust":
					actual = PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_knight_thrust_extra_strike_count(owner)
			_expect_equal(actual, int(table[level]), "%s level %d should have %s extra segments" % [str(progress_id), int(level), str(table[level])])
	var shockwave_table := {1: 1, 2: 1, 3: 2, 5: 2, 6: 3, 8: 3, 9: 4, 10: 4}
	for level in shockwave_table.keys():
		_set_level(owner, "swordsman_judgement_sword", int(level))
		_expect_equal(
			PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_judgement_sword_shockwave_count(owner),
			int(shockwave_table[level]),
			"judgement level %d shockwave count" % int(level)
		)
	owner.free()


func _check_preview_text() -> void:
	var owner := _make_owner()
	_set_level(owner, "swordsman_basic", 1)
	var level_two_preview := PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "swordsman", "swordsman_basic")
	_expect(level_two_preview.contains("伤害倍率 +10%"), "basic level 1 preview should mention +10% damage")
	_expect(level_two_preview.contains("追加一道 60% 伤害的斩击"), "basic level 1 preview should mention the level-2 extra slash")
	_expect(level_two_preview.contains("开启天赋位选择") == false, "level 2 preview should not open talent slots")
	_set_level(owner, "swordsman_basic", 4)
	var level_five_preview := PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "swordsman", "swordsman_basic")
	_expect(level_five_preview.contains("开启天赋位选择"), "level 5 preview should mention the talent slot pick")
	_expect(level_five_preview.contains("追加一道") == false, "level 5 basic attack preview should not add a milestone slash")
	_set_level(owner, "swordsman_judgement_sword", 2)
	var judgement_preview := PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "swordsman", "swordsman_judgement_sword")
	_expect(judgement_preview.contains("追加一道冲击波"), "judgement level 3 preview should mention the extra shockwave")
	_set_level(owner, "swordsman_trait", 10)
	_expect_equal(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "swordsman", "swordsman_trait"), "", "maxed skills should have no upgrade preview")
	owner.free()


func _check_upgrade_card_text() -> void:
	var owner := _make_owner()
	_set_level(owner, "swordsman_basic", 3)
	var options: Array = PLAYER_BUILD_SYSTEM._build_role_options(owner, "swordsman", 0)
	var basic_option := {}
	for option_value in options:
		var option: Dictionary = option_value
		if str(option.get("build_id", "")) == "skill_up_swordsman_basic":
			basic_option = option
			break
	_expect(not basic_option.is_empty(), "swordsman basic upgrade card should be offered")
	_expect(str(basic_option.get("title", "")) == "普通攻击等级+1", "upgrade card title should state the level gain")
	var summary := str(basic_option.get("summary", ""))
	_expect(summary.contains("3 级 → 4 级"), "upgrade card summary should show the level transition, got %s" % summary)
	_expect(summary.contains("升级效果："), "upgrade card summary should include the upgrade effect, got %s" % summary)
	_expect(summary.contains("追加一道 60% 伤害的斩击"), "level 4 upgrade card should preview the milestone slash, got %s" % summary)
	owner.free()


func _set_level(owner, progress_id: String, level: int) -> void:
	var states: Dictionary = owner.role_special_states if owner.role_special_states is Dictionary else {}
	var role_state: Dictionary = states.get("swordsman", {}) if states.get("swordsman", {}) is Dictionary else {}
	var levels: Dictionary = role_state.get("skill_levels", {}) if role_state.get("skill_levels", {}) is Dictionary else {}
	if level <= 1:
		levels.erase(progress_id)
	else:
		levels[progress_id] = level
	role_state["skill_levels"] = levels
	states["swordsman"] = role_state
	owner.role_special_states = states


func _make_owner() -> SwordsmanLevelOwnerStub:
	var owner := SwordsmanLevelOwnerStub.new()
	owner.roles = [
		{"id": "swordsman", "name": "剑士"},
		{"id": "gunner", "name": "枪手"},
		{"id": "mage", "name": "法师"}
	]
	for skill_id in ["blade_storm", "crescent_wave", "knight_thrust", "king_blade", "judgement_sword"]:
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


class SwordsmanLevelOwnerStub:
	extends Node

	var roles: Array = []
	var role_special_states: Dictionary = {}
	var blessing_skill_state: Dictionary = {}
	var current_blessing_offer: Dictionary = {}
	var global_position := Vector2.ZERO

	func _spawn_combat_tag(_position: Vector2, _text: String, _color: Color) -> void:
		pass

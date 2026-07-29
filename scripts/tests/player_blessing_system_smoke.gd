extends SceneTree

const PlayerBlessingSystem := preload("res://scripts/player/player_blessing_system.gd")
const PlayerBuildSystem := preload("res://scripts/player/player_build_system.gd")
const PlayerBlessingSkillState := preload("res://scripts/player/player_blessing_skill_state.gd")
const PlayerRoleStatFlow := preload("res://scripts/player/player_role_stat_flow.gd")
const DeveloperOptionProvider := preload("res://scripts/developer/developer_option_provider.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_level_up_offer_uses_new_pool()
	_check_role_build_single_card_refresh()
	_check_role_build_skill_gating()
	_check_level_based_tier_weights()
	_check_legacy_skill_blessings_are_not_in_level_up_pool()
	_check_kebiru_magic_stone_item_offer_flow()
	_check_kebiru_magic_stone_description_matches_active_role()
	_check_magic_stone_blessing_descriptions_use_role_skill_name()
	_check_default_magic_stone_blessings_are_offerable()
	_check_four_tier_caps()
	_check_general_blessing_descriptions_match_current_design()
	_check_general_blessing_stats()
	_check_tailwind_move_speed_bonus_visible_to_role_stat_flow()
	_check_global_skill_blessings()
	_check_kingdom_trick_scope()
	_check_nonlinear_stats()
	_check_legacy_skill_blessing_storage()
	_check_developer_blessing_options_count_shared_blessings()
	if failures.is_empty():
		print("PLAYER_BLESSING_SYSTEM_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_level_up_offer_uses_new_pool() -> void:
	var owner := _OwnerStub.new()
	var offer: Dictionary = PlayerBlessingSystem.build_offer_for_owner(owner)
	var options: Array = offer.get("options", [])
	if options.size() != PlayerBlessingSystem.OFFER_COUNT:
		failures.append("level-up build offer should provide %d options, got %d" % [PlayerBlessingSystem.OFFER_COUNT, options.size()])
	var context: Dictionary = offer.get("context", {})
	if not bool(context.get("role_build_offer", false)):
		failures.append("level-up offer should be marked as role_build_offer")
	if int(context.get("selection_count", 0)) != 2:
		failures.append("level-up build offer should select 2 cards")
	var expected_role_ids := ["swordsman", "gunner", "mage"]
	for index in range(min(3, options.size())):
		var option = options[index]
		if option is not Dictionary:
			failures.append("role build option %d should be a Dictionary, got %s" % [index, str(option)])
			continue
		if str((option as Dictionary).get("option_category", "")) != PlayerBuildSystem.CATEGORY_ROLE_BUILD:
			failures.append("slot %d should be role build, got %s" % [index, str(option)])
		if int((option as Dictionary).get("role_slot_index", -1)) != index:
			failures.append("slot %d should keep role_slot_index %d, got %s" % [index, index, str(option)])
		if str((option as Dictionary).get("role_id", "")) != str(expected_role_ids[index]):
			failures.append("slot %d should use role %s, got %s" % [index, str(expected_role_ids[index]), str(option)])
	if options.size() >= 4:
		var general_option = options[3]
		if general_option is not Dictionary:
			failures.append("general build option should be a Dictionary, got %s" % str(general_option))
		else:
			if str((general_option as Dictionary).get("blessing_category", "")) != PlayerBlessingSystem.CATEGORY_GENERAL_BLESSING:
				failures.append("fourth slot should be a general blessing, got %s" % str(general_option))
			var tier: int = int((general_option as Dictionary).get("blessing_tier", 0))
			if tier < 1 or tier > 4:
				failures.append("general blessing tier should be I-IV, got %s" % str(general_option))


func _check_role_build_single_card_refresh() -> void:
	var owner := _OwnerStub.new()
	var offer: Dictionary = PlayerBlessingSystem.build_offer_for_owner(owner)
	var before_options: Array = offer.get("options", [])
	if before_options.size() != 4:
		failures.append("single card refresh should start from 4 build options, got %d" % before_options.size())
		return
	var refreshed_offer: Dictionary = PlayerBlessingSystem.refresh_offer_card_for_owner(owner, offer, 1)
	var after_options: Array = refreshed_offer.get("options", [])
	if after_options.size() != before_options.size():
		failures.append("single card refresh should keep option count, got %d" % after_options.size())
		return
	for index in range(after_options.size()):
		if index == 1:
			continue
		var before_option: Dictionary = before_options[index]
		var after_option: Dictionary = after_options[index]
		if str(before_option.get("id", "")) != str(after_option.get("id", "")):
			failures.append("single card refresh should keep card %d unchanged, before %s after %s" % [index, str(before_option), str(after_option)])
	var refreshed_option: Dictionary = after_options[1]
	if int(refreshed_option.get("role_slot_index", -1)) != 1:
		failures.append("single role card refresh should keep role slot index 1, got %s" % str(refreshed_option))
	var refreshed_general_offer: Dictionary = PlayerBlessingSystem.refresh_offer_card_for_owner(owner, offer, 3)
	var after_general_options: Array = refreshed_general_offer.get("options", [])
	for index in range(min(3, after_general_options.size())):
		var before_option: Dictionary = before_options[index]
		var after_option: Dictionary = after_general_options[index]
		if str(before_option.get("id", "")) != str(after_option.get("id", "")):
			failures.append("general card refresh should keep role card %d unchanged, before %s after %s" % [index, str(before_option), str(after_option)])
	if after_general_options.size() >= 4 and str((after_general_options[3] as Dictionary).get("slot", "")) != "general":
		failures.append("general card refresh should keep fourth card as general, got %s" % str(after_general_options[3]))


func _check_role_build_skill_gating() -> void:
	var owner := _OwnerStub.new()
	var before_unlock: Array = PlayerBuildSystem._build_role_options(owner, "swordsman", 0)
	if not _has_role_build_option(before_unlock, "unlock_blade_storm"):
		failures.append("swordsman should offer blade storm unlock before the skill is owned")
	var trait_option := _find_role_build_option(before_unlock, "trait_extra_roll")
	if bool(trait_option.get("hide_card_title", true)) or str(trait_option.get("card_title", "")) != "剑士特性":
		failures.append("trait role build should show trait as card title, got %s" % str(trait_option))
	if str(trait_option.get("build_card_scene", "")) != "stone":
		failures.append("trait role build should use stone card scene, got %s" % str(trait_option))
	if str(trait_option.get("summary", "")) != "战意触发次数+1":
		failures.append("trait role build summary should use design text, got %s" % str(trait_option))
	var swordsman_basic_option := _find_role_build_option(before_unlock, "basic_attack_range")
	if bool(swordsman_basic_option.get("hide_card_title", true)) or str(swordsman_basic_option.get("card_title", "")) != "普通攻击":
		failures.append("basic attack build should show basic attack as card title, got %s" % str(swordsman_basic_option))
	if str(swordsman_basic_option.get("summary", "")) != "剑士普通攻击范围增加10％":
		failures.append("basic attack summary should omit parenthetical notes, got %s" % str(swordsman_basic_option))
	var swordsman_entry_option := _find_role_build_option(before_unlock, "entry_damage")
	if bool(swordsman_entry_option.get("hide_card_title", true)) or str(swordsman_entry_option.get("card_title", "")) != "冲锋":
		failures.append("entry build should show entry skill name as card title, got %s" % str(swordsman_entry_option))
	if str(swordsman_entry_option.get("summary", "")) != "冲锋伤害倍率增加10％":
		failures.append("entry build summary should use entry skill name, got %s" % str(swordsman_entry_option))
	if str(swordsman_entry_option.get("build_card_scene", "")) != "stone":
		failures.append("entry role build should use stone card scene, got %s" % str(swordsman_entry_option))
	var ultimate_option := _find_role_build_option(before_unlock, "ultimate_damage")
	if bool(ultimate_option.get("hide_card_title", true)) or str(ultimate_option.get("card_title", "")) != "无敌斩":
		failures.append("ultimate role build should show ultimate name as card title, got %s" % str(ultimate_option))
	if str(ultimate_option.get("build_card_scene", "")) != "stone":
		failures.append("ultimate role build should use stone card scene, got %s" % str(ultimate_option))
	var gunner_options: Array = PlayerBuildSystem._build_role_options(owner, "gunner", 1)
	var gunner_trait_option := _find_role_build_option(gunner_options, "hunt_safe_radius")
	if bool(gunner_trait_option.get("hide_card_title", true)) or str(gunner_trait_option.get("card_title", "")) != "枪手特性":
		failures.append("gunner trait build should show trait as card title, got %s" % str(gunner_trait_option))
	var gunner_basic_option := _find_role_build_option(gunner_options, "basic_attack_damage")
	if bool(gunner_basic_option.get("hide_card_title", true)) or str(gunner_basic_option.get("card_title", "")) != "普通攻击":
		failures.append("gunner basic attack build should show basic attack as card title, got %s" % str(gunner_basic_option))
	if str(gunner_basic_option.get("summary", "")) != "枪手普通攻击伤害倍率+10％":
		failures.append("gunner basic attack summary should name role, got %s" % str(gunner_basic_option))
	var gunner_entry_option := _find_role_build_option(gunner_options, "entry_damage")
	if bool(gunner_entry_option.get("hide_card_title", true)) or str(gunner_entry_option.get("card_title", "")) != "枪火典礼":
		failures.append("gunner entry build should show entry skill name as card title, got %s" % str(gunner_entry_option))
	var gunner_ultimate_option := _find_role_build_option(gunner_options, "ultimate_wave_count")
	if bool(gunner_ultimate_option.get("hide_card_title", true)) or str(gunner_ultimate_option.get("card_title", "")) != "火箭弹幕":
		failures.append("gunner ultimate build should show ultimate name as card title, got %s" % str(gunner_ultimate_option))
	var mage_options: Array = PlayerBuildSystem._build_role_options(owner, "mage", 2)
	var mage_trait_option := _find_role_build_option(mage_options, "arcane_charge_chance")
	if bool(mage_trait_option.get("hide_card_title", true)) or str(mage_trait_option.get("card_title", "")) != "法师特性":
		failures.append("mage trait build should show trait as card title, got %s" % str(mage_trait_option))
	var mage_basic_option := _find_role_build_option(mage_options, "basic_attack_damage")
	if bool(mage_basic_option.get("hide_card_title", true)) or str(mage_basic_option.get("card_title", "")) != "普通攻击":
		failures.append("mage basic attack build should show basic attack as card title, got %s" % str(mage_basic_option))
	if str(mage_basic_option.get("summary", "")) != "法师普通攻击伤害倍率+15％":
		failures.append("mage basic attack summary should name role, got %s" % str(mage_basic_option))
	var mage_ultimate_option := _find_role_build_option(mage_options, "ultimate_bombard_count")
	if bool(mage_ultimate_option.get("hide_card_title", true)) or str(mage_ultimate_option.get("card_title", "")) != "奥数轰炸":
		failures.append("mage ultimate build should show ultimate name as card title, got %s" % str(mage_ultimate_option))
	if not PlayerBuildSystem.apply_option(owner, "role_build:mage:ultimate_bombard_count"):
		failures.append("mage ultimate bombard count build should apply")
	if PlayerBuildSystem.get_mage_ultimate_bombard_count_bonus(owner) != 2:
		failures.append("mage ultimate bombard count build should add 2")
	var unlock_option := _find_role_build_option(before_unlock, "unlock_blade_storm")
	if bool(unlock_option.get("hide_card_title", true)) or str(unlock_option.get("card_title", "")) != "剑刃风暴":
		failures.append("skill unlock build should show skill name as card title, got %s" % str(unlock_option))
	if str(unlock_option.get("unlock_skill", "")) != "blade_storm":
		failures.append("skill unlock build should expose unlock_skill for card scene routing, got %s" % str(unlock_option))
	if str(unlock_option.get("build_card_scene", "")) != "magicstone":
		failures.append("skill unlock build should use magicstone card scene, got %s" % str(unlock_option))
	for build_id in ["blade_storm_damage", "blade_storm_area", "blade_storm_cooldown"]:
		if _has_role_build_option(before_unlock, str(build_id)):
			failures.append("%s should not be offered before blade storm is unlocked" % str(build_id))
	if not PlayerBuildSystem.apply_option(owner, "role_build:swordsman:unlock_blade_storm"):
		failures.append("blade storm unlock build should apply")
	var after_unlock: Array = PlayerBuildSystem._build_role_options(owner, "swordsman", 0)
	if _has_role_build_option(after_unlock, "unlock_blade_storm"):
		failures.append("blade storm unlock should not be offered after the skill is owned")
	for build_id in ["blade_storm_damage", "blade_storm_area", "blade_storm_cooldown"]:
		if not _has_role_build_option(after_unlock, str(build_id)):
			failures.append("%s should be offered after blade storm is unlocked" % str(build_id))
	var skill_build_option := _find_role_build_option(after_unlock, "blade_storm_damage")
	if bool(skill_build_option.get("hide_card_title", true)) or str(skill_build_option.get("card_title", "")) != "剑刃风暴":
		failures.append("skill upgrade build should show skill name as card title, got %s" % str(skill_build_option))
	if str(skill_build_option.get("build_card_scene", "")) != "stone":
		failures.append("skill upgrade role build should use stone card scene, got %s" % str(skill_build_option))


func _check_level_based_tier_weights() -> void:
	var expected_by_level := {
		1: {1: 100},
		6: {1: 100},
		7: {1: 80, 2: 20},
		12: {1: 80, 2: 20},
		13: {1: 65, 2: 30, 3: 5},
		18: {1: 65, 2: 30, 3: 5},
		19: {1: 48, 2: 40, 3: 10, 4: 2}
	}
	for level in expected_by_level.keys():
		var actual: Dictionary = PlayerBlessingSystem._get_tier_weights_for_level(int(level))
		var expected: Dictionary = expected_by_level.get(level, {})
		if actual != expected:
			failures.append("tier weights mismatch at level %d, expected %s got %s" % [int(level), str(expected), str(actual)])


func _check_legacy_skill_blessings_are_not_in_level_up_pool() -> void:
	var owner := _OwnerStub.new()
	var seen_legacy := false
	for _index in range(80):
		var offer: Dictionary = PlayerBlessingSystem.build_offer_for_owner(owner)
		for option in offer.get("options", []):
			if option is Dictionary and ["tide_rain", "reprise", "trick"].has(str((option as Dictionary).get("blessing_id", ""))):
				seen_legacy = true
	if seen_legacy:
		failures.append("legacy skill blessings should not appear in normal level-up offers")


func _check_kebiru_magic_stone_item_offer_flow() -> void:
	var owner := _OwnerStub.new()
	var options: Array = PlayerBlessingSystem.build_magic_stone_options(owner)
	var seen_kebiru := false
	for option in options:
		if option is Dictionary and str((option as Dictionary).get("id", "")) == "magic_stone:kebiru":
			seen_kebiru = true
	if not seen_kebiru:
		failures.append("kebiru magic stone should be offerable before it is owned")
	if not PlayerBlessingSystem.apply_magic_stone(owner, "kebiru"):
		failures.append("kebiru magic stone should be applied once")
	if PlayerBlessingSystem.apply_magic_stone(owner, "kebiru"):
		failures.append("kebiru magic stone should not be applied twice")
	for option in PlayerBlessingSystem.build_magic_stone_options(owner):
		if option is Dictionary and str((option as Dictionary).get("id", "")) == "magic_stone:kebiru":
			failures.append("owned kebiru magic stone should not be offered again")
	var blessing_options_after_owned: Array = PlayerBlessingSystem.build_magic_stone_blessing_options(owner)
	var seen_kebiru_blessing := false
	for option in blessing_options_after_owned:
		if option is Dictionary and str((option as Dictionary).get("blessing_id", "")).begins_with("kebiru_"):
			seen_kebiru_blessing = true
	if not seen_kebiru_blessing:
		failures.append("kebiru magic stone blessings should be offerable after kebiru is owned")


func _check_kebiru_magic_stone_description_matches_active_role() -> void:
	var expected_by_role_index := {
		0: "获得月牙剑气",
		1: "获得散弹",
		2: "获得波涛汹涌"
	}
	for role_index in expected_by_role_index.keys():
		var owner := _OwnerStub.new()
		owner.active_role_index = int(role_index)
		var option: Dictionary = _find_magic_stone_option(owner, "magic_stone:kebiru")
		var expected_description: String = str(expected_by_role_index.get(role_index, ""))
		if option.is_empty():
			failures.append("kebiru magic stone option should exist for role index %d" % int(role_index))
			continue
		for key in ["summary", "description", "preview_description", "detail_description", "exact_description"]:
			if str(option.get(key, "")) != expected_description:
				failures.append("kebiru magic stone %s should be '%s' for role index %d, got '%s'" % [key, expected_description, int(role_index), str(option.get(key, ""))])


func _check_magic_stone_blessing_descriptions_use_role_skill_name() -> void:
	var owner := _OwnerStub.new()
	owner.active_role_index = 0
	owner.owned_magic_stones = ["kebiru", "invoker"]
	owner.level = 19
	var kebiru_reprise: Dictionary = _find_magic_stone_blessing_option(owner, "kebiru_reprise", 3)
	if str(kebiru_reprise.get("description", "")) != "月牙剑气100%效果+1":
		failures.append("kebiru reprise should name swordsman skill, got '%s'" % str(kebiru_reprise.get("description", "")))
	if str(kebiru_reprise.get("summary", "")) != "月牙剑气100%+1":
		failures.append("kebiru reprise summary should name swordsman skill, got '%s'" % str(kebiru_reprise.get("summary", "")))
	var invoker_range: Dictionary = _find_magic_stone_blessing_option(owner, "invoker_formation_break", 4)
	if str(invoker_range.get("description", "")) != "剑刃风暴范围增加30%":
		failures.append("invoker formation break should name swordsman skill, got '%s'" % str(invoker_range.get("description", "")))
	owner.active_role_index = 1
	var gunner_kebiru_reprise: Dictionary = _find_magic_stone_blessing_option(owner, "kebiru_reprise", 3)
	if str(gunner_kebiru_reprise.get("description", "")) != "散弹100%效果+1":
		failures.append("kebiru reprise should name gunner skill, got '%s'" % str(gunner_kebiru_reprise.get("description", "")))
	owner.active_role_index = 2
	var mage_invoker_duration: Dictionary = _find_magic_stone_blessing_option(owner, "invoker_tide_rain", 3)
	if str(mage_invoker_duration.get("description", "")) != "梅塔领域持续时间+1.0s":
		failures.append("invoker tide rain should name mage skill, got '%s'" % str(mage_invoker_duration.get("description", "")))


func _check_default_magic_stone_blessings_are_offerable() -> void:
	var owner := _OwnerStub.new()
	owner.level = 19
	var owned_stones := PlayerBlessingSystem.get_owned_magic_stones(owner)
	if not owned_stones.has("kingdom"):
		failures.append("kingdom magic stone should be owned by default")
	if not owned_stones.has("king"):
		failures.append("king magic stone should be owned by default")
	var options: Array = PlayerBlessingSystem.build_magic_stone_blessing_options(owner)
	var seen_ids := {}
	var seen_tiers := {}
	for option in options:
		if option is Dictionary:
			var blessing_id: String = str((option as Dictionary).get("blessing_id", ""))
			var tier: int = int((option as Dictionary).get("blessing_tier", 0))
			seen_ids[blessing_id] = true
			if not seen_tiers.has(blessing_id):
				seen_tiers[blessing_id] = {}
			(seen_tiers[blessing_id] as Dictionary)[tier] = true
	for blessing_id in ["kingdom_prayer", "kingdom_trick", "kingdom_reprise", "kingdom_tide_rain", "kingdom_blazing_sun", "kingdom_coronation"]:
		if not seen_ids.has(blessing_id):
			failures.append("%s should appear when kingdom stone is owned" % blessing_id)
	if not (seen_tiers.get("kingdom_prayer", {}) as Dictionary).has(1) or not (seen_tiers.get("kingdom_prayer", {}) as Dictionary).has(4):
		failures.append("kingdom prayer should offer tier I through IV")
	if (seen_tiers.get("kingdom_trick", {}) as Dictionary).has(1) or (seen_tiers.get("kingdom_trick", {}) as Dictionary).has(4):
		failures.append("kingdom trick should only offer tier II and III")
	if not (seen_tiers.get("kingdom_trick", {}) as Dictionary).has(2) or not (seen_tiers.get("kingdom_trick", {}) as Dictionary).has(3):
		failures.append("kingdom trick should offer tier II and III")
	if (seen_tiers.get("kingdom_reprise", {}) as Dictionary).has(1) or (seen_tiers.get("kingdom_reprise", {}) as Dictionary).has(4):
		failures.append("kingdom reprise should only offer tier II and III")
	if not (seen_tiers.get("kingdom_reprise", {}) as Dictionary).has(2) or not (seen_tiers.get("kingdom_reprise", {}) as Dictionary).has(3):
		failures.append("kingdom reprise should offer tier II and III")
	if (seen_tiers.get("kingdom_tide_rain", {}) as Dictionary).has(1):
		failures.append("kingdom tide rain tier I should not be offerable")
	if not (seen_tiers.get("kingdom_tide_rain", {}) as Dictionary).has(2) or not (seen_tiers.get("kingdom_tide_rain", {}) as Dictionary).has(3):
		failures.append("kingdom tide rain should offer tier II and III")
	if (seen_tiers.get("kingdom_blazing_sun", {}) as Dictionary).has(1) or (seen_tiers.get("kingdom_blazing_sun", {}) as Dictionary).has(2):
		failures.append("kingdom blazing sun should only offer tier III and IV")
	if not (seen_tiers.get("kingdom_blazing_sun", {}) as Dictionary).has(3) or not (seen_tiers.get("kingdom_blazing_sun", {}) as Dictionary).has(4):
		failures.append("kingdom blazing sun should offer tier III and IV")
	if (seen_tiers.get("kingdom_coronation", {}) as Dictionary).has(1) or (seen_tiers.get("kingdom_coronation", {}) as Dictionary).has(2):
		failures.append("kingdom coronation should only offer tier III and IV")
	if not (seen_tiers.get("kingdom_coronation", {}) as Dictionary).has(3) or not (seen_tiers.get("kingdom_coronation", {}) as Dictionary).has(4):
		failures.append("kingdom coronation should offer tier III and IV")


func _check_four_tier_caps() -> void:
	var owner := _OwnerStub.new()
	for tier in range(1, PlayerBlessingSystem.MAX_BLESSING_TIER + 1):
		for _index in range(8):
			PlayerBlessingSystem.apply_option(owner, "blessing:divine_grace:%d" % int(tier))
		var level: int = int(((owner.role_blessing_levels.get("swordsman", {}) as Dictionary).get("divine_grace", {}) as Dictionary).get(int(tier), 0))
		if level != 8:
			failures.append("tier %d should be unlimited, expected 8 got %d" % [int(tier), level])


func _check_general_blessing_stats() -> void:
	var owner := _OwnerStub.new()
	PlayerBlessingSystem.apply_option(owner, "blessing:divine_grace:1")
	PlayerBlessingSystem.apply_option(owner, "blessing:tailwind:2")
	PlayerBlessingSystem.apply_option(owner, "blessing:blazing_sun:3")
	PlayerBlessingSystem.apply_option(owner, "blessing:greed:4")
	PlayerBlessingSystem.apply_option(owner, "blessing:support:4")
	PlayerBlessingSystem.apply_option(owner, "blessing:burst:3")
	PlayerBlessingSystem.apply_option(owner, "blessing:unyielding:2")
	for role_id in ["swordsman", "gunner", "mage"]:
		if not is_equal_approx(PlayerBlessingSystem.get_role_stat_bonus(owner, role_id, "max_health_percent"), 0.08):
			failures.append("divine grace should add shared max health percent")
		if not is_equal_approx(PlayerBlessingSystem.get_role_stat_bonus(owner, role_id, "move_speed_percent"), 0.04):
			failures.append("tailwind should add shared move speed percent")
		if not is_equal_approx(PlayerBlessingSystem.get_role_stat_bonus(owner, role_id, "damage"), 0.115):
			failures.append("blazing sun should add shared percent damage")
		if not is_equal_approx(PlayerBlessingSystem.get_blazing_sun_flat_base_damage(owner, role_id), 2.0):
			failures.append("blazing sun tier III should add flat base damage")
		if not is_equal_approx(PlayerBlessingSystem.get_role_stat_bonus(owner, role_id, "switch_energy_gain"), 0.11):
			failures.append("support tier IV should add switch energy gain")
		if not is_equal_approx(PlayerBlessingSystem.get_role_stat_bonus(owner, role_id, "entry_damage"), 0.08):
			failures.append("support tier IV should add entry damage")
		if not is_equal_approx(PlayerBlessingSystem.get_role_stat_bonus(owner, role_id, "critical_chance"), 0.10):
			failures.append("burst tier III should add critical chance")
		if not is_equal_approx(PlayerBlessingSystem.get_role_stat_bonus(owner, role_id, "critical_damage_bonus"), 0.05):
			failures.append("burst tier III should add critical damage")
		if not is_equal_approx(PlayerBlessingSystem.get_role_stat_bonus(owner, role_id, "damage_reduction"), 12.0):
			failures.append("unyielding tier II should add damage reduction value")
	if not is_equal_approx(PlayerBlessingSystem.get_greed_heal_ratio(owner), 0.04):
		failures.append("greed tier IV should provide 4 percent current health heal ratio")
	if not is_equal_approx(PlayerBlessingSystem.get_greed_max_health_heal_ratio(owner), 0.02):
		failures.append("greed tier IV should provide 2 percent max health heal ratio")
	if not is_equal_approx(PlayerBlessingSystem.get_greed_proc_chance(owner), 0.05):
		failures.append("greed should keep a fixed 5 percent proc chance")


func _check_general_blessing_descriptions_match_current_design() -> void:
	var expected := {
		"divine_grace": {
			1: "I级：最大血量增加8％",
			2: "II级：最大血量增加12％",
			3: "III级：最大血量增加16％，每5s回复1％点最大血量",
			4: "IV级：最大血量增加20％，每5s回复2％点最大血量"
		},
		"support": {
			1: "I级：切人能量获取效率增加2％",
			2: "II级：切人能量获取效率增加5％",
			3: "III级：切人能量获取效率增加8％，进场角色登场技伤害增强5％",
			4: "IV级：切人能量获取效率增加11％，进场角色登场技能伤害增强8％"
		},
		"tailwind": {
			1: "I级：角色移动速度+2％",
			2: "II级：角色移动速度+4％",
			3: "III级：角色移动速度+6％，角色闪避+6",
			4: "IV级：角色移动速度+8％，角色闪避+12"
		},
		"blazing_sun": {
			1: "I级：造成伤害增加5.5％",
			2: "II级：造成伤害增加8.5％",
			3: "III级：造成伤害增加11.5％，角色基础伤害+2",
			4: "IV级：造成伤害增加14.5％，角色基础伤害+4"
		},
		"burst": {
			1: "I级：暴击率增加5％",
			2: "II级：暴击率增加7％",
			3: "III级：暴击率增加10％，暴击伤害增加5％",
			4: "IV级：暴击率增加15％，暴击伤害增加10％"
		},
		"unyielding": {
			1: "I级：角色减伤+6",
			2: "II级：角色减伤+12",
			3: "III级：角色减伤+18",
			4: "IV级：角色减伤+24"
		},
		"greed": {
			1: "I级：角色攻击造成伤害时有5％的概率回复1％当前生命值",
			2: "II级：角色攻击造成伤害时有5％的概率回复2％当前生命值",
			3: "III级：角色攻击造成伤害时有5％的概率回复回复3％当前生命值+1％最大生命值",
			4: "IV级：角色攻击造成伤害时有5％概率回复4％当前生命值+2％最大生命值"
		}
	}
	for blessing_id in expected.keys():
		var definition: Dictionary = PlayerBlessingSystem.DEFINITIONS.get(str(blessing_id), {})
		for tier in (expected.get(blessing_id, {}) as Dictionary).keys():
			var actual: String = PlayerBlessingSystem._get_tier_description(definition, int(tier))
			var expected_description: String = str((expected.get(blessing_id, {}) as Dictionary).get(tier, ""))
			if actual != expected_description:
				failures.append("%s tier %d description should match current design, got '%s'" % [str(blessing_id), int(tier), actual])


func _check_tailwind_move_speed_bonus_visible_to_role_stat_flow() -> void:
	var owner := _OwnerStub.new()
	var before_speed: float = PlayerRoleStatFlow.get_role_move_speed(owner, "gunner")
	PlayerBlessingSystem.apply_option(owner, "blessing:tailwind:1")
	var after_speed: float = PlayerRoleStatFlow.get_role_move_speed(owner, "gunner")
	if not is_equal_approx(before_speed, 70.0):
		failures.append("baseline inactive role speed should be 70.0, got %.2f" % before_speed)
	if not is_equal_approx(after_speed, 71.4):
		failures.append("tailwind tier I should be visible in role move speed, got %.2f" % after_speed)


func _check_global_skill_blessings() -> void:
	var owner := _OwnerStub.new()
	if PlayerBlessingSystem.apply_option(owner, "blessing:general_trick:1"):
		failures.append("global trick should only have tier IV")
	if PlayerBlessingSystem.apply_option(owner, "blessing:general_reprise:2"):
		failures.append("global reprise should only have tier IV")
	if PlayerBlessingSystem.apply_option(owner, "blessing:general_tide_rain:3"):
		failures.append("global tide rain should only have tier IV")
	if not PlayerBlessingSystem.apply_option(owner, "blessing:general_trick:4"):
		failures.append("global trick tier IV should apply")
	if not PlayerBlessingSystem.apply_option(owner, "blessing:general_reprise:4"):
		failures.append("global reprise tier IV should apply")
	if not PlayerBlessingSystem.apply_option(owner, "blessing:general_tide_rain:4"):
		failures.append("global tide rain tier IV should apply")
	var quantity_scales: Array[float] = PlayerBlessingSkillState.get_skill_effect_scales(owner, PlayerBlessingSkillState.SKILL_SWORDSMAN_BASIC_ATTACK, "quantity_skill_count")
	var combo_scales: Array[float] = PlayerBlessingSkillState.get_skill_effect_scales(owner, PlayerBlessingSkillState.SKILL_SWORDSMAN_BASIC_ATTACK, "combo_skill_extra")
	var duration_bonus: float = PlayerBlessingSkillState.get_duration_flat_bonus(owner, PlayerBlessingSkillState.SKILL_BLADE_STORM)
	if quantity_scales.size() != 1 or not is_equal_approx(float(quantity_scales[0]), 1.0):
		failures.append("global trick should add one 100 percent quantity scale, got %s" % str(quantity_scales))
	if combo_scales.size() != 1 or not is_equal_approx(float(combo_scales[0]), 1.0):
		failures.append("global reprise should add one 100 percent combo scale, got %s" % str(combo_scales))
	if not is_equal_approx(duration_bonus, 2.5):
		failures.append("global tide rain should add 2.5s to duration skills, got %.2f" % duration_bonus)
	if not is_zero_approx(PlayerBlessingSkillState.get_duration_flat_bonus(owner, PlayerBlessingSkillState.SKILL_SWORDSMAN_BASIC_ATTACK)):
		failures.append("global tide rain should not affect non-duration skills")
	PlayerBlessingSystem.apply_option(owner, "blessing:kingdom_tide_rain:2")
	PlayerBlessingSystem.apply_option(owner, "blessing:kingdom_blazing_sun:3")
	PlayerBlessingSystem.apply_option(owner, "blessing:kingdom_coronation:3")
	var ultimate_duration_bonus: float = PlayerBlessingSkillState.get_duration_flat_bonus(owner, PlayerBlessingSkillState.SKILL_SWORDSMAN_ULTIMATE)
	var ultimate_damage_multiplier: float = PlayerBlessingSkillState.get_ultimate_damage_multiplier(owner, PlayerBlessingSkillState.SKILL_SWORDSMAN_ULTIMATE)
	var ultimate_special_multiplier: float = PlayerBlessingSkillState.get_ultimate_special_effect_multiplier(owner, PlayerBlessingSkillState.SKILL_SWORDSMAN_ULTIMATE)
	if not is_equal_approx(ultimate_duration_bonus, 3.0):
		failures.append("global + kingdom tide rain should add 3s to ultimate duration, got %.2f" % ultimate_duration_bonus)
	if not is_equal_approx(ultimate_damage_multiplier, 2.0):
		failures.append("kingdom blazing sun tier III should make ultimate damage multiplier 2.0, got %.2f" % ultimate_damage_multiplier)
	if not is_equal_approx(ultimate_special_multiplier, 1.2):
		failures.append("kingdom coronation tier III should make ultimate special multiplier 1.2, got %.2f" % ultimate_special_multiplier)


func _check_kingdom_trick_scope() -> void:
	var owner := _OwnerStub.new()
	if not PlayerBlessingSystem.apply_option(owner, "blessing:kingdom_trick:2"):
		failures.append("kingdom trick tier II should apply")
	var basic_quantity_scales: Array[float] = PlayerBlessingSkillState.get_skill_effect_scales(owner, PlayerBlessingSkillState.SKILL_GUNNER_BASIC_ATTACK, "quantity_skill_count")
	if basic_quantity_scales.size() != 1 or not is_equal_approx(float(basic_quantity_scales[0]), 0.5):
		failures.append("kingdom trick should affect basic attacks as one 50 percent quantity scale, got %s" % str(basic_quantity_scales))
	for skill_id in [
		PlayerBlessingSkillState.SKILL_BLADE_STORM,
		PlayerBlessingSkillState.SKILL_CRESCENT_WAVE,
		PlayerBlessingSkillState.SKILL_INFINITE_RELOAD,
		PlayerBlessingSkillState.SKILL_SHRAPNEL_FIELD,
		PlayerBlessingSkillState.SKILL_SURGING_WAVE,
		PlayerBlessingSkillState.SKILL_META_FIELD
	]:
		var active_quantity_scales: Array[float] = PlayerBlessingSkillState.get_skill_effect_scales(owner, str(skill_id), "quantity_skill_count")
		if not active_quantity_scales.is_empty():
			failures.append("kingdom trick should not affect active skill %s, got %s" % [str(skill_id), str(active_quantity_scales)])


func _check_nonlinear_stats() -> void:
	var owner := _OwnerStub.new()
	PlayerBlessingSystem.apply_option(owner, "blessing:benediction:1")
	PlayerBlessingSystem.apply_option(owner, "blessing:benediction:1")
	var expected_energy := 1.0 - pow(0.90, 2.0)
	if not is_equal_approx(PlayerBlessingSystem.get_role_stat_bonus(owner, "swordsman", "energy_gain"), expected_energy):
		failures.append("benediction should stack nonlinearly")
	PlayerBlessingSystem.apply_option(owner, "blessing:phantom:2")
	PlayerBlessingSystem.apply_option(owner, "blessing:phantom:2")
	var expected_dodge := 0.10
	if not is_equal_approx(PlayerBlessingSystem.get_role_stat_bonus(owner, "gunner", "dodge"), expected_dodge):
		failures.append("phantom should stack linearly")


func _check_legacy_skill_blessing_storage() -> void:
	var owner := _OwnerStub.new()
	PlayerBlessingSystem.apply_option(owner, "blessing:reprise:1")
	if int((owner.skill_blessing_levels.get("reprise", {}) as Dictionary).get(1, 0)) != 1:
		failures.append("legacy skill blessing storage should still work")


func _check_developer_blessing_options_count_shared_blessings() -> void:
	var owner := _OwnerStub.new()
	PlayerBlessingSystem.apply_blessing(owner, "divine_grace", 1, false)
	var role_option: Dictionary = _find_developer_blessing_option(owner, "divine_grace:1")
	if int(role_option.get("tier", 0)) != 1:
		failures.append("developer blessing option should include role-bound blessing")
	if not str(role_option.get("title", "")).contains("x1"):
		failures.append("developer role-bound blessing option should display shared count x1, got %s" % str(role_option.get("title", "")))
	PlayerBlessingSystem.apply_blessing(owner, "tide_rain", 1, false)
	var skill_option: Dictionary = _find_developer_blessing_option(owner, "tide_rain:1")
	if not str(skill_option.get("title", "")).contains("x1"):
		failures.append("developer skill-bound blessing option should display count x1, got %s" % str(skill_option.get("title", "")))


func _has_role_build_option(options: Array, build_id: String) -> bool:
	for option in options:
		if option is Dictionary and str((option as Dictionary).get("build_id", "")) == build_id:
			return true
	return false


func _find_role_build_option(options: Array, build_id: String) -> Dictionary:
	for option in options:
		if option is Dictionary and str((option as Dictionary).get("build_id", "")) == build_id:
			return option
	return {}


func _find_developer_blessing_option(owner, option_id: String) -> Dictionary:
	for option in DeveloperOptionProvider.get_blessing_options(owner):
		if option is Dictionary and str((option as Dictionary).get("id", "")) == option_id:
			return option
	return {}


func _find_magic_stone_option(owner, option_id: String) -> Dictionary:
	for option in PlayerBlessingSystem.build_magic_stone_options(owner):
		if option is Dictionary and str((option as Dictionary).get("id", "")) == option_id:
			return option
	return {}


func _find_magic_stone_blessing_option(owner, blessing_id: String, tier: int) -> Dictionary:
	for option in PlayerBlessingSystem.build_magic_stone_blessing_options(owner):
		if option is Dictionary and str((option as Dictionary).get("blessing_id", "")) == blessing_id and int((option as Dictionary).get("blessing_tier", 0)) == tier:
			return option
	return {}


class _OwnerStub:
	var level: int = 1
	var roles: Array = [
		{"id": "swordsman", "name": "剑士"},
		{"id": "gunner", "name": "枪手"},
		{"id": "mage", "name": "术师"}
	]
	var active_role_index: int = 0
	var role_blessing_levels: Dictionary = {
		"swordsman": {},
		"gunner": {},
		"mage": {}
	}
	var skill_blessing_levels: Dictionary = {}
	var blessing_skill_state: Dictionary = {}
	var role_special_states: Dictionary = {}
	var owned_magic_stones: Array = []
	var role_upgrade_levels: Dictionary = {
		"swordsman": {},
		"gunner": {},
		"mage": {}
	}
	var base_speed: float = 100.0
	var speed: float = 100.0
	var equipment_speed_bonus: float = 0.0
	var max_health: float = 100.0
	var current_health: float = 100.0
	var switch_cooldown_remaining: float = 0.0
	var equipment_cooldown_multiplier: float = 1.0
	var equipment_skill_range_multiplier: float = 1.0
	var equipment_dodge_chance: float = 0.0
	var damage_taken_multiplier: float = 1.0
	var global_position: Vector2 = Vector2.ZERO
	var health_changed := _SignalStub.new()
	var stats_changed := _SignalStub.new()

	func _get_active_role() -> Dictionary:
		return roles[active_role_index]

	func _spawn_combat_tag(_position: Vector2, _text: String, _color: Color) -> void:
		pass

	func _update_fire_timer() -> void:
		pass

	func get_stat_summary() -> Dictionary:
		return {}

	func get_role_blessing_levels(role_id: String) -> Dictionary:
		PlayerBlessingSystem.sync_shared_role_blessings(self)
		return (role_blessing_levels.get(role_id, {}) as Dictionary).duplicate(true)

	func _get_role_blessing_stat_bonus(role_id: String, stat: String) -> float:
		return PlayerBlessingSystem.get_role_stat_bonus(self, role_id, stat)

	func _get_role_equipment_bonus_summary(_role_id: String) -> Dictionary:
		return {}

	func _get_role_attribute_move_speed_multiplier(_role_id: String) -> float:
		return 1.0

	func get_skill_blessing_levels() -> Dictionary:
		skill_blessing_levels = PlayerBlessingSystem.normalize_skill_state(skill_blessing_levels)
		return skill_blessing_levels.duplicate(true)


class _SignalStub:
	func emit(_a = null, _b = null, _c = null, _d = null) -> void:
		pass

extends SceneTree

const PlayerBlessingSystem := preload("res://scripts/player/player_blessing_system.gd")
const PlayerBlessingSkillState := preload("res://scripts/player/player_blessing_skill_state.gd")
const DeveloperOptionProvider := preload("res://scripts/developer/developer_option_provider.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_level_up_offer_uses_new_pool()
	_check_level_based_tier_weights()
	_check_legacy_skill_blessings_are_not_in_level_up_pool()
	_check_kebiru_magic_stone_item_offer_flow()
	_check_kebiru_magic_stone_description_matches_active_role()
	_check_magic_stone_blessing_descriptions_use_role_skill_name()
	_check_default_magic_stone_blessings_are_offerable()
	_check_four_tier_caps()
	_check_general_blessing_stats()
	_check_global_skill_blessings()
	_check_kingdom_trick_scope()
	_check_nonlinear_stats()
	_check_manual_compose_keeps_legacy_entry_points()
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
	if options.size() != 3:
		failures.append("level-up blessing offer should provide 3 options, got %d" % options.size())
	for option in options:
		if option is not Dictionary:
			failures.append("offer option should be a Dictionary, got %s" % str(option))
			continue
		var category: String = str((option as Dictionary).get("blessing_category", ""))
		if category != PlayerBlessingSystem.CATEGORY_GENERAL_BLESSING and category != PlayerBlessingSystem.CATEGORY_MAGIC_STONE and category != PlayerBlessingSystem.CATEGORY_MAGIC_STONE_BLESSING:
			failures.append("current offer should contain blessings or magic stone items, got %s" % str(option))
		var tier: int = int((option as Dictionary).get("blessing_tier", 0))
		if tier < 1 or tier > 4:
			failures.append("offer tier should be I-IV, got %s" % str(option))


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
	if not PlayerBlessingSystem.build_magic_stone_options(owner).is_empty():
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
	for role_id in ["swordsman", "gunner", "mage"]:
		if not is_equal_approx(PlayerBlessingSystem.get_role_stat_bonus(owner, role_id, "max_health"), 10.0):
			failures.append("divine grace should add shared max health")
		if not is_equal_approx(PlayerBlessingSystem.get_role_stat_bonus(owner, role_id, "move_speed"), 8.0):
			failures.append("tailwind should add shared move speed")
		if not is_equal_approx(PlayerBlessingSystem.get_role_stat_bonus(owner, role_id, "damage"), 15.0):
			failures.append("blazing sun should add shared flat damage")
	if not is_equal_approx(PlayerBlessingSystem.get_greed_heal_ratio(owner), 0.01):
		failures.append("greed should provide 1 percent max health heal ratio")
	if not is_equal_approx(PlayerBlessingSystem.get_greed_proc_chance(owner), 0.20):
		failures.append("greed tier IV should provide 20 percent proc chance")


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
	if not is_equal_approx(duration_bonus, 3.0):
		failures.append("global tide rain should add 3s to duration skills, got %.2f" % duration_bonus)
	if not is_zero_approx(PlayerBlessingSkillState.get_duration_flat_bonus(owner, PlayerBlessingSkillState.SKILL_SWORDSMAN_BASIC_ATTACK)):
		failures.append("global tide rain should not affect non-duration skills")
	PlayerBlessingSystem.apply_option(owner, "blessing:kingdom_tide_rain:2")
	PlayerBlessingSystem.apply_option(owner, "blessing:kingdom_blazing_sun:3")
	PlayerBlessingSystem.apply_option(owner, "blessing:kingdom_coronation:3")
	var ultimate_duration_bonus: float = PlayerBlessingSkillState.get_duration_flat_bonus(owner, PlayerBlessingSkillState.SKILL_SWORDSMAN_ULTIMATE)
	var ultimate_damage_multiplier: float = PlayerBlessingSkillState.get_ultimate_damage_multiplier(owner, PlayerBlessingSkillState.SKILL_SWORDSMAN_ULTIMATE)
	var ultimate_special_multiplier: float = PlayerBlessingSkillState.get_ultimate_special_effect_multiplier(owner, PlayerBlessingSkillState.SKILL_SWORDSMAN_ULTIMATE)
	if not is_equal_approx(ultimate_duration_bonus, 4.0):
		failures.append("global + kingdom tide rain should add 4s to ultimate duration, got %.2f" % ultimate_duration_bonus)
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


func _check_manual_compose_keeps_legacy_entry_points() -> void:
	var owner := _OwnerStub.new()
	owner.role_blessing_levels["swordsman"]["divine_grace"] = {1: 3}
	if not PlayerBlessingSystem.can_compose_role_blessing(owner, "swordsman", "divine_grace"):
		failures.append("role blessing compose entry point should still work")
	if not PlayerBlessingSystem.compose_role_blessing(owner, "swordsman", "divine_grace"):
		failures.append("role blessing compose should succeed")
	var levels: Dictionary = owner.role_blessing_levels["swordsman"]["divine_grace"]
	if int(levels.get(1, 0)) != 0 or int(levels.get(2, 0)) != 1:
		failures.append("compose should consume three tier I and add one tier II, got %s" % str(levels))
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
	var owned_magic_stones: Array = []
	var role_upgrade_levels: Dictionary = {
		"swordsman": {"damage_bonus": 0.0},
		"gunner": {"damage_bonus": 0.0},
		"mage": {"damage_bonus": 0.0}
	}
	var speed: float = 100.0
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

	func get_skill_blessing_levels() -> Dictionary:
		skill_blessing_levels = PlayerBlessingSystem.normalize_skill_state(skill_blessing_levels)
		return skill_blessing_levels.duplicate(true)


class _SignalStub:
	func emit(_a = null, _b = null, _c = null, _d = null) -> void:
		pass

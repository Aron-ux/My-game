extends SceneTree

const TalentSystem := preload("res://scripts/player/player_skill_talent_system.gd")
const BuildSystem := preload("res://scripts/player/player_build_system.gd")

var failures: Array[String] = []


func _init() -> void:
	_check_definition_matrix()
	_check_stage_thresholds_and_order()
	_check_legacy_string_migration()
	_check_path_and_name_projection()
	_check_axis_specific_upgrade_projection()
	_check_exact_projection_regressions()
	if failures.is_empty():
		print("PLAYER_SKILL_TALENT_SYSTEM_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_definition_matrix() -> void:
	_expect(TalentSystem.TRIGGER_LEVELS == [3, 6, 9], "talent stages should trigger at Lv.3, Lv.6, and Lv.9")
	_expect(TalentSystem.TALENT_DEFINITIONS.size() == 18, "talent matrix should contain 18 skill trees")
	var build_ids_by_progress: Dictionary = {}
	for role_id in BuildSystem.BUILD_DEFINITIONS:
		for build_value in BuildSystem.BUILD_DEFINITIONS[role_id]:
			var build: Dictionary = build_value
			if str(build.get("unlock_skill", "")) != "":
				continue
			var progress_id := str(build.get("skill_progress_id", ""))
			var build_ids: Array = build_ids_by_progress.get(progress_id, [])
			build_ids.append(str(build.get("id", "")))
			build_ids_by_progress[progress_id] = build_ids
	var talent_ids: Dictionary = {}
	var projection_count := 0
	for progress_id in TalentSystem.TALENT_DEFINITIONS:
		var definitions: Array = TalentSystem.TALENT_DEFINITIONS[progress_id]
		_expect(definitions.size() == 6, "%s should contain six talent nodes" % progress_id)
		var stage_sides: Dictionary = {}
		var role_prefix := str(progress_id).get_slice("_", 0) + "_"
		for definition_value in definitions:
			var definition: Dictionary = definition_value
			var talent_id := str(definition.get("id", ""))
			var stage := int(definition.get("stage", 0))
			var side := str(definition.get("side", ""))
			_expect(talent_id.begins_with(role_prefix), "%s should use its role prefix" % talent_id)
			_expect(stage >= 1 and stage <= 3, "%s should declare a valid stage" % talent_id)
			_expect(side == "left" or side == "right", "%s should declare left or right" % talent_id)
			_expect(str(definition.get("upgrade_note", "")) != "", "%s should explain later upgrade inheritance" % talent_id)
			_expect(not talent_ids.has(talent_id), "%s should be globally unique" % talent_id)
			var expected_build_ids: Array = (build_ids_by_progress.get(progress_id, []) as Array).duplicate()
			var projected_build_ids: Array = (TalentSystem.TALENT_BUILD_PROJECTIONS.get(talent_id, {}) as Dictionary).keys()
			expected_build_ids.sort()
			projected_build_ids.sort()
			_expect(projected_build_ids == expected_build_ids, "%s should define every exact non-unlock build projection once" % talent_id)
			projection_count += projected_build_ids.size()
			talent_ids[talent_id] = true
			stage_sides["%d:%s" % [stage, side]] = true
		for stage in range(1, 4):
			_expect(stage_sides.has("%d:left" % stage), "%s stage %d should have a left node" % [progress_id, stage])
			_expect(stage_sides.has("%d:right" % stage), "%s stage %d should have a right node" % [progress_id, stage])
	_expect(talent_ids.size() == 108, "talent matrix should contain 108 unique ids")
	_expect(TalentSystem.TALENT_BUILD_PROJECTIONS.size() == 108, "projection matrix should cover all talents")
	_expect(projection_count == 270, "projection matrix should contain 270 exact talent/build texts")


func _check_stage_thresholds_and_order() -> void:
	var owner := OwnerStub.new()
	_set_trait_level(owner, 2)
	_expect(TalentSystem.get_pending_choices(owner).is_empty(), "Lv.2 should not offer stage I")

	_set_trait_level(owner, 3)
	var pending: Array = TalentSystem.get_pending_choices(owner)
	_expect(pending.size() == 1, "Lv.3 should offer exactly stage I")
	_expect(int((pending[0] as Dictionary).get("talent_stage", 0)) == 1, "Lv.3 should offer stage I first")

	_set_trait_level(owner, 9)
	var offer := TalentSystem.build_choice_offer(owner, pending[0])
	_expect(int((offer.get("context", {}) as Dictionary).get("talent_stage", 0)) == 1, "stage-I offer should preserve its stage context")
	_expect((offer.get("options", []) as Array).size() == 2, "each talent stage should offer two choices")
	_expect(TalentSystem.apply_option_with_result(owner, "skill_talent:swordsman_trait_blood_battle", offer).get("talent_stage", 0) == 1, "stage-I choice should apply")

	pending = TalentSystem.get_pending_choices(owner)
	_expect(pending.size() == 1, "Lv.9 should queue one next stage at a time")
	_expect(int((pending[0] as Dictionary).get("talent_stage", 0)) == 2, "stage II should follow stage I")
	offer = TalentSystem.build_choice_offer(owner, pending[0])
	_expect(TalentSystem.apply_option_with_result(owner, "skill_talent:swordsman_trait_guard_stance", offer).get("talent_stage", 0) == 2, "stage-II choice should apply")

	pending = TalentSystem.get_pending_choices(owner)
	_expect(pending.size() == 1, "stage III should remain pending after stage II")
	_expect(int((pending[0] as Dictionary).get("talent_stage", 0)) == 3, "stage III should follow stage II")
	offer = TalentSystem.build_choice_offer(owner, pending[0])
	_expect(TalentSystem.apply_option_with_result(owner, "skill_talent:swordsman_trait_unyielding", offer).get("talent_stage", 0) == 3, "stage-III choice should apply")
	_expect(TalentSystem.get_pending_choices(owner).is_empty(), "completed three-stage tree should have no pending choice")
	_expect(TalentSystem.get_selected_talents(owner, "swordsman", "swordsman_trait") == [
		"swordsman_trait_blood_battle",
		"swordsman_trait_guard_stance",
		"swordsman_trait_unyielding"
	], "selected talents should retain stage order")


func _check_legacy_string_migration() -> void:
	var owner := OwnerStub.new()
	owner.role_special_states["gunner"] = {
		"skill_talents": {"gunner_basic": "gunner_basic_armor"}
	}
	_expect(TalentSystem.get_selected_talents(owner, "gunner", "gunner_basic") == ["gunner_basic_armor"], "legacy string should read as stage I")
	owner.role_special_states = TalentSystem.normalize_role_special_states(owner.role_special_states)
	_expect(owner.role_special_states["gunner"]["skill_talents"]["gunner_basic"] is Array, "legacy string should migrate to an array")
	_expect(TalentSystem.get_selected_talent(owner, "gunner", "gunner_basic") == "gunner_basic_armor", "legacy stage-I getter should stay compatible")
	_expect(TalentSystem.has_talent(owner, "gunner_basic_armor"), "has_talent should recognize migrated selections")


func _check_path_and_name_projection() -> void:
	var owner := OwnerStub.new()
	owner.role_special_states["swordsman"] = {
		"skill_talents": {
			"swordsman_crescent_wave": [
				"swordsman_crescent_return",
				"swordsman_crescent_twin_moons",
				"swordsman_crescent_eclipse"
			]
		}
	}
	var display := TalentSystem.get_display(owner, "swordsman", "swordsman_crescent_wave")
	_expect(str(display.get("name", "")) == "月牙剑气·月返·双月·月蚀", "full name should append all selected node names")
	_expect(str(display.get("path", "")) == "111", "path should project fixed left/right choices")
	_expect(str(display.get("hud_name", "")) == "月蚀", "HUD name should use the latest node's first two characters")
	_expect(display.get("talent_ids", []) == [
		"swordsman_crescent_return",
		"swordsman_crescent_twin_moons",
		"swordsman_crescent_eclipse"
	], "display should expose the ordered talent ids")

	var payload := TalentSystem.project_skill_payload(owner, "crescent_wave", {
		"name": "月牙剑气",
		"description": "基础说明。"
	})
	_expect(str(payload.get("name", "")) == "月牙剑气·月返·双月·月蚀", "skill payload should use the full evolved name")
	_expect(str(payload.get("talent_path", "")) == "111", "skill payload should expose the projected path")
	_expect(payload.get("talent_ids", []) == display.get("talent_ids", []), "skill payload should retain ordered talent ids")
	var build_option := TalentSystem.project_build_option(owner, {
		"role_id": "swordsman",
		"skill_progress_id": "swordsman_crescent_wave",
		"build_id": "crescent_wave_damage",
		"title": "月牙剑气伤害倍率增加10％",
		"summary": "月牙剑气伤害倍率增加10％"
	})
	_expect(str(build_option.get("card_title", "")) == "月牙剑气·月返·双月·月蚀", "post-talent build cards should keep the full evolved name")
	_expect(str(build_option.get("summary", "")).contains("月返"), "post-talent build cards should name affected talent nodes")
	_expect(not str(build_option.get("summary", "")).contains("速度只改变"), "build cards should not append unrelated talent upgrade axes")

	var base_payload := TalentSystem.project_skill_payload(OwnerStub.new(), "crescent_wave", {"name": "月牙剑气"})
	_expect(str(base_payload.get("hud_name", "")) == "月牙", "base skills should still project a compact HUD name")


func _check_axis_specific_upgrade_projection() -> void:
	var owner := OwnerStub.new()
	owner.role_special_states = {
		"swordsman": {"skill_talents": {"swordsman_crescent_wave": [
			"swordsman_crescent_return",
			"swordsman_crescent_twin_moons",
			"swordsman_crescent_eclipse"
		]}},
		"gunner": {"skill_talents": {"gunner_shrapnel": [
			"gunner_shrapnel_mobile",
			"gunner_shrapnel_rend",
			"gunner_shrapnel_afterfield"
		]}},
		"mage": {"skill_talents": {"mage_surging_wave": [
			"mage_surge_four",
			"mage_surge_vortex",
			"mage_surge_wake"
		]}}
	}
	var moon_damage := _project_build(owner, "swordsman", "swordsman_crescent_wave", "crescent_wave_damage")
	var moon_speed := _project_build(owner, "swordsman", "swordsman_crescent_wave", "crescent_wave_speed")
	_expect(moon_damage.contains("月返") and moon_damage.contains("返程"), "crescent damage should describe return-wave damage inheritance")
	_expect(moon_damage.contains("双月") and moon_damage.contains("额外月牙"), "crescent damage should describe twin-moon damage inheritance")
	_expect(not moon_damage.contains("速度只改变"), "crescent damage should exclude speed-only eclipse timing")
	_expect(moon_speed.contains("月返") and moon_speed.contains("双月"), "crescent speed should name speed-affected derived waves")
	_expect(moon_speed.contains("月蚀") and moon_speed.contains("到达时间"), "crescent speed should explain eclipse timing")
	_expect(not moon_speed.contains("60%") and not moon_speed.contains("55%"), "crescent speed should exclude fixed damage ratios")

	var shrapnel_range := _project_build(owner, "gunner", "gunner_shrapnel", "shrapnel_radius")
	var shrapnel_cooldown := _project_build(owner, "gunner", "gunner_shrapnel", "shrapnel_cooldown")
	_expect(shrapnel_range.contains("机动弹幕") and shrapnel_range.contains("乘1.2"), "shrapnel range should identify the mobile field calculation")
	_expect(not shrapnel_range.contains("冷却"), "shrapnel range should exclude cooldown projection")
	_expect(shrapnel_cooldown.contains("机动弹幕") and shrapnel_cooldown.contains("基础冷却"), "shrapnel cooldown should identify the base skill cooldown")
	_expect(not shrapnel_cooldown.contains("再乘形态倍率"), "mobile shrapnel should not multiply cooldown by its damage/radius form multiplier")
	_expect(not shrapnel_cooldown.contains("半径"), "shrapnel cooldown should exclude range projection")
	owner.role_special_states["gunner"]["skill_talents"]["gunner_shrapnel"][2] = "gunner_shrapnel_quick_throw"
	var quick_throw_cooldown := _project_build(owner, "gunner", "gunner_shrapnel", "shrapnel_cooldown")
	_expect(quick_throw_cooldown.contains("速抛") and quick_throw_cooldown.contains("0.78"), "quick throw should apply its separate cooldown multiplier")

	var surge_duration := _project_build(owner, "mage", "mage_surging_wave", "surging_wave_duration")
	var surge_damage := _project_build(owner, "mage", "mage_surging_wave", "surging_wave_damage")
	_expect(surge_duration.contains("四向潮涌") and surge_duration.contains("涡流") and surge_duration.contains("潮痕"), "surge duration should name affected and fixed-duration mechanisms")
	_expect(surge_duration.contains("不延长潮痕"), "surge duration should preserve the wake duration exception")
	_expect(not surge_duration.contains("55% 伤害"), "surge duration should exclude fixed damage ratios")
	_expect(surge_damage.contains("四向潮涌") and surge_damage.contains("潮痕"), "surge damage should identify wave and wake damage")
	_expect(not surge_damage.contains("持续强化"), "surge damage should exclude duration projection")
	owner.role_special_states["mage"]["skill_talents"]["mage_surging_wave"][1] = "mage_surge_rapid"
	var rapid_speed := _project_build(owner, "mage", "mage_surging_wave", "surging_wave_speed")
	_expect(rapid_speed.contains("疾潮") and rapid_speed.contains("1.30"), "rapid surge speed should apply after the upgraded projectile speed")
	_expect(not rapid_speed.contains("额外伤害基数") and not rapid_speed.contains("15%"), "rapid surge speed should not claim to scale its extra damage")

	owner.role_special_states["swordsman"]["skill_talents"]["swordsman_basic"] = [
		"swordsman_basic_cross",
		"swordsman_basic_pursuit",
		"swordsman_basic_sword_wheel"
	]
	var swordsman_basic_cooldown := _project_build(owner, "swordsman", "swordsman_basic", "basic_attack_cooldown")
	_expect(swordsman_basic_cooldown.contains("十字剑势") and swordsman_basic_cooldown.contains("追锋") and swordsman_basic_cooldown.contains("剑轮"), "swordsman basic cooldown should include all selected attack forms")
	_expect(swordsman_basic_cooldown.contains("主斩") and swordsman_basic_cooldown.contains("追加斩"), "swordsman basic cooldown should name the main and added slashes")

	owner.role_special_states["gunner"]["skill_talents"]["gunner_basic"] = [
		"gunner_basic_burst",
		"gunner_basic_penetration",
		"gunner_basic_mobile_fire"
	]
	var gunner_basic_cooldown := _project_build(owner, "gunner", "gunner_basic", "basic_attack_cooldown")
	_expect(gunner_basic_cooldown.contains("三连点射") and gunner_basic_cooldown.contains("整组三连点射"), "gunner basic cooldown should apply to the full three-shot burst")
	_expect(gunner_basic_cooldown.contains("穿排") and gunner_basic_cooldown.contains("冷却强化完整作用普攻间隔"), "gunner penetration should retain the full cooldown benefit")


func _project_build(owner: OwnerStub, role_id: String, progress_id: String, build_id: String) -> String:
	var projected := TalentSystem.project_build_option(owner, {
		"role_id": role_id,
		"skill_progress_id": progress_id,
		"build_id": build_id,
		"title": build_id,
		"summary": build_id
	})
	return str(projected.get("summary", ""))


func _check_exact_projection_regressions() -> void:
	var gale: Dictionary = TalentSystem.TALENT_BUILD_PROJECTIONS["swordsman_blade_storm_returning_gale"]
	for build_id in ["blade_storm_damage", "blade_storm_area", "blade_storm_cooldown"]:
		var text := str(gale.get(build_id, ""))
		_expect(text.contains("不影响") and text.contains("30%减伤"), "returning gale %s should explicitly preserve its 30%% reduction" % build_id)

	var escape_step: Dictionary = TalentSystem.TALENT_BUILD_PROJECTIONS["gunner_trait_escape_step"]
	_expect(str(escape_step.get("hunt_inside_damage", "")).contains("不影响") and str(escape_step.get("hunt_inside_damage", "")).contains("圈内"), "danger slide should not alter inside-circle damage")
	_expect(str(escape_step.get("hunt_outside_damage", "")).contains("不影响") and str(escape_step.get("hunt_outside_damage", "")).contains("圈外"), "danger slide should not alter outside-circle damage")

	var follow_fire := str((TalentSystem.TALENT_BUILD_PROJECTIONS["gunner_entry_follow_fire"] as Dictionary).get("entry_damage", ""))
	_expect(follow_fire.contains("只提高礼炮") and follow_fire.contains("续火"), "entry damage should strengthen salvos, not follow-fire")

	var flow_energy := str((TalentSystem.TALENT_BUILD_PROJECTIONS["mage_trait_flow"] as Dictionary).get("arcane_charge_energy", ""))
	_expect(flow_energy.contains("每层回能继续生效"), "flow duration should retain per-stack energy recovery")
	_expect(not flow_energy.contains("同步比例"), "energy projection should not claim to change charge sharing")

	for talent_id in [
		"gunner_infinite_axis",
		"gunner_infinite_dual",
		"gunner_infinite_sweep",
		"gunner_infinite_sear",
		"gunner_infinite_overload",
		"gunner_infinite_recycle"
	]:
		var speed_text := str((TalentSystem.TALENT_BUILD_PROJECTIONS[talent_id] as Dictionary).get("infinite_reload_speed", ""))
		_expect(speed_text.contains("角色移速"), "%s should project the player's movement-speed build" % talent_id)
		_expect(not speed_text.contains("光束移速") and not speed_text.contains("光束移动") and not speed_text.contains("光束均继承移速"), "%s should not project player movement speed onto beam motion" % talent_id)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _set_trait_level(owner: OwnerStub, level: int) -> void:
	var role_state: Dictionary = owner.role_special_states.get("swordsman", {})
	role_state["build_levels"] = {"trait_extra_roll": maxi(0, level - 1)}
	owner.role_special_states["swordsman"] = role_state


class OwnerStub:
	var roles: Array = [
		{"id": "swordsman"},
		{"id": "gunner"},
		{"id": "mage"}
	]
	var blessing_skill_state: Dictionary = {}
	var role_special_states: Dictionary = {}
	var current_blessing_offer: Dictionary = {}

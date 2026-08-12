extends SceneTree

const TalentSystem := preload("res://scripts/player/player_skill_talent_system.gd")
const SkillState := preload("res://scripts/player/player_blessing_skill_state.gd")

var failures: Array[String] = []


func _init() -> void:
	_check_level_talent_offer_flow()
	_check_level_talent_skill_requirements()
	_check_level_talent_group_locks()
	_check_old_skill_talent_path_is_disabled()
	_check_legacy_data_is_cleared_on_normalize()
	if failures.is_empty():
		print("PLAYER_SKILL_TALENT_SYSTEM_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_level_talent_offer_flow() -> void:
	var owner := OwnerStub.new()
	_expect(TalentSystem.get_pending_choices(owner).is_empty(), "no level talent should be pending at game start")

	owner.level = 3
	owner.pending_level_talent_choices = 1
	var pending: Array = TalentSystem.get_pending_choices(owner)
	_expect(pending.size() == 1, "one queued level talent should expose one pending choice")
	_expect(bool((pending[0] as Dictionary).get("level_talent_offer", false)), "pending choice should use the level talent interface")

	var offer := TalentSystem.build_next_offer(owner)
	var options: Array = offer.get("options", [])
	var context: Dictionary = offer.get("context", {})
	_expect(options.size() == 3, "level talent offer should contain three role entries")
	_expect(bool(context.get("level_talent_offer", false)), "level talent context should be marked explicitly")
	_expect(context.get("selection_count", 0) == 1, "level talent offer should be single select")
	_expect((options[0] as Dictionary).get("role_id", "") == "swordsman", "first role entry should be swordsman")
	_expect((options[1] as Dictionary).get("role_id", "") == "gunner", "second role entry should be gunner")
	_expect((options[2] as Dictionary).get("role_id", "") == "mage", "third role entry should be mage")

	for raw_role_option in options:
		var role_option: Dictionary = raw_role_option
		_expect(bool(role_option.get("level_talent_role_entry", false)), "top-level talent options should be role entries")
		var nested_options: Array = role_option.get("level_talent_options", [])
		var role_id := str(role_option.get("role_id", ""))
		if role_id == "mage":
			_expect(not nested_options.is_empty(), "mage role entry should expose secondary talent cards after arcane charge talents are added")
			_expect(nested_options.size() <= 3, "mage role entry should not exceed three talent cards")
		else:
			_expect(nested_options.size() == 3, "non-empty role entries should contain three talent cards")
		for nested_value in nested_options:
			_expect((nested_value as Dictionary).get("role_id", "") == role_id, "nested talent should retain its role id")

	owner.current_blessing_offer = offer
	var swordsman_options: Array = (options[0] as Dictionary).get("level_talent_options", [])
	var old_card_id := str((swordsman_options[0] as Dictionary).get("id", ""))
	var refreshed_options: Array = TalentSystem.refresh_offer_card(owner, 0, "swordsman")
	var refreshed_card_id := str((refreshed_options[0] as Dictionary).get("id", ""))
	_expect(old_card_id != refreshed_card_id, "refresh should replace only the requested swordsman talent card")
	_expect((refreshed_options[1] as Dictionary).get("id", "") == (swordsman_options[1] as Dictionary).get("id", ""), "refresh should not replace other swordsman cards")
	var gunner_options: Array = (options[1] as Dictionary).get("level_talent_options", [])
	var old_gunner_card_id := str((gunner_options[0] as Dictionary).get("id", ""))
	var refreshed_gunner_options: Array = TalentSystem.refresh_offer_card(owner, 0, "gunner")
	_expect(refreshed_gunner_options.size() == 3, "gunner refresh should keep three talent cards")
	var refreshed_gunner_card_id := str((refreshed_gunner_options[0] as Dictionary).get("id", ""))
	_expect(old_gunner_card_id != refreshed_gunner_card_id, "refresh should replace only the requested gunner talent card")
	_expect((refreshed_gunner_options[1] as Dictionary).get("id", "") == (gunner_options[1] as Dictionary).get("id", ""), "refresh should not replace other gunner cards")

	var selected_id := str((refreshed_options[0] as Dictionary).get("id", ""))
	_expect(TalentSystem.apply_choice(owner, selected_id), "level talent choice should be applicable")
	_expect(owner.pending_level_talent_choices == 0, "applying a level talent should consume one pending choice")
	_expect(TalentSystem.get_selected_level_talents(owner, "swordsman").size() == 1, "selected level talent should be stored by role")
	_expect(TalentSystem.has_level_talent(owner, selected_id.trim_prefix(TalentSystem.OPTION_PREFIX)), "new level talent interface should expose selected ids")
	_expect(TalentSystem.get_pending_choices(owner).is_empty(), "no pending choice should remain after selection")


func _check_level_talent_skill_requirements() -> void:
	var owner := OwnerStub.new()
	var gunner_definitions: Array = TalentSystem.LEVEL_TALENT_DEFINITIONS.get("gunner", [])
	var locked_candidates: Array = TalentSystem._collect_level_talent_candidates(owner, gunner_definitions, {}, false)
	_expect(not _has_candidate(locked_candidates, "gunner_level_talent_shrapnel_1"), "locked shrapnel should hide shrapnel I level talent")
	_expect(not _has_candidate(locked_candidates, "gunner_level_talent_shrapnel_2"), "locked shrapnel should hide shrapnel II level talent")
	_expect(not _has_candidate(locked_candidates, "gunner_level_talent_infinite_reload_1"), "locked infinite reload should hide infinite reload I level talent")
	_expect(not _has_candidate(locked_candidates, "gunner_level_talent_infinite_reload_2"), "locked infinite reload should hide infinite reload II level talent")
	_expect(_has_candidate(locked_candidates, "gunner_level_talent_rocket_barrage_1"), "gunner ultimate should expose rocket barrage I level talent")
	_expect(_has_candidate(locked_candidates, "gunner_level_talent_gunfire_ceremony_1"), "gunner entry should expose gunfire ceremony I level talent")
	_expect(_has_candidate(locked_candidates, "gunner_level_talent_basic_attack_1"), "inherent basic attack should remain available")
	var mage_definitions: Array = TalentSystem.LEVEL_TALENT_DEFINITIONS.get("mage", [])
	var mage_candidates: Array = TalentSystem._collect_level_talent_candidates(owner, mage_definitions, {}, false)
	_expect(_has_candidate(mage_candidates, "mage_level_talent_arcane_charge_1"), "mage arcane charge I should be available without a skill unlock")
	_expect(_has_candidate(mage_candidates, "mage_level_talent_arcane_charge_2"), "mage arcane charge II should be available without a skill unlock")
	_expect(_has_candidate(mage_candidates, "mage_level_talent_arcane_surplus_1"), "mage arcane surplus I should be available without a skill unlock")
	_expect(_has_candidate(mage_candidates, "mage_level_talent_arcane_surplus_2"), "mage arcane surplus II should be available without a skill unlock")

	SkillState.force_unlock_skill(owner, "shrapnel_field", 1)
	var shrapnel_candidates: Array = TalentSystem._collect_level_talent_candidates(owner, gunner_definitions, {}, false)
	_expect(_has_candidate(shrapnel_candidates, "gunner_level_talent_shrapnel_1"), "unlocked shrapnel should expose shrapnel I level talent")
	_expect(_has_candidate(shrapnel_candidates, "gunner_level_talent_shrapnel_2"), "unlocked shrapnel should expose shrapnel II level talent")
	_expect(not _has_candidate(shrapnel_candidates, "gunner_level_talent_infinite_reload_1"), "locked infinite reload should still hide infinite reload I level talent")

	var stale_owner := OwnerStub.new()
	stale_owner.pending_level_talent_choices = 1
	stale_owner.current_blessing_offer = _make_nested_level_talent_offer("gunner", "gunner_level_talent_shrapnel_1")
	_expect(not TalentSystem.apply_choice(stale_owner, "skill_talent:gunner_level_talent_shrapnel_1"), "stale shrapnel level talent should not apply before skill unlock")
	_expect(stale_owner.pending_level_talent_choices == 1, "rejected stale level talent should not consume pending choice")
	_expect(TalentSystem.get_selected_level_talents(stale_owner, "gunner").is_empty(), "rejected stale level talent should not be stored")
	SkillState.force_unlock_skill(stale_owner, "shrapnel_field", 1)
	_expect(TalentSystem.apply_choice(stale_owner, "skill_talent:gunner_level_talent_shrapnel_1"), "shrapnel level talent should apply after skill unlock")


func _check_level_talent_group_locks() -> void:
	var owner := OwnerStub.new()
	owner.pending_level_talent_choices = 1
	owner.current_blessing_offer = _make_nested_level_talent_offer("gunner", "gunner_level_talent_basic_attack_1")
	_expect(TalentSystem.apply_choice(owner, "skill_talent:gunner_level_talent_basic_attack_1"), "first talent in a level talent group should apply")

	var gunner_definitions: Array = TalentSystem.LEVEL_TALENT_DEFINITIONS.get("gunner", [])
	var candidates: Array = TalentSystem._collect_level_talent_candidates(owner, gunner_definitions, {}, false)
	_expect(not _has_candidate(candidates, "gunner_level_talent_basic_attack_1"), "selected grouped talent should not refresh again in the same scope")
	_expect(not _has_candidate(candidates, "gunner_level_talent_basic_attack_2"), "alternate grouped talent should not refresh after picking basic attack I")
	var current_offer_candidates: Array = TalentSystem._collect_level_talent_candidates(owner, gunner_definitions, {}, false, {"gunner_level_talent_basic_attack": true})
	_expect(not _has_candidate(current_offer_candidates, "gunner_level_talent_basic_attack_2"), "same offer should not roll another card from an already offered group")

	owner.pending_level_talent_choices = 1
	owner.current_blessing_offer = _make_nested_level_talent_offer("gunner", "gunner_level_talent_basic_attack_2")
	_expect(not TalentSystem.apply_choice(owner, "skill_talent:gunner_level_talent_basic_attack_2"), "stale alternate grouped talent offer should be rejected")
	_expect(TalentSystem.get_selected_level_talents(owner, "gunner").size() == 1, "rejected grouped talent should not be stored")

	var legacy_owner := OwnerStub.new()
	legacy_owner.role_special_states["gunner"] = {"level_talents": ["gunner_level_talent_basic_attack_1"]}
	legacy_owner.role_special_states = TalentSystem.normalize_role_special_states(legacy_owner.role_special_states)
	var legacy_candidates: Array = TalentSystem._collect_level_talent_candidates(legacy_owner, gunner_definitions, {}, false)
	_expect(not _has_candidate(legacy_candidates, "gunner_level_talent_basic_attack_2"), "normalization should derive group locks from existing selected level talents")

	var future_owner := OwnerStub.new()
	future_owner.role_special_states["gunner"] = {
		"level_talents": ["gunner_level_talent_basic_attack_1"],
		"level_talent_group_scope": "period_2"
	}
	var future_candidates: Array = TalentSystem._collect_level_talent_candidates(future_owner, gunner_definitions, {}, false)
	_expect(_has_candidate(future_candidates, "gunner_level_talent_basic_attack_2"), "different future group scope should be able to expose an alternate grouped talent")

	var stale_lock_owner := OwnerStub.new()
	stale_lock_owner.role_special_states["gunner"] = {
		TalentSystem.LEVEL_TALENT_GROUP_LOCKS_KEY: {
			"default": {"gunner_level_talent_basic_attack": "gunner_level_talent_basic_attack_1"}
		}
	}
	stale_lock_owner.role_special_states = TalentSystem.normalize_role_special_states(stale_lock_owner.role_special_states)
	var stale_lock_candidates: Array = TalentSystem._collect_level_talent_candidates(stale_lock_owner, gunner_definitions, {}, false)
	_expect(_has_candidate(stale_lock_candidates, "gunner_level_talent_basic_attack_2"), "stale group locks without a selected talent should be removed during normalization")


func _check_old_skill_talent_path_is_disabled() -> void:
	var owner := OwnerStub.new()
	owner.role_special_states["swordsman"] = {
		"build_levels": {"basic_attack_damage": 8},
		"skill_talents": {
			"swordsman_basic": [
				"swordsman_basic_cross",
				"swordsman_basic_pursuit",
				"swordsman_basic_sword_wheel"
			]
		}
	}
	_expect(TalentSystem.get_pending_choices(owner).is_empty(), "old skill build levels should not create pending talent choices")
	_expect(TalentSystem.build_choice_offer(owner, {
		"role_id": "swordsman",
		"progress_id": "swordsman_basic",
		"talent_stage": 1
	}).is_empty(), "explicit old skill-talent requests should no longer build offers")
	_expect(TalentSystem.get_selected_talent(owner, "swordsman", "swordsman_basic") == "", "old selected-talent getter should return empty")
	_expect(TalentSystem.get_selected_talents(owner, "swordsman", "swordsman_basic").is_empty(), "old selected-talents getter should return empty")
	_expect(not TalentSystem.has_talent(owner, "swordsman_basic_cross"), "old skill talents should not activate runtime effects")

	var display := TalentSystem.get_display(owner, "swordsman", "swordsman_basic")
	_expect(str(display.get("name", "")) == "普通攻击", "old skill talents should not evolve display names")
	_expect((display.get("talent_ids", []) as Array).is_empty(), "old skill talents should not project talent ids")
	var payload := TalentSystem.project_skill_payload(owner, "swordsman_basic_attack", {"name": "普通攻击"})
	_expect(not bool(payload.get("evolved", false)), "old skill talents should not project evolved skill payloads")


func _check_legacy_data_is_cleared_on_normalize() -> void:
	var owner := OwnerStub.new()
	owner.role_special_states["gunner"] = {
		"level_talents": ["gunner_level_talent_hunt_1"],
		"skill_talents": {"gunner_basic": "gunner_basic_armor"}
	}
	owner.role_special_states = TalentSystem.normalize_role_special_states(owner.role_special_states)
	_expect((owner.role_special_states["gunner"]["skill_talents"] as Dictionary).is_empty(), "legacy skill talents should be cleared during normalization")
	_expect(owner.role_special_states["gunner"]["level_talents"] == ["gunner_level_talent_hunt_1"], "level talents should survive normalization")
	_expect(not TalentSystem.has_talent(owner, "gunner_basic_armor"), "cleared legacy skill talents should stay inactive")
	_expect(TalentSystem.has_level_talent(owner, "gunner_level_talent_hunt_1"), "normalized level talents should stay active")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _has_candidate(candidates: Array, talent_id: String) -> bool:
	for candidate_value in candidates:
		if candidate_value is Dictionary and str((candidate_value as Dictionary).get("id", "")) == talent_id:
			return true
	return false


func _make_nested_level_talent_offer(role_id: String, talent_id: String) -> Dictionary:
	return {
		"options": [
			{
				"id": "level_talent_role:%s" % role_id,
				"role_id": role_id,
				"level_talent_role_entry": true,
				"level_talent_options": [
					{
						"id": "skill_talent:%s" % talent_id,
						"role_id": role_id,
						"talent_id": talent_id,
						"level_talent_id": talent_id
					}
				]
			}
		],
		"context": {
			"skill_talent_offer": true,
			"level_talent_offer": true,
			"selection_count": 1
		}
	}


class OwnerStub:
	var roles: Array = [
		{"id": "swordsman"},
		{"id": "gunner"},
		{"id": "mage"}
	]
	var blessing_skill_state: Dictionary = {}
	var role_special_states: Dictionary = {}
	var current_blessing_offer: Dictionary = {}
	var pending_level_talent_choices: int = 0
	var level: int = 1

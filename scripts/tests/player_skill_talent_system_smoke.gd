extends SceneTree

const TalentSystem := preload("res://scripts/player/player_skill_talent_system.gd")


func _init() -> void:
	var owner := OwnerStub.new()
	assert(TalentSystem.TALENT_DEFINITIONS.size() == 18)
	var talent_ids: Dictionary = {}
	for progress_id in TalentSystem.TALENT_DEFINITIONS:
		var definitions: Array = TalentSystem.TALENT_DEFINITIONS[progress_id]
		assert((definitions as Array).size() == 2)
		var role_prefix := str(progress_id).get_slice("_", 0) + "_"
		for definition in definitions:
			var talent_id := str((definition as Dictionary).get("id", ""))
			assert(talent_id.begins_with(role_prefix))
			assert(str((definition as Dictionary).get("upgrade_note", "")) != "")
			talent_ids[talent_id] = true
	assert(talent_ids.size() == 36)

	owner.role_special_states["swordsman"] = {
		"build_levels": {"trait_extra_roll": 1, "trait_heal_bonus": 1}
	}
	assert(TalentSystem.get_skill_progress_level(owner, "swordsman", "swordsman_trait") == 3)
	assert(TalentSystem.get_skill_progress_level(owner, "swordsman", "swordsman_blade_storm") == 0)

	owner.blessing_skill_state = {"unlocked": {"blade_storm": true}}
	assert(TalentSystem.get_skill_progress_level(owner, "swordsman", "swordsman_blade_storm") == 1)
	var pending: Array = TalentSystem.get_pending_choices(owner)
	assert(pending.size() == 1)
	assert(str((pending[0] as Dictionary).get("progress_id", "")) == "swordsman_trait")

	owner.current_blessing_offer = TalentSystem.build_choice_offer(owner, pending[0])
	assert((owner.current_blessing_offer.get("options", []) as Array).size() == 2)
	var option_id := str((owner.current_blessing_offer.get("options", []) as Array)[0].get("id", ""))
	assert(str((owner.current_blessing_offer.get("options", []) as Array)[0].get("title", "")).begins_with("剑士特性·"))
	assert(not TalentSystem.apply_choice(owner, option_id, "swordsman_basic"))
	assert(TalentSystem.apply_choice(owner, option_id, "swordsman_trait"))
	assert(not TalentSystem.apply_choice(owner, option_id, "swordsman_trait"))
	assert(TalentSystem.has_talent(owner, option_id.trim_prefix(TalentSystem.OPTION_PREFIX)))

	owner.role_special_states["swordsman"]["skill_talents"]["swordsman_blade_storm"] = "swordsman_blade_storm_stationary"
	var display := TalentSystem.get_display(owner, "swordsman", "swordsman_blade_storm")
	assert(str(display.get("name", "")) == "剑刃风暴·驻地风暴")
	var skill_payload := TalentSystem.project_skill_payload(owner, "blade_storm", {
		"name": "剑刃风暴",
		"description": "基础说明。"
	})
	assert(str(skill_payload.get("name", "")) == "剑刃风暴·驻地风暴")
	assert(str(skill_payload.get("description", "")).contains("固定在施放地点"))
	var build_option := TalentSystem.project_build_option(owner, {
		"id": "role_build:swordsman:blade_storm_damage",
		"offer_key": "swordsman:blade_storm_damage",
		"role_id": "swordsman",
		"build_id": "blade_storm_damage",
		"skill_progress_id": "swordsman_blade_storm",
		"title": "剑士剑刃风暴伤害倍率增加1.5％",
		"summary": "剑士剑刃风暴伤害倍率增加1.5％"
	})
	assert(str(build_option.get("id", "")) == "role_build:swordsman:blade_storm_damage")
	assert(str(build_option.get("offer_key", "")) == "swordsman:blade_storm_damage")
	assert(str(build_option.get("card_title", "")) == "剑刃风暴·驻地风暴")
	assert(str(build_option.get("summary", "")).contains("驻地风暴") or str(build_option.get("title", "")).contains("驻地风暴"))
	assert(str(build_option.get("summary", "")).contains("伤害倍率增加1.5％"))
	print("PLAYER_SKILL_TALENT_SYSTEM_SMOKE_OK")
	quit(0)


class OwnerStub:
	var roles: Array = [
		{"id": "swordsman"},
		{"id": "gunner"},
		{"id": "mage"}
	]
	var blessing_skill_state: Dictionary = {}
	var role_special_states: Dictionary = {}
	var current_blessing_offer: Dictionary = {}

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
	assert(not TalentSystem.apply_choice(owner, option_id, "swordsman_basic"))
	assert(TalentSystem.apply_choice(owner, option_id, "swordsman_trait"))
	assert(not TalentSystem.apply_choice(owner, option_id, "swordsman_trait"))
	assert(TalentSystem.has_talent(owner, option_id.trim_prefix(TalentSystem.OPTION_PREFIX)))
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

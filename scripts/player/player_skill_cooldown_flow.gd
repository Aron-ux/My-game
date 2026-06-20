extends RefCounted

const PLAYER_SKILL_COOLDOWN_SLOTS := preload("res://scripts/player/player_skill_cooldown_slots.gd")


static func get_active_skill_cooldown_slots(owner, attack_interval: float, include_descriptions: bool = true) -> Array:
	var role_data: Dictionary = owner._get_active_role()
	var role_id: String = str(role_data.get("id", ""))
	return get_role_skill_cooldown_slots(owner, role_id, attack_interval, include_descriptions)


static func get_role_skill_cooldown_slots(owner, role_id: String, attack_interval: float, include_descriptions: bool = true) -> Array:
	var attack_remaining: float = 0.0
	var active_role_id: String = str(owner._get_active_role().get("id", ""))
	if role_id == active_role_id and owner.fire_timer != null and not owner.fire_timer.is_stopped():
		attack_remaining = clamp(owner.fire_timer.time_left, 0.0, attack_interval)

	var extra_slots: Array = []
	_append_blessing_active_skill_slot(owner, role_id, extra_slots)

	var slots: Array = PLAYER_SKILL_COOLDOWN_SLOTS.build_slots(role_id, attack_remaining, attack_interval, extra_slots, owner)
	if include_descriptions:
		_append_requirement_text(owner, slots)
	else:
		_strip_frame_only_slot_text(slots)
	return slots


static func apply_switch_lock_to_role_skills(owner, role_id: String, duration: float) -> void:
	if owner == null or not is_instance_valid(owner) or duration <= 0.0:
		return
	for property_name in _get_role_skill_property_names(role_id):
		var ability: Variant = _get_owner_property(owner, property_name)
		if ability == null:
			continue
		if ability.get("cooldown_remaining") == null:
			continue
		ability.cooldown_remaining = max(float(ability.cooldown_remaining), duration)


static func _append_blessing_active_skill_slot(owner, role_id: String, extra_slots: Array) -> void:
	match role_id:
		"swordsman":
			_append_ability_slot_if_unlocked(owner, extra_slots, "blade_storm", "swordsman_blade_storm_ability")
			_append_ability_slot_if_unlocked(owner, extra_slots, "crescent_wave", "swordsman_crescent_wave_ability")
		"gunner":
			_append_ability_slot_if_unlocked(owner, extra_slots, "infinite_reload", "gunner_infinite_reload_ability")
			_append_ability_slot_if_unlocked(owner, extra_slots, "shrapnel_field", "gunner_shrapnel_field_ability")
		"mage":
			_append_ability_slot_if_unlocked(owner, extra_slots, "surging_wave", "mage_tidal_surge_ability")
			_append_ability_slot_if_unlocked(owner, extra_slots, "meta_field", "mage_meta_field_ability")


static func _get_role_skill_property_names(role_id: String) -> Array[String]:
	match role_id:
		"swordsman":
			return ["swordsman_blade_storm_ability", "swordsman_crescent_wave_ability"]
		"gunner":
			return ["gunner_infinite_reload_ability", "gunner_shrapnel_field_ability"]
		"mage":
			return ["mage_tidal_surge_ability", "mage_meta_field_ability"]
	return []


static func _append_ability_slot_if_unlocked(owner, extra_slots: Array, skill_id: String, property_name: String) -> void:
	if not owner.has_method("_is_blessing_skill_unlocked") or not bool(owner._is_blessing_skill_unlocked(skill_id)):
		return
	var ability: Variant = _get_owner_property(owner, property_name)
	if ability == null or not ability.has_method("get_cooldown_slot"):
		return
	var slot: Dictionary = ability.get_cooldown_slot(owner)
	if slot.is_empty():
		return
	slot["skill_id"] = skill_id
	slot["slot_label"] = str(slot.get("slot_label", "祝福技能"))
	extra_slots.append(slot)


static func _append_requirement_text(owner, slots: Array) -> void:
	if owner == null or not owner.has_method("get_skill_next_requirement_text"):
		return
	for slot in slots:
		if slot is not Dictionary:
			continue
		var slot_dict: Dictionary = slot
		var skill_id := str(slot_dict.get("skill_id", ""))
		if skill_id == "":
			continue
		var requirement_text := str(owner.get_skill_next_requirement_text(skill_id))
		if requirement_text == "":
			continue
		slot_dict["next_requirement"] = requirement_text
		var description := str(slot_dict.get("description", ""))
		slot_dict["description"] = "%s\n\n进化需求：\n%s" % [description, requirement_text] if description != "" else "进化需求：\n%s" % requirement_text

static func _strip_frame_only_slot_text(slots: Array) -> void:
	for slot in slots:
		if slot is not Dictionary:
			continue
		var slot_dict: Dictionary = slot
		slot_dict["description"] = ""
		slot_dict.erase("next_requirement")


static func _get_owner_property(owner, property_name: String):
	if owner == null or not is_instance_valid(owner):
		return null
	return owner.get(property_name)

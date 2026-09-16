extends RefCounted

const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")

## 技能等级系统：每个技能线 1~10 级，5 级开放天赋位选择，10 级自动补齐另一个天赋位。
const MAX_SKILL_LEVEL := 10
const TALENT_PICK_LEVEL := 5
const TALENT_AUTO_LEVEL := 10
const TALENT_SLOT_COUNT := 2
const SKILL_LEVELS_KEY := "skill_levels"
const SKILL_TALENT_SLOTS_KEY := "skill_talent_slots"
const OPTION_PREFIX := "skill_level_talent:"
const CATEGORY_SKILL_LEVEL_TALENT := "skill_level_talent"
const ULTIMATE_PROGRESS_SUFFIX := "_ultimate"

const ROLE_PROGRESS_ORDER := {
	"swordsman": ["swordsman_trait", "swordsman_entry", "swordsman_basic", "swordsman_blade_storm", "swordsman_crescent_wave", "swordsman_knight_thrust", "swordsman_king_blade", "swordsman_judgement_sword", "swordsman_ultimate"],
	"gunner": ["gunner_trait", "gunner_hunt", "gunner_entry", "gunner_basic", "gunner_shrapnel", "gunner_infinite_reload", "gunner_explosive_round", "gunner_magic_grenade", "gunner_magic_eye", "gunner_ultimate"],
	"mage": ["mage_trait", "mage_entry", "mage_basic", "mage_meta_field", "mage_surging_wave", "mage_flame_path", "mage_dark_contract", "mage_fireball", "mage_ultimate"],
	"mechanic": ["mechanic_trait", "mechanic_entry", "mechanic_basic", "mechanic_drone", "mechanic_mine", "mechanic_emp_burst", "mechanic_tulip_turret", "mechanic_missile_volley", "mechanic_ultimate"]
}

const PROGRESS_TITLES := {
	"swordsman_trait": "剑士特性",
	"swordsman_entry": "冲锋",
	"swordsman_basic": "普通攻击",
	"swordsman_blade_storm": "剑刃风暴",
	"swordsman_crescent_wave": "月牙剑气",
	"swordsman_knight_thrust": "骑士突",
	"swordsman_king_blade": "王者之剑",
	"swordsman_judgement_sword": "审判之誓",
	"swordsman_ultimate": "无敌斩",
	"gunner_trait": "瞬杀",
	"gunner_hunt": "猎杀",
	"gunner_entry": "枪火典礼",
	"gunner_basic": "普通攻击",
	"gunner_shrapnel": "散弹",
	"gunner_infinite_reload": "无限装填",
	"gunner_explosive_round": "爆破弹",
	"gunner_magic_grenade": "魔法榴弹",
	"gunner_magic_eye": "魔眼聚合",
	"gunner_ultimate": "火箭弹幕",
	"mage_trait": "术师特性",
	"mage_entry": "密集雷群",
	"mage_basic": "范围轰炸",
	"mage_meta_field": "梅塔领域",
	"mage_surging_wave": "波涛汹涌",
	"mage_flame_path": "火焰之径",
	"mage_dark_contract": "黑暗契约",
	"mage_fireball": "火球术",
	"mage_ultimate": "奥数轰炸",
	"mechanic_trait": "机械师特性",
	"mechanic_entry": "紧急部署",
	"mechanic_basic": "机械蜘蛛",
	"mechanic_drone": "守卫机器人",
	"mechanic_mine": "感应地雷",
	"mechanic_emp_burst": "磁滞力场",
	"mechanic_tulip_turret": "定点机炮",
	"mechanic_missile_volley": "重型炮台",
	"mechanic_ultimate": "机械全开·郁金香齐射"
}

const UNLOCKABLE_PROGRESS := {
	"swordsman_blade_storm": "blade_storm",
	"swordsman_crescent_wave": "crescent_wave",
	"swordsman_knight_thrust": "knight_thrust",
	"swordsman_king_blade": "king_blade",
	"swordsman_judgement_sword": "judgement_sword",
	"gunner_shrapnel": "shrapnel_field",
	"gunner_infinite_reload": "infinite_reload",
	"gunner_explosive_round": "explosive_round",
	"gunner_magic_grenade": "magic_grenade",
	"gunner_magic_eye": "magic_eye",
	"mage_meta_field": "meta_field",
	"mage_surging_wave": "surging_wave",
	"mage_flame_path": "flame_path",
	"mage_dark_contract": "dark_contract",
	"mage_fireball": "fireball",
	"mechanic_drone": "drone",
	"mechanic_mine": "mine",
	"mechanic_emp_burst": "emp_burst",
	"mechanic_tulip_turret": "tulip_turret",
	"mechanic_missile_volley": "missile_volley"
}

const TALENT_SLOT_ROMANS := ["I", "II"]


static func get_skill_level(owner, role_id: String, progress_id: String) -> int:
	if owner == null or role_id == "" or progress_id == "":
		return 0
	if not ROLE_PROGRESS_ORDER.get(role_id, []).has(progress_id):
		return 0
	if not is_progress_unlocked(owner, progress_id):
		return 0
	var state := _get_role_state(owner, role_id)
	var levels: Dictionary = state.get(SKILL_LEVELS_KEY, {}) if state.get(SKILL_LEVELS_KEY, {}) is Dictionary else {}
	return clampi(int(levels.get(progress_id, 1)), 1, MAX_SKILL_LEVEL)


static func get_progress_title(progress_id: String) -> String:
	return str(PROGRESS_TITLES.get(progress_id, progress_id))


static func get_role_progress_ids(actor_role_id: String) -> Array:
	var result: Array = []
	for progress_value in ROLE_PROGRESS_ORDER.get(actor_role_id, []):
		result.append(str(progress_value))
	return result


static func is_ultimate_progress(progress_id: String) -> bool:
	return progress_id.ends_with(ULTIMATE_PROGRESS_SUFFIX)


static func is_progress_unlocked(owner, progress_id: String) -> bool:
	var required_skill := str(UNLOCKABLE_PROGRESS.get(progress_id, ""))
	if required_skill == "":
		return true
	return PLAYER_BLESSING_SKILL_STATE.is_skill_unlocked(owner, required_skill)


static func is_progress_upgradeable(owner, progress_id: String) -> bool:
	if is_ultimate_progress(progress_id):
		return false
	if not is_progress_unlocked(owner, progress_id):
		return false
	return get_skill_level(owner, _resolve_progress_role_id(progress_id), progress_id) < MAX_SKILL_LEVEL


static func get_upgradeable_progress_ids(owner, role_id: String) -> Array:
	var result: Array = []
	for progress_value in get_role_progress_ids(role_id):
		var progress_id := str(progress_value)
		if is_progress_upgradeable(owner, progress_id):
			result.append(progress_id)
	return result


static func add_skill_level(owner, role_id: String, progress_id: String, amount: int = 1) -> Dictionary:
	if owner == null or role_id == "" or progress_id == "":
		return {}
	if not ROLE_PROGRESS_ORDER.get(role_id, []).has(progress_id):
		return {}
	if not is_progress_unlocked(owner, progress_id):
		return {}
	var current_level := get_skill_level(owner, role_id, progress_id)
	if current_level <= 0 or current_level >= MAX_SKILL_LEVEL:
		return {}
	var state := _get_role_state(owner, role_id)
	var levels: Dictionary = state.get(SKILL_LEVELS_KEY, {}) if state.get(SKILL_LEVELS_KEY, {}) is Dictionary else {}
	var next_level: int = mini(MAX_SKILL_LEVEL, current_level + maxi(1, amount))
	levels[progress_id] = next_level
	state[SKILL_LEVELS_KEY] = levels
	_set_role_state(owner, role_id, state)
	apply_level_effect(owner, role_id, progress_id, next_level)
	var pending_opened := _refresh_talent_slots(owner, role_id, progress_id, next_level)
	return {
		"role_id": role_id,
		"progress_id": progress_id,
		"progress_title": get_progress_title(progress_id),
		"previous_level": current_level,
		"level": next_level,
		"maxed": next_level >= MAX_SKILL_LEVEL,
		"pending_talent": pending_opened
	}


## 升级效果的接入点：等级写入后调用。具体数值成长由后续设计补充。
static func apply_level_effect(_owner, _role_id: String, _progress_id: String, _level: int) -> void:
	pass


static func get_granted_talent_slots(owner, role_id: String, progress_id: String) -> Array:
	var state := _get_role_state(owner, role_id)
	var slots_state: Dictionary = state.get(SKILL_TALENT_SLOTS_KEY, {}) if state.get(SKILL_TALENT_SLOTS_KEY, {}) is Dictionary else {}
	var entry: Dictionary = slots_state.get(progress_id, {}) if slots_state.get(progress_id, {}) is Dictionary else {}
	var granted: Array = entry.get("granted", []) if entry.get("granted", []) is Array else []
	var result: Array = []
	for slot_value in granted:
		var slot := int(slot_value)
		if slot >= 1 and slot <= TALENT_SLOT_COUNT and not result.has(slot):
			result.append(slot)
	result.sort()
	return result


static func get_picked_talent_slot(owner, role_id: String, progress_id: String) -> int:
	var state := _get_role_state(owner, role_id)
	var slots_state: Dictionary = state.get(SKILL_TALENT_SLOTS_KEY, {}) if state.get(SKILL_TALENT_SLOTS_KEY, {}) is Dictionary else {}
	var entry: Dictionary = slots_state.get(progress_id, {}) if slots_state.get(progress_id, {}) is Dictionary else {}
	return clampi(int(entry.get("picked", 0)), 0, TALENT_SLOT_COUNT)


static func has_talent_slot(owner, role_id: String, progress_id: String, slot: int) -> bool:
	return get_granted_talent_slots(owner, role_id, progress_id).has(slot)


static func is_talent_pick_pending(owner, role_id: String, progress_id: String) -> bool:
	var level := get_skill_level(owner, role_id, progress_id)
	if level < TALENT_PICK_LEVEL:
		return false
	if level >= TALENT_AUTO_LEVEL:
		return false
	return get_granted_talent_slots(owner, role_id, progress_id).is_empty()


static func get_pending_talent_picks(owner) -> Array:
	var result: Array = []
	if owner == null:
		return result
	for role_id_value in _get_team_role_ids(owner):
		var role_id := str(role_id_value)
		for progress_value in get_role_progress_ids(role_id):
			var progress_id := str(progress_value)
			if not is_talent_pick_pending(owner, role_id, progress_id):
				continue
			result.append({
				"role_id": role_id,
				"progress_id": progress_id,
				"progress_title": get_progress_title(progress_id),
				"skill_level": get_skill_level(owner, role_id, progress_id),
				"trigger_level": TALENT_PICK_LEVEL
			})
	return result


static func has_pending_talent_pick(owner) -> bool:
	return not get_pending_talent_picks(owner).is_empty()


static func build_talent_offer(owner) -> Dictionary:
	var pending := get_pending_talent_picks(owner)
	if pending.is_empty():
		return {}
	var pick: Dictionary = pending[0]
	return build_talent_offer_for(owner, str(pick.get("role_id", "")), str(pick.get("progress_id", "")))


static func build_talent_offer_for(owner, role_id: String, progress_id: String) -> Dictionary:
	if owner == null or role_id == "" or progress_id == "":
		return {}
	if not is_talent_pick_pending(owner, role_id, progress_id):
		return {}
	var progress_title := get_progress_title(progress_id)
	var skill_level := get_skill_level(owner, role_id, progress_id)
	var options: Array = []
	for slot in range(1, TALENT_SLOT_COUNT + 1):
		options.append(_make_talent_option(role_id, progress_id, slot))
	return {
		"options": options,
		"context": {
			"offer_mode": CATEGORY_SKILL_LEVEL_TALENT,
			"skill_talent_offer": true,
			"level_talent_offer": false,
			"role_build_offer": false,
			"skill_level_talent_offer": true,
			"selection_count": 1,
			"refresh_limit": 0,
			"refresh_remaining": 0,
			"refresh_unlimited": false,
			"refresh_button_label": "",
			"role_id": role_id,
			"skill_progress_id": progress_id,
			"talent_slot_count": TALENT_SLOT_COUNT,
			"summary": "%s 达到 %d 级：从两个天赋位中选择一个。满 %d 级会自动获得另一个。" % [progress_title, skill_level, TALENT_AUTO_LEVEL]
		}
	}


static func is_skill_talent_option_id(option_id: String) -> bool:
	return option_id.begins_with(OPTION_PREFIX)


static func apply_choice(owner, option_id: String, _expected_progress_id: String = "") -> bool:
	if owner == null:
		return false
	var offer: Dictionary = owner.get("current_blessing_offer") if owner.get("current_blessing_offer") is Dictionary else {}
	return not apply_option_with_result(owner, option_id, offer).is_empty()


static func apply_option_with_result(owner, option_id: String, current_offer: Dictionary) -> Dictionary:
	if owner == null or not is_skill_talent_option_id(option_id):
		return {}
	var offered := _find_offered_option(current_offer, option_id)
	if offered.is_empty():
		return {}
	var role_id := str(offered.get("role_id", ""))
	var progress_id := str(offered.get("skill_progress_id", ""))
	var slot := int(offered.get("talent_slot", 0))
	if not is_talent_pick_pending(owner, role_id, progress_id):
		return {}
	if slot < 1 or slot > TALENT_SLOT_COUNT:
		return {}
	_record_talent_slot(owner, role_id, progress_id, slot, true)
	var progress_title := get_progress_title(progress_id)
	if owner.has_method("_spawn_combat_tag"):
		owner._spawn_combat_tag(
			owner.global_position + Vector2(0.0, -62.0),
			"%s 天赋位 %s" % [progress_title, _get_slot_roman(slot)],
			Color(0.86, 0.80, 1.0, 1.0)
		)
	return {
		"type": CATEGORY_SKILL_LEVEL_TALENT,
		"role_id": role_id,
		"progress_id": progress_id,
		"progress_title": progress_title,
		"talent_slot": slot,
		"title": "%s 天赋位 %s" % [progress_title, _get_slot_roman(slot)]
	}


static func refresh_talent_card(owner, option_index: int) -> Array:
	var offer: Dictionary = owner.get("current_blessing_offer") if owner != null and owner.get("current_blessing_offer") is Dictionary else {}
	var options: Array = offer.get("options", []) if offer.get("options", []) is Array else []
	if options.is_empty():
		return []
	var index: int = clampi(option_index, 0, max(0, options.size() - 1))
	var option: Dictionary = options[index] if options[index] is Dictionary else {}
	var role_id := str(option.get("role_id", ""))
	var progress_id := str(option.get("skill_progress_id", ""))
	var rebuilt := build_talent_offer_for(owner, role_id, progress_id)
	var rebuilt_options: Array = rebuilt.get("options", []) if rebuilt.get("options", []) is Array else []
	return rebuilt_options if not rebuilt_options.is_empty() else options


static func get_role_summary_text(owner, role_id: String) -> String:
	var parts := PackedStringArray()
	for progress_value in get_role_progress_ids(role_id):
		var progress_id := str(progress_value)
		if is_ultimate_progress(progress_id) or not is_progress_unlocked(owner, progress_id):
			continue
		var level := get_skill_level(owner, role_id, progress_id)
		if level <= 0:
			continue
		parts.append("%s Lv.%d" % [get_progress_title(progress_id), level])
	return " · ".join(parts)


static func normalize_role_state(role_id: String, value: Variant) -> Dictionary:
	var state: Dictionary = value.duplicate(true) if value is Dictionary else {}
	var raw_levels: Dictionary = state.get(SKILL_LEVELS_KEY, {}) if state.get(SKILL_LEVELS_KEY, {}) is Dictionary else {}
	var levels: Dictionary = {}
	for progress_value in ROLE_PROGRESS_ORDER.get(role_id, []):
		var progress_id := str(progress_value)
		if not raw_levels.has(progress_id):
			continue
		var level: int = clampi(int(raw_levels.get(progress_id, 1)), 1, MAX_SKILL_LEVEL)
		if level > 1:
			levels[progress_id] = level
	state[SKILL_LEVELS_KEY] = levels
	var raw_slots: Dictionary = state.get(SKILL_TALENT_SLOTS_KEY, {}) if state.get(SKILL_TALENT_SLOTS_KEY, {}) is Dictionary else {}
	var slots: Dictionary = {}
	for progress_value in ROLE_PROGRESS_ORDER.get(role_id, []):
		var progress_id := str(progress_value)
		var entry_value: Variant = raw_slots.get(progress_id, {})
		if entry_value is not Dictionary:
			continue
		var granted_raw: Array = (entry_value as Dictionary).get("granted", []) if (entry_value as Dictionary).get("granted", []) is Array else []
		var granted: Array = []
		for slot_value in granted_raw:
			var slot := int(slot_value)
			if slot >= 1 and slot <= TALENT_SLOT_COUNT and not granted.has(slot):
				granted.append(slot)
		granted.sort()
		if granted.is_empty():
			continue
		slots[progress_id] = {
			"picked": clampi(int((entry_value as Dictionary).get("picked", 0)), 0, TALENT_SLOT_COUNT),
			"granted": granted
		}
	state[SKILL_TALENT_SLOTS_KEY] = slots
	return state


static func _refresh_talent_slots(owner, role_id: String, progress_id: String, level: int) -> bool:
	if level >= TALENT_AUTO_LEVEL:
		for slot in range(1, TALENT_SLOT_COUNT + 1):
			if not has_talent_slot(owner, role_id, progress_id, slot):
				_record_talent_slot(owner, role_id, progress_id, slot, false)
		return false
	if level >= TALENT_PICK_LEVEL and get_granted_talent_slots(owner, role_id, progress_id).is_empty():
		return true
	return false


static func _record_talent_slot(owner, role_id: String, progress_id: String, slot: int, mark_picked: bool) -> void:
	var state := _get_role_state(owner, role_id)
	var slots_state: Dictionary = state.get(SKILL_TALENT_SLOTS_KEY, {}) if state.get(SKILL_TALENT_SLOTS_KEY, {}) is Dictionary else {}
	var entry: Dictionary = slots_state.get(progress_id, {}) if slots_state.get(progress_id, {}) is Dictionary else {}
	var granted: Array = entry.get("granted", []) if entry.get("granted", []) is Array else []
	if not granted.has(slot):
		granted.append(slot)
	granted.sort()
	entry["granted"] = granted
	if mark_picked:
		entry["picked"] = slot
	slots_state[progress_id] = entry
	state[SKILL_TALENT_SLOTS_KEY] = slots_state
	_set_role_state(owner, role_id, state)


static func _make_talent_option(role_id: String, progress_id: String, slot: int) -> Dictionary:
	var progress_title := get_progress_title(progress_id)
	var slot_roman := _get_slot_roman(slot)
	var summary := "天赋位 %s：占用「%s」的天赋位，具体效果尚未实装。" % [slot_roman, progress_title]
	var description := "选择后占用「%s」的天赋位 %s。该位效果尚未实装；技能满 %d 级时会自动获得另一个天赋位。" % [progress_title, slot_roman, TALENT_AUTO_LEVEL]
	return {
		"id": "%s%s:%s:%d" % [OPTION_PREFIX, role_id, progress_id, slot],
		"offer_key": "%s:%s:%d" % [role_id, progress_id, slot],
		"option_category": CATEGORY_SKILL_LEVEL_TALENT,
		"slot": "skill",
		"slot_label": "技能天赋",
		"role_id": role_id,
		"skill_progress_id": progress_id,
		"talent_slot": slot,
		"talent_stage": slot,
		"title": "%s 天赋位 %s" % [progress_title, slot_roman],
		"card_title": progress_title,
		"hide_card_title": false,
		"summary": summary,
		"short_description": summary,
		"description": description,
		"preview_description": description,
		"detail_description": description,
		"exact_description": description
	}


static func _find_offered_option(current_offer: Dictionary, option_id: String) -> Dictionary:
	if current_offer.is_empty():
		return {}
	var options: Array = current_offer.get("options", []) if current_offer.get("options", []) is Array else []
	for option_value in options:
		if option_value is Dictionary and str((option_value as Dictionary).get("id", "")) == option_id:
			return (option_value as Dictionary).duplicate(true)
	return {}


static func _resolve_progress_role_id(progress_id: String) -> String:
	for role_id_value in ROLE_PROGRESS_ORDER.keys():
		var role_id := str(role_id_value)
		if ROLE_PROGRESS_ORDER[role_id_value].has(progress_id):
			return role_id
	return ""


static func _get_slot_roman(slot: int) -> String:
	return str(TALENT_SLOT_ROMANS[clampi(slot, 1, TALENT_SLOT_COUNT) - 1])


static func _get_team_role_ids(owner) -> Array:
	var result: Array = []
	if owner != null and owner.get("roles") is Array:
		for role_value in owner.get("roles"):
			if role_value is Dictionary:
				var role_id := str((role_value as Dictionary).get("id", ""))
				if role_id != "" and not result.has(role_id):
					result.append(role_id)
	return result


static func _get_role_state(owner, role_id: String) -> Dictionary:
	if owner == null or role_id == "":
		return {}
	if not _owner_has_property(owner, "role_special_states"):
		return {}
	if owner.get("role_special_states") is not Dictionary:
		owner.set("role_special_states", {})
	var states: Dictionary = owner.get("role_special_states")
	if not states.has(role_id) or states.get(role_id, {}) is not Dictionary:
		states[role_id] = {}
		owner.set("role_special_states", states)
	return states[role_id]


static func _set_role_state(owner, role_id: String, state: Dictionary) -> void:
	if owner == null or role_id == "":
		return
	if not _owner_has_property(owner, "role_special_states"):
		return
	var states: Dictionary = owner.get("role_special_states") if owner.get("role_special_states") is Dictionary else {}
	states[role_id] = state
	owner.set("role_special_states", states)


static func _owner_has_property(owner, property_name: String) -> bool:
	if owner == null:
		return false
	for property in owner.get_property_list():
		if property is Dictionary and str((property as Dictionary).get("name", "")) == property_name:
			return true
	return false

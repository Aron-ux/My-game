extends RefCounted

const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")

const OPTION_PREFIX := "skill_talent:"
const CATEGORY_SKILL_TALENT := "skill_talent"
const TALENTS_KEY := "skill_talents"
const TRIGGER_LEVEL := 3

const ROLE_PROGRESS_ORDER := {
	"swordsman": ["swordsman_trait", "swordsman_entry", "swordsman_basic", "swordsman_blade_storm", "swordsman_crescent_wave", "swordsman_ultimate"],
	"gunner": ["gunner_trait", "gunner_entry", "gunner_basic", "gunner_shrapnel", "gunner_infinite_reload", "gunner_ultimate"],
	"mage": ["mage_trait", "mage_entry", "mage_basic", "mage_meta_field", "mage_surging_wave", "mage_ultimate"]
}

const PROGRESS_TITLES := {
	"swordsman_trait": "剑士特性",
	"swordsman_entry": "冲锋",
	"swordsman_basic": "普通攻击",
	"swordsman_blade_storm": "剑刃风暴",
	"swordsman_crescent_wave": "月牙剑气",
	"swordsman_ultimate": "无敌斩",
	"gunner_trait": "枪手特性",
	"gunner_entry": "枪火典礼",
	"gunner_basic": "普通攻击",
	"gunner_shrapnel": "散弹",
	"gunner_infinite_reload": "无限装填",
	"gunner_ultimate": "火箭弹幕",
	"mage_trait": "术师特性",
	"mage_entry": "密集雷群",
	"mage_basic": "范围轰炸",
	"mage_meta_field": "梅塔领域",
	"mage_surging_wave": "波涛汹涌",
	"mage_ultimate": "奥数轰炸"
}

const UNLOCKABLE_PROGRESS := {
	"swordsman_blade_storm": "blade_storm",
	"swordsman_crescent_wave": "crescent_wave",
	"gunner_shrapnel": "shrapnel_field",
	"gunner_infinite_reload": "infinite_reload",
	"mage_meta_field": "meta_field",
	"mage_surging_wave": "surging_wave"
}

const SKILL_PROGRESS_BY_SKILL_ID := {
	"swordsman_basic_attack": "swordsman_basic",
	"gunner_basic_attack": "gunner_basic",
	"mage_basic_attack": "mage_basic",
	"blade_storm": "swordsman_blade_storm",
	"crescent_wave": "swordsman_crescent_wave",
	"shrapnel_field": "gunner_shrapnel",
	"infinite_reload": "gunner_infinite_reload",
	"meta_field": "mage_meta_field",
	"surging_wave": "mage_surging_wave",
	"swordsman_ultimate": "swordsman_ultimate",
	"gunner_ultimate": "gunner_ultimate",
	"mage_ultimate": "mage_ultimate"
}

const TALENT_DEFINITIONS := {
	"swordsman_trait": [
		{"id": "swordsman_trait_blood_battle", "title": "血战昂扬", "description": "战意实际治疗后，3秒内剑士总伤害提高15%；刷新持续时间，不叠层。", "upgrade_note": "战意判定与治疗强化会提高触发收益；骑士荣耀持续构筑也会延长血战昂扬。"},
		{"id": "swordsman_trait_last_guard", "title": "最后的换防", "description": "剑士在后台时，可消耗满换位能量与骑士荣耀挽救一次前台角色，并强制剑士登场；80秒冷却。", "upgrade_note": "战意治疗构筑提高救回生命，骑士荣耀持续构筑提高换防后的无敌时间。"}
	],
	"swordsman_entry": [
		{"id": "swordsman_entry_long_charge", "title": "长驱冲阵", "description": "首次冲锋命中后再向前突进120距离，造成70%伤害。", "upgrade_note": "首次与追加冲锋同步继承伤害强化；追加冲锋保持首次伤害的70%。"},
		{"id": "swordsman_entry_return_guard", "title": "回马护阵", "description": "首次冲锋后沿原路返回起点，造成70%伤害。", "upgrade_note": "去程与回程冲锋同步继承伤害强化；回程保持去程伤害的70%。"}
	],
	"swordsman_basic": [
		{"id": "swordsman_basic_cross", "title": "十字剑势", "description": "每第3次普通攻击追加一道垂直剑气，造成70%伤害。", "upgrade_note": "主斩与第3击垂直追斩同步继承伤害、范围和攻击间隔；追斩保持70%伤害。"},
		{"id": "swordsman_basic_back", "title": "背身斩", "description": "普通攻击主斩同时向身后追加一次45%伤害斩击。", "upgrade_note": "正面主斩与背身斩同步继承伤害、范围和攻击间隔；背身斩保持45%伤害。"}
	],
	"swordsman_blade_storm": [
		{"id": "swordsman_blade_storm_retain", "title": "随身风暴", "description": "切换角色后，剑刃风暴跟随当前角色完成剩余持续时间，伤害降为70%。", "upgrade_note": "施放阶段与后台跟随阶段同步继承伤害、范围和冷却；跟随伤害保持当前每跳的70%。"},
		{"id": "swordsman_blade_storm_stationary", "title": "驻地风暴", "description": "剑刃风暴固定在施放地点，命中使敌人短暂减速至70%。", "upgrade_note": "固定在施放点的风暴继承伤害、范围和冷却；命中减速至70%。"}
	],
	"swordsman_crescent_wave": [
		{"id": "swordsman_crescent_return", "title": "月返", "description": "月牙剑气抵达终点后返回一次，返回伤害为60%。", "upgrade_note": "去程与返程同步继承伤害、速度和冷却；返程保持去程伤害的60%。"},
		{"id": "swordsman_crescent_full_moon", "title": "满月重刃", "description": "剑气变短、变宽、变慢，形成更稳定的近中距离横扫。", "upgrade_note": "短程宽刃继承伤害、速度和冷却；基础飞行速度为500。"}
	],
	"swordsman_ultimate": [
		{"id": "swordsman_ultimate_king", "title": "擒王", "description": "存在Boss时，无敌斩优先追击最近Boss，线斩伤害提高30%。", "upgrade_note": "全部线斩继承伤害强化；命中Boss的线斩额外保持30%增伤。"},
		{"id": "swordsman_ultimate_blossom", "title": "剑华", "description": "每次线斩终点产生一次半径70、伤害为线斩30%的爆发。", "upgrade_note": "线斩与终点爆发同步继承伤害强化；爆发保持线斩伤害的30%。"}
	],
	"gunner_trait": [
		{"id": "gunner_trait_clear_hunt", "title": "清场猎手", "description": "猎杀圈内无敌人时，每1.25秒获得瞬杀层数；敌人进入时暂停积累。", "upgrade_note": "猎杀圈半径、圈内外伤害和瞬杀每层收益继续生效；空圈积层间隔保持1.25秒。"},
		{"id": "gunner_trait_invade_hunt", "title": "侵入猎场", "description": "猎杀圈内有敌人时，每1.25秒获得瞬杀层数，圈内伤害加成提高至75%。", "upgrade_note": "猎杀圈半径、圈内外伤害和瞬杀每层收益继续生效；有敌人时每1.25秒积层。"}
	],
	"gunner_entry": [
		{"id": "gunner_entry_focus", "title": "聚焦礼炮", "description": "登场技改为3波五发前向扇射，每发造成原伤害35%。", "upgrade_note": "3波五发各自继承伤害强化；每发保持原登场弹伤害的35%。"},
		{"id": "gunner_entry_denial", "title": "封锁礼炮", "description": "登场技改为2波十二发环射，每发50%伤害并造成40%减速1.5秒。", "upgrade_note": "2波十二发各自继承伤害强化；每发保持50%，减速数值与持续时间不变。"}
	],
	"gunner_basic": [
		{"id": "gunner_basic_armor", "title": "破甲重弹", "description": "每第4次普通攻击发射2倍伤害、更大且高穿透的重弹。", "upgrade_note": "普通弹与第4发重弹同步继承伤害、射程和攻击间隔；重弹保持2倍伤害。"},
		{"id": "gunner_basic_burst", "title": "三连点射", "description": "每次普通攻击改为3发短点射，每发42%伤害。", "upgrade_note": "三发各自继承伤害与射程，整组启动间隔继承冷却；每发保持42%伤害。"}
	],
	"gunner_shrapnel": [
		{"id": "gunner_shrapnel_mobile", "title": "机动弹幕", "description": "两处固定散弹场合并为跟随枪手的单一弹幕场，范围与伤害提高。", "upgrade_note": "跟随弹幕场继承每跳伤害、半径和冷却；质变倍率在构筑强化后结算。"},
		{"id": "gunner_shrapnel_delayed", "title": "延迟引爆", "description": "基础散弹场自然结束时爆炸，造成当前每跳伤害的250%并续接减速。", "upgrade_note": "散弹场与终爆同步继承伤害、半径和冷却；终爆保持当前每跳伤害的250%。"}
	],
	"gunner_infinite_reload": [
		{"id": "gunner_infinite_axis", "title": "轴线贯穿", "description": "无限装填锁定初始方向，射程更长、光束更窄且每跳伤害提高55%。", "upgrade_note": "锁定轴线光束继承移速、每跳伤害、长度和冷却；长度保持1.25倍、每跳保持1.55倍。"},
		{"id": "gunner_infinite_dual", "title": "双轨齐射", "description": "无限装填变为两条平行光束，每条造成60%伤害。", "upgrade_note": "两条光束分别继承移速、每跳伤害、长度和冷却；每条保持60%伤害。"}
	],
	"gunner_ultimate": [
		{"id": "gunner_ultimate_line", "title": "线列轰炸", "description": "火箭弹幕收窄并延长，每波伤害提高55%。", "upgrade_note": "新增波次继续使用线列形态；每波保持1.55倍伤害。"},
		{"id": "gunner_ultimate_fan", "title": "广域覆盖", "description": "火箭弹幕大幅扩展角度、缩短射程，每波伤害降至70%。", "upgrade_note": "新增波次继续使用广域形态；每波保持70%伤害。"}
	],
	"mage_trait": [
		{"id": "mage_trait_relay", "title": "奥能接力", "description": "奥数充能转移后可在两名非法师角色间额外接力一次。", "upgrade_note": "充能概率、每层回能和同步比例继续生效；额外接力保留当前层数与剩余时间。"},
		{"id": "mage_trait_ultimate", "title": "奥能终式", "description": "充能持有者施放终结技时，每层使最终伤害提高2%，最高20%，随后清空。", "upgrade_note": "充能概率、每层回能和同步比例在消耗前继续生效；终式每层增伤固定2%、最高20%。"}
	],
	"mage_entry": [
		{"id": "mage_entry_center", "title": "雷环归心", "description": "五道环形落雷后，中心追加一次150%范围、60%伤害的落雷。", "upgrade_note": "登场后获得的奥法盈余继续继承持续时间强化；中心落雷保持150%范围、60%伤害。"},
		{"id": "mage_entry_mark", "title": "雷印点名", "description": "登场落雷优先命中范围内至多5个不同敌人，剩余次数补回雷环。", "upgrade_note": "登场后获得的奥法盈余继续继承持续时间强化；点名上限保持5个敌人。"}
	],
	"mage_basic": [
		{"id": "mage_basic_aftershock", "title": "奥术余震", "description": "主爆炸0.35秒后在原处追加一次45%伤害余震。", "upgrade_note": "主爆炸与余震同步继承伤害和范围；余震保持主爆炸伤害的45%。"},
		{"id": "mage_basic_triangle", "title": "三角术式", "description": "主爆炸分裂为三角形三点，每点范围70%、伤害40%。", "upgrade_note": "三个节点分别继承伤害和范围；每点保持40%伤害、70%范围。"}
	],
	"mage_meta_field": [
		{"id": "mage_meta_transfer", "title": "领域转移", "description": "切换角色后领域跟随下一角色4秒，范围、伤害和减速衰减且不再减伤。", "upgrade_note": "减速、范围和每跳伤害在衰减前继承强化；固定减伤仅作用于术师持有领域阶段。"},
		{"id": "mage_meta_collapse", "title": "领域坍缩", "description": "切换角色时立即结束领域并爆发2倍当前每跳伤害，随后进入8秒冷却。", "upgrade_note": "减速、范围和每跳伤害同步作用于坍缩爆发；固定减伤仅作用于坍缩前。"}
	],
	"mage_surging_wave": [
		{"id": "mage_surge_four", "title": "四向潮涌", "description": "基础波次向四个正交方向发射，每道造成55%伤害。", "upgrade_note": "四道基础波分别继承伤害、持续时间、速度和冷却；每道保持55%伤害。"},
		{"id": "mage_surge_back", "title": "逆潮回响", "description": "基础前向波0.8秒后从当前角色位置反向追加70%伤害波。", "upgrade_note": "正向波与反向波同步继承伤害、持续时间、速度和冷却；反向波保持70%伤害。"}
	],
	"mage_ultimate": [
		{"id": "mage_ultimate_lock", "title": "星落锁定", "description": "锁定Boss或单一敌人追踪轰炸，范围缩小、伤害提高25%。", "upgrade_note": "新增轰炸次数继续追踪同一目标；每次保持1.25倍伤害、70%范围。"},
		{"id": "mage_ultimate_triangle", "title": "三星阵列", "description": "锁定敌群中心周围三处节点，轰炸依次循环落于节点。", "upgrade_note": "新增轰炸次数继续在三个节点间循环；每次保持80%范围。"}
	]
}

const EVOLVED_BUILD_TEXT_OVERRIDES := {
	"swordsman_trait_blood_battle:knight_glory_duration": {
		"title": "骑士荣耀与血战昂扬持续时间均增加0.2s",
		"summary": "骑士荣耀无敌与血战昂扬增伤持续时间均增加0.2s。"
	},
	"swordsman_trait_last_guard:trait_heal_bonus": {
		"title": "战意治疗增强，换防救回生命+1%",
		"summary": "战意两部分治疗比例各增加1个百分点；最后的换防救回生命增加1个百分点。"
	},
	"swordsman_trait_last_guard:knight_glory_duration": {
		"title": "骑士荣耀与换防后无敌均增加0.2s",
		"summary": "骑士荣耀及最后的换防强制登场后的无敌时间均增加0.2s。"
	}
}


static func get_display(owner, role_id: String, progress_id: String) -> Dictionary:
	var base_name := str(PROGRESS_TITLES.get(progress_id, progress_id))
	var talent_id := get_selected_talent(owner, role_id, progress_id)
	var talent_definition := get_talent_definition(progress_id, talent_id)
	var talent_title := str(talent_definition.get("title", ""))
	return {
		"base_name": base_name,
		"name": "%s·%s" % [base_name, talent_title] if talent_title != "" else base_name,
		"role_id": role_id,
		"progress_id": progress_id,
		"talent_id": talent_id,
		"talent_title": talent_title,
		"description": str(talent_definition.get("description", "")),
		"upgrade_note": str(talent_definition.get("upgrade_note", ""))
	}


static func get_display_for_skill_id(owner, skill_id: String) -> Dictionary:
	var progress_id := str(SKILL_PROGRESS_BY_SKILL_ID.get(skill_id, ""))
	if progress_id == "":
		return {}
	return get_display(owner, progress_id.get_slice("_", 0), progress_id)


static func get_talent_definition(progress_id: String, talent_id: String) -> Dictionary:
	if talent_id == "":
		return {}
	for definition_value in TALENT_DEFINITIONS.get(progress_id, []):
		if definition_value is Dictionary and str((definition_value as Dictionary).get("id", "")) == talent_id:
			return (definition_value as Dictionary).duplicate(true)
	return {}


static func project_skill_payload(owner, skill_id: String, payload: Dictionary, include_description: bool = true) -> Dictionary:
	var result := payload.duplicate(true)
	var display := get_display_for_skill_id(owner, skill_id)
	if str(display.get("talent_id", "")) == "":
		return result
	result["name"] = str(display.get("name", result.get("name", skill_id)))
	result["evolved"] = true
	result["skill_progress_id"] = str(display.get("progress_id", ""))
	result["talent_id"] = str(display.get("talent_id", ""))
	if include_description:
		var base_description := str(result.get("description", ""))
		var talent_description := str(display.get("description", ""))
		result["description"] = "%s\n\n当前质变：%s" % [base_description, talent_description] if base_description != "" else talent_description
	return result


static func project_build_option(owner, option: Dictionary) -> Dictionary:
	var result := option.duplicate(true)
	var role_id := str(result.get("role_id", ""))
	var progress_id := str(result.get("skill_progress_id", ""))
	if role_id == "" or progress_id == "":
		return result
	var display := get_display(owner, role_id, progress_id)
	var talent_id := str(display.get("talent_id", ""))
	if talent_id == "":
		return result
	var talent_title := str(display.get("talent_title", ""))
	var base_title := str(result.get("title", result.get("build_id", "")))
	var base_summary := str(result.get("summary", result.get("description", "")))
	var override_key := "%s:%s" % [talent_id, str(result.get("build_id", ""))]
	var override: Dictionary = EVOLVED_BUILD_TEXT_OVERRIDES.get(override_key, {})
	var title := str(override.get("title", "%s：%s" % [talent_title, base_title]))
	var summary := str(override.get("summary", base_summary))
	var upgrade_note := str(display.get("upgrade_note", ""))
	if upgrade_note != "":
		summary = "%s；%s" % [summary.trim_suffix("。"), upgrade_note]
	result["title"] = title
	result["summary"] = summary
	result["short_description"] = summary
	result["description"] = summary
	result["preview_description"] = summary
	result["detail_description"] = summary
	result["exact_description"] = summary
	result["card_title"] = str(display.get("name", result.get("card_title", "")))
	result["hide_card_title"] = false
	result["evolved"] = true
	result["talent_id"] = talent_id
	return result


static func is_talent_option_id(option_id: String) -> bool:
	return option_id.begins_with(OPTION_PREFIX)


static func get_skill_progress_level(owner, role_id: String, progress_id: String) -> int:
	if owner == null or not ROLE_PROGRESS_ORDER.get(role_id, []).has(progress_id):
		return 0
	var required_skill := str(UNLOCKABLE_PROGRESS.get(progress_id, ""))
	if required_skill != "" and not PLAYER_BLESSING_SKILL_STATE.is_skill_unlocked(owner, required_skill):
		return 0
	var level := 1
	for definition_value in PLAYER_BUILD_SYSTEM.BUILD_DEFINITIONS.get(role_id, []):
		if definition_value is not Dictionary:
			continue
		var definition: Dictionary = definition_value
		if str(definition.get("skill_progress_id", "")) != progress_id or str(definition.get("unlock_skill", "")) != "":
			continue
		level += PLAYER_BUILD_SYSTEM.get_count(owner, role_id, str(definition.get("id", "")))
	return level


static func get_pending_choices(owner) -> Array:
	var result: Array = []
	for role_id in _get_team_role_ids(owner):
		for progress_id in ROLE_PROGRESS_ORDER.get(role_id, []):
			if get_skill_progress_level(owner, role_id, progress_id) >= TRIGGER_LEVEL and get_selected_talent(owner, role_id, progress_id) == "":
				result.append({"role_id": role_id, "progress_id": progress_id})
	return result


static func build_choice_offer(owner, choice: Dictionary = {}) -> Dictionary:
	if choice.is_empty():
		return build_next_offer(owner)
	return _build_offer_for_choice(owner, choice)


static func get_next_pending(owner) -> Dictionary:
	for role_id in _get_team_role_ids(owner):
		for progress_id in ROLE_PROGRESS_ORDER.get(role_id, []):
			if get_skill_progress_level(owner, role_id, progress_id) < TRIGGER_LEVEL:
				continue
			if get_selected_talent(owner, role_id, progress_id) != "":
				continue
			return {"role_id": role_id, "progress_id": progress_id}
	return {}


static func has_pending(owner) -> bool:
	return not get_next_pending(owner).is_empty()


static func build_next_offer(owner) -> Dictionary:
	return _build_offer_for_choice(owner, get_next_pending(owner))


static func _build_offer_for_choice(owner, pending: Dictionary) -> Dictionary:
	if pending.is_empty():
		return {}
	var role_id := str(pending.get("role_id", ""))
	var progress_id := str(pending.get("progress_id", ""))
	if get_skill_progress_level(owner, role_id, progress_id) < TRIGGER_LEVEL or get_selected_talent(owner, role_id, progress_id) != "":
		return {}
	var options: Array = []
	for definition_value in TALENT_DEFINITIONS.get(progress_id, []):
		var definition: Dictionary = (definition_value as Dictionary).duplicate(true)
		var talent_id := str(definition.get("id", ""))
		var description := str(definition.get("description", ""))
		var talent_title := str(definition.get("title", talent_id))
		options.append({
			"id": OPTION_PREFIX + talent_id,
			"offer_key": talent_id,
			"option_category": CATEGORY_SKILL_TALENT,
			"slot": "skill_talent",
			"slot_label": "技能质变",
			"role_id": role_id,
			"skill_progress_id": progress_id,
			"talent_id": talent_id,
			"title": "%s·%s" % [str(PROGRESS_TITLES.get(progress_id, progress_id)), talent_title],
			"summary": description,
			"short_description": description,
			"description": description,
			"preview_description": description,
			"detail_description": description,
			"exact_description": description,
			"hide_card_title": true,
			"blessing_tier": 1
		})
	return {
		"options": options,
		"context": {
			"offer_mode": CATEGORY_SKILL_TALENT,
			"skill_talent_offer": true,
			"role_build_offer": false,
			"selection_count": 1,
			"refresh_limit": 0,
			"refresh_remaining": 0,
			"refresh_unlimited": false,
			"refresh_button_label": "",
			"role_id": role_id,
			"skill_progress_id": progress_id,
			"summary": "%s达到构筑 Lv.%d：选择一项技能质变（另一项本局不可选）。" % [str(PROGRESS_TITLES.get(progress_id, progress_id)), TRIGGER_LEVEL]
		}
	}


static func apply_option_with_result(owner, option_id: String, current_offer: Dictionary) -> Dictionary:
	if owner == null or not is_talent_option_id(option_id):
		return {}
	var context: Dictionary = current_offer.get("context", {}) if current_offer.get("context", {}) is Dictionary else {}
	if not bool(context.get("skill_talent_offer", false)):
		return {}
	var talent_id := option_id.trim_prefix(OPTION_PREFIX)
	var progress_id := str(context.get("skill_progress_id", ""))
	var role_id := str(context.get("role_id", ""))
	var offered := false
	for option_value in current_offer.get("options", []):
		if option_value is Dictionary and str((option_value as Dictionary).get("id", "")) == option_id:
			offered = str((option_value as Dictionary).get("skill_progress_id", "")) == progress_id
			break
	if not offered or get_skill_progress_level(owner, role_id, progress_id) < TRIGGER_LEVEL:
		return {}
	var valid := false
	for definition_value in TALENT_DEFINITIONS.get(progress_id, []):
		if str((definition_value as Dictionary).get("id", "")) == talent_id:
			valid = true
			break
	if not valid or get_selected_talent(owner, role_id, progress_id) != "":
		return {}
	var states: Dictionary = owner.get("role_special_states") if owner.get("role_special_states") is Dictionary else {}
	var role_state: Dictionary = states.get(role_id, {}) if states.get(role_id, {}) is Dictionary else {}
	var talents: Dictionary = role_state.get(TALENTS_KEY, {}) if role_state.get(TALENTS_KEY, {}) is Dictionary else {}
	talents[progress_id] = talent_id
	role_state[TALENTS_KEY] = talents
	states[role_id] = role_state
	owner.set("role_special_states", states)
	return {"type": CATEGORY_SKILL_TALENT, "role_id": role_id, "skill_progress_id": progress_id, "talent_id": talent_id}


static func apply_choice(owner, option_id: String, expected_progress_id: String = "") -> bool:
	var offer: Dictionary = owner.get("current_blessing_offer") if owner != null and owner.get("current_blessing_offer") is Dictionary else {}
	var context: Dictionary = offer.get("context", {}) if offer.get("context", {}) is Dictionary else {}
	if expected_progress_id != "" and str(context.get("skill_progress_id", "")) != expected_progress_id:
		return false
	return not apply_option_with_result(owner, option_id, offer).is_empty()


static func get_selected_talent(owner, role_id: String, progress_id: String) -> String:
	if owner == null:
		return ""
	var states: Variant = owner.get("role_special_states")
	if states is not Dictionary:
		return ""
	var role_state: Variant = (states as Dictionary).get(role_id, {})
	if role_state is not Dictionary:
		return ""
	var talents: Variant = (role_state as Dictionary).get(TALENTS_KEY, {})
	return str((talents as Dictionary).get(progress_id, "")) if talents is Dictionary else ""


static func has_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	for role_id in _get_team_role_ids(owner):
		var states: Variant = owner.get("role_special_states")
		if states is not Dictionary:
			return false
		var role_state: Variant = (states as Dictionary).get(role_id, {})
		if role_state is not Dictionary:
			continue
		var talents: Variant = (role_state as Dictionary).get(TALENTS_KEY, {})
		if talents is Dictionary and (talents as Dictionary).values().has(talent_id):
			return true
	return false


static func get_progress_text(owner, role_id: String) -> String:
	var lines: Array[String] = []
	for progress_id in ROLE_PROGRESS_ORDER.get(role_id, []):
		var level: int = get_skill_progress_level(owner, role_id, progress_id)
		var selected_id: String = get_selected_talent(owner, role_id, progress_id)
		var status := "未解锁" if level <= 0 else ("Lv.%d" % level)
		if selected_id != "":
			status += " · %s" % _get_talent_title(progress_id, selected_id)
		elif level >= TRIGGER_LEVEL:
			status += " · 待选择质变"
		else:
			status += " · Lv.%d触发质变" % TRIGGER_LEVEL
		lines.append("%s  %s" % [str(PROGRESS_TITLES.get(progress_id, progress_id)), status])
	return "\n".join(lines)


static func _get_talent_title(progress_id: String, talent_id: String) -> String:
	return str(get_talent_definition(progress_id, talent_id).get("title", talent_id))


static func _get_team_role_ids(owner) -> Array:
	var result: Array = []
	if owner != null and owner.get("roles") is Array:
		for role_value in owner.get("roles"):
			if role_value is Dictionary:
				var role_id := str((role_value as Dictionary).get("id", ""))
				if role_id != "" and not result.has(role_id):
					result.append(role_id)
	return result

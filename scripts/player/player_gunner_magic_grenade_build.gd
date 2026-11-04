extends RefCounted

const PROGRESS := "gunner_magic_grenade"
const STATE_KEY := "gunner_magic_grenade_build"
const STAGES := [4, 8, 9]
const OPTIONS := {
	4: [
		{"key": "magic_chase", "title": "魔法追弹", "description": "每枚魔法榴弹伤害倍率降低 100 个百分点；每次释放额外发射 3 枚魔法榴弹。"},
		{"key": "lucky_round", "title": "幸运之弹", "description": "魔法榴弹额外暴击率提高 20 个百分点；只有暴击爆炸的半径增加 50，普通爆炸半径保持 75。"}
	],
	8: [
		{"key": "mental_shock", "title": "精神震荡", "description": "每枚魔法榴弹命中施加 1 层精神震荡；每层使目标受到的伤害增加 3%。拥有 5 层的目标死亡时，使半径 75 内敌人眩晕 2 秒。"},
		{"key": "chain_blast", "title": "连爆", "description": "每枚魔法榴弹的暴击分别计数；累计 8 次暴击后，免费释放 1 枚魔法榴弹。"}
	],
	9: [
		{"key": "magic_assistant", "title": "魔弹助手", "description": "普通攻击每次暴击时，额外发射 1 枚魔法榴弹。"},
		{"key": "magic_charge", "title": "魔法充能", "description": "枪手每获得 1 点大招能量，魔法榴弹暴击率提高 0.25%，暴击伤害提高 0.7%。"}
	]
}

static func state(owner) -> Dictionary:
	if owner == null or owner.get("role_special_states") is not Dictionary:
		return {}
	var value: Variant = owner.role_special_states.get("gunner", {})
	return value if value is Dictionary else {}

static func level_from_state(role_state: Dictionary) -> int:
	var levels: Variant = role_state.get("skill_levels", {})
	var stored := int((levels as Dictionary).get(PROGRESS, 0)) if levels is Dictionary else 0
	return clampi(stored if role_state.has(STATE_KEY) else maxi(0, stored - 1), 0, 9)

static func level(owner) -> int:
	return level_from_state(state(owner))

static func choices(owner) -> Dictionary:
	var value: Variant = state(owner).get(STATE_KEY, {})
	return value if value is Dictionary else {}

static func has_choice(owner, key: String) -> bool:
	for stage in STAGES:
		if level(owner) >= stage and str(choices(owner).get(str(stage), "")) == key:
			return true
	return false

static func pending_stage(owner) -> int:
	for stage in STAGES:
		if level(owner) >= stage and not choices(owner).has(str(stage)):
			return stage
	return 0

static func choose(owner, stage: int, slot: int) -> bool:
	if owner == null or stage != pending_stage(owner) or slot < 1 or slot > 2:
		return false
	var role_state := state(owner)
	var selected := choices(owner).duplicate()
	selected[str(stage)] = OPTIONS[stage][slot - 1]["key"]
	role_state[STATE_KEY] = selected
	owner.role_special_states["gunner"] = role_state
	return true

static func refresh_speed(_owner) -> void:
	pass

static func damage_ratio(owner) -> float:
	var lv := level(owner)
	return 2.0 + mini(lv, 3) * 0.25 + clampi(lv - 4, 0, 3) * 0.50 + (-1.0 if has_choice(owner, "magic_chase") else 0.0)

static func next_preview(owner) -> String:
	match level(owner) + 1:
		1, 2, 3: return "每枚伤害 +25%"
		4: return "选择魔法追弹或幸运之弹"
		5, 7: return "每枚伤害 +50%"
		6: return "每枚伤害 +50%；魔法榴弹数量 +1"
		8: return "选择精神震荡或连爆，保留之前的强化"
		9: return "选择魔弹助手或魔法充能，保留之前的强化"
	return ""

static func description(owner) -> String:
	var lv := level(owner)
	var count := 3 + (3 if has_choice(owner, "magic_chase") else 0) + (1 if lv >= 6 else 0)
	var lines := PackedStringArray([
		"魔法榴弹 LV%d / 9" % lv,
		"每枚伤害 %.0f%%；数量 %d；基础爆炸半径 75；额外暴击率 20%%。" % [damage_ratio(owner) * 100.0, count]
	])
	for stage in STAGES:
		var selected := str(choices(owner).get(str(stage), ""))
		for option in OPTIONS[stage]:
			if selected == str(option["key"]):
				lines.append("LV%d：%s；%s" % [stage, option["title"], option["description"]])
	if lv < 9:
		lines.append("下一等级：" + next_preview(owner))
	return "\n".join(lines)

extends RefCounted

const PROGRESS := "swordsman_crescent_wave"
const STATE_KEY := "crescent_wave_build"
const STAGES := [4, 8, 9]
const OPTIONS := {
	4: [
		{"key": "lian_yue", "title": "连月", "description": "剑气数量 +2；冷却时间 +1秒。"},
		{"key": "feng_yue", "title": "风月", "description": "剑气伤害 +50%；飞行速度 +175；飞行距离 +200；冷却时间 -1秒。"}
	],
	8: [
		{"key": "blood_moon", "title": "血月", "description": "剑气命中时，按普通攻击当前战意触发概率的 1/2 尝试触发战意回复；受战意冷却限制。"},
		{"key": "red_moon", "title": "红月", "description": "每释放 3 次月牙剑气，额外释放 1 道红月剑气；红月剑气飞行速度 +200，并额外增加 1 道剑气。"}
	],
	9: [
		{"key": "echo", "title": "残响", "description": "普通攻击有 30% 概率额外释放月牙剑气；额外释放不计入月牙剑气冷却，但计入红月计数。"},
		{"key": "whirlwind", "title": "风卷残云", "description": "释放月牙剑气时，有 30% 概率追加 1 道、10% 概率追加 3 道、5% 概率追加 5 道剑气。"}
	]
}

static func state(owner) -> Dictionary:
	if owner == null or owner.get("role_special_states") is not Dictionary:
		return {}
	var role_state: Variant = owner.role_special_states.get("swordsman", {})
	return role_state if role_state is Dictionary else {}

static func level_from_state(role_state: Dictionary) -> int:
	var stored: int = int(role_state.get("skill_levels", {}).get(PROGRESS, 0))
	return clampi(stored if role_state.has(STATE_KEY) else maxi(0, stored - 1), 0, 9)

static func level(owner) -> int:
	return level_from_state(state(owner))

static func choices(owner) -> Dictionary:
	var selected: Variant = state(owner).get(STATE_KEY, {})
	return selected if selected is Dictionary else {}

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
	if stage != pending_stage(owner) or slot < 1 or slot > 2:
		return false
	var role_state: Dictionary = state(owner)
	var selected: Dictionary = (choices(owner).duplicate() as Dictionary)
	selected[str(stage)] = OPTIONS[stage][slot - 1]["key"]
	role_state[STATE_KEY] = selected
	owner.role_special_states["swordsman"] = role_state
	return true

static func refresh_speed(_owner) -> void:
	pass

static func damage_ratio(owner) -> float:
	var lv: int = level(owner)
	var ratio: float = 1.5 + mini(lv, 3) * 0.20
	if lv >= 5:
		ratio += 0.40
	if lv >= 6:
		ratio += 0.40
	if lv >= 7:
		ratio += 0.40
	if has_choice(owner, "feng_yue"):
		ratio += 0.50
	return ratio

static func sword_count_bonus(owner) -> int:
	var bonus: int = 1 if level(owner) >= 6 else 0
	if has_choice(owner, "lian_yue"):
		bonus += 2
	return bonus

static func cooldown_bonus(owner) -> float:
	if has_choice(owner, "lian_yue"):
		return 1.0
	if has_choice(owner, "feng_yue"):
		return -1.0
	return 0.0

static func speed_bonus(owner) -> float:
	return 175.0 if has_choice(owner, "feng_yue") else 0.0

static func range_bonus(owner) -> float:
	return 200.0 if has_choice(owner, "feng_yue") else 0.0

static func next_preview(owner) -> String:
	match level(owner) + 1:
		1, 2, 3: return "剑气伤害 +20%"
		4: return "选择连月或风月"
		5: return "剑气伤害 +40%"
		6: return "剑气伤害 +40%；剑气数量 +1"
		7: return "剑气伤害 +40%"
		8: return "选择血月或红月，保留 LV4 强化"
		9: return "终极强化：选择残响或风卷残云，保留之前强化"
	return ""

static func description(owner) -> String:
	var text: String = "月牙剑气 LV%d / 9；当前剑气伤害 %.0f%%；剑气数量 %d；冷却 %.1f 秒。" % [
		level(owner), damage_ratio(owner) * 100.0, 1 + sword_count_bonus(owner), 6.0 + cooldown_bonus(owner)
	]
	for stage in STAGES:
		for option in OPTIONS[stage]:
			if has_choice(owner, option["key"]):
				text += "\n%s：%s" % [option["title"], option["description"]]
	if level(owner) < 9:
		text += "\n下一级：" + next_preview(owner)
	return text

extends RefCounted

const PROGRESS := "mage_meta_field"
const STATE_KEY := "mage_meta_field_build"
const STAGES := [4, 8, 9]
const BASE_RADIUS := 75.0
const EARLY_RADIUS_PER_LEVEL := 15.0
const LATE_RADIUS_PER_LEVEL := 25.0
const BASE_SLOW := 0.25
const BASE_ARMOR := 25.0
const LEVEL_SIX_ARMOR := 25.0

const OPTIONS := {
	4: [
		{"key": "space_lock", "title": "空间锁", "description": "怪物在领域内持续超过 2 秒后，领域减速效果翻倍，并开始每秒流失自身最大生命值 3% 的伤害；对 Boss 和小 Boss 造成三分之一效果。"},
		{"key": "barrier", "title": "屏障", "description": "领域同时使范围内敌方飞行道具减速 30%。"}
	],
	8: [
		{"key": "domain_remnant", "title": "领域残阵", "description": "法师切换下场后，领域在原地继续存在 8 秒。"},
		{"key": "magic_pressure", "title": "魔法灵压", "description": "领域内敌方单位护甲降低 20 点，并获得 10% 易伤。"}
	],
	9: [
		{"key": "soul_shackle", "title": "灵魂枷锁", "description": "领域每对单位减速 3 次，使其移速变为 1，持续 2 秒。"},
		{"key": "soul_extraction", "title": "灵魂抽离", "description": "领域内阵亡单位为法师提供额外大招能量；额外能量可超过 100%，释放大招时按额外能量比例提高大招伤害。"}
	]
}

static func state(owner) -> Dictionary:
	if owner == null or owner.get("role_special_states") is not Dictionary:
		return {}
	var value: Variant = owner.role_special_states.get("mage", {})
	return value if value is Dictionary else {}

static func level_from_state(role_state: Dictionary) -> int:
	var levels: Variant = role_state.get("skill_levels", {})
	var stored := int((levels as Dictionary).get(PROGRESS, 0)) if levels is Dictionary else 0
	if not role_state.has(STATE_KEY):
		stored = maxi(0, stored - 1)
	return clampi(stored, 0, 9)

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
	owner.role_special_states["mage"] = role_state
	return true

static func refresh_speed(_owner) -> void:
	pass

static func radius_bonus(owner) -> float:
	var lv := level(owner)
	var bonus := float(mini(lv - 1, 2)) * EARLY_RADIUS_PER_LEVEL
	if lv >= 5:
		bonus += float(mini(lv - 4, 3)) * LATE_RADIUS_PER_LEVEL
	return maxf(0.0, bonus)

static func armor_bonus(owner) -> float:
	return LEVEL_SIX_ARMOR if level(owner) >= 6 else 0.0

static func slow_multiplier(owner) -> float:
	var lv := level(owner)
	var slow_bonus := float(mini(maxi(lv - 1, 0), 2)) * 0.015
	if lv >= 5:
		slow_bonus += float(mini(lv - 4, 3)) * 0.03
	return 1.0 - clampf(BASE_SLOW + slow_bonus, 0.0, 0.95)

static func next_preview(owner) -> String:
	match level(owner) + 1:
		1, 2, 3: return "领域半径 +15"
		4: return "选择空间锁或屏障"
		5, 7: return "领域半径 +25"
		6: return "领域半径 +25；护甲 +25"
		8: return "选择领域残阵或魔法灵压"
		9: return "终极强化：选择灵魂枷锁或灵魂抽离"
	return ""

static func description(owner) -> String:
	var lv := level(owner)
	var lines := PackedStringArray([
		"梅塔领域 LV%d / 9" % lv,
		"领域半径 %.0f；减速 %.0f%%；法师护甲 +%.0f" % [BASE_RADIUS + radius_bonus(owner), (1.0 - slow_multiplier(owner)) * 100.0, BASE_ARMOR + armor_bonus(owner)]
	])
	for stage in STAGES:
		var selected := str(choices(owner).get(str(stage), ""))
		for option in OPTIONS[stage]:
			if selected == str(option["key"]):
				lines.append("LV%d · %s：%s" % [stage, option["title"], option["description"]])
	if lv < 9:
		lines.append("下一级：" + next_preview(owner))
	return "\n".join(lines)

static func add_soul_extraction_energy(owner, amount: float) -> void:
	if owner == null or amount <= 0.0 or not has_choice(owner, "soul_extraction"):
		return
	var role_state := state(owner)
	role_state["meta_field_extra_energy"] = maxf(0.0, float(role_state.get("meta_field_extra_energy", 0.0))) + amount
	owner.role_special_states["mage"] = role_state

static func get_soul_extraction_energy(owner) -> float:
	return maxf(0.0, float(state(owner).get("meta_field_extra_energy", 0.0)))

static func consume_soul_extraction_energy(owner) -> float:
	var value := get_soul_extraction_energy(owner)
	if value <= 0.0:
		return 0.0
	var role_state := state(owner)
	role_state["meta_field_extra_energy"] = 0.0
	owner.role_special_states["mage"] = role_state
	return value

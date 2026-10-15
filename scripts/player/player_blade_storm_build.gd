extends RefCounted

const PROGRESS := "swordsman_blade_storm"
const STATE_KEY := "blade_storm_build"
const STAGES := [4, 8, 9]
const OPTIONS := {
	4: [
		{"key": "typhoon", "title": "台风", "description": "每跳伤害倍率 +10 个百分点；以风暴为中心，牵引半径220内的敌人，牵引速度60。"},
		{"key": "gale", "title": "狂风", "description": "风暴半径 +50；半径300内敌人减速30%；随身风暴期间自身移速 +15%、闪避率 +30%、护甲 +30。"}
	],
	8: [
		{"key": "rend", "title": "烈风", "description": "每跳伤害倍率 +15 个百分点；造成伤害时削减2点护甲，每层独立持续15秒，无叠加上限。"},
		{"key": "breath", "title": "风息", "description": "随身风暴结束时获得风息，持续15秒，切换角色继承：移速 +10%、闪避率 +25%、冷却缩减 +20%、基础攻速 +0.3。"}
	],
	9: [
		{"key": "tornado", "title": "龙卷", "description": "随身风暴结束后沿脱离瞬间的瞄准方向以150速度移动，额外持续与随身阶段相同的时长；剑士恢复普通攻击。"},
		{"key": "windblade", "title": "风刃", "description": "风暴伤害视为普通攻击，可触发攻击特效与被动；概率触发效果的概率翻倍。"}
	]
}

static func state(owner) -> Dictionary:
	if owner == null or owner.get("role_special_states") is not Dictionary:
		return {}
	var role_state: Variant = owner.role_special_states.get("swordsman", {})
	return role_state if role_state is Dictionary else {}

static func level_from_state(value: Dictionary) -> int:
	var stored: int = int(value.get("skill_levels", {}).get(PROGRESS, 0))
	return clampi(stored if value.has(STATE_KEY) else maxi(0, stored - 1), 0, 9)

static func level(owner) -> int:
	return level_from_state(state(owner))

static func choices(owner) -> Dictionary:
	return state(owner).get(STATE_KEY, {})

static func has_choice(owner, key: String) -> bool:
	for stage in STAGES:
		if level(owner) >= stage and choices(owner).get(str(stage), "") == key:
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
	var value := state(owner)
	var selected := choices(owner).duplicate()
	selected[str(stage)] = OPTIONS[stage][slot - 1]["key"]
	value[STATE_KEY] = selected
	owner.role_special_states["swordsman"] = value
	return true

static func refresh_speed(_owner) -> void:
	pass

static func damage_ratio(owner) -> float:
	return 0.8 + mini(level(owner), 3) * 0.03 + clampi(level(owner) - 4, 0, 3) * 0.06 + (0.1 if has_choice(owner, "typhoon") else 0.0) + (0.15 if has_choice(owner, "rend") else 0.0)

static func duration(owner) -> float:
	return 3.6 if level(owner) >= 6 else 2.7

static func radius(owner) -> float:
	return 200.0 if has_choice(owner, "gale") else 150.0

static func next_preview(owner) -> String:
	match level(owner) + 1:
		1, 2, 3: return "每跳伤害倍率 +3 个百分点"
		4: return "选择台风或狂风"
		5, 7: return "每跳伤害倍率 +6 个百分点"
		6: return "每跳伤害倍率 +6 个百分点；持续时间 +0.9 秒"
		8: return "选择烈风或风息，保留LV4强化"
		9: return "终极强化：龙卷或风刃，保留之前强化"
	return ""

static func description(owner) -> String:
	var text := "剑刃风暴 LV%d / 9；半径%.0f，每0.3秒造成%.0f%%攻击力伤害，持续%.1f秒，基础冷却32秒；随身风暴期间不能普通攻击。" % [level(owner), radius(owner), damage_ratio(owner) * 100.0, duration(owner)]
	for stage in STAGES:
		for option in OPTIONS[stage]:
			if has_choice(owner, option["key"]):
				text += "\n%s：%s" % [option["title"], option["description"]]
	if level(owner) < 9:
		text += "\n下一级：" + next_preview(owner)
	return text

# Shared buff lives on the ability, so switching the active role does not remove it.
static func bonus(owner, role_id: String, stat: String) -> float:
	var ability: Variant = owner.get("swordsman_blade_storm_ability") if owner != null else null
	if ability == null or not ability.has_method("get_stat_bonus"):
		return 0.0
	return float(ability.get_stat_bonus(owner, role_id, stat))

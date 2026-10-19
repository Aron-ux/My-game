extends RefCounted

const PROGRESS := "gunner_infinite_reload"
const STATE_KEY := "infinite_reload_build"
const STAGES := [4, 8, 9]
const OPTIONS := {
	4: [
		{"key": "light_step", "title": "轻盈步伐", "description": "射程+100；释放期间闪避率+30个百分点、移速+10%。"},
		{"key": "aim", "title": "瞄准", "description": "伤害倍率+10个百分点；以每秒150°的角速度跟随鼠标转向。"}
	],
	8: [
		{"key": "soul_form", "title": "灵魂形态", "description": "释放期间免疫怪物碰撞和普通攻击子弹；无限装填每击杀一个单位，减少本次冷却0.3秒。"},
		{"key": "soul_impact", "title": "灵魂冲击", "description": "每次命中追加目标当前生命值1%的伤害；跳过护甲与减伤，保留易伤，遵守无敌与转阶段保护，对Boss生效。"}
	],
	9: [
		{"key": "fire_control", "title": "火力调控", "description": "变为无冷却的开关技能，开启至少1秒后可关闭；关闭后可立即重新开启，只有瞄准分支允许转向。"},
		{"key": "dual_impact", "title": "双发冲击", "description": "射程+100，伤害倍率+10个百分点，攻击间隔变为0.2秒；增加一条全额伤害的平行轨道，重叠目标分别承受两次命中。"}
	]
}

static func state(owner) -> Dictionary:
	if owner == null or owner.get("role_special_states") is not Dictionary:
		return {}
	var value: Variant = owner.role_special_states.get("gunner", {})
	return value if value is Dictionary else {}

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
	owner.role_special_states["gunner"] = value
	return true

static func refresh_speed(_owner) -> void:
	pass

static func damage_ratio(owner) -> float:
	return 0.4 + mini(level(owner), 3) * 0.05 + clampi(level(owner) - 4, 0, 3) * 0.1 + (0.1 if has_choice(owner, "aim") else 0.0) + (0.1 if has_choice(owner, "dual_impact") else 0.0)

static func range_bonus(owner) -> float:
	return (100.0 if has_choice(owner, "light_step") else 0.0) + (100.0 if level(owner) >= 6 else 0.0) + (100.0 if has_choice(owner, "dual_impact") else 0.0)

static func next_preview(owner) -> String:
	match level(owner) + 1:
		1, 2, 3: return "伤害倍率+5个百分点"
		4: return "选择轻盈步伐或瞄准"
		5, 7: return "伤害倍率+10个百分点"
		6: return "伤害倍率+10个百分点；射程+100"
		8: return "选择灵魂形态或灵魂冲击，保留LV4强化"
		9: return "终极强化：火力调控或双发冲击，保留之前强化"
	return ""

static func description(owner) -> String:
	var text := "无限装填 LV%d / 9；射程%.0f，每%.2f秒造成%.0f%%攻击力的贯穿伤害；持续4秒，基础冷却36秒，结束后开始冷却。默认锁定出手方向，释放期间不能普通攻击。" % [level(owner), 400.0 + range_bonus(owner), 0.2 if has_choice(owner, "dual_impact") else 0.25, damage_ratio(owner) * 100.0]
	for stage in STAGES:
		for option in OPTIONS[stage]:
			if has_choice(owner, option["key"]):
				text += "\n%s：%s" % [option["title"], option["description"]]
	if level(owner) < 9:
		text += "\n下一级：" + next_preview(owner)
	return text

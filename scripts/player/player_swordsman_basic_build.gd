extends RefCounted

const PROGRESS := "swordsman_basic"
const STATE_KEY := "swordsman_basic_build"
const STAGES := [4, 8, 9]
const OPTIONS := {
	4: [
		{"key": "heavy", "title": "重剑", "description": "攻击速度 -50%；普攻范围 +200%；伤害倍率 +65 个百分点；有连击效果时，连击间隔变为0.5秒；命中时引起屏幕震动。"},
		{"key": "light", "title": "轻剑", "description": "攻击速度 +30%；伤害倍率 -25 个百分点。"}
	],
	8: [
		{"key": "split", "title": "分裂", "description": "每刀命中后，选最近的命中目标，沿斩击方向向其身后产生一次 150°、半径 200 的扇形伤害，造成当前普攻倍率的 50%；忽略护甲，计算减伤。"},
		{"key": "ground", "title": "地裂", "description": "命中后在主目标脚下生成半径 175 的圆形裂地，1.5 秒后爆炸造成当前普攻倍率的 300% 伤害；每刀一次，不能与尚未爆炸的裂地重叠。"}
	],
	9: [
		{"key": "guard", "title": "守势", "description": "斩击范围内的敌方弹道按入射角反弹，伤害为原弹道的 200%，命中第一个敌人后消失；包含 Boss 弹幕、分裂弹，不包含激光和地面攻击。"},
		{"key": "brave", "title": "勇猛", "description": "普通攻击暴击率 +30%、暴击伤害 +50%、伤害倍率 +30 个百分点；普通攻击命中的敌人沿本次攻击指向方向击退50。分裂与地裂不享受额外暴击属性。"}
	]
}

static func state(owner) -> Dictionary:
	if owner == null or owner.get("role_special_states") is not Dictionary:
		return {}
	var role_state: Variant = owner.role_special_states.get("swordsman", {})
	return role_state if role_state is Dictionary else {}

static func level(owner) -> int:
	return level_from_state(state(owner))

static func level_from_state(role_state: Dictionary) -> int:
	var levels: Dictionary = role_state.get("skill_levels", {})
	var stored: int = int(levels.get(PROGRESS, 0))
	# Old levels started at one. Preserve the number of purchased upgrades.
	if not role_state.has(STATE_KEY):
		stored = maxi(0, stored - 1)
	return clampi(stored, 0, 9)

static func choices(owner) -> Dictionary:
	return state(owner).get(STATE_KEY, {})

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
	var role_state := state(owner)
	var selected := choices(owner).duplicate()
	selected[str(stage)] = OPTIONS[stage][slot - 1]["key"]
	role_state[STATE_KEY] = selected
	owner.role_special_states["swordsman"] = role_state
	refresh_speed(owner)
	return true

static func refresh_speed(owner) -> void:
	if owner != null and owner.has_method("_update_fire_timer"):
		owner._update_fire_timer()

static func damage_ratio(owner) -> float:
	var lv := level(owner)
	var ratio: float = 1.0 + mini(lv, 3) * 0.1 + clampi(lv - 4, 0, 3) * 0.2
	if has_choice(owner, "heavy"):
		ratio += 0.65
	if has_choice(owner, "light"):
		ratio -= 0.25
	if has_choice(owner, "brave"):
		ratio += 0.3
	return ratio

static func speed_bonus(owner) -> float:
	return -0.5 if has_choice(owner, "heavy") else 0.3 if has_choice(owner, "light") else 0.0

static func range_multiplier(owner) -> float:
	return 1.0

static func slash_length(owner) -> float:
	if has_choice(owner, "heavy"):
		return 200.0
	if has_choice(owner, "light"):
		return 60.0
	return 80.0

static func slash_width(owner) -> float:
	return 45.0 if has_choice(owner, "heavy") else 20.0

static func combo_interval(owner) -> float:
	return 0.5 if has_choice(owner, "heavy") else 0.14

static func critical_bonus(owner, source: String) -> float:
	return 0.3 if source.begins_with("swordsman_basic:") and has_choice(owner, "brave") else 0.0

static func critical_damage_bonus(owner, source: String) -> float:
	return 0.5 if source.begins_with("swordsman_basic:") and has_choice(owner, "brave") else 0.0

static func next_preview(owner) -> String:
	var next := level(owner) + 1
	match next:
		1, 2, 3: return "伤害倍率 +10 个百分点"
		4: return "选择重剑或轻剑"
		5, 7: return "伤害倍率 +20 个百分点"
		6: return "伤害倍率 +20 个百分点；0.25 秒后从角色当前位置追加一次完整普攻，可触发全部普攻效果"
		8: return "选择分裂或地裂，保留 LV4 强化"
		9: return "终极强化：选择守势或勇猛，保留之前的强化"
	return ""

static func description(owner) -> String:
	var lines := PackedStringArray(["普通攻击 LV%d / 9；当前伤害倍率 %.0f%%。" % [level(owner), damage_ratio(owner) * 100.0]])
	if level(owner) >= 6:
		lines.append("每次普通攻击 0.25 秒后，从角色当前位置追加一次完整斩击。")
	for stage in STAGES:
		var selected: String = str(choices(owner).get(str(stage), ""))
		for option in OPTIONS[stage]:
			if selected == option["key"]:
				lines.append("LV%d · %s：%s" % [stage, option["title"], option["description"]])
	if level(owner) < 9:
		lines.append("下一级：" + next_preview(owner))
	return "\n".join(lines)

extends RefCounted

const PROGRESS := "mage_basic"
const STATE_KEY := "mage_basic_build"
const STAGES := [4, 8, 9]
const OPTIONS := {
	4: [
		{"key": "storm", "title": "狂雷", "description": "基础攻击速度 -0.15 次/秒。首次落点连续三雷，间隔 0.2 秒、0.45 秒；范围 100%/130%/160%，伤害为当前倍率的 100%/65%/42.25%，震动逐次增强。三雷结束后开始普攻间隔。"},
		{"key": "charge", "title": "通电", "description": "命中叠加感电，每层护甲 -10，最多 3 层且不自然消失。满层后下一次受伤引爆，造成当前出场角色 300% 攻击力伤害并清空。"}
	],
	8: [
		{"key": "focus", "title": "聚雷", "description": "攻击速度 -50%，雷击范围 +50%，伤害倍率 +30 个百分点；当前大招能量比例的 1.2 倍转为攻击速度加成。"},
		{"key": "heaven", "title": "天雷", "description": "基础攻击速度 -0.1 次/秒。每道雷附加目标最大生命值 2% 的直接伤害，忽略护甲、减伤和护盾；对 Boss、狂雷三道及神绛雷均生效。"}
	],
	9: [
		{"key": "divine", "title": "神绛", "description": "每释放 3 道雷追加一道普通大小的黄色神绛雷，造成当前倍率 150% 的伤害，可触发通电、天雷和攻击特效；追加雷本身不计数。"},
		{"key": "quake", "title": "雷震", "description": "基础攻击速度 -0.15 次/秒。所有雷击伤害倍率 +100 个百分点，命中施加 0.5 秒眩晕；Boss 演出及收尾期间每轮仅延长下一次瘫痪一次，瘫痪和转阶段免控。"}
	]
}

static func state(owner) -> Dictionary:
	if owner == null or owner.get("role_special_states") is not Dictionary:
		return {}
	return owner.role_special_states.get("mage", {})

static func level_from_state(role_state: Dictionary) -> int:
	var stored: int = int(role_state.get("skill_levels", {}).get(PROGRESS, 0))
	if not role_state.has(STATE_KEY):
		stored = maxi(0, stored - 1)
	return clampi(stored, 0, 9)

static func level(owner) -> int:
	return level_from_state(state(owner))

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
	owner.role_special_states["mage"] = role_state
	refresh_speed(owner)
	return true

static func refresh_speed(owner) -> void:
	if owner != null and owner.has_method("_update_fire_timer"):
		owner._update_fire_timer()

static func damage_ratio(owner) -> float:
	var lv := level(owner)
	return 2.0 + mini(lv, 3) * 0.15 + clampi(lv - 4, 0, 3) * 0.25 + (0.3 if has_choice(owner, "focus") else 0.0)

static func strike_ratio(owner, scale: float = 1.0) -> float:
	return damage_ratio(owner) * scale + (1.0 if has_choice(owner, "quake") else 0.0)

static func range_multiplier(owner) -> float:
	return (1.3 if level(owner) >= 6 else 1.0) * (1.5 if has_choice(owner, "focus") else 1.0)

static func base_speed_modifier(owner) -> float:
	return -(0.15 if has_choice(owner, "storm") else 0.0) - (0.1 if has_choice(owner, "heaven") else 0.0) - (0.15 if has_choice(owner, "quake") else 0.0)

static func speed_bonus(owner) -> float:
	var level_penalty := -0.1 if level(owner) >= 6 else 0.0
	if not has_choice(owner, "focus"):
		return level_penalty
	var energy: float = owner._get_role_mana("mage") if owner.has_method("_get_role_mana") else 0.0
	var maximum: float = float(owner.get("max_mana")) if owner.get("max_mana") != null else 100.0
	return level_penalty - 0.5 + 1.2 * clampf(energy / maxf(1.0, maximum), 0.0, 1.0)

static func energy_bonus(owner, source: String) -> float:
	return 0.5 if source.begins_with("mage_basic:") and level(owner) >= 6 else 0.0

static func next_preview(owner) -> String:
	match level(owner) + 1:
		1, 2, 3: return "伤害倍率 +15 个百分点"
		4: return "选择狂雷或通电"
		5, 7: return "伤害倍率 +25 个百分点"
		6: return "伤害倍率 +25 个百分点；雷击范围 +30%；普攻大招能量获取 ×1.5；普通攻击速度 -10%"
		8: return "选择聚雷或天雷，保留 LV4 强化"
		9: return "终极强化：选择神绛或雷震，保留之前强化"
	return ""

static func description(owner) -> String:
	var lines := PackedStringArray(["普通攻击 LV%d / 9；首道雷伤害倍率 %.0f%%。" % [level(owner), strike_ratio(owner) * 100.0]])
	if level(owner) >= 6:
		lines.append("雷击范围 +30%，普攻大招能量获取 ×1.5，普通攻击速度 -10%。")
	for stage in STAGES:
		for option in OPTIONS[stage]:
			if str(choices(owner).get(str(stage), "")) == option["key"]:
				lines.append("LV%d · %s：%s" % [stage, option["title"], option["description"]])
	if level(owner) < 9:
		lines.append("下一级：" + next_preview(owner))
	return "\n".join(lines)


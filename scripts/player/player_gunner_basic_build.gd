extends RefCounted

const PROGRESS := "gunner_basic"
const STATE_KEY := "gunner_basic_build"
const STAGES := [4, 8, 9]
const OPTIONS := {
	4: [
		{"key": "rapid", "title": "连射", "description": "子弹数量 +1，间隔 0.25 秒发射；攻击速度 +15%，弹速 +10%。"},
		{"key": "sniper", "title": "狙击", "description": "伤害倍率 +25 个百分点；攻击距离 +150；攻击速度 -40%；子弹飞行速度 +100%。"}
	],
	8: [
		{"key": "split", "title": "爆裂", "description": "命中后向敌人身后分裂 3 颗子弹，各造成原子弹 80% 的伤害，弹速不变，射程为普攻的 60%；不触发攻击特效。连射的每颗子弹均可分裂。"},
		{"key": "shock", "title": "强震", "description": "每次命中有 30% 概率击退目标 25 距离，本次伤害倍率 +50 个百分点；Boss 同样可以被击退。"}
	],
	9: [
		{"key": "pierce", "title": "贯穿", "description": "每颗子弹生成时有 30% 概率贯穿沿途全部敌人，到达最大射程消失；同一目标只命中一次。选择爆裂时，仅分裂弹享受贯穿。"},
		{"key": "frenzy", "title": "狂猎", "description": "每发普通攻击子弹有 25% 概率使攻击速度 +80%，持续 3 秒；连射每颗分别判定，持续期间不能再次触发。分裂弹不触发。"}
	]
}

static func state(owner) -> Dictionary:
	if owner == null or owner.get("role_special_states") is not Dictionary:
		return {}
	var role_state: Variant = owner.role_special_states.get("gunner", {})
	return role_state if role_state is Dictionary else {}

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
	owner.role_special_states["gunner"] = role_state
	refresh_speed(owner)
	return true

static func refresh_speed(owner) -> void:
	if owner != null and owner.has_method("_update_fire_timer"):
		owner._update_fire_timer()

static func damage_ratio(owner) -> float:
	var lv := level(owner)
	return 1.5 + mini(lv, 3) * 0.2 + clampi(lv - 4, 0, 3) * 0.3 + (0.25 if has_choice(owner, "sniper") else 0.0)

static func range_bonus(owner) -> float:
	return (75.0 if level(owner) >= 6 else 0.0) + (150.0 if has_choice(owner, "sniper") else 0.0)

static func speed_bonus(owner) -> float:
	return (0.15 if has_choice(owner, "rapid") else -0.4 if has_choice(owner, "sniper") else 0.0) + (0.8 if has_choice(owner, "frenzy") and float(state(owner).get("gunner_frenzy_remaining", 0.0)) > 0.0 else 0.0)

static func on_shot(owner, roll: float = -1.0) -> bool:
	if not has_choice(owner, "frenzy") or float(state(owner).get("gunner_frenzy_remaining", 0.0)) > 0.0:
		return false
	if (randf() if roll < 0.0 else roll) >= 0.25:
		return false
	var role_state := state(owner)
	role_state["gunner_frenzy_remaining"] = 3.0
	owner.role_special_states["gunner"] = role_state
	refresh_speed(owner)
	return true

static func tick(owner, delta: float) -> void:
	var role_state := state(owner)
	var remaining := float(role_state.get("gunner_frenzy_remaining", 0.0))
	if remaining <= 0.0:
		return
	role_state["gunner_frenzy_remaining"] = maxf(0.0, remaining - delta)
	if remaining <= delta:
		refresh_speed(owner)

static func next_preview(owner) -> String:
	match level(owner) + 1:
		1, 2, 3: return "伤害倍率 +20 个百分点"
		4: return "选择连射或狙击"
		5, 7: return "伤害倍率 +30 个百分点"
		6: return "伤害倍率 +30 个百分点；攻击距离 +75"
		8: return "选择爆裂或强震，保留 LV4 强化"
		9: return "终极强化：选择贯穿或狂猎，保留之前的强化"
	return ""

static func description(owner) -> String:
	var lines := PackedStringArray(["普通攻击 LV%d / 9；当前伤害倍率 %.0f%%。" % [level(owner), damage_ratio(owner) * 100.0]])
	for stage in STAGES:
		for option in OPTIONS[stage]:
			if str(choices(owner).get(str(stage), "")) == option["key"]:
				lines.append("LV%d · %s：%s" % [stage, option["title"], option["description"]])
	if level(owner) < 9:
		lines.append("下一级：" + next_preview(owner))
	return "\n".join(lines)

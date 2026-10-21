extends RefCounted

const PROGRESS := "mage_surging_wave"
const STATE_KEY := "mage_surging_wave_build"
const STAGES := [4, 8, 9]
const OPTIONS := {
	4: [
		{"key": "flow", "title": "回流", "description": "冲击波结束后，按法师当时的朝向继续前进；速度与持续时间不变，回流伤害为当前倍率的60%。"},
		{"key": "flood", "title": "洪流", "description": "命中敌人后沿冲击波方向推动1.5秒，并减速40%、持续2秒。"}
	],
	8: [
		{"key": "water_path", "title": "水径", "description": "冲击波经过的路径在波消失后保留8秒；路径上的角色技能冷却速度提高20%，敌人每秒受到攻击力40%的伤害并减速50%、持续1.5秒。"},
		{"key": "clear_spring", "title": "清泉", "description": "持续时间增加2秒；经过角色时恢复其已损失生命的20%并驱散负面效果，之后每秒恢复当前生命的5%、持续3秒。"}
	],
	9: [
		{"key": "tidal", "title": "潮涌", "description": "冲击波视觉与命中宽度为80，释放3道、相邻夹角40°的冲击波，伤害增加50%。"},
		{"key": "stack", "title": "叠浪", "description": "命中施加潮湿4秒，重复命中刷新；对潮湿敌人造成伤害时恢复自身最大生命0.5%，敌人减速30%，每秒流失当前生命1%。"}
	]
}

static func state(owner) -> Dictionary:
	if owner == null or owner.get("role_special_states") is not Dictionary:
		return {}
	var value: Variant = owner.role_special_states.get("mage", {})
	return value if value is Dictionary else {}

static func level_from_state(role_state: Dictionary) -> int:
	var stored := int(role_state.get("skill_levels", {}).get(PROGRESS, 0))
	if not role_state.has(STATE_KEY):
		stored = maxi(0, stored - 1)
	return clampi(stored, 0, 9)

static func level(owner) -> int:
	return level_from_state(state(owner))

static func refresh_speed(_owner) -> void:
	pass

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

static func damage_ratio(owner) -> float:
	var lv := level(owner)
	var ratio := 3.0 + mini(lv, 3) * 0.30 + clampi(lv - 4, 0, 3) * 0.50
	return ratio + (0.50 if has_choice(owner, "tidal") else 0.0)

static func next_preview(owner) -> String:
	match level(owner) + 1:
		1, 2, 3: return "伤害倍率 +30%"
		4: return "选择回流或洪流"
		5, 7: return "伤害倍率 +50%"
		6: return "伤害倍率 +50%，持续时间 +1秒"
		8: return "选择水径或清泉"
		9: return "选择潮涌或叠浪"
	return ""

static func description(owner) -> String:
	var lines := PackedStringArray(["波涛汹涌 LV%d / 9；当前伤害倍率 %.0f%%" % [level(owner), damage_ratio(owner) * 100.0]])
	if level(owner) >= 6:
		lines.append("持续时间 +1秒")
	for stage in STAGES:
		var selected := str(choices(owner).get(str(stage), ""))
		for option in OPTIONS[stage]:
			if selected == str(option["key"]):
				lines.append("LV%d · %s：%s" % [stage, option["title"], option["description"]])
	if level(owner) < 9:
		lines.append("下一级：" + next_preview(owner))
	return "\n".join(lines)

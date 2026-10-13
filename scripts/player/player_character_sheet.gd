extends RefCounted

const STATS := preload("res://scripts/player/player_role_stat_flow.gd")
const COMBAT := preload("res://scripts/player/player_combat_modifiers.gd")
const EQUIPMENT := preload("res://scripts/player/player_equipment_flow.gd")
const STONES := preload("res://scripts/player/player_ruan_stone_stat_flow.gd")
const BLESSINGS := preload("res://scripts/player/player_blessing_system.gd")

# Values and optional traces use the combat getters; opening the sheet never switches roles.
static func get_stats(owner, role: Dictionary) -> Array[Dictionary]:
	var id := str(role.id)
	var bonus: Dictionary = owner._get_role_equipment_bonus_summary(id)
	var rows: Array[Dictionary] = []
	var sources: Array = []
	var value := STATS.get_role_damage(owner, id, sources)
	rows.append(_row("attack", "攻击力", "输出", value, "%.1f" % value, sources,
		"已包含下列增伤。实际命中还需计算技能倍率、暴击和目标防御。"))
	sources = []
	value = STATS.get_effective_attack_speed(owner, id, sources)
	rows.append(_row("attack_speed", "普通攻速", "输出", value, "%.2f 次/秒" % value, sources,
		"当前攻击间隔 %.2f 秒。攻速加成直接增加每秒攻击次数；减速效果另算。" % (1.0 / maxf(0.01, value))))
	value = STATS.get_role_base_attack_speed(owner, id)
	rows.append(_row("base_attack_speed", "基础攻击速度", "输出", value, "%.2f 次/秒" % value,
		[_source("角色基础", float(role.get("base_attack_speed", 1.0)), "="), _source("构筑与风息", value - float(role.get("base_attack_speed", 1.0)))], "基础攻速包含当前构筑与风息修正。"))
	var damage_sources: Array = []
	STATS.get_role_damage(owner, id, damage_sources)
	var damage_multiplier := 1.0
	for source in damage_sources:
		if str(source.op) == "*":
			damage_multiplier *= float(source.value)
	value = damage_multiplier - 1.0
	rows.append(_row("damage_bonus", "增伤", "输出", value, _percent(value),
		[_source("当前增伤合计", value, "=")], "已计入攻击力显示；技能倍率和暴击另算。", true))
	sources = [_source("角色基础", owner._get_role_base_critical_chance(id), "=")]
	sources.append(_source("祝福", owner._get_role_blessing_stat_bonus(id, "critical_chance")))
	sources.append(_source("共享阮石", STONES.get_critical_chance_bonus(owner)))
	if id == "swordsman":
		sources.append(_source("无敌斩永久暴击", owner.swordsman_ultimate_crit_bonus_chance))
	value = owner._get_role_critical_chance(id)
	rows.append(_row("crit", "暴击率", "输出", value, _percent(value), sources,
		"暴击率上限 100%；溢出部分按战斗规则转化为暴击伤害。", true))
	sources = [_source("基础暴击伤害", owner.BASE_CRITICAL_DAMAGE_MULTIPLIER, "=")]
	sources.append(_source("暴击率溢出", owner._get_role_critical_overflow_chance(id) * owner.CRITICAL_OVERFLOW_DAMAGE_RATIO))
	sources.append(_source("祝福", owner._get_role_blessing_stat_bonus(id, "critical_damage_bonus")))
	value = owner._get_critical_damage_multiplier(id)
	rows.append(_row("crit_damage", "暴击伤害", "输出", value, _percent(value), sources,
		"暴击时的伤害倍率；150% 表示造成普通命中的 1.5 倍伤害。", true))

	sources = []
	value = STATS.get_role_max_health(owner, id, sources)
	rows.append(_row("health", "生命值", "生存", value, "%.0f / %.0f" % [owner._get_role_current_health(id), value], sources,
		"左侧为当前 / 最大生命；下列来源计算最大生命。临时血量另计 %.0f。" % owner._get_role_temporary_health(id)))
	value = owner.get_role_armor(id)
	var storm_armor: float = preload("res://scripts/player/player_blade_storm_build.gd").bonus(owner, id, "armor")
	sources = [_source("角色基础", float(role.get("armor", 0.0)), "="), _source("剑刃风暴", storm_armor), _source("梅塔领域（当前生效）", value - float(role.get("armor", 0.0)) - storm_armor)]
	rows.append(_row("armor", "护甲", "生存", value, "%.1f" % value, sources,
		"护甲与减伤率分开计算；负护甲会增加受到的伤害。"))
	sources = []
	value = COMBAT.get_role_damage_reduction_rate(owner, id, sources)
	rows.append(_row("reduction", "减伤率", "生存", value, _percent(value), sources,
		"最终减伤 = 1 − 各来源剩余伤害比例的乘积。条件效果仅在当前满足条件时计入；护甲另算。", true))
	sources = []
	value = EQUIPMENT.get_role_dodge_chance(owner, id, sources)
	rows.append(_row("dodge", "闪避率", "生存", value, _percent(value), sources,
		"最终闪避 = 1 − 各来源命中概率的乘积。例如两份 10% 闪避合成为 19%。", true))
	value = owner.get_status_resistance(id)
	rows.append(_row("status_resistance", "状态抗性", "生存", value, _percent(value),
		[_source("当前状态抗性", value, "=")], "缩短受影响负面状态的持续时间。", true))
	var maximum: float = owner._get_role_max_health(id)
	var blessing_regen := maximum * BLESSINGS.get_divine_grace_regen_ratio_per_tick(owner) / BLESSINGS.DIVINE_GRACE_REGEN_INTERVAL
	sources = [_source("角色道具", float(bonus.get("regen_per_second", 0.0)), "="), _source("属性回复", owner._get_attribute_health_regen_per_second()), _source("神恩（折算每秒）", blessing_regen)]
	value = float(bonus.get("regen_per_second", 0.0)) + owner._get_attribute_health_regen_per_second() + blessing_regen
	rows.append(_row("regen", "生命回复", "生存", value, "%.2f /秒" % value, sources,
		"显示持续回复的速率；命中、击杀、阮石定时回复与禁疗状态另算。"))

	sources = []
	value = STATS.get_role_move_speed(owner, id, sources)
	rows.append(_row("move", "移动速度", "机动与循环", value, "%.1f" % value, sources,
		"按当前站场 / 候补状态计算。站场专属增益与减速不会预先套到候补角色。"))
	var equipment_cooldown := float(bonus.get("cooldown_multiplier", 1.0))
	var arcane_cooldown: float = owner._get_mage_arcane_charge_skill_cooldown_multiplier(id)
	sources = [_source("原始冷却", 1.0, "="), _source("角色道具", equipment_cooldown, "*"), _source("奥术充能", arcane_cooldown, "*")]
	var storm_cooldown: float = 1.0 - preload("res://scripts/player/player_blade_storm_build.gd").bonus(owner, id, "cooldown")
	sources.append(_source("风息", storm_cooldown, "*"))
	value = 1.0 - equipment_cooldown * arcane_cooldown * storm_cooldown
	rows.append(_row("cooldown", "通用冷却缩减", "机动与循环", value, _percent(value), sources,
		"冷却倍率相乘后换算缩减率；专属技能、阮石及其他条件修正请查看技能页的最终冷却。", true))
	_decorate_blessing_sources(owner, id, rows)
	_decorate_item_sources(owner, id, rows)
	return rows


static func _row(id: String, title: String, group: String, value: float, formatted: String, sources: Array, note: String, percent: bool = false) -> Dictionary:
	return {"id": id, "title": title, "group": group, "value": value, "formatted": formatted, "sources": sources, "note": note, "percent": percent}


static func _source(label: String, value: float, op: String = "+") -> Dictionary:
	return {"label": label, "value": value, "op": op}


static func _percent(value: float) -> String:
	return "%.1f%%" % (value * 100.0)


static func format_source(source: Dictionary, percent: bool) -> String:
	var value := float(source.value)
	match str(source.op):
		"*": return "× %.3f" % value
		"chance": return _percent(value)
		"+": return ("+" if value >= 0.0 else "") + (_percent(value) if percent else "%.2f" % value)
	return _percent(value) if percent else "%.2f" % value


static func visible_source(source: Dictionary) -> bool:
	if str(source.op) == "=" or str(source.label) == "角色基础":
		return true
	return not is_equal_approx(float(source.value), 1.0 if str(source.op) == "*" else 0.0)


static func tier_counts(levels: Dictionary) -> String:
	var parts: PackedStringArray = []
	for tier in range(1, BLESSINGS.MAX_BLESSING_TIER + 1):
		var count := int(levels.get(tier, levels.get(str(tier), 0)))
		if count > 0:
			parts.append("%s×%d" % [BLESSINGS._tier_label(tier), count])
	return "  ".join(parts)


static func blessing_total(id: String, levels: Dictionary) -> String:
	var definition: Dictionary = BLESSINGS.DEFINITIONS.get(id, {})
	var stat := str(definition.get("stat", ""))
	var titles := {"base_damage": "固定攻击", "damage": "增伤", "max_health": "固定生命", "max_health_percent": "基础生命", "basic_attack_speed_percent": "普通攻速（次/秒）", "critical_chance": "暴击率", "critical_damage_bonus": "暴击伤害", "move_speed": "固定移速", "move_speed_percent": "移速", "dodge_chance": "独立闪避", "damage_reduction_rate": "独立减伤"}
	var stats: Array = [stat]
	stats.append_array((definition.get("extra_stats", {}) as Dictionary).keys())
	var parts: PackedStringArray = []
	var other_effects := false
	for key in stats:
		var value := BLESSINGS._sum_stat_bonus({id: levels}, key)
		if is_zero_approx(value):
			continue
		if not titles.has(key):
			other_effects = true
			continue
		var formatted := "%.2f" % value if key in ["base_damage", "max_health", "move_speed", "basic_attack_speed_percent"] else _percent(value)
		parts.append("%s +%s" % [titles[key], formatted])
	if parts.is_empty():
		return "各阶效果分别生效 · 详见右侧"
	return "合计  " + "；".join(parts) + ("；其余效果见明细" if other_effects else "")



static func _decorate_blessing_sources(owner, role_id: String, rows: Array[Dictionary]) -> void:
	var levels: Dictionary = BLESSINGS.get_blessing_level_summary(owner, role_id).get("role", {})
	var names_by_stat := {}
	for id in levels:
		var definition: Dictionary = BLESSINGS.DEFINITIONS.get(id, {})
		var stats: Array = [str(definition.get("stat", ""))]
		stats.append_array((definition.get("extra_stats", {}) as Dictionary).keys())
		for stat in stats:
			var title := str(definition.get("display_title", definition.get("title", id)))
			var names: Array = names_by_stat.get(stat, [])
			names.append(title + " · " + tier_counts(levels[id]))
			names_by_stat[stat] = names
	var mapping := {"attack": {"焰阳": "base_damage", "祝福增伤": "damage"}, "attack_speed": {"祝福": "basic_attack_speed_percent"}, "crit": {"祝福": "critical_chance"}, "crit_damage": {"祝福": "critical_damage_bonus"}, "health": {"祝福生命倍率": "max_health_percent", "祝福固定生命": "max_health"}, "dodge": {"祝福": "dodge_chance"}, "move": {"祝福固定移速": "move_speed", "祝福移速倍率": "move_speed_percent"}}
	for row in rows:
		for source in row.sources:
			var stat := str((mapping.get(row.id, {}) as Dictionary).get(source.label, ""))
			if names_by_stat.has(stat):
				source.label = "\n".join(names_by_stat[stat])


static func equipment_effect_text(id: String, count: int) -> String:
	var definition: Dictionary = EQUIPMENT.EQUIPMENT_DEFINITIONS.get(id, {})
	var lines: PackedStringArray = []
	var formats := {"damage_multiplier_bonus": ["伤害 +%.1f%%", 100.0], "speed_bonus": ["移速 +%.0f", 1.0], "max_health_bonus": ["最大生命 +%.0f", 1.0], "regen_bonus": ["生命回复 +%.2f /秒", 1.0], "skill_range_multiplier_bonus": ["技能范围 +%.1f%%", 100.0], "energy_gain_bonus": ["大招能量获取 +%.1f%%", 100.0]}
	for key in formats:
		if definition.has(key):
			lines.append(str(formats[key][0]) % (float(definition[key]) * count * float(formats[key][1])))
	if definition.has("cooldown_multiplier"):
		lines.append("技能冷却缩减 %.1f%%" % ((1.0 - maxf(0.65, pow(float(definition.cooldown_multiplier), count))) * 100.0))
	if definition.has("low_health_threshold"):
		lines.append("站场且生命低于 %.0f%% 时，减伤 %.0f%%；重复持有取最高值。" % [float(definition.low_health_threshold) * 100.0, float(definition.low_health_damage_reduction_rate) * 100.0])
	return "；".join(lines)


static func get_innate_skill_info(owner, role_id: String, progress_id: String) -> Dictionary:
	var summaries := {
		"swordsman_trait": "战意在战斗中触发回复，骑士荣耀在濒死时提供保护。",
		"gunner_trait": "瞬杀积累层数，强化伤害、移动和闪避；层数随战斗状态变化。",
		"gunner_hunt": "猎杀根据周围敌人与安全距离提供强化。",
		"mage_trait": "积累奥术充能，强化输出并影响技能循环。",
		"mechanic_trait": "战场改装持续产出零件，强化召唤物、力场和机械全开齐射。",
		"swordsman_entry": "满能切换登场时向指定方向冲锋，对路径上的敌人造成伤害。",
		"gunner_entry": "满能切换登场时释放多波环形弹幕，压制周围敌人。",
		"mage_entry": "满能切换登场时释放密集雷群，并进入奥法盈余。",
		"mechanic_entry": "满能切换登场时紧急部署定点机炮，自动攻击附近敌人。",
		"swordsman_basic": "挥剑攻击前方敌人；追加斩击沿同一方向依次释放。",
		"gunner_basic": "向瞄准方向发射子弹，升级可强化射程、弹速和分裂。",
		"mage_basic": "在目标区域引发雷击，造成范围伤害。",
		"mechanic_basic": "释放机械蜘蛛，追击攻击范围内的敌人。"
	}
	var rows: Array = []
	var note := ""
	if progress_id.ends_with("_basic"):
		rows.append({"label": "当前攻击力", "value": "%.1f" % owner._get_role_damage(role_id)})
		rows.append({"label": "攻击间隔", "value": "%.2f 秒" % owner._get_effective_attack_interval(role_id)})
		if role_id == "swordsman":
			var preview: Dictionary = preload("res://scripts/player/player_skill_level_effect_flow.gd").get_upgrade_display(owner, role_id, progress_id)
			for row in preview.get("effect_rows", []):
				rows.append({"label": row.label, "value": row.before})
		note = "攻击力已包含通用增伤；实际命中另计普攻倍率、暴击、专属强化和目标防御。"
	elif progress_id.ends_with("_entry"):
		rows.append({"label": "当前登场能量", "value": "%.0f / %.0f" % [owner._get_role_switch_energy(role_id), owner.SWITCH_ENTRY_ENERGY_REQUIRED]})
		note = "需切换角色并满足登场能量条件；查看人物页不会触发登场。"
	elif progress_id == "swordsman_trait":
		var effects := preload("res://scripts/player/player_skill_level_effect_flow.gd")
		var runtime := preload("res://scripts/player/player_swordsman_trait_runtime_flow.gd")
		var will := preload("res://scripts/player/player_swordsman_battle_will_flow.gd")
		var low_health := will.get_low_health_will_multiplier(owner)
		var chance: float = (owner._get_swordsman_trait_heal_proc_chance() + runtime.get_battle_will_proc_chance_bonus(owner) + effects.get_swordsman_battle_will_proc_chance_bonus(owner)) * low_health
		var heal: float = (owner._get_swordsman_trait_heal_amount() + effects.get_swordsman_battle_will_heal_ratio_bonus(owner)) * low_health
		rows.append({"label": "剑士战意触发率", "value": _percent(chance)})
		rows.append({"label": "最大生命回复比例", "value": _percent(heal)})
		note = "战意还会回复部分已损失生命；后台共享、必定触发和治疗增减按对应条件计算。"
	elif progress_id == "mechanic_trait":
		rows.append({"label": "当前零件", "value": "%d" % owner.mechanic_role.get_parts_count(owner)})
		rows.append({"label": "当前召唤伤害倍率", "value": "%.0f%%" % (owner.mechanic_role.get_summon_damage_multiplier(owner) * 100.0)})
	elif progress_id == "gunner_trait":
		rows.append({"label": "当前伤害倍率", "value": "%.0f%%" % (owner._get_gunner_flash_damage_multiplier() * 100.0)})
		rows.append({"label": "每层闪避来源", "value": "%.1f%%" % (owner._get_gunner_flash_dodge_chance(role_id) * 100.0)})
	elif progress_id == "gunner_hunt":
		rows.append({"label": "安全区半径", "value": "%.0f" % owner._get_gunner_safe_zone_radius()})
		rows.append({"label": "当前伤害倍率", "value": "%.0f%%" % (owner._get_gunner_hunt_damage_multiplier(role_id) * 100.0)})
	elif progress_id == "mage_trait":
		rows.append({"label": "当前有效充能", "value": "%d 层" % owner._get_mage_arcane_charge_effective_stacks_for_role(role_id)})
		rows.append({"label": "当前伤害倍率", "value": "%.0f%%" % (owner._get_mage_arcane_charge_damage_multiplier() * 100.0)})
	return {"effect_summary": summaries.get(progress_id, ""), "effect_rows": rows, "effect_note": note}


static func _decorate_item_sources(owner, role_id: String, rows: Array[Dictionary]) -> void:
	var stone_system := preload("res://scripts/player/ruan_stone_system.gd")
	var equipped: Dictionary = owner._get_role_equipment_levels(role_id)
	var equipment_keys := {"attack": "damage_multiplier_bonus", "attack_speed": "attack_speed_percent_bonus", "health": "max_health_bonus", "regen": "regen_bonus", "move": "speed_bonus", "cooldown": "cooldown_multiplier"}
	var stone_ids := {"attack": ["broken_sword", "ground_branch"], "attack_speed": ["ground_branch", "failed_assassin_dagger"], "crit": ["rusted_dagger"], "health": ["broken_chestplate"], "dodge": ["tattered_cloak"], "reduction": ["broken_chestplate"], "move": ["failed_assassin_dagger"]}
	for row in rows:
		var item_names: PackedStringArray = []
		for id in equipped:
			if int(equipped[id]) > 0 and (EQUIPMENT.EQUIPMENT_DEFINITIONS.get(id, {}) as Dictionary).has(equipment_keys.get(row.id, "")):
				item_names.append("%s ×%d" % [EQUIPMENT.EQUIPMENT_DEFINITIONS[id].title, equipped[id]])
		for source in row.sources:
			if str(source.label) == "角色道具" and not item_names.is_empty():
				source.label = "\n".join(item_names)
			elif str(source.label) == "通用与角色道具增伤" and not item_names.is_empty():
				source.label += "\n" + "、".join(item_names)
			elif str(source.label).begins_with("共享阮石"):
				var names: PackedStringArray = []
				var ids: Array = ["broken_sword"] if str(source.label) == "共享阮石增伤" else stone_ids.get(row.id, [])
				for id in ids:
					var count := STONES.get_count(owner, id)
					if count > 0:
						names.append("%s ×%d" % [stone_system.get_definition(id).get("title", id), count])
				if not names.is_empty():
					source.label = "\n".join(names)
			elif str(source.label) == "通用与物品移速加值":
				var count := STONES.get_count(owner, "tattered_cloak")
				if count > 0:
					item_names.append("残破披风 ×%d" % count)
				if not item_names.is_empty():
					source.label += "\n" + "、".join(item_names)
	var blessing_rates: Array = []
	var levels: Dictionary = BLESSINGS.get_blessing_level_summary(owner, role_id).get("role", {})
	for id in levels:
		var definition: Dictionary = BLESSINGS.DEFINITIONS.get(id, {})
		if str(definition.get("stat", "")) != "damage_reduction_rate":
			continue
		for tier in levels[id]:
			for _copy in int(levels[id][tier]):
				blessing_rates.append("%s · %s（单份）" % [definition.get("display_title", definition.get("title", id)), BLESSINGS._tier_label(int(tier))])
	for row in rows:
		if row.id == "reduction":
			for source in row.sources:
				if str(source.label) == "祝福（每份独立）" and not blessing_rates.is_empty():
					source.label = blessing_rates.pop_front()

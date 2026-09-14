extends RefCounted

const STONE_THUNDER := "thunder"
const STONE_FROST := "frost"
const STONE_POISON := "poison"
const STONE_FLAME := "flame"
const STONE_FURY := "fury"
const STONE_IDS := [STONE_THUNDER, STONE_FROST, STONE_FURY, STONE_FLAME, "useless_pendant", "broken_sword", "keen_fragment", "tattered_cloak", "ground_branch", "guild_token", "broken_magic_stone", "rusted_dagger", "used_potion", "broken_chestplate", "unknown_spellbook"]

const DEFINITIONS := {
	STONE_THUNDER: {"title": "雷石", "summary": "普攻触发电流连锁。"},
	STONE_FROST: {"title": "冰石", "summary": "普攻大幅减速敌人。"},
	STONE_POISON: {"title": "毒石", "summary": "普攻附加持续毒伤。"},
	STONE_FLAME: {"title": "炎石", "summary": "普攻击杀敌人时引爆尸骸。"},
	STONE_FURY: {"title": "烈石", "summary": "普攻附加伤害加深。"}
	,"broken_sword": {"title": "冒险者破剑", "summary": "攻击力 +2，伤害 +5%。"}
	,"keen_fragment": {"title": "基恩碎片", "summary": "远程攻击距离 +25，近战攻击范围 +25%。"}
	,"tattered_cloak": {"title": "残破披风", "summary": "移动速度 +10，闪避值 +20。"}
	,"ground_branch": {"title": "地上的树枝", "summary": "减伤值 +20，所有角色伤害 +8%。"}
	,"guild_token": {"title": "工会令牌碎片", "summary": "每 10 秒回复 20 点生命。"}
	,"broken_magic_stone": {"title": "残破的魔石", "summary": "经验获取效率 +10%。"}
	,"rusted_dagger": {"title": "生锈的匕首", "summary": "暴击率 +8%，暴击伤害 +8%。"}
	,"used_potion": {"title": "喝过的魔瓶", "summary": "每秒恢复 1 点生命和 1 点大招能量。"}
	,"broken_chestplate": {"title": "残破胸甲", "summary": "生命 +30，减伤值 +20。"}
	,"unknown_spellbook": {"title": "不知名魔法书残页", "summary": "大招伤害 +20%，其他技能冷却减少 5%。"}
	,"useless_pendant": {"title": "无用挂件", "summary": "每秒回复1点大招能量，大招伤害增加10%。"}
}


static func normalize_profile(profile: Dictionary) -> Dictionary:
	profile["bones"] = _non_negative_int(profile.get("bones", 0))
	var source_purchased: Variant = profile.get("ruan_stone_purchased", [])
	var purchased: Array = source_purchased.duplicate() if source_purchased is Array else []
	var normalized_purchased: Array = []
	for stone_id in purchased:
		if STONE_IDS.has(str(stone_id)) and not normalized_purchased.has(str(stone_id)):
			normalized_purchased.append(str(stone_id))
	profile["ruan_stone_purchased"] = normalized_purchased
	profile["ruan_stone_levels"] = {}
	profile["equipped_ruan_stone"] = ""
	return profile


static func get_definition(stone_id: String) -> Dictionary:
	return (DEFINITIONS.get(stone_id, {}) as Dictionary).duplicate(true)


static func get_level(profile: Dictionary, stone_id: String) -> int:
	if not STONE_IDS.has(stone_id):
		return 0
	var purchased: Variant = profile.get("ruan_stone_purchased", [])
	if purchased is Array:
		return 1 if (purchased as Array).has(stone_id) else 0
	return 0


static func get_next_cost(profile: Dictionary, stone_id: String) -> int:
	if not STONE_IDS.has(stone_id):
		return 0
	return 5


static func purchase(profile: Dictionary, stone_id: String) -> Dictionary:
	normalize_profile(profile)
	if not STONE_IDS.has(stone_id):
		return {"success": false, "reason": "invalid_stone"}
	var cost := get_next_cost(profile, stone_id)
	var bones := int(profile.get("bones", 0))
	if bones < cost:
		return {"success": false, "reason": "not_enough_bones", "cost": cost, "bones": bones}
	var purchased: Array = profile.get("ruan_stone_purchased", [])
	if not purchased.is_empty():
		return {"success": false, "reason": "purchase_limit_reached", "cost": cost, "bones": bones}
	if purchased.has(stone_id):
		return {"success": false, "reason": "already_purchased", "cost": 0, "bones": bones}
	profile["bones"] = bones - cost
	purchased.append(stone_id)
	profile["ruan_stone_purchased"] = purchased
	return {
		"success": true,
		"stone_id": stone_id,
		"cost": cost,
		"level": 1,
		"bones": int(profile["bones"])
	}


static func equip(profile: Dictionary, stone_id: String) -> bool:
	normalize_profile(profile)
	if get_level(profile, stone_id) <= 0:
		return false
	profile["equipped_ruan_stone"] = stone_id
	return true


static func get_equipped(profile: Dictionary) -> String:
	var equipped := str(profile.get("equipped_ruan_stone", ""))
	return equipped if STONE_IDS.has(equipped) and get_level(profile, equipped) > 0 else ""


static func get_effect_values(stone_id: String, level: int) -> Dictionary:
	var safe_level: int = max(1, level)
	var upgrades: int = safe_level - 1
	match stone_id:
		STONE_THUNDER:
			return {
				"damage_ratio": 0.30 + 0.03 * upgrades,
				"jump_count": min(5, 1 + floori(float(safe_level) / 5.0))
			}
		STONE_FROST:
			return {
				"slow_ratio": min(0.75, 0.45 + 0.015 * upgrades),
				"duration": 1.2 + 0.08 * upgrades
			}
		STONE_POISON:
			return {
				"total_damage_ratio": 0.45 + 0.07 * upgrades,
				"duration": 3.0,
				"max_stacks": 3
			}
		STONE_FLAME:
			return {
				"damage_ratio": 0.08 + 0.005 * upgrades,
				"radius": 260.0
			}
		STONE_FURY:
			return {
				"vulnerability_ratio": 0.06 + 0.005 * upgrades,
				"duration": 2.0 + 0.05 * upgrades
			}
		"broken_sword": return {"attack_bonus": 2.0, "damage_bonus": 0.05}
		"keen_fragment": return {"range_bonus": 25.0, "melee_range_multiplier": 1.25}
		"tattered_cloak": return {"speed_bonus": 10.0, "dodge_bonus": 20.0}
		"ground_branch": return {"damage_reduction_bonus": 20.0, "damage_bonus": 0.08}
		"guild_token": return {"heal_interval": 10.0, "heal_amount": 20.0}
		"broken_magic_stone": return {"experience_multiplier": 1.10}
		"rusted_dagger": return {"critical_chance_bonus": 0.08, "critical_damage_bonus": 0.08}
		"used_potion": return {"heal_per_second": 1.0, "energy_per_second": 1.0}
		"broken_chestplate": return {"max_health_bonus": 30.0, "damage_reduction_bonus": 20.0}
		"unknown_spellbook": return {"ultimate_damage_bonus": 0.20, "cooldown_multiplier": 0.95}
		"useless_pendant": return {"energy_per_second": 1.0, "ultimate_damage_bonus": 0.10}
	return {}


static func get_effect_text(stone_id: String, level: int) -> String:
	if level <= 0 or not STONE_IDS.has(stone_id):
		return "未拥有"
	var values := get_effect_values(stone_id, level)
	match stone_id:
		STONE_THUNDER:
			return "连锁%d个目标，造成%s%%伤害" % [int(values["jump_count"]), _percent(values["damage_ratio"])]
		STONE_FROST:
			return "减速%s%%，持续%s秒" % [_percent(values["slow_ratio"]), _decimal(values["duration"])]
		STONE_POISON:
			return "3秒造成%s%%毒伤，最多3层" % _percent(values["total_damage_ratio"])
		STONE_FLAME:
			return "普攻击杀爆炸：%d范围，造成死者最大生命%s%%伤害" % [int(values["radius"]), _percent(values["damage_ratio"])]
		STONE_FURY:
			return "伤害加深%s%%，持续%s秒" % [_percent(values["vulnerability_ratio"]), _decimal(values["duration"])]
	return ""


static func get_next_effect_text(profile: Dictionary, stone_id: String) -> String:
	if not STONE_IDS.has(stone_id):
		return ""
	return get_effect_text(stone_id, get_level(profile, stone_id) + 1)


static func _non_negative_int(value: Variant) -> int:
	if value is int or value is float or value is bool or value is String:
		return max(0, int(value))
	return 0


static func _percent(ratio: float) -> String:
	return _number(ratio * 100.0)


static func _decimal(value: float) -> String:
	return _number(value)


static func _number(value: float) -> String:
	var rounded := snappedf(value, 0.01)
	if is_equal_approx(rounded, roundf(rounded)):
		return str(int(roundf(rounded)))
	return ("%.2f" % rounded).trim_suffix("0")

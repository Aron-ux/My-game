extends RefCounted

const STONE_THUNDER := "thunder"
const STONE_FROST := "frost"
const STONE_POISON := "poison"
const STONE_FLAME := "flame"
const STONE_FURY := "fury"
const STONE_IDS := [STONE_THUNDER, STONE_FROST, STONE_POISON, STONE_FLAME, STONE_FURY]

const DEFINITIONS := {
	STONE_THUNDER: {"title": "雷石", "summary": "普攻触发电流连锁。"},
	STONE_FROST: {"title": "冰石", "summary": "普攻大幅减速敌人。"},
	STONE_POISON: {"title": "毒石", "summary": "普攻附加持续毒伤。"},
	STONE_FLAME: {"title": "炎石", "summary": "普攻向附近敌人分裂伤害。"},
	STONE_FURY: {"title": "烈石", "summary": "普攻附加伤害加深。"}
}


static func normalize_profile(profile: Dictionary) -> Dictionary:
	profile["bones"] = _non_negative_int(profile.get("bones", 0))
	var source_levels: Dictionary = profile.get("ruan_stone_levels", {}) if profile.get("ruan_stone_levels", {}) is Dictionary else {}
	var normalized_levels := {}
	for stone_id in STONE_IDS:
		normalized_levels[stone_id] = _non_negative_int(source_levels.get(stone_id, 0))
	profile["ruan_stone_levels"] = normalized_levels
	var equipped := str(profile.get("equipped_ruan_stone", ""))
	if not STONE_IDS.has(equipped) or int(normalized_levels.get(equipped, 0)) <= 0:
		equipped = ""
	profile["equipped_ruan_stone"] = equipped
	return profile


static func get_definition(stone_id: String) -> Dictionary:
	return (DEFINITIONS.get(stone_id, {}) as Dictionary).duplicate(true)


static func get_level(profile: Dictionary, stone_id: String) -> int:
	if not STONE_IDS.has(stone_id):
		return 0
	var levels: Variant = profile.get("ruan_stone_levels", {})
	if levels is not Dictionary:
		return 0
	return _non_negative_int((levels as Dictionary).get(stone_id, 0))


static func get_next_cost(profile: Dictionary, stone_id: String) -> int:
	if not STONE_IDS.has(stone_id):
		return 0
	return 5 + 3 * get_level(profile, stone_id)


static func purchase(profile: Dictionary, stone_id: String) -> Dictionary:
	normalize_profile(profile)
	if not STONE_IDS.has(stone_id):
		return {"success": false, "reason": "invalid_stone"}
	var cost := get_next_cost(profile, stone_id)
	var bones := int(profile.get("bones", 0))
	if bones < cost:
		return {"success": false, "reason": "not_enough_bones", "cost": cost, "bones": bones}
	var next_level := get_level(profile, stone_id) + 1
	profile["bones"] = bones - cost
	(profile["ruan_stone_levels"] as Dictionary)[stone_id] = next_level
	return {
		"success": true,
		"stone_id": stone_id,
		"cost": cost,
		"level": next_level,
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
				"damage_ratio": 0.25 + 0.03 * upgrades,
				"target_count": min(5, 2 + floori(float(safe_level) / 6.0))
			}
		STONE_FURY:
			return {
				"vulnerability_ratio": 0.06 + 0.005 * upgrades,
				"duration": 2.0 + 0.05 * upgrades
			}
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
			return "分裂至%d个目标，造成%s%%伤害" % [int(values["target_count"]), _percent(values["damage_ratio"])]
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

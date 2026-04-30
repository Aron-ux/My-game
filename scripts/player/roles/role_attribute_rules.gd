extends RefCounted

const EVOLUTION_LEVEL := 6
const THIRD_EVOLUTION_LEVEL := 12
const MAX_ATTRIBUTE_LEVEL := 18
const EVOLVED_TITLE_COLOR := Color(0.38, 1.0, 0.48, 1.0)

const SWORD_HEART_INTERVAL_REDUCTION := 0.022
const SWORD_HEART_EVOLVED_INTERVAL_REDUCTION := 0.034
const SWORD_HEART_THIRD_INTERVAL_REDUCTION := 0.057
const SWORD_HEART_RANGE_GROWTH := 0.05
const SWORD_HEART_EVOLVED_SCALE := 1.25
const SWORD_HEART_THIRD_EVOLVED_SCALE := 1.5
const SWORD_HEART_THIRD_LENGTH_GROWTH := 0.10
const SWORD_HEART_THIRD_WIDTH_GROWTH := 0.12
const SWORD_HEART_THIRD_FINAL_VISUAL_RATIO := 0.60
const SWORD_BLOOD_EVOLVED_BASE_DODGE := 0.25
const SWORD_BLOOD_EVOLVED_DODGE_PER_LEVEL := 0.01
const SWORD_BLOOD_EVOLVED_LIFESTEAL_PER_LEVEL := 0.005

const GUNNER_BARRAGE_SPEED_GROWTH := 0.10
const GUNNER_BARRAGE_EVOLUTION_INTERVAL_REDUCTION := 0.10
const GUNNER_FOOTWORK_RANGE_GROWTH := 0.015
const GUNNER_FOOTWORK_MOVE_GROWTH := 0.01
const GUNNER_FOOTWORK_EVOLVED_FLAT_SPEED := 20.0
const GUNNER_FOOTWORK_THIRD_FLAT_SPEED := 35.0

const MAGE_ARCANE_FOCUS_BASE_FINAL_SCALE := 1.18
const MAGE_ARCANE_FOCUS_EVOLVED_START_SCALE := 1.32
const MAGE_ARCANE_FOCUS_EVOLVED_FINAL_SCALE := 1.50
const MAGE_ARCANE_FOCUS_THIRD_START_SCALE := 1.62
const MAGE_ARCANE_FOCUS_THIRD_FINAL_SCALE := 1.80
const MAGE_SURPLUS_ENERGY_GROWTH := 0.01
const MAGE_SURPLUS_ENERGY_GROWTH_SELF := 0.02
const MAGE_SURPLUS_EVOLVED_GROWTH_MULTIPLIER := 1.5
const MAGE_SURPLUS_THIRD_GROWTH_MULTIPLIER := 2.0
const MAGE_SURPLUS_BASE_PASSIVE_ENERGY := 1.2
const MAGE_SURPLUS_PASSIVE_ENERGY_PER_LEVEL := 0.12
const MAGE_SURPLUS_THIRD_PASSIVE_ENERGY_PER_LEVEL := 0.18


static func is_attribute_evolved(level: int) -> bool:
	return level > EVOLUTION_LEVEL


static func is_attribute_third_evolved(level: int) -> bool:
	return level > THIRD_EVOLUTION_LEVEL


static func get_effective_level(level: int) -> int:
	return clamp(level, 0, MAX_ATTRIBUTE_LEVEL)


static func get_base_tier_level(level: int) -> int:
	return min(get_effective_level(level), EVOLUTION_LEVEL)


static func get_evolved_extra_level(level: int) -> int:
	return min(max(0, get_effective_level(level) - EVOLUTION_LEVEL), THIRD_EVOLUTION_LEVEL - EVOLUTION_LEVEL)


static func get_third_extra_level(level: int) -> int:
	return max(0, get_effective_level(level) - THIRD_EVOLUTION_LEVEL)


static func get_swordsman_heart_interval_multiplier(level: int) -> float:
	var base_multiplier := pow(1.0 - SWORD_HEART_INTERVAL_REDUCTION, float(get_base_tier_level(level)))
	var second_multiplier := pow(1.0 - SWORD_HEART_EVOLVED_INTERVAL_REDUCTION, float(get_evolved_extra_level(level)))
	var third_multiplier := pow(1.0 - SWORD_HEART_THIRD_INTERVAL_REDUCTION, float(get_third_extra_level(level)))
	return base_multiplier * second_multiplier * third_multiplier


static func get_swordsman_heart_range_multiplier(level: int) -> float:
	var base_multiplier := pow(1.0 + SWORD_HEART_RANGE_GROWTH, float(get_base_tier_level(level)))
	if level <= EVOLUTION_LEVEL:
		return base_multiplier
	var second_multiplier := SWORD_HEART_EVOLVED_SCALE * pow(1.0 + SWORD_HEART_RANGE_GROWTH * 2.0, float(get_evolved_extra_level(level)))
	var third_multiplier := 1.0
	if level > THIRD_EVOLUTION_LEVEL:
		third_multiplier = SWORD_HEART_THIRD_EVOLVED_SCALE * pow(1.0 + SWORD_HEART_RANGE_GROWTH * 3.0, float(get_third_extra_level(level)))
	return base_multiplier * second_multiplier * third_multiplier


static func get_swordsman_normal_attack_scale(level: int) -> float:
	if level <= EVOLUTION_LEVEL:
		return 1.0
	if level <= THIRD_EVOLUTION_LEVEL:
		return SWORD_HEART_EVOLVED_SCALE * pow(1.0 + SWORD_HEART_RANGE_GROWTH * 2.0, float(get_evolved_extra_level(level)))
	var level_thirteen_scale: float = _get_swordsman_level_thirteen_normal_attack_scale()
	var target_level_eighteen_scale: float = level_thirteen_scale * (1.0 + SWORD_HEART_THIRD_LENGTH_GROWTH) * SWORD_HEART_THIRD_FINAL_VISUAL_RATIO
	var third_step: float = _get_swordsman_third_visual_step(level)
	return lerp(level_thirteen_scale, target_level_eighteen_scale, third_step)


static func get_swordsman_normal_attack_width_scale(level: int) -> float:
	if level <= THIRD_EVOLUTION_LEVEL:
		return get_swordsman_heart_range_multiplier(level) * get_swordsman_normal_attack_scale(level)
	var level_thirteen_width_scale: float = get_swordsman_heart_range_multiplier(THIRD_EVOLUTION_LEVEL + 1) * _get_swordsman_level_thirteen_normal_attack_scale()
	var target_level_eighteen_width_scale: float = level_thirteen_width_scale * (1.0 + SWORD_HEART_THIRD_WIDTH_GROWTH) * SWORD_HEART_THIRD_FINAL_VISUAL_RATIO
	var third_step: float = _get_swordsman_third_visual_step(level)
	return lerp(level_thirteen_width_scale, target_level_eighteen_width_scale, third_step)


static func _get_swordsman_level_thirteen_normal_attack_scale() -> float:
	var level_twelve_scale: float = SWORD_HEART_EVOLVED_SCALE * pow(1.0 + SWORD_HEART_RANGE_GROWTH * 2.0, float(THIRD_EVOLUTION_LEVEL - EVOLUTION_LEVEL))
	return level_twelve_scale * SWORD_HEART_THIRD_EVOLVED_SCALE


static func _get_swordsman_third_visual_step(level: int) -> float:
	var raw_step: float = float(max(0, get_effective_level(level) - (THIRD_EVOLUTION_LEVEL + 1))) / float(max(1, MAX_ATTRIBUTE_LEVEL - (THIRD_EVOLUTION_LEVEL + 1)))
	raw_step = clamp(raw_step, 0.0, 1.0)
	return 1.0 - pow(1.0 - raw_step, 2.0)


static func _get_original_swordsman_bloodthirst_ratio(level: int) -> float:
	var remaining: int = max(0, level)
	var ratio: float = 0.0
	var first_tier: int = min(remaining, 3)
	ratio += float(first_tier) * 0.008
	remaining -= first_tier
	if remaining > 0:
		var second_tier: int = min(remaining, 3)
		ratio += float(second_tier) * 0.006
		remaining -= second_tier
	if remaining > 0:
		ratio += float(remaining) * 0.004
	return min(ratio, 0.08)


static func get_swordsman_bloodthirst_ratio(level: int) -> float:
	var ratio := _get_original_swordsman_bloodthirst_ratio(get_base_tier_level(level)) * 0.5
	ratio += float(get_evolved_extra_level(level)) * SWORD_BLOOD_EVOLVED_LIFESTEAL_PER_LEVEL
	ratio += float(get_third_extra_level(level)) * SWORD_BLOOD_EVOLVED_LIFESTEAL_PER_LEVEL * 1.5
	return min(ratio, 0.16)


static func get_swordsman_bloodthirst_heal_cap(level: int) -> float:
	var cap := 0.7 + float(get_base_tier_level(level)) * 0.09
	cap += float(get_evolved_extra_level(level)) * 0.12
	cap += float(get_third_extra_level(level)) * 0.18
	return cap


static func get_swordsman_dodge_chance(level: int) -> float:
	if level <= EVOLUTION_LEVEL:
		return 0.0
	var dodge := SWORD_BLOOD_EVOLVED_BASE_DODGE
	dodge += float(get_evolved_extra_level(level)) * SWORD_BLOOD_EVOLVED_DODGE_PER_LEVEL
	dodge += float(get_third_extra_level(level)) * SWORD_BLOOD_EVOLVED_DODGE_PER_LEVEL * 1.5
	return min(0.70, dodge)


static func get_gunner_barrage_speed_multiplier(level: int) -> float:
	var base_multiplier := pow(1.0 + GUNNER_BARRAGE_SPEED_GROWTH, float(get_base_tier_level(level)))
	var second_multiplier := pow(1.0 + GUNNER_BARRAGE_SPEED_GROWTH * 2.0, float(get_evolved_extra_level(level)))
	var third_multiplier := pow(1.0 + GUNNER_BARRAGE_SPEED_GROWTH * 3.0, float(get_third_extra_level(level)))
	return base_multiplier * second_multiplier * third_multiplier


static func get_gunner_barrage_interval_reduction(level: int) -> float:
	var reduction: float = 0.0
	if level > EVOLUTION_LEVEL:
		reduction += GUNNER_BARRAGE_EVOLUTION_INTERVAL_REDUCTION
	if level > THIRD_EVOLUTION_LEVEL:
		reduction += GUNNER_BARRAGE_EVOLUTION_INTERVAL_REDUCTION
	return reduction


static func get_gunner_barrage_bounce_count(level: int) -> int:
	if level > EVOLUTION_LEVEL:
		return 0
	return int(floor(float(max(0, level)) / 3.0))


static func get_gunner_barrage_shotgun_wave_count(level: int) -> int:
	if level > THIRD_EVOLUTION_LEVEL:
		return 3
	return 2 if level > EVOLUTION_LEVEL else 0


static func get_gunner_barrage_shotgun_pellet_count(level: int) -> int:
	return 3 if level > EVOLUTION_LEVEL else 0


static func get_gunner_barrage_split_count(level: int) -> int:
	if level > THIRD_EVOLUTION_LEVEL:
		return 2
	return 1 if level > EVOLUTION_LEVEL else 0


static func get_gunner_footwork_range_multiplier(level: int) -> float:
	var base_multiplier := pow(1.0 + GUNNER_FOOTWORK_RANGE_GROWTH, float(get_base_tier_level(level)))
	var second_multiplier := pow(1.0 + GUNNER_FOOTWORK_RANGE_GROWTH, float(get_evolved_extra_level(level)))
	var third_multiplier := pow(1.0 + GUNNER_FOOTWORK_RANGE_GROWTH * 1.5, float(get_third_extra_level(level)))
	return base_multiplier * second_multiplier * third_multiplier


static func get_gunner_footwork_move_multiplier(level: int) -> float:
	var base_multiplier := pow(1.0 + GUNNER_FOOTWORK_MOVE_GROWTH, float(get_base_tier_level(level)))
	var second_multiplier := pow(1.0 + GUNNER_FOOTWORK_MOVE_GROWTH, float(get_evolved_extra_level(level)))
	var third_multiplier := pow(1.0 + GUNNER_FOOTWORK_MOVE_GROWTH * 1.5, float(get_third_extra_level(level)))
	return base_multiplier * second_multiplier * third_multiplier


static func get_gunner_footwork_flat_speed_bonus(level: int) -> float:
	if level > THIRD_EVOLUTION_LEVEL:
		return GUNNER_FOOTWORK_THIRD_FLAT_SPEED
	return GUNNER_FOOTWORK_EVOLVED_FLAT_SPEED if level > EVOLUTION_LEVEL else 0.0


static func get_mage_arcane_focus_range_multiplier(level: int) -> float:
	level = get_effective_level(level)
	if level <= EVOLUTION_LEVEL:
		return lerp(1.0, MAGE_ARCANE_FOCUS_BASE_FINAL_SCALE, float(level) / float(EVOLUTION_LEVEL))
	if level <= THIRD_EVOLUTION_LEVEL:
		var evolved_step: float = _ease_out_ratio(float(level - (EVOLUTION_LEVEL + 1)) / float(THIRD_EVOLUTION_LEVEL - (EVOLUTION_LEVEL + 1)))
		return lerp(MAGE_ARCANE_FOCUS_EVOLVED_START_SCALE, MAGE_ARCANE_FOCUS_EVOLVED_FINAL_SCALE, evolved_step)
	var third_step: float = _ease_out_ratio(float(level - (THIRD_EVOLUTION_LEVEL + 1)) / float(MAX_ATTRIBUTE_LEVEL - (THIRD_EVOLUTION_LEVEL + 1)))
	return lerp(MAGE_ARCANE_FOCUS_THIRD_START_SCALE, MAGE_ARCANE_FOCUS_THIRD_FINAL_SCALE, third_step)


static func _ease_out_ratio(raw_ratio: float) -> float:
	var ratio: float = clamp(raw_ratio, 0.0, 1.0)
	return 1.0 - pow(1.0 - ratio, 2.0)


static func get_mage_surplus_energy_multiplier(level: int, role_id: String = "") -> float:
	var growth := MAGE_SURPLUS_ENERGY_GROWTH
	if role_id == "mage":
		growth = MAGE_SURPLUS_ENERGY_GROWTH_SELF
	var base_multiplier := pow(1.0 + growth, float(get_base_tier_level(level)))
	var second_multiplier := pow(1.0 + growth * MAGE_SURPLUS_EVOLVED_GROWTH_MULTIPLIER, float(get_evolved_extra_level(level)))
	var third_multiplier := pow(1.0 + growth * MAGE_SURPLUS_THIRD_GROWTH_MULTIPLIER, float(get_third_extra_level(level)))
	return base_multiplier * second_multiplier * third_multiplier


static func get_mage_surplus_passive_energy_per_second(level: int) -> float:
	if level <= EVOLUTION_LEVEL:
		return 0.0
	var passive := MAGE_SURPLUS_BASE_PASSIVE_ENERGY
	passive += float(get_evolved_extra_level(level)) * MAGE_SURPLUS_PASSIVE_ENERGY_PER_LEVEL
	passive += float(get_third_extra_level(level)) * MAGE_SURPLUS_THIRD_PASSIVE_ENERGY_PER_LEVEL
	return passive


static func get_role_attribute_titles(role_id: String, levels: Dictionary = {}) -> Dictionary:
	match role_id:
		"swordsman":
			return {
				"vitality": _tiered_title(int(levels.get("vitality", 0)), "剑术小成", "剑术中成II", "剑术大成III"),
				"agility": _tiered_title(int(levels.get("agility", 0)), "嗜血", "嗜战II", "血战无前III")
			}
		"gunner":
			return {
				"vitality": _tiered_title(int(levels.get("vitality", 0)), "弹幕技巧", "弹幕手法II", "弹幕宗师III"),
				"agility": _tiered_title(int(levels.get("agility", 0)), "灵活步伐", "迅捷II", "疾风掠影III")
			}
		"mage":
			return {
				"vitality": _tiered_title(int(levels.get("vitality", 0)), "奥数集中", "奥数爆发II", "奥数洪流III"),
				"agility": _tiered_title(int(levels.get("agility", 0)), "奥数光环", "奥数盈余II", "星界盈流III")
			}
		_:
			return {"vitality": "生命训练", "agility": "机动训练"}


static func _tiered_title(level: int, base_title: String, second_title: String, third_title: String) -> String:
	if level > THIRD_EVOLUTION_LEVEL:
		return third_title
	if level > EVOLUTION_LEVEL:
		return second_title
	return base_title


static func get_role_attribute_description(role_id: String, attribute_key: String, next_level: int) -> String:
	var level: int = get_effective_level(next_level)
	if next_level > MAX_ATTRIBUTE_LEVEL:
		return "已达到当前版本上限 Lv.%d。" % MAX_ATTRIBUTE_LEVEL
	match role_id:
		"swordsman":
			if attribute_key == "vitality":
				if level > THIRD_EVOLUTION_LEVEL:
					return "III阶：普通攻击与特效在12级基础上即时提升为150%%；13-18级每级按原剑术小成的3倍强化攻速、范围与特效。当前攻速 %.1f%%，范围/特效 %.1f%%" % [get_swordsman_heart_interval_multiplier(level) * 100.0, get_swordsman_heart_range_multiplier(level) * 100.0]
				if level > EVOLUTION_LEVEL:
					return "II阶：普通攻击与特效提升为6级时的125%%；7-12级每级按原剑术小成的2倍继续强化。当前攻速 %.1f%%，范围/特效 %.1f%%" % [get_swordsman_heart_interval_multiplier(level) * 100.0, get_swordsman_heart_range_multiplier(level) * 100.0]
				return "普通攻击冷却缩短为基准的 %.1f%%，攻击范围与特效提升为基准的 %.1f%%" % [get_swordsman_heart_interval_multiplier(level) * 100.0, get_swordsman_heart_range_multiplier(level) * 100.0]
			if attribute_key == "agility":
				if level > THIRD_EVOLUTION_LEVEL:
					return "III阶：13-18级每级额外提升0.75%%吸血、1.5%%闪避与更高单次回复上限。当前闪避 %.0f%%，吸血 %.1f%%，单次回复上限 %.2f" % [get_swordsman_dodge_chance(level) * 100.0, get_swordsman_bloodthirst_ratio(level) * 100.0, get_swordsman_bloodthirst_heal_cap(level)]
				if level > EVOLUTION_LEVEL:
					return "II阶：剑士获得 %.0f%% 闪避；7-12级每级额外提升0.5%%吸血与1%%闪避。当前吸血 %.1f%%，单次回复上限 %.2f" % [get_swordsman_dodge_chance(level) * 100.0, get_swordsman_bloodthirst_ratio(level) * 100.0, get_swordsman_bloodthirst_heal_cap(level)]
				return "剑士造成伤害时吸血 %.1f%%，单次回复上限 %.2f" % [get_swordsman_bloodthirst_ratio(level) * 100.0, get_swordsman_bloodthirst_heal_cap(level)]
		"gunner":
			if attribute_key == "vitality":
				if level > THIRD_EVOLUTION_LEVEL:
					return "III阶：普通攻击变为3波3发散弹；13-18级每级按原弹幕技巧的3倍提升弹速，仍不提供弹射。当前弹速 %.1f%%" % (get_gunner_barrage_speed_multiplier(level) * 100.0)
				if level > EVOLUTION_LEVEL:
					return "II阶：普通攻击变为2波3发散弹；7-12级每级按原弹幕技巧的2倍提升弹速，但不再提供弹射。当前弹速 %.1f%%" % (get_gunner_barrage_speed_multiplier(level) * 100.0)
				return "弹道速度提升为基准的 %.1f%%，当前弹射 +%d，命中判定提升到视觉的 120%%" % [get_gunner_barrage_speed_multiplier(level) * 100.0, get_gunner_barrage_bounce_count(level)]
			if attribute_key == "agility":
				if level > THIRD_EVOLUTION_LEVEL:
					return "III阶：枪手移动速度 +35；13-18级每级继续提升1.5%%移动速度并强化射程。当前射程 %.1f%%，移动速度 %.1f%%" % [get_gunner_footwork_range_multiplier(level) * 100.0, get_gunner_footwork_move_multiplier(level) * 100.0]
				if level > EVOLUTION_LEVEL:
					return "II阶：枪手移动速度 +20；7-12级每级继续提升1%%移动速度。当前射程 %.1f%%，移动速度 %.1f%%" % [get_gunner_footwork_range_multiplier(level) * 100.0, get_gunner_footwork_move_multiplier(level) * 100.0]
				return "射程提升为基准的 %.1f%%，移动速度提升为基准的 %.1f%%" % [get_gunner_footwork_range_multiplier(level) * 100.0, get_gunner_footwork_move_multiplier(level) * 100.0]
		"mage":
			if attribute_key == "vitality":
				if level > THIRD_EVOLUTION_LEVEL:
					return "III阶：普通攻击聚能一次轰炸3下；13级即时提升至162%%，13-18级保守非线性提升，18级最终约180%%。当前技能范围 %.1f%%" % (get_mage_arcane_focus_range_multiplier(level) * 100.0)
				if level > EVOLUTION_LEVEL:
					return "II阶：普通攻击聚能一次轰炸2下；7级即时提升至132%%，7-12级保守非线性提升，12级约150%%。当前技能范围 %.1f%%" % (get_mage_arcane_focus_range_multiplier(level) * 100.0)
				return "术师全技能范围保守提升；6级约118%%。当前技能范围 %.1f%%" % (get_mage_arcane_focus_range_multiplier(level) * 100.0)
			if attribute_key == "agility":
				if level > THIRD_EVOLUTION_LEVEL:
					return "III阶：站场自动回能继续增强；13-18级每级按原奥数光环的2倍提升能量获取。当前每秒 %.2f，术师获取 %.1f%%，其他角色 %.1f%%" % [get_mage_surplus_passive_energy_per_second(level), get_mage_surplus_energy_multiplier(level, "mage") * 100.0, get_mage_surplus_energy_multiplier(level, "swordsman") * 100.0]
				if level > EVOLUTION_LEVEL:
					return "II阶：术师站场时每秒自动获得 %.2f 大招能量；7-12级每级按原奥数光环的1.5倍提升能量获取。当前术师获取 %.1f%%，其他角色 %.1f%%" % [get_mage_surplus_passive_energy_per_second(level), get_mage_surplus_energy_multiplier(level, "mage") * 100.0, get_mage_surplus_energy_multiplier(level, "swordsman") * 100.0]
				return "术师大招能量获取效率提升为基准的 %.1f%%，其他角色提升为基准的 %.1f%%" % [get_mage_surplus_energy_multiplier(level, "mage") * 100.0, get_mage_surplus_energy_multiplier(level, "swordsman") * 100.0]
	return ""

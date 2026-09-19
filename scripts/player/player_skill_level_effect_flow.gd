extends RefCounted

const PLAYER_SKILL_LEVEL_SYSTEM := preload("res://scripts/player/player_skill_level_system.gd")

## 技能等级的数值成长统一出口。
## 所有“每级 +X”的加成都在这里按 (等级 - 1) 线性累加，调用方只管读取，不自行计算等级。
## 设计口径：
## - 百分比倍率一律绝对加法，例如普攻基础 150% 在 2 级变成 160%；
## - 范围/体积类按倍率相乘，例如 200 在 2 级变成 220；
## - 2/4/6/8 与 3/6/9 这类里程碑在达到对应等级时各追加一段。

const SWORDSMAN_TRAIT := "swordsman_trait"
const SWORDSMAN_BASIC := "swordsman_basic"
const SWORDSMAN_ENTRY := "swordsman_entry"
const SWORDSMAN_CRESCENT_WAVE := "swordsman_crescent_wave"
const SWORDSMAN_BLADE_STORM := "swordsman_blade_storm"
const SWORDSMAN_KNIGHT_THRUST := "swordsman_knight_thrust"
const SWORDSMAN_KING_BLADE := "swordsman_king_blade"
const SWORDSMAN_JUDGEMENT_SWORD := "swordsman_judgement_sword"

# 战意：每级 +0.5% 触发概率，最大生命与已损失生命回复各 +0.5%
const BATTLE_WILL_PROC_CHANCE_PER_LEVEL := 0.005
const BATTLE_WILL_HEAL_RATIO_PER_LEVEL := 0.005
# 骑士荣耀：每级 +0.2s 濒死无敌
const KNIGHT_GLORY_INVULNERABILITY_PER_LEVEL := 0.2
# 普通攻击：每级 +10% 伤害倍率（绝对加法）与 +10% 范围（相对乘法），2/4/6/8 级各多一道 60% 斩击
const BASIC_ATTACK_DAMAGE_RATIO_PER_LEVEL := 0.10
const BASIC_ATTACK_RANGE_RATIO_PER_LEVEL := 0.10
const BASIC_ATTACK_EXTRA_SLASH_DAMAGE_SCALE := 0.60
## 追加斩击的依次发射间隔：同方向同时出刀会完全重叠，看不出追加了几道
const BASIC_ATTACK_EXTRA_SLASH_INTERVAL := 0.15
const BASIC_ATTACK_EXTRA_SLASH_FIRST_LEVEL := 2
const BASIC_ATTACK_EXTRA_SLASH_STEP := 2
const BASIC_ATTACK_EXTRA_SLASH_MAX := 4
# 月牙剑气：每级 +15% 伤害倍率（绝对加法）与 +10 飞行速度，2/4/6/8 级各多一道 75% 剑气（体积不变）
const CRESCENT_WAVE_DAMAGE_RATIO_PER_LEVEL := 0.15
const CRESCENT_WAVE_SPEED_PER_LEVEL := 10.0
const CRESCENT_WAVE_EXTRA_WAVE_DAMAGE_SCALE := 0.75
## 追加剑气的依次发射间隔：同方向同时出手会完全重叠，看不出追加了几道
const CRESCENT_WAVE_EXTRA_WAVE_INTERVAL := 0.35
const CRESCENT_WAVE_EXTRA_WAVE_FIRST_LEVEL := 2
const CRESCENT_WAVE_EXTRA_WAVE_STEP := 2
const CRESCENT_WAVE_EXTRA_WAVE_MAX := 4
# 剑刃风暴：每级 +2% 每跳伤害倍率（绝对加法）与 +7.5 半径
const BLADE_STORM_DAMAGE_RATIO_PER_LEVEL := 0.02
const BLADE_STORM_RADIUS_PER_LEVEL := 7.5
# 冲锋：每级 +10% 伤害倍率（绝对加法）与 +20 可指定距离
const ENTRY_DAMAGE_RATIO_PER_LEVEL := 0.10
const ENTRY_DISTANCE_PER_LEVEL := 20.0
# 骑士突：每级 +5% 伤害倍率（绝对加法）与 +1 临时血量，3/6/9 级各多一道 60% 连击突刺
const KNIGHT_THRUST_DAMAGE_RATIO_PER_LEVEL := 0.05
const KNIGHT_THRUST_TEMP_HEALTH_PER_LEVEL := 1.0
const KNIGHT_THRUST_EXTRA_STRIKE_DAMAGE_SCALE := 0.60
const KNIGHT_THRUST_EXTRA_STRIKE_FIRST_LEVEL := 3
const KNIGHT_THRUST_EXTRA_STRIKE_STEP := 3
const KNIGHT_THRUST_EXTRA_STRIKE_MAX := 3
const KNIGHT_THRUST_EXTRA_STRIKE_INTERVAL := 0.5
# 审判之誓：每级 +50% 巨剑伤害倍率与 +10% 冲击波倍率（绝对加法），3/6/9 级各多一道冲击波
const JUDGEMENT_SWORD_FALL_RATIO_PER_LEVEL := 0.50
const JUDGEMENT_SWORD_SHOCKWAVE_RATIO_PER_LEVEL := 0.10
const JUDGEMENT_SWORD_SHOCKWAVE_FIRST_LEVEL := 3
const JUDGEMENT_SWORD_SHOCKWAVE_STEP := 3
const JUDGEMENT_SWORD_SHOCKWAVE_MAX := 3
const JUDGEMENT_SWORD_SHOCKWAVE_INTERVAL := 2.0
# 王者之剑：每级 +10% 伤害倍率（绝对加法）与 +10% 范围（相对乘法）
const KING_BLADE_DAMAGE_RATIO_PER_LEVEL := 0.10
const KING_BLADE_RANGE_RATIO_PER_LEVEL := 0.10

# 枪手技能线
const GUNNER_EXECUTION := "gunner_trait"
const GUNNER_HUNT := "gunner_hunt"
const GUNNER_ENTRY := "gunner_entry"
const GUNNER_BASIC := "gunner_basic"
const GUNNER_SHRAPNEL := "gunner_shrapnel"
const GUNNER_INFINITE_RELOAD := "gunner_infinite_reload"
const GUNNER_EXPLOSIVE_ROUND := "gunner_explosive_round"
const GUNNER_MAGIC_GRENADE := "gunner_magic_grenade"
const GUNNER_MAGIC_EYE := "gunner_magic_eye"

# 瞬杀：每级每层 +0.5% 增伤、+0.5% 移速、+0.35% 闪避率；2/4/6/8/10 级最大层数 +1
const FLASH_DAMAGE_PER_STACK_PER_LEVEL := 0.005
const FLASH_SPEED_PER_STACK_PER_LEVEL := 0.005
const FLASH_DODGE_CHANCE_PER_STACK_PER_LEVEL := 0.0035
const FLASH_MAX_STACK_FIRST_LEVEL := 2
const FLASH_MAX_STACK_STEP := 2
const FLASH_MAX_STACK_MAX := 5
# 猎杀：每级猎杀圈半径 -5、圈外伤害 +1%（绝对加法）
const HUNT_RADIUS_PER_LEVEL := -5.0
const HUNT_OUTSIDE_DAMAGE_PER_LEVEL := 0.01
# 枪手普通攻击：每级 +15 射程、+10 弹道速度；3/6/9 级各获得一枚分裂弹
const GUNNER_BASIC_RANGE_PER_LEVEL := 15.0
const GUNNER_BASIC_BULLET_SPEED_PER_LEVEL := 10.0
const GUNNER_BASIC_SPLIT_FIRST_LEVEL := 3
const GUNNER_BASIC_SPLIT_STEP := 3
const GUNNER_BASIC_SPLIT_MAX := 3
const GUNNER_BASIC_SPLIT_ANGLES := [20.0, -20.0, 40.0]
# 无限装填：每级 +20 射程、+1% 每跳倍率（绝对加法）、+0.5% 移速倍率（绝对加法）
const INFINITE_RELOAD_RANGE_PER_LEVEL := 20.0
const INFINITE_RELOAD_DAMAGE_RATIO_PER_LEVEL := 0.01
const INFINITE_RELOAD_MOVE_SPEED_PER_LEVEL := 0.005
# 散弹：每级 +2% 每跳伤害；3/6/9 级各多一个散弹圈
const SHRAPNEL_DAMAGE_RATIO_PER_LEVEL := 0.02
const SHRAPNEL_FIELD_FIRST_LEVEL := 3
const SHRAPNEL_FIELD_STEP := 3
const SHRAPNEL_FIELD_MAX := 3
# 爆破弹：每级命中与扇形伤害 +10%（绝对加法）、扇形半径 +7.5；3/6/9 级各多一发
const EXPLOSIVE_ROUND_DAMAGE_RATIO_PER_LEVEL := 0.10
const EXPLOSIVE_ROUND_CONE_RADIUS_PER_LEVEL := 7.5
const EXPLOSIVE_ROUND_EXTRA_SHOT_FIRST_LEVEL := 3
const EXPLOSIVE_ROUND_EXTRA_SHOT_STEP := 3
const EXPLOSIVE_ROUND_EXTRA_SHOT_MAX := 3
const EXPLOSIVE_ROUND_EXTRA_SHOT_INTERVAL := 0.2
# 魔法榴弹：每级 +10% 伤害、+5% 额外暴击率（绝对加法）；2/4/6/8 级各多一枚
const MAGIC_GRENADE_DAMAGE_RATIO_PER_LEVEL := 0.10
const MAGIC_GRENADE_CRIT_PER_LEVEL := 0.05
const MAGIC_GRENADE_EXTRA_FIRST_LEVEL := 2
const MAGIC_GRENADE_EXTRA_STEP := 2
const MAGIC_GRENADE_EXTRA_MAX := 4
# 魔眼聚合：每级 +2% 每次伤害、+0.75 护甲降低量
const MAGIC_EYE_DAMAGE_RATIO_PER_LEVEL := 0.02
const MAGIC_EYE_ARMOR_SHRED_PER_LEVEL := 0.75
# 枪火典礼：每级 +10% 每颗子弹伤害、+10 弹道速度
const GUNNER_ENTRY_DAMAGE_RATIO_PER_LEVEL := 0.10
const GUNNER_ENTRY_BULLET_SPEED_PER_LEVEL := 10.0

# 法师技能线
const MAGE_TRAIT := "mage_trait"
const MAGE_ENTRY := "mage_entry"
const MAGE_BASIC := "mage_basic"
const MAGE_META_FIELD := "mage_meta_field"
const MAGE_SURGING_WAVE := "mage_surging_wave"
const MAGE_FLAME_PATH := "mage_flame_path"
const MAGE_DARK_CONTRACT := "mage_dark_contract"
const MAGE_FIREBALL := "mage_fireball"

# 奥数充能：每级 +2% 击杀叠加概率、+0.3% 每层大招回能效率
const ARCANE_CHARGE_PROC_CHANCE_PER_LEVEL := 0.02
const ARCANE_CHARGE_ENERGY_PER_STACK_PER_LEVEL := 0.003
# 奥法盈余：每级 +1.5% 大招回能、切人回能、伤害（仅当前站场角色）
const ARCANE_SURPLUS_BONUS_PER_LEVEL := 0.015
# 法师普通攻击：每级 +10% 雷击范围（相对乘法）与 +10% 伤害倍率（绝对加法）；2/4/6/8/10 级各多一道雷击
const MAGE_BASIC_RANGE_RATIO_PER_LEVEL := 0.10
const MAGE_BASIC_DAMAGE_RATIO_PER_LEVEL := 0.10
const MAGE_BASIC_EXTRA_LIGHTNING_FIRST_LEVEL := 2
const MAGE_BASIC_EXTRA_LIGHTNING_STEP := 2
const MAGE_BASIC_EXTRA_LIGHTNING_MAX := 5
# 梅塔领域：每级 +2.5 护甲、+7.5 半径
const META_FIELD_ARMOR_PER_LEVEL := 2.5
const META_FIELD_RADIUS_PER_LEVEL := 7.5
# 波涛汹涌：每级 +10% 伤害倍率（绝对加法）、+0.2s 持续时间
const SURGING_WAVE_DAMAGE_RATIO_PER_LEVEL := 0.10
const SURGING_WAVE_DURATION_PER_LEVEL := 0.2
# 火球术：每级 +20% 伤害倍率（绝对加法）、+0.5% 灼烧倍率；3/6/9 级灼烧地面 +1s
const FIREBALL_DAMAGE_RATIO_PER_LEVEL := 0.20
const FIREBALL_BURN_RATIO_PER_LEVEL := 0.005
const FIREBALL_GROUND_FIRST_LEVEL := 3
const FIREBALL_GROUND_STEP := 3
const FIREBALL_GROUND_MAX := 3
const FIREBALL_GROUND_DURATION_PER_MILESTONE := 1.0
# 黑暗契约：每级 +2.5 球体速度、+15 最大移动距离、+7.5 吸引半径、+10% 碰撞与爆炸伤害
const DARK_CONTRACT_SPEED_PER_LEVEL := 2.5
const DARK_CONTRACT_DISTANCE_PER_LEVEL := 15.0
const DARK_CONTRACT_ATTRACT_RADIUS_PER_LEVEL := 7.5
const DARK_CONTRACT_DAMAGE_RATIO_PER_LEVEL := 0.10
# 火焰之径：每级 +2.5% 每秒伤害、+0.5% 法师移速倍率
const FLAME_PATH_DAMAGE_PER_SECOND_PER_LEVEL := 0.025
const FLAME_PATH_MOVE_SPEED_PER_LEVEL := 0.005


static func get_mage_arcane_charge_proc_chance_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_TRAIT) * ARCANE_CHARGE_PROC_CHANCE_PER_LEVEL


static func get_mage_arcane_charge_energy_bonus_per_stack(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_TRAIT) * ARCANE_CHARGE_ENERGY_PER_STACK_PER_LEVEL


static func get_mage_arcane_surplus_ultimate_energy_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_ENTRY) * ARCANE_SURPLUS_BONUS_PER_LEVEL


static func get_mage_arcane_surplus_switch_energy_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_ENTRY) * ARCANE_SURPLUS_BONUS_PER_LEVEL


static func get_mage_arcane_surplus_damage_multiplier_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_ENTRY) * ARCANE_SURPLUS_BONUS_PER_LEVEL


static func get_mage_basic_range_multiplier(owner) -> float:
	return 1.0 + _mage_levels_above_first(owner, MAGE_BASIC) * MAGE_BASIC_RANGE_RATIO_PER_LEVEL


static func get_mage_basic_damage_ratio_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_BASIC) * MAGE_BASIC_DAMAGE_RATIO_PER_LEVEL


static func get_mage_basic_extra_lightning_count(owner) -> int:
	return _mage_milestone_count(owner, MAGE_BASIC, MAGE_BASIC_EXTRA_LIGHTNING_FIRST_LEVEL, MAGE_BASIC_EXTRA_LIGHTNING_STEP, MAGE_BASIC_EXTRA_LIGHTNING_MAX)


static func get_mage_meta_field_armor_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_META_FIELD) * META_FIELD_ARMOR_PER_LEVEL


static func get_mage_meta_field_radius_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_META_FIELD) * META_FIELD_RADIUS_PER_LEVEL


static func get_mage_surging_wave_damage_ratio_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_SURGING_WAVE) * SURGING_WAVE_DAMAGE_RATIO_PER_LEVEL


static func get_mage_surging_wave_duration_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_SURGING_WAVE) * SURGING_WAVE_DURATION_PER_LEVEL


static func get_mage_fireball_damage_ratio_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_FIREBALL) * FIREBALL_DAMAGE_RATIO_PER_LEVEL


static func get_mage_fireball_burn_ratio_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_FIREBALL) * FIREBALL_BURN_RATIO_PER_LEVEL


static func get_mage_fireball_ground_duration_bonus(owner) -> float:
	var milestones := _mage_milestone_count(owner, MAGE_FIREBALL, FIREBALL_GROUND_FIRST_LEVEL, FIREBALL_GROUND_STEP, FIREBALL_GROUND_MAX)
	return float(milestones) * FIREBALL_GROUND_DURATION_PER_MILESTONE


static func get_mage_dark_contract_speed_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_DARK_CONTRACT) * DARK_CONTRACT_SPEED_PER_LEVEL


static func get_mage_dark_contract_distance_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_DARK_CONTRACT) * DARK_CONTRACT_DISTANCE_PER_LEVEL


static func get_mage_dark_contract_attract_radius_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_DARK_CONTRACT) * DARK_CONTRACT_ATTRACT_RADIUS_PER_LEVEL


static func get_mage_dark_contract_damage_ratio_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_DARK_CONTRACT) * DARK_CONTRACT_DAMAGE_RATIO_PER_LEVEL


static func get_mage_flame_path_damage_per_second_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_FLAME_PATH) * FLAME_PATH_DAMAGE_PER_SECOND_PER_LEVEL


static func get_mage_flame_path_move_speed_bonus(owner) -> float:
	return _mage_levels_above_first(owner, MAGE_FLAME_PATH) * FLAME_PATH_MOVE_SPEED_PER_LEVEL


static func _mage_level(owner, progress_id: String) -> int:
	return PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, "mage", progress_id)


static func _mage_levels_above_first(owner, progress_id: String) -> int:
	return maxi(0, _mage_level(owner, progress_id) - 1)


static func _mage_milestone_count(owner, progress_id: String, first_level: int, step: int, max_count: int) -> int:
	return _milestone_count(_mage_level(owner, progress_id), first_level, step, max_count)


static func get_gunner_flash_damage_bonus_per_stack(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_EXECUTION) * FLASH_DAMAGE_PER_STACK_PER_LEVEL


static func get_gunner_flash_speed_bonus_per_stack(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_EXECUTION) * FLASH_SPEED_PER_STACK_PER_LEVEL


static func get_gunner_flash_dodge_chance_bonus_per_stack(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_EXECUTION) * FLASH_DODGE_CHANCE_PER_STACK_PER_LEVEL


static func get_gunner_flash_max_stack_bonus(owner) -> int:
	return _gunner_milestone_count(owner, GUNNER_EXECUTION, FLASH_MAX_STACK_FIRST_LEVEL, FLASH_MAX_STACK_STEP, FLASH_MAX_STACK_MAX)


static func get_gunner_hunt_radius_bonus(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_HUNT) * HUNT_RADIUS_PER_LEVEL


static func get_gunner_hunt_outside_damage_bonus(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_HUNT) * HUNT_OUTSIDE_DAMAGE_PER_LEVEL


static func get_gunner_basic_range_bonus(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_BASIC) * GUNNER_BASIC_RANGE_PER_LEVEL


static func get_gunner_basic_bullet_speed_bonus(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_BASIC) * GUNNER_BASIC_BULLET_SPEED_PER_LEVEL


static func get_gunner_basic_split_bullet_count(owner) -> int:
	return _gunner_milestone_count(owner, GUNNER_BASIC, GUNNER_BASIC_SPLIT_FIRST_LEVEL, GUNNER_BASIC_SPLIT_STEP, GUNNER_BASIC_SPLIT_MAX)


static func get_gunner_basic_split_angle_degrees(index: int) -> float:
	if index < 0 or index >= GUNNER_BASIC_SPLIT_ANGLES.size():
		return 0.0
	return float(GUNNER_BASIC_SPLIT_ANGLES[index])


static func get_gunner_infinite_reload_range_bonus(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_INFINITE_RELOAD) * INFINITE_RELOAD_RANGE_PER_LEVEL


static func get_gunner_infinite_reload_damage_ratio_bonus(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_INFINITE_RELOAD) * INFINITE_RELOAD_DAMAGE_RATIO_PER_LEVEL


static func get_gunner_infinite_reload_move_speed_bonus(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_INFINITE_RELOAD) * INFINITE_RELOAD_MOVE_SPEED_PER_LEVEL


static func get_gunner_shrapnel_damage_ratio_bonus(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_SHRAPNEL) * SHRAPNEL_DAMAGE_RATIO_PER_LEVEL


static func get_gunner_shrapnel_extra_field_count(owner) -> int:
	return _gunner_milestone_count(owner, GUNNER_SHRAPNEL, SHRAPNEL_FIELD_FIRST_LEVEL, SHRAPNEL_FIELD_STEP, SHRAPNEL_FIELD_MAX)


static func get_gunner_explosive_round_damage_ratio_bonus(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_EXPLOSIVE_ROUND) * EXPLOSIVE_ROUND_DAMAGE_RATIO_PER_LEVEL


static func get_gunner_explosive_round_cone_radius_bonus(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_EXPLOSIVE_ROUND) * EXPLOSIVE_ROUND_CONE_RADIUS_PER_LEVEL


static func get_gunner_explosive_round_extra_shot_count(owner) -> int:
	return _gunner_milestone_count(owner, GUNNER_EXPLOSIVE_ROUND, EXPLOSIVE_ROUND_EXTRA_SHOT_FIRST_LEVEL, EXPLOSIVE_ROUND_EXTRA_SHOT_STEP, EXPLOSIVE_ROUND_EXTRA_SHOT_MAX)


static func get_gunner_magic_grenade_damage_ratio_bonus(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_MAGIC_GRENADE) * MAGIC_GRENADE_DAMAGE_RATIO_PER_LEVEL


static func get_gunner_magic_grenade_crit_bonus(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_MAGIC_GRENADE) * MAGIC_GRENADE_CRIT_PER_LEVEL


static func get_gunner_magic_grenade_extra_count(owner) -> int:
	return _gunner_milestone_count(owner, GUNNER_MAGIC_GRENADE, MAGIC_GRENADE_EXTRA_FIRST_LEVEL, MAGIC_GRENADE_EXTRA_STEP, MAGIC_GRENADE_EXTRA_MAX)


static func get_gunner_magic_eye_damage_ratio_bonus(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_MAGIC_EYE) * MAGIC_EYE_DAMAGE_RATIO_PER_LEVEL


static func get_gunner_magic_eye_armor_shred_bonus(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_MAGIC_EYE) * MAGIC_EYE_ARMOR_SHRED_PER_LEVEL


static func get_gunner_entry_damage_ratio_bonus(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_ENTRY) * GUNNER_ENTRY_DAMAGE_RATIO_PER_LEVEL


static func get_gunner_entry_bullet_speed_bonus(owner) -> float:
	return _gunner_levels_above_first(owner, GUNNER_ENTRY) * GUNNER_ENTRY_BULLET_SPEED_PER_LEVEL


static func _gunner_level(owner, progress_id: String) -> int:
	return PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, "gunner", progress_id)


static func _gunner_levels_above_first(owner, progress_id: String) -> int:
	return maxi(0, _gunner_level(owner, progress_id) - 1)


static func _gunner_milestone_count(owner, progress_id: String, first_level: int, step: int, max_count: int) -> int:
	return _milestone_count(_gunner_level(owner, progress_id), first_level, step, max_count)


static func get_swordsman_battle_will_proc_chance_bonus(owner) -> float:
	return _levels_above_first(owner, SWORDSMAN_TRAIT) * BATTLE_WILL_PROC_CHANCE_PER_LEVEL


static func get_swordsman_battle_will_heal_ratio_bonus(owner) -> float:
	return _levels_above_first(owner, SWORDSMAN_TRAIT) * BATTLE_WILL_HEAL_RATIO_PER_LEVEL


static func get_swordsman_knight_glory_invulnerability_bonus(owner) -> float:
	return _levels_above_first(owner, SWORDSMAN_TRAIT) * KNIGHT_GLORY_INVULNERABILITY_PER_LEVEL


static func get_swordsman_basic_attack_damage_ratio_bonus(owner) -> float:
	return _levels_above_first(owner, SWORDSMAN_BASIC) * BASIC_ATTACK_DAMAGE_RATIO_PER_LEVEL


static func get_swordsman_basic_attack_range_multiplier(owner) -> float:
	return 1.0 + _levels_above_first(owner, SWORDSMAN_BASIC) * BASIC_ATTACK_RANGE_RATIO_PER_LEVEL


static func get_swordsman_basic_attack_extra_slash_count(owner) -> int:
	return _milestone_count(
		_get_level(owner, SWORDSMAN_BASIC),
		BASIC_ATTACK_EXTRA_SLASH_FIRST_LEVEL,
		BASIC_ATTACK_EXTRA_SLASH_STEP,
		BASIC_ATTACK_EXTRA_SLASH_MAX
	)


static func get_swordsman_crescent_wave_damage_ratio_bonus(owner) -> float:
	return _levels_above_first(owner, SWORDSMAN_CRESCENT_WAVE) * CRESCENT_WAVE_DAMAGE_RATIO_PER_LEVEL


static func get_swordsman_crescent_wave_speed_bonus(owner) -> float:
	return _levels_above_first(owner, SWORDSMAN_CRESCENT_WAVE) * CRESCENT_WAVE_SPEED_PER_LEVEL


static func get_swordsman_crescent_wave_extra_wave_count(owner) -> int:
	return _milestone_count(
		_get_level(owner, SWORDSMAN_CRESCENT_WAVE),
		CRESCENT_WAVE_EXTRA_WAVE_FIRST_LEVEL,
		CRESCENT_WAVE_EXTRA_WAVE_STEP,
		CRESCENT_WAVE_EXTRA_WAVE_MAX
	)


static func get_swordsman_blade_storm_damage_ratio_bonus(owner) -> float:
	return _levels_above_first(owner, SWORDSMAN_BLADE_STORM) * BLADE_STORM_DAMAGE_RATIO_PER_LEVEL


static func get_swordsman_blade_storm_radius_bonus(owner) -> float:
	return _levels_above_first(owner, SWORDSMAN_BLADE_STORM) * BLADE_STORM_RADIUS_PER_LEVEL


static func get_swordsman_entry_damage_ratio_bonus(owner) -> float:
	return _levels_above_first(owner, SWORDSMAN_ENTRY) * ENTRY_DAMAGE_RATIO_PER_LEVEL


static func get_swordsman_entry_distance_bonus(owner) -> float:
	return _levels_above_first(owner, SWORDSMAN_ENTRY) * ENTRY_DISTANCE_PER_LEVEL


static func get_swordsman_knight_thrust_damage_ratio_bonus(owner) -> float:
	return _levels_above_first(owner, SWORDSMAN_KNIGHT_THRUST) * KNIGHT_THRUST_DAMAGE_RATIO_PER_LEVEL


static func get_swordsman_knight_thrust_temp_health_bonus(owner) -> float:
	return _levels_above_first(owner, SWORDSMAN_KNIGHT_THRUST) * KNIGHT_THRUST_TEMP_HEALTH_PER_LEVEL


static func get_swordsman_knight_thrust_extra_strike_count(owner) -> int:
	return _milestone_count(
		_get_level(owner, SWORDSMAN_KNIGHT_THRUST),
		KNIGHT_THRUST_EXTRA_STRIKE_FIRST_LEVEL,
		KNIGHT_THRUST_EXTRA_STRIKE_STEP,
		KNIGHT_THRUST_EXTRA_STRIKE_MAX
	)


static func get_swordsman_judgement_sword_fall_ratio_bonus(owner) -> float:
	return _levels_above_first(owner, SWORDSMAN_JUDGEMENT_SWORD) * JUDGEMENT_SWORD_FALL_RATIO_PER_LEVEL


static func get_swordsman_judgement_sword_shockwave_ratio_bonus(owner) -> float:
	return _levels_above_first(owner, SWORDSMAN_JUDGEMENT_SWORD) * JUDGEMENT_SWORD_SHOCKWAVE_RATIO_PER_LEVEL


static func get_swordsman_judgement_sword_shockwave_count(owner) -> int:
	return 1 + _milestone_count(
		_get_level(owner, SWORDSMAN_JUDGEMENT_SWORD),
		JUDGEMENT_SWORD_SHOCKWAVE_FIRST_LEVEL,
		JUDGEMENT_SWORD_SHOCKWAVE_STEP,
		JUDGEMENT_SWORD_SHOCKWAVE_MAX
	)


static func get_swordsman_king_blade_damage_ratio_bonus(owner) -> float:
	return _levels_above_first(owner, SWORDSMAN_KING_BLADE) * KING_BLADE_DAMAGE_RATIO_PER_LEVEL


static func get_swordsman_king_blade_range_multiplier(owner) -> float:
	return 1.0 + _levels_above_first(owner, SWORDSMAN_KING_BLADE) * KING_BLADE_RANGE_RATIO_PER_LEVEL


## 返回“再升一级”会获得的收益文案，用于升级卡与角色面板预览。
static func get_upgrade_preview_text(owner, role_id: String, progress_id: String) -> String:
	match role_id:
		"swordsman":
			return _get_swordsman_upgrade_preview(owner, progress_id)
		"gunner":
			return _get_gunner_upgrade_preview(owner, progress_id)
		"mage":
			return _get_mage_upgrade_preview(owner, progress_id)
	return ""


static func _get_swordsman_upgrade_preview(owner, progress_id: String) -> String:
	var level := _get_level(owner, progress_id)
	if level <= 0 or level >= PLAYER_SKILL_LEVEL_SYSTEM.MAX_SKILL_LEVEL:
		return ""
	var next_level := level + 1
	var parts: Array[String] = []
	match progress_id:
		SWORDSMAN_TRAIT:
			parts.append("战意触发概率 +0.5%")
			parts.append("最大生命与已损失生命回复各 +0.5%")
			parts.append("濒死无敌 +0.2s")
		SWORDSMAN_ENTRY:
			parts.append("冲锋伤害倍率 +10%")
			parts.append("冲锋可指定距离 +20")
		SWORDSMAN_BASIC:
			parts.append("伤害倍率 +10%")
			parts.append("范围 +10%")
		SWORDSMAN_BLADE_STORM:
			parts.append("每跳伤害倍率 +2%")
			parts.append("半径 +7.5")
		SWORDSMAN_CRESCENT_WAVE:
			parts.append("伤害倍率 +15%")
			parts.append("飞行速度 +10")
		SWORDSMAN_KNIGHT_THRUST:
			parts.append("伤害倍率 +5%")
			parts.append("每次命中临时血量 +1")
		SWORDSMAN_KING_BLADE:
			parts.append("伤害倍率 +10%")
			parts.append("范围 +10%")
		SWORDSMAN_JUDGEMENT_SWORD:
			parts.append("巨剑伤害倍率 +50%")
			parts.append("冲击波倍率 +10%")
		_:
			return ""
	var milestone_text := _get_milestone_preview_text(progress_id, next_level)
	if milestone_text != "":
		parts.append(milestone_text)
	if next_level == PLAYER_SKILL_LEVEL_SYSTEM.TALENT_PICK_LEVEL:
		parts.append("开启天赋位选择")
	return "；".join(parts)


static func _get_milestone_preview_text(progress_id: String, next_level: int) -> String:
	match progress_id:
		SWORDSMAN_BASIC:
			if _is_milestone_level(next_level, BASIC_ATTACK_EXTRA_SLASH_FIRST_LEVEL, BASIC_ATTACK_EXTRA_SLASH_STEP, BASIC_ATTACK_EXTRA_SLASH_MAX):
				return "追加一道 60% 伤害的斩击"
		SWORDSMAN_CRESCENT_WAVE:
			if _is_milestone_level(next_level, CRESCENT_WAVE_EXTRA_WAVE_FIRST_LEVEL, CRESCENT_WAVE_EXTRA_WAVE_STEP, CRESCENT_WAVE_EXTRA_WAVE_MAX):
				return "追加一道 75% 伤害的剑气"
		SWORDSMAN_KNIGHT_THRUST:
			if _is_milestone_level(next_level, KNIGHT_THRUST_EXTRA_STRIKE_FIRST_LEVEL, KNIGHT_THRUST_EXTRA_STRIKE_STEP, KNIGHT_THRUST_EXTRA_STRIKE_MAX):
				return "追加一道 60% 伤害的连击突刺"
		SWORDSMAN_JUDGEMENT_SWORD:
			if _is_milestone_level(next_level, JUDGEMENT_SWORD_SHOCKWAVE_FIRST_LEVEL, JUDGEMENT_SWORD_SHOCKWAVE_STEP, JUDGEMENT_SWORD_SHOCKWAVE_MAX):
				return "追加一道冲击波"
	return ""


static func _is_milestone_level(level: int, first_level: int, step: int, max_count: int) -> bool:
	if level < first_level or step <= 0:
		return false
	if (level - first_level) % step != 0:
		return false
	return (level - first_level) / step < max_count


static func _get_gunner_upgrade_preview(owner, progress_id: String) -> String:
	var level := _gunner_level(owner, progress_id)
	if level <= 0 or level >= PLAYER_SKILL_LEVEL_SYSTEM.MAX_SKILL_LEVEL:
		return ""
	var next_level := level + 1
	var parts: Array[String] = []
	match progress_id:
		GUNNER_EXECUTION:
			parts.append("每层增伤 +0.5%")
			parts.append("每层移速 +0.5%")
			parts.append("每层闪避率 +0.35%")
		GUNNER_HUNT:
			parts.append("猎杀圈半径 -5")
			parts.append("圈外伤害 +1%")
		GUNNER_ENTRY:
			parts.append("每颗子弹伤害 +10%")
			parts.append("弹道速度 +10")
		GUNNER_BASIC:
			parts.append("射程 +15")
			parts.append("弹道速度 +10")
		GUNNER_SHRAPNEL:
			parts.append("每跳伤害 +2%")
		GUNNER_INFINITE_RELOAD:
			parts.append("射程 +20")
			parts.append("每跳伤害倍率 +1%")
			parts.append("移速倍率 +0.5%")
		GUNNER_EXPLOSIVE_ROUND:
			parts.append("命中与扇形伤害 +10%")
			parts.append("扇形半径 +7.5")
		GUNNER_MAGIC_GRENADE:
			parts.append("伤害 +10%")
			parts.append("暴击率 +5%")
		GUNNER_MAGIC_EYE:
			parts.append("每次伤害 +2%")
			parts.append("命中降低护甲额外 +0.75")
		_:
			return ""
	var milestone_text := _get_gunner_milestone_preview_text(progress_id, next_level)
	if milestone_text != "":
		parts.append(milestone_text)
	if next_level == PLAYER_SKILL_LEVEL_SYSTEM.TALENT_PICK_LEVEL:
		parts.append("开启天赋位选择")
	return "；".join(parts)


static func _get_gunner_milestone_preview_text(progress_id: String, next_level: int) -> String:
	match progress_id:
		GUNNER_EXECUTION:
			if _is_milestone_level(next_level, FLASH_MAX_STACK_FIRST_LEVEL, FLASH_MAX_STACK_STEP, FLASH_MAX_STACK_MAX):
				return "瞬杀最大层数 +1"
		GUNNER_BASIC:
			if _is_milestone_level(next_level, GUNNER_BASIC_SPLIT_FIRST_LEVEL, GUNNER_BASIC_SPLIT_STEP, GUNNER_BASIC_SPLIT_MAX):
				return "获得一枚分裂弹"
		GUNNER_SHRAPNEL:
			if _is_milestone_level(next_level, SHRAPNEL_FIELD_FIRST_LEVEL, SHRAPNEL_FIELD_STEP, SHRAPNEL_FIELD_MAX):
				return "多一个散弹圈"
		GUNNER_EXPLOSIVE_ROUND:
			if _is_milestone_level(next_level, EXPLOSIVE_ROUND_EXTRA_SHOT_FIRST_LEVEL, EXPLOSIVE_ROUND_EXTRA_SHOT_STEP, EXPLOSIVE_ROUND_EXTRA_SHOT_MAX):
				return "多发射一枚爆破弹"
		GUNNER_MAGIC_GRENADE:
			if _is_milestone_level(next_level, MAGIC_GRENADE_EXTRA_FIRST_LEVEL, MAGIC_GRENADE_EXTRA_STEP, MAGIC_GRENADE_EXTRA_MAX):
				return "多发射一枚魔法榴弹"
	return ""


static func _get_mage_upgrade_preview(owner, progress_id: String) -> String:
	var level := _mage_level(owner, progress_id)
	if level <= 0 or level >= PLAYER_SKILL_LEVEL_SYSTEM.MAX_SKILL_LEVEL:
		return ""
	var next_level := level + 1
	var parts: Array[String] = []
	match progress_id:
		MAGE_TRAIT:
			parts.append("击杀叠加奥数充能概率 +2%")
			parts.append("每层大招回能效率 +0.3%")
		MAGE_ENTRY:
			parts.append("奥法盈余：大招回能 +1.5%")
			parts.append("切人回能 +1.5%")
			parts.append("伤害 +1.5%")
		MAGE_BASIC:
			parts.append("雷击范围 +10%")
			parts.append("伤害倍率 +10%")
		MAGE_META_FIELD:
			parts.append("护甲 +2.5")
			parts.append("领域半径 +7.5")
		MAGE_SURGING_WAVE:
			parts.append("伤害倍率 +10%")
			parts.append("持续时间 +0.2s")
		MAGE_FIREBALL:
			parts.append("伤害倍率 +20%")
			parts.append("灼烧倍率 +0.5%")
		MAGE_DARK_CONTRACT:
			parts.append("球体速度 +2.5")
			parts.append("最大移动距离 +15")
			parts.append("吸引半径 +7.5")
			parts.append("碰撞与爆炸伤害 +10%")
		MAGE_FLAME_PATH:
			parts.append("路径每秒伤害 +2.5%")
			parts.append("法师移速倍率 +0.5%")
		_:
			return ""
	var milestone_text := _get_mage_milestone_preview_text(progress_id, next_level)
	if milestone_text != "":
		parts.append(milestone_text)
	if next_level == PLAYER_SKILL_LEVEL_SYSTEM.TALENT_PICK_LEVEL:
		parts.append("开启天赋位选择")
	return "；".join(parts)


static func _get_mage_milestone_preview_text(progress_id: String, next_level: int) -> String:
	match progress_id:
		MAGE_BASIC:
			if _is_milestone_level(next_level, MAGE_BASIC_EXTRA_LIGHTNING_FIRST_LEVEL, MAGE_BASIC_EXTRA_LIGHTNING_STEP, MAGE_BASIC_EXTRA_LIGHTNING_MAX):
				return "追加一道雷击"
		MAGE_FIREBALL:
			if _is_milestone_level(next_level, FIREBALL_GROUND_FIRST_LEVEL, FIREBALL_GROUND_STEP, FIREBALL_GROUND_MAX):
				return "灼烧地面持续时间 +1s"
	return ""


static func get_swordsman_skills_summary(owner) -> String:
	var parts := PackedStringArray()
	for progress_id in [
		SWORDSMAN_TRAIT,
		SWORDSMAN_ENTRY,
		SWORDSMAN_BASIC,
		SWORDSMAN_BLADE_STORM,
		SWORDSMAN_CRESCENT_WAVE,
		SWORDSMAN_KNIGHT_THRUST,
		SWORDSMAN_KING_BLADE,
		SWORDSMAN_JUDGEMENT_SWORD
	]:
		var level := _get_level(owner, progress_id)
		if level > 0:
			parts.append("%s Lv.%d" % [PLAYER_SKILL_LEVEL_SYSTEM.get_progress_title(progress_id), level])
	return " · ".join(parts)


static func _get_level(owner, progress_id: String) -> int:
	return PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, "swordsman", progress_id)


static func _levels_above_first(owner, progress_id: String) -> int:
	return maxi(0, _get_level(owner, progress_id) - 1)


static func _milestone_count(level: int, first_level: int, step: int, max_count: int) -> int:
	if level < first_level or step <= 0 or max_count <= 0:
		return 0
	return mini(max_count, 1 + (level - first_level) / step)

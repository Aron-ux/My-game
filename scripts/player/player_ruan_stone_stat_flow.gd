extends RefCounted

const SYSTEM := preload("res://scripts/player/ruan_stone_system.gd")

static func has(owner, stone_id: String) -> bool:
	return owner != null and owner.has_method("get_purchased_ruan_stones") and stone_id in owner.get_purchased_ruan_stones()

static func get_damage_bonus(owner) -> float:
	return (0.05 if has(owner, "broken_sword") else 0.0) + (0.08 if has(owner, "ground_branch") else 0.0)

static func get_attack_bonus(owner) -> float:
	return 2.0 if has(owner, "broken_sword") else 0.0

static func get_speed_bonus(owner) -> float:
	return 10.0 if has(owner, "tattered_cloak") else 0.0

static func get_damage_reduction_bonus(owner) -> float:
	return (20.0 if has(owner, "ground_branch") else 0.0) + (20.0 if has(owner, "broken_chestplate") else 0.0)

static func get_max_health_bonus(owner) -> float:
	return 30.0 if has(owner, "broken_chestplate") else 0.0

static func get_critical_chance_bonus(owner) -> float:
	return 0.08 if has(owner, "rusted_dagger") else 0.0

static func get_critical_damage_bonus(owner) -> float:
	return 0.08 if has(owner, "rusted_dagger") else 0.0

extends RefCounted

const ROLE_ATTRIBUTE_RULES := preload("res://scripts/player/roles/role_attribute_rules.gd")

static func get_enemy_meta_int(enemy: Node, key: String) -> int:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_meta(key):
		return 0
	return int(enemy.get_meta(key))

static func get_enemy_meta_float(enemy: Node, key: String) -> float:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_meta(key):
		return 0.0
	return float(enemy.get_meta(key))

static func apply_role_damage_lifesteal(owner, source_role_id: String, damage_amount: float) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	if source_role_id != "swordsman":
		return
	if damage_amount <= 0.0:
		return
	if not owner.has_method("_get_role_attribute_level"):
		return

	var trait_level: float = float(owner._get_role_attribute_level("swordsman", "swordsman_trait"))
	var proc_chance: float = ROLE_ATTRIBUTE_RULES.get_swordsman_trait_heal_proc_chance(trait_level)
	if randf() > min(proc_chance, 1.0):
		return

	if float(owner.get("lifesteal_proc_cooldown_remaining")) > 0.0:
		return

	var role_max_health: float = 1.0
	if owner.has_method("_get_role_max_health"):
		role_max_health = max(1.0, float(owner._get_role_max_health("swordsman")))
	var role_current_health: float = role_max_health
	if owner.has_method("_get_role_current_health"):
		role_current_health = clamp(float(owner._get_role_current_health("swordsman")), 0.0, role_max_health)

	var heal_ratio: float = ROLE_ATTRIBUTE_RULES.get_swordsman_trait_heal_amount(trait_level)
	var missing_heal_ratio: float = ROLE_ATTRIBUTE_RULES.SWORDSMAN_TRAIT_MISSING_HEAL_RATIO
	var heal_amount: float = role_max_health * heal_ratio + max(0.0, role_max_health - role_current_health) * missing_heal_ratio

	var active_role_id: String = ""
	if owner.has_method("_get_active_role"):
		active_role_id = str(owner._get_active_role().get("id", ""))
	if active_role_id == "swordsman" and float(owner.get("switch_invulnerability_remaining")) > 0.0:
		heal_amount *= 2.0

	if owner.has_method("_heal"):
		owner._heal(heal_amount)
	if active_role_id == "swordsman" and float(owner.get("switch_invulnerability_remaining")) > 0.0 and owner.has_method("_add_all_role_current_health"):
		owner._add_all_role_current_health(heal_amount)

	owner.lifesteal_proc_cooldown_remaining = ROLE_ATTRIBUTE_RULES.SWORDSMAN_TRAIT_HEAL_COOLDOWN

static func get_gunner_distance_damage_multiplier(distance: float, trait_bonus: float = 0.0) -> float:
	var safe_distance: float = max(0.0, distance)
	if safe_distance <= 115.0:
		return 0.4
	var outside_distance: float = safe_distance - 115.0
	var multiplier: float = 1.0 + outside_distance / 100.0 * 0.05 + max(0.0, trait_bonus)
	return max(0.4, multiplier)

static func get_enemy_hit_radius(enemy: Node) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return 12.0
	var enemy_contact_radius: Variant = enemy.get("contact_radius")
	if enemy_contact_radius == null:
		return 12.0
	return clamp(float(enemy_contact_radius) * 0.42, 10.0, 28.0)

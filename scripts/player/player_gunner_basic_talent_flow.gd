extends RefCounted

const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")
const PLAYER_COMBAT_MODIFIERS := preload("res://scripts/player/player_combat_modifiers.gd")

const TALENT_BASIC_ATTACK_1 := "gunner_level_talent_basic_attack_1"
const TALENT_BASIC_ATTACK_2 := "gunner_level_talent_basic_attack_2"
const BASIC_SOURCE_PREFIX := "gunner_basic:"

const TIMED_ARMOR_SHRED_META := "gunner_timed_armor_shred_entries"

const BASIC_ATTACK_1_SPEED_BONUS := 150.0
const BASIC_ATTACK_1_DAMAGE_MULTIPLIER := 1.20
const BASIC_ATTACK_1_ARMOR_SHRED_PER_HIT := 2.0
const BASIC_ATTACK_2_PRE_SPLIT_DAMAGE_MULTIPLIER := 0.80
const BASIC_ATTACK_2_SPLIT_DAMAGE_MULTIPLIER := 0.50
const BASIC_ATTACK_2_SPLIT_COUNT := 3
const BASIC_ATTACK_2_SPLIT_ARC_DEGREES := 60.0
const BASIC_ATTACK_2_SPLIT_LIFETIME_SCALE := 0.72
const BASIC_ATTACK_2_SPLIT_SPEED_SCALE := 0.92
const BASIC_ATTACK_2_SPLIT_DISTANCE_BONUS := 100.0
const BASIC_ATTACK_2_SPLIT_VISUAL_SCALE := 0.88
const BASIC_ATTACK_CAMERA_SHAKE_STRENGTH := 5.8
const BASIC_ATTACK_CAMERA_SHAKE_DURATION := 0.12


static func has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)


static func get_basic_damage_multiplier(owner) -> float:
	return BASIC_ATTACK_1_DAMAGE_MULTIPLIER if has_level_talent(owner, TALENT_BASIC_ATTACK_1) else 1.0


static func get_basic_speed_bonus(owner) -> float:
	return BASIC_ATTACK_1_SPEED_BONUS if has_level_talent(owner, TALENT_BASIC_ATTACK_1) else 0.0


static func get_pre_split_damage_multiplier(owner) -> float:
	return BASIC_ATTACK_2_PRE_SPLIT_DAMAGE_MULTIPLIER if has_level_talent(owner, TALENT_BASIC_ATTACK_2) else 1.0


static func get_modified_basic_damage(owner, damage_amount: float) -> float:
	return damage_amount * get_basic_damage_multiplier(owner) * get_pre_split_damage_multiplier(owner)


static func get_split_damage(owner, damage_amount: float) -> float:
	if not has_level_talent(owner, TALENT_BASIC_ATTACK_2):
		return 0.0
	return damage_amount * get_basic_damage_multiplier(owner) * BASIC_ATTACK_2_SPLIT_DAMAGE_MULTIPLIER


static func build_projectile_config(owner, base_config: Dictionary, base_damage_amount: float = 0.0) -> Dictionary:
	var config := base_config.duplicate(true)
	if has_level_talent(owner, TALENT_BASIC_ATTACK_2):
		config["gunner_basic_split_enabled"] = true
		config["gunner_basic_split_count"] = BASIC_ATTACK_2_SPLIT_COUNT
		config["gunner_basic_split_arc_degrees"] = BASIC_ATTACK_2_SPLIT_ARC_DEGREES
		config["gunner_basic_split_damage"] = get_split_damage(owner, base_damage_amount)
		config["gunner_basic_split_lifetime_scale"] = BASIC_ATTACK_2_SPLIT_LIFETIME_SCALE
		config["gunner_basic_split_speed_scale"] = BASIC_ATTACK_2_SPLIT_SPEED_SCALE
		config["gunner_basic_split_distance_bonus"] = BASIC_ATTACK_2_SPLIT_DISTANCE_BONUS
		config["gunner_basic_split_visual_scale"] = BASIC_ATTACK_2_SPLIT_VISUAL_SCALE
	return config


static func should_apply_basic_armor_shred(source_role_id: String) -> bool:
	return source_role_id.begins_with(BASIC_SOURCE_PREFIX)


static func apply_basic_armor_shred(enemy: Node, source_role_id: String, shred_value: float = BASIC_ATTACK_1_ARMOR_SHRED_PER_HIT) -> void:
	if enemy == null or not is_instance_valid(enemy) or not should_apply_basic_armor_shred(source_role_id) or shred_value <= 0.0:
		return
	if enemy.get("damage_reduction_value") == null:
		return
	enemy.damage_reduction_value = float(enemy.damage_reduction_value) - shred_value


static func apply_timed_armor_shred(enemy: Node, shred_value: float, duration: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or shred_value <= 0.0 or duration <= 0.0:
		return
	var entries: Array = _get_active_timed_armor_shred_entries(enemy)
	entries.append({
		"value": shred_value,
		"expires_at": Time.get_ticks_msec() * 0.001 + duration
	})
	enemy.set_meta(TIMED_ARMOR_SHRED_META, entries)


static func on_basic_attack_hit(owner, enemy: Node, source_role_id: String) -> void:
	if owner == null or not should_apply_basic_armor_shred(source_role_id):
		return
	if owner.has_method("_queue_camera_shake"):
		owner._queue_camera_shake(BASIC_ATTACK_CAMERA_SHAKE_STRENGTH, BASIC_ATTACK_CAMERA_SHAKE_DURATION)
	if not has_level_talent(owner, TALENT_BASIC_ATTACK_1):
		return
	apply_basic_armor_shred(enemy, source_role_id, BASIC_ATTACK_1_ARMOR_SHRED_PER_HIT)


static func get_enemy_damage_taken_multiplier(enemy: Node) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return 1.0
	var damage_reduction_rate := PLAYER_COMBAT_MODIFIERS.calculate_damage_reduction_rate(get_effective_damage_reduction_value(enemy))
	return max(0.0, 1.0 - damage_reduction_rate)


static func get_effective_damage_reduction_value(enemy: Node) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return 0.0
	var base_value: Variant = enemy.get("damage_reduction_value")
	if base_value == null:
		return 0.0
	return float(base_value) - _get_active_timed_armor_shred_value(enemy)


static func _get_active_timed_armor_shred_value(enemy: Node) -> float:
	var total := 0.0
	for entry in _get_active_timed_armor_shred_entries(enemy):
		if entry is Dictionary:
			total += max(0.0, float((entry as Dictionary).get("value", 0.0)))
	return total


static func _get_active_timed_armor_shred_entries(enemy: Node) -> Array:
	if enemy == null or not is_instance_valid(enemy):
		return []
	var raw_entries: Variant = enemy.get_meta(TIMED_ARMOR_SHRED_META, [])
	var now := Time.get_ticks_msec() * 0.001
	var active_entries: Array = []
	if raw_entries is Array:
		for entry_value in raw_entries:
			if entry_value is not Dictionary:
				continue
			var entry: Dictionary = entry_value
			if float(entry.get("expires_at", 0.0)) <= now:
				continue
			active_entries.append(entry.duplicate(true))
	enemy.set_meta(TIMED_ARMOR_SHRED_META, active_entries)
	return active_entries

extends RefCounted

const FIELD_EFFECT_SCENE := preload("res://effects/wizard/field/field.tscn")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_MAGE_META_FIELD_TALENT_FLOW := preload("res://scripts/player/player_mage_meta_field_talent_flow.gd")
const PLAYER_SKILL_LEVEL_EFFECT_FLOW := preload("res://scripts/player/player_skill_level_effect_flow.gd")
const BUILD := preload("res://scripts/player/player_mage_meta_field_build.gd")

const SKILL_ID := "meta_field"
const COOLDOWN := 0.0
const PERMANENT_ACTIVE_REMAINING := 1.0
const TIER_ONE_SLOW := 0.50
const TIER_TWO_SLOW := 0.40
const TIER_THREE_SLOW := 0.20
const BASE_ARMOR_BONUS := 25.0
const TIER_ONE_DAMAGE_RATIO := 0.10
const TIER_TWO_DAMAGE_RATIO := 0.28
const TIER_THREE_DAMAGE_RATIO := 0.38
const TIER_ONE_RADIUS := 75.0
const TIER_TWO_RADIUS := 190.0
const TIER_THREE_RADIUS := 218.6
const RADIUS_BONUS_PER_TIER := 0.10
const SLOW_EFFECT_BONUS_PER_TIER := 0.10
const DAMAGE_RATIO_BONUS_PER_TIER := 0.02
const FIELD_SIZE_MULTIPLIER := 0.70
const TICK_INTERVAL := 0.7
const MAX_CATCH_UP_TICKS := 4
const TRANSFER_DURATION := 4.0
const COLLAPSE_COOLDOWN := 8.0
const TALENT_IDS := [
	"mage_meta_guard_pulse",
	"mage_meta_transfer",
	"mage_meta_collapse",
	"mage_meta_expansion",
	"mage_meta_inner_ring",
	"mage_meta_stasis"
]

var cooldown_remaining: float = 0.0
var active_remaining: float = 0.0
var tick_remaining: float = 0.0
var transferred_role_id: String = ""
var effect: Node2D
var effect_pool: Array[Node2D] = []
var expansion_tick_count: int = 0
var inner_ring_enemy_ids: Dictionary = {}
var cast_talent_ids: Array[String] = []
var cast_talent_snapshot_valid: bool = false
var projectile_slow_tick_remaining: float = 0.0
var slowed_projectile_refs: Dictionary = {}
var field_center := Vector2.ZERO
var remnant_remaining: float = 0.0
var space_lock_elapsed: Dictionary = {}
var space_lock_damage_elapsed: Dictionary = {}
var pressure_enemy_ids: Dictionary = {}


func update(owner, delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)
	if active_remaining <= 0.0:
		return
	if owner == null or not is_instance_valid(owner):
		stop()
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if active_role_id != "mage":
		if transferred_role_id.is_empty() and BUILD.has_choice(owner, "domain_remnant"):
			remnant_remaining = maxf(remnant_remaining, 8.0)
			active_remaining = remnant_remaining
		elif active_role_id != transferred_role_id:
			stop(owner)
			return

	if transferred_role_id.is_empty() and remnant_remaining <= 0.0:
		active_remaining = PERMANENT_ACTIVE_REMAINING
	else:
		active_remaining = max(0.0, active_remaining - delta)
		remnant_remaining = max(0.0, remnant_remaining - delta)
	tick_remaining -= delta
	projectile_slow_tick_remaining -= delta
	_update_effect(owner)
	_update_enemy_projectile_speed_aura(owner)
	_update_space_lock_state(owner, delta)
	var catch_up_ticks: int = 0
	while tick_remaining <= 0.0 and active_remaining > 0.0 and catch_up_ticks < MAX_CATCH_UP_TICKS:
		tick_remaining += TICK_INTERVAL
		_trigger_tick(owner)
		catch_up_ticks += 1
	if catch_up_ticks >= MAX_CATCH_UP_TICKS and tick_remaining <= 0.0:
		tick_remaining = TICK_INTERVAL
	if active_remaining <= 0.0:
		stop(owner)


func can_trigger(owner, role_id: String) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	if bool(owner.get("is_dead")) or bool(owner.get("level_up_active")):
		return false
	if role_id != "mage":
		return false
	if not _has_required_unlock(owner):
		return false
	return active_remaining <= 0.0 and cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		return false
	cast_talent_ids = _capture_talents(owner)
	cast_talent_snapshot_valid = true
	active_remaining = _get_duration(owner)
	transferred_role_id = ""
	remnant_remaining = 0.0
	field_center = owner.global_position
	space_lock_elapsed.clear()
	space_lock_damage_elapsed.clear()
	pressure_enemy_ids.clear()
	_restore_pressure_armor()
	cooldown_remaining = _get_cooldown(owner)
	tick_remaining = 0.0
	projectile_slow_tick_remaining = 0.0
	expansion_tick_count = 0
	inner_ring_enemy_ids.clear()
	_ensure_effect(owner)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -70.0), "\u6885\u5854\u9886\u57df", Color(0.58, 0.88, 1.0, 1.0))
	return true


func stop(owner = null) -> void:
	active_remaining = 0.0
	tick_remaining = 0.0
	projectile_slow_tick_remaining = 0.0
	transferred_role_id = ""
	expansion_tick_count = 0
	inner_ring_enemy_ids.clear()
	PLAYER_MAGE_META_FIELD_TALENT_FLOW.restore_projectile_speed_aura(slowed_projectile_refs)
	cast_talent_ids.clear()
	cast_talent_snapshot_valid = false
	remnant_remaining = 0.0
	space_lock_elapsed.clear()
	space_lock_damage_elapsed.clear()
	_restore_pressure_armor()
	pressure_enemy_ids.clear()
	if effect != null and is_instance_valid(effect):
		_release_effect(effect)
	effect = null


func get_cooldown_slot(owner = null) -> Dictionary:
	var duration: float = _get_cooldown(owner)
	return {
		"name": "\u6885\u5854\u9886\u57df",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(0.58, 0.86, 1.0, 1.0),
		"description": "术师周围展开减速和持续伤害领域，开启期间护甲提升25点，每升一级额外提升2.5点护甲。"
	}


func get_save_data() -> Dictionary:
	return {
		"cooldown_remaining": cooldown_remaining,
		"active_remaining": active_remaining,
		"tick_remaining": tick_remaining,
			"transferred_role_id": transferred_role_id,
			"expansion_tick_count": expansion_tick_count,
			"talent_ids": cast_talent_ids.duplicate(),
			"talent_snapshot_valid": cast_talent_snapshot_valid,
			"field_center": field_center,
			"remnant_remaining": remnant_remaining
	}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COLLAPSE_COOLDOWN)
	transferred_role_id = str(data.get("transferred_role_id", ""))
	active_remaining = clamp(float(data.get("active_remaining", 0.0)), 0.0, TRANSFER_DURATION) if not transferred_role_id.is_empty() else (PERMANENT_ACTIVE_REMAINING if float(data.get("active_remaining", 0.0)) > 0.0 else 0.0)
	tick_remaining = clamp(float(data.get("tick_remaining", 0.0)), 0.0, TICK_INTERVAL)
	projectile_slow_tick_remaining = 0.0
	expansion_tick_count = clampi(int(data.get("expansion_tick_count", 0)), 0, 3)
	cast_talent_ids = _normalize_talent_ids(data.get("talent_ids", []))
	cast_talent_snapshot_valid = bool(data.get("talent_snapshot_valid", data.has("talent_ids")))
	field_center = data.get("field_center", Vector2.ZERO)
	remnant_remaining = maxf(0.0, float(data.get("remnant_remaining", 0.0)))
	inner_ring_enemy_ids.clear()


func restore_effect_if_active(owner) -> void:
	if active_remaining > 0.0:
		_ensure_effect(owner)


func get_armor_bonus(owner) -> float:
	if active_remaining <= 0.0:
		return 0.0
	var active_role_id := str(owner._get_active_role().get("id", "")) if owner != null and owner.has_method("_get_active_role") else ""
	if active_role_id != "mage":
		if not PLAYER_MAGE_META_FIELD_TALENT_FLOW.should_persist_in_background(owner):
			return 0.0
		if BUILD.has_choice(owner, "domain_remnant"):
			return 0.0
		return (BASE_ARMOR_BONUS + PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_meta_field_armor_bonus(owner)) * PLAYER_MAGE_META_FIELD_TALENT_FLOW.BACKGROUND_EFFECT_RATIO
	return BASE_ARMOR_BONUS + PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_meta_field_armor_bonus(owner)


func _trigger_tick(owner) -> void:
	var hits: int = 0
	var center := _get_field_center(owner)
	var vulnerability := 0.10 if BUILD.has_choice(owner, "magic_pressure") else 0.0
	if owner.has_method("_damage_enemies_in_radius_suppressing_status_visuals"):
		hits = int(owner._damage_enemies_in_radius_suppressing_status_visuals(center, _get_radius(owner), _get_damage(owner), vulnerability, _get_slow_multiplier(owner), 1.2, "mage", "mage_meta_field"))
	elif owner.has_method("_damage_enemies_in_radius_batched"):
		hits = int(owner._damage_enemies_in_radius_batched(center, _get_radius(owner), _get_damage(owner), vulnerability, _get_slow_multiplier(owner), 1.2, "mage", "mage_meta_field"))
	else:
		hits = int(owner._damage_enemies_in_radius(
			center,
			_get_radius(owner),
			_get_damage(owner),
			vulnerability,
			_get_slow_multiplier(owner),
			1.2,
			"mage",
			"mage_meta_field"
		))
	if hits > 0 and not _uses_batched_damage(owner):
		owner._register_attack_result("mage", hits, false)
	if BUILD.has_choice(owner, "soul_shackle"):
		_apply_soul_shackle(owner)

func _apply_inner_ring_pull(owner) -> void:
	if not _has_talent(owner, "mage_meta_inner_ring") or owner == null or not owner.has_method("_collect_enemies_in_radius_for_damage_batch"):
		return
	var center: Vector2 = owner.global_position
	var inner_radius := _get_radius(owner) * 0.60
	for enemy in owner._collect_enemies_in_radius_for_damage_batch(center, inner_radius):
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node := enemy as Node2D
		var enemy_id := enemy_node.get_instance_id()
		if inner_ring_enemy_ids.has(enemy_id) or str(enemy_node.get("enemy_kind")) == "boss":
			continue
		var offset := center - enemy_node.global_position
		if offset.length_squared() <= 0.001 or offset.length() > inner_radius:
			continue
		inner_ring_enemy_ids[enemy_id] = true
		enemy_node.global_position += offset.normalized() * min(36.0, offset.length())

func _trigger_collapse(owner) -> void:
	var center: Vector2 = owner.global_position
	var radius: float = _get_radius(owner)
	var damage: float = _get_damage(owner) * 2.0
	var slow: float = _get_slow_multiplier(owner)
	if owner.has_method("_damage_enemies_in_radius_suppressing_status_visuals"):
		owner._damage_enemies_in_radius_suppressing_status_visuals(center, radius, damage, 0.0, slow, 2.0, "mage", "mage_meta_field")
	else:
		owner._damage_enemies_in_radius(center, radius, damage, 0.0, slow, 2.0, "mage", "mage_meta_field")
	cooldown_remaining = COLLAPSE_COOLDOWN
	stop(owner)



func _ensure_effect(owner) -> void:
	if effect != null and is_instance_valid(effect):
		return
	if owner == null or not is_instance_valid(owner) or FIELD_EFFECT_SCENE == null:
		return
	effect = _acquire_effect(owner)
	if effect == null:
		return
	effect.name = "MageMetaFieldEffect"
	effect.z_index = 9
	var sprite: AnimatedSprite2D = effect.get_node_or_null("field") as AnimatedSprite2D
	if sprite != null:
		sprite.centered = true
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE * _get_visual_scale(owner)
		sprite.modulate = Color(0.78, 0.94, 1.0, 0.72)
		if sprite.sprite_frames != null:
			sprite.play()
	_update_effect(owner)

func _acquire_effect(owner) -> Node2D:
	while not effect_pool.is_empty():
		var pooled_effect: Variant = effect_pool.pop_back()
		if not is_instance_valid(pooled_effect) or not (pooled_effect is Node2D):
			continue
		var pooled := pooled_effect as Node2D
		if pooled.is_queued_for_deletion():
			continue
		var parent := pooled.get_parent()
		if parent != owner:
			if parent != null:
				parent.remove_child(pooled)
			owner.add_child(pooled)
		pooled.show()
		pooled.position = Vector2.ZERO
		pooled.rotation = 0.0
		pooled.scale = Vector2.ONE
		pooled.modulate = Color.WHITE
		pooled.set_meta("meta_field_released", false)
		return pooled
	var instance := FIELD_EFFECT_SCENE.instantiate() as Node2D
	if instance != null:
		owner.add_child(instance)
		instance.set_meta("meta_field_released", false)
	return instance

func _release_effect(effect_to_release: Node2D) -> void:
	if effect_to_release == null or not is_instance_valid(effect_to_release):
		return
	if bool(effect_to_release.get_meta("meta_field_released", false)):
		return
	effect_to_release.set_meta("meta_field_released", true)
	effect_to_release.hide()
	var sprite := effect_to_release.get_node_or_null("field") as AnimatedSprite2D
	if sprite != null:
		sprite.stop()
	if effect_pool.size() < 2 and not effect_pool.has(effect_to_release):
		effect_pool.append(effect_to_release)
	else:
		effect_to_release.queue_free()

func _uses_batched_damage(owner) -> bool:
	return owner != null and owner.has_method("_damage_enemies_in_radius_batched")


func _update_effect(owner) -> void:
	_ensure_effect(owner)
	if effect == null or not is_instance_valid(effect):
		return
	var center := _get_field_center(owner)
	effect.position = center - owner.global_position
	var ratio: float = clamp(active_remaining / max(_get_duration(owner), 0.001), 0.0, 1.0)
	effect.modulate.a = 0.52 + ratio * 0.32


func _has_required_unlock(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))


func _get_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return int(owner._get_blessing_skill_tier(SKILL_ID))
	return 1


func _get_tier_bonus_level(owner) -> int:
	return max(0, _get_tier(owner) - 1)


func _get_duration(_owner) -> float:
	return PERMANENT_ACTIVE_REMAINING


func _get_cooldown(_owner) -> float:
	return COOLDOWN


func _get_radius(owner) -> float:
	var base_radius: float = TIER_ONE_RADIUS + BUILD.radius_bonus(owner)
	var range_multiplier: float = 1.0
	if owner != null and owner.has_method("_get_equipment_skill_range_multiplier"):
		range_multiplier *= float(owner._get_equipment_skill_range_multiplier())
	if owner != null and owner.has_method("_get_invoker_magic_range_multiplier"):
		range_multiplier *= float(owner._get_invoker_magic_range_multiplier(SKILL_ID))
	var radius: float = base_radius * range_multiplier
	radius *= PLAYER_MAGE_META_FIELD_TALENT_FLOW.get_radius_multiplier(owner)
	if not transferred_role_id.is_empty():
		radius *= 0.75
	return radius

func _get_field_center(owner) -> Vector2:
	var active_role_id := str(owner._get_active_role().get("id", "")) if owner != null and owner.has_method("_get_active_role") else ""
	if active_role_id == "mage" and remnant_remaining <= 0.0:
		return owner.global_position
	return field_center


func _get_visual_scale(owner) -> float:
	return max(1.0, _get_radius(owner) / 90.0)


func _get_slow_multiplier(owner) -> float:
	var slow_effect: float = clamp(1.0 - BUILD.slow_multiplier(owner), 0.0, 0.95)
	if not transferred_role_id.is_empty():
		slow_effect *= 0.50
	else:
		slow_effect *= _get_level_talent_effect_ratio(owner)
	return 1.0 - slow_effect


func _get_damage(owner) -> float:
	var tier: int = _get_tier(owner)
	var ratio: float = TIER_ONE_DAMAGE_RATIO
	if tier >= 3:
		ratio = TIER_THREE_DAMAGE_RATIO
	elif tier >= 2:
		ratio = TIER_TWO_DAMAGE_RATIO
	ratio += float(_get_tier_bonus_level(owner)) * DAMAGE_RATIO_BONUS_PER_TIER
	ratio += PLAYER_BUILD_SYSTEM.get_meta_field_damage_ratio_bonus(owner)
	if not transferred_role_id.is_empty():
		ratio *= 0.50
	else:
		ratio *= _get_level_talent_effect_ratio(owner)
	return float(owner._get_role_damage("mage")) * ratio

func _update_space_lock_state(owner, delta: float) -> void:
	if owner == null or not owner.has_method("_collect_enemies_in_radius_for_damage_batch"):
		return
	var center := _get_field_center(owner)
	var live: Dictionary = {}
	for enemy in owner._collect_enemies_in_radius_for_damage_batch(center, _get_radius(owner)):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var id: int = enemy.get_instance_id()
		live[id] = true
		var previous_elapsed: float = float(space_lock_elapsed.get(id, 0.0))
		var elapsed: float = previous_elapsed + delta
		space_lock_elapsed[id] = elapsed
		if BUILD.has_choice(owner, "space_lock") and elapsed >= 2.0:
			if enemy.has_method("apply_slow_from_source"):
				var base_slow_multiplier: float = _get_slow_multiplier(owner)
				var doubled_slow_multiplier: float = maxf(0.0, 1.0 - (1.0 - base_slow_multiplier) * 2.0)
				var additional_slow_multiplier: float = doubled_slow_multiplier / base_slow_multiplier if base_slow_multiplier > 0.0 else 0.0
				enemy.apply_slow_from_source(additional_slow_multiplier, 0.8, "mage_meta_field_space_lock", true)
			var damage_elapsed: float = float(space_lock_damage_elapsed.get(id, 0.0))
			damage_elapsed += maxf(0.0, elapsed - maxf(previous_elapsed, 2.0))
			while damage_elapsed >= 1.0:
				damage_elapsed -= 1.0
				_apply_space_lock_damage(enemy)
			space_lock_damage_elapsed[id] = damage_elapsed
		if BUILD.has_choice(owner, "magic_pressure") and enemy.get("damage_reduction_value") != null:
			if not enemy.has_meta("mage_meta_field_pressure_base"):
				enemy.set_meta("mage_meta_field_pressure_base", float(enemy.get("damage_reduction_value")))
			enemy.set("damage_reduction_value", float(enemy.get_meta("mage_meta_field_pressure_base")) - 20.0)
	for id in space_lock_elapsed.keys():
		if not live.has(id):
			space_lock_elapsed.erase(id)
			space_lock_damage_elapsed.erase(id)
	for id in pressure_enemy_ids.keys():
		if not live.has(id):
			var old_ref: WeakRef = pressure_enemy_ids[id]
			var old_enemy: Node = old_ref.get_ref() if old_ref != null else null
			if old_enemy != null and is_instance_valid(old_enemy) and old_enemy.has_meta("mage_meta_field_pressure_base") and old_enemy.get("damage_reduction_value") != null:
				old_enemy.set("damage_reduction_value", float(old_enemy.get_meta("mage_meta_field_pressure_base")))
				old_enemy.remove_meta("mage_meta_field_pressure_base")
			pressure_enemy_ids.erase(id)
	if BUILD.has_choice(owner, "magic_pressure"):
		for enemy in owner._collect_enemies_in_radius_for_damage_batch(center, _get_radius(owner)):
			if enemy != null and is_instance_valid(enemy):
				pressure_enemy_ids[enemy.get_instance_id()] = weakref(enemy)
func _apply_space_lock_damage(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("take_direct_damage"):
		return
	var max_health_value: Variant = enemy.get("max_health")
	if max_health_value == null:
		return
	var damage_ratio: float = 0.01 if str(enemy.get("enemy_kind")) in ["boss", "small_boss"] else 0.03
	enemy.take_direct_damage(maxf(0.0, float(max_health_value)) * damage_ratio)

func _apply_soul_shackle(owner) -> void:
	if not BUILD.has_choice(owner, "soul_shackle") or owner == null or not owner.has_method("_collect_enemies_in_radius_for_damage_batch"):
		return
	var center := _get_field_center(owner)
	for enemy in owner._collect_enemies_in_radius_for_damage_batch(center, _get_radius(owner)):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var count := int(enemy.get_meta("mage_meta_field_slow_count", 0)) + 1
		if count >= 3:
			count = 0
			if enemy.has_method("apply_slow_from_source"):
				enemy.apply_slow_from_source(0.01, 2.0, "mage_meta_field_soul_shackle", true)
		enemy.set_meta("mage_meta_field_slow_count", count)

func _restore_pressure_armor() -> void:
	if effect == null or not is_instance_valid(effect):
		return
	var tree := effect.get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if node != null and is_instance_valid(node) and node.has_meta("mage_meta_field_pressure_base") and node.get("damage_reduction_value") != null:
			node.set("damage_reduction_value", float(node.get_meta("mage_meta_field_pressure_base")))
			node.remove_meta("mage_meta_field_pressure_base")

func _get_level_talent_effect_ratio(owner) -> float:
	var active_role_id := str(owner._get_active_role().get("id", "")) if owner != null and owner.has_method("_get_active_role") else ""
	return PLAYER_MAGE_META_FIELD_TALENT_FLOW.get_level_talent_effect_ratio(owner, active_role_id, transferred_role_id)


func _update_enemy_projectile_speed_aura(owner) -> void:
	if projectile_slow_tick_remaining > 0.0:
		return
	projectile_slow_tick_remaining = PLAYER_MAGE_META_FIELD_TALENT_FLOW.PROJECTILE_AURA_SCAN_INTERVAL
	var effect_ratio := _get_level_talent_effect_ratio(owner)
	var speed_multiplier := PLAYER_MAGE_META_FIELD_TALENT_FLOW.get_enemy_projectile_speed_multiplier(owner, effect_ratio)
	var center := _get_field_center(owner)
	slowed_projectile_refs = PLAYER_MAGE_META_FIELD_TALENT_FLOW.apply_enemy_projectile_speed_aura(owner, center, _get_radius(owner), speed_multiplier, slowed_projectile_refs)


func _has_talent(owner, talent_id: String) -> bool:
	if cast_talent_snapshot_valid:
		return cast_talent_ids.has(talent_id)
	return owner != null and owner.has_method("_has_skill_talent") and bool(owner._has_skill_talent(talent_id))

func _capture_talents(owner) -> Array[String]:
	var result: Array[String] = []
	for talent_id in TALENT_IDS:
		if owner != null and owner.has_method("_has_skill_talent") and bool(owner._has_skill_talent(talent_id)):
			result.append(talent_id)
	return result

func _normalize_talent_ids(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for talent_id in value:
			var normalized := str(talent_id)
			if TALENT_IDS.has(normalized) and not result.has(normalized):
				result.append(normalized)
	return result

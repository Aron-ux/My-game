extends RefCounted

const FIELD_EFFECT_SCENE := preload("res://effects/wizard/field/field.tscn")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")

const SKILL_ID := "meta_field"
const COOLDOWN := 0.0
const PERMANENT_ACTIVE_REMAINING := 1.0
const TIER_ONE_SLOW := 0.50
const TIER_TWO_SLOW := 0.40
const TIER_THREE_SLOW := 0.20
const TIER_ONE_DAMAGE_REDUCTION := 0.50
const TIER_TWO_DAMAGE_REDUCTION := 0.50
const TIER_THREE_DAMAGE_REDUCTION := 0.50
const TIER_ONE_DAMAGE_REDUCTION_VALUE := 320.0
const TIER_TWO_DAMAGE_REDUCTION_VALUE := 320.0
const TIER_THREE_DAMAGE_REDUCTION_VALUE := 320.0
const TIER_ONE_DAMAGE_RATIO := 0.10
const TIER_TWO_DAMAGE_RATIO := 0.28
const TIER_THREE_DAMAGE_RATIO := 0.38
const TIER_ONE_RADIUS := 100.0
const TIER_TWO_RADIUS := 190.0
const TIER_THREE_RADIUS := 218.6
const RADIUS_BONUS_PER_TIER := 0.10
const SLOW_EFFECT_BONUS_PER_TIER := 0.10
const DAMAGE_RATIO_BONUS_PER_TIER := 0.02
const FIELD_SIZE_MULTIPLIER := 0.70
const TICK_INTERVAL := 0.5
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
		if transferred_role_id.is_empty() and _has_talent(owner, "mage_meta_transfer"):
			transferred_role_id = active_role_id
			active_remaining = TRANSFER_DURATION
		elif transferred_role_id.is_empty() and _has_talent(owner, "mage_meta_collapse"):
			_trigger_collapse(owner)
			return
		elif active_role_id != transferred_role_id:
			stop(owner)
			return

	if transferred_role_id.is_empty():
		active_remaining = PERMANENT_ACTIVE_REMAINING
	else:
		active_remaining = max(0.0, active_remaining - delta)
	tick_remaining -= delta
	_update_effect(owner)
	_apply_inner_ring_pull(owner)
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
	cooldown_remaining = _get_cooldown(owner)
	tick_remaining = 0.0
	expansion_tick_count = 0
	inner_ring_enemy_ids.clear()
	_ensure_effect(owner)
	if _has_talent(owner, "mage_meta_guard_pulse") and owner.has_method("_heal"):
		owner._heal(float(owner.get("max_health")) * 0.04)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -70.0), "\u6885\u5854\u9886\u57df", Color(0.58, 0.88, 1.0, 1.0))
	return true


func stop(owner = null) -> void:
	active_remaining = 0.0
	tick_remaining = 0.0
	transferred_role_id = ""
	expansion_tick_count = 0
	inner_ring_enemy_ids.clear()
	cast_talent_ids.clear()
	cast_talent_snapshot_valid = false
	if effect != null and is_instance_valid(effect):
		_release_effect(effect)
	effect = null


func get_cooldown_slot(owner = null) -> Dictionary:
	var duration: float = COLLAPSE_COOLDOWN if _has_talent(owner, "mage_meta_collapse") else _get_cooldown(owner)
	return {
		"name": "\u6885\u5854\u9886\u57df",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(0.58, 0.86, 1.0, 1.0),
		"description": "\u672f\u5e08\u5468\u56f4\u5c55\u5f00\u51cf\u901f\u548c\u6301\u7eed\u4f24\u5bb3\u9886\u57df\uff0c\u81ea\u8eab\u83b7\u5f97\u51cf\u4f24\u548c\u56fa\u5b9a\u56de\u8840\u3002"
	}


func get_save_data() -> Dictionary:
	return {
		"cooldown_remaining": cooldown_remaining,
		"active_remaining": active_remaining,
		"tick_remaining": tick_remaining,
			"transferred_role_id": transferred_role_id,
			"expansion_tick_count": expansion_tick_count,
			"talent_ids": cast_talent_ids.duplicate(),
			"talent_snapshot_valid": cast_talent_snapshot_valid
	}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COLLAPSE_COOLDOWN)
	transferred_role_id = str(data.get("transferred_role_id", ""))
	active_remaining = clamp(float(data.get("active_remaining", 0.0)), 0.0, TRANSFER_DURATION) if not transferred_role_id.is_empty() else (PERMANENT_ACTIVE_REMAINING if float(data.get("active_remaining", 0.0)) > 0.0 else 0.0)
	tick_remaining = clamp(float(data.get("tick_remaining", 0.0)), 0.0, TICK_INTERVAL)
	expansion_tick_count = clampi(int(data.get("expansion_tick_count", 0)), 0, 3)
	cast_talent_ids = _normalize_talent_ids(data.get("talent_ids", []))
	cast_talent_snapshot_valid = bool(data.get("talent_snapshot_valid", data.has("talent_ids")))
	inner_ring_enemy_ids.clear()


func restore_effect_if_active(owner) -> void:
	if active_remaining > 0.0:
		_ensure_effect(owner)


func get_damage_taken_multiplier(owner) -> float:
	if active_remaining <= 0.0 or not transferred_role_id.is_empty():
		return 1.0
	return 1.0 - _get_damage_reduction(owner)


func get_damage_reduction_value(owner) -> float:
	if active_remaining <= 0.0 or not transferred_role_id.is_empty():
		return 0.0
	return _get_damage_reduction_value(owner)


func _trigger_tick(owner) -> void:
	var hits: int = 0
	if owner.has_method("_damage_enemies_in_radius_suppressing_status_visuals"):
		hits = int(owner._damage_enemies_in_radius_suppressing_status_visuals(owner.global_position, _get_radius(owner), _get_damage(owner), 0.0, _get_slow_multiplier(owner), 1.2, "mage"))
	elif owner.has_method("_damage_enemies_in_radius_batched"):
		hits = int(owner._damage_enemies_in_radius_batched(owner.global_position, _get_radius(owner), _get_damage(owner), 0.0, _get_slow_multiplier(owner), 1.2, "mage"))
	else:
		hits = int(owner._damage_enemies_in_radius(
			owner.global_position,
			_get_radius(owner),
			_get_damage(owner),
			0.0,
			_get_slow_multiplier(owner),
			1.2,
			"mage"
		))
	if hits > 0 and not _uses_batched_damage(owner):
		owner._register_attack_result("mage", hits, false)
	if _has_talent(owner, "mage_meta_expansion"):
		expansion_tick_count = min(3, expansion_tick_count + 1)

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
		owner._damage_enemies_in_radius_suppressing_status_visuals(center, radius, damage, 0.0, slow, 2.0, "mage")
	else:
		owner._damage_enemies_in_radius(center, radius, damage, 0.0, slow, 2.0, "mage")
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
	effect.position = Vector2.ZERO
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
	var tier: int = _get_tier(owner)
	var base_radius: float = TIER_ONE_RADIUS
	if tier >= 3:
		base_radius = TIER_THREE_RADIUS
	elif tier >= 2:
		base_radius = TIER_TWO_RADIUS
	var range_multiplier: float = 1.0
	if owner != null and owner.has_method("_get_equipment_skill_range_multiplier"):
		range_multiplier *= float(owner._get_equipment_skill_range_multiplier())
	if owner != null and owner.has_method("_get_invoker_magic_range_multiplier"):
		range_multiplier *= float(owner._get_invoker_magic_range_multiplier(SKILL_ID))
	base_radius *= 1.0 + float(_get_tier_bonus_level(owner)) * RADIUS_BONUS_PER_TIER
	var build_radius_multiplier: float = PLAYER_BUILD_SYSTEM.get_meta_field_radius_multiplier(owner)
	var radius: float = base_radius * range_multiplier * build_radius_multiplier
	if tier > 1:
		radius *= FIELD_SIZE_MULTIPLIER
	if not transferred_role_id.is_empty():
		radius *= 0.75
	if _has_talent(owner, "mage_meta_expansion"):
		radius *= pow(1.12, float(clampi(expansion_tick_count, 0, 3)))
	return radius


func _get_visual_scale(owner) -> float:
	return max(1.0, _get_radius(owner) / 90.0)


func _get_slow_multiplier(owner) -> float:
	var tier: int = _get_tier(owner)
	var base_multiplier: float = TIER_ONE_SLOW
	if tier >= 3:
		base_multiplier = TIER_THREE_SLOW
	elif tier >= 2:
		base_multiplier = TIER_TWO_SLOW
	var slow_effect: float = 1.0 - base_multiplier
	slow_effect = clamp(slow_effect + float(_get_tier_bonus_level(owner)) * SLOW_EFFECT_BONUS_PER_TIER + PLAYER_BUILD_SYSTEM.get_meta_field_slow_bonus(owner), 0.0, 0.95)
	if _has_talent(owner, "mage_meta_stasis"):
		slow_effect = min(0.95, slow_effect + 0.12)
	if not transferred_role_id.is_empty():
		slow_effect *= 0.50
	return 1.0 - slow_effect


func _get_damage_reduction(owner) -> float:
	var tier: int = _get_tier(owner)
	if tier >= 3:
		return TIER_THREE_DAMAGE_REDUCTION
	if tier >= 2:
		return TIER_TWO_DAMAGE_REDUCTION
	return TIER_ONE_DAMAGE_REDUCTION


func _get_damage_reduction_value(owner) -> float:
	var tier: int = _get_tier(owner)
	var value: float = TIER_ONE_DAMAGE_REDUCTION_VALUE
	if tier >= 3:
		value = TIER_THREE_DAMAGE_REDUCTION_VALUE
	elif tier >= 2:
		value = TIER_TWO_DAMAGE_REDUCTION_VALUE
	return value + PLAYER_BUILD_SYSTEM.get_meta_field_damage_reduction_value_bonus(owner)


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
	return float(owner._get_role_damage("mage")) * ratio

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

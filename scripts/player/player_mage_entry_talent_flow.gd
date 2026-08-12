extends RefCounted

const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

const TALENT_DENSE_LIGHTNING_1 := "mage_level_talent_dense_lightning_1"
const TALENT_DENSE_LIGHTNING_2 := "mage_level_talent_dense_lightning_2"
const ENTRY_SOURCE_PREFIX := "mage_entry_lightning:"
const EXTRA_RING_DISTANCE_MULTIPLIER := 1.65
const COOLDOWN_CUT_PER_KILL := 0.20
const ARCANE_SURPLUS_DURATION_PER_KILL := 0.20
const PENDING_SURPLUS_BONUS_KEY := "dense_lightning_pending_surplus_bonus"


static func has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)


static func has_extra_ring(owner) -> bool:
	return has_level_talent(owner, TALENT_DENSE_LIGHTNING_1) or has_level_talent(owner, TALENT_DENSE_LIGHTNING_2)


static func make_damage_source_id() -> String:
	return "%s%d" % [ENTRY_SOURCE_PREFIX, Time.get_ticks_usec()]


static func is_entry_lightning_source(source_role_id: String, resolved_role_id: String = "") -> bool:
	return source_role_id.begins_with(ENTRY_SOURCE_PREFIX) or (source_role_id == "mage_entry" and (resolved_role_id == "" or resolved_role_id == "mage"))


static func append_extra_ring_centers(owner, centers: Array[Vector2], base_direction: Vector2, entry_count: int, entry_distance: float) -> void:
	if not has_extra_ring(owner):
		return
	var direction := base_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	var outer_distance: float = max(1.0, entry_distance * EXTRA_RING_DISTANCE_MULTIPLIER)
	for index in range(max(0, entry_count)):
		var angle_offset: float = TAU * float(index) / float(max(1, entry_count))
		centers.append(owner.global_position + direction.rotated(angle_offset).normalized() * outer_distance)


static func on_entry_lightning_killed(owner, source_role_id: String, resolved_role_id: String = "") -> void:
	if owner == null or not is_entry_lightning_source(source_role_id, resolved_role_id):
		return
	if has_level_talent(owner, TALENT_DENSE_LIGHTNING_1):
		_cut_mage_active_cooldowns(owner, COOLDOWN_CUT_PER_KILL)
	if has_level_talent(owner, TALENT_DENSE_LIGHTNING_2):
		_add_arcane_surplus_duration(owner, ARCANE_SURPLUS_DURATION_PER_KILL)


static func consume_pending_arcane_surplus_bonus(owner) -> float:
	if owner == null or not owner.has_method("_get_role_special_state"):
		return 0.0
	var state: Dictionary = owner._get_role_special_state("mage")
	var bonus: float = max(0.0, float(state.get(PENDING_SURPLUS_BONUS_KEY, 0.0)))
	if bonus > 0.0:
		state[PENDING_SURPLUS_BONUS_KEY] = 0.0
		if owner.get("role_special_states") is Dictionary:
			owner.role_special_states["mage"] = state
	return bonus


static func _cut_mage_active_cooldowns(owner, amount: float) -> void:
	var cut_amount: float = max(0.0, amount)
	if cut_amount <= 0.0:
		return
	for property_name in ["mage_tidal_surge_ability", "mage_meta_field_ability"]:
		var ability = owner.get(property_name)
		if ability != null and ability.get("cooldown_remaining") != null:
			ability.cooldown_remaining = max(0.0, float(ability.cooldown_remaining) - cut_amount)
	var timer_value: Variant = owner.get("fire_timer")
	if timer_value is Timer:
		var fire_timer := timer_value as Timer
		if not fire_timer.is_stopped():
			fire_timer.start(max(0.001, fire_timer.time_left - cut_amount))
	elif timer_value is Object:
		var timer_object := timer_value as Object
		if timer_object.has_method("is_stopped") and timer_object.has_method("start") and not bool(timer_object.call("is_stopped")):
			var time_left := 0.0
			var time_left_value: Variant = timer_object.get("time_left")
			if time_left_value != null:
				time_left = float(time_left_value)
			timer_object.call("start", max(0.001, time_left - cut_amount))


static func _add_arcane_surplus_duration(owner, amount: float) -> void:
	var bonus: float = max(0.0, amount)
	if bonus <= 0.0:
		return
	if owner.get("mage_arcane_surplus_remaining") != null and float(owner.get("mage_arcane_surplus_remaining")) > 0.0:
		owner.mage_arcane_surplus_remaining = max(0.0, float(owner.mage_arcane_surplus_remaining) + bonus)
		if owner.has_method("_sync_duration_status"):
			owner._sync_duration_status("mage_arcane_surplus", "\u5965\u6CD5\u76C8\u4F59", owner.mage_arcane_surplus_remaining, 18, Color(0.34, 0.72, 1.0, 0.95))
		return
	if not owner.has_method("_get_role_special_state"):
		return
	var state: Dictionary = owner._get_role_special_state("mage")
	state[PENDING_SURPLUS_BONUS_KEY] = max(0.0, float(state.get(PENDING_SURPLUS_BONUS_KEY, 0.0))) + bonus
	if owner.get("role_special_states") is Dictionary:
		owner.role_special_states["mage"] = state

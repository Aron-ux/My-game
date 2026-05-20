extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const ENEMY_BATCH_ELIGIBILITY := preload("res://scripts/enemies/enemy_batch_eligibility.gd")

const BATCH_FRAME_META_KEY := "__enemy_batch_simulation_frame"


static func update_simple_normal_enemies(scene: Node, delta: float) -> void:
	if scene == null or delta <= 0.0:
		return
	var current_frame: int = Engine.get_physics_frames()
	if int(scene.get_meta(BATCH_FRAME_META_KEY, -1)) == current_frame:
		return
	scene.set_meta(BATCH_FRAME_META_KEY, current_frame)

	var updated_count := 0
	var scanned_count := 0
	var skipped_by_reason: Dictionary = {}
	for raw_enemy in _get_runtime_enemies(scene):
		if raw_enemy == null or not is_instance_valid(raw_enemy) or raw_enemy is not Node:
			continue
		var enemy_node := raw_enemy as Node
		scanned_count += 1
		if not enemy_node.has_method("can_use_batch_simulation") or not enemy_node.has_method("batch_physics_process"):
			_add_skip_reason(skipped_by_reason, "missing_batch_api")
			continue
		var reason := ENEMY_BATCH_ELIGIBILITY.REASON_ELIGIBLE
		if enemy_node.has_method("get_batch_ineligibility_reason"):
			reason = str(enemy_node.call("get_batch_ineligibility_reason"))
		elif not bool(enemy_node.call("can_use_batch_simulation")):
			reason = "legacy_rejected"
		if reason != ENEMY_BATCH_ELIGIBILITY.REASON_ELIGIBLE:
			_add_skip_reason(skipped_by_reason, reason)
			_restore_enemy_physics(enemy_node)
			continue

		if "batch_simulation_enabled" in enemy_node:
			enemy_node.set("batch_simulation_enabled", true)
		if enemy_node.is_physics_processing():
			enemy_node.set_physics_process(false)
		enemy_node.call("batch_physics_process", delta)
		updated_count += 1

	if updated_count > 0:
		PERFORMANCE_COUNTERS.add("batched_enemy_ticks", updated_count)
	if scanned_count > 0:
		PERFORMANCE_COUNTERS.add("enemy_batch_scanned", scanned_count)
		PERFORMANCE_COUNTERS.add("enemy_batch_eligible", updated_count)
	for reason_key in skipped_by_reason.keys():
		PERFORMANCE_COUNTERS.add("enemy_batch_skip_%s" % str(reason_key), int(skipped_by_reason.get(reason_key, 0)))


static func _get_runtime_enemies(scene: Node) -> Array:
	if scene.has_method("get_runtime_enemies"):
		return scene.call("get_runtime_enemies")
	return scene.get_tree().get_nodes_in_group("enemies") if scene.is_inside_tree() else []


static func _restore_enemy_physics(enemy_node: Node) -> void:
	if "batch_simulation_enabled" in enemy_node:
		enemy_node.set("batch_simulation_enabled", false)
	var pooled_inactive := false
	if "pooled_inactive" in enemy_node:
		pooled_inactive = bool(enemy_node.get("pooled_inactive"))
	if enemy_node.is_inside_tree() and not pooled_inactive and not enemy_node.is_physics_processing():
		enemy_node.set_physics_process(true)


static func _add_skip_reason(skipped_by_reason: Dictionary, reason: String) -> void:
	if reason == "":
		reason = "unknown"
	skipped_by_reason[reason] = int(skipped_by_reason.get(reason, 0)) + 1

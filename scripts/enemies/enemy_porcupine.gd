extends RefCounted


static func is_porcupine(enemy) -> bool:
	return enemy != null and str(enemy.get("archetype_id")) == "angry_porcupine"


static func reset(enemy) -> void:
	enemy.porcupine_state = {"rage": 0.0, "remaining": 0.0}


static func is_enraged(enemy) -> bool:
	return is_porcupine(enemy) and float(enemy.porcupine_state.get("remaining", 0.0)) > 0.0


static func tick(enemy, delta: float) -> void:
	if not is_porcupine(enemy):
		return
	enemy.porcupine_state["remaining"] = maxf(0, float(enemy.porcupine_state.get("remaining", 0)) - delta)
	sync_visual(enemy)


static func accumulate(enemy, damage_before_defenses: float) -> void:
	if not is_porcupine(enemy) or is_enraged(enemy) or enemy.current_health <= 0 or damage_before_defenses <= 0:
		return
	var state: Dictionary = enemy.porcupine_state
	state["rage"] = minf(60, float(state.get("rage", 0)) + damage_before_defenses * 0.2)
	if float(state["rage"]) >= 60 - 0.000001:
		state["rage"] = 0.0
		state["remaining"] = 20.0
		enemy._spawn_status_burst(Color(1, 0.25, 0.1, 0.7), 50)
	sync_visual(enemy)


static func sync_visual(enemy) -> void:
	var visual: Node = enemy.get_node_or_null("ProfileVisual")
	if visual != null and visual.get("enraged") != null:
		visual.enraged = is_enraged(enemy)


static func crossed_health_thresholds(max_health: float, before: float, after: float) -> int:
	if max_health <= 0 or before <= after:
		return 0
	var count := 0
	for index in range(10):
		var threshold := max_health * float(index) / 10.0
		if before > threshold and after <= threshold:
			count += 1
	return count


static func show_quill_burst(enemy, count: int) -> void:
	if count <= 0 or not enemy.is_inside_tree():
		return
	var scene: Node = enemy.get_tree().current_scene
	if scene == null:
		return
	for index in count:
		var effect := preload("res://scripts/enemies/porcupine_quill_visual.gd").new()
		effect.position = enemy.global_position
		effect.enraged = is_enraged(enemy)
		effect.angle_offset = float(index) * PI / 24.0
		scene.add_child(effect)

extends RefCounted

const LIMIT := 2
const MARK := preload("res://scripts/player/player_necro_mark.gd")


static func is_priest(enemy) -> bool:
	return enemy != null and str(enemy.get("archetype_id")) == "necro_priest"


static func reset(enemy) -> void:
	enemy.necro_priest_state = {"prayer_cooldown": 5.0, "mark_cooldown": 12.0}


static func update(enemy, delta: float) -> void:
	var state: Dictionary = enemy.necro_priest_state
	for key in ["prayer_cooldown", "mark_cooldown"]:
		state[key] = maxf(0, float(state.get(key, 0)) - delta)
	if float(state["prayer_cooldown"]) <= 0:
		state["prayer_cooldown"] = 5.0
		for other in enemy.get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(other) or other.is_queued_for_deletion() or other.pooled_inactive or other.current_health <= 0 or other.rebirth_timer > 0:
				continue
			if other.current_health < other.max_health:
				other.current_health += (other.max_health - other.current_health) * 0.3
			other._spawn_status_burst(Color(0.35, 0.85, 0.68, 0.45), 24)
		enemy._spawn_status_burst(Color(0.55, 1, 0.8, 0.6), 55)
	if float(state["mark_cooldown"]) <= 0 and is_instance_valid(enemy.target):
		if enemy.global_position.distance_squared_to(enemy.target.global_position) <= 250.0 * 250.0:
			state["mark_cooldown"] = 12.0
			MARK.apply(enemy.target)
			enemy._spawn_status_burst(Color(0.7, 0.35, 0.9, 0.7), 45)


static func immune_to_source(enemy, source: String) -> bool:
	if not is_priest(enemy):
		return false
	for role in ["swordsman", "gunner", "mage", "mechanic"]:
		if source.begins_with(role + "_basic:"):
			return true
	return source.begins_with("swordsman_aux:") or source.begins_with("gunner_aux:")


static func living(main: Node) -> Array:
	var result: Array = []
	for enemy in main.get_tree().get_nodes_in_group("enemies"):
		if is_priest(enemy) and not enemy.pooled_inactive and enemy.current_health > 0 and not enemy.is_queued_for_deletion():
			result.append(enemy)
	return result


static func spawn_position(main: Node) -> Vector2:
	var bounds: Rect2 = main.map_bounds if main.get("map_bounds") is Rect2 else Rect2(-1600, -900, 3200, 1800)
	var left := Vector2(bounds.position.x + 120, bounds.get_center().y)
	var right := Vector2(bounds.end.x - 120, bounds.get_center().y)
	var current := living(main)
	if current.is_empty():
		return left
	return right if current[0].global_position.distance_squared_to(left) < current[0].global_position.distance_squared_to(right) else left

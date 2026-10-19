extends RefCounted

const LIMIT := 2
const MARK := preload("res://scripts/player/player_necro_mark.gd")
const SHEET_EFFECT := preload("res://scripts/enemies/enemy_sheet_effect.gd")
const PRAYER_CIRCLE := preload("res://assets/enemies/necropriest/prayer_circle.png")
const HEAL_WISP := preload("res://assets/enemies/necropriest/heal_wisp.png")
const HEAL_WISP_LIMIT := 16


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
		var scene: Node = enemy.get_tree().current_scene
		var wisps := 0
		for other in enemy.get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(other) or other.is_queued_for_deletion() or other.pooled_inactive or other.current_health <= 0 or other.rebirth_timer > 0:
				continue
			if other.current_health < other.max_health:
				other.current_health += (other.max_health - other.current_health) * 0.3
				if wisps < HEAL_WISP_LIMIT:
					wisps += 1
					SHEET_EFFECT.spawn(scene, HEAL_WISP, 6, other.global_position, {"follow": other, "offset": Vector2(0, -34), "fps": 12.0, "z_index": 16})
		_play_cast(enemy)
		SHEET_EFFECT.spawn(scene, PRAYER_CIRCLE, 8, enemy.global_position, {"offset": Vector2(0, 22), "fps": 13.0, "art_scale": 1.6, "z_index": 9})
	if float(state["mark_cooldown"]) <= 0 and is_instance_valid(enemy.target):
		if enemy.global_position.distance_squared_to(enemy.target.global_position) <= 250.0 * 250.0:
			state["mark_cooldown"] = 12.0
			MARK.apply(enemy.target)
			_play_cast(enemy)


static func _play_cast(enemy) -> void:
	var visual: Node = enemy.get_node_or_null("ProfileVisual")
	if visual != null and visual.has_method("play_cast"):
		visual.play_cast()


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

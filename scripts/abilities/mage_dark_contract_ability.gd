extends RefCounted

const PLAYER_MAGE_DARK_CONTRACT_FLOW := preload("res://scripts/player/player_mage_dark_contract_flow.gd")
const DARK_CONTRACT_VISUAL_SCRIPT := preload("res://scripts/player/mage_dark_contract_visual.gd")

const SKILL_ID := "dark_contract"
const COOLDOWN := 24.0
const PROJECTILE_SPEED := 50.0
const TRAVEL_DISTANCE := 600.0

var cooldown_remaining: float = 0.0
var active_spheres: Array[Dictionary] = []
var pending_saved_spheres: Array[Dictionary] = []


func update(owner, delta: float) -> void:
	cooldown_remaining = max(0.0, cooldown_remaining - delta)
	for index in range(active_spheres.size() - 1, -1, -1):
		var data: Dictionary = active_spheres[index]
		var sphere: Node2D = data.get("node", null) as Node2D
		if owner == null or not is_instance_valid(owner) or sphere == null or not is_instance_valid(sphere):
			if sphere != null and is_instance_valid(sphere):
				sphere.queue_free()
			active_spheres.remove_at(index)
			continue
		var direction: Vector2 = data.get("direction", Vector2.RIGHT)
		var origin: Vector2 = data.get("origin", Vector2.ZERO)
		var traveled: float = float(data.get("traveled", 0.0)) + PROJECTILE_SPEED * delta
		data["traveled"] = traveled
		var position: Vector2 = origin + direction * traveled
		sphere.global_position = position
		active_spheres[index] = data
		if traveled >= TRAVEL_DISTANCE:
			_explode(owner, position)
			sphere.queue_free()
			active_spheres.remove_at(index)
			continue
		data = PLAYER_MAGE_DARK_CONTRACT_FLOW.apply_sphere_tick(owner, data, position, delta)
		active_spheres[index] = data


func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and role_id == "mage" and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and _is_unlocked(owner) and cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, "mage"):
		return false
	var direction: Vector2 = owner._get_live_mouse_aim_direction(owner.facing_direction)
	if direction.length_squared() <= 0.001:
		direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	direction = direction.normalized()
	owner.facing_direction = direction
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return false
	cooldown_remaining = COOLDOWN
	var sphere := Node2D.new()
	sphere.name = "MageDarkContract"
	sphere.global_position = owner.global_position + direction * 22.0
	sphere.z_index = 27
	sphere.set_script(DARK_CONTRACT_VISUAL_SCRIPT)
	scene.add_child(sphere)
	active_spheres.append({
		"node": sphere,
		"origin": owner.global_position + direction * 22.0,
		"direction": direction,
		"traveled": 0.0,
		"attract_tick_elapsed": 0.0,
		"collided_ids": {}
	})
	return true


func get_cooldown_slot(owner = null) -> Dictionary:
	return {
		"name": "黑暗契约",
		"remaining": clamp(cooldown_remaining, 0.0, COOLDOWN),
		"duration": COOLDOWN,
		"color": Color(0.5, 0.3, 0.85, 1.0),
		"description": "向前方丢出黑暗球体，沿途吸引附近敌人并持续造成伤害；球体碰撞造成 300% 伤害，终点爆炸造成 300% 范围伤害。"
	}


func get_save_data() -> Dictionary:
	var spheres: Array[Dictionary] = []
	for data in active_spheres:
		var sphere: Node2D = data.get("node", null) as Node2D
		if sphere == null or not is_instance_valid(sphere):
			continue
		var direction: Vector2 = data.get("direction", Vector2.RIGHT)
		spheres.append({
			"position": [sphere.global_position.x, sphere.global_position.y],
			"origin": _encode_vector2(data.get("origin", sphere.global_position)),
			"direction": [direction.x, direction.y],
			"traveled": max(0.0, float(data.get("traveled", 0.0))),
			"attract_tick_elapsed": max(0.0, float(data.get("attract_tick_elapsed", 0.0)))
		})
	return {"cooldown_remaining": cooldown_remaining, "spheres": spheres}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	_clear_spheres()
	pending_saved_spheres.clear()
	var saved_spheres: Variant = data.get("spheres", [])
	if saved_spheres is Array:
		for saved_data in saved_spheres:
			if saved_data is Dictionary:
				pending_saved_spheres.append((saved_data as Dictionary).duplicate(true))


func restore_effect_if_active(owner) -> void:
	var tree: SceneTree = owner.get_tree() if owner != null and is_instance_valid(owner) and owner.has_method("get_tree") else null
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return
	for saved_data in pending_saved_spheres:
		var position := _decode_vector2(saved_data.get("position", []), owner.global_position)
		var direction := _decode_vector2(saved_data.get("direction", []), Vector2.RIGHT).normalized()
		if direction.length_squared() <= 0.001:
			direction = Vector2.RIGHT
		var sphere := Node2D.new()
		sphere.name = "MageDarkContract"
		sphere.global_position = position
		sphere.z_index = 27
		sphere.set_script(DARK_CONTRACT_VISUAL_SCRIPT)
		scene.add_child(sphere)
		active_spheres.append({
			"node": sphere,
			"origin": _decode_vector2(saved_data.get("origin", []), position),
			"direction": direction,
			"traveled": clamp(float(saved_data.get("traveled", 0.0)), 0.0, TRAVEL_DISTANCE),
			"attract_tick_elapsed": clamp(float(saved_data.get("attract_tick_elapsed", 0.0)), 0.0, PLAYER_MAGE_DARK_CONTRACT_FLOW.ATTRACT_TICK_INTERVAL),
			"collided_ids": {}
		})
	pending_saved_spheres.clear()


func _explode(owner, position: Vector2) -> void:
	PLAYER_MAGE_DARK_CONTRACT_FLOW.apply_explosion(owner, position)
	if owner.has_method("_spawn_burst_effect"):
		owner._spawn_burst_effect(position, PLAYER_MAGE_DARK_CONTRACT_FLOW.BLAST_RADIUS * 0.8, Color(0.4, 0.2, 0.7, 0.85), 0.22)
	if owner.has_method("_spawn_vortex_effect"):
		owner._spawn_vortex_effect(position, PLAYER_MAGE_DARK_CONTRACT_FLOW.BLAST_RADIUS, Color(0.35, 0.18, 0.65, 0.5), 0.28)
	if owner.has_method("_spawn_ring_effect"):
		owner._spawn_ring_effect(position, PLAYER_MAGE_DARK_CONTRACT_FLOW.BLAST_RADIUS, Color(0.55, 0.3, 0.9, 0.9), 3.0, 0.26)
		owner._spawn_ring_effect(position, PLAYER_MAGE_DARK_CONTRACT_FLOW.BLAST_RADIUS * 0.5, Color(0.9, 0.8, 1.0, 0.75), 2.0, 0.18)
	if owner.has_method("_queue_camera_shake"):
		owner._queue_camera_shake(12.0, 0.22)


func _clear_spheres() -> void:
	for data in active_spheres:
		var sphere: Node2D = data.get("node", null) as Node2D
		if sphere != null and is_instance_valid(sphere):
			sphere.queue_free()
	active_spheres.clear()


func _encode_vector2(value: Vector2) -> Array:
	return [value.x, value.y]


func _decode_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback


func _is_unlocked(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))

extends RefCounted

const PLAYER_GUNNER_EXPLOSIVE_ROUND_FLOW := preload("res://scripts/player/player_gunner_explosive_round_flow.gd")
const EXPLOSIVE_ROUND_VISUAL_SCRIPT := preload("res://scripts/player/gunner_explosive_round_visual.gd")

const SKILL_ID := "explosive_round"
const COOLDOWN := 8.0
const PROJECTILE_SPEED := 620.0
const PROJECTILE_LIFETIME := 0.95

var cooldown_remaining: float = 0.0
var active_projectiles: Array[Dictionary] = []
var pending_saved_projectiles: Array[Dictionary] = []

func update(owner, delta: float) -> void:
	cooldown_remaining = max(0.0, cooldown_remaining - delta)
	for index in range(active_projectiles.size() - 1, -1, -1):
		var data: Dictionary = active_projectiles[index]
		var projectile: Node2D = data.get("node", null) as Node2D
		if owner == null or not is_instance_valid(owner) or projectile == null or not is_instance_valid(projectile):
			active_projectiles.remove_at(index)
			continue
		var direction: Vector2 = data.get("direction", Vector2.RIGHT)
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var next_position: Vector2 = projectile.global_position + direction * PROJECTILE_SPEED * delta
		var hit_enemy: Node2D = PLAYER_GUNNER_EXPLOSIVE_ROUND_FLOW.find_enemy_between(owner, projectile.global_position, next_position)
		projectile.global_position = next_position
		data["elapsed"] = elapsed
		active_projectiles[index] = data
		if hit_enemy != null or elapsed >= PROJECTILE_LIFETIME:
			_explode(owner, projectile.global_position if hit_enemy == null else hit_enemy.global_position, direction, hit_enemy)
			if is_instance_valid(projectile):
				projectile.queue_free()
			active_projectiles.remove_at(index)

func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and role_id == "gunner" and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and _is_unlocked(owner) and cooldown_remaining <= 0.0

func try_trigger(owner) -> bool:
	if not can_trigger(owner, "gunner"):
		return false
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return false
	var direction: Vector2 = owner._get_live_mouse_aim_direction(owner.facing_direction)
	if direction.length_squared() <= 0.001:
		direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	direction = direction.normalized()
	owner.facing_direction = direction
	var projectile: Node2D = Node2D.new()
	projectile.name = "GunnerExplosiveRound"
	projectile.global_position = owner.global_position + direction * 26.0
	projectile.z_index = 28
	projectile.set_script(EXPLOSIVE_ROUND_VISUAL_SCRIPT)
	projectile.set("direction", direction)
	cooldown_remaining = COOLDOWN
	scene.add_child(projectile)
	active_projectiles.append({"node": projectile, "direction": direction, "elapsed": 0.0})
	return true

func get_cooldown_slot(owner = null) -> Dictionary:
	return {
		"name": "爆破弹",
		"remaining": clamp(cooldown_remaining, 0.0, COOLDOWN),
		"duration": COOLDOWN,
		"color": Color(1.0, 0.42, 0.18, 1.0),
		"description": "发射爆破弹，命中敌人造成 280% 伤害，爆炸沿飞行方向形成 60° 扇形造成 160% 伤害。"
	}
func get_save_data() -> Dictionary:
	var projectiles: Array[Dictionary] = []
	for data in active_projectiles:
		var projectile: Node2D = data.get("node", null) as Node2D
		if projectile == null or not is_instance_valid(projectile):
			continue
		var direction: Vector2 = data.get("direction", Vector2.RIGHT)
		projectiles.append({
			"position": [projectile.global_position.x, projectile.global_position.y],
			"direction": [direction.x, direction.y],
			"elapsed": max(0.0, float(data.get("elapsed", 0.0)))
		})
	return {"cooldown_remaining": cooldown_remaining, "projectiles": projectiles}

func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	_clear_projectiles()
	pending_saved_projectiles.clear()
	var saved_projectiles: Variant = data.get("projectiles", [])
	if saved_projectiles is Array:
		for saved_data in saved_projectiles:
			if saved_data is Dictionary:
				pending_saved_projectiles.append((saved_data as Dictionary).duplicate(true))

func restore_effect_if_active(owner) -> void:
	var tree: SceneTree = owner.get_tree() if owner != null and is_instance_valid(owner) and owner.has_method("get_tree") else null
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return
	for saved_data in pending_saved_projectiles:
		var direction := _decode_vector2(saved_data.get("direction", []), Vector2.RIGHT).normalized()
		var projectile := Node2D.new()
		projectile.name = "GunnerExplosiveRound"
		projectile.global_position = _decode_vector2(saved_data.get("position", []), owner.global_position)
		projectile.z_index = 28
		projectile.set_script(EXPLOSIVE_ROUND_VISUAL_SCRIPT)
		projectile.set("direction", direction)
		scene.add_child(projectile)
		active_projectiles.append({
			"node": projectile,
			"direction": direction,
			"elapsed": clamp(float(saved_data.get("elapsed", 0.0)), 0.0, PROJECTILE_LIFETIME)
		})
	pending_saved_projectiles.clear()

func _explode(owner, center: Vector2, direction: Vector2, hit_enemy: Node2D) -> void:
	PLAYER_GUNNER_EXPLOSIVE_ROUND_FLOW.apply_explosion(owner, center, direction, hit_enemy)
	if owner.has_method("_spawn_cone_effect"):
		owner._spawn_cone_effect(center, direction, PLAYER_GUNNER_EXPLOSIVE_ROUND_FLOW.BLAST_CONE_RADIUS, rad_to_deg(PLAYER_GUNNER_EXPLOSIVE_ROUND_FLOW.BLAST_CONE_ANGLE), Color(1.0, 0.42, 0.12, 0.42), 0.2)
	if owner.has_method("_queue_camera_shake"):
		owner._queue_camera_shake(13.5, 0.22)

func _clear_projectiles() -> void:
	for data in active_projectiles:
		var projectile: Node2D = data.get("node", null) as Node2D
		if projectile != null and is_instance_valid(projectile):
			projectile.queue_free()
	active_projectiles.clear()

func _decode_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback

func _is_unlocked(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))

extends Node2D

const ROSE_VISUAL_SCENE := preload("res://assets/enemies/rose/rose.tscn")
const ROSE_BULLET_STYLE := "rose_flower"
const ATTACK_INTERVAL := 1.0
const ATTACK_SPREAD := 0.14
const ATTACK_BULLET_COUNT := 3
const MINION_LIFETIME := 10.0
const OWNER_MISSING_HEALTH_HEAL_RATIO := 0.05

var owner_ref: WeakRef
var target: Node2D
var projectile_scene: PackedScene
var projectile_speed: float = 320.0
var projectile_damage: float = 10.0
var projectile_lifetime: float = 4.4
var attack_timer: float = 0.0
var remaining_lifetime: float = MINION_LIFETIME
var visual: Node2D


func configure(owner, target_node: Node2D, enemy_projectile_scene: PackedScene, boss_scale: Vector2, damage: float, speed: float, shot_lifetime: float) -> void:
	owner_ref = weakref(owner)
	target = target_node
	projectile_scene = enemy_projectile_scene
	projectile_damage = damage
	projectile_speed = speed
	projectile_lifetime = shot_lifetime
	scale = boss_scale * 0.5
	attack_timer = randf_range(0.05, 0.35)
	remaining_lifetime = MINION_LIFETIME
	_ensure_visual()
	set_process(true)


func _process(delta: float) -> void:
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0:
		_heal_owner()
		queue_free()
		return
	_update_facing()
	attack_timer -= delta
	if attack_timer > 0.0:
		return
	attack_timer += ATTACK_INTERVAL
	_fire_attack()


func _fire_attack() -> void:
	if target == null or not is_instance_valid(target):
		return
	var aim_direction: Vector2 = global_position.direction_to(target.global_position)
	if aim_direction.length_squared() <= 0.001:
		aim_direction = Vector2.RIGHT
	_play_attack_visual()
	var offset_center: float = float(ATTACK_BULLET_COUNT - 1) * 0.5
	for index in range(ATTACK_BULLET_COUNT):
		var shot_direction: Vector2 = aim_direction.rotated((float(index) - offset_center) * ATTACK_SPREAD)
		_spawn_projectile(global_position + shot_direction * 18.0, shot_direction, projectile_speed, projectile_damage, projectile_lifetime, 0.82)


func _spawn_projectile(origin: Vector2, shot_direction: Vector2, speed: float, damage: float, shot_lifetime: float, size_scale: float) -> void:
	if projectile_scene == null or not is_inside_tree():
		return
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var projectile = null
	if current_scene.has_method("take_runtime_enemy_projectile_from_pool"):
		projectile = current_scene.take_runtime_enemy_projectile_from_pool()
	if projectile == null:
		projectile = projectile_scene.instantiate()
	if projectile == null:
		return
	if projectile.get_parent() == null:
		current_scene.add_child(projectile)
	elif projectile.get_parent() != current_scene:
		projectile.get_parent().remove_child(projectile)
		current_scene.add_child(projectile)
	if projectile.has_method("reset_projectile"):
		var difficulty_speed_bonus := 0.0
		if current_scene.has_method("_get_difficulty_projectile_speed_bonus"):
			difficulty_speed_bonus = max(0.0, float(current_scene._get_difficulty_projectile_speed_bonus()))
		projectile.reset_projectile({
			"position": origin,
			"direction": shot_direction.normalized(),
			"speed": speed + difficulty_speed_bonus,
			"damage": damage,
			"lifetime": shot_lifetime,
			"hit_radius": 14.0 * size_scale,
			"motion_mode": "straight",
			"visual_style": ROSE_BULLET_STYLE,
			"size_scale": size_scale,
			"target": target
		})


func _heal_owner() -> void:
	var owner = owner_ref.get_ref() if owner_ref != null else null
	if owner == null or not is_instance_valid(owner):
		return
	var missing_health: float = max(0.0, float(owner.max_health) - float(owner.current_health))
	if missing_health <= 0.0:
		return
	owner.current_health = min(float(owner.max_health), float(owner.current_health) + missing_health * OWNER_MISSING_HEALTH_HEAL_RATIO)
	if owner.has_method("_spawn_status_burst"):
		owner._spawn_status_burst(Color(0.95, 0.22, 0.38, 0.18), 34.0 + owner.scale.x * 8.0)


func _ensure_visual() -> void:
	if visual != null:
		return
	visual = ROSE_VISUAL_SCENE.instantiate() as Node2D
	if visual == null:
		return
	add_child(visual)
	if visual.has_method("set_moving"):
		visual.set_moving(false)


func _play_attack_visual() -> void:
	_ensure_visual()
	if visual != null and visual.has_method("play_attack"):
		visual.play_attack()


func _update_facing() -> void:
	if target == null or not is_instance_valid(target):
		return
	_ensure_visual()
	if visual != null and visual.has_method("set_facing_direction"):
		visual.set_facing_direction(global_position.direction_to(target.global_position))

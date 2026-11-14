extends SceneTree

const DIRECTION := preload("res://scripts/combat/attack_hit_direction.gd")
const RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const QUEUE := preload("res://scripts/player/player_damage_job_queue.gd")
const BATCHER := preload("res://scripts/player/player_damage_batcher.gd")
const DEATH := preload("res://scripts/enemies/enemy_death_effects.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const BULLET := preload("res://scenes/bullet.tscn")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var owner := AimOwner.new()
	scene.add_child(owner)
	check(DIRECTION.resolve(owner).is_equal_approx(Vector2.RIGHT), "ordinary hits follow current aim")
	check(DIRECTION.resolve(owner, Vector2.LEFT * 4).is_equal_approx(Vector2.LEFT), "detached direction overrides aim and normalizes")
	check(DIRECTION.for_shape(owner, {"type": "oriented_rect", "axis": Vector2.UP, "hit_registry": {"slash_direction": Vector2.RIGHT}}).is_equal_approx(Vector2.RIGHT), "slash uses attack direction instead of perpendicular rectangle axis")
	var queue := QUEUE.new()
	queue.configure(owner)
	scene.add_child(queue)
	queue.set_process(false)
	queue.set_physics_process(false)
	var enemy = make_enemy(scene, owner)
	queue.enqueue_values(weakref(enemy), enemy.get_instance_id(), 100.0, 1, "swordsman")
	owner.facing_direction = Vector2.UP
	queue._apply_job_at_index(0)
	await verify_flight(scene, Vector2.RIGHT)
	queue._clear_jobs()
	queue.pending_by_enemy_id.clear()

	# A real projectile keeps its own travel direction while its owner aims up.
	enemy = make_enemy(scene, owner)
	var bullet = BULLET.instantiate()
	scene.add_child(bullet)
	bullet.set_physics_process(false)
	bullet.source_player = owner
	bullet.source_role_id = "swordsman"
	bullet.damage = 100.0
	bullet.direction = Vector2.LEFT
	bullet._apply_hit(enemy)
	var damage_queue := scene.get_node_or_null("PlayerDamageJobQueue")
	if damage_queue != null:
		damage_queue.set_process(false)
		damage_queue.set_physics_process(false)
		damage_queue._apply_job_at_index(0)
	await verify_flight(scene, Vector2.LEFT)
	if is_instance_valid(bullet):
		bullet.queue_free()
	if damage_queue != null:
		damage_queue.free()

	# Opposite hits cannot merge and replace the actual lethal hit's direction.
	enemy = make_enemy(scene, owner)
	var batcher := BATCHER.new(owner)
	batcher.add_enemy(enemy, 0.25, "swordsman", 0.0, 2.0, 1.0, 0.0, null, 0.0, false, false, "", "", Vector2.RIGHT)
	batcher.add_enemy(enemy, 100.0, "swordsman", 0.0, 2.0, 1.0, 0.0, null, 0.0, false, false, "", "", Vector2.DOWN)
	check(batcher.enemy_refs.size() == 2, "different attack directions must remain separate batch entries")
	queue.enqueue_values(weakref(enemy), enemy.get_instance_id(), 0.25, 1, "swordsman", 0.0, 2.0, 1.0, 0.0, null, 0.0, true, false, false, "", "", Vector2.RIGHT)
	queue.enqueue_values(weakref(enemy), enemy.get_instance_id(), 100.0, 1, "swordsman", 0.0, 2.0, 1.0, 0.0, null, 0.0, true, false, false, "", "", Vector2.DOWN)
	check(queue.enemy_refs.size() == 2, "different attack directions must remain separate queue jobs")
	queue._apply_job_at_index(0)
	queue.job_cursor = 1
	queue._compact_processed_jobs(true)
	check(queue.hit_directions.size() == 1 and queue.hit_directions[0].is_equal_approx(Vector2.DOWN), "compaction preserves remaining direction")
	queue.feedback_jobs_used_this_frame = 100
	queue._apply_job_at_index(0)
	await verify_flight(scene, Vector2.DOWN)
	batcher.reset(owner)
	check(batcher.hit_directions.is_empty(), "batch reuse clears directions")

	enemy = make_enemy(scene, owner)
	enemy.take_damage(0.25, false, Vector2.LEFT)
	enemy.take_damage(100.0)
	await verify_flight(scene, Vector2.UP)

	preload("res://scripts/player/player_mage_fireball_flow.gd").apply_impact(owner, Vector2.ZERO, 10.0, 100.0, Vector2.LEFT)
	check(owner.last_radius_direction == Vector2.LEFT, "fireball impact preserves detached direction")
	preload("res://scripts/player/player_gunner_magic_grenade_flow.gd").apply_explosion(owner, Vector2.ZERO, "", Vector2.DOWN)
	check(owner.last_radius_direction == Vector2.DOWN, "grenade explosion preserves arrival direction")
	preload("res://scripts/player/player_mage_dark_contract_flow.gd").apply_explosion(owner, Vector2.ZERO, Vector2.RIGHT)
	check(owner.last_radius_direction == Vector2.RIGHT, "dark sphere explosion preserves travel direction")

	# Cleanup animation has no attacking source and remains stationary.
	enemy = make_enemy(scene, owner)
	DEATH.spawn_spin_shrink(enemy)
	enemy.free()
	await verify_flight(scene, Vector2.ZERO)
	scene.queue_free()
	await process_frame
	current_scene = null
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("ENEMY_DEATH_DIRECTION_SMOKE_OK")
	quit(0 if failures.is_empty() else 1)

func make_enemy(scene: Node, owner: Node):
	var enemy = ENEMY.instantiate()
	scene.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set_process(false)
	enemy.target = owner
	enemy.current_health = 1.0
	enemy.armor = 0.0
	enemy.archetype_id = "tree_seed" # Prevent random test pickups.
	enemy.global_position = Vector2(160.0, 120.0)
	return enemy

func verify_flight(scene: Node, expected_direction: Vector2) -> void:
	var visual: Node2D
	for child in scene.get_children():
		if str(child.name).begins_with("EnemySpinShrinkDeath"):
			visual = child
			break
	check(visual != null, "lethal hit creates independent death visual")
	if visual == null:
		return
	var start := visual.global_position
	var start_scale := visual.scale
	# Step the actual animation deterministically without opening a window.
	for tween in get_processed_tweens():
		if tween.is_valid():
			tween.pause()
			tween.custom_step(DEATH.SPIN_SHRINK_DURATION * 0.5)
	var displacement := visual.global_position - start
	if expected_direction == Vector2.ZERO:
		check(displacement.is_zero_approx(), "wave cleanup has no attack knockback")
	else:
		check(displacement.dot(expected_direction) > 20.0, "death flies along the lethal attack")
		check(absf(displacement.cross(expected_direction)) < 0.01, "death does not drift sideways")
	check(visual.scale.length() < start_scale.length(), "death visual shrinks while flying")
	check(absf(visual.rotation) > 0.1, "death visual spins while flying")
	for tween in get_processed_tweens():
		if tween.is_valid():
			tween.custom_step(DEATH.SPIN_SHRINK_DURATION)
	await process_frame
	check(not is_instance_valid(visual), "death visual is removed after animation")

class AimOwner:
	extends Node2D
	var facing_direction := Vector2.RIGHT
	var last_radius_direction := Vector2.ZERO
	var blessing_skill_state: Dictionary = {}
	var role_special_states: Dictionary = {}
	func _has_level_talent(_talent: String) -> bool:
		return false
	func _get_skill_level(_role: String, _skill: String) -> int:
		return 0
	func _get_role_damage(_role: String) -> float:
		return 10.0
	func _damage_enemies_in_radius(_center: Vector2, _radius: float, _damage: float, _vulnerability: float, _slow: float, _duration: float, _source: String = "", _slow_source: String = "", direction: Vector2 = Vector2.ZERO) -> int:
		last_radius_direction = direction
		return 0
	func _get_attack_aim_direction(_fallback: Vector2) -> Vector2:
		return facing_direction
	func _deal_damage_to_enemy(enemy: Node, amount: float, source: String, vulnerability: float = 0.0, duration: float = 2.0, slow: float = 1.0, slow_duration: float = 0.0, origin: Variant = null, silent: bool = false, energy: float = 0.0, direction: Vector2 = Vector2.ZERO) -> bool:
		return RESOLVER.deal_damage_to_enemy(self, enemy, amount, source, vulnerability, duration, slow, slow_duration, origin, silent, energy, false, "", "", -1, direction)

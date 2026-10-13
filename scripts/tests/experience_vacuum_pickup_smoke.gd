extends SceneTree

const ENEMY_DROPS := preload("res://scripts/enemies/enemy_drops.gd")
const PLAYER_SURVIVAL_FLOW := preload("res://scripts/player/player_survival_flow.gd")
const EXP_GEM_SCENE := preload("res://scenes/exp_gem.tscn")
const VACUUM_SCENE := preload("res://scenes/experience_vacuum_pickup.tscn")
const SAVE_RUNTIME := preload("res://scripts/game/run_save_runtime_flow.gd")
const COMPACTOR := preload("res://scripts/game/pickup_compactor.gd")
const ENEMY_DAMAGE := preload("res://scripts/enemies/enemy_damage.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := RuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene
	var player := PickupPlayer.new()
	scene.player = player
	scene.add_child(player)
	_check_drop_rules(scene)
	await _check_collection_and_save(scene, player)
	scene.free_pools()
	scene.queue_free()
	await process_frame
	current_scene = null
	if failures.is_empty():
		print("EXPERIENCE_VACUUM_PICKUP_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_drop_rules(scene: Node2D) -> void:
	var enemy := DropEnemy.new()
	enemy.global_position = Vector2(20.0, 30.0)
	scene.add_child(enemy)
	for kind in ["normal", "elite", "small_boss", "boss"]:
		enemy.enemy_kind = kind
		_expect(ENEMY_DROPS.maybe_drop_experience_vacuum(enemy, 0.0005) == null, "0.05% boundary must miss for " + kind)
		_expect(ENEMY_DROPS.maybe_drop_experience_vacuum(enemy, 0.5) == null, "ordinary losing roll must miss for " + kind)
		var pickup := ENEMY_DROPS.maybe_drop_experience_vacuum(enemy, 0.000499)
		_expect(pickup != null and pickup.global_position == enemy.global_position, "winning roll must drop at the enemy for " + kind)
		pickup.recycle()
	enemy.drop_absorber = scene
	_expect(ENEMY_DROPS.maybe_drop_experience_vacuum(enemy, 0.0) == null, "tree-devoured enemies must not drop player kill pickups")
	enemy.free()

	# Exercise the actual final-lethal-damage callback with a deterministic roll.
	var winning_seed: int = -1
	for candidate in range(50000):
		seed(candidate)
		if randf() < 0.0005:
			winning_seed = candidate
			break
	_expect(winning_seed >= 0, "deterministic winning seed must exist")
	var killed_enemy := KillEnemy.new()
	scene.add_child(killed_enemy)
	killed_enemy.set_physics_process(false)
	killed_enemy.current_health = 1.0
	killed_enemy.armor = 0.0
	seed(winning_seed)
	_expect(ENEMY_DAMAGE.apply_damage(killed_enemy, 10.0, false), "lethal hit must complete the enemy defeat")
	var drops: Array = scene.get_runtime_pickups("experience_vacuum_pickups")
	_expect(drops.size() == 1, "a real lethal hit must invoke the new drop hook once")
	for pickup in drops:
		pickup.recycle()


func _check_collection_and_save(scene, player) -> void:
	var pickup: Node2D = scene.take_runtime_pickup_from_pool("experience_vacuum_pickups")
	_expect(pickup != null, "dropped vacuum should reuse the existing pool")
	scene.add_child(pickup)
	pickup.reset_pickup(Vector2(350.0, 0.0))
	var expected_experience := 0
	for index in range(180):
		var gem := EXP_GEM_SCENE.instantiate() as Node2D
		scene.add_child(gem)
		gem.reset_pickup(Vector2.RIGHT.rotated(float(index) * 0.3) * 1200.0, index % 4 + 1, index % 9 + 1)
		gem.set_physics_process(false)
		gem.age_seconds = 49.9
		expected_experience += int(gem.value)
	PLAYER_SURVIVAL_FLOW.collect_nearby_gems(player)
	_expect(not bool(pickup.pooled), "vacuum must be picked up at the player's normal pickup distance")
	pickup.global_position = Vector2(20.0, 0.0)
	scene._mark_runtime_pickup_cache_dirty("experience_vacuum_pickups")
	PLAYER_SURVIVAL_FLOW.collect_nearby_gems(player)
	_expect(bool(pickup.pooled), "nearby vacuum must be consumed by the real player collection flow")
	for gem in scene.get_runtime_pickups("exp_gems"):
		_expect(bool(gem.attraction_active) and gem.attraction_target_node == player, "all 180 distant crystals must be attracted")
		gem.batch_physics_process(0.2)
		_expect(not bool(gem.pooled), "attracted crystals must not expire during their flight")

	# A consumed item cannot activate again and scoop up future drops.
	var future := EXP_GEM_SCENE.instantiate() as Node2D
	scene.add_child(future)
	future.reset_pickup(Vector2(1400.0, 800.0), 1, 5)
	future.set_physics_process(false)
	pickup.collect(player)
	_expect(not bool(future.attraction_active), "future drops must keep normal attraction range")
	var heart: Node2D = scene.heart_pickup_scene.instantiate()
	scene.add_child(heart)
	heart.reset_pickup(Vector2(1000.0, 800.0), 50.0)
	heart.set_physics_process(false)

	var waiting := VACUUM_SCENE.instantiate() as Node2D
	scene.add_child(waiting)
	waiting.reset_pickup(Vector2(-800.0, 350.0))
	var payload: Dictionary = {"gems": [], "experience_vacuum_pickups": []}
	SAVE_RUNTIME.append_group_save_data(scene, payload, "gems", "exp_gems")
	SAVE_RUNTIME.append_group_save_data(scene, payload, "experience_vacuum_pickups", "experience_vacuum_pickups")
	payload = JSON.parse_string(JSON.stringify(payload))
	_expect(payload["gems"].size() == 181 and payload["experience_vacuum_pickups"].size() == 1, "save includes active gems and only unconsumed vacuums")
	for gem in scene.get_runtime_pickups("exp_gems").duplicate():
		gem.recycle()
	waiting.recycle()
	SAVE_RUNTIME.restore_gems(scene, payload["gems"])
	SAVE_RUNTIME.restore_experience_vacuum_pickups(scene, payload["experience_vacuum_pickups"])
	var restored: Array = scene.get_runtime_pickups("experience_vacuum_pickups")
	_expect(restored.size() == 1 and restored[0].global_position == Vector2(-800.0, 350.0), "runtime restore recovers the waiting vacuum")
	var active_count := 0
	for gem in scene.get_runtime_pickups("exp_gems"):
		gem.set_physics_process(false)
		if gem.attraction_active:
			active_count += 1
			_expect(gem.attraction_target_node == player, "loaded crystals must follow the current player")
	_expect(active_count == 180, "restore must retain exactly the previously attracted crystals")

	# Follow a moving player and drain more crystals than a single scan allows.
	player.global_position = Vector2(60.0, 45.0)
	for _step in range(24):
		await physics_frame
		for gem in scene.get_runtime_pickups("exp_gems").duplicate():
			gem.batch_physics_process(0.2)
		scene._mark_runtime_pickup_cache_dirty("exp_gems")
		PLAYER_SURVIVAL_FLOW.collect_nearby_gems(player)
	_expect(player.experience_received == expected_experience, "all original experience must be granted exactly once without changing tier values")
	_expect(scene.get_runtime_pickups("exp_gems").size() == 1, "only the future unmarked crystal should remain")
	_expect(scene.get_runtime_pickups("heart_pickups").size() == 1 and player.healing_received == 0.0, "vacuum must not collect hearts")
	PLAYER_SURVIVAL_FLOW.collect_nearby_gems(player)
	_expect(player.experience_received == expected_experience, "repeated scans must not grant duplicate experience")

	var legacy := EXP_GEM_SCENE.instantiate() as Node2D
	scene.add_child(legacy)
	legacy.apply_save_data({"position": [900.0, 400.0], "value": 17, "tier": 2})
	_expect(not legacy.attraction_active and legacy.value == 17, "old saves must retain normal unmarked crystals")
	var pulled := EXP_GEM_SCENE.instantiate() as Node2D
	scene.add_child(pulled)
	pulled.reset_pickup(Vector2(950.0, 400.0), 1, 5)
	pulled.set_attraction_target(player)
	var merged_value: int = legacy.value + pulled.value
	COMPACTOR._merge_exp_gem(legacy, pulled)
	_expect(legacy.attraction_active and legacy.attraction_target_node == player and legacy.value == merged_value, "compaction must preserve both experience and an existing attraction")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


class RuntimeRoot:
	extends "res://scripts/main.gd"

	func _ready() -> void:
		game_over = true
		suppress_exit_save = true
		set_process(false)
		set_physics_process(false)

	func _exit_tree() -> void:
		pass

	func free_pools() -> void:
		for pool in runtime_pickup_pool_nodes.values():
			for pickup in (pool as Dictionary).values():
				if is_instance_valid(pickup):
					pickup.free()
		runtime_pickup_pool_nodes.clear()
		for enemy in runtime_enemy_pool_nodes.values():
			if is_instance_valid(enemy):
				enemy.free()
		runtime_enemy_pool_nodes.clear()


class DropEnemy:
	extends Node2D

	var enemy_kind: String = "normal"
	var drop_absorber = null


class PickupPlayer:
	extends Node2D

	const GEM_ATTRACT_RADIUS := 140.0
	const GEM_ABSORB_RADIUS := 24.0
	var pickup_radius := 34.0
	var experience_received := 0
	var healing_received := 0.0

	func get_hurtbox_center() -> Vector2:
		return global_position

	func get_hurtbox_radius() -> float:
		return 10.0

	func gain_experience(amount: int) -> void:
		experience_received += amount

	func _heal(amount: float) -> void:
		healing_received += amount


class KillEnemy:
	extends "res://scripts/enemy.gd"

	func _ready() -> void:
		pass

	func _drop_experience_gem() -> void:
		pass

	func _maybe_drop_heart() -> void:
		pass

	func _maybe_drop_bones() -> void:
		pass

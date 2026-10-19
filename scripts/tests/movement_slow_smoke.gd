extends SceneTree

const PLAYER := preload("res://scenes/player.tscn")
const ENEMY := preload("res://scenes/enemy.tscn")
const SLOWS := preload("res://scripts/combat/movement_slow.gd")
const STATUS := preload("res://scripts/enemies/enemy_status_effects.gd")
const SAVE := preload("res://scripts/enemies/enemy_save_data.gd")
const POOL := preload("res://scripts/enemies/enemy_pool_lifecycle.gd")
const RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const BATCHER := preload("res://scripts/player/player_damage_batcher.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var player = PLAYER.instantiate()
	scene.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.fire_timer.stop()
	for role in player.roles:
		role["status_resistance"] = 0.0
	var role_id: String = player._get_active_role_id()
	var base_speed: float = player._get_role_move_speed(role_id)
	player.apply_enemy_slow(0.8, 2.0, "a")
	player.apply_enemy_slow(0.7, 4.0, "b")
	check(is_equal_approx(player._get_role_move_speed(role_id), base_speed * 0.56), "player 20% and 30% slow multiply")
	player.plague_remaining = 1.5
	check(is_equal_approx(player._get_role_move_speed(role_id), base_speed * 0.56 * 0.8), "plague multiplies with other slows")
	player.plague_remaining = 0.0
	player._update_timers(1.0)
	player.apply_enemy_slow(0.8, 2.0, "a")
	check(is_equal_approx(player.enemy_move_slow_multiplier, 0.56), "same player effect refreshes without stacking")
	var saved: Dictionary = player.get_save_data()
	player._update_timers(2.0)
	check(is_equal_approx(player.enemy_move_slow_multiplier, 0.7), "only expired player effect removed")
	player.apply_save_data(saved)
	player.fire_timer.stop()
	player._update_timers(2.0)
	check(is_equal_approx(player.enemy_move_slow_multiplier, 0.7), "player save preserves independent expirations")
	player._update_timers(1.0)
	check(is_equal_approx(player.enemy_move_slow_multiplier, 1.0), "player restores original speed")

	var enemy = ENEMY.instantiate()
	scene.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set_process(false)
	enemy.current_health = 10000.0
	enemy.max_health = 10000.0
	enemy.apply_slow_from_source(0.8, 2.0, "a", true)
	enemy.apply_slow_from_source(0.7, 4.0, "b", true)
	check(is_equal_approx(enemy.slow_multiplier, 0.56), "enemy 20% and 30% slow multiply")
	STATUS.tick_timers(enemy, 1.0)
	enemy.apply_slow_from_source(0.8, 2.0, "a", true)
	check(is_equal_approx(enemy.slow_multiplier, 0.56), "same enemy effect refreshes without stacking")
	var enemy_saved: Dictionary = SAVE.get_save_data(enemy)
	STATUS.tick_timers(enemy, 2.0)
	check(is_equal_approx(enemy.slow_multiplier, 0.7), "only expired enemy effect removed")
	SAVE.apply_save_data(enemy, enemy_saved, player)
	STATUS.tick_timers(enemy, 2.0)
	check(is_equal_approx(enemy.slow_multiplier, 0.7), "enemy save preserves independent expirations")
	STATUS.tick_timers(enemy, 1.0)
	check(is_equal_approx(enemy.slow_multiplier, 1.0), "enemy restores original speed")

	# Different skills with identical damage attribution must survive batching and queueing.
	var batcher := BATCHER.new(player)
	batcher.add_enemy(enemy, 0.0, "mage", 0.0, 0.0, 0.8, 2.0, null, 0.0, true, false, "", "mage_meta_field")
	batcher.add_enemy(enemy, 0.0, "mage", 0.0, 0.0, 0.7, 4.0, null, 0.0, true, false, "", "mage_tidal_surge")
	batcher.flush()
	var queue = scene.get_node("PlayerDamageJobQueue")
	queue.set_physics_process(false)
	queue._physics_process(0.0)
	check(is_equal_approx(enemy.slow_multiplier, 0.56), "batching and queue preserve different skill slows")
	RESOLVER.deal_damage_to_enemy(player, enemy, 0.0, "mage", 0.0, 0.0, 0.8, 2.0, null, true, 0.0, false, "", "mage_meta_field")
	check(is_equal_approx(enemy.slow_multiplier, 0.56), "direct and queued hits refresh the same effect")
	RESOLVER.queue_damage_to_enemy(player, enemy, 0.0, "mage", 0.0, 0.0, 0.8, 2.0, null, false, true, false, "", "another_skill")
	await process_frame
	# The first process_frame signal can precede the initial frame counter increment.
	await process_frame
	queue._physics_process(0.0)
	check(is_equal_approx(enemy.slow_multiplier, 0.56 * 0.8), "non-batched queue preserves separate same-strength effects")
	POOL.prepare_for_pool(enemy)
	check(SLOWS.save(enemy).is_empty() and is_equal_approx(enemy.slow_multiplier, 1.0), "pool clears all slow effects")

	enemy.status_resistance = 0.2
	enemy.apply_slow_from_source(0.8, 10.0, "a", true)
	enemy.apply_slow_from_source(0.7, 5.0, "b", true)
	check(is_equal_approx(enemy.slow_multiplier, 0.56), "resistance does not weaken slow magnitude")
	STATUS.tick_timers(enemy, 4.0)
	check(is_equal_approx(enemy.slow_multiplier, 0.8) and is_equal_approx(enemy.slow_timer, 4.0), "resistance scales each duration exactly once")
	POOL.prepare_for_pool(enemy)
	enemy.slow_multiplier = 0.7
	enemy.slow_timer = 3.0
	STATUS.tick_timers(enemy, 1.0)
	check(is_equal_approx(enemy.slow_multiplier, 0.7) and is_equal_approx(enemy.slow_timer, 2.0), "combined-only saves retain remaining slow")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("MOVEMENT_SLOW_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

extends SceneTree

const EnemyDirector := preload("res://scripts/enemy/enemy_director.gd")
const EnemySpawnFlow := preload("res://scripts/game/enemy_spawn_flow.gd")

var failures: Array[String] = []

class MainStub:
	extends Node2D

	var map_bounds := Rect2(Vector2(-240.0, -160.0), Vector2(480.0, 320.0))
	var player: Node2D

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_spawn_positions_stay_inside_map()
	_check_wave_plan_batches_multiple_packs()
	_check_late_game_spawn_timing()
	if failures.is_empty():
		print("ENEMY_SPAWN_FLOW_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_spawn_positions_stay_inside_map() -> void:
	var main := MainStub.new()
	var player := Node2D.new()
	player.global_position = Vector2.ZERO
	main.player = player
	main.add_child(player)
	get_root().add_child(main)
	for index in range(48):
		var position: Vector2 = EnemySpawnFlow.get_spawn_position(main, TAU * float(index) / 48.0, 900.0)
		var safe_bounds: Rect2 = main.map_bounds.grow(-36.0)
		if not safe_bounds.has_point(position):
			failures.append("spawn position should stay inside map bounds: %s" % str(position))
			break
	main.queue_free()

func _check_wave_plan_batches_multiple_packs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var profile := EnemyDirector.get_wave_profile(180.0, EnemyDirector.get_default_elite_spawn_times(), 8.0, 8.0)
	var pack_interval: float = EnemyDirector.get_spawn_interval(
		EnemyDirector.get_default_starting_spawn_interval(),
		EnemyDirector.get_default_minimum_spawn_interval(),
		180.0,
		EnemyDirector.get_default_boss_spawn_time(),
		profile,
		1.0
	)
	var batch_interval: float = EnemyDirector.get_wave_batch_interval(pack_interval)
	var plan: Array = EnemyDirector.pick_spawn_wave_plan(profile, rng, pack_interval, batch_interval, 80)
	if plan.size() < 2:
		failures.append("spawn wave plan should batch multiple packs, got %s" % str(plan))
	var total_count := 0
	for pack in plan:
		total_count += int((pack as Dictionary).get("count", 0))
	if total_count <= 1:
		failures.append("spawn wave plan should spawn a visible wave, got total count %d" % total_count)

func _check_late_game_spawn_timing() -> void:
	var elite_times: Array = EnemyDirector.get_default_elite_spawn_times()
	if elite_times.is_empty():
		failures.append("elite spawn times should not be empty")
	elif float(elite_times[0]) < 360.0:
		failures.append("first elite should not spawn before 360s, got %.2f" % float(elite_times[0]))
	if EnemyDirector.get_active_enemy_limit(359.9) != 40:
		failures.append("early active enemy limit should be 40")
	if EnemyDirector.get_active_enemy_limit(360.0) != 60:
		failures.append("late active enemy limit should be 60")
	if EnemyDirector.get_cycle_active_enemy_limit(120.0) != 40:
		failures.append("cycle first half active enemy limit should reset to 40")
	if EnemyDirector.get_cycle_active_enemy_limit(480.0) != 60:
		failures.append("cycle second half active enemy limit should be 60")

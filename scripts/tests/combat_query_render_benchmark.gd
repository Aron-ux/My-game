extends SceneTree

# Fixed workload for query/sorting/render-submission CPU costs, without saves.
const FIXTURE := preload("res://scripts/tests/dense_combat_benchmark_smoke.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const BULLET := preload("res://scenes/bullet.tscn")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const BATCH := preload("res://scripts/player/player_projectile_batch.gd")
const SORT := preload("res://scripts/enemies/enemy_occlusion_sort.gd")
const GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")
const SAMPLES := 30
const ENEMY_COUNT := 240
const PROBES := 240


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 0
	var scene := FIXTURE.BenchmarkRuntimeRoot.new()
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scene)
	current_scene = scene
	var source := Node2D.new()
	scene.add_child(source)
	for index in range(ENEMY_COUNT):
		var enemy = ENEMY.instantiate()
		scene.add_child(enemy)
		var is_boss := index % 60 == 0
		enemy.apply_enemy_profile("small_boss" if is_boss else "normal", DATABASE.get_profile("small_boss", "smallboss_glutton") if is_boss else DATABASE.get_profile("normal", "chaser"))
		enemy.position = Vector2((index % 20) * 42.0 - 420.0, (index / 20) * 50.0 - 300.0)
		enemy.set_meta("benchmark_index", index + 1)
	var bullet = BULLET.instantiate()
	bullet.source_player = source
	scene.add_child(bullet)
	bullet.set_physics_process(false)
	var batch := BATCH.new()
	scene.add_child(batch)
	batch.set_physics_process(false)
	for index in range(720):
		batch.add_projectile({"position": Vector2((index % 24) * 35.0 - 420.0, (index / 24) * 22.0 - 330.0), "direction": Vector2.RIGHT.rotated(index * 0.13), "lifetime": 100.0, "visual_outline_width": 1.5, "color": Color(0.9, 0.6, 0.3, 0.8)})
	var timings := {"single_projectile_queries": [], "batched_projectile_queries": [], "occlusion_sort": [], "render_submission": []}
	var checks := {}
	for sample in range(SAMPLES + 3):
		await physics_frame
		var grid := GRID.get_grid(scene)
		var single_checksum := 0
		var batch_checksum := 0
		var started := Time.get_ticks_usec()
		for index in range(PROBES):
			var position := batch.positions[index]
			for enemy in bullet._get_candidate_enemies_near(position, 390.0):
				if bullet._segment_hits_enemy(enemy, position, position + Vector2(8.0, 0.0)):
					single_checksum += int(enemy.get_meta("benchmark_index"))
					break
		_record(timings.single_projectile_queries, started, sample)
		started = Time.get_ticks_usec()
		for index in range(PROBES):
			var enemy := batch._find_hit_enemy(index, grid)
			if enemy != null:
				batch_checksum += int(enemy.get_meta("benchmark_index"))
		_record(timings.batched_projectile_queries, started, sample)
		started = Time.get_ticks_usec()
		SORT._update_scene(scene)
		_record(timings.occlusion_sort, started, sample)
		batch.last_multimesh_refresh_frame = -1
		started = Time.get_ticks_usec()
		batch._update_multimesh_instances()
		_record(timings.render_submission, started, sample)
		var sort_checksum := 0
		for enemy in scene.get_runtime_enemies():
			sort_checksum += enemy.z_index * int(enemy.get_meta("benchmark_index"))
		var current_checks := {"single_hits": single_checksum, "batch_hits": batch_checksum, "sort": sort_checksum, "visible_projectiles": batch.bullet_multimesh.visible_instance_count}
		if checks.is_empty():
			checks = current_checks
		else:
			assert(checks == current_checks)
	var result := {"checks": checks, "workload": {"enemies": ENEMY_COUNT, "query_probes": PROBES, "rendered_projectiles": 720, "samples": SAMPLES}, "display": DisplayServer.get_name()}
	for key in timings:
		var samples: Array = timings[key]
		samples.sort()
		result[key] = {"median_ms": samples[SAMPLES / 2], "p95_ms": samples[ceili(SAMPLES * 0.95) - 1]}
	var label := OS.get_environment("COMBAT_BENCHMARK_LABEL")
	var output := FileAccess.open("res://.omx/performance/query_render_%s.json" % label, FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print(JSON.stringify(result))
	bullet.clear_runtime_state()
	scene.free()
	current_scene = null
	print("COMBAT_QUERY_RENDER_BENCHMARK_OK")
	quit()


func _record(samples: Array, started: int, sample: int) -> void:
	if sample >= 3:
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)

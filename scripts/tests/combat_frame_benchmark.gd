extends SceneTree

# Identical fixed-step workload for comparing commits; no production save writes.
const FIXTURE := preload("res://scripts/tests/dense_combat_benchmark_smoke.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const BULLET := preload("res://scenes/enemy_bullet.tscn")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const BATCH := preload("res://scripts/enemies/enemy_projectile_batch_simulation.gd")
const ENEMIES := 120
const BULLETS := 240
const FRAMES := 180


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(20260920)
	Engine.max_fps = 0
	var scene := FIXTURE.BenchmarkRuntimeRoot.new()
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scene)
	current_scene = scene
	var player := FIXTURE.TargetStub.new()
	scene.player = player
	scene.add_child(player)
	player.position = Vector2(550.0, 0.0)
	for index in range(ENEMIES):
		var enemy = ENEMY.instantiate()
		enemy.target = player
		scene.add_child(enemy)
		enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", "chaser"))
		enemy.position = Vector2((index % 15) * 26.0 - 250.0, (index / 15) * 26.0 - 100.0)
		enemy.max_health = 1000000.0
		enemy.current_health = enemy.max_health
	for index in range(BULLETS):
		var bullet = BULLET.instantiate()
		scene.add_child(bullet)
		bullet.reset_projectile({"position": Vector2(-500.0 + (index % 30) * 28, -240.0 + (index / 30) * 60), "target": player, "direction": Vector2.RIGHT, "speed": 150.0, "damage": 1.0, "lifetime": 20.0})
	var samples: Array[float] = []
	var hits := 0
	for frame in range(FRAMES + 30):
		await physics_frame
		var started := Time.get_ticks_usec()
		for enemy in scene.get_runtime_enemies():
			enemy.batch_physics_process(1.0 / 60.0)
		BATCH.update_enemy_projectiles(scene, 1.0 / 60.0)
		if frame % 6 == 0:
			for index in range(60):
				RESOLVER.deal_damage_to_enemy(null, scene.get_runtime_enemies()[index], 1.0, "swordsman")
				hits += 1
		if frame >= 30:
			samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	var health := 0.0
	var position_sum := Vector2.ZERO
	for enemy in scene.get_runtime_enemies():
		health += enemy.current_health
		position_sum += enemy.position
	samples.sort()
	var total := 0.0
	for sample in samples:
		total += sample
	var result := {"cpu_tick_ms": {"mean": total / samples.size(), "median": samples[FRAMES / 2], "p95": samples[ceili(FRAMES * 0.95) - 1], "max": samples.back()}, "checks": {"enemies": scene.get_runtime_enemies().size(), "player_hits": hits, "health": health, "position_sum": [position_sum.x, position_sum.y], "enemy_projectile_hits": player.hit_count, "player_damage_taken": player.damage_taken}, "workload": {"frames": FRAMES, "initial_enemies": ENEMIES, "initial_bullets": BULLETS, "aoe_hits_every_six_frames": 60}}
	assert(scene.get_runtime_enemies().size() == ENEMIES)
	assert(hits == 2100 and player.hit_count > 0 and player.damage_taken > 0.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.omx/performance"))
	var label := OS.get_environment("COMBAT_BENCHMARK_LABEL")
	var output := FileAccess.open("res://.omx/performance/frames_%s.json" % label, FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print(JSON.stringify(result))
	scene.free()
	current_scene = null
	print("COMBAT_FRAME_BENCHMARK_OK")
	quit(0)

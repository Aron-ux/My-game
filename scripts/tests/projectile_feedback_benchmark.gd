extends SceneTree

const BULLET := preload("res://scenes/enemy_bullet.tscn")
const FEEDBACK := preload("res://scripts/enemies/enemy_hit_feedback.gd")
const FIXTURE := preload("res://scripts/tests/dense_combat_benchmark_smoke.gd")
const COUNT := 512
const SAMPLES := 90


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := FIXTURE.BenchmarkRuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var target := FIXTURE.TargetStub.new()
	scene.add_child(target)
	var bullets: Array[Node2D] = []
	for index in range(COUNT):
		var bullet = BULLET.instantiate()
		scene.add_child(bullet)
		bullet.reset_projectile({"position": Vector2(-600.0 + (index % 32) * 36.0, 150.0 + (index / 32) * 16.0), "target": target, "direction": Vector2.RIGHT, "speed": 60.0, "lifetime": 120.0, "motion_mode": "straight"})
		bullets.append(bullet)
	var samples: Array[float] = []
	for _index in range(SAMPLES):
		var started := Time.get_ticks_usec()
		for bullet in bullets:
			bullet.batch_physics_process(1.0 / 60.0)
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	var position_sum := Vector2.ZERO
	var alpha_sum := 0.0
	for bullet in bullets:
		position_sum += bullet.position
		alpha_sum += bullet.modulate.a
	samples.sort()
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.add_frame("default", GradientTexture2D.new())
	scene.add_child(sprite)
	var flash_start := Time.get_ticks_usec()
	for _index in range(512):
		FEEDBACK._spawn_boss_hit_flash_overlay_for_sprite(sprite)
	var flash_ms := float(Time.get_ticks_usec() - flash_start) / 1000.0
	var result := {"projectile_tick_median_ms": samples[SAMPLES / 2], "projectile_tick_p95_ms": samples[ceili(SAMPLES * 0.95) - 1], "flash_512_refresh_ms": flash_ms, "pending_tweens_after_512_hits": get_processed_tweens().size(), "checks": {"position": [position_sum.x, position_sum.y], "alpha_sum": alpha_sum, "hits": target.hit_count}, "workload": {"projectiles": COUNT, "samples": SAMPLES}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.omx/performance"))
	var label := OS.get_environment("COMBAT_BENCHMARK_LABEL")
	var output := FileAccess.open("res://.omx/performance/projectile_feedback_%s.json" % label, FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print(JSON.stringify(result))
	scene.free()
	current_scene = null
	print("PROJECTILE_FEEDBACK_BENCHMARK_OK")
	quit(0)

extends SceneTree

const RUNTIME := preload("res://scripts/tests/boss_danmaku_test_runtime.gd")
const STATE := preload("res://scripts/enemies/enemy_boss_state.gd")
const BUDGET := preload("res://scripts/enemies/boss_danmaku_budget.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for pressure in [0.9, 1.65]:
		var scene := RUNTIME.new()
		root.add_child(scene)
		current_scene = scene
		scene.process_mode = Node.PROCESS_MODE_DISABLED
		scene.player = Node2D.new()
		scene.add_child(scene.player)
		var boss = scene.make_boss()
		boss.boss_phase = 3
		boss.current_health = 15000.0
		boss.boss_shield_break_intro_played = true
		boss.boss_attack_pressure_scale = pressure
		var usecs := 0
		var worst_usecs := 0
		var samples: Array[int] = []
		var seen_themes: Dictionary = {}
		var seen_patterns: Dictionary = {}
		# Six complete third-bar cycles exercise every authored performance.
		var frame_count := 16200
		for frame in range(frame_count):
			var start := Time.get_ticks_usec()
			STATE.update_boss_trait(boss, 1.0 / 60.0)
			if boss.boss_routine.stage == "performance":
				seen_themes[boss.boss_routine.theme] = true
				seen_patterns[boss.boss_danmaku_pattern] = true
			for bullet in scene.active.values():
				if not bullet.is_queued_for_deletion():
					bullet.batch_physics_process(1.0 / 60.0)
			var elapsed := Time.get_ticks_usec() - start
			usecs += elapsed
			worst_usecs = maxi(worst_usecs, elapsed)
			samples.append(elapsed)
			assert(scene.active.size() < BUDGET.LIMIT - 128, "authored overlap must leave capacity margin")
			if frame % 120 == 0:
				await process_frame
		samples.sort()
		assert(scene.peak_count > 500, "stress workload must exceed ordinary caps")
		assert(seen_themes.size() == 6, "stress must cover all six performances")
		for pattern in range(12):
			assert(seen_patterns.has(pattern), "third-bar prelude must not skip any authored pattern")
		assert(scene.ordinary_budget_calls == 0, "Boss attack density must not use adaptive caps")
		print("BOSS_DANMAKU_STRESS pressure=%.2f peak=%d avg_ms=%.3f p95_ms=%.3f max_ms=%.3f" % [
			pressure, scene.peak_count, float(usecs) / float(frame_count) / 1000.0,
			float(samples[int(frame_count * 0.95)]) / 1000.0, float(worst_usecs) / 1000.0])
		boss._clear_boss_runtime_effects()
		assert(get_node_count_in_group(BUDGET.GROUP) == 0, "Boss death must free its bullet capacity immediately")
		scene.free()
		current_scene = null
	print("BOSS_DANMAKU_STRESS_SMOKE_OK")
	quit(0)

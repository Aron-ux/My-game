extends SceneTree

const RUNTIME := preload("res://scripts/tests/boss_danmaku_test_runtime.gd")
const ROUTINE := preload("res://scripts/enemies/enemy_boss_routine.gd")
const BATCH := preload("res://scripts/enemies/enemy_projectile_batch_simulation.gd")
const SAMPLE_FRAMES := 240
var results: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var label := "current"
	var case_filter := ""
	var reference_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
		if arg.begins_with("--case="):
			case_filter = arg.trim_prefix("--case=")
		if arg.begins_with("--reference="):
			reference_path = arg.trim_prefix("--reference=")
	var cases := [
		["shield", 1, -1, false],
		["broken_basic", 1, -1, true],
		["second_basic", 2, -1, true],
		["third_basic", 3, -1, true],
		["broken_performance", 1, 0, true],
		["second_spiral", 2, 1, true],
		["second_rift", 2, 3, true]
	]
	for theme in range(6):
		cases.append(["final_theme_%d" % theme, 3, theme, true])
	var paired_cases := []
	for spec in cases:
		if not reference_path.is_empty():
			paired_cases.append(spec + [true])
		paired_cases.append(spec + [false])
	cases = paired_cases
	for spec in cases:
		if case_filter != "" and str(spec[0]) != case_filter:
			continue
		seed(8675309)
		var scene := RUNTIME.new()
		root.add_child(scene)
		current_scene = scene
		scene.process_mode = Node.PROCESS_MODE_DISABLED
		scene.set_meta(&"_profile_boss_projectiles", true)
		scene.set_meta(&"_benchmark_reference", bool(spec[4]))
		var camera := Camera2D.new()
		camera.zoom = Vector2.ONE * 0.72
		scene.add_child(camera)
		scene.player = RUNTIME.Target.new()
		scene.player.position = Vector2(450, 150)
		scene.add_child(scene.player)
		var boss = scene.make_boss()
		if bool(spec[4]):
			boss.projectile_scene = load(reference_path)
		boss.boss_phase = int(spec[1])
		boss.boss_shield_break_intro_played = bool(spec[3])
		boss.current_health = 15000.0 if bool(spec[3]) else 20000.0
		boss.boss_attack_pressure_scale = 1.65
		ROUTINE.reset(boss, maxi(0, int(spec[2])))
		if int(spec[2]) >= 0:
			ROUTINE.advance_stage(boss)
			ROUTINE.advance_stage(boss)
		var preroll := 9.0 if int(spec[2]) == 2 else 6.0
		for frame in range(roundi(preroll * 60)):
			_tick(scene, boss, int(spec[2]) < 0)
		for frame in range(20):
			await process_frame
		var samples: Array[float] = []
		var logic_samples: Array[float] = []
		var draws := 0.0
		var count_sum := 0
		var simulation_usec := 0
		var upload_usec := 0
		var started := Time.get_ticks_usec()
		for frame in range(SAMPLE_FRAMES):
			var logic_start := Time.get_ticks_usec()
			_tick(scene, boss, int(spec[2]) < 0)
			logic_samples.append((Time.get_ticks_usec() - logic_start) / 1000.0)
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append((now - started) / 1000.0)
			started = now
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			count_sum += scene.active.size()
			simulation_usec += int(scene.get_meta(&"_boss_simulation_usec", 0))
			upload_usec += int(scene.get_meta(&"_boss_render_upload_usec", 0))
		samples.sort()
		logic_samples.sort()
		var row := {
			"case": spec[0], "frame_ms": _average(samples), "p95_ms": samples[int(SAMPLE_FRAMES * 0.95)],
			"logic_ms": _average(logic_samples), "logic_p95_ms": logic_samples[int(SAMPLE_FRAMES * 0.95)],
			"draw_calls": draws / SAMPLE_FRAMES, "peak_bullets": scene.peak_count,
			"bullet_samples": count_sum, "damage": scene.player.damage_taken
		}
		row["simulation_ms"] = simulation_usec / float(SAMPLE_FRAMES) / 1000.0
		row["upload_ms"] = upload_usec / float(SAMPLE_FRAMES) / 1000.0
		row["reference"] = bool(spec[4])
		results.append(row)
		print(JSON.stringify(row))
		scene.free()
		current_scene = null
		await process_frame
	DirAccess.make_dir_recursive_absolute("res://.omx/boss-performance")
	var output := FileAccess.open("res://.omx/boss-performance/%s.json" % label, FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "\t"))
	output.close()
	print("BOSS_ALL_PHASE_BENCHMARK_OK")
	quit(0)


func _tick(scene, boss, basic: bool) -> void:
	if basic:
		boss.boss_routine.elapsed = 0.0
	ROUTINE.update(boss, 1.0 / 60.0)
	scene.remove_meta(BATCH.BATCH_FRAME_META_KEY)
	BATCH.update_enemy_projectiles(scene, 1.0 / 60.0, not bool(scene.get_meta(&"_benchmark_reference", false)))


func _average(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()

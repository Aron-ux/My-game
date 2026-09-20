extends SceneTree

const RUNTIME := preload("res://scripts/tests/boss_danmaku_test_runtime.gd")
const ATTACKS := preload("res://scripts/enemies/enemy_boss_attacks.gd")
const STATE := preload("res://scripts/enemies/enemy_boss_state.gd")
const BUDGET := preload("res://scripts/enemies/boss_danmaku_budget.gd")
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var scene := RUNTIME.new()
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var target := RUNTIME.Target.new()
	scene.add_child(target)
	scene.player = target
	var boss = scene.make_boss()
	for phase in [1, 2, 3]:
		boss.boss_phase = phase
		ATTACKS.fire_radial_burst(boss, 16)
		check(scene.active.size() == 16, "radial must fire every bullet")
		for bullet in scene.active.values():
			check(is_equal_approx(bullet.damage, 64.0), "radial damage must be 80% in every phase")
		scene.clear_bullets()
	boss.attack = 160.0
	ATTACKS.fire_radial_burst(boss, 16)
	check(is_equal_approx(scene.active.values()[0].damage, 128.0), "radial uses current attack")
	scene.clear_bullets()
	boss.attack = 80.0
	boss.boss_danmaku_pattern = -1
	var signatures: Array[Vector2] = []
	for pattern in range(3):
		ATTACKS.fire_quarter_sine_ring(boss, 12)
		check(scene.active.size() == 24, "first danmaku wave must be complete")
		ATTACKS.update_danmaku_stream(boss, 0.8)
		check(scene.active.size() == 144, "all six danmaku waves must survive ordinary frame cap")
		check(boss.boss_danmaku_pattern == pattern, "patterns must rotate in order")
		for bullet in scene.active.values():
			check(is_equal_approx(bullet.damage, 64.0), "all danmaku bullets use 80% attack")
			check(bullet.get_node("Polygon2D").color == bullet.visual_color, "danmaku must retain authored color")
		var sample = scene.active.values()[1]
		sample.travel_time = 1.2
		sample._update_danmaku_motion()
		signatures.append(sample.global_position)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(sample.get_save_data()))
		var restored = RUNTIME.BULLET.instantiate()
		scene.add_child(restored)
		restored.apply_save_data(saved, target)
		sample._run_physics_tick(0.1)
		restored._run_physics_tick(0.1)
		check(sample.global_position.distance_to(restored.global_position) < 0.001, "saved danmaku must resume same curve")
		check(restored.is_in_group(BUDGET.GROUP), "restored Boss bullets retain separate budget")
		restored.reset_projectile({"position": Vector2(200, 0), "motion_mode": "straight", "target": target})
		check(restored.danmaku_sway == 0.0 and restored.danmaku_angular_speed == 0.0, "pooled ordinary bullets clear curve fields")
		check(not restored.is_in_group(BUDGET.GROUP), "ordinary bullets leave Boss budget")
		scene.clear_bullets()
	check(signatures[0].distance_to(signatures[1]) > 10.0 and signatures[1].distance_to(signatures[2]) > 10.0, "three patterns need distinct paths")

	ATTACKS.fire_quarter_sine_ring(boss, 12)
	ATTACKS.update_danmaku_stream(boss, 0.23)
	var saved_boss: Dictionary = JSON.parse_string(JSON.stringify(boss.get_save_data()))
	var restored_boss = scene.make_boss()
	restored_boss.apply_save_data(saved_boss, target)
	check(restored_boss.boss_danmaku_wave == 2, "save retains pending waves")
	scene.clear_bullets()
	ATTACKS.update_danmaku_stream(restored_boss, 0.6)
	check(scene.active.size() == 96, "restore fires remaining four waves exactly once")
	STATE._prepare_transition_state(restored_boss)
	scene.clear_bullets()
	ATTACKS.update_danmaku_stream(restored_boss, 1.0)
	check(scene.active.is_empty(), "transition cancels pending waves")
	restored_boss.free()

	boss.boss_phase = 2
	ATTACKS.fire_recall_split(boss)
	var parent = scene.active.values()[0]
	check(is_equal_approx(parent.damage, 19.24), "unspecified split parent damage stays unchanged")
	var split_save: Dictionary = JSON.parse_string(JSON.stringify(parent.get_save_data()))
	parent.apply_save_data(split_save, target)
	var before: int = scene.active.size()
	parent._spawn_split_bullets()
	check(scene.active.size() == before + 6, "all six split children spawn")
	for bullet in scene.active.values().slice(before):
		check(is_equal_approx(bullet.damage, 40.0), "split child uses 50% attack after save")
		check(bullet.split_damage_override == -1.0, "child must not inherit another split override")
	scene.clear_bullets()

	target.position = Vector2(500, 0)
	boss.boss_orbit_bomb_shot_timer = 0.0
	boss._ensure_boss_orbit_ball()
	ATTACKS._update_orbit_aimed_burst(boss, 0.0)
	check(scene.active.size() == 3, "aimed burst starts with three bullets")
	var first = scene.active.values()[1]
	check(first.direction.is_equal_approx(Vector2.RIGHT), "central aimed bullet snapshots target")
	target.position = Vector2(0, 500)
	first._run_physics_tick(0.09)
	check(first.direction.is_equal_approx(Vector2.RIGHT), "launched aimed bullet must not home")
	ATTACKS._update_orbit_aimed_burst(boss, 0.09)
	check(scene.active.values()[4].direction.is_equal_approx(Vector2.DOWN), "next volley reacquires target")
	saved_boss = JSON.parse_string(JSON.stringify(boss.get_save_data()))
	boss.apply_save_data(saved_boss, target)
	boss._ensure_boss_orbit_ball()
	ATTACKS._update_orbit_aimed_burst(boss, 0.45)
	check(scene.active.size() == 21, "aimed salvo resumes all seven volleys after save")
	for bullet in scene.active.values():
		check(bullet.motion_mode == "straight" and is_equal_approx(bullet.damage, 14.208), "aimed salvo retains unspecified damage")
	scene.clear_bullets()

	for fps in [30, 60, 120]:
		target.position = Vector2(200, 0)
		target.damage_taken = 0.0
		boss.boss_laser_duration = 2.0
		ATTACKS.start_laser_sweep(boss)
		boss.boss_laser_spin_duration = 0.0
		boss.boss_laser_final_rotation = 0.0
		for frame in range(fps * 2):
			ATTACKS.update_lasers(boss, 1.0 / float(fps))
		check(absf(target.damage_taken - 160.0) < 0.01, "laser must deal 80 DPS at %d Hz" % fps)
	# Center overlaps multiple rays, but one second still deals only 80.
	target.position = Vector2.ZERO
	target.damage_taken = 0.0
	boss.boss_laser_duration = 1.0
	ATTACKS.start_laser_sweep(boss)
	ATTACKS.update_lasers(boss, 2.0)
	check(is_equal_approx(target.damage_taken, 80.0), "overlap and oversized delta cannot multiply laser damage")
	target.position = Vector2(200, 0)
	target.damage_taken = 0.0
	boss.boss_laser_duration = 2.0
	ATTACKS.start_laser_sweep(boss)
	boss.boss_laser_final_rotation = 0.0
	ATTACKS.update_lasers(boss, 0.07)
	saved_boss = JSON.parse_string(JSON.stringify(boss.get_save_data()))
	boss.apply_save_data(saved_boss, target)
	target.position = Vector2(200, 100) # Outside every ray.
	ATTACKS.update_lasers(boss, 0.1)
	check(is_equal_approx(target.damage_taken, 5.6), "saved fractional laser contact settles on exit")
	ATTACKS.update_lasers(boss, 0.1)
	check(is_equal_approx(target.damage_taken, 5.6), "leaving laser cannot repeat fractional damage")
	target.position = Vector2(200, 0)
	ATTACKS.update_lasers(boss, 0.2)
	check(is_equal_approx(target.damage_taken, 21.6), "reentry resumes correct laser DPS")

	# Distant batching must not subtract lifetime twice or lose motion on approach.
	target.position = Vector2.ZERO
	var remote = RUNTIME.BULLET.instantiate()
	scene.add_child(remote)
	remote.reset_projectile({"position": Vector2(1000, 0), "direction": Vector2.LEFT, "speed": 100.0, "lifetime": 4.0, "target": target})
	for frame in range(60):
		remote._run_physics_tick(1.0 / 60.0)
	check(absf(remote.lifetime - 3.0) < 0.001, "remote lifetime follows wall time")
	check(remote.global_position.distance_to(Vector2(900, 0)) < 0.001, "remote batching preserves motion")
	scene.clear_bullets()
	check(scene.ordinary_budget_calls == 0, "Boss parent and child projectiles bypass ordinary adaptive cap")
	# A full Boss pattern must not starve ordinary enemies of their allowance.
	for volley in range(12):
		ATTACKS.fire_radial_burst(boss, 20)
	check(scene.active.size() == 240, "Boss workload exceeds ordinary total limit")
	# Ordinary enemies continue to use the real 28-per-frame limiter.
	boss.archetype_id = "shooter"
	var ordinary_count := 0
	for index in range(40):
		if boss._spawn_projectile(Vector2.ZERO, Vector2.RIGHT, 10.0, 1.0, 1.0, Color.WHITE, "straight") != null:
			ordinary_count += 1
	check(ordinary_count == 28, "ordinary enemy frame limit must remain 28")
	scene.clear_bullets()
	boss.archetype_id = "boss_spellcore"
	var reservations: Array[Node] = []
	for index in range(BUDGET.LIMIT):
		var slot := Node.new()
		scene.add_child(slot)
		slot.add_to_group(BUDGET.GROUP)
		reservations.append(slot)
	check(boss._spawn_projectile(Vector2.ZERO, Vector2.RIGHT, 10.0, 1.0, 1.0, Color.WHITE, "straight") == null, "Boss safety ceiling must remain bounded")
	reservations.pop_back().free()
	check(boss._spawn_projectile(Vector2.ZERO, Vector2.RIGHT, 10.0, 1.0, 1.0, Color.WHITE, "straight") != null, "released Boss capacity is immediately reusable")
	for slot in reservations:
		slot.free()
	boss.boss_danmaku_wave = 0
	boss.boss_aimed_shots_remaining = 7
	boss._clear_boss_runtime_effects()
	check(boss.boss_danmaku_wave == 6 and boss.boss_aimed_shots_remaining == 0, "death cancels pending shots")
	scene.free()
	current_scene = null
	if failures.is_empty():
		print("BOSS_DANMAKU_REWORK_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

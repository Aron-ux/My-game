extends SceneTree

const RUNTIME := preload("res://scripts/tests/boss_danmaku_test_runtime.gd")
const ROUTINE := preload("res://scripts/enemies/enemy_boss_routine.gd")
const ATTACKS := preload("res://scripts/enemies/enemy_boss_attacks.gd")
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func step(scene, boss, delta: float) -> void:
	ROUTINE.update(boss, delta)
	for bullet in scene.active.values():
		bullet.batch_physics_process(delta)


func _run() -> void:
	var scene := RUNTIME.new()
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.player = Node2D.new()
	scene.player.position = Vector2(600, 300)
	scene.add_child(scene.player)
	var boss = scene.make_boss()
	for phase in [1, 2, 3]:
		boss.boss_phase = phase
		boss.boss_shield_break_intro_played = true
		boss.current_health = 15000.0
		var expected: Array = [[0], [0, 1, 3], [0, 1, 2, 3, 4, 5]][phase - 1]
		for requested_theme in range(6):
			ROUTINE.reset(boss, requested_theme)
			ROUTINE.advance_stage(boss)
			check(int(boss.boss_routine.theme) in expected, "preview cannot announce a theme beyond this health bar")
		ROUTINE.reset(boss)
		var visited: Array = []
		for cycle in range(expected.size()):
			ROUTINE.advance_stage(boss)
			visited.append(int(boss.boss_routine.theme))
			ROUTINE.advance_stage(boss)
			ROUTINE.advance_stage(boss)
			ROUTINE.advance_stage(boss)
			ROUTINE.advance_stage(boss)
		check(visited == expected, "every unlocked theme must rotate without skipping or early unlocks")

	# Force several legitimate casts to overlap the emission boundary.
	# The tail must complete every wave, aimed volley and laser, including
	# children that are born several seconds after the parent was fired.
	boss.boss_phase = 2
	ROUTINE.reset(boss, 1)
	boss.boss_routine.stage = "performance"
	boss.boss_routine.elapsed = 14.99
	ATTACKS.fire_quarter_sine_ring(boss, 12, 7)
	ATTACKS.fire_recall_split(boss)
	ATTACKS.start_laser_sweep(boss)
	boss._ensure_boss_orbit_ball()
	boss.boss_aimed_shots_remaining = 2
	boss.boss_aimed_shot_timer = 0.12
	boss.boss_orbit_bomb_shot_timer = 0.0
	ROUTINE.advance_stage(boss)
	var issued := scene.active.size()
	for frame in range(66):
		step(scene, boss, 1.0 / 60.0)
	check(boss.boss_routine.stage == "finishing", "remaining laser and split parents keep the performance active")
	check(scene.active.size() - issued == 5 * 24 + 2 * 3, "tail fires exactly five remaining waves and two aimed volleys, with no new casts")
	check(boss.boss_danmaku_wave == 6 and boss.boss_aimed_shots_remaining == 0, "pending emissions complete")
	check(boss.boss_laser_remaining > 3.8, "laser is allowed to finish its full duration")
	var data: Dictionary = JSON.parse_string(JSON.stringify(boss.get_save_data()))
	boss.apply_save_data(data, scene.player)
	var saw_children := false
	var elapsed := 1.1
	while boss.boss_routine.stage == "finishing" and elapsed < 20.0:
		var previous_angle: float = boss.boss_orbit_bomb_angle
		var previous_position: Vector2 = boss.boss_orbit_ball.position
		step(scene, boss, 1.0 / 60.0)
		elapsed += 1.0 / 60.0
		if boss.boss_routine.stage == "finishing":
			var expected_angle := wrapf(previous_angle + ATTACKS.ORBIT_ROTATION_SPEED / 60.0, 0.0, TAU)
			check(is_equal_approx(boss.boss_orbit_bomb_angle, expected_angle) and boss.boss_orbit_ball.position != previous_position, "existing orbit keeps moving at its original speed after pending volleys end and after loading")
			check(boss.boss_aimed_shots_remaining == 0 and boss.boss_orbit_bomb_shot_timer == 0.0, "orbit animation cannot start another aimed burst")
		for bullet in scene.active.values():
			check(bullet.clear_fade_remaining == 0.0, "tail cannot force a clear fade")
			if is_equal_approx(bullet.damage, 40.0):
				saw_children = true
				check(boss.boss_routine.stage == "finishing", "split children retain their own lifetime before recovery")
	check(saw_children and elapsed > 10.0, "delayed split children are emitted and run to completion")
	check(boss.boss_routine.stage == "recovery" and scene.active.is_empty(), "recovery starts only after the last active attack ends")
	check(float(boss.boss_routine.elapsed) < 0.02, "tail does not consume the nine-second paralysis")
	check(not is_instance_valid(boss.boss_orbit_ball), "orbit is cleared when paralysis begins")

	# A performance without an orbit must not gain one during its tail.
	ROUTINE.reset(boss, 1)
	boss.boss_routine.stage = "finishing"
	ATTACKS.fire_radial_burst(boss, 12)
	step(scene, boss, 0.1)
	check(boss.boss_routine.stage == "finishing" and not is_instance_valid(boss.boss_orbit_ball), "tail only continues an existing orbit")

	scene.free()
	current_scene = null
	if failures.is_empty():
		print("BOSS_DANMAKU_COMPLETION_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

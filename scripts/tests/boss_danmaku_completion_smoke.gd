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

func performance_projectile_count(scene) -> int:
	var count := 0
	for bullet in scene.active.values():
		if not bool(bullet.get_meta(&"boss_finishing_shot", false)):
			count += 1
	return count


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
	check(performance_projectile_count(scene) - issued == 5 * 24 + 2 * 3, "tail completes exactly five remaining waves and two aimed volleys")
	check(scene.active.size() > performance_projectile_count(scene), "tail also fires normal cannonballs")
	check(boss.boss_danmaku_wave == 6 and boss.boss_aimed_shots_remaining == 0, "pending emissions complete")
	check(boss.boss_laser_remaining > 3.8, "laser is allowed to finish its full duration")
	var data: Dictionary = JSON.parse_string(JSON.stringify(boss.get_save_data()))
	var shots: Array = []
	for bullet in scene.active.values():
		shots.append(JSON.parse_string(JSON.stringify(bullet.get_save_data())))
	var performance_count_before_load := performance_projectile_count(scene)
	scene.clear_bullets()
	boss.apply_save_data(data, scene.player)
	for shot in shots:
		var bullet = RUNTIME.BULLET.instantiate()
		scene.add_child(bullet)
		bullet.apply_save_data(shot, scene.player)
	check(performance_projectile_count(scene) == performance_count_before_load, "JSON roundtrip preserves which bullets the tail waits for")
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
	check(boss.boss_routine.stage == "recovery" and performance_projectile_count(scene) == 0, "paralysis starts after the last performance attack, even while basic shots remain")
	check(not scene.active.is_empty(), "new basic shots are not abruptly erased when paralysis begins")
	for bullet in scene.active.values():
		check(bool(bullet.get_meta(&"boss_finishing_shot", false)) and bullet.clear_fade_remaining == 0.0, "remaining basic shots keep flying naturally")
	check(float(boss.boss_routine.elapsed) < 0.02, "tail does not consume the nine-second paralysis")
	check(not is_instance_valid(boss.boss_orbit_ball), "orbit is cleared when paralysis begins")

	# All health bars use their existing basic bullet count, damage and
	# speed while waiting, without an extra volley when nothing is left.
	for phase in [1, 2, 3]:
		scene.clear_bullets()
		boss.boss_phase = phase
		boss.boss_attack_pressure_scale = 1.0
		ROUTINE.reset(boss)
		boss.boss_routine.stage = "performance"
		ATTACKS.fire_radial_burst(boss, 12)
		for bullet in scene.active.values():
			bullet.speed = 0.0
			bullet.lifetime = 0.6
		ROUTINE.advance_stage(boss)
		step(scene, boss, 0.01)
		check(scene.active.size() - performance_projectile_count(scene) == [16, 18, 20][phase - 1], "tail uses the current health bar's normal ring count")
		for bullet in scene.active.values():
			if bool(bullet.get_meta(&"boss_finishing_shot", false)):
				check(is_equal_approx(bullet.damage, 64.0) and bullet.motion_mode == "straight", "tail cannonballs keep normal attack damage and trajectory")
				check(is_equal_approx(bullet.speed, (255.0 + (phase - 1) * 12.0) * ATTACKS.BOSS_PROJECTILE_SPEED_SCALE), "tail cannonballs keep normal speed")
		var fired: int = scene.registered_count
		for frame in range(15):
			step(scene, boss, 0.05)
		check(boss.boss_routine.stage == "recovery" and scene.registered_count == fired, "basic shots cannot keep the tail alive or fire after paralysis")
		var normal = scene.active.values()[0]
		var normal_save: Dictionary = JSON.parse_string(JSON.stringify(normal.get_save_data()))
		normal.recycle()
		check(not normal.has_meta(&"boss_finishing_shot"), "recycling clears the tail classification")
		normal.reset_projectile({"position": Vector2(800, 0), "target": scene.player, "speed": 0.0, "lifetime": 5.0, "source_enemy_kind": "boss"})
		check(not normal.has_meta(&"boss_finishing_shot"), "pooled normal or performance reuse cannot inherit the classification")
		normal.apply_save_data(normal_save, scene.player)
		check(bool(normal.get_meta(&"boss_finishing_shot", false)), "saved tail shots restore their classification")
		normal_save.erase("boss_finishing_shot")
		normal.apply_save_data(normal_save, scene.player)
		check(not normal.has_meta(&"boss_finishing_shot"), "legacy saves default to the original completion rules")

	# A performance without an orbit must not gain one during its tail.
	scene.clear_bullets()
	ROUTINE.reset(boss, 1)
	boss.boss_routine.stage = "finishing"
	ATTACKS.fire_radial_burst(boss, 12)
	step(scene, boss, 0.1)
	check(boss.boss_routine.stage == "finishing" and not is_instance_valid(boss.boss_orbit_ball), "tail only continues an existing orbit")
	boss._clear_boss_runtime_effects()
	check(scene.active.is_empty(), "Boss death also clears the new tail cannonballs")

	scene.free()
	current_scene = null
	if failures.is_empty():
		print("BOSS_DANMAKU_COMPLETION_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

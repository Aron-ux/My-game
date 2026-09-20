extends SceneTree

const RUNTIME := preload("res://scripts/tests/boss_danmaku_test_runtime.gd")
const ATTACKS := preload("res://scripts/enemies/enemy_boss_attacks.gd")
const ROUTINE := preload("res://scripts/enemies/enemy_boss_routine.gd")
const STATE := preload("res://scripts/enemies/enemy_boss_state.gd")
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
	scene.player = Node2D.new()
	scene.player.position = Vector2(500, 150)
	scene.add_child(scene.player)
	var boss = scene.make_boss()
	boss.boss_phase = 2
	boss.boss_shield_break_intro_played = true
	boss.current_health = 15000.0
	var signatures: Array[Vector2] = []
	for pattern in range(ATTACKS.DANMAKU.PATTERN_COUNT):
		scene.clear_bullets()
		scene.player.position = Vector2(500, 150)
		ATTACKS.fire_quarter_sine_ring(boss, 18, pattern)
		ATTACKS.update_danmaku_stream(boss, 1.0)
		check(scene.active.size() == 216, "every pattern must emit all six complete waves")
		var signature := Vector2.ZERO
		var bullets: Array = scene.active.values()
		for index in range(bullets.size()):
			var bullet = bullets[index]
			check(is_equal_approx(bullet.damage, 64.0), "new pattern damage remains 80% attack")
			check(is_equal_approx(bullet.lifetime, 10.0), "new pattern lifetime remains 10s")
			bullet.batch_physics_process(2.7)
			check(bullet.position.is_finite() and is_finite(bullet.rotation), "new curves stay finite through hold / drift")
			signature += bullet.position * float((index % 7) + 1)
		signatures.append(signature)

		# JSON snapshots preserve all three trajectory families at arbitrary
		# points, including inside a stationary bloom and during its release.
		for sample_time in [0.8, 2.7, 3.25, 5.0]:
			var sample = bullets[7]
			sample.travel_time = sample_time
			var data: Dictionary = JSON.parse_string(JSON.stringify(sample.get_save_data()))
			var restored = RUNTIME.BULLET.instantiate()
			scene.add_child(restored)
			restored.apply_save_data(data, scene.player)
			sample.batch_physics_process(0.17)
			restored.batch_physics_process(0.17)
			check(sample.position.distance_to(restored.position) < 0.001, "all pattern paths must survive JSON load")
			check(is_equal_approx(sample.rotation, restored.rotation), "loaded crystals must face the same direction")
			restored.free()

		# Resuming a six-wave cast must keep its new (>2) pattern and locked aim.
		scene.clear_bullets()
		ATTACKS.fire_quarter_sine_ring(boss, 18, pattern, -1.0)
		ATTACKS.update_danmaku_stream(boss, 0.21)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(boss.get_save_data()))
		var loaded = scene.make_boss()
		ROUTINE.reset(boss)
		loaded.apply_save_data(saved, scene.player)
		check(loaded.boss_danmaku_pattern == pattern, "save must not clamp new pattern IDs to old three-pattern range")
		var rotation_before: float = loaded.boss_danmaku_rotation
		scene.player.position = -scene.player.position
		scene.clear_bullets()
		ATTACKS.update_danmaku_stream(loaded, 0.8)
		check(scene.active.size() == 144, "restored cast emits remaining four waves exactly once")
		check(is_equal_approx(loaded.boss_danmaku_rotation, rotation_before), "fan snapshots cannot chase after restore")
		loaded.free()
	for first in range(signatures.size()):
		for second in range(first + 1, signatures.size()):
			check(signatures[first].distance_to(signatures[second]) > 1.0, "patterns must change geometry, not only color")
	scene.clear_bullets()

	ATTACKS.fire_quarter_sine_ring(boss, 12, 7)
	var flower = scene.active.values()[0]
	flower.travel_time = 2.45
	flower._update_danmaku_bloom_motion()
	var hold_position: Vector2 = flower.position
	flower.travel_time = 2.95
	flower._update_danmaku_bloom_motion()
	check(flower.position.distance_to(hold_position) < 0.001, "flower holds still while changing direction")
	flower.travel_time = 3.05001
	flower._update_danmaku_bloom_motion()
	check(flower.position.distance_to(hold_position) < 0.001, "flower release cannot teleport")
	flower.travel_time = 4.0
	flower._update_danmaku_bloom_motion()
	check(flower.position.distance_to(hold_position) > 60.0, "held flower visibly reaccelerates")
	var original_speed: float = flower.speed
	var original_release_speed: float = flower.danmaku_release_speed
	flower.reset_projectile({"position": Vector2.ZERO, "direction": Vector2.RIGHT, "speed": 100.0, "lifetime": 5.0, "motion_mode": "straight"})
	check(flower.danmaku_brake_time == 0.0 and flower.danmaku_hold_time == 0.0 and flower.danmaku_release_angle == 0.0 and flower.danmaku_release_speed == 0.0, "ordinary pool reuse must clear every bloom field")
	flower.batch_physics_process(0.1)
	check(flower.position.distance_to(Vector2(10, 0)) < 0.001, "ordinary pooled bullets keep straight movement")
	scene.clear_bullets()
	scene.difficulty_speed_bonus = 30.0
	ATTACKS.fire_quarter_sine_ring(boss, 12, 7)
	var faster = scene.active.values()[0]
	check(is_equal_approx(faster.speed, original_speed + 30.0), "difficulty scales the approach speed")
	check(is_equal_approx(faster.danmaku_release_speed, original_release_speed + 30.0), "difficulty also scales speed after the hold")
	scene.difficulty_speed_bonus = 0.0
	scene.clear_bullets()

	boss.boss_phase = 3
	for theme in range(ROUTINE.THEMES.size()):
		ROUTINE.stop_attacks(boss)
		ROUTINE.reset(boss, theme)
		ROUTINE.advance_stage(boss)
		ROUTINE.advance_stage(boss)
		var seen: Dictionary = {}
		for frame in range(1080):
			STATE.update_boss_trait(boss, 1.0 / 60.0)
			seen[boss.boss_danmaku_pattern] = true
			for bullet in scene.active.values():
				if not bullet.is_queued_for_deletion():
					bullet.batch_physics_process(1.0 / 60.0)
			if frame == 450:
				var saved: Dictionary = JSON.parse_string(JSON.stringify(boss.get_save_data()))
				var loaded = scene.make_boss()
				loaded.apply_save_data(saved, scene.player)
				check(loaded.boss_routine.theme == theme, "new themes survive save/load")
				check(loaded.get_boss_ui_payload().status.label.contains(ROUTINE.THEMES[theme]), "HUD names the actual restored theme")
				loaded.free()
		for expected in ROUTINE.THEME_PATTERNS[theme]:
			check(seen.has(expected), "every performance must actually execute its three distinct sections")
		check(boss.boss_routine.stage == "finishing", "all six final-bar performances emit for 18s then finish naturally")
		scene.clear_bullets()
		ROUTINE.stop_attacks(boss)
		ROUTINE.advance_stage(boss)
		ROUTINE.advance_stage(boss)
		check(boss.boss_routine.theme == (theme + 1) % ROUTINE.THEMES.size(), "theme rotation must include all six themes")
		scene.clear_bullets()

	for phase in [2, 3]:
		STATE.start_phase_transition(boss, phase)
		STATE.update_boss_trait(boss, 5.0)
		check(boss.boss_routine.theme == (1 if phase == 2 else 5), "later health bars open with distinct dark-stone performances")
	scene.free()
	current_scene = null
	if failures.is_empty():
		print("BOSS_MAGIC_STONE_PATTERNS_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

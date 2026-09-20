extends SceneTree

const RUNTIME := preload("res://scripts/tests/boss_danmaku_test_runtime.gd")
const STATE := preload("res://scripts/enemies/enemy_boss_state.gd")
const ROUTINE := preload("res://scripts/enemies/enemy_boss_routine.gd")
const DAMAGE := preload("res://scripts/enemies/enemy_damage.gd")
const MOTION := preload("res://scripts/enemies/enemy_movement.gd")
const BUDGET := preload("res://scripts/enemies/boss_danmaku_budget.gd")
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func advance(scene, boss, duration: float, step: float = 1.0 / 60.0) -> void:
	var remaining := duration
	while remaining > 0.000001:
		var delta := minf(step, remaining)
		STATE.update_boss_trait(boss, delta)
		for bullet in scene.active.values():
			if not bullet.is_queued_for_deletion():
				bullet.batch_physics_process(delta)
		remaining -= delta


func start_performance(scene, boss, theme: int) -> void:
	ROUTINE.stop_attacks(boss)
	ROUTINE.reset(boss, theme)
	ROUTINE.advance_stage(boss)
	advance(scene, boss, 1.5)
	check(boss.boss_routine.stage == "performance", "preview lasts 1.5 seconds")


func _run() -> void:
	var scene := RUNTIME.new()
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var target := RUNTIME.Target.new()
	target.position = Vector2(500, 200)
	scene.add_child(target)
	scene.player = target
	var boss = scene.make_boss()
	boss.boss_attack_pressure_scale = 0.9
	boss.boss_sine_cooldown = 0.0
	boss.boss_split_timer = 0.0
	boss.boss_laser_timer = 0.0
	boss.boss_peacock_timer = 0.0
	advance(scene, boss, 11.9)
	check(boss.boss_routine.stage == "basic", "first bar has a full 12s basic segment")
	check(not scene.active.is_empty(), "basic segment fires radial attacks")
	for bullet in scene.active.values():
		check(bullet.motion_mode == "straight" and bullet.visual_style == "boss_danmaku_violet_orb", "shielded basic cannot leak advanced skills")
	check(boss.boss_laser_remaining == 0.0, "independent laser cooldown must not bypass routine")
	var ordinary = RUNTIME.BULLET.instantiate()
	scene.add_child(ordinary)
	ordinary.reset_projectile({"position": Vector2(800, 0), "target": target, "speed": 0.0, "lifetime": 100.0, "source_enemy_kind": "normal", "source_enemy_instance_id": 123})
	advance(scene, boss, 24.1)
	check(boss.boss_routine.stage == "basic" and ROUTINE.get_available_themes(boss).is_empty(), "shield intact stays in basic combat indefinitely")
	STATE.start_shield_break_intro(boss)
	advance(scene, boss, 5.0)
	advance(scene, boss, 12.0)
	check(boss.boss_routine.stage == "preview", "basic transitions to preview at 12s")
	check(boss.get_boss_ui_payload().status.label.contains("污染迸发"), "preview announces its theme through real HUD payload")
	check(MOTION.compute_boss_velocity(boss, Vector2.RIGHT, 500.0, 0.02) == Vector2.ZERO, "Boss holds position during preview")
	var neighbor = RUNTIME.ENEMY.instantiate()
	scene.add_child(neighbor)
	neighbor.position = boss.position + Vector2.ONE
	var locked_position: Vector2 = boss.position
	boss._physics_process(0.01)
	check(boss.position == locked_position, "crowd separation cannot move the telegraph origin")
	neighbor.free()
	boss.boss_routine.elapsed = 0.0
	check(ordinary.clear_fade_remaining == 0.0 and not ordinary.pooled, "clearing Boss bullets preserves ordinary enemy attacks")
	var held_state: Dictionary = boss.boss_routine.duplicate(true)
	STATE.update_boss_trait(boss, 0.0)
	check(boss.boss_routine == held_state, "zero elapsed time cannot advance the routine")
	advance(scene, boss, 1.5)
	check(boss.boss_routine.stage == "performance", "preview enters performance")
	for bullet in scene.active.values():
		check(bullet == ordinary, "preview clears all old Boss bullets before the new performance")
	advance(scene, boss, 5.6)
	check(boss.boss_danmaku_pattern == 0 and boss.boss_danmaku_spin < 0.0, "bloom reverses rotation in its middle section")
	check(boss.boss_laser_remaining == 0.0, "bloom cannot independently start lasers")
	var health: float = boss.current_health
	DAMAGE.apply_damage(boss, 10.0, false)
	check(boss.current_health < health, "performance must allow normal player damage")
	advance(scene, boss, 9.4)
	check(boss.boss_routine.stage == "finishing", "15s ends emission, not the live performance")
	check(ROUTINE.get_armor_modifier(boss) == 0.0, "tail is not yet the armor vulnerability window")
	var tail_bullets := 0
	for bullet in scene.active.values():
		if bullet != ordinary:
			tail_bullets += 1
			check(bullet.clear_fade_remaining == 0.0, "last bullets are not forcibly faded")
	check(tail_bullets > 0, "last wave remains on screen at the boundary")
	var tail_save: Dictionary = JSON.parse_string(JSON.stringify(boss.get_save_data()))
	boss.apply_save_data(tail_save, target)
	check(boss.boss_routine.stage == "finishing", "load preserves natural tail")
	var tail_time := 0.0
	while boss.boss_routine.stage == "finishing" and tail_time < 25.0:
		advance(scene, boss, 0.05)
		tail_time += 0.05
	check(boss.boss_routine.stage == "recovery" and tail_time > 1.0, "recovery waits for live bullets to finish")
	for bullet in scene.active.values():
		check(bullet == ordinary, "all Boss bullets end naturally before recovery")
	boss.boss_routine.elapsed = 0.0
	health = boss.current_health
	DAMAGE.apply_damage(boss, 100.0, false)
	var expected_damage := preload("res://scripts/combat/armor_rules.gd").apply_damage(100.0, -40.0) * 0.9
	check(absf(health - boss.current_health - expected_damage) < 0.01, "recovery damage uses base armor 10 minus 50 before 10% reduction")
	check(boss.armor == 10.0, "temporary penalty never mutates base armor")
	var recovery_save: Dictionary = JSON.parse_string(JSON.stringify(boss.get_save_data()))
	boss.apply_save_data(recovery_save, target)
	check(ROUTINE.get_armor_modifier(boss) == -50.0 and boss.armor == 10.0, "load restores recovery penalty exactly once")
	advance(scene, boss, 3.99)
	check(boss.boss_routine.stage == "recovery", "recovery supplies full four-second output window")
	advance(scene, boss, 0.01)
	check(boss.boss_routine.stage == "basic" and boss.boss_routine.theme == 0, "first broken-shield bar only rotates the simple theme")
	check(ROUTINE.get_armor_modifier(boss) == 0.0, "armor recovers at the exact end of recovery")
	scene.clear_bullets()

	# Fade remains harmless through JSON save/load, even for split parents.
	var fading = RUNTIME.BULLET.instantiate()
	scene.add_child(fading)
	fading.reset_projectile({"position": target.position, "target": target, "damage": 100.0, "lifetime": 0.01, "split_on_return": true, "split_count": 8, "motion_mode": "returning_sine"})
	fading.begin_clear_fade(0.45)
	fading.batch_physics_process(0.15)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(fading.get_save_data()))
	var restored_bullet = RUNTIME.BULLET.instantiate()
	scene.add_child(restored_bullet)
	restored_bullet.apply_save_data(snapshot, target)
	var damage_before: float = target.damage_taken
	fading.batch_physics_process(0.5)
	restored_bullet.batch_physics_process(0.5)
	check(target.damage_taken == damage_before and scene.active.is_empty(), "fading bullets never hit or split after restore")
	restored_bullet.reset_projectile({"position": target.position, "target": target, "damage": 2.0, "lifetime": 1.0, "motion_mode": "straight", "speed": 0.0, "split_count": 0, "split_on_return": false})
	restored_bullet.batch_physics_process(0.01)
	check(is_equal_approx(target.damage_taken - damage_before, 2.0), "reused faded bullet restores normal collision")
	scene.clear_bullets()

	boss.boss_phase = 2
	boss.boss_shield_break_intro_played = true
	boss.current_health = 15000.0
	start_performance(scene, boss, 1)
	advance(scene, boss, 11.0)
	var children := 0
	for bullet in scene.active.values():
		if is_equal_approx(bullet.damage, 40.0):
			children += 1
	check(children > 0, "spiral performance produces its scheduled split children")
	check(boss.boss_laser_remaining == 0.0 and boss.boss_aimed_shots_remaining == 0, "spiral excludes unrelated attacks")
	scene.clear_bullets()

	boss.boss_phase = 3
	start_performance(scene, boss, 2)
	advance(scene, boss, 7.2)
	check(ROUTINE.is_laser_warning(boss) and boss.boss_laser_remaining == 0.0, "overload gives harmless laser warning first")
	check(absf(float(boss.get_boss_ui_payload().status.remaining) - 1.0) < 0.001, "laser warning HUD counts down to firing, not end of performance")
	var locked_angle: float = boss.boss_routine.laser_aim
	snapshot = JSON.parse_string(JSON.stringify(boss.get_save_data()))
	var restored = scene.make_boss()
	restored.apply_save_data(snapshot, target)
	check(restored.boss_laser_lines[0].visible and restored.get_boss_ui_payload().status.label.contains("预警"), "load restores warning visuals and UI")
	target.position = Vector2(-500, 200)
	advance(scene, restored, 1.0)
	check(restored.boss_laser_remaining > 4.9, "laser activates only after 1.2s warning")
	check(is_equal_approx(restored.boss_laser_start_rotation, locked_angle), "laser does not retarget after its preview")
	var ray: Line2D = restored.boss_laser_lines[0]
	check(absf(ray.to_global(ray.points[1]).distance_to(ray.to_global(ray.points[0])) - 980.0) < 0.01, "rendered laser length matches world collision length")
	# Damage can interrupt the active performance and clean every hostile cue.
	restored.boss_phase = 2
	restored.current_health = 10.0
	DAMAGE.apply_damage(restored, 100.0, false)
	check(restored.boss_phase_transition_target == 3, "player can end performance by defeating its health bar")
	check(get_node_count_in_group(BUDGET.GROUP) == 0 and restored.boss_laser_remaining == 0.0, "health transition clears active lasers and Boss bullets")
	advance(scene, restored, 5.0)
	check(restored.boss_phase == 3 and restored.boss_routine.stage == "basic", "next health bar starts with basic combat")
	check(ROUTINE.get_duration(restored, "basic") == 8.0 and ROUTINE.get_duration(restored, "performance") == 18.0, "third health bar uses shorter basic and longer performance")
	restored.free()
	scene.clear_bullets()

	# The third-bar pull has its own seven-second section, before laser cues.
	boss.boss_phase = 3
	target.position = Vector2(500, 200)
	start_performance(scene, boss, 2)
	var pull_position: Vector2 = target.position
	advance(scene, boss, 2.0)
	check(target.position != pull_position and scene.active.is_empty(), "overload pull runs separately from damaging volleys")
	advance(scene, boss, 5.0)
	check(boss.boss_orbit_pull_remaining == 0.0 and ROUTINE.is_laser_warning(boss), "pull ends before laser warning")
	snapshot = boss.get_save_data()
	snapshot.erase("boss_routine")
	var legacy = scene.make_boss()
	legacy.apply_save_data(snapshot, target)
	check(legacy.boss_routine.stage == "basic" and legacy.boss_laser_remaining == 0.0 and legacy.boss_orbit_pull_remaining == 0.0, "old save safely starts basic without stale continuous attacks")
	legacy.free()
	scene.clear_bullets()

	# Large delta carries over across a boundary, never into a skipped stage.
	ROUTINE.stop_attacks(boss)
	boss.boss_phase = 1
	ROUTINE.reset(boss)
	boss.boss_routine.elapsed = 11.8
	STATE.update_boss_trait(boss, 0.6)
	check(boss.boss_routine.stage == "preview" and absf(boss.boss_routine.elapsed - 0.4) < 0.001, "large step preserves preview remainder")
	boss._clear_boss_runtime_effects()
	check(boss.boss_routine.is_empty() and get_node_count_in_group(BUDGET.GROUP) == 0, "death clears routine and bullet capacity")
	scene.free()
	current_scene = null
	if failures.is_empty():
		print("BOSS_ROUTINE_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

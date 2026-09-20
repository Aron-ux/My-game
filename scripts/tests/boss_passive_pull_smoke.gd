extends SceneTree

const RUNTIME := preload("res://scripts/tests/boss_danmaku_test_runtime.gd")
const STATE := preload("res://scripts/enemies/enemy_boss_state.gd")
const ROUTINE := preload("res://scripts/enemies/enemy_boss_routine.gd")
const ATTACKS := preload("res://scripts/enemies/enemy_boss_attacks.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := RUNTIME.new()
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.player = MovingTarget.new()
	scene.add_child(scene.player)
	var boss = scene.make_boss()
	scene.player.position = Vector2(500, 0)
	STATE.update_boss_trait(boss, 0.2)
	assert(scene.player.position == Vector2(500, 0), "shielded Boss does not apply the passive")

	boss.boss_shield_break_intro_played = true
	boss.current_health = 15000.0
	boss.boss_phase = 3
	for stage in ["basic", "preview", "performance", "finishing", "recovery"]:
		ROUTINE.stop_attacks(boss)
		scene.clear_bullets()
		ROUTINE.reset(boss, 3)
		boss.boss_routine.stage = stage
		if stage == "finishing":
			ATTACKS.fire_radial_burst(boss, 12)
		scene.player.position = Vector2(500, 0)
		scene.player.velocity = Vector2.ZERO
		STATE.update_boss_trait(boss, 0.2)
		assert(scene.player.position.distance_to(Vector2(490, 0)) < 0.001, "passive pulls at 50 units/s in every broken-shield stage, including paralysis")
		assert(boss.boss_orbit_pull_remaining == 0.0, "passive does not start the active gravity skill")

	for sample in [[Vector2(-100, 0), 14.5], [Vector2(100, 0), 3.5]]:
		scene.player.position = Vector2(500, 0)
		scene.player.velocity = sample[0]
		STATE.update_boss_trait(boss, 0.2)
		assert(absf(scene.player.position.x - (500.0 - sample[1])) < 0.001, "original toward/away movement multipliers are preserved")
	scene.player.position = Vector2(500, 0)
	scene.player.velocity = Vector2.ZERO
	STATE.update_boss_trait(boss, 0.0)
	assert(scene.player.position == Vector2(500, 0) and scene.player.velocity == Vector2.ZERO, "pause cannot apply displacement or a velocity impulse")

	var saved: Dictionary = JSON.parse_string(JSON.stringify(boss.get_save_data()))
	boss.apply_save_data(saved, scene.player)
	STATE.update_boss_trait(boss, 0.2)
	assert(scene.player.position.distance_to(Vector2(490, 0)) < 0.001, "restored paralysis retains the passive exactly once")

	for transition in ["shield", "health"]:
		scene.player.position = Vector2(500, 0)
		scene.player.velocity = Vector2.ZERO
		if transition == "shield":
			STATE.start_shield_break_intro(boss)
		else:
			boss.boss_shield_break_visual_intro_active = false
			STATE.start_phase_transition(boss, 3)
		STATE.update_boss_trait(boss, 0.2)
		assert(scene.player.position == Vector2(500, 0) and scene.player.velocity == Vector2.ZERO, "cinematic transitions still suspend attraction")

	# Compare a real overload tick with the former passive + active order.
	# The themed active pull must not apply the restored passive twice.
	boss.boss_phase_transition_target = 0
	boss.boss_phase_three_intro_remaining = 0.0
	boss.boss_phase = 3
	boss.boss_shield_break_intro_played = true
	boss.current_health = 15000.0
	ROUTINE.reset(boss, 2)
	boss.boss_routine.stage = "performance"
	scene.player.position = Vector2(500, 300)
	scene.player.velocity = Vector2.ZERO
	var reference_target := MovingTarget.new()
	scene.add_child(reference_target)
	reference_target.position = scene.player.position
	var reference = scene.make_boss()
	reference.target = reference_target
	reference.boss_orbit_bomb_angle = boss.boss_orbit_bomb_angle
	ATTACKS.apply_passive_boss_pull(reference, 0.01)
	ATTACKS.start_orbit_bomb(reference)
	ATTACKS.update_orbit_bomb(reference, 0.01, false)
	STATE.update_boss_trait(boss, 0.01)
	assert(scene.player.position.distance_to(reference_target.position) < 0.001, "active overload retains a single passive contribution")
	assert(scene.player.velocity.distance_to(reference_target.velocity) < 0.001, "active and passive velocity effects match their original order")
	scene.free()
	current_scene = null
	print("BOSS_PASSIVE_PULL_SMOKE_OK")
	quit(0)


class MovingTarget:
	extends Node2D
	var velocity := Vector2.ZERO

extends SceneTree

const RULES := preload("res://scripts/combat/status_resistance.gd")
const PLAYER := preload("res://scenes/player.tscn")
const ENEMY := preload("res://scenes/enemy.tscn")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const SAVE := preload("res://scripts/enemies/enemy_save_data.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var player = PLAYER.instantiate()
	scene.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.fire_timer.stop()
	check(is_equal_approx(RULES.combine([0.1, 0.2, 0.3]), 0.496), "multiplicative stacking")
	check(is_equal_approx(player.get_status_resistance("swordsman"), 0.1), "swordsman base 10 percent")
	check(is_zero_approx(player.get_status_resistance("gunner")) and is_zero_approx(player.get_status_resistance("mage")), "gunner and mage zero")
	player.role_special_states["swordsman"]["status_resistance_sources"] = [0.2, 0.3]
	check(is_equal_approx(RULES.duration(player, 10.0), 5.04), "duration multiplies once")
	player.apply_enemy_slow(0.5, 10.0)
	check(is_equal_approx(player.enemy_move_slow_remaining, 5.04), "player slow duration")
	check(is_equal_approx(player.enemy_move_slow_multiplier, 0.5), "slow strength unchanged")
	for pair in [["normal", "chaser"], ["small_boss", "smallboss_rebirth"], ["boss", "boss_spellcore"]]:
		var enemy = ENEMY.instantiate()
		scene.add_child(enemy)
		enemy.apply_enemy_profile(pair[0], DATABASE.get_profile(pair[0], pair[1]))
		enemy.target = player
		enemy.set_physics_process(false)
		var expected: float = 0.0 if pair[0] == "normal" else 0.2
		check(is_equal_approx(RULES.total(enemy), expected), "enemy default " + pair[0])
		enemy.apply_stun(0.5)
		check(is_equal_approx(enemy.stun_remaining, 0.5 * (1.0 - expected)), "stun scaled")
		enemy.apply_slow(0.7, 5.0)
		check(is_equal_approx(enemy.slow_timer, 5.0 * (1.0 - expected)), "enemy slow scaled")
		enemy.status_resistance_sources = [0.5]
		var data: Dictionary = SAVE.get_save_data(enemy)
		SAVE.apply_save_data(enemy, data, player)
		check(is_equal_approx(enemy.stun_remaining, 0.5 * (1.0 - expected)), "load does not rescale remaining duration")
		check(is_equal_approx(RULES.total(enemy), 1.0 - (1.0 - expected) * 0.5), "save preserves independent sources")
		if pair[0] == "boss":
			enemy.stun_remaining = 0.0
			enemy.status_resistance_sources.clear()
			enemy.boss_routine.stage = "performance"
			enemy.apply_stun(0.5)
			enemy.apply_stun(2.0)
			check(is_equal_approx(float(enemy.boss_routine.get("stun_extension", 0.0)), 0.4), "deferred stun scales exactly once")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("STATUS_RESISTANCE_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

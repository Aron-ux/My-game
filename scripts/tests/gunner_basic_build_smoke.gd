extends SceneTree

const BUILD := preload("res://scripts/player/player_gunner_basic_build.gd")
const LEVELS := preload("res://scripts/player/player_skill_level_system.gd")
const TOOLS := preload("res://scripts/developer/developer_build_tools.gd")
const CARDS := preload("res://scripts/player/player_build_system.gd")
const PLAYER := preload("res://scenes/player.tscn")
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
	player.auto_attack_enabled = false
	player.fire_timer.stop()
	player.active_role_index = 1
	check(BUILD.level(player) == 0, "starts LV0")
	check(is_equal_approx(BUILD.damage_ratio(player), 1.5), "base 150 percent")
	check(not CARDS._make_skill_upgrade_option(player, "gunner", 1, "gunner_basic").is_empty(), "LV0 upgrade card")
	for lv in range(1, 10):
		LEVELS.add_skill_level(player, "gunner", "gunner_basic")
		check(BUILD.level(player) == lv, "level %d" % lv)
		if lv in BUILD.STAGES:
			var offer := LEVELS.build_talent_offer_for(player, "gunner", "gunner_basic")
			var option: Dictionary = offer["options"][0]
			check(not LEVELS.apply_option_with_result(player, option["id"], offer).is_empty(), "choice accepted")
			check(LEVELS.apply_option_with_result(player, option["id"], offer).is_empty(), "stale offer rejected")
	check(is_equal_approx(BUILD.damage_ratio(player), 3.0), "rapid max 300 percent")
	check(is_equal_approx(player._get_effective_attack_speed("gunner"), 1.0), "rapid speed 1.0")
	var normalized := LEVELS.normalize_role_state("gunner", player.role_special_states["gunner"])
	check(normalized == LEVELS.normalize_role_state("gunner", normalized), "normalization idempotent")
	var request := {"kind": "skill", "role_id": "gunner", "id": "gunner_basic"}
	player.gunner_role.perform_attack(player)
	var batch = scene.get_node("PlayerProjectileBatch")
	batch.set_process(false)
	check(batch.positions.size() == 1, "first rapid shot immediate")
	await create_timer(0.3).timeout
	check(batch.positions.size() == 2, "second rapid shot at 0.25 seconds")
	check(is_equal_approx(batch.speeds[0], 836.0), "rapid projectile speed +10 percent")
	var enemy := Target.new()
	enemy.enemy_kind = "boss"
	scene.add_child(enemy)
	var before: int = batch.positions.size()
	batch._apply_projectile_hit(0, enemy)
	check(batch.positions.size() == before + 3, "three split children")
	for index in range(before, before + 3):
		check(is_equal_approx(batch.damages[index], batch.damages[0] * 0.8), "split damage 80 percent")
		check(is_equal_approx(batch.speeds[index], batch.speeds[0]), "same split speed")
		check(is_equal_approx(batch.speeds[index] * batch.lifetimes[index], 255.0), "full split distance 60 percent")
		check(batch.role_ids[index] == "gunner_aux:split", "split excludes basic procs")
		check(batch._has_projectile_hit_enemy(index, enemy), "split excludes original target")
	batch._clear_projectiles()
	TOOLS.apply(player, request.merged({"operation": "branch", "stage": 4, "choice": "sniper"}))
	TOOLS.apply(player, request.merged({"operation": "branch", "stage": 8, "choice": "shock"}))
	check(is_equal_approx(BUILD.damage_ratio(player), 3.4), "sniper max 340 percent")
	check(is_equal_approx(player._get_effective_attack_speed("gunner"), 0.45), "sniper speed 0.45")
	player.gunner_role.perform_attack(player)
	check(is_equal_approx(batch.speeds[0] * batch.lifetimes[0], 600.0), "sniper range 600")
	# Repeat hits only in this isolated test to sample both strong-shock outcomes.
	var shock_count := 0
	for index in range(100):
		var position_before: Vector2 = enemy.global_position
		batch._apply_projectile_hit(0, enemy)
		if enemy.global_position != position_before:
			shock_count += 1
			check(is_equal_approx(enemy.global_position.distance_to(position_before), 25.0), "boss knockback 25")
	check(shock_count > 0 and shock_count < 100, "shock probabilistic")
	var shot_attack: float = batch.damages[0] / 3.4
	check(is_equal_approx(batch._build_hit_damage(0, enemy, 0.0), shot_attack * 3.4 * 1.8), "shock multiplies this hit by 1.8")
	check(is_equal_approx(batch._build_hit_damage(0, enemy, 0.9), shot_attack * 3.4), "normal hit unchanged")
	batch._clear_projectiles()
	batch.add_projectile({"damage": 10.0, "role_id": "gunner_aux:split", "pierce_count": -1, "position": Vector2.ZERO})
	batch._apply_projectile_hit(0, enemy)
	check(batch._has_projectile_hit_enemy(0, enemy), "unlimited pierce remembers hit target")
	check(batch.pierce_counts[0] == -1, "unlimited pierce remains unlimited")
	TOOLS.apply(player, request.merged({"operation": "branch", "stage": 9, "choice": "frenzy"}))
	check(BUILD.on_shot(player, 0.0), "frenzy triggers")
	check(is_equal_approx(player._get_effective_attack_speed("gunner"), 1.25), "frenzy adds 0.8 speed")
	BUILD.tick(player, 1.0)
	check(not BUILD.on_shot(player, 0.0), "frenzy cannot refresh")
	BUILD.tick(player, 3.0)
	check(not BUILD.on_shot(player, 0.0), "frenzy remains active for 5 seconds")
	BUILD.tick(player, 1.0)
	check(BUILD.on_shot(player, 0.0), "frenzy retriggers after full expiry")
	TOOLS.apply(player, request.merged({"operation": "set", "amount": 4}))
	check(BUILD.choices(player) == {"4": "sniper"}, "lowering level removes later choices")
	TOOLS.apply(player, request.merged({"operation": "reset"}))
	check(BUILD.level(player) == 0 and BUILD.choices(player).is_empty(), "developer reset")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("GUNNER_BASIC_BUILD_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

class Target:
	extends Node2D
	var current_health := 1000000.0
	var max_health := 1000000.0
	var enemy_kind := "normal"
	var pooled_inactive := false
	var rebirth_timer := 0.0
	func take_damage(amount: float, _critical: bool = false) -> bool:
		current_health -= amount
		return false

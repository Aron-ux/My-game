extends SceneTree

const BUILD := preload("res://scripts/player/player_mage_basic_build.gd")
const RUNTIME := preload("res://scripts/player/player_mage_basic_runtime.gd")
const LEVELS := preload("res://scripts/player/player_skill_level_system.gd")
const TOOLS := preload("res://scripts/developer/developer_build_tools.gd")
const STUN := preload("res://scripts/enemies/enemy_stun.gd")
const ROUTINE := preload("res://scripts/enemies/enemy_boss_routine.gd")
const SAVE := preload("res://scripts/enemies/enemy_save_data.gd")
const PLAYER := preload("res://scenes/player.tscn")
const ENEMY := preload("res://scenes/enemy.tscn")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _run() -> void:
	var scene := Combat.new()
	root.add_child(scene)
	current_scene = scene
	var player = PLAYER.instantiate()
	scene.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.auto_attack_enabled = false
	player.fire_timer.stop()
	player.active_role_index = 2
	check(BUILD.level(player) == 0 and is_equal_approx(BUILD.damage_ratio(player), 2.0), "LV0 200 percent")
	for lv in range(1, 10):
		LEVELS.add_skill_level(player, "mage", "mage_basic")
		check(BUILD.level(player) == lv, "level %d" % lv)
		if lv in BUILD.STAGES:
			var offer := LEVELS.build_talent_offer_for(player, "mage", "mage_basic")
			check(offer["options"].size() == 2, "two branch choices")
			var option: Dictionary = offer["options"][0]
			check(not LEVELS.apply_option_with_result(player, option["id"], offer).is_empty(), "branch applied")
	check(is_equal_approx(BUILD.damage_ratio(player), 3.5), "max focus ratio 350 percent")
	player.role_mana_values["mage"] = 62.0
	check(is_equal_approx(player._get_effective_attack_speed("mage"), 0.17), "focus additive speed at 62 energy with storm and LV6 penalties")
	check(is_equal_approx(BUILD.range_multiplier(player), 1.25), "focus range")
	check(is_equal_approx(BUILD.energy_bonus(player, "mage_basic:test"), 0.2), "energy x1.2")
	var request := {"kind": "skill", "role_id": "mage", "id": "mage_basic"}
	TOOLS.apply(player, request.merged({"operation": "branch", "stage": 4, "choice": "charge"}))
	var enemy = ENEMY.instantiate()
	scene.add_child(enemy)
	scene.enemies.append(enemy)
	enemy.target = player
	enemy.set_physics_process(false)
	enemy.max_health = 10000.0
	enemy.current_health = 10000.0
	enemy.armor = 0.0
	enemy.damage_reduction_rate = 0.0
	enemy.damage_reduction_value = 0.0
	for index in range(3):
		enemy.take_damage(10.0)
		RUNTIME.after_hit(player, enemy, "mage_basic:test", false)
		check(enemy.electric_stacks == index + 1, "one stack per hit")
	check(enemy.current_health > 9900.0, "third hit does not detonate")
	var before: float = enemy.current_health
	var proc: float = player._get_role_damage("mage") * 4.0
	enemy.take_damage(10.0)
	check(enemy.electric_stacks == 0, "next damage consumes stacks")
	var armor_rules = preload("res://scripts/combat/armor_rules.gd")
	check(is_equal_approx(before - enemy.current_health, armor_rules.apply_damage(10.0 + proc, -60.0) * 1.15), "400 percent active role attack with 3 stacks of armor shred and vulnerability")
	enemy.shot_timer = 0.3
	enemy.dash_windup_remaining = 0.2
	check(enemy.apply_stun(0.5), "normal stunned")
	check(enemy.dash_windup_remaining == 0.0, "charge interrupted")
	check(enemy.try_stalwart_body_damage() > 0.0, "stalwart contact remains active during stun")
	var position_before: Vector2 = enemy.position
	STUN.tick(enemy, 0.4)
	check(is_equal_approx(enemy.stun_remaining, 0.1) and enemy.shot_timer == 0.0, "cooldown progresses during stun")
	check(enemy.position == position_before, "stun prevents movement")
	STUN.tick(enemy, 0.1)
	check(enemy.stun_remaining <= 0.00001, "exact expiry")
	var boss = ENEMY.instantiate()
	scene.add_child(boss)
	boss.set_physics_process(false)
	boss.target = player
	boss.enemy_kind = "boss"
	boss.behavior_id = "boss"
	boss.max_health = 45000.0
	boss.current_health = 20000.0
	boss.boss_shield_max_health = 5000.0
	boss.boss_shield_break_intro_played = false
	boss.armor = 25.0
	boss.damage_reduction_rate = 0.25
	boss.take_direct_damage(900.0)
	var payload: Dictionary = boss.get_boss_ui_payload()
	check(is_equal_approx(payload["shield_health"], 5000.0), "heaven bypasses shield")
	check(is_equal_approx(payload["current_health"], 14100.0), "heaven removes real HP")
	check(not boss.boss_shield_break_intro_played, "direct hit does not break shield")
	boss.boss_shield_break_intro_played = true
	boss.boss_direct_health_loss = 0.0
	boss.current_health = 15000.0
	ROUTINE.reset(boss)
	boss.boss_routine.stage = "performance"
	boss.boss_routine.elapsed = 4.0
	check(not boss.apply_stun(0.5), "performance does not stop")
	boss.apply_stun(3.0)
	check(is_equal_approx(ROUTINE.get_duration(boss, "recovery"), 9.5), "one deferred extension only")
	check(is_equal_approx(boss.boss_routine.elapsed, 4.0), "performance timeline retained")
	boss.boss_routine.stage = "recovery"
	boss.boss_routine.elapsed = 2.0
	boss.apply_stun(5.0)
	check(is_equal_approx(ROUTINE.get_duration(boss, "recovery"), 9.5) and boss.boss_routine.elapsed == 2.0, "recovery not reset")
	var saved: Dictionary = SAVE.get_save_data(boss)
	ROUTINE.restore(boss, saved["boss_routine"])
	check(is_equal_approx(ROUTINE.get_duration(boss, "recovery"), 9.5), "save retains extension")
	ROUTINE.reset(boss)
	boss.boss_routine.stage = "preview"
	check(boss.apply_stun(0.5), "ordinary windup interrupted")
	check(boss.boss_routine.stage == "basic", "interrupted cast does not resume")
	STUN.tick(boss, 0.5)
	boss.boss_phase_transition_target = 2
	check(not boss.apply_stun(0.5), "phase transition immune")
	boss.boss_phase_transition_target = 0
	TOOLS.apply(player, request.merged({"operation": "branch", "stage": 9, "choice": "quake"}))
	check(is_equal_approx(BUILD.strike_ratio(player), 4.5), "quake adds 100 points")
	check(is_equal_approx(BUILD.strike_ratio(player, 0.4225), 3.5 * 0.4225 + 1.0), "quake applies to every storm strike")
	TOOLS.apply(player, request.merged({"operation": "branch", "stage": 4, "choice": "storm"}))
	TOOLS.apply(player, request.merged({"operation": "branch", "stage": 8, "choice": "heaven"}))
	check(is_equal_approx(BUILD.base_speed_modifier(player), -0.35), "storm heaven quake base penalties stack")
	check(is_equal_approx(player._get_effective_attack_speed("mage"), 0.15), "final speed preserves 0.15 minimum")
	TOOLS.apply(player, request.merged({"operation": "set", "amount": 5}))
	check(is_equal_approx(player._get_effective_attack_speed("mage"), 0.25), "lowering level clears heaven quake and LV6 penalties")
	TOOLS.apply(player, request.merged({"operation": "reset"}))
	check(BUILD.level(player) == 0 and BUILD.choices(player).is_empty(), "developer reset LV0")
	check(is_equal_approx(player._get_effective_attack_speed("mage"), 0.4), "reset restores original base speed")
	var caster := CastStub.new()
	scene.add_child(caster)
	caster.fire_timer = Timer.new()
	caster.add_child(caster.fire_timer)
	RUNTIME.perform(caster)
	check(caster.jobs.size() == 1, "storm starts a sequential cast")
	caster.aim = Vector2(800, 800)
	for index in range(3):
		caster.jobs[index].callback.call(0)
		check(caster.hits[index].center == Vector2(100, 50), "first aim position remains fixed")
		check(caster.restarts == (1 if index == 2 else 0), "cooldown begins only after third strike")
	check(is_equal_approx(caster.jobs[1].delay, 0.2), "first interval 0.2")
	check(is_equal_approx(caster.jobs[2].delay, 0.45), "second interval 0.45")
	check(caster.hits.size() == 3 and caster.jobs.size() == 3, "one storm cast counts as one lightning")
	for cast_index in range(2):
		for strike_index in range(3):
			RUNTIME.strike(caster, Vector2(100, 50), 40.0, strike_index, true)
	check(caster.jobs.size() == 4, "third lightning cast schedules one divine")
	check(is_equal_approx(caster.jobs[3].delay, 0.4), "divine delay is 0.4 seconds")
	var local_hits_before_divine: int = caster.hits.size()
	caster.jobs[3].callback.call(0)
	check(caster.hits.size() == local_hits_before_divine and caster.jobs.size() == 4, "divine does not recursively count or repeat local damage")
	check(caster.global_hits.size() == 1, "divine damages globally once without local duplicate damage")
	check(is_equal_approx(caster.global_hits[0].damage, caster.hits[0].damage * 1.5), "divine deals 150 percent of the current strike multiplier")
	check(is_equal_approx(caster.hits[1].damage, caster.hits[0].damage * 0.65), "second 65 percent")
	check(is_equal_approx(caster.hits[2].damage, caster.hits[0].damage * 0.4225), "third 42.25 percent")
	check(caster.shakes[0] < caster.shakes[1] and caster.shakes[1] < caster.shakes[2], "progressively stronger shake")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("MAGE_BASIC_BUILD_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

class Combat:
	extends Node2D
	var enemies: Array = []
	func get_runtime_enemies() -> Array:
		return enemies

class CastStub:
	extends Node2D
	var role_special_states := {"mage": {"skill_levels": {"mage_basic": 9}, "mage_basic_build": {"4": "storm", "8": "heaven", "9": "divine"}}}
	var role_upgrade_levels := {"mage": {"range_bonus": 0.0}}
	var fire_timer: Timer
	var is_dead := false
	var MAGE_WARNING_EFFECT_SCENE = null
	var aim := Vector2(100, 50)
	var jobs: Array = []
	var hits: Array = []
	var global_hits: Array = []
	var shakes: Array = []
	var restarts := 0
	func _get_active_role() -> Dictionary:
		return {"id": "mage", "range": 350.0}
	func _get_mage_mouse_bombard_center(_range: float) -> Vector2:
		return aim
	func _get_role_attribute_range_multiplier(_role: String) -> float:
		return 1.0
	func _get_role_equipment_skill_range_multiplier(_role: String) -> float:
		return 1.0
	func _get_role_damage(_role: String) -> float:
		return 10.0
	func _spawn_mage_warning_scene_effect(_center: Vector2, _radius: float) -> void:
		pass
	func _spawn_mage_boom_scene_effect(_center: Vector2, _radius: float) -> Node2D:
		return null
	func _get_scene_animation_duration(_scene, fallback: float) -> float:
		return fallback
	func _schedule_repeating_sequence(_interval: float, _count: int, callback: Callable, delay: float) -> void:
		jobs.append({"callback": callback, "delay": delay})
	func _update_fire_timer() -> void:
		restarts += 1
	func _queue_camera_shake(strength: float, _duration: float) -> void:
		shakes.append(strength)
	func _create_basic_attack_source_id(_role: String) -> String:
		return "mage_basic:test"
	func _damage_enemies_in_ellipse(center: Vector2, horizontal: float, _vertical: float, damage: float, _vulnerability: float, _slow: float, _duration: float, _source: String) -> int:
		hits.append({"center": center, "radius": horizontal, "damage": damage})
		return 1
	func _damage_all_enemies(damage: float, _vulnerability: float, _slow: float, _duration: float, _source: String) -> int:
		global_hits.append({"damage": damage})
		return 1

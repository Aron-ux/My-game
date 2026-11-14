extends SceneTree

const SCALING := preload("res://scripts/game/enemy_tier_wave_scaling.gd")
const SPAWN := preload("res://scripts/game/enemy_spawn_instance_flow.gd")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const DIFFICULTY := preload("res://scripts/game/difficulty_profile.gd")
const PLANTS := preload("res://scripts/enemies/enemy_plant_behavior.gd")
const PROJECTILES := preload("res://scripts/enemies/enemy_projectiles.gd")
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func check_close(actual: float, expected: float, label_text: String) -> void:
	if not is_equal_approx(actual, expected):
		failures += 1
		push_error("%s: expected %f, got %f" % [label_text, expected, actual])

func _run() -> void:
	var scene := Runtime.new()
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.player = Node2D.new()
	scene.player.position = Vector2(1000, 0)
	scene.add_child(scene.player)
	scene.wave_flow = Wave.new()
	scene.add_child(scene.wave_flow)
	var hp_initial := [0.8, 1.0, 2.0, 2.5, 2.5]
	var atk_initial := [0.8, 1.0, 1.5, 2.0, 2.5]
	var hp_growth := [1.0, 1.15, 1.2, 1.2, 1.25]
	var speed_growth := [1.0, 1.0, 1.01, 1.015, 1.02]
	var flat_growth := [0.0, 0.0, 0.0, 1.5, 2.0]
	for tier in range(1, 6):
		scene.difficulty_profile = DIFFICULTY.get_endless_tier_profile(tier)
		for wave in range(1, 21):
			scene.wave_flow.wave = wave
			var enemy = spawn(scene, "normal", "chaser")
			check_close(enemy.max_health, 30.0 * hp_initial[tier - 1] * pow(hp_growth[tier - 1], wave - 1), "health N%d W%d" % [tier, wave])
			check_close(enemy.attack, 15.0 * atk_initial[tier - 1] + flat_growth[tier - 1] * (wave - 1), "attack N%d W%d" % [tier, wave])
			check_close(enemy.speed, 60.0 * pow(speed_growth[tier - 1], wave - 1), "speed")
			check_close(enemy.damage_reduction_rate, floorf(float(wave) / 5.0) * 0.05 if tier == 5 else 0.0, "reduction boundary")
			check_close(enemy.try_stalwart_body_damage(), enemy.attack * 1.5, "actual contact coefficient")
			enemy.free()
	# First appearance on wave 10, and elite scaling.
	scene.difficulty_profile = DIFFICULTY.get_endless_tier_profile(4)
	scene.wave_flow.wave = 10
	var shotgun = spawn(scene, "normal", "shotgunner")
	check_close(shotgun.attack, 63.5, "N4 wave10 shotgun attack")
	PROJECTILES._fire_shooter_pattern_now(shotgun)
	var shots := 0
	for node in scene.get_children():
		if node.get_script() == preload("res://scripts/enemy_bullet.gd"):
			check_close(node.damage, 127.0, "actual shotgun damage 200 percent")
			shots += 1
			node.free()
	if shots == 0:
		failures += 1
		push_error("No actual shotgun bullets spawned")
	var elite = spawn(scene, "elite", "elite_ram_trail")
	check_close(elite.attack, 30.0 * 2.0 + 13.5, "elite current wave")
	# Seed health and hatching use own templates/current wave, not parent HP.
	var tree = spawn(scene, "normal", "shadow_tree")
	var seed = PLANTS.throw_tree_seed(tree)
	check_close(seed.max_health, 60.0 * 2.5 * pow(1.2, 9), "summoned seed")
	scene.wave_flow.wave = 11
	PLANTS.hatch(seed)
	check_close(seed.max_health, 50.0 * 2.5 * pow(1.2, 10), "hatch current wave")
	check_close(seed.attack, 20.0 * 2.0 + 15.0, "hatch independent attack")
	# Reapplication and save restore must not compound multipliers.
	SCALING.apply_spawn(seed, scene)
	check_close(seed.attack, 55.0, "no double scaling")
	var restored = scene.enemy_scene.instantiate()
	scene.add_child(restored)
	restored.apply_save_data(seed.get_save_data(), scene.player)
	check_close(restored.attack, seed.attack, "save restore attack")
	check_close(restored.max_health, seed.max_health, "save restore health")
	# Existing reduction adds directly; porcupine base 80% + N5 wave10 10%.
	scene.difficulty_profile = DIFFICULTY.get_endless_tier_profile(5)
	scene.wave_flow.wave = 10
	var porcupine = spawn(scene, "normal", "angry_porcupine")
	check_close(porcupine.damage_reduction_rate, 0.9, "additive base reduction")
	# A Boss-summoned rose is a non-boss attack and uses the current wave.
	var rose_owner = scene.enemy_scene.instantiate()
	scene.add_child(rose_owner)
	rose_owner.apply_enemy_profile("small_boss", DATABASE.get_profile("small_boss", "smallboss_turret"))
	var rose := preload("res://scripts/enemies/rose_minion.gd").new()
	scene.add_child(rose)
	rose.configure(rose_owner, scene.player, scene.enemy_bullet_scene, Vector2.ONE, 999.0, 320.0, 4.4)
	check_close(rose.projectile_damage, 80.0 * 2.5 + 18.0, "rose summon current wave, not boss multiplier")
	# Bosses receive N1-N5 initial HP/attack multipliers, but no wave growth.
	var boss_hp_initial := [0.8, 1.0, 2.0, 2.5, 2.5]
	var boss_attack_initial := [0.8, 1.0, 1.5, 2.0, 2.5]
	for tier in range(1, 6):
		scene.difficulty_profile = DIFFICULTY.get_endless_tier_profile(tier)
		for wave in [1, 10, 20]:
			scene.wave_flow.wave = wave
			for archetype in ["smallboss_glutton", "smallboss_rebirth", "smallboss_turret", "boss_spellcore"]:
				var kind := "boss" if archetype == "boss_spellcore" else "small_boss"
				var boss = spawn(scene, kind, archetype)
				var base := DATABASE.get_profile(kind, archetype)
				check_close(boss.attack, float(base.attack) * boss_attack_initial[tier - 1], "boss attack N%d W%d" % [tier, wave])
				check_close(boss.max_health, float(base.max_health) * boss_hp_initial[tier - 1], "boss health N%d W%d" % [tier, wave])
				check_close(boss.speed, float(base.speed), "boss speed has no wave growth")
				check_close(boss.damage_reduction_rate, float(base.get("damage_reduction_rate", 0.0)), "boss reduction has no wave growth")
				boss.free()
	# Developer mode without a wave defaults to initial multipliers.
	scene.difficulty_profile = DIFFICULTY.get_endless_tier_profile(4)
	scene.wave_flow.free()
	scene.wave_flow = null
	var initial = spawn(scene, "normal", "shotgunner")
	check_close(initial.attack, 50.0, "developer initial attack")
	check_close(initial.max_health, 80.0 * 2.5, "developer initial health")
	scene.free()
	current_scene = null
	if failures == 0:
		print("ENEMY_TIER_WAVE_SCALING_SMOKE_OK")
	quit(0 if failures == 0 else 1)

func spawn(scene, kind: String, archetype: String):
	return SPAWN.spawn_configured_enemy_at_position(scene, kind, archetype, float(scene.difficulty_profile.boss_health_scale if kind in ["boss", "small_boss"] else scene.difficulty_profile.enemy_health_scale), float(scene.difficulty_profile.enemy_speed_scale), Vector2.ZERO, float(scene.difficulty_profile.enemy_damage_scale))

class Wave:
	extends Node
	const PLAN := preload("res://scripts/game/combat_wave_plan.gd")
	var wave := 1
	var phase := "combat"

class Runtime:
	extends Node2D
	const ENEMY_SPAWN_FLOW := preload("res://scripts/game/enemy_spawn_flow.gd")
	var difficulty_profile: Dictionary = {}
	var wave_flow: Node
	var enemy_scene := preload("res://scenes/enemy.tscn")
	var enemy_bullet_scene := preload("res://scenes/enemy_bullet.tscn")
	var heart_pickup_scene := preload("res://scenes/heart_pickup.tscn")
	var player: Node2D
	var endless_mode_active := true
	var map_bounds := Rect2(-2000, -2000, 4000, 4000)
	func _on_enemy_defeated(_kind: String, _enemy: Node) -> void:
		pass
	func _get_difficulty_projectile_speed_bonus() -> float:
		return float(difficulty_profile.get("projectile_speed_bonus", 0.0))

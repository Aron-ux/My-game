extends SceneTree

const ENEMY := preload("res://scenes/enemy.tscn")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const DIFFICULTY := preload("res://scripts/game/difficulty_profile.gd")
const SPAWN := preload("res://scripts/game/enemy_spawn_instance_flow.gd")
const STATE := preload("res://scripts/enemies/enemy_boss_state.gd")
const DAMAGE := preload("res://scripts/enemies/enemy_damage.gd")
const MOTION := preload("res://scripts/enemies/enemy_movement.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Runtime.new()
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.player = Node2D.new()
	scene.add_child(scene.player)
	var boss = SPAWN.spawn_configured_enemy_at_position(scene, "boss", "boss_spellcore", 1.0, 1.0, Vector2.ZERO, 0.8)
	assert(boss.boss_display_name == "被污染的魔法石")
	assert(is_equal_approx(boss.attack, 80.0) and is_equal_approx(boss.speed, 30.0))
	assert(is_equal_approx(boss.max_health, 45000.0) and is_equal_approx(boss.current_health, 20000.0))
	assert(is_equal_approx(boss.boss_shield_max_health, 5000.0))
	assert(is_equal_approx(boss.try_stalwart_body_damage(), 120.0))
	assert(is_equal_approx(MOTION.compute_boss_velocity(boss, Vector2.RIGHT, 500.0, 0.01).length(), 30.0))
	var before: float = boss.current_health
	DAMAGE.apply_damage(boss, 100.0, false)
	assert(is_equal_approx(before - boss.current_health, 60.0)) # 100 / 1.25 * .75
	boss.apply_fury_armor_shred(5.0, 2.0)
	before = boss.current_health
	DAMAGE.apply_damage(boss, 120.0, false)
	assert(is_equal_approx(before - boss.current_health, 75.0))
	var restored = ENEMY.instantiate()
	scene.add_child(restored)
	restored.apply_save_data(boss.get_save_data(), scene.player)
	assert(is_equal_approx(restored.boss_shield_max_health, 5000.0) and STATE.has_boss_shield(restored))
	assert(is_equal_approx(restored.get_boss_ui_payload().shield_health, boss.get_boss_ui_payload().shield_health))
	boss.current_health = 15001.0
	DAMAGE.apply_damage(boss, 100.0, false)
	assert(boss.boss_shield_break_intro_played and not STATE.has_boss_shield(boss))
	assert(is_equal_approx(boss.current_health, 15000.0))
	boss.boss_phase_three_intro_remaining = 0.0
	boss.boss_shield_break_visual_intro_active = false
	before = boss.current_health
	DAMAGE.apply_damage(boss, 105.0, false)
	assert(is_equal_approx(before - boss.current_health, 90.0)) # Existing -5 armor persists.
	boss.fury_armor_shred = 0.0
	before = boss.current_health
	DAMAGE.apply_damage(boss, 110.0, false)
	assert(is_equal_approx(before - boss.current_health, 90.0))
	restored.apply_save_data(boss.get_save_data(), scene.player)
	assert(not STATE.has_boss_shield(restored))
	assert(is_equal_approx(restored.attack, 80.0) and is_equal_approx(restored.armor, 10.0))
	var n2 := DIFFICULTY.get_endless_tier_profile(2)
	var higher = SPAWN.spawn_configured_enemy_at_position(scene, "boss", "boss_spellcore", n2.boss_health_scale, n2.enemy_speed_scale, Vector2.ZERO, n2.enemy_damage_scale)
	assert(is_equal_approx(higher.max_health, 54000.0))
	assert(is_equal_approx(higher.attack, 86.8))
	assert(is_equal_approx(higher.speed, 32.4))
	var ordinary = SPAWN.spawn_configured_enemy_at_position(scene, "normal", "chaser", 1.0, 1.0, Vector2.ZERO, 0.8)
	assert(is_equal_approx(ordinary.max_health, 30.0 * 2.04))
	assert(is_equal_approx(ordinary.attack, 15.0 * 0.8))
	scene.free()
	current_scene = null
	print("BOSS_MAGIC_STONE_STATS_SMOKE_OK")
	quit()


class Runtime:
	extends Node2D
	const ENEMY_SPAWN_FLOW := preload("res://scripts/game/enemy_spawn_flow.gd")
	var enemy_scene := ENEMY
	var enemy_bullet_scene := preload("res://scenes/enemy_bullet.tscn")
	var heart_pickup_scene := preload("res://scenes/heart_pickup.tscn")
	var player: Node2D
	var endless_mode_active := true
	var map_bounds := Rect2(-2000, -2000, 4000, 4000)
	func _on_enemy_defeated(_kind: String, _enemy: Node) -> void:
		pass

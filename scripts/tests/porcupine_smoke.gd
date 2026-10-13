extends SceneTree

const ENEMY := preload("res://scenes/enemy.tscn")
const DB := preload("res://scripts/enemy/enemy_archetype_database.gd")
const DAMAGE := preload("res://scripts/enemies/enemy_damage.gd")
const RAGE := preload("res://scripts/enemies/enemy_porcupine.gd")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var target := Node2D.new()
	target.position = Vector2(1000, 0)
	scene.add_child(target)
	var enemy = ENEMY.instantiate()
	enemy.target = target
	enemy.apply_enemy_profile("normal", DB.get_profile("normal", "angry_porcupine"))
	scene.add_child(enemy)
	enemy.set_physics_process(false)
	enemy._cached_direction_to_target = Vector2.RIGHT
	check(enemy.max_health == 200 and enemy.attack == 30 and enemy.armor == 15 and enemy.speed == 80, "base attributes")
	check(RAGE.crossed_health_thresholds(200, 200, 139) == 3, "large hit crosses three ten-percent thresholds")
	check(RAGE.crossed_health_thresholds(200, 185, 179) == 1, "healing allows repeated threshold crossing")
	check(RAGE.crossed_health_thresholds(200, 180, 179) == 0, "starting exactly on threshold does not double count")
	check(is_equal_approx(enemy.damage_reduction_rate, 0.8) and is_equal_approx(enemy.status_resistance, 0.2), "base rates")
	check(enemy.try_stalwart_body_damage() == 45, "normal contact damage")
	DAMAGE.apply_damage(enemy, 100, false)
	check(is_equal_approx(enemy.porcupine_state.rage, 20), "rage uses damage before defenses")
	var expected: float = preload("res://scripts/combat/armor_rules.gd").apply_damage(100, 15) * 0.2
	check(is_equal_approx(enemy.current_health, 200 - expected), "normal reduction eighty percent")
	DAMAGE.apply_damage(enemy, 100, false)
	DAMAGE.apply_damage(enemy, 100, false)
	check(RAGE.is_enraged(enemy) and enemy.porcupine_state.rage == 0, "three hundred raw damage triggers rage")
	check(is_equal_approx(enemy._compute_velocity(0).length(), 112), "rage doubles movement")
	enemy.stalwart_body_cooldown = 0
	check(enemy.try_stalwart_body_damage() == 90, "rage contact damage doubles")
	var before: float = enemy.current_health
	DAMAGE.apply_damage(enemy, 10, false)
	check(is_equal_approx(before - enemy.current_health, preload("res://scripts/combat/armor_rules.gd").apply_damage(10, -5)), "rage has minus5 armor and zero reduction")
	check(enemy.porcupine_state.rage == 0, "rage does not accumulate while active")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(enemy.get_save_data()))
	var restored = ENEMY.instantiate()
	scene.add_child(restored)
	restored.apply_save_data(saved, target)
	restored.set_physics_process(false)
	check(RAGE.is_enraged(restored) and restored.get_node("ProfileVisual").enraged, "rage save restores visual")
	RAGE.tick(restored, 20)
	check(not RAGE.is_enraged(restored) and is_equal_approx(restored._compute_velocity(0).length(), 56), "rage expires restoring movement")
	check(restored.attack == 30 and restored.armor == 15 and restored.damage_reduction_rate == 0.8, "rage keeps base stats intact")
	preload("res://scripts/enemies/enemy_pool_lifecycle.gd").prepare_for_pool(restored)
	check(restored.porcupine_state.rage == 0 and restored.porcupine_state.remaining == 0, "pool resets rage")
	scene.free()
	current_scene = null
	if failures == 0:
		print("PORCUPINE_SMOKE_OK")
	quit(0 if failures == 0 else 1)

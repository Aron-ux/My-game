extends SceneTree

const ENEMY := preload("res://scenes/enemy.tscn")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const MAGE := preload("res://scripts/enemies/enemy_skull_mage.gd")
const DAMAGE := preload("res://scripts/enemies/enemy_damage.gd")
const DOMAIN := preload("res://scripts/enemies/skull_mage_domain.gd")
const EFFECTS := preload("res://scripts/player/player_skull_mage_effects.gd")
const POOL := preload("res://scripts/enemies/enemy_pool_lifecycle.gd")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func make_enemy(scene: Node, player: Node2D):
	var enemy = ENEMY.instantiate()
	enemy.target = player
	enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", "skull_mage"))
	scene.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func _run() -> void:
	var scene := RuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene
	var player := Target.new()
	scene.add_child(player)
	var enemy = make_enemy(scene, player)
	check(enemy.max_health == 100 and enemy.attack == 15 and enemy.armor == 0 and enemy.speed == 30, "authored base attributes")
	check(enemy.status_resistance == 0 and enemy.damage_reduction_rate == 0, "normal resistances")
	check(not enemy.can_use_batch_simulation(), "mage uses full skill simulation")
	check(DATABASE.get_normal_archetypes().has("skull_mage"), "developer normal enemy catalog")
	player.position = Vector2(200, 0)
	MAGE.update(enemy, 2.9)
	check(not MAGE.is_draining(enemy), "drain waits three continuous seconds")
	MAGE.update(enemy, 0.1)
	check(MAGE.is_draining(enemy), "drain locks at three seconds")
	enemy.current_health = 40
	player.position = Vector2(250, 0)
	MAGE.update(enemy, 1)
	check(MAGE.is_draining(enemy), "drain remains active at250 boundary")
	check(player.current_health == 85 and enemy.current_health == 55, "drain heals actual damage once per second")
	player.position = Vector2(251, 0)
	MAGE.update(enemy, 0.2)
	check(not MAGE.is_draining(enemy) and player.current_health == 70 and enemy.current_health == 70, "leaving settles pending tick and ends drain")
	MAGE.reset(enemy)
	enemy.skull_mage_state.ice_cooldown = 0.0
	MAGE.update(enemy, 0)
	check(MAGE.is_ice_active(enemy), "ice starts on ready")
	enemy.current_health = 100
	var reduced: float = preload("res://scripts/combat/armor_rules.gd").apply_damage(50, 10) * 0.8
	DAMAGE.apply_damage(enemy, 50, false)
	check(is_equal_approx(EFFECTS.get_cold_remaining(player), 3.0), "attacking ice armor applies cold")
	check(is_equal_approx(enemy.current_health, 100 - maxf(0, reduced - 20)), "ice armor and reduction precede temporary HP")
	check(is_zero_approx(float(enemy.skull_mage_state.temporary_health)), "temporary HP is consumed")
	EFFECTS.on_enemy_damage(player, enemy, 10)
	check(is_equal_approx(EFFECTS.attack_speed_multiplier(player), 0.7), "cold slows attack speed thirty percent")
	EFFECTS.tick(player, 3)
	check(EFFECTS.attack_speed_multiplier(player) == 1, "cold expires")
	enemy.skull_mage_state.domain_cooldown = 0.0
	MAGE.update(enemy, 0)
	var fields := get_nodes_in_group("skull_mage_domains")
	check(fields.size() == 1, "domain spawned independently")
	player.position = Vector2(300, 0)
	check(DOMAIN.get_slow_multiplier(player) == 0.8, "domain movement penalty")
	player.gunner_magic_eye_ability.cooldown_remaining = 10.0
	for index in 12:
		EFFECTS.slow_cooldowns_before_update(player, 1.0)
		player.gunner_magic_eye_ability.cooldown_remaining = maxf(0, player.gunner_magic_eye_ability.cooldown_remaining - 1)
		if index == 9:
			check(is_equal_approx(player.gunner_magic_eye_ability.cooldown_remaining, 10.0 / 6), "ten real seconds advance only 8.333 seconds")
	check(player.gunner_magic_eye_ability.cooldown_remaining < 0.000001, "ten second CD ends in twelve real seconds")
	player.position = Vector2(301, 0)
	check(DOMAIN.get_slow_multiplier(player) == 1, "leaving domain removes penalty")
	enemy.skull_mage_state.ice_remaining = 0.0
	scene.difficulty_profile = {"tier": 3}
	DAMAGE.apply_damage(enemy, 10000, false)
	check(enemy.current_health == 1 and MAGE.is_invulnerable(enemy), "N3 lethal hit leaves one HP")
	DAMAGE.apply_damage(enemy, 10000, false)
	check(enemy.current_health == 1, "two second immunity rejects damage")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(enemy.get_save_data()))
	var restored = make_enemy(scene, player)
	restored.apply_save_data(saved, player)
	check(MAGE.is_invulnerable(restored) and restored.skull_mage_state.death_used, "save keeps one-use death protection")
	MAGE.tick_passives(restored, 2)
	restored.current_health = 0
	check(not MAGE.try_death_save(restored), "death protection cannot trigger twice")
	restored.current_health = 1
	POOL.prepare_for_pool(restored)
	check(not restored.skull_mage_state.death_used and not MAGE.is_invulnerable(restored), "pool clears mage state")
	restored.apply_enemy_profile("normal", DATABASE.get_profile("normal", "skull_mage"))
	restored.pooled_inactive = false
	restored.current_health = 100
	make_enemy(scene, player)
	make_enemy(scene, player)
	check(not MAGE.can_spawn(scene), "hard cap four living mages")
	var field_save: Dictionary = fields[0].get_save_data()
	check(field_save.remaining == 10 and field_save.position == [0.0, 0.0], "domain saves location and lifetime")
	restored.skull_mage_state.domain_cooldown = 0.0
	MAGE.update(restored, 0)
	check(get_nodes_in_group("skull_mage_domains").size() == 1, "second mage cannot cast while domain exists")
	check(is_zero_approx(float(restored.skull_mage_state.domain_cooldown)), "waiting mage retains ready cooldown")
	fields[0].free()
	MAGE.update(restored, 0)
	check(get_nodes_in_group("skull_mage_domains").size() == 1, "ready mage casts immediately after previous domain ends")
	check(is_equal_approx(float(restored.skull_mage_state.domain_cooldown), 25.0), "casting starts individual cooldown")
	scene.free()
	current_scene = null
	if failures == 0:
		print("SKULL_MAGE_SMOKE_OK")
	quit(0 if failures == 0 else 1)


class RuntimeRoot:
	extends Node2D
	var difficulty_profile := {"tier": 1}


class Cooldown:
	extends RefCounted
	var cooldown_remaining := 0.0


class Target:
	extends Node2D
	var current_health := 100.0
	var max_health := 100.0
	var current_temporary_health := 0.0
	var gunner_magic_eye_ability := Cooldown.new()
	func take_damage(amount: float) -> void:
		current_health = maxf(0, current_health - amount)

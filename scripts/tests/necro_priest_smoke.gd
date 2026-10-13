extends SceneTree

const PRIEST := preload("res://scripts/enemies/enemy_necro_priest.gd")
const MARK := preload("res://scripts/player/player_necro_mark.gd")
const DB := preload("res://scripts/enemy/enemy_archetype_database.gd")
const RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		push_error(text)

func _run() -> void:
	var arena := Arena.new()
	root.add_child(arena)
	current_scene = arena
	var player = preload("res://scenes/player.tscn").instantiate()
	arena.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.fire_timer.stop()
	player.auto_attack_enabled = false
	var enemy = make_enemy(arena, player, "necro_priest")
	check(enemy.max_health == 80 and enemy.attack == 0 and enemy.armor == 5 and enemy.speed == 0, "priest base stats")
	check(is_equal_approx(enemy.damage_reduction_rate, 0.2) and is_equal_approx(enemy.status_resistance, 0.2), "priest reduction and resistance")
	for source in ["swordsman_basic:1", "gunner_basic:1", "mage_basic:1", "mechanic_basic:1", "swordsman_aux:split", "swordsman_aux:ground", "gunner_aux:split"]:
		var before: float = enemy.current_health
		RESOLVER.deal_damage_to_enemy(player, enemy, 100, source)
		check(enemy.current_health == before, "virtual spirit immune " + source)
	enemy.current_health = 80
	var queue := preload("res://scripts/player/player_damage_job_queue.gd").new()
	queue.source_player = player
	queue._deal_batched_damage_to_enemy(enemy, 100, "mage_basic:queued", 0, 2, 1, 0, null, 0, false)
	check(enemy.current_health == 80, "batched ordinary attack respects virtual spirit")
	RESOLVER.deal_damage_to_enemy(player, enemy, 10, "mage")
	check(enemy.current_health < 80, "active spell still damages priest")
	enemy.current_health = 40
	var other = make_enemy(arena, player, "chaser")
	other.current_health = 10
	enemy.necro_priest_state.prayer_cooldown = 0
	PRIEST.update(enemy, 0)
	check(is_equal_approx(enemy.current_health, 52) and is_equal_approx(other.current_health, 16), "prayer heals thirty percent missing HP including self")
	player.position = Vector2(250, 0)
	enemy.necro_priest_state.mark_cooldown = 0
	PRIEST.update(enemy, 0)
	check(is_equal_approx(MARK.remaining(player), 4.5), "mark250 range and swordsman resistance")
	player.current_health = 100
	player.current_temporary_health = 30
	player.gunner_flash_stacks = 3
	player.gunner_flash_stack_elapsed = 1.0
	player.gunner_flash_cooldown_remaining = 0.0
	player._heal(20)
	check(player.current_health == 80 and player.current_temporary_health == 30, "heal becomes direct HP loss bypassing temporary HP")
	check(player.gunner_flash_stacks == 3 and player.gunner_flash_stack_elapsed == 1 and player.gunner_flash_cooldown_remaining == 0, "healing reversal preserves actual gunner passive Buff")
	MARK.apply(player)
	check(is_equal_approx(MARK.remaining(player), 4.5), "marks refresh without stacking")
	MARK.tick(player, 5)
	player._heal(10)
	check(player.current_health == 90, "healing restores after mark expires")
	var data: Dictionary = enemy.get_save_data()
	var restored = make_enemy(arena, player, "necro_priest")
	restored.apply_save_data(data, player)
	check(restored.necro_priest_state == enemy.necro_priest_state, "priest cooldown save restore")
	check(PRIEST.living(arena).size() == 2, "priest count")
	enemy.position = Vector2(-880, 0)
	restored.position = Vector2(880, 0)
	check(PRIEST.spawn_position(arena).x == 880, "spawn selects opposite side")
	player.current_health = 5
	MARK.apply(player)
	player._heal(10)
	check(player.current_health == 0 and player.is_dead, "healing reversal can kill")
	queue.free()
	arena.free()
	current_scene = null
	if failures == 0:
		print("NECRO_PRIEST_SMOKE_OK")
	quit(0 if failures == 0 else 1)

func make_enemy(arena, player, id: String):
	var enemy = preload("res://scenes/enemy.tscn").instantiate()
	enemy.target = player
	enemy.apply_enemy_profile("normal", DB.get_profile("normal", id))
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

class Arena:
	extends Node2D
	var map_bounds := Rect2(-1000, -700, 2000, 1400)

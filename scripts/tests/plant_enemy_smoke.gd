extends SceneTree

const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const PLANTS := preload("res://scripts/enemies/enemy_plant_behavior.gd")
const ROOT := preload("res://scripts/player/player_vine_entangle.gd")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var player = preload("res://scenes/player.tscn").instantiate()
	scene.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.fire_timer.stop()
	player.auto_attack_enabled = false
	player._get_active_role()["base_dodge"] = 0.0
	var vine = make_enemy(scene, player, "vine")
	check(vine.max_health == 50 and vine.attack == 10 and vine.armor == 5 and vine.speed == 70, "vine template")
	check(vine.try_stalwart_body_damage() == 15, "vine contact coefficient")
	preload("res://scripts/player/player_survival_flow.gd").take_damage(player, 15, vine)
	check(is_equal_approx(ROOT.get_remaining(player), 1.35), "contact roots with status resistance")
	check(preload("res://scripts/player/player_survival_flow.gd").is_movement_locked(player), "root prevents moving")
	check(not player._is_player_action_locked(), "root does not prohibit attacks or casts")
	var before: float = player.current_health
	ROOT.tick(player, 0.5)
	check(player.current_health < before and is_equal_approx(ROOT.get_remaining(player), 0.85), "periodic damage does not refresh root")
	ROOT.tick(player, 0.85)
	check(ROOT.get_remaining(player) == 0, "root expires")
	player.position = Vector2(1000, 0)
	var parasite = PLANTS.throw_parasite_seed(vine)
	parasite.set_physics_process(false)
	parasite._physics_process(1)
	check(parasite.position.is_equal_approx(Vector2(180, 0)), "parasite travels at180")
	parasite._physics_process(1)
	check(parasite.position.is_equal_approx(Vector2(350, 0)) and parasite.landed and parasite.fuse == 2, "parasite fuse starts on landing")
	parasite._physics_process(1.9)
	check(not parasite.exploded, "parasite waits full two seconds")
	var parasite_saved: Dictionary = JSON.parse_string(JSON.stringify(parasite.get_save_data()))
	var parasite_restored := preload("res://scripts/enemies/parasite_seed.gd").new()
	scene.add_child(parasite_restored)
	parasite_restored.set_physics_process(false)
	parasite_restored.apply_save_data(parasite_saved, player)
	player.position = Vector2(350, 0)
	before = player.current_health
	parasite_restored._physics_process(0.11)
	check(parasite_restored.exploded and player.current_health < before, "saved parasite explodes and deals area damage")
	check(ROOT.get_remaining(player) > 0, "parasite actual damage applies entangle")
	var tree = make_enemy(scene, player, "shadow_tree")
	check(tree.max_health == 100 and tree.attack == 15 and tree.armor == 5 and tree.speed == 60, "tree template")
	player.position = Vector2(1000, 0)
	var seed = PLANTS.throw_tree_seed(tree)
	seed.set_physics_process(false)
	check(seed.max_health == 60 and seed.armor == 10, "seed has destroyable HP and armor")
	check(seed.try_stalwart_body_damage() == 0, "seed has no contact passive")
	PLANTS.update_tree_seed(seed, 1)
	check(seed.position.is_equal_approx(Vector2(180, 0)), "seed speed180")
	PLANTS.update_tree_seed(seed, 2)
	check(seed.position.is_equal_approx(Vector2(400, 0)) and seed.plant_state.landed, "seed lands at400")
	PLANTS.update_tree_seed(seed, 1.9)
	check(seed.archetype_id == "tree_seed", "hatch waits two seconds after landing")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(seed.get_save_data()))
	var restored = make_enemy(scene, player, "tree_seed")
	restored.apply_save_data(saved, player)
	check(restored.plant_state.landed and is_equal_approx(restored.plant_state.land_remaining, 0.1), "save preserves landed hatch timer")
	PLANTS.update_tree_seed(restored, 0.11)
	check(restored.archetype_id == "shadow_tree_young", "hatch creates young tree")
	check(restored.max_health == 50 and restored.attack == 20 and restored.speed == 100 and restored.armor == 0, "young tree template")
	var hit_seed = PLANTS.throw_tree_seed(tree)
	hit_seed.set_physics_process(false)
	player.position = Vector2(90, 0)
	before = player.current_health
	PLANTS.update_tree_seed(hit_seed, 0.6)
	check(hit_seed.is_queued_for_deletion() and player.current_health < before, "flight collision deals damage and removes seed")
	var destroyed = PLANTS.throw_tree_seed(tree)
	destroyed.set_physics_process(false)
	preload("res://scripts/enemies/enemy_damage.gd").apply_damage(destroyed, 10000, false)
	check(destroyed.is_queued_for_deletion(), "player can destroy seed before hatching")
	scene.free()
	current_scene = null
	if failures == 0:
		print("PLANT_ENEMY_SMOKE_OK")
	quit(0 if failures == 0 else 1)


func make_enemy(scene: Node, player: Node2D, archetype: String):
	var enemy = ENEMY.instantiate()
	enemy.target = player
	enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", archetype))
	scene.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

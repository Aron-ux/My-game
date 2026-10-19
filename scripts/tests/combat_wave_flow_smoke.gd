extends SceneTree

const FLOW := preload("res://scripts/game/combat_wave_flow.gd")
const PLAN := preload("res://scripts/game/combat_wave_plan.gd")
const PLAYER := preload("res://scenes/player.tscn")
const ENEMY := preload("res://scenes/enemy.tscn")
const PLANTS := preload("res://scripts/enemies/enemy_plant_behavior.gd")
const FLYBY := preload("res://scripts/enemies/enemy_swarm_flyby.gd")
const GEM := preload("res://scripts/exp_gem.gd")
const COOLDOWNS := preload("res://scripts/player/player_skill_cooldown_flow.gd")
var failures: Array[String] = []
var capture: bool = false

class TestMain:
	extends "res://scripts/main.gd"
	var saved: Dictionary = {}
	var defeat_count: int = 0
	func _ready() -> void:
		pass
	func _is_developer_mode() -> bool:
		return false
	func _save_run_state() -> void:
		if is_instance_valid(wave_flow):
			saved = wave_flow.get_save_data()
	func _refresh_hud() -> void:
		pass
	func _on_enemy_defeated(_kind: String, enemy: Node2D) -> void:
		defeat_count += 1
		if is_instance_valid(wave_flow):
			wave_flow.boss_defeated(enemy)
	func _exit_tree() -> void:
		pass
	func _notification(_what: int) -> void:
		pass

func _init() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _clear_enemies(main) -> void:
	for enemy in main.get_runtime_enemies().duplicate():
		if is_instance_valid(enemy):
			enemy.free()

static func finish_ending(flow) -> void:
	# Drive the real gem motion and ending state without waiting in wall time.
	for index in range(1800):
		if flow.phase not in ["clearing", "collecting", "settling"]:
			return
		for gem in flow.main.get_runtime_pickups("exp_gems").duplicate():
			if is_instance_valid(gem) and not gem.pooled:
				gem._run_physics_tick(1.0 / 60.0)
		flow.tick(1.0 / 60.0)
	push_error("Wave ending failed to finish")

func capture_frame(filename: String) -> void:
	if not capture or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/combat-waves")
	root.get_texture().get_image().save_png("res://artifacts/combat-waves/" + filename)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var main := TestMain.new()
	root.add_child(main)
	current_scene = main
	main.set_process(false)
	main.set_physics_process(false)
	main.player = PLAYER.instantiate()
	main.add_child(main.player)
	main.player.configure_story_loadout(["swordsman", "gunner", "mage"])
	main.player.set_process(false)
	main.player.set_physics_process(false)
	if capture:
		var camera := Camera2D.new()
		main.add_child(camera)
	main.rng.seed = 1234
	main._setup_spawn_timer()
	FLOW.setup(main)
	var flow = main.wave_flow
	check(main.spawn_timer.is_stopped(), "Wave mode must stop the old continuous spawn timer")
	check(PLAN.POOLS.size() == 20 and PLAN.DURATIONS.size() == 20, "Plan must contain 20 waves")
	check(int(PLAN.limits(19)["middle"]) == 18 and int(PLAN.limits(19)["high"]) == 5, "Late-wave caps must match approved increased limits")
	for pool in PLAN.POOLS:
		check("swarm" not in pool, "Fly-eyes must never enter the regular spawn pool")

	flow.tick(1.0)
	var batch = main.get_node("SpawnWarningBatch")
	batch.set_process(false)
	batch._process(1.0)
	main._process_pending_enemy_spawns()
	check(flow.living_enemies().size() > 0, "The opening wave must actually spawn")
	for enemy in flow.living_enemies():
		check(str(enemy.archetype_id) == "chaser", "Wave one may only spawn mushrooms")
		enemy.set_physics_process(false)
	var survivor = flow.living_enemies()[0]
	var elite = main.ENEMY_SPAWN_FLOW.spawn_special_enemy_with_archetype(main, "elite", "elite_ram_trail")
	elite.set_physics_process(false)
	if capture:
		survivor.global_position = main.player.global_position + Vector2(80, -35)
		elite.global_position = main.player.global_position + Vector2(-120, -60)
		for index in range(24):
			var visible_gem = main.exp_gem_scene.instantiate()
			main.add_child(visible_gem)
			visible_gem.configure(1, 1, 1.0)
			visible_gem.global_position = main.player.global_position + Vector2.RIGHT.rotated(index * TAU / 24.0) * (250.0 + (index % 3) * 50.0)
	var drops_before := {}
	var distant_gem := GEM.new()
	main.add_child(distant_gem)
	distant_gem.configure(1, 100, 1.0)
	distant_gem.global_position = Vector2(10000, 10000)
	var xp_before: int = main.player.experience
	for group in ["exp_gems", "heart_pickups", "bone_pickups", "experience_vacuum_pickups"]:
		drops_before[group] = get_nodes_in_group(group).size()
	var defeats_before: int = main.defeat_count
	flow.elapsed = 59.9
	flow.tick(0.2)
	check(flow.phase == "clearing" and not flow.blessing_pending, "Timeout must start visible cleanup before offering rewards")
	check(is_instance_valid(survivor) and survivor.visible and survivor.current_health == 0 and not survivor.pooled_inactive, "Cleanup must leave a visible dying enemy")
	check(not distant_gem.attraction_active, "Distant gems must wait for death animation")
	flow.tick(FLOW.DEATH_SECONDS * 0.5)
	check(survivor.modulate.a < 1.0 and survivor.modulate.a > 0.0, "Dying enemies must visibly fade over time")
	check(not survivor.take_damage(1000), "Cleanup animation must reject damage and produce no kill rewards")
	survivor.batch_physics_process(0.1)
	check(survivor.current_health == 0 and not survivor.pooled_inactive, "Batch simulation must not restart dying enemies")
	var corpse_snapshot := {"enemies": []}
	preload("res://scripts/game/run_save_runtime_flow.gd").append_group_save_data(main, corpse_snapshot, "enemies", "enemies")
	check(corpse_snapshot.enemies.is_empty(), "Cleanup corpses must not be saved as living monsters")
	await capture_frame("wave-ending-death.png")
	var cleanup_save: Dictionary = flow.get_save_data()
	flow.apply_save_data(cleanup_save)
	check(flow.phase == "clearing", "Continue must preserve the ending stage")
	if capture:
		flow.tick(FLOW.DEATH_SECONDS)
		for gem in main.get_runtime_pickups("exp_gems").duplicate():
			gem._run_physics_tick(0.1)
		await capture_frame("wave-ending-experience.png")
	finish_ending(flow)
	await process_frame
	check(flow.phase == "preparation", "Combat timeout must begin preparation")
	check(flow.blessing_pending and flow.blessing_offer.get("options", []).size() == 3, "Wave end must queue three free blessing choices")
	flow.finish_wave_blessing()
	check(is_instance_valid(survivor) and survivor.pooled_inactive, "Wave transition must recycle leftover normal enemies")
	check(not is_instance_valid(elite), "Wave transition must remove leftover elite enemies")
	check(flow.living_enemies().is_empty(), "Preparation must start with no remaining living enemies")
	check(main.defeat_count == defeats_before, "Automatic wave cleanup must not count as kills")
	for group in drops_before:
		var expected := 0 if group == "exp_gems" else int(drops_before[group])
		check(get_nodes_in_group(group).size() == expected, "Wave end must collect existing XP without dropping new rewards: " + group)
	check(main.player.level > 1 or main.player.experience > xp_before, "Distant wave XP must reach the player")
	check(flow._absorb_all_experience() == 0, "Wave experience must not be awarded twice")
	check(is_instance_valid(flow.merchant), "Preparation must spawn Ruan")
	check(batch.warnings.is_empty() and batch.pending_finished_entries.is_empty(), "Preparation must remove obsolete spawn warnings")
	check(not flow.accept_spawn({"wave_token": flow.token - 1, "archetype": "chaser"}), "Previous wave queued spawns must be discarded")
	var prep_snapshot: Dictionary = flow.get_save_data()
	flow.tick(2.0)
	check(flow.remaining < 30 and not paused, "Preparation must count down while the world runs")
	flow.apply_save_data(prep_snapshot)
	main.player.global_position = flow.merchant.global_position
	var before := {}
	for role in main.player.roles:
		var id: String = str(role["id"])
		var maximum: float = main.player._get_role_max_health(id)
		before[id] = maximum * 0.4
		main.player.role_health_values[id] = maximum * 0.4
	main.player.current_health = before[str(main.player._get_active_role()["id"])]
	flow.claim_first_aid()
	for role in main.player.roles:
		var id: String = str(role["id"])
		check(is_equal_approx(main.player._get_role_current_health(id), main.player._get_role_max_health(id) * 0.7), "First aid must restore half of each role's missing HP: " + id)
	var healed: float = main.player.current_health
	flow.claim_first_aid()
	check(is_equal_approx(main.player.current_health, healed), "First aid may be claimed only once")
	var claimed_save: Dictionary = flow.get_save_data()
	flow.apply_save_data(claimed_save)
	check(flow.claimed, "Loading preparation must not restore the claimed card")
	for role in main.player.roles:
		for property_name in COOLDOWNS._get_role_skill_property_names(str(role.id)):
			main.player.get(property_name).cooldown_remaining = 45.0
	flow.skip_preparation()
	for role in main.player.roles:
		for property_name in COOLDOWNS._get_role_skill_property_names(str(role.id)):
			check(is_equal_approx(main.player.get(property_name).cooldown_remaining, 0.2), "All team skills must reset on skip: " + property_name)
	check(flow.wave == 2 and flow.phase == "combat", "Skip must immediately start the next wave")
	flow.begin_preparation()
	finish_ending(flow)
	flow.finish_wave_blessing()
	flow.merchant.take_damage(1000)
	check(flow.merchant_health == 0, "Ruan must be killable")
	flow.claim_first_aid()
	check(not flow.claimed, "Dead Ruan cannot give first aid")
	var dead_save: Dictionary = flow.get_save_data()
	flow.apply_save_data(dead_save)
	check(not is_instance_valid(flow.merchant), "Loading must not revive Ruan in the same preparation")
	flow.remaining = 0.01
	main.player.swordsman_blade_storm_ability.cooldown_remaining = 25.0
	flow.tick(0.1)
	check(flow.wave == 3 and flow.phase == "combat", "Preparation timeout must start next wave")
	check(is_equal_approx(main.player.swordsman_blade_storm_ability.cooldown_remaining, 0.2), "Natural preparation expiry must also reset skills")

	_clear_enemies(main)
	flow.wave = 6
	flow.elapsed = 0
	flow.boss_started = false
	flow.tick(0.1)
	check(str(main.small_boss_enemy.archetype_id) == "smallboss_glutton", "Wave six must spawn Glutton")
	check(main.small_boss_enemy.experience_reward == int(PLAN.SMALL_BOSS_EXPERIENCE[6]), "Wave six boss must use its wave XP reward")
	var tree_count := 0
	for enemy in flow.living_enemies():
		enemy.set_physics_process(false)
		if enemy.archetype_id == "shadow_tree":
			tree_count += 1
	check(tree_count == 2, "Glutton must start with two adult trees")
	check(not flow.can_spawn("chaser"), "Glutton's regular pool must only include shadow trees")
	for index in range(24):
		flow.tick(PLAN.TREE_ESCORT_INTERVAL)
		batch._process(1.0)
		main._process_pending_enemy_spawns()
		for enemy in flow.living_enemies():
			enemy.set_physics_process(false)
	tree_count = 0
	for enemy in flow.living_enemies():
		if enemy.archetype_id == "shadow_tree":
			tree_count += 1
	check(tree_count == 20, "Wave six must gradually reach twenty adult trees")
	check(not flow.can_spawn("shadow_tree"), "Escort spawning must stop at twenty living adults")
	var removed_tree
	for enemy in flow.living_enemies():
		if enemy.archetype_id == "shadow_tree":
			removed_tree = enemy
			break
	removed_tree.free()
	flow.tick(PLAN.TREE_ESCORT_INTERVAL)
	batch._process(1.0)
	main._process_pending_enemy_spawns()
	tree_count = 0
	for enemy in flow.living_enemies():
		enemy.set_physics_process(false)
		if enemy.archetype_id == "shadow_tree":
			tree_count += 1
	check(tree_count == 20, "Killed escorts must be replenished back to twenty")
	check(flow.phase == "combat", "Boss waves cannot end on a time limit")
	var adult
	for enemy in flow.living_enemies():
		if enemy.archetype_id == "shadow_tree":
			adult = enemy
			break
	for index in range(6):
		PLANTS.throw_tree_seed(adult)
	check(PLANTS.throw_tree_seed(adult) == null, "Seeds and young trees must share the six-unit cap")
	flow.boss_defeated(main.small_boss_enemy)
	finish_ending(flow)
	check(flow.phase == "preparation", "Defeating a wave boss must begin preparation")
	_clear_enemies(main)

	# Caps include earlier-wave survivors and pending warning reservations.
	flow.wave = 19
	flow.phase = "combat"
	for index in range(3):
		var high = main.ENEMY_SPAWN_FLOW.spawn_special_enemy_with_archetype(main, "normal", "vine")
		if high != null:
			high.set_physics_process(false)
	check(not flow.can_spawn("vine"), "Single-species high-tier cap must be enforced")
	flow.reservations = {"skull_mage": 2}
	check(not flow.can_spawn("angry_porcupine"), "Category caps must include warned/queued enemies")
	flow.reservations.clear()
	_clear_enemies(main)
	for boss_wave in [11, 16, 20]:
		flow.wave = boss_wave
		flow.phase = "combat"
		flow.elapsed = 0
		flow.boss_started = false
		flow.tick(0.1)
		var boss = main.boss_enemy if boss_wave == 20 else main.small_boss_enemy
		check(is_instance_valid(boss) and str(boss.archetype_id) == str(PLAN.BOSSES[boss_wave]), "Correct boss must spawn in wave %d" % boss_wave)
		if boss_wave < 20:
			check(boss.experience_reward == int(PLAN.SMALL_BOSS_EXPERIENCE[boss_wave]), "Small boss must use its wave XP reward")
		if boss_wave == 11:
			check(flow.reservations.is_empty(), "Rebirth escorts must not spawn immediately")
			check(not flow.can_spawn("chaser") and not flow.can_spawn("runner") and not flow.can_spawn("brute"), "Rebirth must exclude non-skeleton escorts")
			flow.tick(PLAN.SKULL_ESCORT_INTERVAL - 0.2)
			check(flow.reservations.is_empty(), "Rebirth escorts must wait three seconds")
			flow.tick(0.2)
			var reserved := 0
			for value in flow.reservations.values():
				reserved += int(value)
			check(reserved == 1, "Rebirth must warn only one escort per interval")
			for index in range(24):
				batch._process(1.0)
				main._process_pending_enemy_spawns()
				for enemy in flow.living_enemies():
					enemy.set_physics_process(false)
				flow.tick(PLAN.SKULL_ESCORT_INTERVAL)
			var escort_counts := {}
			for enemy in flow.living_enemies():
				if enemy == boss:
					continue
				var archetype := str(enemy.archetype_id)
				check(PLAN.SKULL_ESCORT_CAPS.has(archetype), "Rebirth may only naturally spawn skeleton escorts")
				escort_counts[archetype] = int(escort_counts.get(archetype, 0)) + 1
			for archetype in PLAN.SKULL_ESCORT_CAPS:
				check(int(escort_counts.get(archetype, 0)) == int(PLAN.SKULL_ESCORT_CAPS[archetype]), "Rebirth escort must reach its species cap: " + archetype)
				check(not flow.can_spawn(archetype), "Rebirth species cap must block excess escorts: " + archetype)
			for index in range(10):
				var soldier = main.ENEMY_SPAWN_FLOW.spawn_special_enemy_with_archetype(main, "normal", "dasher")
				soldier.set_physics_process(false)
			var removed_shooter
			for enemy in flow.living_enemies():
				if enemy.archetype_id == "shooter":
					removed_shooter = enemy
					break
			removed_shooter.free()
			check(flow.can_spawn("shooter"), "Death-domain soldiers must leave room for capped ranged escorts")
			flow.reservations = {"shooter": 1}
			check(not flow.can_spawn("shooter"), "Rebirth caps must include pending spawn warnings")
			flow.reservations.clear()
		var boss_save: Dictionary = flow.get_save_data()
		flow.apply_save_data(boss_save)
		flow.tick(0.1)
		var boss_count := 0
		for enemy in flow.living_enemies():
			enemy.set_physics_process(false)
			if enemy.has_meta("combat_wave_boss"):
				boss_count += 1
		check(boss_count == 1, "Restoring boss wave must not duplicate the boss")
		flow.boss_defeated(boss)
		finish_ending(flow)
		check(flow.phase == ("complete" if boss_wave == 20 else "preparation"), "Boss defeat must transition wave %d" % boss_wave)
		_clear_enemies(main)
	var flyer = ENEMY.instantiate()
	main.add_child(flyer)
	flyer.target = main.player
	flyer.set_physics_process(false)
	main.player.position = Vector2.ZERO
	flyer.position = Vector2(-100, 40)
	FLYBY.configure(flyer, Vector2.RIGHT)
	var initial_velocity: Vector2 = FLYBY.velocity(flyer, 0.1)
	check(absf(initial_velocity.angle()) <= deg_to_rad(2.51), "Flyby turning speed must be limited")
	flyer.position = Vector2(100, 0)
	FLYBY.velocity(flyer, 0.1)
	check(bool(flyer.get_meta("wave_flyby")["passed"]), "Flyby must stop tracking after passing")
	flyer.free()

	if capture and DisplayServer.get_name() != "headless":
		flow.wave = 7
		flow.begin_preparation()
		finish_ending(flow)
		main.player.position = flow.merchant.position - Vector2(70, 0)
		var camera := Camera2D.new()
		camera.position = Vector2.ZERO
		main.add_child(camera)
		flow.view.shop_open = true
		flow.view.refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts/combat-waves")
		root.get_texture().get_image().save_png("res://artifacts/combat-waves/preparation.png")
	for pooled_enemy in main.runtime_enemy_pool_nodes.values():
		if is_instance_valid(pooled_enemy):
			pooled_enemy.free()
	main.runtime_enemy_pool_nodes.clear()
	for pool in main.runtime_pickup_pool_nodes.values():
		for pickup in pool.values():
			if is_instance_valid(pickup):
				pickup.free()
	main.runtime_pickup_pool_nodes.clear()
	main.free()
	await process_frame
	if failures.is_empty():
		print("COMBAT_WAVE_FLOW_SMOKE_OK")
		quit(0)
	else:
		for message in failures:
			push_error(message)
		quit(1)

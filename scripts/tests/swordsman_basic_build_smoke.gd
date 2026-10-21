extends SceneTree

const BUILD := preload("res://scripts/player/player_swordsman_basic_build.gd")
const BASIC_RUNTIME := preload("res://scripts/player/player_swordsman_basic_runtime.gd")
const LEVELS := preload("res://scripts/player/player_skill_level_system.gd")
const CARDS := preload("res://scripts/player/player_build_system.gd")
const RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const GROUND := preload("res://scripts/player/swordsman_ground_crack.gd")
const PLAYER := preload("res://scenes/player.tscn")
const BULLET := preload("res://scenes/enemy_bullet.tscn")
const ENEMY := preload("res://scenes/enemy.tscn")
const SAVE := preload("res://scripts/game/run_save_runtime_flow.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	var scene := CombatScene.new()
	root.add_child(scene)
	current_scene = scene
	var player = PLAYER.instantiate()
	scene.add_child(player)
	scene.player = player
	player.set_physics_process(false)
	player.set_process(false)
	player.auto_attack_enabled = false
	player.fire_timer.stop()
	check(BUILD.level(player) == 0, "new run starts at LV0")
	var card := CARDS._make_skill_upgrade_option(player, "swordsman", 0, "swordsman_basic")
	check(int(card.get("skill_level_next", -1)) == 1, "LV0 has valid upgrade card")
	for lv in range(1, 10):
		LEVELS.add_skill_level(player, "swordsman", "swordsman_basic")
		check(BUILD.level(player) == lv, "exact level %d" % lv)
		if lv in [4, 8, 9]:
			var offer := LEVELS.build_talent_offer_for(player, "swordsman", "swordsman_basic")
			var slot := 1 if lv != 9 else 2
			var option: Dictionary = offer["options"][slot - 1]
			check(not LEVELS.apply_option_with_result(player, option["id"], offer).is_empty(), "stage choice applies")
			check(LEVELS.apply_option_with_result(player, option["id"], offer).is_empty(), "stale offer cannot apply again")
	check(BUILD.has_choice(player, "heavy") and BUILD.has_choice(player, "split") and BUILD.has_choice(player, "brave"), "all three choices retained")
	check(is_equal_approx(BUILD.damage_ratio(player), 2.85), "heavy brave coefficient = 285%")
	check(is_equal_approx(player._get_effective_attack_speed("swordsman"), 0.2), "heavy brave final speed = 0.2")
	check(not LEVELS.is_progress_upgradeable(player, "swordsman_basic"), "LV9 removes upgrade")
	var normalized := LEVELS.normalize_role_state("swordsman", player.role_special_states["swordsman"])
	check(normalized == LEVELS.normalize_role_state("swordsman", normalized), "normalization is idempotent")
	check(normalized["swordsman_basic_build"].size() == 3, "normalization retains branches")
	var migrated := LEVELS.normalize_role_state("swordsman", {"skill_levels": {"swordsman_basic": 10}})
	check(migrated["skill_levels"]["swordsman_basic"] == 9, "old ten upgrades migrate to LV9")
	check(is_zero_approx(BUILD.critical_bonus(player, "swordsman_aux:split")), "split excludes brave critical")
	check(is_zero_approx(BUILD.critical_damage_bonus(player, "swordsman_aux:ground")), "ground excludes brave critical")
	check(is_equal_approx(BASIC_RUNTIME.SPLIT_ANGLE_DEGREES, 150.0), "split cone uses 150 degrees")
	check(is_equal_approx(GROUND.BASE_RADIUS, 75.0), "ground radius base is 75")
	check(is_equal_approx(BUILD.critical_bonus(player, "swordsman_basic:test"), 0.3), "slash gets brave critical")
	check(is_equal_approx(BUILD.critical_damage_bonus(player, "swordsman_basic:test"), 0.5), "slash gets brave critical damage")
	await _check_runtime(scene, player)
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("SWORDSMAN_BASIC_BUILD_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_runtime(scene, player) -> void:
	var armored = ENEMY.instantiate()
	scene.add_child(armored)
	armored.set_physics_process(false)
	armored.current_health = 10000.0
	armored.armor = 100.0
	armored.damage_reduction_rate = 0.2
	armored.take_damage_ignoring_armor(100.0, false, false)
	check(is_equal_approx(armored.current_health, 9920.0), "split bypasses armor but retains DR")
	armored.armor = -100.0
	armored.take_damage_ignoring_armor(100.0, false, false)
	check(is_equal_approx(armored.current_health, 9840.0), "split bypasses negative armor too")
	armored.free()
	var near := Target.new()
	var far := Target.new()
	scene.add_child(near)
	scene.add_child(far)
	near.position = Vector2(50.0, 0.0)
	far.position = Vector2(95.0, 0.0)
	scene.enemies = [far, near]
	await physics_frame
	# The secondary cone is generated once per slash, not once per victim.
	var split_registry := {"swordsman_slash": true, "slash_direction": Vector2.RIGHT}
	RESOLVER.damage_enemies_in_oriented_rect_unique(player, Vector2(60.0, 0.0), Vector2.DOWN, 100.0, 180.0, 10.0, 0.0, 1.0, 0.0, split_registry, "swordsman_basic:split_test")
	var jobs: Node = scene.get_node("PlayerDamageJobQueue")
	var split_jobs := 0
	for index in range(jobs.source_role_ids.size()):
		if jobs.source_role_ids[index] == "swordsman_aux:split":
			split_jobs += 1
			check(is_equal_approx(jobs.damage_amounts[index], 5.0), "split damage is half the current slash")
	check(split_jobs == 2, "one cone hits two enemies without duplicate cones")
	var total_jobs: int = jobs.source_role_ids.size()
	RESOLVER.damage_enemies_in_oriented_rect_unique(player, Vector2(60.0, 0.0), Vector2.DOWN, 100.0, 180.0, 10.0, 0.0, 1.0, 0.0, split_registry, "swordsman_basic:split_test")
	check(jobs.source_role_ids.size() == total_jobs, "same slash followthrough does not reapply split")
	# One slash and its followthrough produce only one ground circle.
	player.role_special_states["swordsman"]["swordsman_basic_build"] = {"4": "heavy", "8": "ground", "9": "guard"}
	var inside = BULLET.instantiate()
	var outside = BULLET.instantiate()
	scene.add_child(inside)
	scene.add_child(outside)
	inside.reset_projectile({"position": Vector2(65.0, 0.0), "direction": Vector2.LEFT, "target": player})
	outside.reset_projectile({"position": Vector2(65.0, 500.0), "direction": Vector2.LEFT, "target": player})
	inside.set_physics_process(false)
	outside.set_physics_process(false)
	var registry := {"swordsman_slash": true, "slash_direction": Vector2.RIGHT}
	RESOLVER.damage_enemies_in_oriented_rect_unique(player, Vector2(60.0, 0.0), Vector2.DOWN, 100.0, 180.0, 10.0, 0.0, 1.0, 0.0, registry, "swordsman_basic:test")
	check(inside.reflected and not outside.reflected, "guard reflects only projectiles intersecting slash")
	inside.free()
	outside.free()
	var cracks := get_nodes_in_group("swordsman_ground_cracks")
	check(cracks.size() == 1, "one hit slash generates one circle")
	if cracks.size() > 0:
		check(cracks[0].position == near.position, "nearest hit target is primary")
		check(is_equal_approx(cracks[0].damage, 30.0), "ground has 300% current slash damage")
		check(is_equal_approx(cracks[0].radius, 125.0), "ground radius uses 75 plus half of the 100 length")
		var saved: Dictionary = cracks[0].get_save_data()
		cracks[0].free()
		SAVE.restore_swordsman_ground_cracks(scene, [saved])
	check(not GROUND.spawn(player, Vector2(100.0, 0.0), 10.0, 125.0), "overlapping pending ground rejected")
	check(GROUND.spawn(player, Vector2(125.0 * 2.0 + 100.0, 0.0), 10.0, 125.0), "nonoverlapping ground accepted")
	RESOLVER.damage_enemies_in_oriented_rect_unique(player, Vector2(60.0, 0.0), Vector2.DOWN, 100.0, 180.0, 10.0, 0.0, 1.0, 0.0, registry, "swordsman_basic:test")
	check(get_nodes_in_group("swordsman_ground_cracks").size() == 2, "followthrough cannot trigger secondary twice")
	for crack in get_nodes_in_group("swordsman_ground_cracks"):
		crack._physics_process(1.49)
		check(not crack.exploded, "ground waits 1.5 seconds")
		crack._physics_process(0.02)
		check(crack.exploded, "ground explodes after delay")
	var knockback_target := Target.new()
	scene.add_child(knockback_target)
	knockback_target.position = Vector2(60.0, 0.0)
	scene.enemies = [knockback_target]
	await physics_frame
	var knockback_registry := {"swordsman_slash": true, "slash_direction": Vector2.RIGHT}
	RESOLVER.damage_enemies_in_oriented_rect_unique(player, Vector2(60.0, 0.0), Vector2.DOWN, 100.0, 180.0, 10.0, 0.0, 1.0, 0.0, knockback_registry, "swordsman_basic:brave_test", 50.0)
	check(knockback_target.position.is_equal_approx(Vector2(110.0, 0.0)), "brave knockback follows slash direction")
	knockback_target.free()
	scene.enemies = [far, near]
	await process_frame
	# Test reflected first-contact ordering, save state and pool reuse.
	for style in ["straight", "danmaku", "quarter_sine"]:
		var bullet = BULLET.instantiate()
		scene.add_child(bullet)
		bullet.reset_projectile({"position": Vector2.ZERO, "direction": Vector2.LEFT, "speed": 100.0, "damage": 20.0, "target": player, "motion_mode": style, "split_after_time": 0.1, "source_enemy_kind": "boss", "source_enemy_instance_id": 99, "source_enemy_archetype": "boss_spellcore"})
		bullet.set_physics_process(false)
		bullet.incident_velocity = Vector2(-100.0, 0.0)
		var old_near := near.damage_taken
		var old_far := far.damage_taken
		check(bullet.reflect_from_slash(player, Vector2.RIGHT), style + " reflects")
		check(bullet.direction.is_equal_approx(Vector2.RIGHT), "specular direction")
		check(not bullet.reflect_from_slash(player, Vector2.RIGHT), "cannot reflect twice")
		check(not bullet.has_meta("source_enemy_instance_id"), "boss cleanup detached")
		var saved: Dictionary = bullet.get_save_data()
		bullet.apply_save_data(saved, player)
		check(bullet.reflected and is_equal_approx(bullet.damage, 40.0), "saved reflected projectile retains doubled damage")
		bullet._run_physics_tick(1.0)
		check(bullet.pooled, "reflected shot recycles on first enemy")
		check(is_equal_approx(near.damage_taken - old_near, 40.0), "reflection deals exactly 2x without player critical")
		check(is_equal_approx(far.damage_taken, old_far), "reflection hits closest enemy only")
		bullet.reset_projectile({"position": Vector2.ZERO, "direction": Vector2.LEFT, "target": player})
		check(not bullet.reflected, "pool reuse restores hostile state")
		bullet.free()
	var angled = BULLET.instantiate()
	scene.add_child(angled)
	angled.direction = Vector2(-1.0, 1.0).normalized()
	angled.speed = 100.0
	angled.reflect_from_slash(player, Vector2.RIGHT)
	check(angled.direction.is_equal_approx(Vector2(1.0, 1.0).normalized()), "reflection preserves tangential velocity")
	angled.free()

class CombatScene:
	extends Node2D
	var enemies: Array = []
	var player: Node2D
	func get_runtime_enemies() -> Array:
		return enemies

class Target:
	extends Node2D
	var current_health := 10000.0
	var max_health := 10000.0
	var contact_radius := 8.0
	var pooled_inactive := false
	var rebirth_timer := 0.0
	var enemy_kind := "normal"
	var damage_taken := 0.0
	func take_damage(amount: float, _critical: bool = false) -> bool:
		damage_taken += amount
		current_health -= amount
		return false
	func take_batched_damage(amount: float, critical: bool = false) -> bool:
		return take_damage(amount, critical)

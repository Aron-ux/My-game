extends SceneTree

const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const SKILLS := preload("res://scripts/enemies/enemy_glutton_skill_behavior.gd")
const GLUTTON := preload("res://scripts/enemies/enemy_glutton_behavior.gd")
const DAMAGE := preload("res://scripts/enemies/enemy_damage.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var player := PlayerStub.new()
	scene.add_child(player)
	var enemy = ENEMY.instantiate()
	scene.add_child(enemy)
	enemy.apply_enemy_profile("small_boss", DATABASE.get_profile("small_boss", "smallboss_glutton"))
	enemy.target = player
	enemy.set_physics_process(false)
	assert(is_equal_approx(enemy.attack, 50.0))
	assert(is_equal_approx(enemy.speed, 20.0))
	assert(is_equal_approx(enemy.armor, 30.0))
	assert(is_equal_approx(enemy.damage_reduction_rate, 0.1))
	assert(is_equal_approx(enemy.max_health, 2500.0))
	assert(is_equal_approx(enemy.try_stalwart_body_damage(), 75.0))
	var gem := GemStub.new()
	scene.add_child(gem)
	gem.add_to_group("exp_gems")
	GLUTTON.update(enemy, 0.99)
	assert(gem.collections == 0)
	GLUTTON.update(enemy, 0.01)
	assert(gem.collections == 1)
	gem.remove_from_group("exp_gems")
	assert(is_equal_approx(enemy.glutton_growth_carry, 0.9))
	var old_scale: Vector2 = enemy.scale
	GLUTTON._apply_glutton_growth(enemy, 1.0)
	assert(is_equal_approx(enemy.glutton_bonus_speed, 2.0))
	assert(enemy.scale.is_equal_approx(old_scale + Vector2.ONE * 0.005))
	GLUTTON._apply_glutton_growth(enemy, 100.0)
	assert(is_equal_approx(enemy.glutton_bonus_speed, 120.0))
	SKILLS.force_start_skill(enemy, SKILLS.SKILL_WAR_STOMP)
	assert(is_equal_approx(SKILLS.get_war_stomp_speed_multiplier(enemy), 1.1))
	assert(is_equal_approx(SKILLS.get_damage_taken_multiplier(enemy), 0.9))
	var before_health: float = enemy.current_health
	DAMAGE.apply_damage(enemy, 130.0, false)
	assert(is_equal_approx(before_health - enemy.current_health, 81.0))
	player.position = SKILLS.get_debug_stomp_shape(enemy).center
	SKILLS._tick_war_stomp(enemy, 2.0)
	assert(player.hits.is_empty())
	assert(SKILLS.should_hold_position_for_cast(enemy))
	SKILLS._tick_war_stomp(enemy, 1.0)
	assert(not SKILLS.should_hold_position_for_cast(enemy))
	assert(is_equal_approx(enemy.glutton_war_stomp_remaining, 6.0))
	# The obsolete collision field must not be a skill damage source.
	enemy.touch_damage = 999.0
	for _index in range(6):
		SKILLS._tick_war_stomp(enemy, 1.0)
	assert(player.hits.size() == 6)
	for hit in player.hits:
		assert(is_equal_approx(hit, 40.0))
	assert(is_equal_approx(enemy.glutton_war_stomp_cooldown_remaining, 16.0))
	assert(is_equal_approx(SKILLS.get_damage_taken_multiplier(enemy), 1.0))
	var shape := {"center": player.position, "horizontal_radius": 100.0, "vertical_radius": 100.0}
	player.hits.clear()
	SKILLS._resolve_skill_impact(enemy, SKILLS.SKILL_DEATH_TWINE, [shape])
	assert(is_equal_approx(player.locked, 2.0))
	SKILLS._tick_entangle_damage(enemy, 0.99)
	assert(player.hits.is_empty())
	SKILLS._tick_entangle_damage(enemy, 0.01)
	SKILLS._tick_entangle_damage(enemy, 2.0)
	assert(player.hits.size() == 2)
	assert(is_equal_approx(player.hits[0], 10.0))
	assert(is_equal_approx(player.hits[1], 10.0))
	# A late entry into residue must start the same damage-over-time effect.
	SKILLS._register_twine_hitbox(enemy, shape)
	SKILLS._resolve_twine_hitbox(enemy, enemy.glutton_active_twine_hitboxes.size() - 1)
	assert(is_equal_approx(enemy.glutton_entangle_damage_remaining, 2.0))
	player.hits.clear()
	enemy.attack = 100.0
	SKILLS._tick_entangle_damage(enemy, 1.0)
	assert(is_equal_approx(player.hits[0], 20.0))
	SKILLS._spawn_wood_spike(enemy, shape)
	assert(is_equal_approx(player.hits[1], 80.0))
	SKILLS._resolve_wood_spike_hitbox(enemy, enemy.glutton_active_wood_spike_hitboxes.size() - 1)
	assert(player.hits.size() == 2)
	SKILLS.reset(enemy)
	scene.free()
	current_scene = null
	print("ENEMY_GLUTTON_REWORK_SMOKE_OK")
	quit(0)


class PlayerStub:
	extends Node2D
	var hits: Array[float] = []
	var locked: float = 0.0

	func take_damage(amount: float) -> void:
		hits.append(amount)

	func _lock_player_actions(duration: float) -> void:
		locked = duration

	func _start_entangled_status(_duration: float) -> void:
		pass


class GemStub:
	extends Node2D
	var collections: int = 0

	func collect() -> int:
		collections += 1
		return 1

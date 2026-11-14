extends SceneTree

const SEPARATION := preload("res://scripts/enemies/enemy_body_separation.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	var scene := Runtime.new()
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var flyer = make_enemy(scene, "swarm")
	var other = make_enemy(scene, "chaser")
	other.position = Vector2(8, 0)
	var radius: float = SEPARATION.get_body_collision_radius(flyer)
	check(is_equal_approx(radius, 10.4625), "flying eye radius is half the current 20.925 radius")
	check(is_equal_approx(SEPARATION.get_body_collision_radius(other), 20.925), "ground enemy radius stays unchanged")
	check(SEPARATION.compute_separation_velocity(flyer).is_zero_approx(), "flying eye ignores ground enemy velocity separation")
	check(SEPARATION.compute_separation_velocity(other).is_zero_approx(), "ground enemy ignores flying eye velocity separation")
	SEPARATION.apply_body_collision_separation(flyer)
	SEPARATION.apply_body_collision_separation(other)
	check(flyer.position.is_zero_approx() and other.position == Vector2(8, 0), "mixed pair ignores direct separation in both directions")

	other.apply_enemy_profile("normal", DATABASE.get_profile("normal", "swarm"))
	check(SEPARATION.compute_separation_velocity(flyer).x < 0.0, "overlapping eyes still repel")
	check(SEPARATION.compute_separation_velocity(other).x > 0.0, "eye repulsion is symmetric")
	SEPARATION.apply_body_collision_separation(flyer)
	check(flyer.position.x < 0.0, "overlapping eyes still use direct separation")
	flyer.position = Vector2.ZERO
	other.position = Vector2(30, 0)
	check(SEPARATION.compute_separation_velocity(flyer).is_zero_approx(), "eyes fit closer than the former collision diameter")
	SEPARATION.apply_body_collision_separation(flyer)
	check(flyer.position.is_zero_approx(), "eyes outside the smaller radius do not move")

	flyer.apply_enemy_profile("normal", DATABASE.get_profile("normal", "chaser"))
	other.apply_enemy_profile("normal", DATABASE.get_profile("normal", "chaser"))
	other.position = Vector2(8, 0)
	check(SEPARATION.compute_separation_velocity(flyer).x < 0.0, "ground enemies retain mutual velocity separation after profile reuse")
	SEPARATION.apply_body_collision_separation(flyer)
	check(flyer.position.x < 0.0, "ground enemies retain direct separation")
	scene.free()
	current_scene = null
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("ENEMY_SWARM_COLLISION_SMOKE_OK")
	quit(0 if failures.is_empty() else 1)

func make_enemy(scene, archetype: String):
	var enemy = ENEMY.instantiate()
	scene.add_child(enemy)
	enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", archetype))
	scene.enemies.append(enemy)
	return enemy

class Runtime:
	extends Node2D
	var enemies: Array = []
	func get_runtime_enemies() -> Array:
		return enemies

extends SceneTree

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := RuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene

	var target := TargetStub.new()
	scene.add_child(target)

	var boss := ENEMY_SCENE.instantiate() as Node2D
	scene.add_child(boss)
	boss.enemy_kind = "boss"
	boss.target = target
	_attach_boss_runtime_nodes(boss)
	boss.boss_laser_remaining = 2.0
	boss.boss_orbit_bomb_remaining = 1.0
	boss.boss_orbit_pull_remaining = 4.0
	boss.boss_peacock_charge_remaining = 0.7

	var boss_projectile := ProjectileStub.new()
	boss_projectile.set_meta("source_enemy_instance_id", boss.get_instance_id())
	boss_projectile.set_meta("source_enemy_kind", "boss")
	scene.add_projectile(boss_projectile)

	var restored_boss_projectile := ProjectileStub.new()
	restored_boss_projectile.set_meta("source_enemy_kind", "boss")
	scene.add_projectile(restored_boss_projectile)

	var normal_projectile := ProjectileStub.new()
	normal_projectile.set_meta("source_enemy_instance_id", 987654321)
	normal_projectile.set_meta("source_enemy_kind", "normal")
	scene.add_projectile(normal_projectile)

	var player := PLAYER_SCENE.instantiate()
	if not player.has_method("_add_boss_damage_energy"):
		failures.append("player should expose the boss damage energy bridge")
	player.free()

	boss.clear_runtime_effects_after_defeat()
	if not boss_projectile.recycled:
		failures.append("boss projectile should be recycled when the boss is defeated")
	if not restored_boss_projectile.recycled:
		failures.append("restored boss projectile should be recycled when the boss is defeated")
	if normal_projectile.recycled:
		failures.append("non-boss projectile should not be recycled by boss cleanup")
	if boss.boss_laser_remaining != 0.0 or boss.boss_orbit_bomb_remaining != 0.0 or boss.boss_orbit_pull_remaining != 0.0 or boss.boss_peacock_charge_remaining != 0.0:
		failures.append("boss attack timers should be cleared on defeat")
	if target.orbit_pull_remaining != 0.0:
		failures.append("boss orbit pull status should be cleared on defeat")
	if boss.boss_orbit_ball != null or not boss.boss_peacock_markers.is_empty():
		failures.append("boss-owned persistent visuals should be cleared on defeat")

	scene.queue_free()
	await process_frame
	current_scene = null

	if failures.is_empty():
		print("BOSS_RUNTIME_CLEANUP_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _attach_boss_runtime_nodes(boss: Node2D) -> void:
	var laser := Line2D.new()
	laser.visible = true
	boss.add_child(laser)
	boss.boss_laser_lines.append(laser)

	var laser_core := Line2D.new()
	laser_core.visible = true
	boss.add_child(laser_core)
	boss.boss_laser_core_lines.append(laser_core)

	var ring := Line2D.new()
	ring.visible = true
	boss.add_child(ring)
	boss.boss_phase_charge_rings.append(ring)

	boss.boss_orbit_ball = Node2D.new()
	boss.add_child(boss.boss_orbit_ball)

	var marker := Polygon2D.new()
	boss.add_child(marker)
	boss.boss_peacock_markers.append(marker)


class ProjectileStub:
	extends Node2D

	var recycled: bool = false

	func recycle() -> void:
		recycled = true
		remove_from_group("enemy_projectiles")


class TargetStub:
	extends Node2D

	var orbit_pull_remaining: float = -1.0

	func _sync_orbit_pull_status(remaining: float, _pull_origin: Vector2) -> void:
		orbit_pull_remaining = remaining


class RuntimeRoot:
	extends Node2D

	var projectiles: Array = []

	func add_projectile(projectile: Node) -> void:
		projectiles.append(projectile)
		add_child(projectile)
		projectile.add_to_group("enemy_projectiles")

	func get_runtime_enemy_projectiles() -> Array:
		return projectiles

	func register_runtime_enemy(_enemy: Node) -> void:
		pass

	func unregister_runtime_enemy(_enemy: Node) -> void:
		pass
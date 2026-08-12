extends SceneTree

const SKULLTOMB_BEHAVIOR := preload("res://scripts/enemies/enemy_skulltomb_behavior.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_charge_roll_threshold()
	_test_death_ring_visual_points()
	_test_aging_aura_passive()
	await _test_charge_cooldown_after_active()
	await _test_charge_push_candidates()

	if failures.is_empty():
		print("SKULLTOMB_CHARGE_DECISION_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_charge_roll_threshold() -> void:
	if not SKULLTOMB_BEHAVIOR._should_start_charge(0.0):
		failures.append("charge roll should start below chance threshold")
	if SKULLTOMB_BEHAVIOR._should_start_charge(0.5):
		failures.append("charge roll should not start at chance threshold")
	if SKULLTOMB_BEHAVIOR._should_start_charge(1.0):
		failures.append("charge roll should not start above chance threshold")


func _test_death_ring_visual_points() -> void:
	var ring := Line2D.new()
	SKULLTOMB_BEHAVIOR._update_circle_points(ring, 120.0)
	if ring.points.size() != 36:
		failures.append("death ring visual should use reduced cached segment count")
	if ring.points.is_empty() or not is_equal_approx(ring.points[0].length(), 120.0):
		failures.append("death ring visual point radius should match requested radius")
	SKULLTOMB_BEHAVIOR._update_circle_points(ring, 240.0)
	if ring.points.size() != 36:
		failures.append("death ring visual should keep reduced segment count after reuse")
	if ring.points.is_empty() or not is_equal_approx(ring.points[0].length(), 240.0):
		failures.append("death ring visual point radius should update on reuse")
	ring.free()


func _test_aging_aura_passive() -> void:
	var target := TargetStub.new()
	target.global_position = Vector2(240.0, 0.0)

	var enemy := SkulltombStub.new()
	enemy.global_position = Vector2.ZERO
	enemy.target = target

	SKULLTOMB_BEHAVIOR._update_aging_aura(enemy, 0.5)
	if not is_equal_approx(target.current_health, 100.0):
		failures.append("aging aura should wait for one full second before draining health")
	SKULLTOMB_BEHAVIOR._update_aging_aura(enemy, 0.5)
	if not is_equal_approx(target.current_health, 95.0):
		failures.append("aging aura should drain 5 percent of current health each second inside radius")
	if not target.aging_applied:
		failures.append("aging aura should apply the player aging status for buff display")

	target.global_position = Vector2(360.0, 0.0)
	SKULLTOMB_BEHAVIOR._update_aging_aura(enemy, 1.0)
	if not is_equal_approx(target.current_health, 95.0):
		failures.append("aging aura should not drain outside the passive radius")

	target.free()
	enemy.free()


func _test_charge_cooldown_after_active() -> void:
	var scene := RuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene

	var target := Node2D.new()
	scene.add_child(target)

	var enemy := SkulltombStub.new()
	enemy.target = target
	enemy.skulltomb_charge_active = true
	enemy.skulltomb_charge_timer = 0.0
	enemy.skulltomb_charge_decision_timer = 0.0
	scene.add_child(enemy)

	SKULLTOMB_BEHAVIOR._update_charge(enemy, 0.2)

	if bool(enemy.skulltomb_charge_active):
		failures.append("finished charge should clear active lock")
	if not is_equal_approx(float(enemy.skulltomb_charge_timer), float(enemy.skulltomb_charge_interval)):
		failures.append("finished charge should start cooldown after skill ends")
	if not is_equal_approx(float(enemy.skulltomb_charge_decision_timer), 1.0):
		failures.append("finished charge should reset decision timer")

	scene.queue_free()
	await process_frame
	current_scene = null


func _test_charge_push_candidates() -> void:
	var scene := RuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene

	var enemy := SkulltombStub.new()
	enemy.global_position = Vector2.ZERO
	enemy.dash_direction = Vector2.RIGHT
	enemy.skulltomb_charge_distance = 120.0
	enemy.contact_radius = 36.0
	enemy.skulltomb_charge_push_distance = 116.0
	scene.add_child(enemy)

	var near_enemy := Node2D.new()
	near_enemy.global_position = Vector2(70.0, 10.0)
	scene.add_child(near_enemy)

	var outside_lateral := Node2D.new()
	outside_lateral.global_position = Vector2(70.0, 50.0)
	scene.add_child(outside_lateral)

	var distant_enemy := Node2D.new()
	distant_enemy.global_position = Vector2(500.0, 0.0)
	scene.add_child(distant_enemy)

	scene.runtime_enemies = [enemy, near_enemy, outside_lateral, distant_enemy]
	var candidates: Array = SKULLTOMB_BEHAVIOR._get_charge_candidates(scene, enemy, 120.0, 25.2)
	if not candidates.has(near_enemy):
		failures.append("charge grid candidates should include nearby path enemy")
	if candidates.has(distant_enemy):
		failures.append("charge grid candidates should exclude distant enemy")

	var near_before: Vector2 = near_enemy.global_position
	var outside_before: Vector2 = outside_lateral.global_position
	var distant_before: Vector2 = distant_enemy.global_position
	SKULLTOMB_BEHAVIOR._push_enemies_during_charge(enemy)
	if near_enemy.global_position.x <= near_before.x:
		failures.append("charge push should move enemy inside path")
	if outside_lateral.global_position != outside_before:
		failures.append("charge push should not move lateral enemy outside path")
	if distant_enemy.global_position != distant_before:
		failures.append("charge push should not move distant enemy")

	scene.queue_free()
	await process_frame
	current_scene = null


class RuntimeRoot:
	extends Node2D

	var runtime_enemies: Array = []

	func get_runtime_enemies() -> Array:
		return runtime_enemies


class SkulltombStub:
	extends Node2D

	var target: Node2D
	var dash_remaining: float = 0.0
	var dash_duration: float = 0.0
	var dash_direction: Vector2 = Vector2.RIGHT
	var dash_speed_multiplier: float = 1.0
	var dash_warning_rect: Polygon2D
	var speed: float = 80.0
	var contact_radius: float = 36.0
	var skulltomb_summon_windup_remaining: float = 0.0
	var skulltomb_charge_active: bool = false
	var skulltomb_charge_interval: float = 9.0
	var skulltomb_charge_timer: float = 0.0
	var skulltomb_charge_decision_timer: float = 0.0
	var skulltomb_charge_windup_duration: float = 2.0
	var skulltomb_charge_windup_remaining: float = 0.0
	var skulltomb_charge_distance: float = 120.0
	var skulltomb_charge_speed_multiplier: float = 2.0
	var skulltomb_charge_push_distance: float = 116.0
	var skulltomb_charge_target_position: Vector2 = Vector2.ZERO
	var skulltomb_aging_aura_elapsed: float = 0.0
	var _cached_direction_to_target: Vector2 = Vector2.RIGHT

	func _spawn_dash_trail(_direction: Vector2, _distance: float) -> void:
		pass

class TargetStub:
	extends Node2D

	signal health_changed(current_health: float, max_health: float)

	var max_health: float = 100.0
	var current_health: float = 100.0
	var is_dead: bool = false
	var aging_applied: bool = false

	func apply_aging(_duration: float) -> void:
		aging_applied = true

	func _save_active_role_health() -> void:
		pass
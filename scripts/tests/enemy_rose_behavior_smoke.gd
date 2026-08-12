extends SceneTree

const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const ENEMY_MOVEMENT := preload("res://scripts/enemies/enemy_movement.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := ENEMY_ARCHETYPE_DATABASE.get_profile("small_boss", "smallboss_turret")
	if str(profile.get("behavior", "")) != "rose":
		failures.append("smallboss_turret should use rose behavior")
	if str(profile.get("boss_name", "")) != "地瑰灵":
		failures.append("smallboss_turret should be named 地瑰灵")
	var visual_scene := profile.get("visual_scene", null) as PackedScene
	if visual_scene == null or visual_scene.resource_path != "res://assets/enemies/rose/rose.tscn":
		failures.append("smallboss_turret should use rose.tscn visual scene")
	var enemy := RoseEnemyStub.new()
	var velocity := ENEMY_MOVEMENT.compute_velocity(enemy, 0.016)
	if velocity != Vector2.ZERO:
		failures.append("rose enemy should never move")
	var boss := BossEnemyStub.new()
	var boss_velocity := ENEMY_MOVEMENT.compute_velocity(boss, 0.016)
	if boss_velocity.length() >= 30.0:
		failures.append("boss should slow orbit movement near preferred distance")
	if boss_velocity.y >= 25.0:
		failures.append("boss preferred-distance orbit should not keep moving downward at full speed")
	if failures.is_empty():
		print("ENEMY_ROSE_BEHAVIOR_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


class RoseEnemyStub:
	extends RefCounted

	var behavior_id := "rose"
	var secondary_behavior_id := ""
	var rebirth_timer := 0.0
	var speed := 100.0
	var slow_multiplier := 1.0
	var _is_boss := false
	var _is_turret := false
	var _is_shooter := false
	var _is_dasher := false
	var _is_accelerator := false
	var _is_glutton := false
	var _is_swarm := false
	var skull_soldier_speed_multiplier := 1.0
	var acceleration_remaining := 0.0
	var dash_windup_remaining := 0.0
	var dash_remaining := 0.0
	var dash_speed_multiplier := 1.0
	var dash_direction := Vector2.RIGHT
	var preferred_distance := 0.0
	var strafe_sign := 1.0
	var glutton_bonus_speed := 0.0
	var _cached_to_target := Vector2.RIGHT * 100.0
	var _cached_distance_to_target := 100.0
	var _cached_direction_to_target := Vector2.RIGHT


class BossEnemyStub:
	extends RefCounted

	var behavior_id := "boss"
	var secondary_behavior_id := ""
	var rebirth_timer := 0.0
	var speed := 100.0
	var slow_multiplier := 1.0
	var _is_boss := true
	var _is_turret := false
	var _is_shooter := false
	var _is_dasher := false
	var _is_accelerator := false
	var _is_glutton := false
	var _is_swarm := false
	var preferred_distance := 230.0
	var boss_phase_transition_target := 0
	var boss_orbit_sign := 1.0
	var boss_pattern_rotation := 0.0
	var _cached_to_target := Vector2.RIGHT * 230.0
	var _cached_distance_to_target := 230.0
	var _cached_direction_to_target := Vector2.RIGHT

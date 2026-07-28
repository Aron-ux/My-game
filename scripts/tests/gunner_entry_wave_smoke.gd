extends SceneTree

const PlayerSwitchEntryFlow := preload("res://scripts/player/player_switch_entry_flow.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := GunnerEntryOwner.new()
	PlayerSwitchEntryFlow.fire_gunner_entry_wave(owner, "gunner", 0, 1.0)
	if owner.radius_damage_calls != 0:
		failures.append("gunner entry wave should not apply instant radius damage")
	if owner.spawned_projectiles.size() != 8:
		failures.append("gunner entry wave should spawn 8 batched bullets, got %d" % owner.spawned_projectiles.size())
	for projectile in owner.spawned_projectiles:
		if not is_equal_approx(float(projectile.get("damage", 0.0)), 20.0):
			failures.append("gunner entry bullet damage should be role damage x2, got %.2f" % float(projectile.get("damage", 0.0)))
		if not is_equal_approx(float(projectile.get("hit_radius", 0.0)), 18.0):
			failures.append("gunner entry bullet hit radius should be 18, got %.2f" % float(projectile.get("hit_radius", 0.0)))
		if int(projectile.get("pierce_count", 0)) != 8:
			failures.append("gunner entry bullet should pierce along its path")
	if failures.is_empty():
		print("GUNNER_ENTRY_WAVE_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


class GunnerEntryOwner:
	extends Node2D

	var spawned_projectiles: Array[Dictionary] = []
	var radius_damage_calls: int = 0

	func _queue_camera_shake(_strength: float, _duration: float) -> void:
		pass

	func _get_role_damage(_role_id: String) -> float:
		return 10.0

	func _damage_enemies_in_radius(_center: Vector2, _radius: float, _damage_amount: float, _vulnerability_bonus: float, _slow_multiplier: float, _slow_duration: float, _source_role_id: String = "") -> int:
		radius_damage_calls += 1
		return 0

	func _schedule_repeating_sequence(_interval: float, _count: int, callback: Callable, _initial_delay: float = 0.0) -> void:
		callback.call(0)

	func _spawn_batched_directional_bullet_values(
		direction: Vector2,
		damage_amount: float,
		_color: Color,
		role_id: String = "",
		origin: Variant = null,
		speed: float = 620.0,
		lifetime: float = 1.0,
		hit_radius: float = 10.0,
		_visual_radius: float = 4.2,
		_visual_min_diameter: float = 8.0,
		_visual_outline_color: Color = Color(1.0, 1.0, 1.0, 0.0),
		_visual_outline_width: float = 0.0,
		enemy_hit_radius_scale: float = 0.2,
		enemy_hit_radius_min: float = 4.0,
		enemy_hit_radius_max: float = 12.0,
		_vulnerability_bonus: float = 0.0,
		_vulnerability_duration: float = 0.0,
		_slow_multiplier: float = 1.0,
		_slow_duration: float = 0.0,
		pierce_count: int = 0,
		_wave_amplitude: float = 0.0,
		_wave_frequency: float = 0.0,
		_wave_phase: float = 0.0
	) -> bool:
		spawned_projectiles.append({
			"direction": direction,
			"damage": damage_amount,
			"role_id": role_id,
			"origin": origin,
			"speed": speed,
			"lifetime": lifetime,
			"hit_radius": hit_radius,
			"enemy_hit_radius_scale": enemy_hit_radius_scale,
			"enemy_hit_radius_min": enemy_hit_radius_min,
			"enemy_hit_radius_max": enemy_hit_radius_max,
			"pierce_count": pierce_count
		})
		return true

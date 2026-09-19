extends RefCounted

const PROJECTILES := preload("res://scripts/enemies/enemy_projectiles.gd")
const BASIC_PROFILE := preload("res://data/enemies/shooter.tres")


static func get_basic_interval() -> float:
	return float(BASIC_PROFILE.extra["shot_interval"])


static func update(enemy, delta: float, basic_interval: float) -> void:
	var frequency: float = maxf(0.01, enemy.skullshot_attack_frequency_multiplier)
	enemy.basic_shot_timer -= delta
	if enemy.basic_shot_timer <= 0.0:
		enemy.basic_shot_timer += maxf(0.18, basic_interval / frequency)
		fire_basic(enemy)
	enemy.shot_timer -= delta
	if enemy.shot_timer <= 0.0:
		# This skill's 15s cooldown is already in game seconds.
		enemy.shot_timer += maxf(0.18, enemy.shot_interval / frequency)
		PROJECTILES.fire_shooter_pattern(enemy)


static func fire_basic(enemy) -> void:
	if enemy.target == null or not is_instance_valid(enemy.target):
		return
	var direction: Vector2 = enemy._cached_direction_to_target
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var origin: Vector2 = enemy.global_position + direction * (22.0 + enemy.scale.x * 4.0)
	PROJECTILES.spawn_projectile(
		enemy, origin, direction,
		float(BASIC_PROFILE.extra["projectile_speed"]), enemy.attack,
		float(BASIC_PROFILE.extra["projectile_lifetime"]),
		BASIC_PROFILE.extra["projectile_color"], "straight",
		{"visual_style": BASIC_PROFILE.extra["projectile_visual_style"]}
	)

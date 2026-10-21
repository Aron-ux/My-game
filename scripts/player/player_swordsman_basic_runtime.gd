extends RefCounted

const BUILD := preload("res://scripts/player/player_swordsman_basic_build.gd")
const GROUND := preload("res://scripts/player/swordsman_ground_crack.gd")
const SPLIT_ANGLE_DEGREES := 150.0

static func on_slash_hit(player, position: Vector2, direction: Vector2, amount: float, attack_length: float) -> void:
	var split_radius: float = 100.0 + maxf(0.0, attack_length) * 0.5
	if BUILD.has_choice(player, "split"):
		player._spawn_cone_effect(position, direction, split_radius, SPLIT_ANGLE_DEGREES, Color(1.0, 0.74, 0.35, 0.55), 0.18)
		player._damage_enemies_in_cone(position, direction, split_radius, deg_to_rad(SPLIT_ANGLE_DEGREES), amount * 0.5, 0.0, 1.0, 0.0, "swordsman_aux:split")
	elif BUILD.has_choice(player, "ground"):
		GROUND.spawn(player, position, amount * 3.0, 75.0 + maxf(0.0, attack_length) * 0.5)

static func reflect_slash(player, center: Vector2, axis: Vector2, length: float, width: float, normal: Vector2) -> void:
	if not BUILD.has_choice(player, "guard"):
		return
	for bullet in player.get_tree().get_nodes_in_group("enemy_projectiles"):
		if not is_instance_valid(bullet) or not bullet.has_method("reflect_from_slash") or bullet.pooled or bullet.reflected:
			continue
		var offset: Vector2 = bullet.global_position - center
		var closest := Vector2(clampf(offset.dot(axis), -length * 0.5, length * 0.5), clampf(offset.dot(axis.orthogonal()), -width * 0.5, width * 0.5))
		var local := Vector2(offset.dot(axis), offset.dot(axis.orthogonal()))
		if local.distance_squared_to(closest) <= bullet.hit_radius * bullet.hit_radius:
			bullet.reflect_from_slash(player, normal)

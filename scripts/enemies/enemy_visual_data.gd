extends RefCounted

static func get_display_color(enemy_kind: String, archetype_id: String, color_override = null) -> Color:
	if color_override is Color:
		return color_override
	match enemy_kind:
		"boss":
			return Color(0.95, 0.2, 0.2, 1.0)
		"small_boss":
			return Color(0.84, 0.52, 1.0, 1.0)
		"elite":
			return Color(1.0, 0.58, 0.25, 1.0)
		_:
			return get_normal_display_color(archetype_id)

static func get_normal_display_color(archetype_id: String) -> Color:
	match archetype_id:
		"shooter":
			return Color(1.0, 0.52, 0.3, 1.0)
		"brute":
			return Color(0.92, 0.76, 0.24, 1.0)
		"runner":
			return Color(0.72, 0.96, 1.0, 1.0)
		"swarm":
			return Color(0.78, 0.94, 1.0, 1.0)
		"dasher":
			return Color(1.0, 0.34, 0.42, 1.0)
		"shotgunner":
			return Color(1.0, 0.7, 0.24, 1.0)
		_:
			return Color(0.34, 0.8, 1.0, 1.0)

static func get_projectile_color(archetype_id: String) -> Color:
	match archetype_id:
		"shooter":
			return Color(0.98, 0.56, 0.32, 1.0)
		"brute":
			return Color(1.0, 0.78, 0.38, 1.0)
		"shotgunner", "elite_splitshot":
			return Color(1.0, 0.78, 0.26, 1.0)
		"dasher":
			return Color(1.0, 0.42, 0.42, 1.0)
		"smallboss_turret":
			return Color(1.0, 0.36, 0.18, 1.0)
		_:
			return Color(0.95, 0.45, 0.35, 1.0)

static func get_shape_points(behavior_id: String) -> PackedVector2Array:
	match behavior_id:
		"shooter":
			return PackedVector2Array([
				Vector2(0.0, -18.0),
				Vector2(16.0, 0.0),
				Vector2(0.0, 18.0),
				Vector2(-16.0, 0.0)
			])
		"accelerator", "brute":
			return PackedVector2Array([
				Vector2(0.0, -18.0),
				Vector2(15.0, -9.0),
				Vector2(15.0, 9.0),
				Vector2(0.0, 18.0),
				Vector2(-15.0, 9.0),
				Vector2(-15.0, -9.0)
			])
		"turret":
			return PackedVector2Array([
				Vector2(0.0, -20.0),
				Vector2(18.0, -10.0),
				Vector2(20.0, 10.0),
				Vector2(0.0, 22.0),
				Vector2(-20.0, 10.0),
				Vector2(-18.0, -10.0)
			])
		"glutton":
			return PackedVector2Array([
				Vector2(0.0, -22.0),
				Vector2(20.0, -14.0),
				Vector2(24.0, 0.0),
				Vector2(20.0, 14.0),
				Vector2(0.0, 22.0),
				Vector2(-20.0, 14.0),
				Vector2(-24.0, 0.0),
				Vector2(-20.0, -14.0)
			])
		"rebirth":
			return PackedVector2Array([
				Vector2(0.0, -20.0),
				Vector2(18.0, -12.0),
				Vector2(22.0, 0.0),
				Vector2(18.0, 12.0),
				Vector2(0.0, 20.0),
				Vector2(-18.0, 12.0),
				Vector2(-22.0, 0.0),
				Vector2(-18.0, -12.0)
			])
		"swarm":
			return PackedVector2Array([
				Vector2(0.0, -16.0),
				Vector2(14.0, 14.0),
				Vector2(-14.0, 14.0)
			])
		"dash":
			return PackedVector2Array([
				Vector2(0.0, -20.0),
				Vector2(18.0, -2.0),
				Vector2(8.0, 18.0),
				Vector2(-8.0, 18.0),
				Vector2(-18.0, -2.0)
			])
		"boss":
			return PackedVector2Array([
				Vector2(0.0, -24.0),
				Vector2(18.0, -16.0),
				Vector2(24.0, 0.0),
				Vector2(18.0, 16.0),
				Vector2(0.0, 24.0),
				Vector2(-18.0, 16.0),
				Vector2(-24.0, 0.0),
				Vector2(-18.0, -16.0)
			])
		_:
			return PackedVector2Array([
				Vector2(14.0, 14.0),
				Vector2(-14.0, 14.0),
				Vector2(-14.0, -14.0),
				Vector2(14.0, -14.0)
			])

static func get_trait_ring_color(secondary_behavior_id: String) -> Color:
	match secondary_behavior_id:
		"dash":
			return Color(1.0, 0.46, 0.46, 0.7)
		"shooter":
			return Color(1.0, 0.68, 0.34, 0.7)
		"accelerator":
			return Color(1.0, 0.82, 0.36, 0.7)
		_:
			return Color(1.0, 0.9, 0.52, 0.64)

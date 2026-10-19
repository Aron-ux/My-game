extends RefCounted

const META := "wave_flyby"

static func configure(enemy, direction: Vector2) -> void:
	enemy.set_meta(META, {"direction": [direction.x, direction.y], "passed": false, "age": 0.0, "closest": INF})

static func velocity(enemy, delta: float) -> Vector2:
	var state: Dictionary = enemy.get_meta(META, {})
	var raw: Array = state.get("direction", [1, 0])
	var direction := Vector2(float(raw[0]), float(raw[1]))
	var to_target: Vector2 = enemy.target.global_position - enemy.global_position
	var distance := to_target.length()
	state["age"] = float(state.get("age", 0)) + delta
	# Once past the player (or past the closest approach), never turn back.
	if to_target.dot(direction) <= 0 or (float(state.get("closest", INF)) < 150 and distance > float(state["closest"]) + 28):
		state["passed"] = true
	state["closest"] = minf(distance, float(state.get("closest", INF)))
	if not bool(state.get("passed", false)):
		direction = direction.rotated(clampf(direction.angle_to(to_target), -deg_to_rad(25) * delta, deg_to_rad(25) * delta))
	state["direction"] = [direction.x, direction.y]
	enemy.set_meta(META, state)
	if float(state["age"]) > 24 or (bool(state["passed"]) and distance > 1100):
		enemy.queue_free()
	return direction * enemy.speed * enemy.slow_multiplier * 0.7 * 1.1

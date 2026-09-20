extends SceneTree

const BULLET := preload("res://scenes/enemy_bullet.tscn")
const CONTEXT := preload("res://scripts/enemies/enemy_projectile_frame_context.gd")
const RUNTIME := preload("res://scripts/tests/boss_danmaku_test_runtime.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := RUNTIME.new()
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var reference := MovingTarget.new()
	var actual := MovingTarget.new()
	scene.add_child(reference)
	scene.add_child(actual)
	var old_bullets: Array = []
	var new_bullets: Array = []
	for index in range(100):
		# The first hit moves and enlarges the hurtbox. Later hits must
		# observe that change, rather than reuse stale frame geometry.
		var config := {
			"position": Vector2(index * 9.0, 0.0), "speed": 0.0,
			"damage": index + 1.0, "lifetime": 10.0, "hit_radius": 3.0,
			"motion_mode": "straight"
		}
		for pair in [[reference, old_bullets], [actual, new_bullets]]:
			var bullet = BULLET.instantiate()
			scene.add_child(bullet)
			config.target = pair[0]
			bullet.reset_projectile(config)
			pair[1].append(bullet)
	for frame in range(3):
		var context := CONTEXT.new()
		for index in range(100):
			old_bullets[index].batch_physics_process(1.0 / 60.0)
			new_bullets[index].batch_physics_process(1.0 / 60.0, context)
			assert(old_bullets[index].pooled == new_bullets[index].pooled, "cached collision must preserve which bullets hit")
			assert(old_bullets[index].global_position == new_bullets[index].global_position, "caching cannot change movement")
		assert(reference.hits == actual.hits and reference.global_position == actual.global_position, "damage and target movement preserve original hit order")
	assert(actual.geometry_queries < reference.geometry_queries / 4, "unhit projectiles must share target geometry")
	var context := CONTEXT.new()
	assert(context.prepare(actual))
	assert(context.prepare(reference) and context.cached_target == reference, "different projectile targets cannot share cached geometry")
	var disappearing := MovingTarget.new()
	scene.add_child(disappearing)
	assert(context.prepare(disappearing))
	disappearing.free()
	# A target destroyed by damage invalidates the cache before the next shot.
	context.invalidate()
	assert(not context.prepare(null))
	scene.free()
	current_scene = null
	print("ENEMY_PROJECTILE_FRAME_CONTEXT_SMOKE_OK")
	quit(0)


class MovingTarget:
	extends Node2D
	var hits: Array[float] = []
	var geometry_queries := 0
	var radius := 3.0
	var center_offset := Vector2.ZERO

	func get_hurtbox_center() -> Vector2:
		geometry_queries += 1
		return global_position + center_offset

	func get_hurtbox_radius() -> float:
		return radius

	func take_damage(amount: float) -> void:
		hits.append(amount)
		if hits.size() == 1:
			position += Vector2(35, 0)
			center_offset = Vector2(7, 0)
			radius = 10.0

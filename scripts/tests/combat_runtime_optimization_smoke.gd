extends SceneTree

const ENEMY := preload("res://scenes/enemy.tscn")
const BULLET := preload("res://scenes/enemy_bullet.tscn")
const GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")
const SEPARATION := preload("res://scripts/enemies/enemy_body_separation.gd")
const FEEDBACK := preload("res://scripts/enemies/enemy_hit_feedback.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	_check_body_bounds(scene)
	_check_projectiles(scene)
	_check_flash_refresh(scene)
	scene.free()
	current_scene = null
	print("COMBAT_RUNTIME_OPTIMIZATION_SMOKE_OK")
	quit(0)


func _check_body_bounds(scene: Node2D) -> void:
	var small = ENEMY.instantiate()
	var growing = ENEMY.instantiate()
	scene.add_child(small)
	scene.add_child(growing)
	small.position = Vector2.ZERO
	growing.position = Vector2(60.0, 0.0)
	small.body_collision_radius = 20.0
	growing.body_collision_radius = 40.0
	small.body_collision_reference_scale = 1.0
	growing.body_collision_reference_scale = 1.0
	assert(is_equal_approx(GRID.get_max_body_radius(small), 12.0))
	assert(SEPARATION.compute_separation_velocity(small).is_zero_approx())
	# Growth must enlarge the conservative bound in this same physics frame.
	growing.scale = Vector2(6.0, 6.0)
	assert(is_equal_approx(GRID.get_max_body_radius(small), 72.0))
	assert(SEPARATION.compute_separation_velocity(small).x < 0.0)
	var before: Vector2 = small.position
	SEPARATION.apply_body_collision_separation(small)
	assert(small.position.x < before.x)
	# Reference-scale and radius changes must also invalidate immediately.
	growing.body_collision_reference_scale = 6.0
	assert(is_equal_approx(GRID.get_max_body_radius(small), 12.0))
	assert(SEPARATION.compute_separation_velocity(small).is_zero_approx())
	growing.body_collision_radius = -1.0
	growing.contact_radius = 25.0
	assert(is_equal_approx(growing.get_body_collision_radius(), 7.2))
	growing.contact_radius = 50.0
	assert(is_equal_approx(growing.get_body_collision_radius(), 12.3))
	scene.remove_child(growing)
	growing.scale = Vector2(12.0, 12.0)
	assert(is_equal_approx(growing.get_body_collision_radius(), 24.6))
	growing.scale = Vector2(18.0, 18.0)
	scene.add_child(growing)
	assert(is_equal_approx(growing.get_body_collision_radius(), 36.9))
	# A size change between two same-frame queries and a freed cached neighbor.
	growing.free()
	GRID.invalidate_body_bounds()
	assert(is_equal_approx(GRID.get_max_body_radius(small), 6.0))
	assert(SEPARATION.compute_separation_velocity(small).is_zero_approx())
	small.free()


func _check_projectiles(scene: Node2D) -> void:
	var target := Target.new()
	scene.add_child(target)
	var bullet = BULLET.instantiate()
	scene.add_child(bullet)
	bullet.reset_projectile({"position": Vector2(100.0, 100.0), "target": target, "speed": 60.0, "direction": Vector2.RIGHT, "lifetime": 2.0, "motion_mode": "straight"})
	bullet.batch_physics_process(0.1)
	assert(bullet.position.is_equal_approx(Vector2(106.0, 100.0)))
	assert(is_zero_approx(bullet.rotation))
	bullet.direction = Vector2.UP
	bullet.batch_physics_process(0.1)
	assert(bullet.position.is_equal_approx(Vector2(106.0, 94.0)))
	assert(is_equal_approx(bullet.rotation, -PI * 0.5))
	bullet.lifetime = 0.3
	bullet._update_lifetime_fade()
	assert(is_equal_approx(bullet.modulate.a, 0.5))
	bullet.recycle()
	bullet.reset_projectile({"position": Vector2(720.0, 0.0), "target": target, "direction": Vector2.LEFT, "lifetime": 4.0})
	bullet.batch_physics_process(0.01)
	assert(bullet.position.x < 720.0 and is_equal_approx(bullet.modulate.a, 1.0))
	# Exactly at the range limit stays live; just past it recycles.
	bullet.position = Vector2(1900.0, 0.0)
	bullet.batch_physics_process(0.01)
	assert(not bullet.pooled)
	bullet.position = Vector2(1900.5, 0.0)
	bullet.batch_physics_process(0.01)
	assert(bullet.pooled)
	bullet.free()
	target.free()


func _check_flash_refresh(scene: Node2D) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.add_frame("default", GradientTexture2D.new())
	scene.add_child(sprite)
	FEEDBACK._spawn_boss_hit_flash_overlay_for_sprite(sprite)
	var overlay := sprite.get_node(FEEDBACK.BOSS_HIT_FLASH_OVERLAY_NAME) as Sprite2D
	var tween: Tween = overlay.get_meta(FEEDBACK.BOSS_HIT_FLASH_TWEEN_META)
	for _index in range(128):
		FEEDBACK._spawn_boss_hit_flash_overlay_for_sprite(sprite)
		assert(overlay.get_meta(FEEDBACK.BOSS_HIT_FLASH_TWEEN_META) == tween)
	assert(get_processed_tweens().size() == 1)
	tween.custom_step(0.09)
	assert(is_equal_approx(overlay.modulate.a, 0.35))
	FEEDBACK._spawn_boss_hit_flash_overlay_for_sprite(sprite)
	assert(is_equal_approx(overlay.modulate.a, 0.7))
	tween.custom_step(0.18)
	assert(is_zero_approx(overlay.modulate.a))
	# A chained zero-duration callback can run on the following Tween step.
	tween.custom_step(0.01)
	assert(not overlay.visible)
	# A completed flash can restart, including on the same pooled visual.
	FEEDBACK._spawn_boss_hit_flash_overlay_for_sprite(sprite)
	assert(overlay.visible and is_equal_approx(overlay.modulate.a, 0.7))
	assert(FEEDBACK._get_boss_hit_flash_material() == overlay.material)


class Target:
	extends Node2D
	func get_hurtbox_center() -> Vector2:
		return global_position
	func get_hurtbox_radius() -> float:
		return 8.0
	func take_damage(_amount: float) -> void:
		pass

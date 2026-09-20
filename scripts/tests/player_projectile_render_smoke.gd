extends SceneTree

const BATCH := preload("res://scripts/player/player_projectile_batch.gd")
const BULLET := preload("res://scenes/bullet.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := _make_viewport()
	var reference_viewport := _make_viewport()
	var batch := BATCH.new()
	viewport.add_child(batch)
	batch.set_physics_process(false)
	var reference := BATCH.new()
	reference_viewport.add_child(reference)
	reference.set_physics_process(false)
	for index in range(48):
		batch.add_projectile({"position": Vector2(30.0 + (index % 8) * 28.0, 20.0 + (index / 8) * 26.0), "direction": Vector2.RIGHT.rotated(index * 0.19), "speed": 30.0, "lifetime": 10.0, "color": Color(0.2 + index * 0.013, 0.7, 0.4, 0.65), "visual_radius": 2.0 + index * 0.025, "visual_outline_width": 1.4 if index % 2 == 0 else 0.0, "visual_outline_color": Color(0.9, 0.1, 0.2, 0.5), "wave_amplitude": 4.0 if index % 3 == 0 else 0.0, "wave_frequency": 3.0, "wave_phase": index * 0.4})
	for step in range(6):
		if step == 1:
			batch._update_projectiles(0.12)
		elif step == 2:
			batch._remove_projectile(5)
			batch.colors[4] = Color(0.8, 0.1, 0.4, 0.3)
			batch.directions[7] = Vector2.ZERO
			batch.visual_radii[6] = 7.0
			batch.visual_outline_widths[8] = 2.3
			batch.outline_colors[8] = Color(0.3, 0.8, 1.0, 0.7)
		elif step == 3:
			batch._clear_projectiles()
		elif step == 4:
			batch.add_projectile_values(Vector2(90, 70), Vector2.ZERO, Vector2.UP, 0.0, Color.WHITE, "gunner")
		batch._update_animation_frame(0.05)
		reference._update_animation_frame(0.05)
		batch.last_multimesh_refresh_frame = -1
		batch._update_multimesh_instances()
		_upload_reference(batch, reference)
		_check_instances(batch, reference)
		if DisplayServer.get_name() != "headless":
			await process_frame
			await RenderingServer.frame_post_draw
			var actual := viewport.get_texture().get_image()
			var expected := reference_viewport.get_texture().get_image()
			assert(actual.get_data() == expected.get_data(), "Rendered pixels must match the previous submission algorithm")
	# Check the full allocation and same-index reuse beyond the heavy threshold.
	batch._clear_projectiles()
	for index in range(BATCH.MAX_BATCHED_PROJECTILES):
		assert(batch.add_projectile({"position": Vector2(index, -index), "direction": Vector2(0.3, 0.7), "color": Color.WHITE}))
	batch.last_multimesh_refresh_frame = -1
	batch._update_multimesh_instances()
	_upload_reference(batch, reference)
	_check_instances(batch, reference)
	_check_shared_material()
	viewport.free()
	reference_viewport.free()
	print("PLAYER_PROJECTILE_RENDER_SMOKE_OK")
	quit()


func _make_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 192)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = true
	root.add_child(viewport)
	return viewport


func _upload_reference(batch: Node2D, reference: Node2D) -> void:
	var count: int = batch.positions.size()
	reference.bullet_multimesh.visible_instance_count = count
	reference.bullet_outline_multimesh.visible_instance_count = count
	for index in range(count):
		var direction: Vector2 = batch.directions[index]
		if direction.length_squared() <= 0.001:
			direction = Vector2.RIGHT
		var diameter: float = max(batch.visual_min_diameters[index], batch.visual_radii[index] * 2.0)
		var size := Vector2.ONE * diameter * (84.0 / 32.0)
		var transform := Transform2D(direction * size.x, direction.orthogonal() * size.y, batch.positions[index])
		reference.bullet_multimesh.set_instance_transform_2d(index, transform)
		reference.bullet_multimesh.set_instance_color(index, batch.colors[index])
		var width: float = batch.visual_outline_widths[index]
		var outline_size := Vector2.ONE * (diameter + width * 2.0) * (84.0 / 32.0)
		var outline_transform := Transform2D(direction * outline_size.x, direction.orthogonal() * outline_size.y, batch.positions[index])
		reference.bullet_outline_multimesh.set_instance_transform_2d(index, outline_transform)
		reference.bullet_outline_multimesh.set_instance_color(index, batch.outline_colors[index] if width > 0.0 else Color(1, 1, 1, 0))


func _check_instances(batch: Node2D, reference: Node2D) -> void:
	for pair in [[batch.bullet_multimesh, reference.bullet_multimesh], [batch.bullet_outline_multimesh, reference.bullet_outline_multimesh]]:
		var actual: MultiMesh = pair[0]
		var expected: MultiMesh = pair[1]
		assert(actual.visible_instance_count == expected.visible_instance_count)
		for index in range(actual.visible_instance_count):
			assert(actual.get_instance_transform_2d(index).is_equal_approx(expected.get_instance_transform_2d(index)))
			assert(actual.get_instance_color(index).is_equal_approx(expected.get_instance_color(index)))


func _check_shared_material() -> void:
	var first = BULLET.instantiate()
	var second = BULLET.instantiate()
	root.add_child(first)
	root.add_child(second)
	first.set_physics_process(false)
	second.set_physics_process(false)
	var first_sprite: Sprite2D = first.get_node("BulletSprite")
	var second_sprite: Sprite2D = second.get_node("BulletSprite")
	assert(first_sprite.material == second_sprite.material)
	var custom := ShaderMaterial.new()
	custom.shader = first.WHITE_KEY_SHADER
	custom.set_shader_parameter("value_threshold", 0.8)
	second_sprite.material = custom
	second._refresh_bullet_visual(true)
	assert(second_sprite.material == custom)
	assert(first_sprite.material != custom)
	first.free()
	second.free()

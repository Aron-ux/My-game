extends SceneTree

const RUNTIME := preload("res://scripts/tests/boss_danmaku_test_runtime.gd")
const RENDERER := preload("res://scripts/enemies/boss_projectile_renderer.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var harness := RUNTIME.new()
	root.add_child(harness)
	current_scene = harness
	var reference_view := _viewport()
	var actual_view := _viewport()
	var reference_scene := RUNTIME.new()
	var actual_scene := RUNTIME.new()
	reference_view.add_child(reference_scene)
	actual_view.add_child(actual_scene)
	reference_scene.process_mode = Node.PROCESS_MODE_DISABLED
	actual_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var renderer = RENDERER.get_or_create(actual_scene)
	var reference_bullets: Array = []
	var actual_bullets: Array = []
	for index in range(90):
		var config := {
			"position": Vector2(22.0 + (index % 10) * 27.0, 22.0 + (index / 10) * 22.0),
			"direction": Vector2.RIGHT.rotated(index * 0.27),
			"visual_color": Color.from_hsv(0.72 + (index % 7) * 0.012, 0.65, 1.0),
			"visual_style": "boss_danmaku_violet_orb" if index % 3 else "boss_danmaku_shadow_orb",
			"size_scale": 0.7 + (index % 5) * 0.3, "lifetime": 10.0
		}
		var reference = RUNTIME.BULLET.instantiate()
		reference_scene.add_child(reference)
		reference.reset_projectile(config)
		reference.rotation = index * 0.27
		reference_bullets.append(reference)
		var actual = RUNTIME.BULLET.instantiate()
		actual.prepare_for_spawn()
		actual_scene.add_child(actual)
		harness.set_meta(RENDERER.META_KEY, renderer)
		actual.reset_projectile(config)
		harness.remove_meta(RENDERER.META_KEY)
		actual.rotation = index * 0.27
		assert(actual.get_child_count() == 1, "production batch spawn must not allocate four per-bullet visual layers")
		actual_bullets.append(actual)
	assert(renderer.members.size() == 90)
	for step_index in range(4):
		if step_index == 1:
			for index in range(90):
				for bullet in [reference_bullets[index], actual_bullets[index]]:
					bullet.position += Vector2(sin(index) * 15.0, cos(index) * 10.0)
					bullet.rotation += 0.23
					bullet.modulate = Color(0.9, 0.8, 0.95, 0.25 + (index % 5) * 0.15)
		elif step_index == 2:
			for index in range(0, 90, 3):
				var saved: Dictionary = JSON.parse_string(JSON.stringify(reference_bullets[index].get_save_data()))
				for pair in [[reference_scene, reference_bullets[index]], [actual_scene, actual_bullets[index]]]:
					pair[1].recycle()
					pair[1].apply_save_data(saved, null)
				renderer.add_projectile(actual_bullets[index])
		elif step_index == 3:
			for index in range(0, 90, 2):
				reference_bullets[index].recycle()
				actual_bullets[index].recycle()
		renderer.sync(true)
		assert(renderer.members.size() == (45 if step_index == 3 else 90))
		assert(renderer.meshes[0].visible_instance_count == renderer.slots.size())
		await process_frame
		await RenderingServer.frame_post_draw
		var actual_image := actual_view.get_texture().get_image()
		var reference_image := reference_view.get_texture().get_image()
		var actual_data := actual_image.get_data()
		var reference_data := reference_image.get_data()
		var changed := 0
		var max_difference := 0
		for index in range(actual_data.size()):
			var difference := absi(actual_data[index] - reference_data[index])
			if difference > 0:
				changed += 1
			max_difference = maxi(max_difference, difference)
		print("BOSS_RENDER_COMPARE step=%d changed=%d max_channel_difference=%d" % [step_index, changed, max_difference])
		actual_image.save_png("res://.omx/boss-performance/batch-%d.png" % step_index)
		reference_image.save_png("res://.omx/boss-performance/reference-%d.png" % step_index)
		assert(max_difference <= 1, "batched circles must retain all layers, overlap order, transforms, color and fading")
	current_scene = null
	reference_view.free()
	actual_view.free()
	harness.free()
	print("BOSS_PROJECTILE_RENDER_SMOKE_OK")
	quit(0)


func _viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 240)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport

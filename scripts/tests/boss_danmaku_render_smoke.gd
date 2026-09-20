extends SceneTree

const RUNTIME := preload("res://scripts/tests/boss_danmaku_test_runtime.gd")
const ATTACKS := preload("res://scripts/enemies/enemy_boss_attacks.gd")
const STATE := preload("res://scripts/enemies/enemy_boss_state.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.world_2d = root.world_2d
	var scene := RUNTIME.new()
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.player = Node2D.new()
	scene.add_child(scene.player)
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([Vector2(-2000, -2000), Vector2(2000, -2000), Vector2(2000, 2000), Vector2(-2000, 2000)])
	backdrop.color = Color(0.07, 0.11, 0.10)
	backdrop.z_index = -10
	scene.add_child(backdrop)
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE * 0.72
	viewport.add_child(camera)
	var boss = scene.make_boss()
	boss.boss_phase = 3
	for pattern in range(3):
		scene.clear_bullets()
		boss.boss_danmaku_pattern = pattern - 1
		boss.boss_pattern_rotation = 0.0
		ATTACKS.fire_quarter_sine_ring(boss, 15)
		for frame in range(240):
			ATTACKS.update_danmaku_stream(boss, 1.0 / 60.0)
			for bullet in scene.active.values():
				bullet.batch_physics_process(1.0 / 60.0)
		assert(scene.active.size() == 180, "all rendered pattern bullets must remain active")
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var colored_pixels := 0
		for y in range(0, 900, 2):
			for x in range(0, 1280, 2):
				var color := image.get_pixel(x, y)
				if color.v > 0.6 and color.s > 0.25:
					colored_pixels += 1
		assert(colored_pixels > 1000, "colored danmaku must be visible in GPU output")
		image.save_png("res://.omx/boss-rework/danmaku-pattern-%d.png" % pattern)
	scene.clear_bullets()
	boss.boss_danmaku_pattern = -1
	boss.boss_phase = 3
	boss.boss_phase_three_elapsed = 0.0
	boss.boss_shield_break_intro_played = true
	boss.boss_attack_pressure_scale = 0.9
	boss.current_health = 15000.0
	boss.boss_radial_timer = 0.0
	boss.boss_sine_cooldown = 0.0
	boss.boss_split_timer = 1.6
	boss.boss_laser_timer = 2.9
	boss.boss_peacock_timer = 4.6
	for frame in range(330):
		scene.player.position = Vector2(450, 150)
		STATE.update_boss_trait(boss, 1.0 / 60.0)
		for bullet in scene.active.values():
			if not bullet.is_queued_for_deletion():
				bullet.batch_physics_process(1.0 / 60.0)
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://.omx/boss-rework/danmaku-combined.png")
	scene.free()
	current_scene = null
	viewport.free()
	print("BOSS_DANMAKU_RENDER_SMOKE_OK")
	quit(0)

extends SceneTree

const RUNTIME := preload("res://scripts/tests/boss_danmaku_test_runtime.gd")
const ATTACKS := preload("res://scripts/enemies/enemy_boss_attacks.gd")
const STATE := preload("res://scripts/enemies/enemy_boss_state.gd")
const ROUTINE := preload("res://scripts/enemies/enemy_boss_routine.gd")
const HUD_FLOW := preload("res://scripts/game/game_hud_flow.gd")


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
	for pattern in range(ATTACKS.DANMAKU.PATTERN_COUNT):
		scene.clear_bullets()
		boss.boss_pattern_rotation = 0.0
		scene.player.position = Vector2(450, 150)
		ATTACKS.fire_quarter_sine_ring(boss, 15, pattern)
		for frame in range(240):
			ATTACKS.update_danmaku_stream(boss, 1.0 / 60.0)
			for bullet in scene.active.values():
				# Isolated geometry snapshots evaluate the analytic path.
				# Live routine captures below retain collisions and culling.
				bullet.travel_time += 1.0 / 60.0
				bullet.call("_update_%s_motion" % bullet.motion_mode)
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
	boss.boss_phase = 2
	boss.boss_shield_break_intro_played = true
	boss.boss_attack_pressure_scale = 0.9
	boss.current_health = 15000.0
	scene.player.position = Vector2(450, 150)
	var hud = preload("res://scripts/hud.gd").new()
	viewport.add_child(hud)
	ROUTINE.reset(boss)
	_advance(scene, boss, 3.0)
	await _capture(viewport, hud, boss, "routine-basic")
	_advance(scene, boss, 9.5)
	await _capture(viewport, hud, boss, "routine-preview")
	_advance(scene, boss, 12.0)
	await _capture(viewport, hud, boss, "routine-bloom")
	_advance(scene, boss, 4.5)
	await _capture(viewport, hud, boss, "routine-recovery")
	for theme in [1, 2]:
		scene.clear_bullets()
		ROUTINE.stop_attacks(boss)
		ROUTINE.reset(boss, theme)
		ROUTINE.advance_stage(boss)
		_advance(scene, boss, 1.5)
		if theme == 1:
			_advance(scene, boss, 11.0)
			await _capture(viewport, hud, boss, "routine-spiral")
		else:
			_advance(scene, boss, 5.5)
			await _capture(viewport, hud, boss, "routine-laser-warning")
			_advance(scene, boss, 2.0)
			await _capture(viewport, hud, boss, "routine-overload")
	for theme in range(3, ROUTINE.THEMES.size()):
		scene.clear_bullets()
		ROUTINE.stop_attacks(boss)
		ROUTINE.reset(boss, theme)
		ROUTINE.advance_stage(boss)
		_advance(scene, boss, 1.5)
		for section in range(3):
			_advance(scene, boss, 4.0 if section == 0 else 5.0)
			await _capture(viewport, hud, boss, "yuyuko-theme-%d-section-%d" % [theme, section])
	scene.free()
	current_scene = null
	viewport.free()
	print("BOSS_DANMAKU_RENDER_SMOKE_OK")
	quit(0)


func _advance(scene, boss, duration: float) -> void:
	for frame in range(roundi(duration * 60.0)):
		STATE.update_boss_trait(boss, 1.0 / 60.0)
		for bullet in scene.active.values():
			if not bullet.is_queued_for_deletion():
				bullet.batch_physics_process(1.0 / 60.0)


func _capture(viewport: SubViewport, hud, boss, filename: String) -> void:
	var data: Dictionary = HUD_FLOW._get_boss_ui_data(boss, "Boss")
	hud.show_boss_ui(data.name, data.current_health, data.max_health, data.status, data.ui)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(hud.boss_status_label.visible and hud.boss_status_label.text.contains(data.status.label), "real HUD must display the active stage name")
	viewport.get_texture().get_image().save_png("res://.omx/boss-rework/%s.png" % filename)

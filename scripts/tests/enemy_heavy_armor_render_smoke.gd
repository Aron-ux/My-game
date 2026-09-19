extends SceneTree

const VISUAL := preload("res://assets/enemies/pumpkin/pumpkin.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 220)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var normal = VISUAL.instantiate()
	viewport.add_child(normal)
	normal.position = Vector2(100, 110)
	var armored = VISUAL.instantiate()
	viewport.add_child(armored)
	armored.position = Vector2(300, 110)
	armored.set_heavy_armor(true)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var orange_count := 0
	var silver_count := 0
	for y in range(30, 150):
		for x in range(40, 160):
			var normal_pixel := image.get_pixel(x, y)
			if normal_pixel.a > 0.9 and normal_pixel.r > normal_pixel.b + 0.15:
				orange_count += 1
			var silver_pixel := image.get_pixel(x + 200, y)
			if silver_pixel.a > 0.9 and silver_pixel.b > 0.3 and silver_pixel.b >= silver_pixel.r and silver_pixel.b - silver_pixel.r < 0.12:
				silver_count += 1
	assert(orange_count > 100)
	assert(silver_count > 100)
	image.save_png(OS.get_environment("TEMP").path_join("enemy_heavy_armor_render.png"))
	armored.set_heavy_armor(false)
	assert(armored.sprite.material == null)
	viewport.queue_free()
	await process_frame
	print("ENEMY_HEAVY_ARMOR_RENDER_SMOKE_OK")
	quit(0)

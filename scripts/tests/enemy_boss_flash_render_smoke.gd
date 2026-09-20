extends SceneTree

const FEEDBACK := preload("res://scripts/enemies/enemy_hit_feedback.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 96)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sprite := AnimatedSprite2D.new()
	var texture_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	texture_image.fill(Color(0.4, 0.1, 0.1, 1.0))
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.add_frame("default", ImageTexture.create_from_image(texture_image))
	sprite.position = Vector2(64, 48)
	viewport.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	var original := viewport.get_texture().get_image().get_pixel(64, 48)
	for _index in range(128):
		FEEDBACK._spawn_boss_hit_flash_overlay_for_sprite(sprite)
	var overlay := sprite.get_node(FEEDBACK.BOSS_HIT_FLASH_OVERLAY_NAME) as Sprite2D
	var tween: Tween = overlay.get_meta(FEEDBACK.BOSS_HIT_FLASH_TWEEN_META)
	tween.pause()
	await process_frame
	await RenderingServer.frame_post_draw
	var flashed := viewport.get_texture().get_image().get_pixel(64, 48)
	assert(flashed.g > original.g + 0.3)
	assert(get_processed_tweens().size() == 1)
	tween.custom_step(0.20)
	await process_frame
	await RenderingServer.frame_post_draw
	var recovered := viewport.get_texture().get_image().get_pixel(64, 48)
	assert(absf(recovered.r - original.r) < 0.02)
	assert(absf(recovered.g - original.g) < 0.02)
	viewport.free()
	print("ENEMY_BOSS_FLASH_RENDER_SMOKE_OK")
	quit(0)

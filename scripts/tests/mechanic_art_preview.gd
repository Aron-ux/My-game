extends SceneTree

const ART := "res://design/mechanic-rework-20261013/"
const VISUAL := preload("res://assets/players/mechanic/mechanic.tscn")
const ROLE := preload("res://scripts/player/roles/mechanic_role.gd")
const TURRET := preload("res://scripts/abilities/mechanic_tulip_turret_ability.gd")
const CANNON := preload("res://scripts/abilities/mechanic_missile_volley_ability.gd")
const FIELD := preload("res://scripts/abilities/mechanic_emp_burst_ability.gd")
const GUARD := preload("res://scripts/abilities/mechanic_drone_ability.gd")
const MINE := preload("res://scripts/abilities/mechanic_mine_ability.gd")

var stage: Node2D
var sprites: Array[AnimatedSprite2D] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 820)
	root.title = "Mechanic — character and equipment preview"
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 820)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var container := SubViewportContainer.new()
	root.add_child(container)
	container.add_child(viewport)
	stage = Node2D.new()
	viewport.add_child(stage)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(1280, 820)
	backdrop.color = Color("171e29")
	stage.add_child(backdrop)
	_label("MECHANIC / TULIP WORKSHOP", Vector2(40, 22), 28)
	_label("Independent character animation & equipment | imported game assets", Vector2(40, 59), 17)
	for i in range(3):
		var actor = VISUAL.instantiate()
		stage.add_child(actor)
		actor.position = Vector2(175 + i * 280, 210)
		actor.scale = Vector2.ONE * 2.0
		var sprite: AnimatedSprite2D = actor.get_node("AnimatedSprite2D")
		var clip: StringName = [&"mechanic-idle", &"mechanic-run", &"mechanic-command"][i]
		sprite.sprite_frames.set_animation_loop(clip, true)
		sprite.play(clip)
		sprites.append(sprite)
		_label(["IDLE / 4 frames", "RUN / 8 frames", "COMMAND / 4 frames"][i], Vector2(70 + i * 280, 310))
	var portrait := Sprite2D.new()
	portrait.texture = preload("res://assets/UI/facility/机械师.png")
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.position = Vector2(1080, 210)
	portrait.scale = Vector2.ONE * 1.5
	stage.add_child(portrait)
	_label("HUD PORTRAIT", Vector2(1000, 310))
	_effect(TURRET.new()._get_turret_frames(), "fire", Vector2(180, 455), 0.7, "LIGHT AUTOCANNON")
	_effect(CANNON.new()._get_cannon_frames(), "fire", Vector2(465, 455), 0.95, "HEAVY CANNON")
	_effect(FIELD.new()._get_tower_frames(), "spin", Vector2(745, 443), 0.75, "FIELD TOWER")
	_effect(GUARD.new()._get_guard_frames(), "guard", Vector2(1060, 452), 0.75, "GUARD ROBOT")
	var role = ROLE.new()
	_effect(role._get_spider_frames(), "crawl", Vector2(175, 681), 1.4, "SPIDER SCOUT")
	_effect(MINE.new()._get_mine_frames(), "idle", Vector2(470, 668), 0.8, "PROXIMITY MINE")
	_effect(role._get_ult_warning_frames(), "warning", Vector2(750, 675), 0.65, "ARTILLERY TARGET")
	_effect(role._get_ult_explosion_frames(), "explosion", Vector2(1060, 675), 0.7, "ARTILLERY BLAST")
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ART + "preview-frames"))
	for sprite in sprites:
		sprite.pause()
	for frame in range(48):
		for sprite in sprites:
			var fps := sprite.sprite_frames.get_animation_speed(sprite.animation)
			var count := sprite.sprite_frames.get_frame_count(sprite.animation)
			sprite.frame = int(float(frame) / 12.0 * fps) % count
		await process_frame
		await RenderingServer.frame_post_draw
		var capture := viewport.get_texture().get_image()
		assert(capture != null and capture.get_width() == 1280)
		capture.save_png(ART + "preview-frames/%03d.png" % frame)
		if frame == 3:
			capture.save_png(ART + "preview.png")
	print("MECHANIC_ART_PREVIEW_OK")
	quit(0)


func _effect(frames: SpriteFrames, clip: StringName, point: Vector2, factor: float, caption: String) -> void:
	assert(frames.has_animation(clip), "missing preview animation: " + clip)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	frames.set_animation_loop(clip, true)
	sprite.position = point
	sprite.scale = Vector2.ONE * factor
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_child(sprite)
	sprite.play(clip)
	sprites.append(sprite)
	_label(caption, Vector2(point.x - 110, 560 if point.y < 600 else 784))


func _label(caption: String, point: Vector2, font_size: int = 18) -> void:
	var label := Label.new()
	label.text = caption
	label.position = point
	label.add_theme_color_override("font_color", Color("e6d3ae"))
	label.add_theme_font_size_override("font_size", font_size)
	stage.add_child(label)

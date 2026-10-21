extends SceneTree

# 技能特效验收：魔眼聚合（紫色激光）、火球术（飞行/爆炸/燃烧地面）、火焰之径。
# 需要显示环境；输出到 artifacts/skill-fx/。只读运行，不改游戏状态。

const EYE := preload("res://scripts/player/gunner_magic_eye_visual.gd")
const PROJECTILE := preload("res://scripts/player/mage_fireball_projectile.gd")
const BLAST := preload("res://scripts/player/mage_fire_blast_visual.gd")
const GROUND := preload("res://scripts/player/mage_fire_ground_visual.gd")
const FLAME_PATH := preload("res://scripts/player/mage_flame_path.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("res://artifacts/skill-fx")
	await _shoot_eye()
	await _shoot_fireball()
	await _shoot_flame_path()
	await _shoot_wet_variants()
	print("SKILL_FX_ACCEPTANCE_OK")
	quit()


func _shot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		for index in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/skill-fx/%s.png" % name)


func _label(scene: Node, text: String, pos: Vector2, size := 18) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	scene.add_child(label)


func _arena(title: String) -> Node2D:
	# Dispose the previous scene so the screenshots don't stack on top of each other.
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.free()
	var scene := Arena.new()
	scene.title = title
	root.add_child(scene)
	current_scene = scene
	return scene


func _shoot_eye() -> void:
	var scene := _arena("魔眼聚合 - 紫色激光加农炮（多帧）")
	for index in 4:
		var anchor := Node2D.new()
		anchor.position = Vector2(180, 300 + index * 90.0)
		scene.add_child(anchor)
		var eye := Node2D.new()
		eye.set_script(EYE)
		eye.set("follow_target", anchor)
		eye.set("beam_direction", Vector2.RIGHT)
		eye.set("beam_length", 420.0)
		eye.set("beam_width", 64.0)
		scene.add_child(eye)
		# 先跑完起手，再按连发次数打脉冲，让四行分别处于不同节奏。
		for step in 8:
			eye._process(0.0167)
		for shot in index * 2 + 1:
			eye.fire_pulse()
		for step in 6:
			eye._process(0.033)
		_label(scene, ["单发", "连发 3", "连发 5", "连发 7"][index], Vector2(24, 292 + index * 90.0))
	await _shot("magic-eye")


func _shoot_fireball() -> void:
	var scene := _arena("火球术 - 飞行 / 爆炸 / 燃烧地面")
	for index in 3:
		var projectile := Node2D.new()
		projectile.set_script(PROJECTILE)
		projectile.set("start_position", Vector2(120, 200 + index * 140))
		projectile.set("target_position", Vector2(620, 200 + index * 140))
		projectile.set("radius", 22.0)
		projectile.global_position = Vector2(120, 200 + index * 140)
		scene.add_child(projectile)
		projectile.set_process(false)
		for step in [0.1, 0.25, 0.42][index] / 0.0167:
			projectile._process(0.0167)
		_label(scene, "飞行 %d" % (index + 1), Vector2(700, 190 + index * 140))
	var ground := Node2D.new()
	ground.set_script(GROUND)
	ground.set("radius", 150.0)
	ground.global_position = Vector2(1000, 220)
	scene.add_child(ground)
	ground.set_process(false)
	for step in 40:
		ground._process(0.0167)
	_label(scene, "燃烧地面", Vector2(940, 380))
	var blast := Node2D.new()
	blast.set_script(BLAST)
	blast.set("radius", 150.0)
	blast.global_position = Vector2(1000, 560)
	scene.add_child(blast)
	blast.set_process(false)
	for step in 6:
		blast._process(0.0167)
	_label(scene, "爆炸", Vector2(960, 700))
	await _shot("fireball")


func _shoot_flame_path() -> void:
	var scene := _arena("火焰之径 - 沿途火舌")
	var path := Node2D.new()
	path.set_script(FLAME_PATH)
	scene.add_child(path)
	path.set_process(false)
	var origin := Vector2(140, 520)
	for index in 60:
		path.record_position(origin + Vector2(index * 17.0, sin(index * 0.35) * 70.0))
	for step in 30:
		path.flicker_elapsed += 0.033
	path.queue_redraw()
	await _shot("flame-path")


func _shoot_wet_variants() -> void:
	# 火焰之径的老/新段落对比，以及燃烧地面接近熄灭时的样子。
	var scene := _arena("燃烧地面 淡出 / 火焰之径 长短对比")
	var fresh := Node2D.new()
	fresh.set_script(GROUND)
	fresh.set("radius", 130.0)
	fresh.global_position = Vector2(230, 300)
	scene.add_child(fresh)
	fresh.set_process(false)
	for step in 40:
		fresh._process(0.0167)
	_label(scene, "燃烧中", Vector2(190, 430))
	var fading := Node2D.new()
	fading.set_script(GROUND)
	fading.set("radius", 130.0)
	fading.global_position = Vector2(560, 300)
	scene.add_child(fading)
	fading.set_process(false)
	for step in 40:
		fading._process(0.0167)
	fading.set_remaining(0.22)
	_label(scene, "即将熄灭", Vector2(520, 430))
	var short_path := Node2D.new()
	short_path.set_script(FLAME_PATH)
	scene.add_child(short_path)
	short_path.set_process(false)
	for index in 18:
		short_path.record_position(Vector2(820 + index * 18.0, 220 + sin(index * 0.4) * 30.0))
	for step in 20:
		short_path.flicker_elapsed += 0.033
	short_path.queue_redraw()
	var long_path := Node2D.new()
	long_path.set_script(FLAME_PATH)
	scene.add_child(long_path)
	long_path.set_process(false)
	for index in 26:
		long_path.record_position(Vector2(820 + index * 16.0, 520 + sin(index * 0.5) * 60.0))
	for step in 20:
		long_path.flicker_elapsed += 0.033
	long_path.age = 13.0
	long_path.queue_redraw()
	_label(scene, "火焰之径（新→旧，旧段落变矮变暗）", Vector2(820, 640))
	await _shot("ground-fade-and-path-age")


class Arena:
	extends Node2D
	var title := ""
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.20, 0.26, 0.19))
		draw_string(ThemeDB.fallback_font, Vector2(24, 34), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

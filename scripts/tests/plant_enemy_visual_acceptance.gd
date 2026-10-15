extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := Arena.new()
	root.add_child(scene)
	current_scene = scene
	var target := Node2D.new()
	target.position = Vector2(1050, 380)
	scene.add_child(target)
	var names := ["vine", "shadow_tree", "shadow_tree_young", "tree_seed", "necro_priest"]
	for index in names.size():
		var enemy = preload("res://scenes/enemy.tscn").instantiate()
		enemy.target = target
		enemy.apply_enemy_profile("normal", preload("res://scripts/enemy/enemy_archetype_database.gd").get_profile("normal", names[index]))
		enemy.position = Vector2(150 + index * 240, 355)
		scene.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.scale *= 2
		var label := Label.new()
		label.text = ["藤蔓怪", "幽影树怪", "幽影树怪·幼年", "可攻击树种", "亡灵牧师"][index]
		label.position = Vector2(enemy.position.x - 65, 470)
		label.add_theme_font_size_override("font_size", 22)
		scene.add_child(label)
	var seed := preload("res://scripts/enemies/parasite_seed.gd").new()
	seed.position = Vector2(200, 580)
	seed.landed = true
	seed.fuse = 1
	scene.add_child(seed)
	seed.set_physics_process(false)
	var porcupine = preload("res://scenes/enemy.tscn").instantiate()
	porcupine.target = target
	porcupine.apply_enemy_profile("normal", preload("res://scripts/enemy/enemy_archetype_database.gd").get_profile("normal", "angry_porcupine"))
	porcupine.position = Vector2(610, 600)
	scene.add_child(porcupine)
	porcupine.set_physics_process(false)
	porcupine.scale *= 1.5
	var angry = preload("res://scenes/enemy.tscn").instantiate()
	angry.target = target
	angry.apply_enemy_profile("normal", preload("res://scripts/enemy/enemy_archetype_database.gd").get_profile("normal", "angry_porcupine"))
	angry.position = Vector2(960, 600)
	scene.add_child(angry)
	angry.set_physics_process(false)
	angry.scale *= 1.5
	angry.porcupine_state.remaining = 20.0
	preload("res://scripts/enemies/enemy_porcupine.gd").sync_visual(angry)
	preload("res://scripts/enemies/enemy_porcupine.gd").show_quill_burst(angry, 1)
	if DisplayServer.get_name() != "headless":
		for index in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts/plant-enemy-acceptance")
		root.get_texture().get_image().save_png("res://artifacts/plant-enemy-acceptance/units-and-seed.png")
	scene.free()
	current_scene = null
	print("PLANT_ENEMY_VISUAL_ACCEPTANCE_OK")
	quit()


class Arena:
	extends Node2D
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.15, 0.19, 0.16))
		draw_string(ThemeDB.fallback_font, Vector2(35, 48), "New plant enemies / visual acceptance (2x preview)", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color.WHITE)

extends SceneTree

# Renders the six reworked enemies, their states and skill effects to
# artifacts/enemy-art-rework/. Needs a display (skips screenshots headless).

const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const PORCUPINE := preload("res://scripts/enemies/enemy_porcupine.gd")
const MAGE := preload("res://scripts/enemies/enemy_skull_mage.gd")
const DOMAIN := preload("res://scripts/enemies/skull_mage_domain.gd")
const SHEET_EFFECT := preload("res://scripts/enemies/enemy_sheet_effect.gd")
const OUTPUT_DIR := "res://artifacts/enemy-art-rework"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	await _shoot_units()
	await _shoot_lineup()
	await _shoot_hits()
	await _shoot_skills()
	print("ENEMY_ART_REWORK_VISUAL_ACCEPTANCE_OK")
	quit()


func _spawn(scene: Node, target: Node2D, archetype: String, position: Vector2, view_scale := 1.5):
	var enemy = preload("res://scenes/enemy.tscn").instantiate()
	enemy.target = target
	enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", archetype))
	enemy.position = position
	scene.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.scale *= view_scale
	return enemy


func _label(scene: Node, text: String, position: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = position - Vector2(70, 0)
	label.size = Vector2(140, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	scene.add_child(label)


func _shoot_units() -> void:
	var scene := Arena.new()
	scene.title = "Enemy art rework - units (1.5x)"
	root.add_child(scene)
	current_scene = scene
	var target := Node2D.new()
	target.position = Vector2(1250, 700)
	scene.add_child(target)
	var row_a := [["angry_porcupine", "愤怒豪猪"], ["angry_porcupine", "愤怒豪猪·狂怒"], ["necro_priest", "亡灵牧师"], ["shadow_tree", "幽影树怪"], ["shadow_tree_young", "幽影树怪·幼年"]]
	for index in row_a.size():
		var x := 140.0 + index * 250.0
		var enemy = _spawn(scene, target, row_a[index][0], Vector2(x, 230))
		if index == 1:
			enemy.porcupine_state.remaining = 20.0
			PORCUPINE.sync_visual(enemy)
		_label(scene, row_a[index][1], Vector2(x, 310))
	var row_b := [["vine", "藤蔓怪"], ["tree_seed", "树种·飞行"], ["skull_mage", "骷髅法师"], ["skull_mage", "寒冰护甲"], ["skull_mage", "死灵身躯"]]
	for index in row_b.size():
		var x := 140.0 + index * 250.0
		var enemy = _spawn(scene, target, row_b[index][0], Vector2(x, 530))
		if row_b[index][0] == "skull_mage":
			enemy.skull_mage_state.ice_remaining = 10.0 if index == 3 else 0.0
			enemy.skull_mage_state.invulnerable_remaining = 2.0 if index == 4 else 0.0
			MAGE.sync_visual(enemy)
		if index == 0:
			var visual = enemy.get_node("ProfileVisual")
			visual.set_moving(true, Vector2.LEFT)
		_label(scene, row_b[index][1], Vector2(x, 620))
	await _capture("units.png", 8)
	scene.free()


# In-game scale next to the existing hand-made enemies, for a style check.
func _shoot_lineup() -> void:
	var scene := Arena.new()
	scene.title = "Lineup at 1x with existing enemies (left: existing, right: reworked)"
	root.add_child(scene)
	current_scene = scene
	var target := Node2D.new()
	target.position = Vector2(1250, 700)
	scene.add_child(target)
	var existing := ["chaser", "runner", "swarm", "shooter", "brute", "shotgunner"]
	var reworked := ["angry_porcupine", "necro_priest", "shadow_tree", "shadow_tree_young", "vine", "skull_mage"]
	for index in existing.size():
		_spawn(scene, target, existing[index], Vector2(70 + index * 95, 380), 1.0)
	for index in reworked.size():
		_spawn(scene, target, reworked[index], Vector2(660 + index * 100, 380), 1.0)
	await _capture("lineup.png", 8)
	scene.free()


func _shoot_hits() -> void:
	var scene := Arena.new()
	scene.title = "Hit feedback (flash + squash/recoil + material burst), 1.5x"
	root.add_child(scene)
	current_scene = scene
	var target := Node2D.new()
	target.position = Vector2(1250, 700)
	scene.add_child(target)
	var ids := [["angry_porcupine", "愤怒豪猪"], ["necro_priest", "亡灵牧师"], ["shadow_tree", "幽影树怪"], ["shadow_tree_young", "幼年"], ["vine", "藤蔓怪"], ["skull_mage", "骷髅法师"]]
	var visuals: Array = []
	for index in ids.size():
		var x := 110.0 + index * 210.0
		var enemy = _spawn(scene, target, ids[index][0], Vector2(x, 360))
		_label(scene, ids[index][1], Vector2(x, 470))
		visuals.append(enemy.get_node("ProfileVisual"))
	for index in 3:
		await process_frame
	for visual in visuals:
		visual.burst_cooldown = 0.0
		visual.play_hit()
	# Capture mid-hit: flash still visible, squash near its peak, burst spreading.
	await _capture("hits.png", 4)
	scene.free()


func _shoot_skills() -> void:
	var scene := Arena.new()
	scene.title = "Enemy art rework - skills (1x)"
	root.add_child(scene)
	current_scene = scene
	var player = preload("res://scenes/player.tscn").instantiate()
	scene.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.fire_timer.stop()
	player.auto_attack_enabled = false
	player.position = Vector2(1060, 300)
	player.get_node("Camera2D").enabled = false
	# Statuses on the player: entangle, necro mark and cold.
	player.set_meta("vine_entangle_state", {"remaining": 1.5, "damage": 0.0, "elapsed": 0.0})
	player.set_meta("necro_mark_remaining", 5.0)
	player.set_meta("skull_mage_cold_remaining", 3.0)
	preload("res://scripts/player/player_enemy_status_overlays.gd").sync(player)
	_label(scene, "缠绕 / 亡灵印记 / 寒冰侵蚀", Vector2(1060, 380))

	var field := DOMAIN.new()
	field.player = null
	field.position = Vector2(330, 420)
	field.time = 2.0
	scene.add_child(field)
	field.set_physics_process(false)
	field.queue_redraw()
	var mage = _spawn(scene, player, "skull_mage", Vector2(330, 420), 1.4)
	mage.skull_mage_state.drain_remaining = 5.0
	MAGE.sync_visual(mage)
	var drain_visual = mage.get_node("ProfileVisual")
	drain_visual.drain_target = Vector2(700, 300)
	_label(scene, "不洁领域 + 死亡汲取", Vector2(330, 690))

	var priest = _spawn(scene, player, "necro_priest", Vector2(760, 560), 1.0)
	priest.get_node("ProfileVisual").play_cast()
	var circle := SHEET_EFFECT.spawn(scene, preload("res://assets/enemies/necropriest/prayer_circle.png"), 8, priest.position, {"offset": Vector2(0, 22), "fps": 0.0, "art_scale": 1.6, "z_index": 9})
	circle.set_process(false)
	circle.frame = 4
	var wisp := SHEET_EFFECT.spawn(scene, preload("res://assets/enemies/necropriest/heal_wisp.png"), 6, Vector2(870, 560), {"fps": 0.0})
	wisp.set_process(false)
	wisp.frame = 2
	_label(scene, "亡灵祷告", Vector2(760, 640))

	var seed_script := preload("res://scripts/enemies/parasite_seed.gd")
	for index in 3:
		var seed := seed_script.new()
		seed.position = Vector2(960 + index * 110, 560)
		seed.landed = index > 0
		seed.fuse = 1.0 if index == 1 else 0.2
		seed.exploded = index == 2
		seed.flash_remaining = 0.1
		scene.add_child(seed)
		seed.set_physics_process(false)
		seed.queue_redraw()
	_label(scene, "寄生种子 飞行/落地/爆炸", Vector2(1070, 640))

	var quills := preload("res://scripts/enemies/porcupine_quill_visual.gd").new()
	quills.position = Vector2(1060, 130)
	quills.enraged = true
	quills.elapsed = 0.06
	scene.add_child(quills)
	quills.set_process(false)
	await _capture("skills.png", 6)
	scene.free()


func _capture(file_name: String, frames: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for index in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s" % [OUTPUT_DIR, file_name])


class Arena:
	extends Node2D
	var title := ""
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.27, 0.36, 0.25))
		draw_string(ThemeDB.fallback_font, Vector2(24, 34), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

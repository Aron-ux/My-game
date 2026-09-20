extends SceneTree

const RUNTIME := preload("res://scripts/tests/boss_danmaku_test_runtime.gd")
const BATCH := preload("res://scripts/enemies/enemy_projectile_batch_simulation.gd")
const RENDERER := preload("res://scripts/enemies/boss_projectile_renderer.gd")
const ATTACKS := preload("res://scripts/enemies/enemy_boss_attacks.gd")
const PROJECTILES := preload("res://scripts/enemies/enemy_projectiles.gd")


func _init() -> void:
	call_deferred("_run")


func tick(scene, delta: float) -> void:
	scene.remove_meta(BATCH.BATCH_FRAME_META_KEY)
	BATCH.update_enemy_projectiles(scene, delta)


func _run() -> void:
	var gpu := DisplayServer.get_name() != "headless"
	var scene := RUNTIME.new()
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.player = RUNTIME.Target.new()
	scene.player.position = Vector2(500, 200)
	scene.add_child(scene.player)
	var boss = scene.make_boss()
	tick(scene, 0.01)
	var renderer = scene.get_meta(RENDERER.META_KEY)
	ATTACKS.fire_radial_burst(boss, 40)
	assert(renderer.members.size() == 40)
	var first = scene.active.values()[0]
	var original_slot: int = first.boss_render_slot
	var original: Dictionary = JSON.parse_string(JSON.stringify(first.get_save_data()))
	for bullet in scene.active.values():
		assert(bullet.get_child_count() == 1, "batched spawn avoids per-bullet visual layers")
	tick(scene, 0.1)
	var submitted: Transform2D = renderer.meshes[0].get_instance_transform_2d(original_slot)
	if gpu:
		assert(submitted.origin.distance_to(first.position) < 0.001, "production tick directly submits the current position")
	first.recycle()
	if gpu:
		assert(renderer.meshes[0].get_instance_transform_2d(original_slot).x == Vector2.ZERO, "pooled slot cannot render a ghost")
	first.reset_projectile({"position": Vector2(-50, 0), "direction": Vector2.RIGHT, "target": scene.player, "speed": 0.0, "visual_style": "boss_dark_core_orb", "source_enemy_archetype": "boss_spellcore", "lifetime": 10.0})
	assert(first.boss_render_slot == original_slot, "pool reuse keeps original draw order")

	# Ordinary bullets reused from the Boss pool recover their own renderer.
	first.recycle()
	first.reset_projectile({"position": Vector2(-50, 0), "target": scene.player, "visual_style": "solid_circle", "visual_color": Color.GREEN, "lifetime": 10.0})
	assert(first.boss_render_owner == null and first.get_node("Polygon2D").visible)
	assert(first.get_node("Polygon2D").color == Color.GREEN)
	first.free()
	renderer._compact_slots()
	assert(renderer.members.size() == 39)

	# Direct deletion followed by compaction must not clear another shot
	# when the queued node finally exits the tree.
	var doomed = scene.active.values()[0]
	doomed.queue_free()
	renderer._compact_slots()
	var survivor = renderer.members.values()[0]
	var survivor_slot: int = survivor.boss_render_slot
	var survivor_transform: Transform2D = renderer.meshes[0].get_instance_transform_2d(survivor_slot)
	await process_frame
	if gpu:
		assert(renderer.meshes[0].get_instance_transform_2d(survivor_slot) == survivor_transform)

	var loaded = RUNTIME.BULLET.instantiate()
	scene.add_child(loaded)
	loaded.apply_save_data(original, scene.player)
	assert(loaded.boss_render_owner == renderer and loaded.damage == original.damage)
	tick(scene, 0.01)
	if gpu:
		assert(renderer.meshes[0].get_instance_transform_2d(loaded.boss_render_slot).origin.distance_to(loaded.position) < 0.001)
	PROJECTILES.clear_projectiles_from_source(boss, 0.45)
	# First shot was not tagged with this source after its explicit reset.
	for bullet in renderer.members.values():
		bullet.begin_clear_fade(0.45)
	for frame in range(10):
		tick(scene, 0.05)
	assert(renderer.members.is_empty() and renderer.meshes[0].visible_instance_count == 0, "natural fading releases every rendered instance")
	ATTACKS.fire_radial_burst(boss, 20)
	tick(scene, 0.01)
	assert(renderer.members.size() == 20, "a new phase can reuse the cleared pool")
	scene.free()
	current_scene = null
	print("BOSS_PROJECTILE_RENDERER_LIFECYCLE_SMOKE_OK")
	quit(0)

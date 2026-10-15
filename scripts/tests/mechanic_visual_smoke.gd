extends SceneTree

const VISUAL := preload("res://assets/players/mechanic/mechanic.tscn")
const PLAYER := preload("res://scenes/player.tscn")
const ENEMY := preload("res://scenes/enemy.tscn")
const BULLET := preload("res://scripts/bullet.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var visual = VISUAL.instantiate()
	# The battle and camp callers can set movement before adding the scene.
	visual.set_moving(true, Vector2.LEFT)
	root.add_child(visual)
	var sprite: AnimatedSprite2D = visual.get_node("AnimatedSprite2D")
	assert(sprite.flip_h and sprite.animation == &"mechanic-run")
	visual.set_moving(false, Vector2.LEFT)
	assert(sprite.flip_h and sprite.animation == &"mechanic-idle", "stopping must not reverse facing")
	visual.play_command()
	visual.set_moving(true, Vector2.RIGHT)
	assert(not sprite.flip_h and sprite.animation == &"mechanic-command")
	sprite.set_frame_and_progress(2, 0.5)
	visual.play_command()
	assert(sprite.frame == 2, "rapid actions must not restart the command pose")
	await create_timer(0.25).timeout
	assert(sprite.animation == &"mechanic-run" and not visual.commanding, "command must resume current movement")
	visual.queue_free()

	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var player = PLAYER.instantiate()
	scene.add_child(player)
	player.set_physics_process(false)
	player.configure_story_loadout(["mechanic", "swordsman", "gunner"])
	player.active_role_index = 0
	player._update_active_role_state()
	player.facing_direction = Vector2(-1.0, -0.5).normalized()
	var turret = player.mechanic_tulip_turret_ability.deploy_turret(player)
	var cannon = player.mechanic_missile_volley_ability.deploy_cannon(player)
	var enemy = ENEMY.instantiate()
	enemy.position = Vector2(-240.0, -160.0)
	scene.add_child(enemy)
	enemy.set_physics_process(false)
	await process_frame
	player.mechanic_tulip_turret_ability._fire(player, {"node": turret})
	player.mechanic_missile_volley_ability._fire(player, {"node": cannon})
	var bullets: Array[Node2D] = []
	for child in scene.get_children():
		if child.get_script() == BULLET:
			bullets.append(child)
	assert(bullets.size() == 2, "both devices must fire at a live enemy")
	assert(bullets[0].global_position.is_equal_approx(turret.global_position + Vector2(-96.0, -90.0) * 0.35))
	assert(bullets[1].global_position.is_equal_approx(cannon.global_position + Vector2(-100.0, -82.0) * 0.65))
	for bullet in bullets:
		bullet.set_physics_process(false)
	for device in [turret, cannon]:
		var device_sprite: AnimatedSprite2D = device.get_node("AnimatedSprite2D")
		assert(device_sprite.flip_h and is_zero_approx(device_sprite.global_rotation), "left/up aim must keep chassis upright")
		device_sprite.play("fire")
		device_sprite.set_frame_and_progress(1, 0.0)
	await create_timer(0.3).timeout
	for device in [turret, cannon]:
		assert(device.get_node("AnimatedSprite2D").frame == 0, "fire must return to the resting barrel")
	var saved: Dictionary = player.mechanic_tulip_turret_ability.get_save_data()
	player.mechanic_tulip_turret_ability.apply_save_data(saved)
	player.mechanic_tulip_turret_ability.restore_effect_if_active(player)
	var restored: Node2D = player.mechanic_tulip_turret_ability.active_turrets[0]["node"]
	assert(restored.get_node("AnimatedSprite2D").flip_h)
	assert(is_zero_approx(restored.get_node("AnimatedSprite2D").global_rotation))
	scene.queue_free()
	await process_frame
	current_scene = null
	print("MECHANIC_VISUAL_SMOKE_OK")
	quit(0)

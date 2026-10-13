extends SceneTree

const MAGE := preload("res://scripts/enemies/enemy_skull_mage.gd")
const EFFECTS := preload("res://scripts/player/player_skull_mage_effects.gd")
const DOMAIN := preload("res://scripts/enemies/skull_mage_domain.gd")
const TIMERS := preload("res://scripts/player/player_timer_flow.gd")
var failures := 0


func _init() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := Arena.new()
	root.add_child(scene)
	current_scene = scene
	var player = preload("res://scenes/player.tscn").instantiate()
	scene.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.fire_timer.stop()
	player.auto_attack_enabled = false
	player._get_active_role()["base_dodge"] = 0.0
	player.position = Vector2(680, 365)
	player.get_node("Camera2D").enabled = false
	var enemy = preload("res://scenes/enemy.tscn").instantiate()
	enemy.target = player
	enemy.apply_enemy_profile("normal", preload("res://scripts/enemy/enemy_archetype_database.gd").get_profile("normal", "skull_mage"))
	scene.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.position = Vector2(600, 365)
	scene.enemies.append(enemy)
	var base_attack_speed: float = player._get_effective_attack_speed("swordsman")
	preload("res://scripts/enemies/enemy_damage.gd").apply_damage(enemy, 15, false)
	check(EFFECTS.get_cold_remaining(player) == 0, "no cold while ice is inactive")
	enemy.skull_mage_state.ice_cooldown = 0
	MAGE.update(enemy, 0)
	preload("res://scripts/enemies/enemy_damage.gd").apply_damage(enemy, 15, false)
	check(is_equal_approx(EFFECTS.get_cold_remaining(player), 2.7), "swordsman status resistance shortens cold")
	check(is_equal_approx(player._get_effective_attack_speed("swordsman"), base_attack_speed * 0.7), "real role attack speed includes cold")
	EFFECTS.tick(player, 3)
	check(is_equal_approx(player._get_effective_attack_speed("swordsman"), base_attack_speed), "role speed restores after cold")
	var field := DOMAIN.new()
	field.player = player
	field.position = enemy.position
	scene.add_child(field)
	field.set_physics_process(false)
	var ability = player.swordsman_knight_thrust_ability
	ability.cooldown_remaining = 10
	for index in 120:
		TIMERS.update_timers(player, 0.1)
		if index == 99:
			check(is_equal_approx(float(ability.cooldown_remaining), 10.0 / 6.0), "real skill remains cooling after ten seconds in domain")
	check(float(ability.cooldown_remaining) < 0.000001, "real skill ready at twelve seconds")
	ability.cooldown_remaining = 10
	player.position = Vector2(1000, 365)
	TIMERS.update_timers(player, 1)
	check(is_equal_approx(float(ability.cooldown_remaining), 9), "outside domain cooldown progresses normally")
	player.position = Vector2(680, 365)
	MAGE.reset(enemy)
	enemy.skull_mage_state.ice_cooldown = 0
	MAGE.update(enemy, 3)
	enemy.current_health = 40.0
	var drain_health_before: float = player.current_health + player.current_temporary_health
	MAGE.update(enemy, 1.0)
	var drain_loss: float = drain_health_before - player.current_health - player.current_temporary_health
	check(drain_loss > 0.0, "drain actually damages real player through one-argument API")
	check(is_equal_approx(enemy.current_health, 40.0 + drain_loss), "drain heals actual real-player damage")
	player.position = Vector2(851, 365)
	MAGE.update(enemy, 0.2)
	check(not MAGE.is_draining(enemy), "real player leaving250 ends drain without invalid call")
	player.position = Vector2(680, 365)
	enemy.skull_mage_state.drain_remaining = 8.0
	MAGE.sync_visual(enemy)
	await capture("life-drain", scene)
	MAGE.tick_passives(enemy, 1)
	enemy.skull_mage_state.drain_remaining = 0
	MAGE.sync_visual(enemy)
	await capture("ice-armor", scene)
	enemy.skull_mage_state.invulnerable_remaining = 2
	MAGE.sync_visual(enemy)
	await capture("death-body", scene)
	scene.free()
	current_scene = null
	if failures == 0:
		print("SKULL_MAGE_ACCEPTANCE_OK")
	quit(0 if failures == 0 else 1)


func capture(label: String, scene: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return
	scene.title = label
	scene.queue_redraw()
	for index in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/skull-mage-acceptance")
	root.get_texture().get_image().save_png("res://artifacts/skull-mage-acceptance/%s.png" % label)


class Arena:
	extends Node2D
	var difficulty_profile := {"tier": 3}
	var enemies: Array = []
	var title := ""
	func get_runtime_enemies() -> Array:
		return enemies
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.15, 0.19, 0.16))
		for x in range(0, 1280, 64):
			draw_line(Vector2(x, 0), Vector2(x, 720), Color(0.18, 0.22, 0.18))
		for y in range(0, 720, 64):
			draw_line(Vector2(0, y), Vector2(1280, y), Color(0.18, 0.22, 0.18))
		draw_string(ThemeDB.fallback_font, Vector2(32, 45), "Skull mage / " + title, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color.WHITE)

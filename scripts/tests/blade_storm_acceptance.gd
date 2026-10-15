extends SceneTree

const TOOLS := preload("res://scripts/developer/developer_build_tools.gd")
const SKILLS := preload("res://scripts/player/player_blessing_skill_state.gd")
const GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")
const BUILD := preload("res://scripts/player/player_blade_storm_build.gd")
var failures: Array[String] = []
var scene: Node2D
var player
var ability
var render := false
var request := {"kind": "skill", "role_id": "swordsman", "id": "swordsman_blade_storm"}

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func enemy_at(position: Vector2):
	var enemy = preload("res://scenes/enemy.tscn").instantiate()
	scene.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set_process(false)
	enemy.position = position
	enemy.current_health = 10000.0
	enemy.max_health = 10000.0
	enemy.armor = 0.0
	enemy.damage_reduction_rate = 0.0
	enemy.status_resistance = 0.0
	scene.enemies.append(enemy)
	GRID.cached_frame = -1
	return enemy

func configure(level: int, choices: Dictionary = {}) -> void:
	TOOLS.apply(player, request.merged({"operation": "set", "amount": level}))
	for stage in choices:
		TOOLS.apply(player, request.merged({"operation": "branch", "stage": int(stage), "choice": choices[stage]}))
	ability.stop()
	ability.cooldown_remaining = 0.0
	ability.breath_remaining = 0.0
	check(ability.try_trigger(player), "cast LV%d" % level)

func _run() -> void:
	render = DisplayServer.get_name() != "headless"
	root.size = Vector2i(1280, 720)
	scene = Arena.new()
	root.add_child(scene)
	current_scene = scene
	player = preload("res://scenes/player.tscn").instantiate()
	scene.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.fire_timer.stop()
	player.auto_attack_enabled = false
	player._get_active_role()["critical_chance"] = 0.0
	player.position = Vector2(640, 360)
	if player.has_node("Camera2D"):
		player.get_node("Camera2D").enabled = false
	SKILLS.force_unlock_skill(player, "blade_storm", 1)
	ability = player.swordsman_blade_storm_ability
	var inside = enemy_at(player.position + Vector2(149, 0))
	var outside = enemy_at(player.position + Vector2(151, 0))
	configure(0)
	ability.update(player, 0.3)
	check(inside.current_health < 10000.0, "LV0 hits inside radius150")
	check(is_equal_approx(outside.current_health, 10000.0), "LV0 excludes outside radius150")
	var damage: float = 10000.0 - inside.current_health
	check(is_equal_approx(damage, player._get_role_damage("swordsman") * 0.8), "LV0 actual tick equals 80% attack")
	var initial_serial: int = ability.serial
	ability.update(player, 2.4)
	check(ability.serial - initial_serial == 8, "LV0 total nine ticks over 2.7seconds")
	check(not ability.is_active(), "LV0 ends at2.7seconds")
	var pulled = enemy_at(player.position + Vector2(210, 0))
	var untouched = enemy_at(player.position + Vector2(221, 0))
	configure(4, {"4": "typhoon"})
	ability.update(player, 0.1)
	check(is_equal_approx(pulled.position.x, player.position.x + 204.0), "typhoon pulls60persecond")
	check(is_equal_approx(untouched.position.x, player.position.x + 221.0), "typhoon excludes radius221")
	var slowed = enemy_at(player.position + Vector2(299, 0))
	var no_slow = enemy_at(player.position + Vector2(301, 0))
	configure(9, {"4": "gale", "8": "breath", "9": "tornado"})
	ability.update(player, 0.1)
	check(is_equal_approx(slowed.slow_multiplier, 0.7), "gale slows radius299")
	check(is_equal_approx(no_slow.slow_multiplier, 1.0), "gale excludes radius301")
	check(is_equal_approx(player.get_role_armor("swordsman"), 40.0), "gale actual armor40")
	check(is_equal_approx(player._get_role_move_speed("swordsman"), 172.5), "gale actual movespeed+15%")
	check(is_equal_approx(player._get_role_dodge_chance("swordsman"), 0.321), "gale actual independent dodge+30%")
	await capture("gale-attached", 200.0)
	ability.update(player, 3.5)
	check(ability.detached and not player.is_swordsman_blade_storm_active(), "detach unblocks normal attacks")
	check(is_equal_approx(ability.breath_remaining, 15.0), "breath begins exactly on detachment")
	check(is_equal_approx(player.get_role_armor("swordsman"), 10.0), "gale self armor ends on detachment")
	check(is_equal_approx(player._get_role_move_speed("swordsman"), 165.0), "breath movespeed+10%")
	check(is_equal_approx(player._get_role_dodge_chance("swordsman"), 0.2725), "breath independent dodge+25%")
	ability.update(player, 1.0)
	await capture("tornado-detached", 200.0)
	ability.update(player, 2.6)
	check(not ability.effect.visible, "final storm disappears")
	await capture("breath-only", 0.0)
	ability.update(player, 15.0)
	check(is_equal_approx(player._get_effective_attack_speed("swordsman"), 0.7), "breath expiration restores base speed")
	var final: Array[String] = failures.duplicate()
	scene.queue_free()
	await process_frame
	for message in final:
		push_error(message)
	print("BLADE_STORM_ACCEPTANCE_OK" if final.is_empty() else "BLADE_STORM_ACCEPTANCE_FAILED")
	quit(0 if final.is_empty() else 1)

func capture(name: String, radius: float) -> void:
	if not render:
		return
	var overlay := Node2D.new()
	overlay.set_script(preload("res://scripts/tests/blade_storm_acceptance_overlay.gd"))
	scene.add_child(overlay)
	overlay.center = ability.cast_origin
	overlay.radius = radius
	overlay.queue_redraw()
	var label := Label.new()
	label.position = Vector2(24, 20)
	label.text = "%s | radius %.0f | green: damage boundary | breath %.1fs" % [name, radius, ability.breath_remaining]
	label.add_theme_font_size_override("font_size", 22)
	overlay.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/blade-storm-acceptance")
	root.get_texture().get_image().save_png("res://artifacts/blade-storm-acceptance/%s.png" % name)
	overlay.queue_free()

class Arena:
	extends Node2D
	var enemies: Array = []
	func get_runtime_enemies() -> Array:
		return enemies

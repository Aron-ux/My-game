extends SceneTree

const PLAYER := preload("res://scenes/player.tscn")
const STATS := preload("res://scripts/player/player_role_stat_flow.gd")
const BLESSINGS := preload("res://scripts/player/player_blessing_system.gd")
const EXPECTED := {
	"swordsman": [150.0, 25.0, 200.0],
	"gunner": [160.0, 20.0, 170.0],
	"mage": [140.0, 30.0, 170.0],
	"mechanic": [140.0, 23.0, 170.0]
}
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	for role_id in EXPECTED:
		var player = PLAYER.instantiate()
		scene.add_child(player)
		var team: Array = [role_id]
		for other in EXPECTED:
			if other != role_id and team.size() < 3:
				team.append(other)
		player.configure_story_loadout(team)
		var values: Array = EXPECTED[role_id]
		check(is_equal_approx(STATS.get_current_move_speed(player), values[0]), "%s actual movement uses new base" % role_id)
		check(is_equal_approx(STATS.get_role_damage(player, role_id), values[1]), "%s actual attack uses new base" % role_id)
		check(is_equal_approx(player.max_health, values[2]), "%s active max health uses new base" % role_id)
		check(is_equal_approx(player.current_health, values[2]), "%s starts with full increased health" % role_id)
		BLESSINGS.apply_blessing(player, "blazing_sun", 1)
		var expected_damage: float = STATS.get_role_damage(player, role_id)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(player.get_save_data()))
		for role in saved.roles:
			role.move_speed -= 10.0
			role.damage -= 5.0
			role.base_health -= 50.0
		saved.current_health = 37.0
		saved.role_health_values[role_id] = 37.0
		for repeat in range(2):
			player.apply_save_data(saved)
			check(is_equal_approx(STATS.get_current_move_speed(player), values[0]), "%s legacy load migrates movement once" % role_id)
			check(is_equal_approx(STATS.get_role_damage(player, role_id), expected_damage), "%s legacy load preserves blessing and adds base attack once" % role_id)
			check(is_equal_approx(player.max_health, values[2]) and is_equal_approx(player.current_health, 37.0), "%s migration raises max HP without changing saved damage taken" % role_id)
			saved = JSON.parse_string(JSON.stringify(player.get_save_data()))
		player.free()
	scene.free()
	current_scene = null
	if failures.is_empty():
		print("PLAYABLE_ROLE_BALANCE_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

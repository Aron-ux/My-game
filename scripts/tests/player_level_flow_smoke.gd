extends SceneTree

const PLAYER_LEVEL_FLOW := preload("res://scripts/player/player_level_flow.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_every_reached_level_grants_skill_point()
	if failures.is_empty():
		print("PLAYER_LEVEL_FLOW_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_every_reached_level_grants_skill_point() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var owner = preload("res://scenes/player.tscn").instantiate()
	world.add_child(owner)
	owner.configure_story_loadout(["swordsman", "gunner", "mage"])
	owner.set_process(false)
	owner.set_physics_process(false)
	PLAYER_LEVEL_FLOW.handle_reached_level(owner, 2)
	_expect_equal(owner.skill_points, 1, "each reached level should grant one skill point")
	_expect_equal(owner.pending_level_ups, 0, "level-up should not queue the old build menu")
	_expect_equal(owner.pending_level_talent_choices, 0, "level 2 should not queue a level talent")
	PLAYER_LEVEL_FLOW.handle_reached_level(owner, 3)
	_expect_equal(owner.skill_points, 2, "a second level should grant a second skill point")
	_expect_equal(owner.pending_level_ups, 0, "reached levels should not queue old upgrade menus")
	_expect_equal(owner.pending_level_talent_choices, 0, "level 3 should not queue a player-level talent")
	PLAYER_LEVEL_FLOW.handle_reached_level(owner, 6)
	_expect_equal(owner.skill_points, 3, "every level should add exactly one skill point")
	_expect_equal(owner.pending_level_ups, 0, "legacy build-menu queue should remain empty")
	_expect_equal(owner.pending_level_talent_choices, 0, "level 6 should not queue a player-level talent")
	for role_id in ["swordsman", "gunner", "mage"]:
		_expect_equal(owner.get_role_skill_points(role_id), 3, "Every role must earn points while in the background")
	_expect_equal(owner.spend_skill_point(), true, "Sword allocation must succeed")
	_expect_equal(owner.get_role_skill_points("swordsman"), 2, "Sword allocation must consume sword points")
	owner.active_role_index = 1
	_expect_equal(owner.skill_points, 3, "Switching to gunner must expose his independent points")
	_expect_equal(owner.get_frame_hud_summary().skill_points, 3, "HUD must use the controlled role's points")
	for index in range(3):
		owner.spend_skill_point()
	_expect_equal(owner.spend_skill_point(), false, "Gunner cannot borrow the other roles' points")
	owner.active_role_index = 2
	_expect_equal(owner.skill_points, 3, "Mage points must remain unspent")
	var snapshot: Dictionary = owner.get_save_data()
	owner.role_skill_points.clear()
	owner.apply_save_data(snapshot)
	_expect_equal(owner.role_skill_points, {"swordsman": 2, "gunner": 0, "mage": 3}, "Different role balances must survive saving")
	owner.apply_save_data(owner.get_save_data())
	_expect_equal(owner.role_skill_points, {"swordsman": 2, "gunner": 0, "mage": 3}, "Repeated loading must not grant more points")
	snapshot.erase("role_skill_points")
	snapshot["skill_points"] = 4
	snapshot["pending_level_ups"] = 1
	owner.apply_save_data(snapshot)
	_expect_equal(owner.role_skill_points, {"swordsman": 5, "gunner": 5, "mage": 5}, "Old shared remaining points must migrate once for each role")
	PLAYER_LEVEL_FLOW.handle_reached_level(owner, 7)
	_expect_equal(owner.role_skill_points, {"swordsman": 6, "gunner": 6, "mage": 6}, "Leveling after restoring must grant each role one point")
	world.free()


func _expect_equal(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: %s != %s" % [message, str(actual), str(expected)])

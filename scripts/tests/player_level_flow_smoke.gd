extends SceneTree

const PLAYER_LEVEL_FLOW := preload("res://scripts/player/player_level_flow.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_every_reached_level_queues_build_menu()
	if failures.is_empty():
		print("PLAYER_LEVEL_FLOW_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_every_reached_level_queues_build_menu() -> void:
	var owner := LevelOwnerStub.new()
	PLAYER_LEVEL_FLOW.handle_reached_level(owner, 2)
	_expect_equal(owner.pending_level_ups, 1, "level 2 should queue the build menu")
	_expect_equal(owner.pending_level_talent_choices, 0, "level 2 should not queue a level talent")
	PLAYER_LEVEL_FLOW.handle_reached_level(owner, 3)
	_expect_equal(owner.pending_level_ups, 2, "level 3 should still queue the build menu")
	_expect_equal(owner.pending_level_talent_choices, 1, "level 3 should queue one level talent")
	PLAYER_LEVEL_FLOW.handle_reached_level(owner, 6)
	_expect_equal(owner.pending_level_ups, 3, "level 6 should also queue the build menu")
	_expect_equal(owner.pending_level_talent_choices, 2, "level 6 should queue a second level talent")
	owner.free()


func _expect_equal(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: %s != %s" % [message, str(actual), str(expected)])


class LevelOwnerStub:
	extends Node

	var pending_level_ups: int = 0
	var pending_level_talent_choices: int = 0

	func queue_level_talent_choice(_reached_level: int) -> void:
		pending_level_talent_choices += 1

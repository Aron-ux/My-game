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
	if PLAYER_LEVEL_FLOW.should_offer_build_choice_for_level(2):
		failures.append("level 2 should be treated as a non-key level")
	if not PLAYER_LEVEL_FLOW.should_offer_build_choice_for_level(4):
		failures.append("level 4 should be treated as a key level")
	PLAYER_LEVEL_FLOW.handle_reached_level(owner, 2)
	_expect_equal(owner.pending_level_ups, 1, "level 2 should queue the build menu")
	PLAYER_LEVEL_FLOW.handle_reached_level(owner, 4)
	_expect_equal(owner.pending_level_ups, 2, "level 4 should also queue the build menu")
	owner.free()


func _expect_equal(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: %s != %s" % [message, str(actual), str(expected)])


class LevelOwnerStub:
	extends Node

	var pending_level_ups: int = 0

extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := HealingPlayer.new()
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.max_health = 100.0
	player.current_health = 50.0
	player.pending_heal_combat_text = 0.0
	player._heal(0.25)
	_check(is_equal_approx(player.current_health, 50.25), "fractional heal applies")
	_check(is_equal_approx(player.pending_heal_combat_text, 0.25), "fractional text accumulates")
	_check(player.tags.is_empty(), "fractional heal waits for whole point")
	player._heal(1.5)
	_check(player.tags == ["+1"], "whole heal is displayed")
	_check(is_equal_approx(player.pending_heal_combat_text, 0.75), "remainder is retained")
	player.current_health = 99.75
	player._heal(10.0)
	_check(is_equal_approx(player.current_health, 100.0), "overheal clamps to maximum")
	_check(player.tags == ["+1", "+1"], "only actual healing contributes to text")
	_check(is_zero_approx(player.pending_heal_combat_text), "accumulated remainder is consumed")
	player._heal(10.0)
	_check(player.tags.size() == 2, "full health produces no healing text")
	player.current_health = 50.0
	player.healing_block_remaining = 1.0
	player._heal(10.0)
	_check(is_equal_approx(player.current_health, 50.0), "healing block prevents recovery")
	player.healing_block_remaining = 0.0
	player.is_dead = true
	player._heal(10.0)
	_check(is_equal_approx(player.current_health, 50.0), "dead player cannot heal")
	player.is_dead = false
	player._heal(-5.0)
	player._heal(0.0)
	_check(is_equal_approx(player.current_health, 50.0), "nonpositive healing is ignored")
	_check(player.tags.size() == 2, "rejected healing produces no text")
	player.free()
	if failures.is_empty():
		print("PLAYER_HEAL_RUNTIME_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


class HealingPlayer:
	extends "res://scripts/player.gd"

	var tags: Array[String] = []

	func _spawn_forced_combat_tag(_position: Vector2, text: String, _color: Color) -> void:
		tags.append(text)

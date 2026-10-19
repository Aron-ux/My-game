extends SceneTree

const BUILD := preload("res://scripts/player/player_gunner_infinite_reload_build.gd")
const LEVELS := preload("res://scripts/player/player_skill_level_system.gd")
const TOOLS := preload("res://scripts/developer/developer_build_tools.gd")
const SKILLS := preload("res://scripts/player/player_blessing_skill_state.gd")
const EQUIPMENT := preload("res://scripts/player/player_equipment_flow.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _run() -> void:
	var arena := Arena.new()
	root.add_child(arena)
	current_scene = arena
	var player = preload("res://scenes/player.tscn").instantiate()
	arena.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.fire_timer.stop()
	player.auto_attack_enabled = false
	player.active_role_index = 1
	SKILLS.force_unlock_skill(player, "infinite_reload", 1)
	var ability := MeasuredAbility.new()
	player.gunner_infinite_reload_ability = ability
	check(BUILD.level(player) == 0 and is_equal_approx(BUILD.damage_ratio(player), 0.4), "unlock starts at LV0, 40%")
	check(ability.try_trigger(player), "base cast")
	check(ability.cooldown_remaining == 0.0, "no cooldown during cast")
	var original_direction := ability.locked_aim_direction
	ability.update(player, 4.0)
	check(ability.ticks == 16, "large frame preserves sixteen base ticks")
	check(ability.locked_aim_direction == original_direction, "base direction remains locked")
	check(not ability.is_active() and is_equal_approx(ability.cooldown_remaining, 36.0), "36s cooldown begins after cast")
	ability.stop()
	ability.cooldown_remaining = 0.0
	ability.ticks = 0
	ability.try_trigger(player)
	for frame in range(240):
		ability.update(player, 1.0 / 60.0)
	check(ability.ticks == 16 and not ability.is_active(), "normal 60 FPS updates preserve sixteen ticks")
	ability.stop()
	ability.cooldown_remaining = 0.0
	var request := {"kind": "skill", "role_id": "gunner", "id": BUILD.PROGRESS}
	for lv in range(1, 10):
		LEVELS.add_skill_level(player, "gunner", BUILD.PROGRESS)
		check(BUILD.level(player) == lv, "level %d" % lv)
		if lv in BUILD.STAGES:
			var offer := LEVELS.build_talent_offer_for(player, "gunner", BUILD.PROGRESS)
			check(offer.get("options", []).size() == 2, "two options at %d" % lv)
			check(not LEVELS.apply_option_with_result(player, offer["options"][0]["id"], offer).is_empty(), "select branch %d" % lv)
	check(BUILD.has_choice(player, "light_step") and BUILD.has_choice(player, "soul_form") and BUILD.has_choice(player, "fire_control"), "choices retained")
	check(is_equal_approx(BUILD.damage_ratio(player), 0.85) and BUILD.range_bonus(player) == 200.0, "light step LV9 ratio/range")
	var base_dodge: float = EQUIPMENT.get_role_dodge_chance(player, "gunner")
	check(ability.toggle_manual(player), "toggle on")
	check(is_equal_approx(EQUIPMENT.get_role_dodge_chance(player, "gunner"), minf(1.0, base_dodge + 0.3)), "dodge adds thirty percentage points")
	check(ability.is_soul_form_active() and ability.get_move_speed_multiplier(player) == 1.1, "active soul immunity and move speed")
	check(not ability.is_movement_locked(player) and not ability.is_blocking_actions(player), "no unintended movement or other skill lock")
	check(not ability.toggle_manual(player), "cannot close before one second")
	ability.update(player, 1.0)
	check(ability.toggle_manual(player) and not ability.is_active(), "close at one second")
	check(ability.cooldown_remaining == 0.0 and ability.toggle_manual(player), "immediate reopen without cooldown")
	ability.stop()
	var flow := preload("res://scripts/player/player_ability_flow.gd")
	var slot := flow.get_slot_skill_id(player, 1)
	var reload_slot := 1
	while slot != "infinite_reload" and reload_slot < 6:
		reload_slot += 1
		slot = flow.get_slot_skill_id(player, reload_slot)
	check(slot == "infinite_reload" and flow.try_handle_manual_skill_slot(player, reload_slot) and ability.is_active(), "toggle hotkey works without changing automatic setting")
	check(ability.get_cooldown_slot(player).get("toggle_mode", false), "HUD identifies toggle mode")
	ability.stop()
	for pair in [[4, "aim"], [8, "soul_impact"], [9, "dual_impact"]]:
		TOOLS.apply(player, request.merged({"operation": "branch", "stage": pair[0], "choice": pair[1]}))
	check(is_equal_approx(BUILD.damage_ratio(player), 1.05) and BUILD.range_bonus(player) == 200.0, "aim dual ratio/range")
	ability.ticks = 0
	check(ability.try_trigger(player), "dual cast")
	ability.desired = ability.locked_aim_direction.rotated(PI * 0.5)
	var before_turn := ability.locked_aim_direction
	ability.update(player, 0.1)
	check(is_equal_approx(absf(before_turn.angle_to(ability.locked_aim_direction)), deg_to_rad(15.0)), "aim turns fifteen degrees in .1 seconds")
	ability.update(player, 3.9)
	check(ability.ticks == 20, "dual fires twenty ticks")
	ability.stop()
	ability.cooldown_remaining = 0.0
	ability.try_trigger(player)
	ability.update(player, 0.13)
	var restored := MeasuredAbility.new()
	restored.apply_save_data(JSON.parse_string(JSON.stringify(ability.get_save_data())))
	check(restored.cast_snapshot == ability.cast_snapshot and restored.pending_beam_hits.size() == ability.pending_beam_hits.size(), "snapshot and delayed hit JSON roundtrip")
	check(is_equal_approx(restored.active_remaining, ability.active_remaining), "remaining duration roundtrip")
	ability.stop()
	var enemy = preload("res://scenes/enemy.tscn").instantiate()
	arena.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.max_health = 10000.0
	enemy.current_health = 10000.0
	enemy.armor = 1000.0
	enemy.damage_reduction_rate = 0.99
	enemy.vulnerability_bonus = 0.5
	enemy.take_soul_impact_damage(100.0)
	check(is_equal_approx(enemy.current_health, 9850.0), "soul damage skips armor/reduction, preserves 1.5 vulnerability")
	enemy.skull_damage_immune_timer = 1.0
	enemy.take_soul_impact_damage(100.0)
	check(is_equal_approx(enemy.current_health, 9850.0), "soul damage honors invulnerability")
	enemy.skull_damage_immune_timer = 0.0
	enemy.enemy_kind = "boss"
	enemy.boss_phase_transition_target = 2
	enemy.take_soul_impact_damage(100.0)
	check(is_equal_approx(enemy.current_health, 9850.0), "soul damage honors phase transition")
	enemy.boss_phase_transition_target = 0
	enemy.max_health = 30000.0
	enemy.current_health = 11000.0
	enemy.take_soul_impact_damage(100.0)
	check(is_equal_approx(enemy.current_health, 10850.0) and enemy.boss_direct_health_loss == 0.0, "soul impact consumes shield instead of bypassing it")
	enemy.max_health = 10000.0
	enemy.current_health = 9850.0
	enemy.enemy_kind = "normal"
	enemy.boss_phase_transition_target = 0
	enemy.armor = 0.0
	enemy.damage_reduction_rate = 0.0
	enemy.vulnerability_bonus = 0.0
	enemy.global_position = player.global_position + Vector2(100.0, 0.0)
	arena.enemies.append(enemy)
	preload("res://scripts/enemies/enemy_spatial_grid.gd").cached_frame = -1
	preload("res://scripts/player/player_damage_resolver.gd").cached_live_enemies_frame = -1
	ability.resolving_soul_impact = true
	var shapes: Array[Dictionary] = []
	for side in range(2):
		shapes.append({"type": "oriented_rect", "center": enemy.global_position, "axis": Vector2.RIGHT, "length": 100.0, "width": 100.0, "damage_amount": 10.0, "source_position": player.global_position, "soul_impact": true})
	# Compare two independently resolved lanes to two identical one-lane calls;
	# disable crit RNG so the current-health ordering is deterministic.
	player.roles[1]["critical_chance"] = 0.0
	seed(1234)
	ability._apply_piercing_beam_shapes(player, shapes)
	var dual_health: float = enemy.current_health
	enemy.current_health = 9850.0
	seed(1234)
	ability._apply_piercing_beam_shapes(player, [shapes[0]])
	ability._apply_piercing_beam_shapes(player, [shapes[1]])
	check(is_equal_approx(enemy.current_health, dual_health) and dual_health < 9660.0, "dual lanes resolve independent base and current-health hits")
	var bullet = preload("res://scripts/enemy_bullet.gd").new()
	bullet.target = player
	bullet._sync_source_enemy_archetype("shooter")
	ability.active_remaining = 1.0
	ability.cast_snapshot = {"choices": ["soul_form"]}
	check(bullet._soul_form_blocks_hit(), "soul form blocks shooter projectile")
	# Boss metadata overrides an otherwise ordinary projectile archetype.
	bullet.set_meta("source_enemy_kind", "boss")
	check(not bullet._soul_form_blocks_hit(), "boss projectiles remain dangerous")
	enemy.global_position = player.global_position
	check(preload("res://scripts/player/player_damage_resolver.gd").get_touching_enemy_hit(player, player.global_position, 100.0).is_empty(), "soul form blocks collision passive")
	ability.active_remaining = 4.0
	ability.cooldown_credit = 0.0
	enemy.current_health = 1.0
	shapes[0]["center"] = enemy.global_position
	shapes[0]["soul_form"] = true
	shapes[0]["soul_impact"] = false
	ability._apply_piercing_beam_shapes(player, [shapes[0]])
	check(is_equal_approx(ability.cooldown_credit, 0.3), "only infinite reload kill earns .3s cooldown credit")
	ability.cast_snapshot["cooldown"] = 36.0
	ability._finish_cast(player)
	check(is_equal_approx(ability.cooldown_remaining, 35.7), "cast kill credit applied when cooldown begins")
	bullet.free()
	ability.stop()
	TOOLS.apply(player, request.merged({"operation": "reset"}))
	check(BUILD.level(player) == 0 and BUILD.choices(player).is_empty(), "developer reset clears build")
	arena.queue_free()
	await process_frame
	for message in failures:
		push_error(message)
	print("GUNNER_INFINITE_RELOAD_BUILD_SMOKE_OK" if failures.is_empty() else "GUNNER_INFINITE_RELOAD_BUILD_SMOKE_FAILED")
	quit(0 if failures.is_empty() else 1)

class MeasuredAbility:
	extends "res://scripts/abilities/gunner_infinite_reload_ability.gd"
	var ticks := 0
	var desired := Vector2.ZERO
	func _desired_direction(owner) -> Vector2:
		return desired if desired != Vector2.ZERO else super._desired_direction(owner)
	func _trigger_tick(owner, overdue: float = 0.0) -> void:
		ticks += 1
		super._trigger_tick(owner, overdue)
	func _spawn_visuals(_owner, _origin: Vector2, _direction: Vector2, _length: float, _width: float) -> void:
		pass

class Arena:
	extends Node2D
	var enemies: Array = []
	func get_runtime_enemies() -> Array:
		return enemies

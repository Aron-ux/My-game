extends SceneTree

const BUILD := preload("res://scripts/player/player_blade_storm_build.gd")
const LEVELS := preload("res://scripts/player/player_skill_level_system.gd")
const TOOLS := preload("res://scripts/developer/developer_build_tools.gd")
const SKILLS := preload("res://scripts/player/player_blessing_skill_state.gd")
const STATUS := preload("res://scripts/enemies/enemy_status_effects.gd")
const SAVE := preload("res://scripts/enemies/enemy_save_data.gd")
const ABILITY := preload("res://scripts/abilities/swordsman_blade_storm_ability.gd")
const RESULT := preload("res://scripts/player/player_combat_result_flow.gd")
const PAYLOAD := preload("res://scripts/player/player_stat_payload.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _run() -> void:
	var scene := Arena.new()
	root.add_child(scene)
	current_scene = scene
	var player = preload("res://scenes/player.tscn").instantiate()
	scene.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.fire_timer.stop()
	player.auto_attack_enabled = false
	SKILLS.force_unlock_skill(player, "blade_storm", 1)
	check(LEVELS.get_skill_level(player, "swordsman", BUILD.PROGRESS) == 0, "unlock starts at LV0")
	var request := {"kind": "skill", "role_id": "swordsman", "id": BUILD.PROGRESS}
	for lv in range(1, 10):
		LEVELS.add_skill_level(player, "swordsman", BUILD.PROGRESS)
		check(BUILD.level(player) == lv, "level %d" % lv)
		if lv in BUILD.STAGES:
			var offer := LEVELS.build_talent_offer_for(player, "swordsman", BUILD.PROGRESS)
			check(offer["options"].size() == 2, "stage offers two branches")
			check(not LEVELS.apply_option_with_result(player, offer["options"][0]["id"], offer).is_empty(), "choose stage %d" % lv)
	check(is_equal_approx(BUILD.damage_ratio(player), 1.32), "typhoon rend LV9 damage 132%")
	var ability = player.swordsman_blade_storm_ability
	check(ability.get_buff_slot().is_empty(), "inactive breath has no buff icon")
	check(ability.try_trigger(player), "cast starts")
	check(is_equal_approx(ability.cooldown_remaining, 32.0), "base cooldown 32 seconds")
	ability.update(player, 3.6)
	check(ability.detached and not ability.is_active(), "detach restores basic attack")
	var origin: Vector2 = ability.cast_origin
	ability.update(player, 1.0)
	check(is_equal_approx(ability.cast_origin.distance_to(origin), 150.0), "detached speed 150")
	var loaded := ABILITY.new()
	loaded.apply_save_data(ability.get_save_data())
	check(loaded.detached and loaded.cast_choices == ability.cast_choices and loaded.cast_origin == ability.cast_origin, "moving tornado save restores")
	ability.update(player, 2.6)
	check(ability.active_remaining == 0.0, "detached duration equals attached")
	TOOLS.apply(player, request.merged({"operation": "branch", "stage": 4, "choice": "gale"}))
	TOOLS.apply(player, request.merged({"operation": "branch", "stage": 8, "choice": "breath"}))
	TOOLS.apply(player, request.merged({"operation": "branch", "stage": 9, "choice": "windblade"}))
	ability.cooldown_remaining = 0.0
	check(ability.try_trigger(player), "gale cast starts")
	check(is_equal_approx(ability.cast_radius, 200.0), "gale radius 200")
	check(is_equal_approx(player.get_role_armor("swordsman"), 40.0), "gale adds 30 to base armor 10")
	ability.update(player, 3.6)
	check(ability.breath_remaining > 14.9, "breath starts on storm end")
	var breath_slot: Dictionary = ability.get_buff_slot()
	check(breath_slot.get("name") == "风息" and is_equal_approx(breath_slot.get("duration", 0.0), 15.0), "breath buff exposes name and duration")
	check(PAYLOAD._build_buff_status_slots(player).has(breath_slot), "breath appears in HUD payload")
	var bar = preload("res://scripts/ui/hud/combat_skill_bar.gd").new()
	root.add_child(bar)
	bar.update_buff_slots([breath_slot])
	check(bar.buff_status_bar.visible and bar.buff_status_slots[0]["view"].visible, "breath uses visible HUD buff slot")
	check(bar.buff_status_slots[0]["title"] == "风息" and "剩余 15.0 / 15.0 秒" in bar.buff_status_slots[0]["description"], "breath HUD shows title and remaining time")
	check(is_equal_approx(player._get_effective_attack_speed("swordsman"), 1.0), "breath adds base speed .3")
	check(is_equal_approx(player._get_equipment_cooldown_multiplier(), 0.8), "breath gives cooldown reduction")
	var old_index: int = player.active_role_index
	player.active_role_index = 1
	check(is_equal_approx(BUILD.bonus(player, player._get_active_role_id(), "speed"), 0.3), "breath inherited on switch")
	check(PAYLOAD._build_buff_status_slots(player).has(breath_slot), "breath HUD survives role switch")
	player.active_role_index = old_index
	ability.update(player, 5.0)
	check(is_equal_approx(ability.get_buff_slot().get("remaining", 0.0), 10.0), "breath HUD follows remaining duration")
	bar.update_buff_slots([ability.get_buff_slot()])
	check(is_equal_approx(bar.buff_status_slots[0]["view"].fill_ratio, 10.0 / 15.0), "breath HUD progress follows timer")
	ability.update(player, 10.0)
	check(ability.get_buff_slot().is_empty(), "expired breath removes buff slot")
	bar.update_buff_slots([ability.get_buff_slot()] if not ability.get_buff_slot().is_empty() else [])
	check(not bar.buff_status_bar.visible and not bar.buff_status_slots[0]["view"].visible, "expired breath hides HUD buff")
	bar.queue_free()
	var enemy = preload("res://scenes/enemy.tscn").instantiate()
	scene.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.current_health = 10000.0
	enemy.max_health = 10000.0
	enemy.global_position = player.global_position
	scene.enemies.append(enemy)
	preload("res://scripts/enemies/enemy_spatial_grid.gd").cached_frame = -1
	TOOLS.apply(player, request.merged({"operation": "branch", "stage": 8, "choice": "rend"}))
	ability.cooldown_remaining = 0.0
	ability.breath_remaining = 0.0
	ability.try_trigger(player)
	ability._trigger_tick(player)
	check(enemy.storm_armor_shred_timers.size() == 1, "rend creates a layer after damage")
	STATUS.tick_timers(enemy, 1.0)
	ability._trigger_tick(player)
	check(enemy.storm_armor_shred_timers.size() == 2, "rend stacks")
	check(is_equal_approx(RESULT.hit_proc_multiplier(player), 1.0), "tick clears probability context")
	if enemy.storm_armor_shred_timers.size() == 2:
		check(is_equal_approx(enemy.storm_armor_shred_timers[0], 14.0) and is_equal_approx(enemy.storm_armor_shred_timers[1], 15.0), "layers keep independent timers")
	var save := SAVE.get_save_data(enemy)
	check(save["storm_armor_shred_timers"] == enemy.storm_armor_shred_timers, "save includes independent layers")
	STATUS.tick_timers(enemy, 14.1)
	check(enemy.storm_armor_shred_timers.size() == 1, "only expired layer removed")
	for index in range(100):
		enemy.storm_armor_shred_timers.append(15.0)
	check(enemy.storm_armor_shred_timers.size() == 101, "no stack limit")
	var restored_enemy = preload("res://scenes/enemy.tscn").instantiate()
	scene.add_child(restored_enemy)
	restored_enemy.set_physics_process(false)
	restored_enemy.set_process(false)
	SAVE.apply_save_data(restored_enemy, save, player)
	check(restored_enemy.storm_armor_shred_timers == save["storm_armor_shred_timers"], "load preserves layer times without shortening twice")
	var old_tick_count: int = ability.serial
	ability.tick_remaining = 0.3
	ability.active_remaining = 3.6
	ability.update(player, 3.6)
	check(ability.serial - old_tick_count == 12, "3.6 seconds delivers twelve ticks including final tick")
	loaded.apply_save_data(ability.get_save_data().merged({"breath_remaining": 10.0}, true))
	check(is_equal_approx(loaded.breath_remaining, 10.0), "breath duration survives save")
	player._push_attack_result_context_tag("windblade_double_proc")
	check(RESULT.hit_proc_multiplier(player) == 2.0, "windblade doubles probability")
	player._pop_attack_result_context_tag("windblade_double_proc")
	check(RESULT.hit_proc_multiplier(player) == 1.0, "double probability does not leak")
	TOOLS.apply(player, request.merged({"operation": "reset"}))
	check(BUILD.level(player) == 0 and BUILD.choices(player).is_empty(), "reset removes branches")
	scene.queue_free()
	await process_frame
	for message in failures:
		push_error(message)
	print("BLADE_STORM_BUILD_SMOKE_OK" if failures.is_empty() else "BLADE_STORM_BUILD_SMOKE_FAILED")
	quit(0 if failures.is_empty() else 1)

class Arena:
	extends Node2D
	var enemies: Array = []
	func get_runtime_enemies() -> Array:
		return enemies

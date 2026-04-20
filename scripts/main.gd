extends Node2D

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const STORY_PREP_SCENE_PATH := "res://scenes/story_prep.tscn"
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const STORY_DATA := preload("res://scripts/story_data.gd")
const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const CONTINUE_BGM_RESUME_DELAY := 0.25
const STAGE_DURATION := 600.0
const ELITE_SPAWN_TIMES := [72.0, 148.0, 228.0, 312.0, 394.0, 452.0]
const BOSS_SPAWN_TIME := 480.0

@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var enemy_bullet_scene: PackedScene = preload("res://scenes/enemy_bullet.tscn")
@export var exp_gem_scene: PackedScene = preload("res://scenes/exp_gem.tscn")
@export var heart_pickup_scene: PackedScene = preload("res://scenes/heart_pickup.tscn")
@export var hud_scene: PackedScene = preload("res://scenes/hud.tscn")
@export var level_up_ui_scene: PackedScene = preload("res://scenes/level_up_ui.tscn")
@export var pause_menu_scene: PackedScene = preload("res://scenes/pause_menu.tscn")
@export var game_over_ui_scene: PackedScene = preload("res://scenes/game_over_ui.tscn")
@export var starting_spawn_interval: float = 1.14
@export var minimum_spawn_interval: float = 0.28
@export var spawn_interval_drop_per_second: float = 0.0013
@export var spawn_distance: float = 350.0
@export var enemy_health_scale_per_minute: float = 0.4
@export var enemy_speed_scale_per_minute: float = 0.14
@export var autosave_interval: float = 2.0

var player
var spawn_timer: Timer
var hud
var level_up_ui
var pause_menu
var game_over_ui
var rng := RandomNumberGenerator.new()
var survival_time: float = 0.0
var autosave_elapsed: float = 0.0
var game_over: bool = false
var loaded_from_save: bool = false
var spawned_elite_count: int = 0
var boss_spawned: bool = false
var stage_cleared: bool = false
var boss_enemy: Node2D
var reward_context: String = ""
var developer_exp_gem_elapsed: float = 0.0
var story_stage: Dictionary = {}
var story_mode_active: bool = false
var suppress_exit_save: bool = false

func _ready() -> void:
	rng.randomize()
	player = _find_player()

	if player == null:
		push_error("Main.gd could not find a player node.")
		return

	_load_story_stage_context()
	_apply_story_loadout()

	_setup_spawn_timer()
	_setup_ui()
	_connect_player_signals()

	var should_continue: bool = SAVE_MANAGER.consume_continue_request() and SAVE_MANAGER.has_save()
	if should_continue and _load_saved_run():
		loaded_from_save = true
		_show_pause_menu_after_continue()
	else:
		loaded_from_save = false
		_start_game_bgm()

	if _is_developer_mode():
		_activate_developer_mode()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not game_over:
			_save_run_state()

func _exit_tree() -> void:
	if not game_over and not suppress_exit_save:
		_save_run_state()

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_handle_escape_toggle()
		elif event.physical_keycode == KEY_QUOTELEFT:
			if hud != null and hud.has_method("toggle_advanced_display"):
				hud.toggle_advanced_display()

func _process(delta: float) -> void:
	if game_over or get_tree().paused:
		return

	survival_time += delta
	autosave_elapsed += delta
	if _is_developer_mode():
		_update_developer_mode(delta)
	else:
		_update_spawn_curve()
		_handle_stage_events()

	if autosave_elapsed >= autosave_interval:
		autosave_elapsed = 0.0
		_save_run_state()

	if hud != null and hud.has_method("update_time"):
		hud.update_time(survival_time)
	if hud != null and hud.has_method("update_difficulty"):
		hud.update_difficulty(spawn_timer.wait_time, _get_enemy_power_multiplier())
	if hud != null and hud.has_method("update_stats") and player != null and player.has_method("get_stat_summary"):
		hud.update_stats(player.get_stat_summary())
	_update_boss_hud()

func _setup_spawn_timer() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = starting_spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_spawn_enemy)
	add_child(spawn_timer)

func _setup_ui() -> void:
	if hud_scene != null:
		hud = hud_scene.instantiate()
		add_child(hud)

	if level_up_ui_scene != null:
		level_up_ui = level_up_ui_scene.instantiate()
		add_child(level_up_ui)
		if level_up_ui.has_signal("upgrade_selected"):
			level_up_ui.connect("upgrade_selected", _on_upgrade_selected)

	if pause_menu_scene != null:
		pause_menu = pause_menu_scene.instantiate()
		add_child(pause_menu)
		if pause_menu.has_signal("resume_requested"):
			pause_menu.connect("resume_requested", _on_resume_requested)
		if pause_menu.has_signal("restart_requested"):
			pause_menu.connect("restart_requested", _on_restart_requested)
		if pause_menu.has_signal("main_menu_requested"):
			pause_menu.connect("main_menu_requested", _on_main_menu_requested)

	if game_over_ui_scene != null:
		game_over_ui = game_over_ui_scene.instantiate()
		add_child(game_over_ui)
		if game_over_ui.has_signal("restart_requested"):
			game_over_ui.connect("restart_requested", _on_restart_requested)

func _connect_player_signals() -> void:
	if player.has_signal("experience_changed"):
		player.experience_changed.connect(_on_player_experience_changed)
	if player.has_signal("level_up_requested"):
		player.level_up_requested.connect(_on_player_level_up_requested)
	if player.has_signal("stats_changed"):
		player.stats_changed.connect(_on_player_stats_changed)
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)
	if player.has_signal("mana_changed"):
		player.mana_changed.connect(_on_player_mana_changed)
	if player.has_signal("died"):
		player.died.connect(_on_player_died)

	_refresh_hud()

func _refresh_hud() -> void:
	if hud != null and hud.has_method("update_display"):
		hud.update_display(player.level, player.experience, player.experience_to_next_level)
	if hud != null and hud.has_method("update_stats"):
		hud.update_stats(player.get_stat_summary())
	if hud != null and hud.has_method("update_health"):
		hud.update_health(player.current_health, player.max_health)
	if hud != null and hud.has_method("update_mana"):
		hud.update_mana(player.current_mana, player.max_mana)
	if hud != null and hud.has_method("update_time"):
		hud.update_time(survival_time)
	if hud != null and hud.has_method("update_difficulty"):
		hud.update_difficulty(spawn_timer.wait_time, _get_enemy_power_multiplier())
	_update_boss_hud()

func _update_boss_hud() -> void:
	if hud == null:
		return

	if boss_enemy != null and not is_instance_valid(boss_enemy):
		boss_enemy = null
		boss_spawned = false

	if boss_enemy != null and is_instance_valid(boss_enemy):
		var boss_name := "Boss"
		var current_health := float(boss_enemy.get("current_health"))
		var max_health := float(boss_enemy.get("max_health"))
		if boss_enemy.has_method("get_boss_ui_payload"):
			var payload: Dictionary = boss_enemy.get_boss_ui_payload()
			boss_name = str(payload.get("name", boss_name))
			current_health = float(payload.get("current_health", current_health))
			max_health = float(payload.get("max_health", max_health))
		if hud.has_method("show_boss_ui"):
			hud.show_boss_ui(boss_name, current_health, max_health)
	else:
		if hud.has_method("hide_boss_ui"):
			hud.hide_boss_ui()

func _handle_escape_toggle() -> void:
	if pause_menu == null:
		return
	if level_up_ui != null and level_up_ui.visible:
		return
	if game_over_ui != null and game_over_ui.visible:
		return

	if pause_menu.visible:
		_resume_game()
	else:
		_pause_game_bgm()
		get_tree().paused = true
		pause_menu.show_ui()

func _show_pause_menu_after_continue() -> void:
	if pause_menu != null:
		_pause_game_bgm()
		get_tree().paused = true
		pause_menu.show_ui()

func _resume_game() -> void:
	if pause_menu != null and pause_menu.has_method("hide_ui"):
		pause_menu.hide_ui()
	get_tree().paused = false

	var resume_delay: float = 0.0

	if loaded_from_save and player != null and player.has_method("resume_pending_level_ups"):
		player.resume_pending_level_ups()
		resume_delay = CONTINUE_BGM_RESUME_DELAY
		loaded_from_save = false

	_resume_game_bgm(resume_delay)

func _update_spawn_curve() -> void:
	if spawn_timer == null:
		return
	if _is_developer_mode():
		spawn_timer.stop()
		return
	if boss_spawned and is_instance_valid(boss_enemy):
		spawn_timer.stop()
		return

	var wave_profile := _get_wave_profile()
	var stage_ratio: float = clamp(survival_time / _get_effective_stage_curve_time(), 0.0, 1.0)
	var base_interval := lerpf(starting_spawn_interval, minimum_spawn_interval, stage_ratio)
	var target_interval: float = max(minimum_spawn_interval, base_interval * float(wave_profile.get("interval_scale", 1.0)) * _get_story_spawn_interval_multiplier())
	spawn_timer.wait_time = target_interval
	if spawn_timer.is_stopped() and not game_over:
		spawn_timer.start()

func _handle_stage_events() -> void:
	if _is_developer_mode():
		return
	if story_mode_active and str(story_stage.get("type", "")) == "normal" and not stage_cleared and survival_time >= float(story_stage.get("target_time", 0.0)):
		_on_stage_cleared()
		return
	while spawned_elite_count < ELITE_SPAWN_TIMES.size() and survival_time >= float(ELITE_SPAWN_TIMES[spawned_elite_count]):
		_spawn_special_enemy("elite")
		spawned_elite_count += 1

	if not boss_spawned and survival_time >= _get_effective_boss_spawn_time():
		boss_spawned = true
		boss_enemy = _spawn_special_enemy("boss")
		if spawn_timer != null:
			spawn_timer.stop()

func _spawn_enemy() -> void:
	if game_over or enemy_scene == null or player == null or _is_developer_mode() or (boss_spawned and is_instance_valid(boss_enemy)):
		return

	var minutes_survived: float = survival_time / 60.0
	var health_multiplier: float = (1.0 + minutes_survived * enemy_health_scale_per_minute) * _get_story_enemy_health_multiplier()
	var speed_multiplier: float = (1.0 + minutes_survived * enemy_speed_scale_per_minute) * _get_story_enemy_speed_multiplier()
	var wave_profile := _get_wave_profile()
	var archetype := _pick_normal_archetype(wave_profile)
	var pack_count: int = 1
	if archetype == "swarm":
		pack_count = rng.randi_range(int(wave_profile.get("swarm_min", 8)), int(wave_profile.get("swarm_max", 14)))
	elif rng.randf() < float(wave_profile.get("pack_chance", 0.0)):
		pack_count += rng.randi_range(1, int(wave_profile.get("pack_bonus_max", 2)))
	_spawn_wave_pack("normal", archetype, pack_count, health_multiplier, speed_multiplier)

func _spawn_special_enemy(kind: String) -> Node2D:
	var minutes_survived: float = survival_time / 60.0
	var health_multiplier: float = (1.0 + minutes_survived * enemy_health_scale_per_minute) * _get_story_enemy_health_multiplier()
	var speed_multiplier: float = (1.0 + minutes_survived * enemy_speed_scale_per_minute) * _get_story_enemy_speed_multiplier()
	match kind:
		"elite":
			return _spawn_configured_enemy(kind, _pick_elite_archetype(), health_multiplier * 1.65, speed_multiplier * 1.06)
		"boss":
			return _spawn_configured_enemy(kind, "boss_spellcore", health_multiplier * 2.25, speed_multiplier * 1.0)
		_:
			return _spawn_configured_enemy(kind, "chaser", health_multiplier, speed_multiplier)

func _spawn_wave_pack(kind: String, archetype: String, count: int, health_multiplier: float, speed_multiplier: float) -> void:
	var base_angle: float = rng.randf_range(0.0, TAU)
	for index in range(count):
		var angle := base_angle + rng.randf_range(-0.34, 0.34) + float(index) * 0.05
		var distance_offset := rng.randf_range(-18.0, 36.0)
		_spawn_configured_enemy(kind, archetype, health_multiplier, speed_multiplier, angle, distance_offset)

func _spawn_configured_enemy(kind: String, archetype: String, health_multiplier: float, speed_multiplier: float, spawn_angle: float = INF, distance_offset: float = 0.0) -> Node2D:
	var enemy = enemy_scene.instantiate()
	if enemy == null:
		return null

	enemy.target = player
	enemy.projectile_scene = enemy_bullet_scene
	enemy.heart_pickup_scene = heart_pickup_scene
	if enemy.has_method("apply_enemy_profile"):
		enemy.apply_enemy_profile(kind, _get_enemy_profile(kind, archetype))
	enemy.max_health *= health_multiplier
	enemy.current_health = enemy.max_health
	enemy.speed *= speed_multiplier
	if enemy.has_signal("defeated"):
		enemy.defeated.connect(_on_enemy_defeated.bind(enemy))

	var angle: float = spawn_angle if is_finite(spawn_angle) else rng.randf_range(0.0, TAU)
	var distance: float = spawn_distance + (100.0 if kind == "boss" else 0.0) + distance_offset
	enemy.global_position = _get_spawn_position(angle, distance)
	add_child(enemy)
	return enemy

func _pick_normal_archetype(wave_profile: Dictionary) -> String:
	return str(_weighted_pick(wave_profile.get("weights", {"chaser": 1.0}), "chaser"))

func _pick_elite_archetype() -> String:
	var choices := ["artillery_dasher", "siege_engine", "berserk_ram"]
	if survival_time >= 360.0:
		choices.append("storm_vanguard")
	return str(choices[rng.randi_range(0, choices.size() - 1)])

func _get_wave_profile() -> Dictionary:
	var profile: Dictionary
	if survival_time < 70.0:
		profile = {
			"interval_scale": 1.06,
			"weights": {"chaser": 7.0, "swarm": 3.0},
			"swarm_min": 6,
			"swarm_max": 9,
			"pack_chance": 0.08,
			"pack_bonus_max": 1
		}
	elif survival_time < 140.0:
		profile = {
			"interval_scale": 0.98,
			"weights": {"chaser": 6.0, "shooter": 1.4, "swarm": 2.2},
			"swarm_min": 8,
			"swarm_max": 12,
			"pack_chance": 0.14,
			"pack_bonus_max": 2
		}
	elif survival_time < 210.0:
		profile = {
			"interval_scale": 0.9,
			"weights": {"chaser": 4.5, "shooter": 2.8, "accelerator": 1.0, "swarm": 2.0},
			"swarm_min": 9,
			"swarm_max": 13,
			"pack_chance": 0.2,
			"pack_bonus_max": 2
		}
	elif survival_time < 280.0:
		profile = {
			"interval_scale": 0.82,
			"weights": {"chaser": 2.8, "shooter": 3.0, "accelerator": 2.2, "swarm": 3.4, "dasher": 0.6},
			"swarm_min": 11,
			"swarm_max": 16,
			"pack_chance": 0.26,
			"pack_bonus_max": 3
		}
	elif survival_time < 340.0:
		profile = {
			"interval_scale": 0.74,
			"weights": {"chaser": 1.8, "shooter": 2.8, "accelerator": 3.0, "swarm": 3.0, "dasher": 1.8},
			"swarm_min": 12,
			"swarm_max": 18,
			"pack_chance": 0.3,
			"pack_bonus_max": 3
		}
	elif survival_time < 400.0:
		profile = {
			"interval_scale": 0.66,
			"weights": {"shooter": 3.0, "accelerator": 3.8, "swarm": 2.4, "dasher": 2.8},
			"swarm_min": 14,
			"swarm_max": 20,
			"pack_chance": 0.34,
			"pack_bonus_max": 4
		}
	elif survival_time < 480.0:
		profile = {
			"interval_scale": 0.58,
			"weights": {"shooter": 3.2, "accelerator": 4.0, "swarm": 2.2, "dasher": 3.4},
			"swarm_min": 14,
			"swarm_max": 18,
			"pack_chance": 0.36,
			"pack_bonus_max": 4
		}
	else:
		profile = {
			"interval_scale": 0.52,
			"weights": {"shooter": 3.0, "accelerator": 4.0, "swarm": 2.0, "dasher": 3.6},
			"swarm_min": 14,
			"swarm_max": 18,
			"pack_chance": 0.36,
			"pack_bonus_max": 4
		}
	return _apply_growth_adjustment(profile)

func _apply_growth_adjustment(base_profile: Dictionary) -> Dictionary:
	var adjusted := base_profile.duplicate(true)
	var score := _get_player_growth_score()
	var expected_score := _get_expected_growth_score()
	var delta := score - expected_score
	var weights: Dictionary = adjusted.get("weights", {}).duplicate(true)

	if delta <= -2.6:
		adjusted["interval_scale"] = float(adjusted.get("interval_scale", 1.0)) + 0.08
		adjusted["pack_chance"] = max(0.02, float(adjusted.get("pack_chance", 0.0)) - 0.08)
		adjusted["swarm_max"] = max(int(adjusted.get("swarm_min", 8)), int(adjusted.get("swarm_max", 10)) - 2)
		_tune_weight(weights, "chaser", 1.18)
		_tune_weight(weights, "swarm", 1.08)
		_tune_weight(weights, "shooter", 0.9)
		_tune_weight(weights, "accelerator", 0.72)
		_tune_weight(weights, "dasher", 0.6)
	elif delta >= 2.6:
		adjusted["interval_scale"] = max(0.46, float(adjusted.get("interval_scale", 1.0)) - 0.07)
		adjusted["pack_chance"] = min(0.58, float(adjusted.get("pack_chance", 0.0)) + 0.08)
		adjusted["swarm_max"] = int(adjusted.get("swarm_max", 10)) + 1
		_tune_weight(weights, "chaser", 0.84)
		_tune_weight(weights, "swarm", 0.92)
		_tune_weight(weights, "shooter", 1.14)
		_tune_weight(weights, "accelerator", 1.26)
		_tune_weight(weights, "dasher", 1.3)
		if survival_time >= 110.0 and not weights.has("accelerator"):
			weights["accelerator"] = 0.8
		if survival_time >= 205.0 and not weights.has("dasher"):
			weights["dasher"] = 0.5

	adjusted["weights"] = weights
	return adjusted

func _tune_weight(weights: Dictionary, key: String, multiplier: float) -> void:
	if not weights.has(key):
		return
	weights[key] = max(0.0, float(weights.get(key, 0.0)) * multiplier)

func _get_player_growth_score() -> float:
	if player == null:
		return 0.0

	var summary: Dictionary = {}
	if player.has_method("get_stat_summary"):
		summary = player.get_stat_summary()

	var score := 0.0
	score += max(0, int(player.level) - 1) * 0.95
	score += int(summary.get("body_build_level", 0)) * 0.7
	score += int(summary.get("combat_build_level", 0)) * 0.75
	score += int(summary.get("skill_build_level", 0)) * 0.8
	score += _count_unlocked_entries(player.slot_resonances_unlocked) * 1.4
	score += _count_unlocked_entries(player.elite_relics_unlocked) * 1.7
	score += float(summary.get("bullet_damage", 0.0)) / 18.0
	return score

func _get_expected_growth_score() -> float:
	var build_ratio: float = clamp(min(survival_time, BOSS_SPAWN_TIME) / BOSS_SPAWN_TIME, 0.0, 1.0)
	var expected := 1.4 + build_ratio * 17.5
	if survival_time >= 140.0:
		expected += 0.8
	if survival_time >= 280.0:
		expected += 0.9
	if survival_time >= 400.0:
		expected += 0.8
	return expected

func _count_unlocked_entries(unlock_map: Dictionary) -> int:
	var count := 0
	for value in unlock_map.values():
		if bool(value):
			count += 1
	return count

func _weighted_pick(weight_map: Dictionary, fallback: String) -> String:
	var total_weight: float = 0.0
	for value in weight_map.values():
		total_weight += float(value)
	if total_weight <= 0.0:
		return fallback

	var roll := rng.randf() * total_weight
	var cumulative: float = 0.0
	for key in weight_map.keys():
		cumulative += float(weight_map[key])
		if roll <= cumulative:
			return str(key)
	return fallback

func _get_spawn_position(angle: float, distance: float) -> Vector2:
	return player.global_position + Vector2.RIGHT.rotated(angle) * max(180.0, distance)

func _make_profile(base: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var merged := base.duplicate(true)
	for key in extra.keys():
		merged[key] = extra[key]
	return merged

func _get_enemy_profile(kind: String, archetype: String) -> Dictionary:
	match archetype:
		"shooter":
			return _make_profile({
				"archetype": "shooter",
				"behavior": "shooter",
				"max_health": 22.0,
				"speed": 68.0,
				"touch_damage": 10.0,
				"contact_radius": 34.0,
				"reward_tier": 2,
				"experience_reward": 9,
				"scale": 0.95,
				"preferred_distance": 230.0,
				"shot_interval": 2.1,
				"projectile_speed": 240.0,
				"projectile_damage": 8.0,
				"projectile_lifetime": 4.2,
				"projectile_spread": 0.0,
				"projectile_count": 1,
				"color": Color(1.0, 0.54, 0.32, 1.0)
			})
		"accelerator":
			return _make_profile({
				"archetype": "accelerator",
				"behavior": "accelerator",
				"max_health": 54.0,
				"speed": 70.0,
				"touch_damage": 15.0,
				"contact_radius": 40.0,
				"reward_tier": 3,
				"experience_reward": 18,
				"scale": 1.2,
				"acceleration_interval": 2.9,
				"acceleration_boost": 2.2,
				"acceleration_duration": 0.95,
				"color": Color(0.96, 0.8, 0.28, 1.0)
			})
		"swarm":
			return _make_profile({
				"archetype": "swarm",
				"behavior": "swarm",
				"max_health": 7.0,
				"speed": 122.0,
				"touch_damage": 7.0,
				"contact_radius": 28.0,
				"reward_tier": 1,
				"experience_reward": 4,
				"scale": 0.72,
				"color": Color(0.84, 0.96, 1.0, 1.0)
			})
		"dasher":
			return _make_profile({
				"archetype": "dasher",
				"behavior": "dash",
				"max_health": 66.0,
				"speed": 76.0,
				"touch_damage": 17.0,
				"contact_radius": 42.0,
				"reward_tier": 3,
				"experience_reward": 18,
				"scale": 1.28,
				"dash_interval": 3.1,
				"dash_duration": 0.42,
				"dash_speed_multiplier": 2.9,
				"color": Color(1.0, 0.36, 0.42, 1.0)
			})
		"artillery_dasher":
			return _make_profile({
				"archetype": "shooter",
				"behavior": "shooter",
				"secondary_behavior": "dash",
				"max_health": 210.0,
				"speed": 86.0,
				"touch_damage": 22.0,
				"contact_radius": 48.0,
				"reward_tier": 4,
				"experience_reward": 40,
				"scale": 1.58,
				"preferred_distance": 250.0,
				"shot_interval": 1.45,
				"projectile_speed": 270.0,
				"projectile_damage": 11.0,
				"projectile_lifetime": 4.6,
				"projectile_spread": 0.16,
				"projectile_count": 3,
				"dash_interval": 3.5,
				"dash_duration": 0.46,
				"dash_speed_multiplier": 3.0,
				"color": Color(1.0, 0.62, 0.32, 1.0)
			})
		"siege_engine":
			return _make_profile({
				"archetype": "accelerator",
				"behavior": "accelerator",
				"secondary_behavior": "shooter",
				"max_health": 260.0,
				"speed": 74.0,
				"touch_damage": 24.0,
				"contact_radius": 52.0,
				"reward_tier": 4,
				"experience_reward": 40,
				"scale": 1.7,
				"preferred_distance": 215.0,
				"shot_interval": 1.9,
				"projectile_speed": 250.0,
				"projectile_damage": 10.0,
				"projectile_lifetime": 4.8,
				"projectile_spread": 0.08,
				"projectile_count": 2,
				"acceleration_interval": 2.5,
				"acceleration_boost": 2.1,
				"acceleration_duration": 1.05,
				"color": Color(1.0, 0.72, 0.28, 1.0)
			})
		"berserk_ram":
			return _make_profile({
				"archetype": "dasher",
				"behavior": "dash",
				"secondary_behavior": "accelerator",
				"max_health": 320.0,
				"speed": 80.0,
				"touch_damage": 28.0,
				"contact_radius": 56.0,
				"reward_tier": 4,
				"experience_reward": 40,
				"scale": 1.82,
				"dash_interval": 2.7,
				"dash_duration": 0.5,
				"dash_speed_multiplier": 3.3,
				"acceleration_interval": 2.3,
				"acceleration_boost": 1.95,
				"acceleration_duration": 1.1,
				"color": Color(1.0, 0.44, 0.34, 1.0)
			})
		"storm_vanguard":
			return _make_profile({
				"archetype": "accelerator",
				"behavior": "accelerator",
				"secondary_behavior": "dash",
				"max_health": 340.0,
				"speed": 84.0,
				"touch_damage": 30.0,
				"contact_radius": 58.0,
				"reward_tier": 4,
				"experience_reward": 40,
				"scale": 1.9,
				"acceleration_interval": 2.0,
				"acceleration_boost": 2.2,
				"acceleration_duration": 1.2,
				"dash_interval": 2.9,
				"dash_duration": 0.54,
				"dash_speed_multiplier": 3.2,
				"color": Color(1.0, 0.58, 0.36, 1.0)
			})
		"boss_spellcore":
			return _make_profile({
				"archetype": "boss_spellcore",
				"behavior": "boss",
				"boss_name": "祸月星核",
				"max_health": 4800.0,
				"speed": 78.0,
				"touch_damage": 28.0,
				"contact_radius": 64.0,
				"reward_tier": 4,
				"experience_reward": 40,
				"scale": 2.35,
				"preferred_distance": 230.0,
				"projectile_damage": 13.5,
				"boss_radial_interval": 0.78,
				"boss_radial_bullets": 16,
				"boss_sine_interval": 2.9,
				"boss_sine_stream_duration": 1.7,
				"boss_sine_stream_rate": 0.12,
				"boss_turning_interval": 4.2,
				"boss_turning_bullets": 9,
				"color": Color(0.95, 0.2, 0.24, 1.0)
			})
		_:
			return _make_profile({
				"archetype": "chaser",
				"behavior": "chaser",
				"max_health": 30.0,
				"speed": 90.0,
				"touch_damage": 11.0,
				"contact_radius": 36.0,
				"reward_tier": 1,
				"experience_reward": 4,
				"scale": 1.0,
				"color": Color(0.34, 0.8, 1.0, 1.0)
			})

func _save_run_state() -> void:
	if game_over or player == null or DEVELOPER_MODE.should_disable_save():
		return

	var game_bgm = _get_game_bgm()
	var music_position: float = 0.0
	if game_bgm != null and game_bgm.has_method("get_saved_playback_position"):
		music_position = float(game_bgm.get_saved_playback_position())

	var save_data: Dictionary = {
		"survival_time": survival_time,
		"music_position": music_position,
		"spawned_elite_count": spawned_elite_count,
		"boss_spawned": boss_spawned,
		"player": player.get_save_data(),
		"enemies": [],
		"enemy_projectiles": [],
		"gems": [],
		"heart_pickups": []
	}

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("get_save_data"):
			save_data["enemies"].append(enemy.get_save_data())

	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(projectile) and projectile.has_method("get_save_data"):
			save_data["enemy_projectiles"].append(projectile.get_save_data())

	for gem in get_tree().get_nodes_in_group("exp_gems"):
		if is_instance_valid(gem) and gem.has_method("get_save_data"):
			save_data["gems"].append(gem.get_save_data())

	for heart_pickup in get_tree().get_nodes_in_group("heart_pickups"):
		if is_instance_valid(heart_pickup) and heart_pickup.has_method("get_save_data"):
			save_data["heart_pickups"].append(heart_pickup.get_save_data())

	SAVE_MANAGER.save_run(save_data)

func _load_saved_run() -> bool:
	if _is_developer_mode():
		return false
	var save_data := SAVE_MANAGER.load_run()
	if save_data.is_empty():
		return false

	survival_time = float(save_data.get("survival_time", 0.0))
	autosave_elapsed = 0.0
	spawned_elite_count = int(save_data.get("spawned_elite_count", 0))
	boss_spawned = bool(save_data.get("boss_spawned", false))
	boss_enemy = null

	player.apply_save_data(save_data.get("player", {}))

	for enemy_data in save_data.get("enemies", []):
		var enemy = enemy_scene.instantiate()
		if enemy == null:
			continue
		add_child(enemy)
		enemy.projectile_scene = enemy_bullet_scene
		enemy.heart_pickup_scene = heart_pickup_scene
		enemy.apply_save_data(enemy_data, player)
		if enemy.has_signal("defeated"):
			enemy.defeated.connect(_on_enemy_defeated.bind(enemy))
		if str(enemy_data.get("enemy_kind", "normal")) == "boss":
			boss_enemy = enemy
			boss_spawned = true

	for projectile_data in save_data.get("enemy_projectiles", []):
		var projectile = enemy_bullet_scene.instantiate()
		if projectile == null:
			continue
		add_child(projectile)
		projectile.apply_save_data(projectile_data, player)

	for gem_data in save_data.get("gems", []):
		var gem = exp_gem_scene.instantiate()
		if gem == null:
			continue
		add_child(gem)
		gem.apply_save_data(gem_data)

	for heart_data in save_data.get("heart_pickups", []):
		var heart_pickup = heart_pickup_scene.instantiate()
		if heart_pickup == null:
			continue
		add_child(heart_pickup)
		heart_pickup.apply_save_data(heart_data)

	var game_bgm = _get_game_bgm()
	if game_bgm != null and game_bgm.has_method("restore_playback_position"):
		game_bgm.restore_playback_position(float(save_data.get("music_position", 0.0)))

	_refresh_hud()
	_save_run_state()
	return true

func _get_enemy_power_multiplier() -> float:
	var minutes_survived: float = survival_time / 60.0
	return 1.0 + minutes_survived * enemy_health_scale_per_minute

func _get_game_bgm():
	return get_node_or_null("GameBGM")

func _start_game_bgm() -> void:
	var game_bgm = _get_game_bgm()
	if game_bgm != null and game_bgm.has_method("start_music"):
		game_bgm.start_music()

func _pause_game_bgm() -> void:
	var game_bgm = _get_game_bgm()
	if game_bgm != null and game_bgm.has_method("pause_music"):
		game_bgm.pause_music()

func _resume_game_bgm(delay_seconds: float = 0.0) -> void:
	var game_bgm = _get_game_bgm()
	if game_bgm != null and game_bgm.has_method("resume_music"):
		game_bgm.resume_music(delay_seconds)

func _on_enemy_defeated(enemy_kind: String, enemy: Node2D) -> void:
	if _is_developer_mode() and enemy_kind == "boss":
		if boss_enemy == enemy:
			boss_enemy = null
			boss_spawned = false
		_spawn_developer_boss()
		return
	if enemy_kind == "elite":
		_refresh_hud()
		return
	if enemy_kind != "boss":
		return
	if boss_enemy != enemy:
		return
	_on_stage_cleared()

func _on_stage_cleared() -> void:
	if game_over or player == null or level_up_ui == null:
		return
	if not level_up_ui.has_method("show_menu"):
		return

	stage_cleared = true
	reward_context = "final_core"
	boss_enemy = null
	if hud != null and hud.has_method("hide_boss_ui"):
		hud.hide_boss_ui()
	if spawn_timer != null:
		spawn_timer.stop()
	get_tree().paused = true
	level_up_ui.show_menu("终局核心", player.get_final_core_options())

func _finish_stage_clear() -> void:
	if game_over:
		return

	if story_mode_active:
		game_over = true
		reward_context = ""
		boss_enemy = null
		if hud != null and hud.has_method("hide_boss_ui"):
			hud.hide_boss_ui()
		if spawn_timer != null:
			spawn_timer.stop()
		var material_reward: int = int(story_stage.get("boss_material_reward", 0))
		SAVE_MANAGER.complete_current_story_stage(material_reward)
		get_tree().paused = false
		get_tree().change_scene_to_file(STORY_PREP_SCENE_PATH)
		return

	game_over = true
	reward_context = ""
	boss_enemy = null
	if hud != null and hud.has_method("hide_boss_ui"):
		hud.hide_boss_ui()
	SAVE_MANAGER.clear_save()
	if spawn_timer != null:
		spawn_timer.stop()
	if pause_menu != null and pause_menu.has_method("hide_ui"):
		pause_menu.hide_ui()
	if level_up_ui != null and level_up_ui.has_method("hide_ui"):
		level_up_ui.hide_ui()
	if game_over_ui != null and game_over_ui.has_method("show_victory"):
		game_over_ui.show_victory(survival_time, player.level)
	_pause_game_bgm()
	get_tree().paused = true

func _on_player_experience_changed(current_experience: int, required_experience: int, current_level: int) -> void:
	if hud != null and hud.has_method("update_display"):
		hud.update_display(current_level, current_experience, required_experience)

func _on_player_stats_changed(summary: Dictionary) -> void:
	if hud != null and hud.has_method("update_stats"):
		hud.update_stats(summary)

func _on_player_health_changed(current_health: float, max_health: float) -> void:
	if hud != null and hud.has_method("update_health"):
		hud.update_health(current_health, max_health)

func _on_player_mana_changed(current_mana: float, max_mana: float) -> void:
	if hud != null and hud.has_method("update_mana"):
		hud.update_mana(current_mana, max_mana)
	if hud != null and hud.has_method("update_stats") and player != null and player.has_method("get_stat_summary"):
		hud.update_stats(player.get_stat_summary())

func _on_player_level_up_requested(options: Array) -> void:
	if game_over:
		return
	if level_up_ui == null or not level_up_ui.has_method("show_options"):
		return

	reward_context = "level_up"
	get_tree().paused = true
	var attribute_options: Array = []
	if player != null and player.has_method("get_attribute_upgrade_options"):
		attribute_options = player.get_attribute_upgrade_options()
	if _is_developer_mode() and player != null and player.has_method("get_all_upgrade_options"):
		options = player.get_all_upgrade_options()
	level_up_ui.show_options(options, attribute_options)

func _on_upgrade_selected(option_id: String, attribute_option_id: String = "") -> void:
	if level_up_ui != null and level_up_ui.has_method("hide_ui"):
		level_up_ui.hide_ui()

	get_tree().paused = false

	if reward_context == "level_up" and attribute_option_id != "" and player != null and player.has_method("apply_attribute_upgrade"):
		player.apply_attribute_upgrade(attribute_option_id)
	if player != null and player.has_method("apply_upgrade"):
		player.apply_upgrade(option_id)

	if reward_context == "final_core":
		_finish_stage_clear()
		return

	reward_context = ""
	_refresh_hud()
	_save_run_state()

func _on_player_died() -> void:
	if game_over:
		return

	game_over = true
	SAVE_MANAGER.clear_save()
	if hud != null and hud.has_method("hide_boss_ui"):
		hud.hide_boss_ui()

	if pause_menu != null and pause_menu.has_method("hide_ui"):
		pause_menu.hide_ui()
	if level_up_ui != null and level_up_ui.has_method("hide_ui"):
		level_up_ui.hide_ui()
	if game_over_ui != null and game_over_ui.has_method("show_game_over"):
		game_over_ui.show_game_over(survival_time, player.level)

	_pause_game_bgm()
	get_tree().paused = true

func _on_resume_requested() -> void:
	_resume_game()

func _on_restart_requested() -> void:
	suppress_exit_save = true
	SAVE_MANAGER.clear_save()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_requested() -> void:
	_save_run_state()
	if _is_developer_mode():
		suppress_exit_save = true
		SAVE_MANAGER.clear_save()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _load_story_stage_context() -> void:
	story_stage = SAVE_MANAGER.get_current_story_stage()
	story_mode_active = not story_stage.is_empty()

func _apply_story_loadout() -> void:
	if not story_mode_active or player == null or not player.has_method("configure_story_loadout"):
		return
	var profile := SAVE_MANAGER.load_story_profile()
	player.configure_story_loadout(
		profile.get("team_order", ["swordsman", "gunner", "mage"]),
		profile.get("equipped_styles", {})
	)

func _get_effective_boss_spawn_time() -> float:
	if story_mode_active:
		return float(story_stage.get("boss_spawn_time", BOSS_SPAWN_TIME))
	return BOSS_SPAWN_TIME

func _get_effective_stage_curve_time() -> float:
	if story_mode_active:
		if str(story_stage.get("type", "")) == "boss":
			return max(60.0, float(story_stage.get("boss_spawn_time", BOSS_SPAWN_TIME)))
		return max(60.0, float(story_stage.get("target_time", 180.0)))
	return BOSS_SPAWN_TIME

func _get_story_spawn_interval_multiplier() -> float:
	if not story_mode_active:
		return 1.0
	return float(story_stage.get("spawn_interval_multiplier", 1.0))

func _get_story_enemy_health_multiplier() -> float:
	if not story_mode_active:
		return 1.0
	return float(story_stage.get("enemy_health_multiplier", 1.0))

func _get_story_enemy_speed_multiplier() -> float:
	if not story_mode_active:
		return 1.0
	return float(story_stage.get("enemy_speed_multiplier", 1.0))

func _find_player() -> Node2D:
	if has_node("player"):
		return get_node("player") as Node2D
	if has_node("Player"):
		return get_node("Player") as Node2D

	for child in get_children():
		if child is CharacterBody2D:
			return child as Node2D

	return null

func _is_developer_mode() -> bool:
	return DEVELOPER_MODE.is_enabled()

func _activate_developer_mode() -> void:
	if spawn_timer != null:
		spawn_timer.stop()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(projectile):
			projectile.queue_free()
	spawned_elite_count = 0
	stage_cleared = false
	boss_spawned = false
	boss_enemy = null
	if hud != null and hud.has_method("hide_boss_ui"):
		hud.hide_boss_ui()
	developer_exp_gem_elapsed = 0.0
	_spawn_developer_exp_gem()
	_spawn_developer_boss()

func _update_developer_mode(delta: float) -> void:
	if spawn_timer != null and not spawn_timer.is_stopped():
		spawn_timer.stop()
	developer_exp_gem_elapsed += delta
	while developer_exp_gem_elapsed >= DEVELOPER_MODE.FULL_XP_GEM_INTERVAL:
		developer_exp_gem_elapsed -= DEVELOPER_MODE.FULL_XP_GEM_INTERVAL
		_spawn_developer_exp_gem()
	if (boss_enemy == null or not is_instance_valid(boss_enemy)) and not game_over:
		_spawn_developer_boss()

func _spawn_developer_boss() -> void:
	boss_spawned = true
	boss_enemy = _spawn_special_enemy("boss")

func _spawn_developer_exp_gem() -> void:
	if exp_gem_scene == null or player == null:
		return
	var gem = exp_gem_scene.instantiate()
	if gem == null:
		return
	var exp_value := DEVELOPER_MODE.get_full_exp_value(player)
	if gem.has_method("configure"):
		gem.configure(4, exp_value)
	var spawn_direction := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
	var spawn_distance: float = rng.randf_range(
		DEVELOPER_MODE.FULL_XP_GEM_MIN_RADIUS,
		DEVELOPER_MODE.FULL_XP_GEM_MAX_RADIUS
	)
	gem.global_position = player.global_position + spawn_direction * spawn_distance
	add_child(gem)


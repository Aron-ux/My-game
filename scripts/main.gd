extends Node2D

const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const DEVELOPER_ACTIONS := preload("res://scripts/developer/developer_actions.gd")
const DEVELOPER_OPTION_PROVIDER := preload("res://scripts/developer/developer_option_provider.gd")
const ENEMY_DIRECTOR := preload("res://scripts/enemy/enemy_director.gd")
const ENEMY_SPAWN_FLOW := preload("res://scripts/game/enemy_spawn_flow.gd")
const REWARD_FLOW := preload("res://scripts/game/reward_flow.gd")
const RUN_SAVE_FLOW := preload("res://scripts/game/run_save_flow.gd")
const GAME_SESSION_FLOW := preload("res://scripts/game/game_session_flow.gd")
const PERFORMANCE_MONITOR := preload("res://scripts/game/performance_monitor.gd")
const PICKUP_COMPACTOR := preload("res://scripts/game/pickup_compactor.gd")
const CHARACTER_PANEL := preload("res://scripts/ui/hud/character_panel.gd")

@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var enemy_bullet_scene: PackedScene = preload("res://scenes/enemy_bullet.tscn")
@export var exp_gem_scene: PackedScene = preload("res://scenes/exp_gem.tscn")
@export var heart_pickup_scene: PackedScene = preload("res://scenes/heart_pickup.tscn")
@export var hud_scene: PackedScene = preload("res://scenes/hud.tscn")
@export var level_up_ui_scene: PackedScene = preload("res://scenes/level_up_ui.tscn")
@export var pause_menu_scene: PackedScene = preload("res://scenes/pause_menu.tscn")
@export var game_over_ui_scene: PackedScene = preload("res://scenes/game_over_ui.tscn")
@export var spawn_distance: float = 350.0
@export var autosave_interval: float = 2.0

var player
var spawn_timer: Timer
var hud
var character_panel
var level_up_ui
var pause_menu
var game_over_ui
var rng := RandomNumberGenerator.new()
var survival_time: float = 0.0
var autosave_elapsed: float = 0.0
var game_over: bool = false
var loaded_from_save: bool = false
var spawned_elite_count: int = 0
var spawned_small_boss_count: int = 0
var boss_spawned: bool = false
var stage_cleared: bool = false
var boss_enemy: Node2D
var reward_context: String = ""
var story_stage: Dictionary = {}
var story_mode_active: bool = false
var endless_mode_active: bool = false
var suppress_exit_save: bool = false
var defeated_boss_count: int = 0
var exit_snapshot_saved: bool = false
var performance_sample_elapsed: float = 0.0
var pickup_compact_elapsed: float = 0.0

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
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not game_over:
			_save_run_state()
			exit_snapshot_saved = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not game_over:
			_save_run_state()

func _exit_tree() -> void:
	if not game_over and not suppress_exit_save and not exit_snapshot_saved:
		_save_run_state()

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_CHARACTER_PANEL):
			_toggle_character_panel()
			get_viewport().set_input_as_handled()
			return
		if character_panel != null and character_panel.visible and event.keycode == KEY_ESCAPE:
			_hide_character_panel()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			_handle_escape_toggle()

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
	if hud != null and hud.has_method("update_stats") and player != null and player.has_method("get_stat_summary"):
		hud.update_stats(player.get_stat_summary())
	_update_boss_hud()
	_update_pickup_compaction(delta)
	_update_performance_metrics(delta)

func _setup_spawn_timer() -> void:
	ENEMY_SPAWN_FLOW.setup_spawn_timer(self)

func _setup_ui() -> void:
	if hud_scene != null:
		hud = hud_scene.instantiate()
		add_child(hud)
		if hud.has_signal("developer_level_up_requested"):
			hud.developer_level_up_requested.connect(_on_developer_level_up_requested)
		if hud.has_signal("developer_boss_spawn_requested"):
			hud.developer_boss_spawn_requested.connect(_on_developer_boss_spawn_requested)
		if hud.has_signal("developer_card_grant_requested"):
			hud.developer_card_grant_requested.connect(_on_developer_card_grant_requested)
		if hud.has_signal("developer_small_boss_spawn_requested"):
			hud.developer_small_boss_spawn_requested.connect(_on_developer_small_boss_spawn_requested)

	character_panel = CHARACTER_PANEL.new()
	add_child(character_panel)
	character_panel.close_requested.connect(_hide_character_panel)

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
	if hud != null and hud.has_method("set_developer_boss_options"):
		hud.set_developer_boss_options(_get_developer_boss_options())
	if hud != null and hud.has_method("set_developer_dangzhen_build_options") and player != null:
		hud.set_developer_dangzhen_build_options(DEVELOPER_OPTION_PROVIDER.get_dangzhen_build_options(player.card_pick_levels))
	if hud != null and hud.has_method("set_developer_special_card_options") and player != null:
		hud.set_developer_special_card_options(DEVELOPER_OPTION_PROVIDER.get_special_card_options(player.special_reward_levels))
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

func _update_performance_metrics(delta: float) -> void:
	if not _is_developer_mode() and not endless_mode_active:
		return
	if hud == null or not hud.has_method("update_performance_metrics"):
		return
	performance_sample_elapsed += delta
	if performance_sample_elapsed < PERFORMANCE_MONITOR.SAMPLE_INTERVAL:
		return
	performance_sample_elapsed = 0.0
	hud.update_performance_metrics(PERFORMANCE_MONITOR.collect_metrics(self))

func _update_pickup_compaction(delta: float) -> void:
	pickup_compact_elapsed += delta
	if pickup_compact_elapsed < PICKUP_COMPACTOR.COMPACT_INTERVAL:
		return
	pickup_compact_elapsed = 0.0
	PICKUP_COMPACTOR.compact_pickups(self)

func _toggle_character_panel() -> void:
	if character_panel == null:
		return
	if character_panel.visible:
		_hide_character_panel()
		return
	if get_tree().paused:
		return
	if level_up_ui != null and level_up_ui.visible:
		return
	if pause_menu != null and pause_menu.visible:
		return
	_show_character_panel()

func _show_character_panel() -> void:
	if character_panel == null or player == null:
		return
	get_tree().paused = true
	character_panel.show_for_player(player)

func _hide_character_panel() -> void:
	if character_panel == null:
		return
	character_panel.hide_panel()
	get_tree().paused = false

func _handle_escape_toggle() -> void:
	GAME_SESSION_FLOW.handle_escape_toggle(self)

func _show_pause_menu_after_continue() -> void:
	GAME_SESSION_FLOW.show_pause_menu_after_continue(self)

func _resume_game() -> void:
	GAME_SESSION_FLOW.resume_game(self)

func _update_spawn_curve() -> void:
	ENEMY_SPAWN_FLOW.update_spawn_curve(self)

func _handle_stage_events() -> void:
	ENEMY_SPAWN_FLOW.handle_stage_events(self)

func _spawn_enemy() -> void:
	ENEMY_SPAWN_FLOW.spawn_enemy(self)

func _spawn_special_enemy(kind: String) -> Node2D:
	return ENEMY_SPAWN_FLOW.spawn_special_enemy(self, kind)

func _spawn_wave_pack(kind: String, archetype: String, count: int, health_multiplier: float, speed_multiplier: float, damage_multiplier: float = 1.0) -> void:
	ENEMY_SPAWN_FLOW.spawn_wave_pack(self, kind, archetype, count, health_multiplier, speed_multiplier, damage_multiplier)

func _spawn_configured_enemy(kind: String, archetype: String, health_multiplier: float, speed_multiplier: float, spawn_angle: float = INF, distance_offset: float = 0.0, damage_multiplier: float = 1.0) -> Node2D:
	return ENEMY_SPAWN_FLOW.spawn_configured_enemy(self, kind, archetype, health_multiplier, speed_multiplier, spawn_angle, distance_offset, damage_multiplier)

func _get_wave_profile() -> Dictionary:
	return ENEMY_SPAWN_FLOW.get_wave_profile(self)

func _get_player_growth_score() -> float:
	return ENEMY_SPAWN_FLOW.get_player_growth_score(self)

func _get_expected_growth_score() -> float:
	return ENEMY_SPAWN_FLOW.get_expected_growth_score(self)

func _get_spawn_position(angle: float, distance: float) -> Vector2:
	return ENEMY_SPAWN_FLOW.get_spawn_position(self, angle, distance)

func _get_enemy_profile(kind: String, archetype: String) -> Dictionary:
	return ENEMY_SPAWN_FLOW.get_enemy_profile(kind, archetype)

func _save_run_state() -> void:
	RUN_SAVE_FLOW.save_run_state(self)

func _load_saved_run() -> bool:
	return RUN_SAVE_FLOW.load_saved_run(self)

func _get_spawn_enemy_health_multiplier() -> float:
	return _get_story_enemy_health_multiplier() * ENEMY_DIRECTOR.get_endless_cycle_health_multiplier(_get_endless_cycle_power_level())

func _get_spawn_enemy_speed_multiplier() -> float:
	return _get_story_enemy_speed_multiplier() * ENEMY_DIRECTOR.get_endless_cycle_speed_multiplier(_get_endless_cycle_power_level())

func _get_spawn_enemy_damage_multiplier() -> float:
	return ENEMY_DIRECTOR.get_endless_cycle_damage_multiplier(_get_endless_cycle_power_level())

func _get_endless_cycle_power_level() -> int:
	if not endless_mode_active:
		return 0
	return max(0, defeated_boss_count)

func _get_game_bgm():
	return GAME_SESSION_FLOW.get_game_bgm(self)

func _start_game_bgm() -> void:
	GAME_SESSION_FLOW.start_game_bgm(self)

func _pause_game_bgm() -> void:
	GAME_SESSION_FLOW.pause_game_bgm(self)

func _resume_game_bgm(delay_seconds: float = 0.0) -> void:
	GAME_SESSION_FLOW.resume_game_bgm(self, delay_seconds)

func _on_enemy_defeated(enemy_kind: String, enemy: Node2D) -> void:
	if _is_developer_mode() and enemy_kind == "boss":
		if boss_enemy == enemy:
			boss_enemy = null
			boss_spawned = false
		_refresh_hud()
		return
	if enemy_kind == "elite":
		_refresh_hud()
		return
	if enemy_kind == "small_boss":
		if boss_enemy == enemy:
			boss_enemy = null
		_show_small_boss_reward()
		_refresh_hud()
		return
	if enemy_kind != "boss":
		return
	if boss_enemy != enemy:
		return
	if endless_mode_active:
		boss_enemy = null
		boss_spawned = false
		defeated_boss_count += 1
		if hud != null and hud.has_method("hide_boss_ui"):
			hud.hide_boss_ui()
		_show_endless_boss_reward()
		return
	_on_stage_cleared()

func _on_stage_cleared() -> void:
	REWARD_FLOW.show_final_core(self)

func _finish_stage_clear() -> void:
	REWARD_FLOW.finish_stage_clear(self)

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
	REWARD_FLOW.show_level_up(self, options)

func _on_upgrade_selected(option_id: String, attribute_option_id: String = "") -> void:
	REWARD_FLOW.handle_upgrade_selected(self, option_id, attribute_option_id)

func _on_player_died() -> void:
	GAME_SESSION_FLOW.handle_player_died(self)

func _on_resume_requested() -> void:
	GAME_SESSION_FLOW.resume_game(self)

func _on_restart_requested() -> void:
	GAME_SESSION_FLOW.restart(self)

func _on_main_menu_requested() -> void:
	GAME_SESSION_FLOW.return_to_main_menu(self)

func _load_story_stage_context() -> void:
	story_stage = SAVE_MANAGER.get_current_story_stage()
	story_mode_active = not story_stage.is_empty()
	endless_mode_active = not story_mode_active and SAVE_MANAGER.is_endless_mode_active()

func _apply_story_loadout() -> void:
	if not story_mode_active or player == null or not player.has_method("configure_story_loadout"):
		return
	var profile := SAVE_MANAGER.load_story_profile()
	player.configure_story_loadout(
		profile.get("team_order", ["swordsman", "gunner", "mage"]),
		profile.get("equipped_styles", {})
	)

func _get_effective_boss_spawn_time() -> float:
	return ENEMY_DIRECTOR.get_effective_boss_spawn_time(
		story_stage,
		story_mode_active,
		endless_mode_active,
		defeated_boss_count
	)

func _get_effective_stage_curve_time() -> float:
	return ENEMY_DIRECTOR.get_effective_stage_curve_time(story_stage, story_mode_active)

func _get_story_spawn_interval_multiplier() -> float:
	return ENEMY_DIRECTOR.get_story_spawn_interval_multiplier(story_stage, story_mode_active)

func _get_story_enemy_health_multiplier() -> float:
	return ENEMY_DIRECTOR.get_story_enemy_health_multiplier(story_stage, story_mode_active)

func _get_story_enemy_speed_multiplier() -> float:
	return ENEMY_DIRECTOR.get_story_enemy_speed_multiplier(story_stage, story_mode_active)

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
	DEVELOPER_ACTIONS.activate(self)

func _update_developer_mode(_delta: float) -> void:
	DEVELOPER_ACTIONS.update(self)

func _on_developer_level_up_requested() -> void:
	DEVELOPER_ACTIONS.grant_level_up(self)

func _on_developer_boss_spawn_requested(archetype_id: String) -> void:
	DEVELOPER_ACTIONS.spawn_boss(self, archetype_id)

func _on_developer_card_grant_requested(card_id: String) -> void:
	DEVELOPER_ACTIONS.grant_card(self, card_id)

func _on_developer_small_boss_spawn_requested(archetype_id: String) -> void:
	DEVELOPER_ACTIONS.spawn_small_boss(self, archetype_id)

func _get_developer_boss_options() -> Array:
	return DEVELOPER_OPTION_PROVIDER.get_boss_options()

func _spawn_developer_boss(archetype_id: String = "boss_spellcore") -> void:
	DEVELOPER_ACTIONS.spawn_boss(self, archetype_id)

func _spawn_developer_small_boss(archetype_id: String) -> void:
	DEVELOPER_ACTIONS.spawn_small_boss(self, archetype_id)

func _has_active_special_enemy(kind: String) -> bool:
	return ENEMY_SPAWN_FLOW.has_active_special_enemy(self, kind)

func _show_small_boss_reward() -> void:
	REWARD_FLOW.show_small_boss_reward(self)

func _show_endless_boss_reward() -> void:
	REWARD_FLOW.show_endless_boss_reward(self)

func _get_small_boss_reward_options() -> Array:
	return REWARD_FLOW.get_blank_small_boss_reward_options()

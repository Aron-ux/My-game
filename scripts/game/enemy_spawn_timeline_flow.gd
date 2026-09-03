extends RefCounted

const ENEMY_DIRECTOR := preload("res://scripts/enemy/enemy_director.gd")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")

const SPAWN_CURVE_REFRESH_INTERVAL := 0.25
const LAST_SPAWN_CURVE_REFRESH_META := "last_spawn_curve_refresh_time"
const SPECIAL_EVENT_QUEUE_META := "pending_special_spawn_events"
const SPECIAL_EVENT_QUEUE_NEXT_TIME_META := "next_special_spawn_event_time"
const SPECIAL_EVENT_QUEUE_GAP := 0.35

static func setup_spawn_timer(main: Node) -> void:
	main.spawn_timer = Timer.new()
	main.spawn_timer.wait_time = ENEMY_DIRECTOR.get_default_starting_spawn_interval()
	main.spawn_timer.one_shot = false
	main.spawn_timer.autostart = true
	main.spawn_timer.timeout.connect(Callable(main, "_spawn_enemy"))
	main.add_child(main.spawn_timer)


static func update_spawn_curve(main: Node) -> void:
	if main.spawn_timer == null:
		return
	if main._is_developer_mode():
		main.spawn_timer.stop()
		return
	if main.boss_spawned and (is_instance_valid(main.boss_enemy) or _has_queued_special_event(main, "boss")):
		main.spawn_timer.stop()
		return
	if not main.spawn_timer.is_stopped() and not _should_refresh_spawn_curve(main):
		return

	var wave_profile: Dictionary = main.ENEMY_SPAWN_FLOW.get_wave_profile(main)
	var minimum_spawn_interval: float = ENEMY_DIRECTOR.get_default_minimum_spawn_interval()
	if main.has_method("_get_difficulty_minimum_spawn_interval_multiplier"):
		minimum_spawn_interval *= max(0.2, float(main._get_difficulty_minimum_spawn_interval_multiplier()))
	var target_interval: float = ENEMY_DIRECTOR.get_spawn_interval(
		ENEMY_DIRECTOR.get_default_starting_spawn_interval(),
		minimum_spawn_interval,
		main.ENEMY_SPAWN_FLOW.get_stage_elapsed_time(main),
		main._get_effective_stage_curve_time(),
		wave_profile,
		main._get_story_spawn_interval_multiplier() * main._get_difficulty_spawn_interval_multiplier()
	)
	main.spawn_timer.wait_time = ENEMY_DIRECTOR.get_wave_batch_interval(target_interval)
	if main.spawn_timer.is_stopped() and not main.game_over:
		main.spawn_timer.start()


static func _should_refresh_spawn_curve(main: Node) -> bool:
	if main == null:
		return false
	var last_refresh_time := float(main.get_meta(LAST_SPAWN_CURVE_REFRESH_META, -999999.0))
	if float(main.survival_time) - last_refresh_time < SPAWN_CURVE_REFRESH_INTERVAL:
		return false
	main.set_meta(LAST_SPAWN_CURVE_REFRESH_META, float(main.survival_time))
	return true


static func handle_stage_events(main: Node) -> void:
	if main._is_developer_mode():
		return
	_process_queued_special_events(main)
	var stage_events: Array = ENEMY_DIRECTOR.collect_stage_events(
		main.survival_time,
		ENEMY_DIRECTOR.get_default_elite_spawn_times(),
		main.spawned_elite_count,
		ENEMY_DIRECTOR.get_default_small_boss_spawn_times(),
		main.spawned_small_boss_count,
		main.boss_spawned,
		main._get_effective_boss_spawn_time(),
		main.ENEMY_SPAWN_FLOW.has_active_special_enemy(main, "small_boss"),
		main.story_stage,
		main.story_mode_active,
		main.stage_cleared
	)
	for stage_event in stage_events:
		match str(stage_event.get("type", "")):
			"clear_stage":
				main._on_stage_cleared()
				return
			"elite":
				_queue_special_event(main, "elite")
			"small_boss":
				_queue_special_event(main, "small_boss")
			"boss":
				_queue_special_event(main, "boss")


static func _queue_special_event(main: Node, event_type: String) -> void:
	var queue: Array = _get_special_event_queue(main)
	var event := {
		"type": event_type,
		"archetype": ENEMY_DIRECTOR.pick_special_archetype(event_type, main.survival_time, main.spawned_small_boss_count, main.rng)
	}
	queue.append(event)
	main.set_meta(SPECIAL_EVENT_QUEUE_META, queue)
	match event_type:
		"elite":
			main.spawned_elite_count += 1
		"small_boss":
			main.spawned_small_boss_count += 1
		"boss":
			main.boss_spawned = true
			if main.spawn_timer != null:
				main.spawn_timer.stop()
	if not main.has_meta(SPECIAL_EVENT_QUEUE_NEXT_TIME_META):
		main.set_meta(SPECIAL_EVENT_QUEUE_NEXT_TIME_META, float(main.survival_time))


static func _process_queued_special_events(main: Node) -> void:
	var queue: Array = _get_special_event_queue(main)
	if queue.is_empty():
		_remove_special_event_queue_time(main)
		return
	var next_time: float = float(main.get_meta(SPECIAL_EVENT_QUEUE_NEXT_TIME_META, float(main.survival_time)))
	if float(main.survival_time) < next_time:
		return
	var event: Dictionary = queue.pop_front()
	main.set_meta(SPECIAL_EVENT_QUEUE_META, queue)
	_spawn_queued_special_event(main, str(event.get("type", "")), str(event.get("archetype", "")))
	if queue.is_empty():
		_remove_special_event_queue_time(main)
	else:
		main.set_meta(SPECIAL_EVENT_QUEUE_NEXT_TIME_META, float(main.survival_time) + SPECIAL_EVENT_QUEUE_GAP)


static func _spawn_queued_special_event(main: Node, event_type: String, archetype: String) -> void:
	match event_type:
		"elite":
			main.ENEMY_SPAWN_FLOW.spawn_special_enemy_with_archetype(main, "elite", archetype)
		"small_boss":
			main.small_boss_enemy = main.ENEMY_SPAWN_FLOW.spawn_special_enemy_with_archetype(main, "small_boss", archetype)
		"boss":
			main.boss_enemy = main.ENEMY_SPAWN_FLOW.spawn_special_enemy_with_archetype(main, "boss", archetype)
			if main.spawn_timer != null:
				main.spawn_timer.stop()


static func _get_special_event_queue(main: Node) -> Array:
	if main == null:
		return []
	var queue_variant: Variant = main.get_meta(SPECIAL_EVENT_QUEUE_META, [])
	if queue_variant is Array:
		return (queue_variant as Array).duplicate()
	return []


static func _has_queued_special_event(main: Node, event_type: String) -> bool:
	for event in _get_special_event_queue(main):
		if event is Dictionary and str((event as Dictionary).get("type", "")) == event_type:
			return true
	return false


static func _remove_special_event_queue_time(main: Node) -> void:
	if main != null and main.has_meta(SPECIAL_EVENT_QUEUE_NEXT_TIME_META):
		main.remove_meta(SPECIAL_EVENT_QUEUE_NEXT_TIME_META)


static func spawn_enemy(main: Node) -> void:
	if main.game_over or main.enemy_scene == null or main.player == null or main._is_developer_mode() or (main.boss_spawned and (is_instance_valid(main.boss_enemy) or _has_queued_special_event(main, "boss"))):
		return

	var health_multiplier: float = main._get_spawn_enemy_health_multiplier("normal")
	var speed_multiplier: float = main._get_spawn_enemy_speed_multiplier()
	var damage_multiplier: float = main._get_spawn_enemy_damage_multiplier()
	var wave_profile: Dictionary = main.ENEMY_SPAWN_FLOW.get_wave_profile(main)
	var pack_interval: float = get_current_pack_interval(main, wave_profile)
	var batch_interval: float = ENEMY_DIRECTOR.get_wave_batch_interval(pack_interval)
	var enemy_limit: int = main.ENEMY_SPAWN_FLOW._get_runtime_enemy_limit(main)
	var capacity: int = PERFORMANCE_GUARD.get_remaining_capacity(main, "enemies", enemy_limit)
	var spawn_plan: Array = ENEMY_DIRECTOR.pick_spawn_wave_plan(wave_profile, main.rng, pack_interval, batch_interval, capacity)
	if spawn_plan.is_empty():
		return
	main.ENEMY_SPAWN_FLOW.spawn_telegraphed_wave_plan(main, spawn_plan, health_multiplier, speed_multiplier, damage_multiplier)


static func get_current_pack_interval(main: Node, wave_profile: Dictionary) -> float:
	var minimum_spawn_interval: float = ENEMY_DIRECTOR.get_default_minimum_spawn_interval()
	if main.has_method("_get_difficulty_minimum_spawn_interval_multiplier"):
		minimum_spawn_interval *= max(0.2, float(main._get_difficulty_minimum_spawn_interval_multiplier()))
	return ENEMY_DIRECTOR.get_spawn_interval(
		ENEMY_DIRECTOR.get_default_starting_spawn_interval(),
		minimum_spawn_interval,
		main.ENEMY_SPAWN_FLOW.get_stage_elapsed_time(main),
		main._get_effective_stage_curve_time(),
		wave_profile,
		main._get_story_spawn_interval_multiplier() * main._get_difficulty_spawn_interval_multiplier()
	)

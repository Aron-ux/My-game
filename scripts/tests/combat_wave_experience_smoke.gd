extends SceneTree

const CURVE := preload("res://scripts/player/player_level_curve.gd")
const SURVIVAL := preload("res://scripts/player/player_survival_flow.gd")
const PLAN := preload("res://scripts/game/combat_wave_plan.gd")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const GEM := preload("res://scripts/exp_gem.gd")
const FLOW_TEST := preload("res://scripts/tests/combat_wave_flow_smoke.gd")
var failures: Array[String] = []

class Progress:
	extends Node
	var level: int = 1
	var experience: int = 0
	var experience_to_next_level: int = 16

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _run() -> void:
	var main := FLOW_TEST.TestMain.new()
	root.add_child(main)
	current_scene = main
	main.set_process(false)
	main.set_physics_process(false)
	var progress := Progress.new()
	main.add_child(progress)
	CURVE.enable_wave_curve(progress)
	check(SURVIVAL._get_adjusted_experience_gain(progress, 100) == 22, "Wave XP gain must use 0.22, replacing the old 2.43 multiplier")
	progress.remove_meta(SURVIVAL.EXPERIENCE_FRACTION_CARRY_KEY)
	main.difficulty_profile = {"tier": 3}
	check(SURVIVAL._get_adjusted_experience_gain(progress, 100) == 26, "Existing N-tier XP bonus must remain effective")
	main.difficulty_profile = {}
	progress.remove_meta(SURVIVAL.EXPERIENCE_FRACTION_CARRY_KEY)
	var regular := Progress.new()
	main.add_child(regular)
	check(SURVIVAL._get_adjusted_experience_gain(regular, 100) == 243, "Non-wave XP must preserve existing behavior")
	for level in range(2, 50):
		check(CURVE.get_required_experience_for_level(level, true) >= CURVE.get_required_experience_for_level(level - 1, true), "Wave requirements must not decrease")
	check(CURVE.get_required_experience_for_level(20, true) == CURVE.get_required_experience_for_level(19, true), "Wave curve must remove the old level-20 XP cliff")

	# A new-format save restores exactly; older saves preserve fractional progress
	# without revoking levels or awarding points from changed thresholds.
	progress.level = 21
	progress.experience = 2800
	CURVE.restore_progress(progress, 5600, "")
	check(progress.level == 21 and progress.experience == 115 and progress.experience_to_next_level == 230, "Old save must migrate within-level progress proportionally")
	CURVE.restore_progress(progress, 230, CURVE.WAVE_CURVE_ID)
	check(progress.experience == 115, "Repeated restore must not remigrate current saves")

	# Reference budget, not an AI combat simulation: 65% of scheduled normal
	# enemies killed AND collected, bosses take 60/75/75 seconds, no training
	# level reward or summoned offspring XP. Actual play can vary.
	progress.level = 1
	progress.experience = 0
	progress.experience_to_next_level = CURVE.get_required_experience_for_level(1, true)
	var duration_assumptions := {6: 60.0, 11: 75.0, 16: 75.0}
	var checkpoints := {1: [3, 4], 5: [8, 10], 6: [10, 12], 11: [16, 18], 20: [28, 32]}
	for wave in range(1, 21):
		var pool: Array = PLAN.POOLS[wave - 1]
		var average_pickup := 0.0
		for archetype in pool:
			var profile := DATABASE.get_profile("normal", str(archetype))
			var gem := GEM.new()
			main.add_child(gem)
			var value: int = int(profile.get("experience_reward", 0))
			if wave in PLAN.REWARD_WAVES:
				value = roundi(value * 1.5)
			gem.configure(int(profile.get("reward_tier", 1)), value)
			average_pickup += gem.value
			gem.free()
		if not pool.is_empty():
			average_pickup /= pool.size()
		var spawn_rate := 0.0 if wave == 20 else (1.0 / PLAN.TREE_ESCORT_INTERVAL if wave == 6 else (2.0 if wave <= 3 or wave in PLAN.REWARD_WAVES else 3.0 if wave <= 12 else 4.0))
		if wave == 11:
			spawn_rate = 1.0 / PLAN.SKULL_ESCORT_INTERVAL
		var seconds: float = duration_assumptions.get(wave, PLAN.duration(wave))
		var pickup_value := seconds * spawn_rate * average_pickup * 0.65
		if PLAN.SMALL_BOSS_EXPERIENCE.has(wave):
			pickup_value += roundi(int(PLAN.SMALL_BOSS_EXPERIENCE[wave]) * 0.9)
		if PLAN.ELITES.has(wave):
			pickup_value += PLAN.ELITES[wave].size() * 41
		if wave in PLAN.FLYBY_WAVES:
			pickup_value += 30
		progress.experience += SURVIVAL._get_adjusted_experience_gain(progress, roundi(pickup_value))
		while progress.experience >= progress.experience_to_next_level:
			progress.experience -= progress.experience_to_next_level
			progress.level += 1
			progress.experience_to_next_level = CURVE.get_required_experience_for_level(progress.level, true)
		if checkpoints.has(wave):
			var range_value: Array = checkpoints[wave]
			print("Wave %d reference level: %d (+%d/%d XP)" % [wave, progress.level, progress.experience, progress.experience_to_next_level])
			check(progress.level >= int(range_value[0]) and progress.level <= int(range_value[1]), "Reference budget misses the approved level range at wave %d" % wave)
	main.free()
	await process_frame
	if failures.is_empty():
		print("COMBAT_WAVE_EXPERIENCE_SMOKE_OK")
		quit(0)
	else:
		for message in failures:
			push_error(message)
		quit(1)

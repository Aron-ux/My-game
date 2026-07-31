extends SceneTree

const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const SAVE_FILE_STORE := preload("res://scripts/save/save_file_store.gd")


func _init() -> void:
	var profile := {
		"bones": 10,
		"highest_cleared_tier": 0,
		"selected_tier": 1,
		"last_rewarded_run_id": ""
	}
	var first := SAVE_MANAGER.settle_endless_profile(profile, 1, "run-1")
	assert(first.get("applied"))
	assert(first.get("base_reward") == 8)
	assert(first.get("first_clear_bonus") == 8)
	assert(profile.get("bones") == 26)
	assert(profile.get("highest_cleared_tier") == 1)
	assert(profile.get("selected_tier") == 2)

	var duplicate := SAVE_MANAGER.settle_endless_profile(profile, 1, "run-1")
	assert(not duplicate.get("applied"))
	assert(profile.get("bones") == 26)

	var replay := SAVE_MANAGER.settle_endless_profile(profile, 1, "run-2")
	assert(replay.get("applied"))
	assert(replay.get("total_reward") == 8)
	assert(profile.get("bones") == 34)
	assert(SAVE_MANAGER.get_endless_unlocked_max(profile) == 2)
	_test_atomic_save_replacement()
	print("ENDLESS_PROGRESSION_SMOKE_OK")
	quit(0)


func _test_atomic_save_replacement() -> void:
	var path := "user://endless_progression_atomic_test.json"
	var temporary_path := path + ".tmp"
	SAVE_FILE_STORE.remove_if_exists(path)
	SAVE_FILE_STORE.remove_if_exists(temporary_path)
	assert(SAVE_FILE_STORE.write_json(path, {"version": 1}) > 0)
	assert(SAVE_FILE_STORE.write_json(path, {"version": 2}) > 0)
	assert((SAVE_FILE_STORE.read_json(path) as Dictionary).get("version") == 2)
	assert(not FileAccess.file_exists(temporary_path))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temporary_path))
	assert(SAVE_FILE_STORE.write_json(path, {"version": 3}) == 0)
	assert((SAVE_FILE_STORE.read_json(path) as Dictionary).get("version") == 2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
	SAVE_FILE_STORE.remove_if_exists(path)

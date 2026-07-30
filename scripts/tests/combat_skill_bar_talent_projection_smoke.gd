extends SceneTree

const COMBAT_SKILL_BAR := preload("res://scripts/ui/hud/combat_skill_bar.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bar := COMBAT_SKILL_BAR.new()
	root.add_child(bar)
	await process_frame
	bar.set_hud_layout("legacy")
	await process_frame

	var payload := {
		"name": "普通攻击·十字剑势·追锋·剑轮",
		"hud_name": "剑轮",
		"description": "完整技能说明",
		"duration": 2.0,
		"remaining": 0.0
	}
	bar.update_skill_cooldown_slots([payload])
	var legacy_slot: Dictionary = bar.get("skill_cd_slots")[0]
	assert((legacy_slot["label"] as Label).text == "剑轮")
	assert(str(legacy_slot["title"]) == payload["name"])

	bar.update_ultimate_energy(100.0, 100.0, payload)
	assert(str(bar.get("ultimate_energy_widget").skill_name) == "剑轮")
	assert(str(bar.get("ultimate_display").get("name", "")) == payload["name"])

	bar.set_hud_layout("team_band")
	await process_frame
	bar.update_team_role_statuses([
		{"role_id": "swordsman", "role_name": "剑士", "cooldown_slots": [payload]},
		{"role_id": "gunner", "role_name": "枪手", "cooldown_slots": []},
		{"role_id": "mage", "role_name": "术师", "cooldown_slots": []}
	], "swordsman", 0)
	var active_slot: Dictionary = bar.get("team_role_rows")[1]["slots"][0]
	assert((active_slot["label"] as Label).text == "剑轮")
	assert(str(active_slot["title"]) == payload["name"])

	var fallback := payload.duplicate()
	fallback.erase("hud_name")
	bar.set_hud_layout("legacy")
	await process_frame
	bar.update_skill_cooldown_slots([fallback])
	assert((bar.get("skill_cd_slots")[0]["label"] as Label).text == payload["name"])

	print("COMBAT_SKILL_BAR_TALENT_PROJECTION_SMOKE_OK")
	bar.queue_free()
	await process_frame
	quit(0)

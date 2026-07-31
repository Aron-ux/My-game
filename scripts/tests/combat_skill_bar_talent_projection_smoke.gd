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
		{"role_id": "swordsman", "role_name": "剑士", "switch_energy": 50.0, "switch_energy_required": 100.0, "cooldown_slots": [payload]},
		{"role_id": "gunner", "role_name": "枪手", "switch_energy": 75.0, "switch_energy_required": 100.0, "cooldown_slots": []},
		{"role_id": "mage", "role_name": "术师", "switch_energy": 25.0, "switch_energy_required": 100.0, "cooldown_slots": []}
	], "swordsman", 0)
	var team_rows: Array = bar.get("team_role_rows")
	assert([
		str(team_rows[0]["portrait"].role_id),
		str(team_rows[1]["portrait"].role_id),
		str(team_rows[2]["portrait"].role_id)
	] == ["mage", "swordsman", "gunner"])
	for row_entry in team_rows:
		var portrait = row_entry["portrait"]
		assert(portrait.head_node != null)
		assert(
			(portrait.head_sprite != null and portrait.head_sprite.texture != null)
			or (portrait.head_texture_rect != null and portrait.head_texture_rect.texture != null)
		)
	bar.update_switch_cooldown(
		"swordsman",
		0.25,
		0.5,
		50.0,
		100.0,
		{"swordsman": 50.0, "gunner": 75.0, "mage": 25.0}
	)
	var active_portrait = team_rows[1]["portrait"]
	assert(active_portrait.active)
	assert(is_equal_approx(active_portrait.energy_ratio, 0.5))
	assert(active_portrait.circle_front_plate.active)
	assert(is_equal_approx(active_portrait.circle_front_plate.energy_ratio, 0.5))
	assert(active_portrait.cooldown_mask.active)
	assert(is_equal_approx(active_portrait.cooldown_mask.cooldown_ratio, 0.5))
	var active_slot: Dictionary = team_rows[1]["slots"][0]
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

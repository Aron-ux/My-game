extends SceneTree

const COMBAT_SKILL_BAR := preload("res://scripts/ui/hud/combat_skill_bar.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var container := Control.new()
	root.add_child(container)
	var cooldown := COMBAT_SKILL_BAR.SkillCooldownIcon.new()
	var portrait := COMBAT_SKILL_BAR.SwitchPortraitDisplay.new()
	var ultimate := COMBAT_SKILL_BAR.UltimateEnergyDisplay.new()
	for widget in [cooldown, portrait, ultimate]:
		container.add_child(widget)
		assert(not widget.is_processing(), "idle widgets should not process frames")
	cooldown.set_auto_mode(true)
	assert(not cooldown.is_processing(), "locked skills should not animate")
	cooldown.set_state(true, Color.WHITE, 0.5)
	portrait.set_state(0.5, 0.9995, true)
	ultimate.set_state(0.9995)
	for widget in [cooldown, portrait, ultimate]:
		assert(widget.is_processing(), "visible ready widgets should animate")
	container.hide()
	for widget in [cooldown, portrait, ultimate]:
		assert(not widget.is_processing(), "hidden ancestor should suspend animation")
	container.show()
	for widget in [cooldown, portrait, ultimate]:
		assert(widget.is_processing(), "showing the ancestor should resume ready animation")
	cooldown.set_auto_mode(false)
	portrait.set_state(0.0, 0.5, true)
	ultimate.set_state(0.5)
	for widget in [cooldown, portrait, ultimate]:
		assert(not widget.is_processing(), "leaving the ready state should stop animation")
	cooldown.set_auto_mode(true)
	cooldown.set_state(false, Color.WHITE, 0.0)
	assert(not cooldown.is_processing(), "locking a skill should stop animation")

	var bar := COMBAT_SKILL_BAR.new()
	container.add_child(bar)
	bar.set_hud_layout("legacy")
	bar.update_switch_cooldown("swordsman", 0.0, 0.5)
	bar._begin_skill_slot_drag(1, "", "blade_storm", "剑刃风暴")
	bar._create_skill_slot_drag_ghost()
	var ghost: Control = bar.skill_slot_drag_state["ghost"]
	bar.update_switch_cooldown("gunner", 0.0, 0.5)
	assert(bar.skill_slot_drag_state.is_empty(), "changing the viewed role should cancel a drag of its slots")
	await process_frame
	assert(not is_instance_valid(ghost), "switching roles should dispose the old ghost")
	bar._begin_skill_slot_drag(1, "", "blade_storm", "剑刃风暴")
	bar._create_skill_slot_drag_ghost()
	ghost = bar.skill_slot_drag_state["ghost"]
	bar.set_hud_layout("team_band")
	assert(bar.skill_slot_drag_state.is_empty(), "layout rebuild should cancel pending drag state")
	await process_frame
	assert(not is_instance_valid(ghost), "layout rebuild should dispose the old ghost")
	bar._begin_skill_slot_drag(1, "swordsman", "blade_storm", "剑刃风暴")
	bar._create_skill_slot_drag_ghost()
	ghost = bar.skill_slot_drag_state["ghost"]
	container.hide()
	assert(bar.skill_slot_drag_state.is_empty(), "hiding the HUD should cancel pending drag state")
	await process_frame
	assert(not is_instance_valid(ghost), "hiding the HUD should dispose the ghost")
	container.queue_free()
	await process_frame
	print("HUD_WIDGET_LIFECYCLE_SMOKE_OK")
	quit(0)

extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PLAYER_TIMER_FLOW := preload("res://scripts/player/player_timer_flow.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var player = PLAYER_SCENE.instantiate()
	scene.add_child(player)
	await process_frame

	_set_active_role(player, "gunner")
	player.mage_arcane_surplus_remaining = 5.0
	var base_gunner_damage: float = player._get_role_damage("gunner")
	_set_level_talents(player, "mage", ["mage_level_talent_arcane_surplus_1"])
	assert(is_equal_approx(player._get_mage_arcane_surplus_damage_multiplier("gunner"), 1.10))
	assert(is_equal_approx(player._get_role_damage("gunner"), base_gunner_damage * 1.10))
	assert(is_equal_approx(player._get_mage_arcane_surplus_damage_multiplier("swordsman"), 1.0))

	_set_level_talents(player, "mage", ["mage_level_talent_arcane_surplus_2"])
	assert(is_equal_approx(player._get_mage_arcane_surplus_skill_cooldown_tick_multiplier("gunner"), 1.0 / 0.9))
	player.gunner_shrapnel_field_ability.cooldown_remaining = 10.0
	player.swordsman_blade_storm_ability.cooldown_remaining = 10.0
	PLAYER_TIMER_FLOW.update_timers(player, 1.0)
	assert(is_equal_approx(player.gunner_shrapnel_field_ability.cooldown_remaining, 10.0 - (1.0 / 0.9)))
	assert(is_equal_approx(player.swordsman_blade_storm_ability.cooldown_remaining, 9.0))

	scene.queue_free()
	await process_frame
	current_scene = null
	print("MAGE_ARCANE_SURPLUS_LEVEL_TALENTS_SMOKE_OK")
	quit(0)


func _set_level_talents(player: Node, role_id: String, talent_ids: Array) -> void:
	var state: Dictionary = player.role_special_states.get(role_id, {})
	state["level_talents"] = talent_ids.duplicate()
	player.role_special_states[role_id] = state


func _set_active_role(player: Node, role_id: String) -> void:
	for index in range(player.roles.size()):
		if str(player.roles[index].get("id", "")) == role_id:
			player.active_role_index = index
			player._update_active_role_state()
			return

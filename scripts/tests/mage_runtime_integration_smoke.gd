extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BULLET := preload("res://scripts/bullet.gd")
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

	_set_trait_path(player, ["mage_trait_relay", "mage_trait_overflow", "mage_trait_dawn"])
	for index in range(player.roles.size()):
		if str(player.roles[index].get("id", "")) == "mage":
			player.active_role_index = index
			break
	player._update_active_role_state()
	player.mage_arcane_surplus_remaining = 0.01
	player.mage_arcane_charge_stacks = 0
	PLAYER_TIMER_FLOW.update_timers(player, 0.02)
	assert(player.mage_arcane_charge_stacks == 5)

	_set_trait_path(player, ["mage_trait_relay", "mage_trait_flow", "mage_trait_dawn"])
	player.mage_arcane_charge_stacks = 8
	player._transfer_mage_arcane_charge_to_role_on_switch("gunner")
	assert(is_equal_approx(player.mage_arcane_charge_transfer_duration, 11.2))
	assert(bool(player.role_special_states["mage"].get("arcane_dawn_armed", false)))

	player._clear_mage_arcane_charge_transfer(false)
	_set_trait_path(player, ["mage_trait_relay", "mage_trait_flow", "mage_trait_relay_chain"])
	player.mage_arcane_charge_stacks = 10
	player._transfer_mage_arcane_charge_to_role_on_switch("gunner")
	assert(is_equal_approx(player.mage_arcane_charge_transfer_remaining, 14.0))
	player._relay_mage_arcane_charge_on_switch("gunner", "swordsman")
	assert(player._get_mage_arcane_relay_count() == 1)
	assert(is_equal_approx(player.mage_arcane_charge_transfer_remaining, 9.8))
	player._relay_mage_arcane_charge_on_switch("swordsman", "gunner")
	assert(player._get_mage_arcane_relay_count() == 2)
	assert(is_equal_approx(player.mage_arcane_charge_transfer_remaining, 6.86))
	player._relay_mage_arcane_charge_on_switch("gunner", "swordsman")
	assert(player.mage_arcane_charge_transfer_remaining == 0.0)
	assert(player._get_mage_arcane_relay_count() == 0)

	player.role_special_states["swordsman"]["blood_surge_remaining"] = 2.0
	player.role_special_states["gunner"]["talent_runtime"] = {
		"follow_fire_remaining": 2.0,
		"execution_cooldown_remaining": 2.0
	}
	player.role_special_states["mage"]["arcane_dawn_armed"] = true
	player.role_special_states["mage"]["arcane_relay_count"] = 1
	player.switch_power_remaining = 3.0
	player.switch_power_role_id = "swordsman"
	player.switch_power_damage_multiplier = 1.15
	player.switch_power_label = "血战昂扬"
	player._clear_skill_talent_runtime_state([
		"swordsman_trait_blood_surge",
		"swordsman_trait_blood_battle",
		"gunner_trait_execution",
		"mage_trait_dawn",
		"mage_trait_relay_chain"
	])
	assert(not player.role_special_states["swordsman"].has("blood_surge_remaining"))
	assert(not player.role_special_states["gunner"]["talent_runtime"].has("execution_cooldown_remaining"))
	assert(float(player.role_special_states["gunner"]["talent_runtime"].get("follow_fire_remaining", 0.0)) == 2.0)
	assert(not player.role_special_states["mage"].has("arcane_dawn_armed"))
	assert(not player.role_special_states["mage"].has("arcane_relay_count"))
	assert(player.switch_power_remaining == 0.0)
	assert(player.switch_power_role_id == "")

	var rapid_wave = BULLET.new()
	rapid_wave.damage = 100.0
	rapid_wave.pierce_count = 1
	rapid_wave.set_meta("mage_surge_rapid", true)
	scene.add_child(rapid_wave)
	var elite := DamageTarget.new()
	elite.enemy_kind = "elite"
	scene.add_child(elite)
	rapid_wave._apply_hit(elite)
	assert(is_equal_approx(elite.received_damage, 115.0))
	assert(not rapid_wave._can_hit_enemy(elite))

	scene.queue_free()
	await process_frame
	current_scene = null
	print("MAGE_RUNTIME_INTEGRATION_SMOKE_OK")
	quit(0)


func _set_trait_path(player: Node, talent_ids: Array) -> void:
	var state: Dictionary = player.role_special_states.get("mage", {})
	var talents: Dictionary = state.get("skill_talents", {})
	talents["mage_trait"] = talent_ids
	state["skill_talents"] = talents
	player.role_special_states["mage"] = state


class DamageTarget:
	extends Node2D

	var enemy_kind := "normal"
	var pooled_inactive := false
	var rebirth_timer := 0.0
	var current_health := 1000.0
	var received_damage := 0.0

	func take_damage(amount: float, _is_critical: bool = false) -> bool:
		received_damage += amount
		current_health -= amount
		return false

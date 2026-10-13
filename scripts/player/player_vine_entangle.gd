extends RefCounted

const META := "vine_entangle_state"
const DURATION := 1.5
const TICK := 0.5


static func on_damage(player, enemy, damage: float) -> void:
	if damage <= 0 or enemy == null or not is_instance_valid(enemy) or str(enemy.get("archetype_id")) != "vine":
		return
	apply(player, maxf(0, float(enemy.attack)) * 0.5)


static func apply(player, tick_damage: float) -> void:
	if player.has_method("_is_status_immune") and player._is_status_immune():
		return
	var duration := preload("res://scripts/combat/status_resistance.gd").duration(player, DURATION)
	var state: Dictionary = player.get_meta(META, {})
	state["remaining"] = duration
	state["damage"] = tick_damage
	state["elapsed"] = float(state.get("elapsed", 0.0))
	player.set_meta(META, state)
	if player.has_method("_start_entangled_status"):
		player._start_entangled_status(DURATION)


static func get_remaining(player) -> float:
	if player == null:
		return 0.0
	return maxf(0, float(player.get_meta(META, {}).get("remaining", 0.0)))


static func tick(player, delta: float) -> void:
	var state: Dictionary = player.get_meta(META, {})
	var remaining := float(state.get("remaining", 0.0))
	if remaining <= 0:
		return
	if player.has_method("_is_status_immune") and player._is_status_immune():
		player.remove_meta(META)
		return
	var active_delta := minf(delta, remaining)
	state["remaining"] = maxf(0, remaining - active_delta)
	state["elapsed"] = float(state.get("elapsed", 0.0)) + active_delta
	while float(state["elapsed"]) >= TICK - 0.000001:
		state["elapsed"] = maxf(0, float(state["elapsed"]) - TICK)
		# No enemy source: periodic damage cannot refresh its own root.
		player.take_damage(float(state.get("damage", 0.0)))
	if float(state["remaining"]) <= 0.000001:
		player.remove_meta(META)
	else:
		player.set_meta(META, state)


static func get_buff_slot(player) -> Dictionary:
	var remaining := get_remaining(player)
	if remaining <= 0:
		return {}
	return {
		"id": "vine_entangle", "name": "缠绕", "text": "缠",
		"description": "无法移动，仍可攻击和施法；每0.5秒受到藤蔓怪50%攻击力伤害。重复命中刷新持续时间。",
		"remaining": remaining, "duration": DURATION, "cooldown": false,
		"color": Color(0.55, 0.8, 0.3), "base_color": Color(0.12, 0.23, 0.1)
	}

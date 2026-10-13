extends RefCounted

const DOMAIN := preload("res://scripts/enemies/skull_mage_domain.gd")
const LIMIT := 4
const DRAIN_TRIGGER_RADIUS := 200.0
const DRAIN_DISTANCE := 250.0


static func reset(enemy) -> void:
	enemy.skull_mage_state = {
		"drain_cooldown": 0.0, "proximity": 0.0, "drain_remaining": 0.0,
		"drain_elapsed": 0.0, "ice_cooldown": 20.0, "ice_remaining": 0.0,
		"temporary_health": 0.0, "domain_cooldown": 25.0,
		"death_used": false, "invulnerable_remaining": 0.0
	}


static func is_mage(enemy) -> bool:
	return enemy != null and str(enemy.get("archetype_id")) == "skull_mage"


static func is_ice_active(enemy) -> bool:
	return is_mage(enemy) and float(enemy.skull_mage_state.get("ice_remaining", 0.0)) > 0


static func is_draining(enemy) -> bool:
	return is_mage(enemy) and float(enemy.skull_mage_state.get("drain_remaining", 0.0)) > 0


static func is_invulnerable(enemy) -> bool:
	return is_mage(enemy) and float(enemy.skull_mage_state.get("invulnerable_remaining", 0.0)) > 0


static func tick_passives(enemy, delta: float) -> void:
	if not is_mage(enemy):
		return
	var state: Dictionary = enemy.skull_mage_state
	for key in ["drain_cooldown", "ice_cooldown", "ice_remaining", "domain_cooldown", "invulnerable_remaining"]:
		state[key] = maxf(0.0, float(state.get(key, 0.0)) - delta)
	if not is_ice_active(enemy):
		state["temporary_health"] = 0.0
	if enemy.stun_remaining > 0:
		state["drain_remaining"] = 0.0
		state["drain_elapsed"] = 0.0
		state["proximity"] = 0.0
	sync_visual(enemy)


static func update(enemy, delta: float) -> void:
	if not is_mage(enemy) or not is_instance_valid(enemy.target) or enemy.current_health <= 0:
		return
	var state: Dictionary = enemy.skull_mage_state
	if float(state.get("ice_cooldown", 0.0)) <= 0:
		state["ice_cooldown"] = 20.0
		state["ice_remaining"] = 10.0
		state["temporary_health"] = 20.0
	if float(state.get("domain_cooldown", 0.0)) <= 0 and can_cast_domain(enemy):
		state["domain_cooldown"] = 25.0
		var field := DOMAIN.new()
		field.player = enemy.target
		field.position = enemy.global_position
		enemy.get_tree().current_scene.add_child(field)
	var distance: float = enemy.global_position.distance_to(enemy.target.global_position)
	if is_draining(enemy):
		state["drain_elapsed"] = float(state.get("drain_elapsed", 0.0)) + minf(delta, float(state["drain_remaining"]))
		state["drain_remaining"] = maxf(0.0, float(state["drain_remaining"]) - delta)
		while float(state["drain_elapsed"]) >= 1.0:
			state["drain_elapsed"] = float(state["drain_elapsed"]) - 1.0
			drain_hit(enemy)
		if distance > DRAIN_DISTANCE or float(state["drain_remaining"]) <= 0:
			if distance > DRAIN_DISTANCE and float(state["drain_elapsed"]) > 0.000001:
				drain_hit(enemy)
			state["drain_elapsed"] = 0.0
			state["drain_remaining"] = 0.0
			state["proximity"] = 0.0
	elif float(state.get("drain_cooldown", 0.0)) <= 0:
		state["proximity"] = float(state.get("proximity", 0.0)) + delta if distance <= DRAIN_TRIGGER_RADIUS else 0.0
		if float(state["proximity"]) >= 3.0:
			state["drain_cooldown"] = 13.0
			state["drain_remaining"] = 8.0
			state["drain_elapsed"] = 0.0
			state["proximity"] = 0.0
	sync_visual(enemy)


static func drain_hit(enemy) -> void:
	var player = enemy.target
	if not is_instance_valid(player) or not player.has_method("take_damage"):
		return
	var before := maxf(0.0, float(player.current_health)) + maxf(0.0, float(player.get("current_temporary_health")))
	player.take_damage(maxf(0.0, float(enemy.attack)))
	var after := maxf(0.0, float(player.current_health)) + maxf(0.0, float(player.get("current_temporary_health")))
	enemy.current_health = minf(enemy.max_health, enemy.current_health + maxf(0.0, before - after))


static func absorb_temporary_health(enemy, damage: float) -> float:
	if not is_ice_active(enemy):
		return damage
	var state: Dictionary = enemy.skull_mage_state
	var absorbed := minf(maxf(0.0, float(state.get("temporary_health", 0.0))), maxf(0.0, damage))
	state["temporary_health"] = maxf(0.0, float(state.get("temporary_health", 0.0)) - absorbed)
	return maxf(0.0, damage - absorbed)


static func try_death_save(enemy) -> bool:
	if not is_mage(enemy) or enemy.current_health > 0 or bool(enemy.skull_mage_state.get("death_used", false)):
		return false
	var scene: Node = enemy.get_tree().current_scene if enemy.is_inside_tree() else null
	if scene == null:
		return false
	var profile: Variant = scene.get("difficulty_profile")
	if profile is not Dictionary or int(profile.get("tier", 0)) < 3:
		return false
	enemy.current_health = 1.0
	enemy.skull_mage_state["death_used"] = true
	enemy.skull_mage_state["invulnerable_remaining"] = 2.0
	sync_visual(enemy)
	return true


static func sync_visual(enemy) -> void:
	var visual: Node = enemy.get_node_or_null("ProfileVisual")
	if visual == null or visual.get("ice_active") == null:
		return
	visual.ice_active = is_ice_active(enemy)
	visual.invulnerable = is_invulnerable(enemy)
	visual.draining = is_draining(enemy)
	if is_instance_valid(enemy.target):
		visual.drain_target = enemy.target.global_position


static func can_spawn(main: Node) -> bool:
	var count := 0
	for enemy in main.get_tree().get_nodes_in_group("enemies"):
		if is_mage(enemy) and not enemy.pooled_inactive and enemy.current_health > 0 and not enemy.is_queued_for_deletion():
			count += 1
	return count < LIMIT


static func can_cast_domain(enemy) -> bool:
	if not enemy.is_inside_tree():
		return false
	for field in enemy.get_tree().get_nodes_in_group("skull_mage_domains"):
		if is_instance_valid(field) and not field.is_queued_for_deletion() and float(field.remaining) > 0.0:
			return false
	return true

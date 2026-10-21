extends RefCounted


static func update_background_effects(owner, delta: float) -> void:
	if owner == null or owner.is_dead or owner.roles.is_empty():
		return
	var mage_index: int = -1
	for index in range(owner.roles.size()):
		if str(owner.roles[index].get("id", "")) == "mage":
			mage_index = index
			break
	if mage_index < 0 or mage_index == owner.active_role_index:
		return
	var build := preload("res://scripts/player/player_mage_basic_build.gd")
	if not build.has_choice(owner, "quake"):
		return
	var interval: float = owner._get_effective_attack_interval("mage")
	var cooldown: float = maxf(0.0, float(owner.background_cooldowns.get("mage", interval)) - delta)
	if cooldown <= 0.0:
		if owner.mage_role != null:
			owner.mage_role.perform_background(owner)
		cooldown = interval
	owner.background_cooldowns["mage"] = cooldown


static func save_role_cooldown(owner, previous_role_id: String) -> void:
	var build := preload("res://scripts/player/player_mage_basic_build.gd")
	if not build.has_choice(owner, "quake"):
		return
	if previous_role_id == "mage" and owner.fire_timer != null and not owner.fire_timer.is_stopped():
		owner.background_cooldowns["mage"] = owner.fire_timer.time_left


static func restore_role_cooldown(owner, active_role_id: String) -> void:
	var build := preload("res://scripts/player/player_mage_basic_build.gd")
	if not build.has_choice(owner, "quake"):
		return
	if active_role_id == "mage":
		var interval: float = owner._get_effective_attack_interval("mage")
		var remaining: float = clampf(float(owner.background_cooldowns.get("mage", interval)), 0.0, interval)
		owner.fire_timer.wait_time = interval
		if bool(owner.get_meta("mage_casting", false)):
			owner.fire_timer.stop()
		else:
			owner.fire_timer.start(maxf(0.001, remaining))


static func trigger_background_effect(owner, role_index: int) -> void:
	var role_id: String = owner.roles[role_index]["id"]
	match role_id:
		"swordsman":
			if owner.swordsman_role != null:
				owner.swordsman_role.perform_background(owner)
		"gunner":
			if owner.gunner_role != null:
				owner.gunner_role.perform_background(owner)
		"mage":
			if owner.mage_role != null:
				owner.mage_role.perform_background(owner)
		"mechanic":
			if owner.mechanic_role != null:
				owner.mechanic_role.perform_background(owner)


static func perform_active_attack(owner) -> void:
	if owner.is_dead:
		return
	if owner.has_method("_is_player_action_locked") and owner._is_player_action_locked():
		return
	if owner.has_method("is_gunner_infinite_reload_blocking_actions") and owner.is_gunner_infinite_reload_blocking_actions():
		return

	var role_id: String = owner._get_active_role()["id"]
	match role_id:
		"swordsman":
			owner._perform_swordsman_attack()
		"gunner":
			owner._perform_gunner_attack()
		"mage":
			owner._perform_mage_attack()
		"mechanic":
			owner._perform_mechanic_attack()

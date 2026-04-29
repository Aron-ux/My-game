extends RefCounted


static func update_background_effects(owner, delta: float) -> void:
	for role_index in range(owner.roles.size()):
		if role_index == owner.active_role_index:
			continue

		var role_id: String = owner.roles[role_index]["id"]
		owner.background_cooldowns[role_id] = float(owner.background_cooldowns.get(role_id, 0.0)) - delta
		if float(owner.background_cooldowns[role_id]) > 0.0:
			continue

		trigger_background_effect(owner, role_index)
		owner.background_cooldowns[role_id] = owner._get_effective_background_attack_interval(role_id)


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


static func perform_active_attack(owner) -> void:
	if owner.is_dead:
		return

	var role_id: String = owner._get_active_role()["id"]
	match role_id:
		"swordsman":
			owner._perform_swordsman_attack()
		"gunner":
			owner._perform_gunner_attack()
		"mage":
			owner._perform_mage_attack()

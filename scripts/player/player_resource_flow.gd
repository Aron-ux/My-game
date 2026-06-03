extends RefCounted

const ROLE_RESOURCE_STATE := preload("res://scripts/player/roles/role_resource_state.gd")

const ULTIMATE_ENERGY_GAIN_OUTPUT_MULTIPLIER := 0.625


static func get_active_role(owner) -> Dictionary:
	return owner.roles[owner.active_role_index]


static func get_active_role_id(owner) -> String:
	return str(get_active_role(owner).get("id", ""))


static func build_role_resource_state_data(owner, default_value: Variant) -> Dictionary:
	return ROLE_RESOURCE_STATE.build_for_roles(owner.roles, default_value)


static func get_role_mana(owner, role_id: String) -> float:
	return ROLE_RESOURCE_STATE.get_mana(owner.role_mana_values, role_id, owner.max_mana)


static func set_role_mana(owner, role_id: String, value: float, emit_for_active: bool = true) -> void:
	ROLE_RESOURCE_STATE.set_mana(owner.role_mana_values, role_id, value, owner.max_mana)
	if role_id == get_active_role_id(owner):
		sync_active_role_ultimate_state(owner)
		if emit_for_active:
			owner.mana_changed.emit(owner.current_mana, owner.max_mana)


static func add_role_mana(owner, role_id: String, amount: float, emit_for_active: bool = true) -> float:
	if amount == 0.0:
		return get_role_mana(owner, role_id)
	if amount > 0.0:
		amount *= ULTIMATE_ENERGY_GAIN_OUTPUT_MULTIPLIER
		if amount <= 0.0:
			return get_role_mana(owner, role_id)
	var updated_value: float = ROLE_RESOURCE_STATE.add_mana(owner.role_mana_values, role_id, amount, owner.max_mana)
	if role_id == get_active_role_id(owner):
		sync_active_role_ultimate_state(owner)
		if emit_for_active:
			owner.mana_changed.emit(owner.current_mana, owner.max_mana)
	return updated_value


static func add_active_role_mana(owner, amount: float, emit_signal: bool = true) -> float:
	return add_role_mana(owner, get_active_role_id(owner), amount, emit_signal)


static func get_role_ultimate_lock_remaining(owner, role_id: String) -> float:
	return ROLE_RESOURCE_STATE.get_lock_remaining(owner.role_ultimate_energy_lock_remaining, role_id)


static func set_role_ultimate_lock_remaining(owner, role_id: String, value: float) -> void:
	ROLE_RESOURCE_STATE.set_lock_remaining(owner.role_ultimate_energy_lock_remaining, role_id, value)
	if role_id == get_active_role_id(owner):
		sync_active_role_ultimate_state(owner)


static func sync_active_role_ultimate_state(owner) -> void:
	var active_role_id: String = get_active_role_id(owner)
	owner.current_mana = get_role_mana(owner, active_role_id)
	owner.ultimate_energy_lock_remaining = get_role_ultimate_lock_remaining(owner, active_role_id)


static func emit_active_mana_changed(owner) -> void:
	sync_active_role_ultimate_state(owner)
	owner.mana_changed.emit(owner.current_mana, owner.max_mana)


static func get_role_special_state(owner, role_id: String) -> Dictionary:
	if not owner.role_special_states.has(role_id):
		owner.role_special_states[role_id] = {}
	return owner.role_special_states[role_id]


static func increase_role_special(owner, role_id: String, key: String, amount: int = 1) -> void:
	var special_data: Dictionary = get_role_special_state(owner, role_id)
	special_data[key] = int(special_data.get(key, 0)) + amount
	owner.role_special_states[role_id] = special_data


static func increase_team_specials(owner, entries: Array) -> void:
	for entry in entries:
		if entry is Dictionary:
			increase_role_special(owner, str(entry.get("role_id", "")), str(entry.get("key", "")), int(entry.get("amount", 1)))


static func add_energy(owner, amount: float) -> void:
	if amount <= 0.0:
		return
	var effective_amount: float = amount * ULTIMATE_ENERGY_GAIN_OUTPUT_MULTIPLIER
	if effective_amount <= 0.0:
		return
	var active_role_id: String = get_active_role_id(owner)
	var self_amount: float = amount
	if active_role_id == "mage" and owner.has_method("_get_mage_arcane_charge_self_energy_multiplier"):
		self_amount *= max(0.0, float(owner._get_mage_arcane_charge_self_energy_multiplier()))
	var updated_mana: float = add_role_mana(owner, active_role_id, self_amount, false)
	if active_role_id == "mage" and owner.mage_arcane_surplus_remaining > 0.0:
		for role_data in owner.roles:
			var role_id: String = str(role_data.get("id", ""))
			if role_id == "" or role_id == active_role_id:
				continue
			add_role_mana(owner, role_id, amount, false)
	if owner._has_elite_relic("elite_reactor") and is_equal_approx(updated_mana, owner.max_mana):
		owner._activate_switch_power(active_role_id, "\u6EE1\u80FD\u53CD\u5E94", 2.8, 1.14, 0.04)
	emit_active_mana_changed(owner)


static func heal(owner, amount: float) -> void:
	if amount <= 0.0 or owner.is_dead:
		return
	if owner.has_method("is_healing_blocked") and owner.is_healing_blocked():
		return
	owner.current_health = min(owner.max_health, owner.current_health + amount)
	if owner.has_method("_save_active_role_health"):
		owner._save_active_role_health()
	owner.health_changed.emit(owner.current_health, owner.max_health)


static func die(owner) -> void:
	if owner.is_dead:
		return

	owner.current_health = 0.0
	if owner.has_method("_save_active_role_health"):
		owner._save_active_role_health()
	owner.health_changed.emit(owner.current_health, owner.max_health)
	if owner.has_method("_update_player_health_bar"):
		owner._update_player_health_bar(owner._get_active_role())

	owner.is_dead = true
	owner.level_up_active = false
	owner.fire_timer.stop()
	owner.died.emit()

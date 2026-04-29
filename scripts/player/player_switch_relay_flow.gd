extends RefCounted


static func prepare_relay_window(owner, from_role_index: int, to_role_index: int, exit_hits: int, entry_hits: int) -> void:
	if exit_hits <= 0 and entry_hits <= 0:
		owner.relay_window_remaining = 0.0
		owner.relay_ready_role_id = ""
		owner.relay_from_role_id = ""
		owner.relay_label = ""
		owner.relay_bonus_pending = false
		return

	var from_role_id: String = str(owner.roles[from_role_index]["id"])
	var to_role_id: String = str(owner.roles[to_role_index]["id"])
	var from_role_name: String = str(owner.roles[from_role_index]["name"])
	var to_role_name: String = str(owner.roles[to_role_index]["name"])
	owner.relay_window_remaining = 2.2 + owner._get_card_level("combat_relay") * 0.45
	owner.relay_ready_role_id = to_role_id
	owner.relay_from_role_id = from_role_id
	owner.relay_label = "%s -> %s" % [from_role_name, to_role_name]
	owner.relay_bonus_pending = true
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -54.0), "\u63A5\u529B\u5F85\u547D", Color(1.0, 0.94, 0.62, 1.0))
	owner.stats_changed.emit(owner.get_stat_summary())


static func trigger_relay_success(owner, role_id: String, hit_count: int) -> void:
	if not owner.relay_bonus_pending:
		return
	if owner.relay_window_remaining <= 0.0:
		return
	if role_id != owner.relay_ready_role_id:
		return
	if hit_count <= 0:
		return

	var relay_level: int = owner._get_card_level("combat_relay")
	owner.relay_bonus_pending = false
	var relay_energy: float = (7.0 + float(min(hit_count, 2)) * 1.6 + relay_level * 2.0) * owner.energy_gain_multiplier
	owner._add_energy(relay_energy)
	owner.switch_cooldown_remaining = max(0.0, owner.switch_cooldown_remaining - (1.6 + relay_level * 0.35))
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, 0.12)
	owner._activate_switch_power(role_id, "\u63A5\u529B\u8D85\u8F7D", 1.8 + relay_level * 0.25, 1.34 + relay_level * 0.06, 0.12 + relay_level * 0.02)
	owner._show_switch_banner("\u63A5\u529B", owner.relay_label, Color(1.0, 0.9, 0.56, 1.0))
	owner._spawn_ring_effect(owner.global_position, 68.0, Color(1.0, 0.9, 0.56, 0.72), 7.0, 0.18)
	owner.relay_window_remaining = 0.0
	owner.relay_ready_role_id = ""
	owner.relay_from_role_id = ""
	owner.relay_label = ""
	owner.stats_changed.emit(owner.get_stat_summary())


static func apply_switch_payoff(owner, hit_count: int, energy_gain: float, cooldown_refund: float) -> void:
	if hit_count <= 0:
		return

	var relay_level: int = owner._get_card_level("combat_relay")
	var switch_energy: float = (energy_gain + float(min(hit_count, 2)) * 1.2 + relay_level * 0.8) * owner.energy_gain_multiplier
	owner._add_energy(switch_energy)
	owner.switch_cooldown_remaining = max(0.0, owner.switch_cooldown_remaining - (cooldown_refund + relay_level * 0.12))

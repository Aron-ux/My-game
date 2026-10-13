extends RefCounted

const BUILD := preload("res://scripts/player/player_mage_basic_build.gd")
const BOMBARD := preload("res://scripts/player/player_mage_bombardment_flow.gd")

static func perform(owner) -> void:
	var state: Dictionary = BUILD.state(owner)
	if bool(owner.get_meta("mage_casting", false)):
		return
	var role: Dictionary = owner._get_active_role()
	var center: Vector2 = owner._get_mage_mouse_bombard_center(float(role["range"]))
	var upgrades: Dictionary = owner.role_upgrade_levels["mage"]
	var radius: float = (43.75 + float(upgrades.get("range_bonus", 0.0)) * 0.55) * 0.8
	radius *= owner._get_role_attribute_range_multiplier("mage") * owner._get_role_equipment_skill_range_multiplier("mage")
	radius *= BUILD.range_multiplier(owner)
	var storm: bool = BUILD.has_choice(owner, "storm")
	owner.set_meta("mage_casting", storm)
	owner.role_special_states["mage"] = state
	if storm:
		owner.fire_timer.stop()
	owner._spawn_mage_warning_scene_effect(center, radius)
	var warning: float = owner._get_scene_animation_duration(owner.MAGE_WARNING_EFFECT_SCENE, 0.2)
	_schedule_strike(owner, center, radius, 0, storm, warning)

static func _schedule_strike(owner, center: Vector2, radius: float, index: int, storm: bool, delay: float) -> void:
	owner._schedule_repeating_sequence(0.0, 1, func(_unused: int) -> void:
		if not is_instance_valid(owner):
			return
		if not owner.is_dead:
			strike(owner, center, radius, index, storm)
		if storm and index < 2 and not owner.is_dead:
			_schedule_strike(owner, center, radius, index + 1, true, 0.2 if index == 0 else 0.45)
		else:
			owner.set_meta("mage_casting", false)
			if storm and not owner.is_dead and str(owner._get_active_role()["id"]) == "mage":
				owner._update_fire_timer()
	, delay)

static func strike(owner, center: Vector2, base_radius: float, index: int = 0, storm: bool = false, divine: bool = false) -> void:
	var scale: float = 1.5 if divine else pow(0.65, index) if storm else 1.0
	var radius: float = base_radius * (1.0 + 0.3 * index if storm and not divine else 1.0)
	var damage: float = owner._get_role_damage("mage") * BUILD.strike_ratio(owner, scale)
	var effect: Node2D = owner._spawn_mage_boom_scene_effect(center, radius)
	if divine and effect != null:
		effect.modulate = Color(1.7, 1.25, 0.2, 1.0)
	owner._queue_camera_shake(5.8 + (index * 3.0 if storm else 0.0), 0.12 + (index * 0.04 if storm else 0.0))
	var source: String = owner._create_basic_attack_source_id("mage")
	var hit_radius_y: float = maxf(BOMBARD.BOOM_VISUAL_MIN_VERTICAL_RADIUS, radius * BOMBARD.BOOM_VISUAL_VERTICAL_RADIUS_SCALE)
	owner._damage_enemies_in_ellipse(center, radius * BOMBARD.BOOM_DAMAGE_HORIZONTAL_RADIUS_SCALE, hit_radius_y, damage, 0.0, 1.0, 0.0, source)
	if not divine and BUILD.has_choice(owner, "divine"):
		var state: Dictionary = BUILD.state(owner)
		var count: int = int(state.get("mage_divine_count", 0)) + 1
		state["mage_divine_count"] = count % 3
		if count >= 3:
			# Do not count the proc as another ordinary strike.
			owner._schedule_repeating_sequence(0.0, 1, func(_unused: int) -> void:
				if is_instance_valid(owner) and not owner.is_dead:
					strike(owner, center, base_radius, 0, false, true)
			, 0.1)

static func after_hit(owner, enemy, source: String, killed: bool) -> void:
	if owner == null or not source.begins_with("mage_basic:") or killed or not is_instance_valid(enemy):
		return
	if enemy.get("boss_phase_transition_target") != null and (enemy.boss_phase_transition_target > 0 or enemy.boss_phase_three_intro_remaining > 0.0 or enemy.rebirth_timer > 0.0 or enemy.skull_damage_immune_timer > 0.0):
		return
	if BUILD.has_choice(owner, "heaven") and enemy.has_method("take_direct_damage"):
		var direct_amount: float = float(enemy.max_health) * 0.02
		killed = bool(enemy.take_direct_damage(direct_amount))
		var gain: float = 1.0 + BUILD.energy_bonus(owner, source)
		if killed and owner.has_method("_add_kill_energy"):
			owner._add_kill_energy(owner._get_kill_energy_from_enemy(enemy) * gain, "", "mage")
		elif str(enemy.enemy_kind) in ["boss", "small_boss"] and owner.has_method("_add_boss_damage_energy"):
			owner._add_boss_damage_energy(owner._get_boss_damage_energy(direct_amount) * gain)
	if killed or enemy.is_queued_for_deletion() or float(enemy.get("current_health")) <= 0.0:
		return
	if BUILD.has_choice(owner, "charge") and enemy.get("electric_stacks") != null:
		enemy.electric_stacks = mini(3, enemy.electric_stacks + 1)
		preload("res://scripts/enemies/enemy_electric_visual.gd").flash(enemy)
	if BUILD.has_choice(owner, "quake") and enemy.has_method("apply_stun"):
		enemy.apply_stun(0.5)

static func update_speed(owner) -> void:
	if str(owner._get_active_role()["id"]) != "mage" or bool(owner.get_meta("mage_casting", false)):
		return
	var timer: Timer = owner.fire_timer
	if timer == null or timer.is_stopped():
		return
	var interval: float = owner._get_effective_attack_interval("mage")
	if is_equal_approx(interval, timer.wait_time):
		return
	var remaining_fraction: float = timer.time_left / maxf(0.001, timer.wait_time)
	timer.start(maxf(0.001, interval * remaining_fraction))
	timer.wait_time = interval

extends SceneTree

const GunnerRole := preload("res://scripts/player/roles/gunner_role.gd")
const InfiniteReload := preload("res://scripts/abilities/gunner_infinite_reload_ability.gd")
const ShrapnelField := preload("res://scripts/abilities/gunner_shrapnel_field_ability.gd")
const SwitchEntryFlow := preload("res://scripts/player/player_switch_entry_flow.gd")


func _init() -> void:
	var owner := TalentOwner.new()
	root.add_child(owner)
	var role := GunnerRole.new()

	owner.talents = {
		"gunner_basic_mark": true,
		"gunner_basic_penetration": true,
		"gunner_basic_mobile_fire": true
	}
	owner.velocity = Vector2.RIGHT * 10.0
	role._spawn_primary_batched_bullet(owner, Vector2.RIGHT, 10.0, Color.WHITE, {"id": "gunner"}, {"range_bonus": 0.0}, 0, Vector2.ZERO)
	assert(is_equal_approx(float(owner.last_projectile.get("vulnerability_bonus", 0.0)), 0.06))
	assert(int(owner.last_projectile.get("pierce_count", 0)) == 2)
	assert(is_equal_approx(float(owner.last_projectile.get("hit_radius", 0.0)), 16.8))
	assert(is_equal_approx(float(owner.last_projectile.get("speed", 0.0)), 950.0))

	owner.talents = {"gunner_entry_piercing": true}
	owner.projectiles.clear()
	SwitchEntryFlow.fire_gunner_entry_wave(owner, "gunner", 0)
	assert(owner.projectiles.size() == 8)
	assert(int(owner.projectiles[0].get("pierce_count", 0)) == 12)
	var entry_enemy := TalentEnemy.new()
	entry_enemy.global_position = Vector2(100.0, 0.0)
	root.add_child(entry_enemy)
	owner.runtime_enemies = [entry_enemy]
	owner.talents = {"gunner_entry_repulse": true}
	SwitchEntryFlow.fire_gunner_entry_wave(owner, "gunner", 0)
	assert(is_equal_approx(entry_enemy.global_position.x, 100.0))

	owner.talents = {"gunner_shrapnel_rend": true, "gunner_shrapnel_quick_throw": true}
	var shrapnel := ShrapnelField.new()
	assert(is_equal_approx(shrapnel._get_cooldown(owner), 10.92))
	assert(is_equal_approx(shrapnel._get_duration(owner), 3.2))
	shrapnel._damage_field(owner, {"center": Vector2.ZERO, "radius": 50.0, "effect_scale": 1.0})
	assert(is_equal_approx(float(owner.last_radius_damage.get("vulnerability_bonus", 0.0)), 0.05))
	owner.talents = {"gunner_shrapnel_snare": true}
	shrapnel._apply_snare_tail(owner, entry_enemy)
	assert(is_equal_approx(entry_enemy.slow_multiplier, 0.75))
	assert(is_equal_approx(entry_enemy.slow_timer, 0.65))

	owner.talents = {"gunner_infinite_sear": true}
	var infinite := InfiniteReload.new()
	infinite._apply_piercing_beam_damage(owner, Vector2.ZERO, Vector2.RIGHT, 100.0, 20.0, 30.0)
	assert(is_equal_approx(float(owner.last_shapes[0].get("vulnerability_bonus", 0.0)), 0.06))
	assert(is_equal_approx(float(owner.last_shapes[0].get("vulnerability_duration", 0.0)), 0.45))
	owner.talents = {"gunner_infinite_recycle": true}
	infinite.cooldown_remaining = 10.0
	infinite.hit_during_cast = true
	infinite._finish_cast(owner)
	assert(is_equal_approx(infinite.cooldown_remaining, 8.5))
	infinite.last_tick_data = {"origin": Vector2(1.0, 2.0), "direction": Vector2.RIGHT, "length": 30.0, "width": 4.0, "damage": 5.0}
	var infinite_save := infinite.get_save_data()
	assert(JSON.stringify(infinite_save).contains("\"origin\":[1.0,2.0]"))
	var restored_infinite := InfiniteReload.new()
	restored_infinite.apply_save_data(infinite_save)
	assert((restored_infinite.last_tick_data.get("origin", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(1.0, 2.0)))

	owner.talents = {"gunner_entry_hot_start": true, "gunner_entry_follow_fire": true}
	owner.gunner_shrapnel_field_ability.cooldown_remaining = 8.0
	owner.gunner_infinite_reload_ability.cooldown_remaining = 20.0
	role._complete_entry_talents(owner)
	assert(is_equal_approx(owner.gunner_shrapnel_field_ability.cooldown_remaining, 6.0))
	assert(is_equal_approx(owner.gunner_infinite_reload_ability.cooldown_remaining, 16.0))
	assert(is_equal_approx(role.get_basic_attack_interval_multiplier(owner), 0.75))

	var calibration := {"anchor": Vector2.RIGHT, "stable_elapsed": 0.0, "calibrated": false}
	role._update_ultimate_calibration(Vector2.RIGHT, 0.5, calibration)
	assert(bool(calibration.get("calibrated", false)))
	role._update_ultimate_calibration(Vector2.DOWN, 0.1, calibration)
	assert(not bool(calibration.get("calibrated", true)))

	owner.talents = {"gunner_trait_execution": true}
	owner.gunner_flash_stacks = 10
	var enemy := TalentEnemy.new()
	root.add_child(enemy)
	assert(is_equal_approx(role.consume_damage_event_multiplier(owner, "gunner"), 1.6))
	assert(owner.gunner_flash_stacks == 5)

	enemy.queue_free()
	owner.queue_free()
	print("GUNNER_SKILL_TALENTS_SMOKE_OK")
	quit(0)


class TalentAbility:
	extends RefCounted
	var cooldown_remaining := 0.0


class TalentEnemy:
	extends Node2D
	var enemy_kind := "normal"
	var vulnerability_bonus := 0.0
	var slow_multiplier := 1.0
	var slow_timer := 0.0
	func apply_vulnerability(value: float, _duration: float) -> void:
		vulnerability_bonus = value
	func apply_slow(value: float, duration: float) -> void:
		slow_multiplier = min(slow_multiplier, value)
		slow_timer = max(slow_timer, duration)


class TalentOwner:
	extends CharacterBody2D

	var talents: Dictionary = {}
	var role_special_states := {"gunner": {"build_levels": {}}}
	var last_projectile: Dictionary = {}
	var projectiles: Array[Dictionary] = []
	var last_radius_damage: Dictionary = {}
	var last_shapes: Array[Dictionary] = []
	var facing_direction := Vector2.RIGHT
	var gunner_flash_stacks := 0
	var gunner_shrapnel_field_ability := TalentAbility.new()
	var gunner_infinite_reload_ability := TalentAbility.new()
	var runtime_enemies: Array = []

	func _has_skill_talent(talent_id: String) -> bool:
		return bool(talents.get(talent_id, false))

	func _get_role_special_state(role_id: String) -> Dictionary:
		if not role_special_states.has(role_id):
			role_special_states[role_id] = {}
		return role_special_states[role_id]

	func _get_active_role() -> Dictionary:
		return {"id": "gunner"}

	func _get_role_damage(_role_id: String) -> float:
		return 10.0

	func _get_gunner_safe_zone_radius() -> float:
		return 115.0

	func _get_live_enemies() -> Array:
		return runtime_enemies

	func _get_blessing_skill_tier(_skill_id: String) -> int:
		return 1

	func _queue_camera_shake(_strength: float, _duration: float) -> void:
		pass

	func _schedule_repeating_sequence(_interval: float, _count: int, callback: Callable, _initial_delay: float = 0.0) -> void:
		callback.call(0)

	func _damage_enemies_in_radius(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
		last_radius_damage = {
			"center": center,
			"radius": radius,
			"damage": damage_amount,
			"vulnerability_bonus": vulnerability_bonus,
			"slow_multiplier": slow_multiplier,
			"slow_duration": slow_duration,
			"source_role_id": source_role_id
		}
		return 1

	func _damage_enemies_in_shapes_batched(shapes: Array[Dictionary]) -> int:
		last_shapes = shapes
		return 1

	func _spawn_batched_directional_bullet_values(
		direction: Vector2,
		damage_amount: float,
		_color: Color,
		role_id: String = "",
		origin: Variant = null,
		speed: float = 620.0,
		lifetime: float = 1.0,
		hit_radius: float = 10.0,
		_visual_radius: float = 4.2,
		_visual_min_diameter: float = 8.0,
		_visual_outline_color: Color = Color.TRANSPARENT,
		_visual_outline_width: float = 0.0,
		_enemy_hit_radius_scale: float = 0.2,
		_enemy_hit_radius_min: float = 4.0,
		_enemy_hit_radius_max: float = 12.0,
		vulnerability_bonus: float = 0.0,
		vulnerability_duration: float = 0.0,
		_slow_multiplier: float = 1.0,
		_slow_duration: float = 0.0,
		pierce_count: int = 0,
		_wave_amplitude: float = 0.0,
		_wave_frequency: float = 0.0,
		_wave_phase: float = 0.0
	) -> bool:
		last_projectile = {
			"direction": direction,
			"damage": damage_amount,
			"role_id": role_id,
			"origin": origin,
			"speed": speed,
			"lifetime": lifetime,
			"hit_radius": hit_radius,
			"vulnerability_bonus": vulnerability_bonus,
			"vulnerability_duration": vulnerability_duration,
			"pierce_count": pierce_count
		}
		projectiles.append(last_projectile)
		return true

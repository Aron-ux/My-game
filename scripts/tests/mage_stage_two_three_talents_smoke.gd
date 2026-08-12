extends SceneTree

const MageRole := preload("res://scripts/player/roles/mage_role.gd")
const MageMetaField := preload("res://scripts/abilities/mage_meta_field_ability.gd")
const MageSurge := preload("res://scripts/abilities/mage_tidal_surge_ability.gd")


func _init() -> void:
	var owner := TalentOwner.new()
	var role := MageRole.new()
	owner.talents = {"mage_trait_flow": true, "mage_trait_overflow": true, "mage_trait_relay_chain": true, "mage_trait_dawn": true}
	assert(is_equal_approx(role.get_arcane_transfer_duration(owner, 10, 10.0), 14.0))
	assert(role.get_arcane_surplus_expire_stacks(owner, 3) == 5)
	assert(role.get_arcane_relay_limit(owner) == 1)
	assert(is_equal_approx(role.get_arcane_relay_remaining(owner, 10.0), 7.0))
	role.record_arcane_dawn(owner, 8)
	assert(is_equal_approx(role.consume_arcane_dawn_duration_bonus(owner), 2.0))
	assert(is_equal_approx(role.consume_arcane_dawn_duration_bonus(owner), 0.0))

	var meta := MageMetaField.new()
	owner.talents = {"mage_meta_expansion": true, "mage_meta_stasis": true}
	meta.active_remaining = 1.0
	meta.expansion_tick_count = 3
	assert(is_equal_approx(meta._get_radius(owner), 100.0 * pow(1.12, 3.0)))
	assert(is_equal_approx(meta._get_slow_multiplier(owner), 0.38))
	var inner_enemy := EnemyStub.new()
	inner_enemy.global_position = Vector2(20.0, 0.0)
	var boss_enemy := EnemyStub.new()
	boss_enemy.enemy_kind = "boss"
	boss_enemy.global_position = Vector2(20.0, 0.0)
	owner.add_child(inner_enemy)
	owner.add_child(boss_enemy)
	owner.talents = {"mage_meta_inner_ring": true}
	owner.radius_candidates = [inner_enemy, boss_enemy]
	meta._apply_inner_ring_pull(owner)
	assert(owner.radius_query_count == 1)
	assert(inner_enemy.global_position == Vector2.ZERO)
	assert(boss_enemy.global_position == Vector2(20.0, 0.0))

	var surge := MageSurge.new()
	assert(surge._allocate_wake_points(4, 24) == [6, 6, 6, 6])
	assert(surge._allocate_wake_points(1, 24) == [8])
	owner.talents = {"mage_surge_wake": true}
	var wake_budget := {"remaining": 4}
	surge._fire_direction_group(owner, Vector2.ZERO, 10.0, [Vector2.RIGHT, Vector2.DOWN], 1.0, 1.0, true, wake_budget)
	assert(owner.spawned_waves == 2)
	owner.talents.clear()
	var wake_hits := {}
	assert(surge._try_apply_wake_hit(owner, inner_enemy, wake_hits, 20.0))
	assert(not surge._try_apply_wake_hit(owner, inner_enemy, wake_hits, 20.0))
	assert(owner.damage_calls.get(inner_enemy.get_instance_id(), 0) == 1)
	owner.talents = {"mage_ultimate_eclipse": true}
	var ultimate_snapshot := role._build_ultimate_talent_target_state(owner, Vector2.ZERO)
	owner.talents.clear()
	assert(role._cast_has_ultimate_talent(ultimate_snapshot, "mage_ultimate_eclipse"))
	owner.free()
	print("MAGE_STAGE_TWO_THREE_TALENTS_SMOKE_OK")
	quit(0)


class TalentOwner:
	extends Node2D

	var talents: Dictionary = {}
	var role_special_states := {"mage": {"build_levels": {}}}
	var radius_candidates: Array = []
	var radius_query_count := 0
	var damage_calls: Dictionary = {}
	var spawned_waves := 0

	func _has_skill_talent(talent_id: String) -> bool:
		return bool(talents.get(talent_id, false))

	func _get_role_special_state(role_id: String) -> Dictionary:
		return role_special_states.get(role_id, {})

	func _get_blessing_skill_tier(_skill_id: String) -> int:
		return 1

	func _get_equipment_skill_range_multiplier() -> float:
		return 1.0

	func _get_invoker_magic_range_multiplier(_skill_id: String) -> float:
		return 1.0

	func _collect_enemies_in_radius_for_damage_batch(_center: Vector2, _radius: float) -> Array:
		radius_query_count += 1
		return radius_candidates

	func _spawn_directional_bullet_from_scene(_projectile_scene: PackedScene, _direction: Vector2, damage_amount: float, _color: Color, _role_id: String = "", _origin: Variant = null):
		var projectile := ProjectileStub.new()
		projectile.damage = damage_amount
		spawned_waves += 1
		add_child(projectile)
		return projectile

	func _get_role_attribute_range_multiplier(_role_id: String) -> float:
		return 1.0

	func _get_role_equipment_skill_range_multiplier(_role_id: String = "") -> float:
		return 1.0

	func _get_kebiru_magic_range_multiplier(_skill_id: String) -> float:
		return 1.0

	func _deal_damage_to_enemy(enemy: Node, _damage_amount: float, _source_role_id: String) -> bool:
		var enemy_id := enemy.get_instance_id()
		damage_calls[enemy_id] = int(damage_calls.get(enemy_id, 0)) + 1
		return false


class ProjectileStub:
	extends Node2D

	var damage := 0.0
	var speed := 0.0
	var lifetime := 0.0
	var hit_radius := 0.0
	var pierce_count := 0
	var visual_scale_multiplier := 1.0
	var enemy_hit_radius_scale := 0.0
	var enemy_hit_radius_min := 0.0
	var enemy_hit_radius_max := 0.0
	var slow_multiplier := 1.0
	var slow_duration := 0.0

class EnemyStub:
	extends Node2D

	var enemy_kind := "normal"

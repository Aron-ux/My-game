extends SceneTree

const SwordsmanRole := preload("res://scripts/player/roles/swordsman_role.gd")


func _init() -> void:
	var owner := AttackOwner.new()
	root.add_child(owner)
	var role := SwordsmanRole.new()

	owner.hit_results = [2, 1, 1]
	role.perform_attack(owner)
	assert(owner.damage_amounts.size() == 3)
	assert(is_equal_approx(owner.damage_amounts[0], 180.0))
	assert(is_equal_approx(owner.damage_amounts[1], 81.0))
	assert(is_equal_approx(owner.damage_amounts[2], 126.0))
	assert(is_zero_approx(float(owner.role_special_states["swordsman"]["blood_surge_remaining"])))

	owner.damage_amounts.clear()
	owner.hit_results = [0, 0, 0]
	owner.swordsman_attack_chain = 2
	owner.role_special_states["swordsman"]["blood_surge_remaining"] = 2.0
	role.perform_attack(owner)
	assert(is_equal_approx(float(owner.role_special_states["swordsman"]["blood_surge_remaining"]), 2.0))
	print("SWORDSMAN_BASIC_ATTACK_EVENT_SMOKE_OK")
	quit()


class AttackOwner:
	extends Node2D

	const SWORD_SLASH_SCENE_VISIBLE_BOUNDS := Rect2(99.0, 30.0, 27.0, 153.0)
	const SWORD_SLASH_SCENE_SIZE := Vector2(256.0, 212.0)

	var talents := {
		"swordsman_basic_back": true,
		"swordsman_basic_cross": true
	}
	var role_special_states: Dictionary = {
		"swordsman": {
			"blood_surge_remaining": 2.0,
			"build_levels": {}
		}
	}
	var role_upgrade_levels := {"swordsman": {"range_bonus": 0.0}}
	var switch_power_remaining := 0.0
	var switch_power_role_id := ""
	var switch_power_label := ""
	var facing_direction := Vector2.RIGHT
	var swordsman_attack_chain := 2
	var is_dead := false
	var hit_results: Array[int] = []
	var damage_amounts: Array[float] = []

	func _has_skill_talent(talent_id: String) -> bool:
		return bool(talents.get(talent_id, false))

	func _get_attack_aim_direction(fallback: Vector2) -> Vector2:
		return fallback

	func _get_active_role() -> Dictionary:
		return {"id": "swordsman", "range": 100.0}

	func _get_swordsman_normal_attack_scale(_heart_level: float) -> float:
		return 1.0

	func _get_swordsman_normal_attack_width_scale(_heart_level: float) -> float:
		return 1.0

	func _get_role_attribute_range_multiplier(_role_id: String) -> float:
		return 1.0

	func _get_role_equipment_skill_range_multiplier(_role_id: String) -> float:
		return 1.0

	func _get_role_damage(_role_id: String) -> float:
		return 100.0

	func _get_downward_perpendicular(direction: Vector2) -> Vector2:
		return Vector2(-direction.y, direction.x)

	func _spawn_sword_slash_scene_effect(_center: Vector2, _axis: Vector2, _length: float, _color: Color, _duration: float, _width: float, _mirror: bool) -> void:
		pass

	func _get_sword_slash_scene_animation_duration() -> float:
		return 0.1

	func _damage_enemies_in_oriented_rect_unique(_center: Vector2, _axis: Vector2, _length: float, _width: float, damage: float, _vulnerability: float, _slow: float, _slow_duration: float, _registry: Dictionary, _role_id: String) -> int:
		damage_amounts.append(damage)
		return hit_results.pop_front() if not hit_results.is_empty() else 0

	func _schedule_swordsman_slash_followthrough(_center: Vector2, _axis: Vector2, _length: float, _width: float, _damage: float, _vulnerability: float, _slow: float, _slow_duration: float, _duration: float, _role_id: String, _registry: Dictionary) -> void:
		pass

	func _spawn_attack_aftershock(_position: Vector2, _role_id: String) -> void:
		pass

	func _get_skill_blessing_effect_scales_for_skill(_skill_id: String, _stat: String) -> Array[float]:
		return []

	func _push_attack_result_context_tag(_tag: String) -> void:
		pass

	func _pop_attack_result_context_tag(_tag: String) -> void:
		pass

extends RefCounted

const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")
const MAGE_SURGING_WAVE_TRAIL := preload("res://scripts/player/mage_surging_wave_trail.gd")

const TALENT_SURGING_WAVE_1 := "mage_level_talent_surging_wave_1"
const TALENT_SURGING_WAVE_2 := "mage_level_talent_surging_wave_2"

const RANGE_MULTIPLIER := 1.20
const EXTRA_LIFETIME := 2.0
const TWIN_WAVE_ANGLE_RADIANS := deg_to_rad(30.0)
const TRAIL_TICK_INTERVAL := 0.20
const TRAIL_DAMAGE_PER_SECOND_RATIO := 0.30
const TRAIL_SLOW_MULTIPLIER := 0.30
const TRAIL_SLOW_DURATION := 0.25
const TRAIL_ALPHA := 0.10
const TRAIL_VISUAL_WIDTH_MULTIPLIER := 1.70
const TRAIL_COLOR := Color(1.0, 0.52, 0.20, TRAIL_ALPHA)
const TRAIL_MIN_LENGTH := 6.0


static func has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)


static func get_range_multiplier(owner) -> float:
	return RANGE_MULTIPLIER if has_level_talent(owner, TALENT_SURGING_WAVE_1) else 1.0


static func get_lifetime_bonus(owner) -> float:
	return EXTRA_LIFETIME if has_level_talent(owner, TALENT_SURGING_WAVE_2) else 0.0


static func get_twin_wave_directions(owner, base_direction: Vector2) -> Array[Vector2]:
	var direction := base_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	if not has_level_talent(owner, TALENT_SURGING_WAVE_1):
		return [direction]
	var half_angle := TWIN_WAVE_ANGLE_RADIANS * 0.5
	return [
		direction.rotated(-half_angle),
		direction.rotated(half_angle)
	]


static func start_path_trail(owner, wave: Node2D, wave_token: int, origin: Vector2, source_role_id: String = "mage") -> void:
	if owner == null or wave == null or not is_instance_valid(wave):
		return
	if not has_level_talent(owner, TALENT_SURGING_WAVE_2):
		return
	if not owner.has_method("_schedule_repeating_sequence"):
		return
	var trail := _spawn_trail_visual(owner, wave, wave_token, origin)
	var tick_count := int(ceil(max(TRAIL_TICK_INTERVAL, float(wave.get("lifetime"))) / TRAIL_TICK_INTERVAL)) + 2
	owner._schedule_repeating_sequence(TRAIL_TICK_INTERVAL, tick_count, func(_index: int) -> void:
		if owner == null or not is_instance_valid(owner):
			_release_trail_visual(trail)
			return
		if wave == null or not is_instance_valid(wave) or int(wave.get_meta("mage_surge_token", -1)) != wave_token or bool(wave.get_meta("player_projectile_released", false)):
			_release_trail_visual(trail)
			return
		var end_position: Vector2 = wave.global_position
		var axis: Vector2 = end_position - origin
		var length: float = axis.length()
		if length < TRAIL_MIN_LENGTH:
			return
		var direction: Vector2 = axis / length
		var width: float = max(4.0, float(wave.get("hit_radius")) * 2.0)
		if owner.has_method("_damage_enemies_in_oriented_rect"):
			var damage_per_tick: float = float(wave.get("damage")) * TRAIL_DAMAGE_PER_SECOND_RATIO * TRAIL_TICK_INTERVAL
			owner._damage_enemies_in_oriented_rect(origin + axis * 0.5, direction, length, width, damage_per_tick, 0.0, TRAIL_SLOW_MULTIPLIER, TRAIL_SLOW_DURATION, source_role_id)
	, TRAIL_TICK_INTERVAL)


static func _spawn_trail_visual(owner, wave: Node2D, wave_token: int, origin: Vector2) -> Node2D:
	var tree: SceneTree = owner.get_tree() if owner != null and owner.has_method("get_tree") else null
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return null
	var trail := MAGE_SURGING_WAVE_TRAIL.new()
	trail.setup(owner, wave, wave_token, origin, TRAIL_COLOR, TRAIL_VISUAL_WIDTH_MULTIPLIER, TRAIL_MIN_LENGTH)
	scene.add_child(trail)
	return trail

static func _release_trail_visual(trail: Polygon2D) -> void:
	if trail == null or not is_instance_valid(trail):
		return
	if bool(trail.get_meta("mage_surging_wave_trail_released", false)):
		return
	trail.set_meta("mage_surging_wave_trail_released", true)
	trail.visible = false
	trail.remove_from_group("temporary_effects")
	trail.queue_free()

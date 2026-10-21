extends RefCounted

const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")
const MAGE_SURGING_WAVE_BUILD := preload("res://scripts/player/player_mage_surging_wave_build.gd")
const MAGE_SURGING_WAVE_TRAIL := preload("res://scripts/player/mage_surging_wave_trail.gd")

const TALENT_FLOW := "mage_surge_back"
const TALENT_FLOOD := "mage_surge_flood"
const TALENT_WATER_PATH := "mage_surge_wake"
const TALENT_CLEAR_SPRING := "mage_surge_clear_spring"
const TALENT_TIDAL := "mage_surge_tidal"
const TALENT_STACK := "mage_surge_stack"

const TRAIL_TICK_INTERVAL := 0.20
const TRAIL_DAMAGE_PER_SECOND_RATIO := 0.40
const TRAIL_SLOW_MULTIPLIER := 0.50
const TRAIL_SLOW_DURATION := 1.5
const TRAIL_DURATION := 8.0
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

static func has_wave_talent(owner, talent_id: String) -> bool:
	match talent_id:
		TALENT_FLOW: return MAGE_SURGING_WAVE_BUILD.has_choice(owner, "flow")
		TALENT_FLOOD: return MAGE_SURGING_WAVE_BUILD.has_choice(owner, "flood")
		TALENT_WATER_PATH: return MAGE_SURGING_WAVE_BUILD.has_choice(owner, "water_path")
		TALENT_CLEAR_SPRING: return MAGE_SURGING_WAVE_BUILD.has_choice(owner, "clear_spring")
		TALENT_TIDAL: return MAGE_SURGING_WAVE_BUILD.has_choice(owner, "tidal")
		TALENT_STACK: return MAGE_SURGING_WAVE_BUILD.has_choice(owner, "stack")
	return false


static func get_range_multiplier(owner) -> float:
	return 1.0


static func get_lifetime_bonus(owner) -> float:
	return 0.0


static func get_twin_wave_directions(owner, base_direction: Vector2) -> Array[Vector2]:
	var direction := base_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	return [direction]


static func start_path_trail(owner, wave: Node2D, wave_token: int, origin: Vector2, source_role_id: String = "mage") -> void:
	if owner == null or wave == null or not is_instance_valid(wave):
		return
	if not has_wave_talent(owner, TALENT_WATER_PATH):
		return
	if not owner.has_method("_schedule_repeating_sequence"):
		return
	var trail := _spawn_trail_visual(owner, wave, wave_token, origin)
	trail.set_meta("mage_surge_water_path", has_wave_talent(owner, TALENT_WATER_PATH))


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

extends CharacterBody2D

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const WHITE_KEY_SHADER := preload("res://shaders/white_key.gdshader")
const SWORD_SLASH_EFFECT_SCENE := preload("res://effects/sword/slash3/slasheffect3.tscn")
const SWORD_OMNISLASH_EFFECT_SCENE := preload("res://effects/sword/omnislash/omnislash.tscn")
const SWORD_FAN_EFFECT_SCENE := preload("res://effects/sword/fan/fan.tscn")
const GUNNER_INTERSECT_EFFECT_SCENE := preload("res://effects/gun/intersect/intersect.tscn")
const MAGE_BOOM_EFFECT_SCENE := preload("res://effects/wizard/boom/boom.tscn")
const MAGE_WARNING_EFFECT_SCENE := preload("res://effects/wizard/warning/warning.tscn")
const MAGE_GATHERING_EFFECT_SCENE := preload("res://effects/wizard/wave/gathering/gatering.tscn")
const MAGE_WAVE_EFFECT_SCENE := preload("res://effects/wizard/wave/wave.tscn")

const DANGZHEN_PREVIEW_ACTIVE := false
const SWORD_FAN_SCENE_SIZE := Vector2(1024.0, 1024.0)
const SWORD_FAN_SCENE_VISIBLE_BOUNDS := Rect2(485.0, 405.0, 117.0, 50.0)
const GUNNER_INTERSECT_SCENE_SIZE := Vector2(1024.0, 1024.0)
const GUNNER_INTERSECT_SCENE_VISIBLE_BOUNDS := Rect2(465.0, 489.0, 274.0, 39.0)
const MAGE_GATHERING_SCENE_SIZE := Vector2(1024.0, 1024.0)
const MAGE_GATHERING_SCENE_VISIBLE_BOUNDS := Rect2(298.0, 399.0, 102.0, 165.0)

signal experience_changed(current_experience: int, required_experience: int, level: int)
signal level_up_requested(options: Array)
signal stats_changed(summary: Dictionary)
signal health_changed(current_health: float, max_health: float)
signal mana_changed(current_mana: float, max_mana: float)
signal died
signal active_role_changed(role_id: String, role_name: String)

const ROLE_SWITCH_COOLDOWN := 8.0
const SWITCH_INVULNERABILITY := 0.2
const ENERGY_PASSIVE_REGEN := 0.0
const ENERGY_PER_HIT := 0.3
const ENERGY_PER_KILL := 1.1
const ULTIMATE_COST := 90.0
const ULTIMATE_SEAL_MAX := 2
const SWORD_ULTIMATE_SLASH_INTERVAL := 0.12
const GUNNER_ULTIMATE_WAVE_INTERVAL := 0.14
const MAGE_ULTIMATE_BOMBARD_INTERVAL := 0.24

const FIRE_RATE_STEP := 0.05
const DAMAGE_STEP := 2.5
const MOVE_SPEED_STEP := 12.0
const PICKUP_RANGE_STEP := 8.0
const ENERGY_GAIN_STEP := 0.08
const HEALTH_STEP := 16.0
const DAMAGE_REDUCTION_STEP := 0.05
const SWITCH_COOLDOWN_STEP := 0.4
const LEVEL_STAT_HEALTH_STEP := 14.0
const LEVEL_STAT_SPEED_STEP := 8.0
const LEVEL_STAT_DAMAGE_STEP := 0.09
const EXIT_SWORD_LIFESTEAL_DURATION := 4.5
const EXIT_SWORD_LIFESTEAL_RATIO := 0.14
const EXIT_GUNNER_HASTE_DURATION := 4.0
const EXIT_GUNNER_ATTACK_INTERVAL_BONUS := 0.08
const EXIT_GUNNER_MOVE_SPEED_MULTIPLIER := 1.18
const ROLE_SHARE_DAMAGE_RATIO := 0.42
const ROLE_SHARE_INTERVAL_RATIO := 0.34
const ROLE_SHARE_RANGE_RATIO := 0.45
const ROLE_SHARE_SKILL_RATIO := 0.4
const SLOT_RESONANCE_FIRST_THRESHOLD := 3
const SLOT_RESONANCE_SECOND_THRESHOLD := 6
const SLOT_EVOLUTION_THRESHOLD := 2
const GEM_COLLECTION_INTERVAL := 0.08
const CONTACT_CHECK_INTERVAL := 0.05
const PLAYER_HURT_CORE_RADIUS := 7.7
const PLAYER_HURT_CORE_OUTLINE_WIDTH := 3.0
const PLAYER_HURT_CORE_OFFSET := Vector2.ZERO
const ROLE_SKETCH_TARGET_HEIGHT := 72.0
const ROLE_SKETCH_PATHS := {
	"swordsman": "人设草图/剑士草图.jpg",
	"gunner": "人设草图/枪手草图.jpg",
	"mage": "人设草图/术师草图.jpg"
}
const ROLE_SKETCH_FULL_SIZES := {
	"swordsman": Vector2(589.0, 527.0),
	"gunner": Vector2(589.0, 582.0),
	"mage": Vector2(589.0, 527.0)
}
const ROLE_SKETCH_SCALE_MULTIPLIERS := {
	"swordsman": 1.0,
	"gunner": 1.12,
	"mage": 1.06
}
const ROLE_SKETCH_BASE_POSITIONS := {
	"swordsman": Vector2(14.0, -4.0),
	"gunner": Vector2(2.0, -3.0),
	"mage": Vector2(10.0, -5.0)
}
const ROLE_SKETCH_VISIBLE_BOUNDS := {
	"swordsman": Rect2(161.0, 49.0, 368.0, 430.0),
	"gunner": Rect2(94.0, 16.0, 415.0, 539.0),
	"mage": Rect2(142.0, 31.0, 377.0, 424.0)
}
const SWORD_SLASH_TEXTURE_RELATIVE_PATH := "技能特效/斩击.jpg"
const SWORD_SLASH_TEXTURE_SIZE := Vector2(1200.0, 1600.0)
const SWORD_SLASH_VISIBLE_BOUNDS := Rect2(246.0, 537.0, 600.0, 615.0)
const SWORD_SLASH_SCENE_SIZE := Vector2(256.0, 256.0)
const SWORD_SLASH_SCENE_VISIBLE_BOUNDS := Rect2(99.0, 30.0, 27.0, 153.0)
const SWORD_SLASH_DAMAGE_FOLLOW_PULSES := 2
const SWORD_OMNISLASH_SCENE_SIZE := Vector2(1024.0, 1024.0)
const SWORD_OMNISLASH_SCENE_VISIBLE_BOUNDS := Rect2(30.0, 344.0, 951.0, 189.0)
const MAGE_WARNING_SCENE_SIZE := Vector2(256.0, 256.0)
const MAGE_WARNING_SCENE_VISIBLE_BOUNDS := Rect2(98.0, 98.0, 59.0, 30.0)
const MAGE_BOOM_SCENE_SIZE := Vector2(256.0, 256.0)
const MAGE_BOOM_SCENE_VISIBLE_BOUNDS := Rect2(101.0, 33.0, 56.0, 92.0)
const MAGE_BOOM_IMPACT_FOCUS_BOUNDS := Rect2(104.0, 99.0, 44.0, 26.0)
const GUNNER_BULLET_TEXTURE_RELATIVE_PATH := "技能特效/子弹.jpg"
const MAGE_BOMBARD_TEXTURE_RELATIVE_PATH := "技能特效/轰炸.jpg"
const MAGE_BOMBARD_TEXTURE_SIZE := Vector2(1200.0, 1600.0)
const MAGE_BOMBARD_VISIBLE_BOUNDS := Rect2(287.0, 434.0, 634.0, 561.0)

const MAGE_ATTACK_EFFECT_SCALE := 0.8
const MAGE_ENTRY_EFFECT_RADIUS := 52.0 * MAGE_ATTACK_EFFECT_SCALE
const MAGE_ENTRY_HIT_RADIUS := 104.0 * MAGE_ATTACK_EFFECT_SCALE

@export var bullet_scene: PackedScene = preload("res://effects/gun/bullet/bullet.tscn")
@export var max_health: float = 110.0
@export var max_mana: float = 100.0
@export var base_speed: float = 192.0
@export var base_pickup_radius: float = 34.0
@export var hurt_cooldown: float = 0.55
@export var experience_to_next_level: int = 30

var fire_timer: Timer
var level: int = 1
var experience: int = 0
var pending_level_ups: int = 0
var level_up_active: bool = false
var current_health: float = 0.0
var current_mana: float = 0.0
var current_ultimate_seals: int = 0
var hurt_cooldown_remaining: float = 0.0
var switch_invulnerability_remaining: float = 0.0
var level_up_delay_remaining: float = 0.0
var switch_cooldown_remaining: float = 0.0
var is_dead: bool = false

var speed: float = 0.0
var pickup_radius: float = 0.0
var energy_gain_multiplier: float = 1.0
var global_damage_multiplier: float = 1.0
var background_interval_multiplier: float = 1.0
var ultimate_cost_multiplier: float = 1.0
var damage_taken_multiplier: float = 1.0
var role_switch_cooldown_bonus: float = 0.0

var active_role_index: int = 0
var facing_direction: Vector2 = Vector2.RIGHT
var roles: Array = []
var role_upgrade_levels: Dictionary = {}
var background_cooldowns: Dictionary = {}
var build_slot_levels: Dictionary = {}
var card_pick_levels: Dictionary = {}
var elite_relics_unlocked: Dictionary = {}
var attribute_training_levels: Dictionary = {}
var slot_resonances_unlocked: Dictionary = {}
var role_special_states: Dictionary = {}
var camera_node: Camera2D
var camera_base_offset: Vector2 = Vector2.ZERO
var camera_shake_strength: float = 0.0
var camera_shake_time: float = 0.0
var switch_power_remaining: float = 0.0
var switch_power_role_id: String = ""
var switch_power_damage_multiplier: float = 1.0
var switch_power_interval_bonus: float = 0.0
var switch_power_label: String = ""
var pending_entry_blessing_source_role_id: String = ""
var entry_blessing_role_id: String = ""
var entry_blessing_label: String = ""
var entry_blessing_remaining: float = 0.0
var entry_lifesteal_ratio: float = 0.0
var entry_haste_interval_bonus: float = 0.0
var entry_haste_move_speed_multiplier: float = 1.0
var relay_window_remaining: float = 0.0
var relay_ready_role_id: String = ""
var relay_from_role_id: String = ""
var relay_label: String = ""
var relay_bonus_pending: bool = false
var standby_entry_role_id: String = ""
var standby_entry_label: String = ""
var standby_entry_remaining: float = 0.0
var standby_entry_damage_multiplier: float = 1.0
var standby_entry_interval_bonus: float = 0.0
var guard_cover_remaining: float = 0.0
var guard_cover_damage_multiplier: float = 1.0
var team_combo_remaining: float = 0.0
var team_combo_damage_multiplier: float = 1.0
var team_combo_move_multiplier: float = 1.0
var team_combo_background_multiplier: float = 1.0
var borrow_fire_role_id: String = ""
var borrow_fire_remaining: float = 0.0
var borrow_fire_damage_multiplier: float = 1.0
var borrow_fire_interval_bonus: float = 0.0
var borrow_fire_background_multiplier: float = 1.0
var post_ultimate_flow_remaining: float = 0.0
var post_ultimate_flow_background_multiplier: float = 1.0
var ultimate_guard_remaining: float = 0.0
var ultimate_guard_damage_multiplier: float = 1.0
var perpetual_motion_cooldown_remaining: float = 0.0
var frenzy_remaining: float = 0.0
var frenzy_stacks: int = 0
var frenzy_overkill_counter: int = 0
var role_standby_elapsed: Dictionary = {}
var role_cycle_marks: Dictionary = {}
var role_share_initialized: bool = false
var role_visual_time: float = 0.0
var active_role_visual_hidden: bool = false
var active_role_visual_hidden_role_id: String = ""
var runtime_texture_cache: Dictionary = {}
var swordsman_attack_chain: int = 0
var swordsman_dangzhen_slash_cooldown_attacks: int = 0
var gunner_attack_chain: int = 0
var mage_attack_chain: int = 0
var mage_dangzhen_wave_cooldown_attacks: int = 0
var gunner_lock_target: Node2D
var gunner_lock_stacks: int = 0
var gem_collection_elapsed: float = 0.0
var contact_check_elapsed: float = 0.0
var execution_pact_burst_active: bool = false
var chain_reaction_active: bool = false
var clean_tide_active: bool = false
var final_set_unlock_announced: Dictionary = {}
var story_equipped_styles: Dictionary = {
	"swordsman": "default",
	"gunner": "default",
	"mage": "default"
}

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 0
	collision_mask = 0

	roles = _build_role_data()
	role_upgrade_levels = _build_role_upgrade_data()
	background_cooldowns = _build_background_cooldowns()
	build_slot_levels = _build_slot_progress_data()
	attribute_training_levels = _build_attribute_training_data()
	slot_resonances_unlocked = {}
	role_special_states = _build_role_special_state_data()
	role_standby_elapsed = _build_role_timing_state_data(0.0)
	role_cycle_marks = _build_role_timing_state_data(false)

	speed = base_speed
	pickup_radius = base_pickup_radius
	current_health = max_health
	current_mana = 0.0

	fire_timer = Timer.new()
	fire_timer.one_shot = false
	fire_timer.autostart = true
	fire_timer.timeout.connect(_perform_active_attack)
	add_child(fire_timer)

	camera_node = get_node_or_null("Camera2D") as Camera2D
	if camera_node != null:
		camera_base_offset = camera_node.offset

	_setup_hurt_core_visual()

	_initialize_existing_role_shares()
	role_cycle_marks[str(_get_active_role().get("id", ""))] = true

	_update_active_role_state()
	experience_changed.emit(experience, experience_to_next_level, level)
	stats_changed.emit(get_stat_summary())
	health_changed.emit(current_health, max_health)
	mana_changed.emit(current_mana, max_mana)

func _get_desktop_sketch_path(relative_path: String) -> String:
	return OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).replace("\\", "/") + "/草图/" + relative_path

func _get_project_sketch_path(relative_path: String) -> String:
	return "res://assets/sketch/" + relative_path

func _get_cached_runtime_texture(relative_path: String) -> Texture2D:
	if runtime_texture_cache.has(relative_path):
		return runtime_texture_cache[relative_path]
	var project_path := _get_project_sketch_path(relative_path)
	if ResourceLoader.exists(project_path):
		var project_texture := load(project_path) as Texture2D
		if project_texture != null:
			runtime_texture_cache[relative_path] = project_texture
			return project_texture
	var image := Image.new()
	var load_error := image.load(_get_desktop_sketch_path(relative_path))
	if load_error != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	runtime_texture_cache[relative_path] = texture
	return texture

func _create_white_key_material(value_threshold: float = 0.94, saturation_threshold: float = 0.08, edge_softness: float = 0.03) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WHITE_KEY_SHADER
	material.set_shader_parameter("value_threshold", value_threshold)
	material.set_shader_parameter("saturation_threshold", saturation_threshold)
	material.set_shader_parameter("edge_softness", edge_softness)
	return material

func _get_role_sprite_offset(role_id: String) -> Vector2:
	var full_size: Vector2 = ROLE_SKETCH_FULL_SIZES.get(role_id, Vector2.ZERO)
	var visible_bounds: Rect2 = ROLE_SKETCH_VISIBLE_BOUNDS.get(role_id, Rect2())
	var visible_center := visible_bounds.position + visible_bounds.size * 0.5
	return full_size * 0.5 - visible_center

func _configure_role_sprite(sprite: Sprite2D, role_id: String) -> bool:
	var texture: Texture2D = _get_cached_runtime_texture(ROLE_SKETCH_PATHS.get(role_id, ""))
	if texture == null:
		return false
	var visible_bounds: Rect2 = ROLE_SKETCH_VISIBLE_BOUNDS.get(role_id, Rect2())
	if visible_bounds.size.y <= 0.0:
		return false
	sprite.texture = texture
	sprite.centered = true
	sprite.material = _create_white_key_material(0.93, 0.12, 0.04)
	sprite.offset = _get_role_sprite_offset(role_id)
	var target_scale: float = ROLE_SKETCH_TARGET_HEIGHT / visible_bounds.size.y
	target_scale *= float(ROLE_SKETCH_SCALE_MULTIPLIERS.get(role_id, 1.0))
	sprite.scale = Vector2.ONE * target_scale
	sprite.modulate = Color.WHITE
	sprite.set_meta("base_scale", sprite.scale)
	sprite.set_meta("base_position", ROLE_SKETCH_BASE_POSITIONS.get(role_id, Vector2(0.0, -4.0)))
	sprite.position = sprite.get_meta("base_position")
	return true

func _spawn_sketch_sprite_effect(
		center: Vector2,
		rotation_angle: float,
		texture_path: String,
		full_size: Vector2,
		visible_bounds: Rect2,
		target_visible_size: Vector2,
		duration: float,
		modulate_color: Color = Color.WHITE,
		z_index: int = 13,
		align_visible_center: bool = true,
		preserve_aspect: bool = false,
		value_threshold: float = 0.94,
		saturation_threshold: float = 0.08,
		edge_softness: float = 0.03
	) -> Node2D:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null

	var texture: Texture2D = _get_cached_runtime_texture(texture_path)
	if texture == null:
		return null

	var effect := Node2D.new()
	effect.global_position = center
	effect.rotation = rotation_angle
	effect.z_index = z_index

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.material = _create_white_key_material(value_threshold, saturation_threshold, edge_softness)
	sprite.modulate = modulate_color
	if align_visible_center:
		var visible_center := visible_bounds.position + visible_bounds.size * 0.5
		sprite.offset = full_size * 0.5 - visible_center
	else:
		sprite.offset = Vector2.ZERO
	if preserve_aspect:
		var base_visible_size: float = max(1.0, max(visible_bounds.size.x, visible_bounds.size.y))
		var target_size: float = max(target_visible_size.x, target_visible_size.y)
		var uniform_scale: float = target_size / base_visible_size
		sprite.scale = Vector2.ONE * uniform_scale
	else:
		sprite.scale = Vector2(
			target_visible_size.x / max(1.0, visible_bounds.size.x),
			target_visible_size.y / max(1.0, visible_bounds.size.y)
		)
	effect.add_child(sprite)
	current_scene.add_child(effect)

	var tween := effect.create_tween()
	tween.parallel().tween_property(effect, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(effect, "scale", Vector2(1.06, 1.06), duration * 0.35)
	tween.tween_callback(effect.queue_free)
	return effect

func _spawn_sword_slash_scene_effect(center: Vector2, direction: Vector2, radius: float, color: Color, duration: float, thickness: float, mirror_horizontal: bool = false) -> Node2D:
	var current_scene := get_tree().current_scene
	if current_scene == null or SWORD_SLASH_EFFECT_SCENE == null:
		return null

	var playback_direction: Vector2 = direction.normalized()
	if playback_direction.length_squared() <= 0.001:
		playback_direction = Vector2.DOWN

	var effect := SWORD_SLASH_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		return null

	effect.global_position = center
	effect.rotation = playback_direction.angle() - Vector2.DOWN.angle()
	effect.z_index = 13

	var slash_sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if slash_sprite != null:
		var base_scale: Vector2 = slash_sprite.scale
		var authored_animation: StringName = slash_sprite.animation
		slash_sprite.material = null
		slash_sprite.modulate = Color.WHITE
		slash_sprite.centered = true
		slash_sprite.position = Vector2.ZERO
		slash_sprite.offset = SWORD_SLASH_SCENE_SIZE * 0.5 - (SWORD_SLASH_SCENE_VISIBLE_BOUNDS.position + SWORD_SLASH_SCENE_VISIBLE_BOUNDS.size * 0.5)
		slash_sprite.flip_h = mirror_horizontal
		var target_visible_size := Vector2(
			max(18.0, thickness * 2.0),
			max(72.0, radius * 2.0)
		)
		var target_scale := Vector2(
			target_visible_size.x / max(1.0, SWORD_SLASH_SCENE_VISIBLE_BOUNDS.size.x),
			target_visible_size.y / max(1.0, SWORD_SLASH_SCENE_VISIBLE_BOUNDS.size.y)
		)
		slash_sprite.scale = Vector2(
			base_scale.x * target_scale.x,
			base_scale.y * target_scale.y
		)
		if slash_sprite.sprite_frames != null:
			var animation_names: PackedStringArray = slash_sprite.sprite_frames.get_animation_names()
			var animation_name: StringName = authored_animation
			if animation_name == StringName() and animation_names.size() > 0:
				animation_name = StringName(animation_names[0])
			elif animation_name != StringName() and not animation_names.has(String(animation_name)) and animation_names.size() > 0:
				animation_name = StringName(animation_names[0])
			if animation_name != StringName():
				slash_sprite.sprite_frames.set_animation_loop(animation_name, false)
				slash_sprite.animation = animation_name
				slash_sprite.frame = 0
				slash_sprite.frame_progress = 0.0
				slash_sprite.play(animation_name)
			else:
				slash_sprite.play()
		else:
			slash_sprite.play()
		if not slash_sprite.animation_finished.is_connected(effect.queue_free):
			slash_sprite.animation_finished.connect(effect.queue_free, CONNECT_ONE_SHOT)
	else:
		var tween := effect.create_tween()
		tween.tween_interval(max(0.24, duration))
		tween.tween_callback(effect.queue_free)

	current_scene.add_child(effect)
	return effect

func _spawn_sword_omnislash_scene_effect(center: Vector2, direction: Vector2, length: float, thickness: float) -> Node2D:
	var current_scene := get_tree().current_scene
	if current_scene == null or SWORD_OMNISLASH_EFFECT_SCENE == null:
		return null

	var playback_direction: Vector2 = direction.normalized()
	if playback_direction.length_squared() <= 0.001:
		playback_direction = Vector2.RIGHT

	var effect := SWORD_OMNISLASH_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		return null

	effect.global_position = center
	effect.rotation = playback_direction.angle() - Vector2.RIGHT.angle()
	effect.z_index = 15

	var slash_sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if slash_sprite != null:
		var base_scale: Vector2 = slash_sprite.scale
		var authored_animation: StringName = slash_sprite.animation
		slash_sprite.material = null
		slash_sprite.modulate = Color.WHITE
		slash_sprite.centered = true
		slash_sprite.position = Vector2.ZERO
		slash_sprite.offset = SWORD_OMNISLASH_SCENE_SIZE * 0.5 - (SWORD_OMNISLASH_SCENE_VISIBLE_BOUNDS.position + SWORD_OMNISLASH_SCENE_VISIBLE_BOUNDS.size * 0.5)
		var target_visible_size := Vector2(
			max(120.0, length),
			max(28.0, thickness * 1.18)
		)
		var target_scale := Vector2(
			target_visible_size.x / max(1.0, SWORD_OMNISLASH_SCENE_VISIBLE_BOUNDS.size.x),
			target_visible_size.y / max(1.0, SWORD_OMNISLASH_SCENE_VISIBLE_BOUNDS.size.y)
		)
		slash_sprite.scale = Vector2(
			base_scale.x * target_scale.x,
			base_scale.y * target_scale.y
		)
		if slash_sprite.sprite_frames != null:
			var animation_names: PackedStringArray = slash_sprite.sprite_frames.get_animation_names()
			var animation_name: StringName = authored_animation
			if animation_name == StringName() and animation_names.size() > 0:
				animation_name = StringName(animation_names[0])
			elif animation_name != StringName() and not animation_names.has(String(animation_name)) and animation_names.size() > 0:
				animation_name = StringName(animation_names[0])
			if animation_name != StringName():
				slash_sprite.sprite_frames.set_animation_loop(animation_name, false)
				slash_sprite.animation = animation_name
				slash_sprite.frame = 0
				slash_sprite.frame_progress = 0.0
				slash_sprite.play(animation_name)
			else:
				slash_sprite.play()
		else:
			slash_sprite.play()
		if not slash_sprite.animation_finished.is_connected(effect.queue_free):
			slash_sprite.animation_finished.connect(effect.queue_free, CONNECT_ONE_SHOT)
	else:
		var tween := effect.create_tween()
		tween.tween_interval(0.2)
		tween.tween_callback(effect.queue_free)

	current_scene.add_child(effect)
	return effect

func _set_active_role_visual_hidden(hidden: bool) -> void:
	active_role_visual_hidden = hidden
	active_role_visual_hidden_role_id = str(_get_active_role().get("id", "")) if hidden else ""
	var should_hide := active_role_visual_hidden and str(_get_active_role().get("id", "")) == active_role_visual_hidden_role_id
	var sprite := get_node_or_null("RoleVisualRoot/RoleSprite") as Sprite2D
	if sprite != null:
		sprite.visible = not should_hide
	var polygon := get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null:
		polygon.visible = sprite == null and not should_hide

func _spawn_authored_scene_effect(scene: PackedScene, scene_size: Vector2, visible_bounds: Rect2, center: Vector2, rotation_radians: float, scale_multiplier: float, z_index: int = 12) -> Node2D:
	var current_scene := get_tree().current_scene
	if current_scene == null or scene == null:
		return null

	var effect := scene.instantiate() as Node2D
	if effect == null:
		return null

	effect.global_position = center
	effect.rotation = rotation_radians
	effect.z_index = z_index

	var animated_sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null:
		var base_scale: Vector2 = animated_sprite.scale
		var authored_animation: StringName = animated_sprite.animation
		animated_sprite.material = null
		animated_sprite.modulate = Color.WHITE
		animated_sprite.centered = true
		animated_sprite.position = Vector2.ZERO
		animated_sprite.offset = scene_size * 0.5 - (visible_bounds.position + visible_bounds.size * 0.5)
		animated_sprite.scale = base_scale * scale_multiplier
		if animated_sprite.sprite_frames != null:
			var animation_names: PackedStringArray = animated_sprite.sprite_frames.get_animation_names()
			var animation_name: StringName = authored_animation
			if animation_name == StringName() and animation_names.size() > 0:
				animation_name = StringName(animation_names[0])
			elif animation_name != StringName() and not animation_names.has(String(animation_name)) and animation_names.size() > 0:
				animation_name = StringName(animation_names[0])
			if animation_name != StringName():
				animated_sprite.sprite_frames.set_animation_loop(animation_name, false)
				animated_sprite.animation = animation_name
				animated_sprite.frame = 0
				animated_sprite.frame_progress = 0.0
				animated_sprite.play(animation_name)
			else:
				animated_sprite.play()
		else:
			animated_sprite.play()
		if not animated_sprite.animation_finished.is_connected(effect.queue_free):
			animated_sprite.animation_finished.connect(effect.queue_free, CONNECT_ONE_SHOT)
	else:
		var tween := effect.create_tween()
		tween.tween_interval(0.3)
		tween.tween_callback(effect.queue_free)

	current_scene.add_child(effect)
	return effect

func _spawn_sword_fan_scene_effect(center: Vector2, direction: Vector2, scale_multiplier: float = 1.0) -> Node2D:
	var playback_direction := direction.normalized()
	if playback_direction.length_squared() <= 0.001:
		playback_direction = Vector2.RIGHT
	var current_scene := get_tree().current_scene
	if current_scene == null or SWORD_FAN_EFFECT_SCENE == null:
		return null
	var effect := SWORD_FAN_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		return null
	effect.global_position = center
	effect.rotation = playback_direction.angle() + PI
	effect.z_index = 12
	var slash_sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if slash_sprite != null:
		var authored_animation: StringName = slash_sprite.animation
		slash_sprite.material = null
		slash_sprite.modulate = Color.WHITE
		slash_sprite.centered = true
		slash_sprite.position = Vector2.ZERO
		slash_sprite.offset = SWORD_FAN_SCENE_SIZE * 0.5 - (SWORD_FAN_SCENE_VISIBLE_BOUNDS.position + SWORD_FAN_SCENE_VISIBLE_BOUNDS.size * 0.5)
		var target_visible_size := Vector2(138.0, 74.0) * scale_multiplier
		slash_sprite.scale = Vector2(
			target_visible_size.x / max(1.0, SWORD_FAN_SCENE_VISIBLE_BOUNDS.size.x),
			target_visible_size.y / max(1.0, SWORD_FAN_SCENE_VISIBLE_BOUNDS.size.y)
		)
		if slash_sprite.sprite_frames != null:
			var animation_names: PackedStringArray = slash_sprite.sprite_frames.get_animation_names()
			var animation_name: StringName = authored_animation
			if animation_name == StringName() and animation_names.size() > 0:
				animation_name = StringName(animation_names[0])
			elif animation_name != StringName() and not animation_names.has(String(animation_name)) and animation_names.size() > 0:
				animation_name = StringName(animation_names[0])
			if animation_name != StringName():
				slash_sprite.sprite_frames.set_animation_loop(animation_name, false)
				slash_sprite.animation = animation_name
				slash_sprite.frame = 0
				slash_sprite.frame_progress = 0.0
				slash_sprite.play(animation_name)
			else:
				slash_sprite.play()
		else:
			slash_sprite.play()
		if not slash_sprite.animation_finished.is_connected(effect.queue_free):
			slash_sprite.animation_finished.connect(effect.queue_free, CONNECT_ONE_SHOT)
	else:
		var tween := effect.create_tween()
		tween.tween_interval(0.24)
		tween.tween_callback(effect.queue_free)
	current_scene.add_child(effect)
	return effect

func _spawn_gunner_intersect_scene_effect(center: Vector2, direction: Vector2, visual_length: float = 112.0, visual_thickness: float = 18.0) -> Node2D:
	var playback_direction := direction.normalized()
	if playback_direction.length_squared() <= 0.001:
		playback_direction = Vector2.RIGHT
	if GUNNER_INTERSECT_EFFECT_SCENE == null:
		return null
	var effect := GUNNER_INTERSECT_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		return null
	effect.set_script(null)
	effect.position = center - global_position
	effect.rotation = playback_direction.angle()
	effect.z_index = 13
	var intersect_sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if intersect_sprite != null:
		var authored_animation: StringName = intersect_sprite.animation
		intersect_sprite.centered = true
		intersect_sprite.position = Vector2.ZERO
		intersect_sprite.modulate = Color.WHITE
		var shader_material := ShaderMaterial.new()
		shader_material.shader = WHITE_KEY_SHADER
		intersect_sprite.material = shader_material
		intersect_sprite.offset = GUNNER_INTERSECT_SCENE_SIZE * 0.5 - Vector2(
			GUNNER_INTERSECT_SCENE_VISIBLE_BOUNDS.position.x,
			GUNNER_INTERSECT_SCENE_VISIBLE_BOUNDS.position.y + GUNNER_INTERSECT_SCENE_VISIBLE_BOUNDS.size.y * 0.5
		)
		var target_visible_size := Vector2(visual_length, visual_thickness)
		intersect_sprite.scale = Vector2(
			target_visible_size.x / max(1.0, GUNNER_INTERSECT_SCENE_VISIBLE_BOUNDS.size.x),
			target_visible_size.y / max(1.0, GUNNER_INTERSECT_SCENE_VISIBLE_BOUNDS.size.y)
		)
		intersect_sprite.speed_scale = 1.875
		if intersect_sprite.sprite_frames != null:
			var animation_names: PackedStringArray = intersect_sprite.sprite_frames.get_animation_names()
			var animation_name: StringName = authored_animation
			if animation_name == StringName() and animation_names.size() > 0:
				animation_name = StringName(animation_names[0])
			elif animation_name != StringName() and not animation_names.has(String(animation_name)) and animation_names.size() > 0:
				animation_name = StringName(animation_names[0])
			if animation_name != StringName():
				intersect_sprite.sprite_frames.set_animation_loop(animation_name, false)
				intersect_sprite.animation = animation_name
				intersect_sprite.frame = 0
				intersect_sprite.frame_progress = 0.0
				intersect_sprite.play(animation_name)
			else:
				intersect_sprite.play()
		else:
			intersect_sprite.play()
		if not intersect_sprite.animation_finished.is_connected(effect.queue_free):
			intersect_sprite.animation_finished.connect(effect.queue_free, CONNECT_ONE_SHOT)
	else:
		var tween := effect.create_tween()
		tween.tween_interval(0.18)
		tween.tween_callback(effect.queue_free)
	add_child(effect)
	return effect

func _spawn_mage_gathering_scene_effect(center: Vector2, direction: Vector2, scale_multiplier: float = 1.0) -> Node2D:
	var playback_direction := direction.normalized()
	if playback_direction.length_squared() <= 0.001:
		playback_direction = Vector2.RIGHT
	return _spawn_authored_scene_effect(
		MAGE_GATHERING_EFFECT_SCENE,
		MAGE_GATHERING_SCENE_SIZE,
		MAGE_GATHERING_SCENE_VISIBLE_BOUNDS,
		center,
		playback_direction.angle() - Vector2.RIGHT.angle(),
		1.55 * scale_multiplier,
		12
	)

func _spawn_mage_boom_scene_effect(center: Vector2, radius: float) -> Node2D:
	var current_scene := get_tree().current_scene
	if current_scene == null or MAGE_BOOM_EFFECT_SCENE == null:
		return null

	var effect := MAGE_BOOM_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		return null

	effect.global_position = center
	effect.z_index = 14

	var boom_sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if boom_sprite != null:
		var base_scale: Vector2 = boom_sprite.scale
		var authored_animation: StringName = boom_sprite.animation
		boom_sprite.material = null
		boom_sprite.modulate = Color.WHITE
		boom_sprite.centered = true
		boom_sprite.position = Vector2.ZERO
		boom_sprite.offset = MAGE_BOOM_SCENE_SIZE * 0.5 - (MAGE_BOOM_IMPACT_FOCUS_BOUNDS.position + MAGE_BOOM_IMPACT_FOCUS_BOUNDS.size * 0.5)
		var target_visible_size := Vector2(
			max(80.0, radius * 4.0),
			max(184.0, radius * 4.9)
		)
		var target_scale := Vector2(
			target_visible_size.x / max(1.0, MAGE_BOOM_SCENE_VISIBLE_BOUNDS.size.x),
			target_visible_size.y / max(1.0, MAGE_BOOM_SCENE_VISIBLE_BOUNDS.size.y)
		)
		boom_sprite.scale = Vector2(
			base_scale.x * target_scale.x,
			base_scale.y * target_scale.y
		)
		if boom_sprite.sprite_frames != null:
			var animation_names: PackedStringArray = boom_sprite.sprite_frames.get_animation_names()
			var animation_name: StringName = authored_animation
			if animation_name == StringName() and animation_names.size() > 0:
				animation_name = StringName(animation_names[0])
			elif animation_name != StringName() and not animation_names.has(String(animation_name)) and animation_names.size() > 0:
				animation_name = StringName(animation_names[0])
			if animation_name != StringName():
				boom_sprite.sprite_frames.set_animation_loop(animation_name, false)
				boom_sprite.animation = animation_name
				boom_sprite.frame = 0
				boom_sprite.frame_progress = 0.0
				boom_sprite.play(animation_name)
			else:
				boom_sprite.play()
		else:
			boom_sprite.play()
		if not boom_sprite.animation_finished.is_connected(effect.queue_free):
			boom_sprite.animation_finished.connect(effect.queue_free, CONNECT_ONE_SHOT)
	else:
		var tween := effect.create_tween()
		tween.tween_interval(0.3)
		tween.tween_callback(effect.queue_free)

	current_scene.add_child(effect)
	return effect

func _get_dangzhen_qichao_damage(role_id: String, qichao_level: int) -> float:
	var level_index: int = clamp(qichao_level - 1, 0, 2)
	match role_id:
		"swordsman":
			return [22.0, 30.0, 38.0][level_index]
		"gunner":
			return [18.0, 25.0, 32.0][level_index]
		"mage":
			return [24.0, 32.0, 40.0][level_index]
		_:
			return [20.0, 28.0, 36.0][level_index]

func _spawn_mage_warning_scene_effect(center: Vector2, radius: float) -> Node2D:
	var current_scene := get_tree().current_scene
	if current_scene == null or MAGE_WARNING_EFFECT_SCENE == null:
		return null

	var effect := MAGE_WARNING_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		return null

	effect.global_position = center
	effect.z_index = 13

	var warning_sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if warning_sprite != null:
		var base_scale: Vector2 = warning_sprite.scale
		var authored_animation: StringName = warning_sprite.animation
		warning_sprite.material = null
		warning_sprite.modulate = Color.WHITE
		warning_sprite.centered = true
		warning_sprite.position = Vector2.ZERO
		warning_sprite.offset = MAGE_WARNING_SCENE_SIZE * 0.5 - (MAGE_WARNING_SCENE_VISIBLE_BOUNDS.position + MAGE_WARNING_SCENE_VISIBLE_BOUNDS.size * 0.5)
		var target_visible_size := Vector2(
			max(80.0, radius * 4.0),
			max(42.0, radius * 1.2)
		)
		var target_scale := Vector2(
			target_visible_size.x / max(1.0, MAGE_WARNING_SCENE_VISIBLE_BOUNDS.size.x),
			target_visible_size.y / max(1.0, MAGE_WARNING_SCENE_VISIBLE_BOUNDS.size.y)
		)
		warning_sprite.scale = Vector2(
			base_scale.x * target_scale.x,
			base_scale.y * target_scale.y
		)
		if warning_sprite.sprite_frames != null:
			var animation_names: PackedStringArray = warning_sprite.sprite_frames.get_animation_names()
			var animation_name: StringName = authored_animation
			if animation_name == StringName() and animation_names.size() > 0:
				animation_name = StringName(animation_names[0])
			elif animation_name != StringName() and not animation_names.has(String(animation_name)) and animation_names.size() > 0:
				animation_name = StringName(animation_names[0])
			if animation_name != StringName():
				warning_sprite.sprite_frames.set_animation_loop(animation_name, false)
				warning_sprite.animation = animation_name
				warning_sprite.frame = 0
				warning_sprite.frame_progress = 0.0
				warning_sprite.play(animation_name)
			else:
				warning_sprite.play()
		else:
			warning_sprite.play()
		if not warning_sprite.animation_finished.is_connected(effect.queue_free):
			warning_sprite.animation_finished.connect(effect.queue_free, CONNECT_ONE_SHOT)
	else:
		var tween := effect.create_tween()
		tween.tween_interval(0.2)
		tween.tween_callback(effect.queue_free)

	current_scene.add_child(effect)
	return effect

func _get_downward_perpendicular(direction: Vector2) -> Vector2:
	var normalized_direction: Vector2 = direction.normalized()
	if normalized_direction.length_squared() <= 0.001:
		return Vector2.DOWN
	var perpendicular: Vector2 = normalized_direction.orthogonal().normalized()
	var mirrored: Vector2 = -perpendicular
	if mirrored.dot(Vector2.DOWN) > perpendicular.dot(Vector2.DOWN):
		return mirrored
	return perpendicular

func _get_clockwise_perpendicular(direction: Vector2) -> Vector2:
	var normalized_direction: Vector2 = direction.normalized()
	if normalized_direction.length_squared() <= 0.001:
		return Vector2.DOWN
	return Vector2(normalized_direction.y, -normalized_direction.x).normalized()

func _get_sword_slash_scene_animation_duration() -> float:
	if SWORD_SLASH_EFFECT_SCENE == null:
		return 0.18
	var effect := SWORD_SLASH_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		return 0.18
	var duration: float = 0.18
	var slash_sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if slash_sprite != null and slash_sprite.sprite_frames != null:
		var animation_name: StringName = slash_sprite.animation
		var animation_names: PackedStringArray = slash_sprite.sprite_frames.get_animation_names()
		if animation_name == StringName() and animation_names.size() > 0:
			animation_name = StringName(animation_names[0])
		elif animation_name != StringName() and not animation_names.has(String(animation_name)) and animation_names.size() > 0:
			animation_name = StringName(animation_names[0])
		if animation_name != StringName():
			var frame_count: int = slash_sprite.sprite_frames.get_frame_count(animation_name)
			var total_relative_duration: float = 0.0
			for frame_index in range(frame_count):
				total_relative_duration += slash_sprite.sprite_frames.get_frame_duration(animation_name, frame_index)
			var animation_speed: float = slash_sprite.sprite_frames.get_animation_speed(animation_name)
			if animation_speed <= 0.001:
				animation_speed = 1.0
			duration = max(0.05, total_relative_duration / animation_speed)
	effect.queue_free()
	return duration

func _get_scene_animation_duration(scene: PackedScene, default_duration: float = 0.18) -> float:
	if scene == null:
		return default_duration
	var effect := scene.instantiate() as Node2D
	if effect == null:
		return default_duration
	var duration: float = default_duration
	var sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null and sprite.sprite_frames != null:
		var animation_name: StringName = sprite.animation
		var animation_names: PackedStringArray = sprite.sprite_frames.get_animation_names()
		if animation_name == StringName() and animation_names.size() > 0:
			animation_name = StringName(animation_names[0])
		elif animation_name != StringName() and not animation_names.has(String(animation_name)) and animation_names.size() > 0:
			animation_name = StringName(animation_names[0])
		if animation_name != StringName():
			var frame_count: int = sprite.sprite_frames.get_frame_count(animation_name)
			var total_relative_duration: float = 0.0
			for frame_index in range(frame_count):
				total_relative_duration += sprite.sprite_frames.get_frame_duration(animation_name, frame_index)
			var animation_speed: float = sprite.sprite_frames.get_animation_speed(animation_name) * max(sprite.speed_scale, 0.001)
			if animation_speed <= 0.001:
				animation_speed = 1.0
			duration = max(0.05, total_relative_duration / animation_speed)
	effect.queue_free()
	return duration

func _build_role_data() -> Array:
	return [
		{
			"id": "swordsman",
			"name": "\u5251\u58EB",
			"color": Color(1.0, 0.66, 0.35, 1.0),
			"speed_scale": 1.03,
			"attack_interval": 0.66,
			"damage": 15.0,
			"range": 82.0,
			"background_interval": 2.6
		},
		{
			"id": "gunner",
			"name": "\u67AA\u624B",
			"color": Color(1.0, 0.35, 0.32, 1.0),
			"speed_scale": 1.0,
			"attack_interval": 0.44,
			"damage": 9.0,
			"range": 360.0,
			"background_interval": 2.0
		},
		{
			"id": "mage",
			"name": "\u672F\u5E08",
			"color": Color(0.44, 0.86, 1.0, 1.0),
			"speed_scale": 0.92,
			"attack_interval": 1.2,
			"damage": 12.5,
			"range": 286.0,
			"background_interval": 3.0
		}
	]

func _serialize_color_for_save(color_value: Variant) -> Array:
	var color := _normalize_role_color(color_value, Color.WHITE)
	return [color.r, color.g, color.b, color.a]

func _normalize_role_color(color_value: Variant, fallback: Color) -> Color:
	if color_value is Color:
		return color_value
	if color_value is Array:
		var color_array: Array = color_value
		if color_array.size() >= 4:
			return Color(
				float(color_array[0]),
				float(color_array[1]),
				float(color_array[2]),
				float(color_array[3])
			)
		if color_array.size() >= 3:
			return Color(
				float(color_array[0]),
				float(color_array[1]),
				float(color_array[2]),
				1.0
			)
	if color_value is String:
		var color_text := str(color_value).strip_edges()
		if color_text.begins_with("(") and color_text.ends_with(")"):
			color_text = color_text.substr(1, color_text.length() - 2)
		var parts := color_text.split(",", false)
		if parts.size() >= 4:
			return Color(
				float(parts[0].strip_edges()),
				float(parts[1].strip_edges()),
				float(parts[2].strip_edges()),
				float(parts[3].strip_edges())
			)
		if parts.size() >= 3:
			return Color(
				float(parts[0].strip_edges()),
				float(parts[1].strip_edges()),
				float(parts[2].strip_edges()),
				1.0
			)
	return fallback

func _serialize_roles_for_save() -> Array:
	var saved_roles: Array = []
	for role_variant in roles:
		if not (role_variant is Dictionary):
			continue
		var role_data: Dictionary = (role_variant as Dictionary).duplicate(true)
		role_data["color"] = _serialize_color_for_save(role_data.get("color", Color.WHITE))
		saved_roles.append(role_data)
	return saved_roles

func _normalize_loaded_roles(saved_roles: Variant) -> Array:
	var base_roles := _build_role_data()
	var base_role_map: Dictionary = {}
	for base_role_variant in base_roles:
		if base_role_variant is Dictionary:
			var base_role: Dictionary = base_role_variant
			base_role_map[str(base_role.get("id", ""))] = base_role

	var normalized_roles: Array = []
	if saved_roles is Array:
		for saved_role_variant in saved_roles:
			if not (saved_role_variant is Dictionary):
				continue
			var saved_role: Dictionary = (saved_role_variant as Dictionary).duplicate(true)
			var role_id := str(saved_role.get("id", ""))
			var merged_role: Dictionary = {}
			var fallback_color: Color = Color.WHITE
			if base_role_map.has(role_id):
				var base_role_data: Dictionary = (base_role_map[role_id] as Dictionary)
				merged_role = base_role_data.duplicate(true)
				fallback_color = base_role_data.get("color", Color.WHITE)
			merged_role.merge(saved_role, true)
			merged_role["color"] = _normalize_role_color(
				merged_role.get("color", Color.WHITE),
				fallback_color
			)
			normalized_roles.append(merged_role)

	var ordered_ids: Array = []
	for role_variant in normalized_roles:
		if role_variant is Dictionary:
			var role_id := str((role_variant as Dictionary).get("id", ""))
			if role_id != "":
				ordered_ids.append(role_id)
	for fallback_role_variant in base_roles:
		var fallback_role: Dictionary = fallback_role_variant
		var fallback_id := str(fallback_role.get("id", ""))
		if ordered_ids.has(fallback_id):
			continue
		normalized_roles.append(fallback_role.duplicate(true))

	return normalized_roles

func _build_role_upgrade_data() -> Dictionary:
	return {
		"swordsman": {"level": 0, "damage_bonus": 0.0, "interval_bonus": 0.0, "range_bonus": 0.0, "skill_bonus": 0.0},
		"gunner": {"level": 0, "damage_bonus": 0.0, "interval_bonus": 0.0, "range_bonus": 0.0, "skill_bonus": 0.0},
		"mage": {"level": 0, "damage_bonus": 0.0, "interval_bonus": 0.0, "range_bonus": 0.0, "skill_bonus": 0.0}
	}

func _build_background_cooldowns() -> Dictionary:
	return {
		"swordsman": 0.8,
		"gunner": 0.6,
		"mage": 1.0
	}

func _build_slot_progress_data() -> Dictionary:
	return {
		"body": 0,
		"combat": 0,
		"skill": 0
	}

func _make_slot_resonance_key(slot_id: String, threshold: int) -> String:
	return "%s_%d" % [slot_id, threshold]

func _is_slot_resonance_unlocked(slot_id: String, threshold: int) -> bool:
	return bool(slot_resonances_unlocked.get(_make_slot_resonance_key(slot_id, threshold), false))

func _unlock_slot_resonance(slot_id: String, threshold: int) -> void:
	var resonance_key := _make_slot_resonance_key(slot_id, threshold)
	if bool(slot_resonances_unlocked.get(resonance_key, false)):
		return

	slot_resonances_unlocked[resonance_key] = true
	var role_id := str(_get_active_role().get("id", ""))
	var role_data: Dictionary = role_upgrade_levels.get(role_id, {}).duplicate(true)
	var tag_text := ""
	match slot_id:
		"body":
			tag_text = "娑撴挸鐫橀崗閬嶇"
			if threshold == SLOT_RESONANCE_FIRST_THRESHOLD:
				role_data["damage_bonus"] = float(role_data.get("damage_bonus", 0.0)) + 4.0
				role_data["range_bonus"] = float(role_data.get("range_bonus", 0.0)) + 8.0
				role_data["skill_bonus"] = float(role_data.get("skill_bonus", 0.0)) + 0.08
				_apply_role_share(role_id, 1.4, 0.0, 3.0, 0.08)
			else:
				role_data["damage_bonus"] = float(role_data.get("damage_bonus", 0.0)) + 6.0
				role_data["interval_bonus"] = float(role_data.get("interval_bonus", 0.0)) + 0.03
				role_data["range_bonus"] = float(role_data.get("range_bonus", 0.0)) + 10.0
				role_data["skill_bonus"] = float(role_data.get("skill_bonus", 0.0)) + 0.12
				_apply_role_share(role_id, 2.0, 0.04, 5.0, 0.12)
		"combat":
			tag_text = "连携共鸣"
			if threshold == SLOT_RESONANCE_FIRST_THRESHOLD:
				global_damage_multiplier += 0.04
				background_interval_multiplier = max(0.66, background_interval_multiplier - 0.05)
				role_switch_cooldown_bonus += 0.45
				switch_cooldown_remaining = max(0.0, switch_cooldown_remaining - 0.4)
			else:
				global_damage_multiplier += 0.06
				background_interval_multiplier = max(0.55, background_interval_multiplier - 0.07)
				role_switch_cooldown_bonus += 0.55
				switch_cooldown_remaining = max(0.0, switch_cooldown_remaining - 0.8)
				switch_invulnerability_remaining = max(switch_invulnerability_remaining, 0.12)
		"skill":
			tag_text = "大招共鸣"
			if threshold == SLOT_RESONANCE_FIRST_THRESHOLD:
				energy_gain_multiplier += 0.1
				max_mana += 10.0
				current_mana = min(max_mana, current_mana + 15.0)
				ultimate_cost_multiplier = max(0.68, ultimate_cost_multiplier - 0.04)
			else:
				energy_gain_multiplier += 0.14
				max_mana += 14.0
				current_mana = min(max_mana, current_mana + 24.0)
				ultimate_cost_multiplier = max(0.6, ultimate_cost_multiplier - 0.05)
				_grant_ultimate_seals(1, "大招共鸣")

	if not role_data.is_empty():
		role_upgrade_levels[role_id] = role_data
	if tag_text != "":
		_spawn_combat_tag(global_position + Vector2(0.0, -34.0), "%s %d" % [tag_text, threshold], Color(1.0, 0.9, 0.56, 1.0))
	mana_changed.emit(current_mana, max_mana)

func _check_slot_resonance_unlocks() -> void:
	for slot_id in ["body", "combat", "skill"]:
		var slot_level := int(build_slot_levels.get(slot_id, 0))
		if slot_level >= SLOT_RESONANCE_FIRST_THRESHOLD and not _is_slot_resonance_unlocked(slot_id, SLOT_RESONANCE_FIRST_THRESHOLD):
			_unlock_slot_resonance(slot_id, SLOT_RESONANCE_FIRST_THRESHOLD)
		if slot_level >= SLOT_RESONANCE_SECOND_THRESHOLD and not _is_slot_resonance_unlocked(slot_id, SLOT_RESONANCE_SECOND_THRESHOLD):
			_unlock_slot_resonance(slot_id, SLOT_RESONANCE_SECOND_THRESHOLD)

func configure_story_loadout(team_order: Array, equipped_styles: Dictionary) -> void:
	var ordered_roles: Array = []
	for role_variant in team_order:
		var role_id := str(role_variant)
		for role_data in roles:
			if str(role_data.get("id", "")) == role_id:
				ordered_roles.append(role_data)
				break
	for role_data in roles:
		if not ordered_roles.has(role_data):
			ordered_roles.append(role_data)
	roles = ordered_roles
	for role_id in ["swordsman", "gunner", "mage"]:
		story_equipped_styles[role_id] = str(equipped_styles.get(role_id, "default"))
	active_role_index = clamp(active_role_index, 0, max(0, roles.size() - 1))
	_update_active_role_state()

func _get_story_style_id(role_id: String) -> String:
	return str(story_equipped_styles.get(role_id, "default"))

func _get_story_style_damage_multiplier(role_id: String) -> float:
	match _get_story_style_id(role_id):
		"moon_edge":
			return 0.92
		"star_pierce":
			return 0.95
		"frostfield":
			return 0.94
	return 1.0

func _get_story_style_range_multiplier(role_id: String) -> float:
	match _get_story_style_id(role_id):
		"moon_edge":
			return 1.22
		"frostfield":
			return 1.18
	return 1.0

func _get_story_style_interval_bonus(role_id: String) -> float:
	match _get_story_style_id(role_id):
		"moon_edge":
			return 0.02
		"frostfield":
			return 0.08
	return 0.0

func _get_story_style_extra_pierce(role_id: String) -> int:
	if _get_story_style_id(role_id) == "star_pierce":
		return 1
	return 0

func _get_story_style_bullet_speed_multiplier(role_id: String) -> float:
	if _get_story_style_id(role_id) == "star_pierce":
		return 1.2
	return 1.0

func _get_story_style_slow_bonus(role_id: String) -> float:
	if _get_story_style_id(role_id) == "frostfield":
		return 0.12
	return 0.0

func _get_upgrade_slot_label(slot_id: String) -> String:
	match slot_id:
		"body":
			return "\u6218\u6597"
		"combat":
			return "\u8FDE\u643A"
		"skill":
			return "\u5927\u62DB"
		_:
			return "\u6784\u7B51"

func _build_role_special_state_data() -> Dictionary:
	return {
		"swordsman": {
			"crescent_level": 0,
			"thrust_level": 0,
			"counter_level": 0,
			"pursuit_level": 0,
			"blood_level": 0,
			"stance_level": 0
		},
		"gunner": {
			"scatter_level": 0,
			"focus_level": 0,
			"support_level": 0,
			"barrage_level": 0,
			"reload_level": 0,
			"lock_level": 0
		},
		"mage": {
			"echo_level": 0,
			"frost_level": 0,
			"support_level": 0,
			"storm_level": 0,
			"flow_level": 0,
			"gravity_level": 0
		}
	}

func _build_attribute_training_data() -> Dictionary:
	return {
		"vitality": 0,
		"agility": 0,
		"power": 0
	}

func _build_role_timing_state_data(default_value: Variant) -> Dictionary:
	var data := {}
	for role_data in _build_role_data():
		data[str(role_data.get("id", ""))] = default_value
	return data

func _get_card_level(card_id: String) -> int:
	return int(card_pick_levels.get(card_id, 0))

func _can_offer_card(card_id: String, max_level: int = 3) -> bool:
	if card_id in ["battle_dangzhen_dielang", "battle_dangzhen_huichao"] and _get_card_level("battle_dangzhen_qichao") <= 0:
		return false
	return _get_card_level(card_id) < max_level

func _has_elite_relic(relic_id: String) -> bool:
	return bool(elite_relics_unlocked.get(relic_id, false))

func _unlock_elite_relic(relic_id: String) -> void:
	elite_relics_unlocked[relic_id] = true

func _get_build_card_config(card_id: String) -> Dictionary:
	match card_id:
		"battle_dangzhen_qichao":
			return {
				"title": "起潮",
				"max_level": 3,
				"set_key": "battle_dangzhen",
				"glossary_terms": []
			}
		"battle_dangzhen_dielang":
			return {
				"title": "叠浪",
				"max_level": 3,
				"set_key": "battle_dangzhen",
				"glossary_terms": []
			}
		"battle_dangzhen_huichao":
			return {
				"title": "回潮",
				"max_level": 2,
				"set_key": "battle_dangzhen",
				"glossary_terms": []
			}
		"battle_cover":
			return {
				"title": "扩域",
				"max_level": 3,
				"set_key": "battle_disaster",
				"glossary_terms": ["回旋", "散射", "冰纹"]
			}
		"battle_split":
			return {
				"title": "重影",
				"max_level": 3,
				"set_key": "battle_disaster",
				"glossary_terms": ["回旋", "散射", "回响"]
			}
		"battle_overload":
			return {
				"title": "化身",
				"max_level": 2,
				"set_key": "battle_disaster",
				"glossary_terms": []
			}
		"battle_tide":
			return {
				"title": "王域",
				"max_level": 3,
				"set_key": "battle_domain",
				"glossary_terms": []
			}
		"battle_devour":
			return {
				"title": "吞灭",
				"max_level": 3,
				"set_key": "battle_domain",
				"glossary_terms": ["战线", "续行", "流转"]
			}
		"battle_aftershock":
			return {
				"title": "归墟",
				"max_level": 2,
				"set_key": "battle_domain",
				"glossary_terms": []
			}
		"battle_suppress":
			return {
				"title": "断界",
				"max_level": 3,
				"set_key": "battle_net",
				"glossary_terms": ["守势", "锁定", "冰纹"]
			}
		"battle_chain":
			return {
				"title": "天网",
				"max_level": 3,
				"set_key": "battle_net",
				"glossary_terms": []
			}
		"battle_hunt":
			return {
				"title": "诛界",
				"max_level": 2,
				"set_key": "battle_net",
				"glossary_terms": ["穿锋", "聚焦", "塌缩"]
			}
		"combat_tuning":
			return {
				"title": "调度",
				"max_level": 3,
				"set_key": "combat_sword_array",
				"glossary_terms": []
			}
		"combat_assault":
			return {
				"title": "并锋",
				"max_level": 3,
				"set_key": "combat_sword_array",
				"glossary_terms": []
			}
		"combat_support":
			return {
				"title": "援阵",
				"max_level": 2,
				"set_key": "combat_sword_array",
				"glossary_terms": ["援护"]
			}
		"combat_swap":
			return {
				"title": "追切",
				"max_level": 3,
				"set_key": "combat_hunt",
				"glossary_terms": []
			}
		"combat_rotation":
			return {
				"title": "借位",
				"max_level": 3,
				"set_key": "combat_hunt",
				"glossary_terms": []
			}
		"combat_synergy":
			return {
				"title": "围猎",
				"max_level": 2,
				"set_key": "combat_hunt",
				"glossary_terms": []
			}
		"combat_legacy":
			return {
				"title": "传承",
				"max_level": 3,
				"set_key": "combat_relay",
				"glossary_terms": []
			}
		"combat_rearguard":
			return {
				"title": "回响",
				"max_level": 3,
				"set_key": "combat_relay",
				"glossary_terms": []
			}
		"combat_relay":
			return {
				"title": "续阵",
				"max_level": 2,
				"set_key": "combat_relay",
				"glossary_terms": []
			}
		"skill_blossom":
			return {
				"title": "终幕",
				"max_level": 3,
				"set_key": "skill_reprise",
				"glossary_terms": ["追斩", "弹幕", "风暴"]
			}
		"skill_extend":
			return {
				"title": "延展",
				"max_level": 3,
				"set_key": "skill_reprise",
				"glossary_terms": []
			}
		"skill_reprise":
			return {
				"title": "再演",
				"max_level": 2,
				"set_key": "skill_reprise",
				"glossary_terms": []
			}
		"skill_afterglow":
			return {
				"title": "余辉",
				"max_level": 3,
				"set_key": "skill_afterglow",
				"glossary_terms": []
			}
		"skill_borrow_fire":
			return {
				"title": "借火",
				"max_level": 3,
				"set_key": "skill_afterglow",
				"glossary_terms": []
			}
		"skill_finale":
			return {
				"title": "圣裁",
				"max_level": 2,
				"set_key": "skill_afterglow",
				"glossary_terms": []
			}
		"skill_resonance":
			return {
				"title": "共振",
				"max_level": 3,
				"set_key": "skill_overload",
				"glossary_terms": []
			}
		"skill_reflux":
			return {
				"title": "溢流",
				"max_level": 3,
				"set_key": "skill_overload",
				"glossary_terms": []
			}
		"skill_overdrive":
			return {
				"title": "超载",
				"max_level": 2,
				"set_key": "skill_overload",
				"glossary_terms": []
			}
		_:
			return {}

func _get_build_final_set_data(set_key: String) -> Dictionary:
	match set_key:
		"battle_dangzhen":
			return {
				"main_name": "荡阵",
				"full_title": "荡阵：潮锋连卷",
				"requirements": [
					{"card_id": "battle_dangzhen_qichao", "label": "起潮", "max_level": 3},
					{"card_id": "battle_dangzhen_dielang", "label": "叠浪", "max_level": 3},
					{"card_id": "battle_dangzhen_huichao", "label": "回潮", "max_level": 2}
				]
			}
		"battle_disaster":
			return {
				"main_name": "天灾化身",
				"full_title": "天灾化身：断神诸恶",
				"requirements": [
					{"card_id": "battle_cover", "label": "扩域", "max_level": 3},
					{"card_id": "battle_split", "label": "重影", "max_level": 3},
					{"card_id": "battle_overload", "label": "化身", "max_level": 2}
				]
			}
		"battle_domain":
			return {
				"main_name": "王域归墟",
				"full_title": "王域归墟：君临终劫",
				"requirements": [
					{"card_id": "battle_tide", "label": "王域", "max_level": 3},
					{"card_id": "battle_devour", "label": "吞灭", "max_level": 3},
					{"card_id": "battle_aftershock", "label": "归墟", "max_level": 2}
				]
			}
		"battle_net":
			return {
				"main_name": "断界天网",
				"full_title": "断界天网：裂空诛界",
				"requirements": [
					{"card_id": "battle_suppress", "label": "断界", "max_level": 3},
					{"card_id": "battle_chain", "label": "天网", "max_level": 3},
					{"card_id": "battle_hunt", "label": "诛界", "max_level": 2}
				]
			}
		"combat_sword_array":
			return {
				"main_name": "三相剑阵",
				"full_title": "三相剑阵：并锋同契",
				"requirements": [
					{"card_id": "combat_tuning", "label": "调度", "max_level": 3},
					{"card_id": "combat_assault", "label": "并锋", "max_level": 3},
					{"card_id": "combat_support", "label": "援阵", "max_level": 2}
				]
			}
		"combat_hunt":
			return {
				"main_name": "追换猎阵",
				"full_title": "追换猎阵：逐影封喉",
				"requirements": [
					{"card_id": "combat_swap", "label": "追切", "max_level": 3},
					{"card_id": "combat_rotation", "label": "借位", "max_level": 3},
					{"card_id": "combat_synergy", "label": "围猎", "max_level": 2}
				]
			}
		"combat_relay":
			return {
				"main_name": "传火轮契",
				"full_title": "传火轮契：继锋承命",
				"requirements": [
					{"card_id": "combat_legacy", "label": "传承", "max_level": 3},
					{"card_id": "combat_rearguard", "label": "回响", "max_level": 3},
					{"card_id": "combat_relay", "label": "续阵", "max_level": 2}
				]
			}
		"skill_reprise":
			return {
				"main_name": "终幕再演",
				"full_title": "终幕再演：余烬回天",
				"requirements": [
					{"card_id": "skill_blossom", "label": "终幕", "max_level": 3},
					{"card_id": "skill_extend", "label": "延展", "max_level": 3},
					{"card_id": "skill_reprise", "label": "再演", "max_level": 2}
				]
			}
		"skill_afterglow":
			return {
				"main_name": "余辉圣裁",
				"full_title": "余辉圣裁：暮焰裁星",
				"requirements": [
					{"card_id": "skill_afterglow", "label": "余辉", "max_level": 3},
					{"card_id": "skill_borrow_fire", "label": "借火", "max_level": 3},
					{"card_id": "skill_finale", "label": "圣裁", "max_level": 2}
				]
			}
		"skill_overload":
			return {
				"main_name": "共鸣超载",
				"full_title": "共鸣超载：星火连宵",
				"requirements": [
					{"card_id": "skill_resonance", "label": "共振", "max_level": 3},
					{"card_id": "skill_reflux", "label": "溢流", "max_level": 3},
					{"card_id": "skill_overdrive", "label": "超载", "max_level": 2}
				]
			}
		_:
			return {}

func _is_final_set_complete(set_key: String) -> bool:
	var final_set := _get_build_final_set_data(set_key)
	if final_set.is_empty():
		return false
	for requirement in final_set.get("requirements", []):
		if not (requirement is Dictionary):
			continue
		var card_id := str(requirement.get("card_id", ""))
		var max_level := int(requirement.get("max_level", 0))
		if card_id == "" or _get_card_level(card_id) < max_level:
			return false
	return true

func _is_disaster_set_complete() -> bool:
	return _is_final_set_complete("battle_disaster")

func _get_role_theme_color(role_id: String) -> Color:
	for role_data in roles:
		if str(role_data.get("id", "")) == role_id:
			return role_data.get("color", Color(1.0, 1.0, 1.0, 1.0))
	return Color(1.0, 1.0, 1.0, 1.0)

func _announce_completed_final_set(set_key: String) -> void:
	if set_key == "" or final_set_unlock_announced.get(set_key, false):
		return
	if not _is_final_set_complete(set_key):
		return
	final_set_unlock_announced[set_key] = true
	var final_set := _get_build_final_set_data(set_key)
	var accent := _get_role_theme_color(str(_get_active_role().get("id", "swordsman")))
	_show_switch_banner("成套", str(final_set.get("full_title", "")), accent)
	_spawn_combat_tag(global_position + Vector2(0.0, -66.0), str(final_set.get("main_name", "")), Color(1.0, 0.96, 0.8, 1.0))
	_spawn_ring_effect(global_position, 88.0, Color(accent.r, accent.g, accent.b, 0.82), 10.0, 0.26)
	_spawn_ring_effect(global_position, 132.0, Color(1.0, 0.42, 0.22, 0.5), 6.0, 0.3)
	_spawn_burst_effect(global_position, 96.0, Color(accent.r, accent.g, accent.b, 0.18), 0.24)

func _build_role_preview_line(role_id: String, content: String) -> String:
	return "%s：%s" % [_get_role_name(role_id), content]

func _get_build_card_role_line(card_id: String, role_id: String) -> String:
	var next_level := _get_card_level(card_id) + 1
	match card_id:
		"battle_dangzhen_qichao":
			match role_id:
				"swordsman":
					return "追加 1 道月牙斩，造成 %d 点伤害" % int(round(_get_dangzhen_qichao_damage("swordsman", next_level)))
				"gunner":
					return "追加 1 道贯穿弹，造成 %d 点伤害" % int(round(_get_dangzhen_qichao_damage("gunner", next_level)))
				"mage":
					return "聚能后追加 1 道冲击波，造成 %d 点伤害" % int(round(_get_dangzhen_qichao_damage("mage", next_level)))
		"battle_dangzhen_dielang":
			match role_id:
				"swordsman":
					return "当前月牙斩结束后，立刻再补 %d 道同方向月牙斩" % next_level
				"gunner":
					return "当前贯穿弹结束后，立刻再补 %d 道同方向贯穿弹" % next_level
				"mage":
					return "第一道冲击波结束后，立刻再补 %d 道同方向冲击波（后续不再聚能）" % next_level
		"battle_dangzhen_huichao":
			match role_id:
				"swordsman":
					return "月牙斩会在反方向同时生成一道镜像斩击" if next_level == 1 else "正反两道斩击结束后，再沿其连线的垂直方向追加一道斩击（继承叠浪）"
				"gunner":
					return "改为两道贯穿弹，夹角 30°" if next_level == 1 else "改为三道贯穿弹，夹角 30°（全部继承叠浪）"
				"mage":
					return "不同冲击波之间的夹角增大" if next_level == 1 else "不同冲击波之间的夹角进一步增大"
		"battle_cover":
			match role_id:
				"swordsman":
					return "攻击范围 +10，回旋强化 +1"
				"gunner":
					return "攻击距离 +10，散射强化 +1"
				"mage":
					return "爆炸范围 +10，冰纹强化 +1"
		"battle_split":
			match role_id:
				"swordsman":
					return "追加 1 次扫尾斩击，伤害为原来的40%"
				"gunner":
					return "追加 1 发补射，单发伤害为原来的40%"
				"mage":
					return "追加 1 次回响爆炸，余爆伤害为原来的24%"
		"battle_overload":
			var damage_ratio := 118 if next_level == 1 else 126
			match role_id:
				"swordsman":
					return "每 3 次普通攻击追加 1 次强化重斩，伤害为原来的%d%%" % damage_ratio
				"gunner":
					return "每 3 次普通攻击追加 1 发强化弹，单发伤害为原来的%d%%" % damage_ratio
				"mage":
					return "每 3 次普通攻击追加 1 次强化轰炸，伤害为原来的%d%%" % damage_ratio
		"battle_tide":
			var tide_radius: int = [32, 40, 48][min(next_level - 1, 2)]
			var tide_damage: int = [45, 55, 65][min(next_level - 1, 2)]
			var extra := ""
			if next_level >= 2:
				extra = "，并附带减速"
			if next_level >= 3:
				extra += "，命中后返还 6 点符能"
			return "同次命中 2 个以上敌人时追加波纹，半径 %d，伤害为原来的%d%%%s" % [tide_radius, tide_damage, extra]
		"battle_devour":
			match role_id:
				"swordsman":
					return "命中后吸血更高，最大生命 +8，并回复 10 点生命"
				"gunner":
					return "命中与击杀回能提高，立即回复 8 点符能"
				"mage":
					return "轰炸前牵引敌人更强，立即回复 8 点符能"
		"battle_aftershock":
			var shock_damage := 35 if next_level == 1 else 45
			var pulse_text := "1 段" if next_level == 1 else "2 段"
			var extra_slow := "，并附带减速" if next_level >= 2 else ""
			return "攻击结束点留下 %s余震，伤害为原来的%d%%%s" % [pulse_text, shock_damage, extra_slow]
		"battle_suppress":
			match role_id:
				"swordsman":
					return "连段期间减伤 -3%，守势强化 +1"
				"gunner":
					return "远距离命中更容易叠锁定，锁定强化 +1"
				"mage":
					return "爆炸附带减速更强，冰纹强化 +1"
		"battle_chain":
			var bounce_count := 1 if next_level == 1 else 2
			var chain_damage: int = [45, 55, 65][min(next_level - 1, 2)]
			var extra_mana := "，并返还 2 点符能" if next_level >= 3 else ""
			return "命中后自动追击 %d 次，伤害为原来的%d%%%s" % [bounce_count, chain_damage, extra_mana]
		"battle_hunt":
			match role_id:
				"swordsman":
					return "正前方斩击更强，穿锋强化 +1"
				"gunner":
					return "远距离主弹更集中，聚焦强化 +1"
				"mage":
					return "轰炸前吸附范围更大，塌缩强化 +1"
		"combat_tuning":
			var refund_text: float = [1.0, 1.2, 1.4][min(next_level - 1, 2)]
			return "切换角色入场冷却 -0.45 秒，并立即返还 %.1f 秒当前冷却" % refund_text
		"combat_assault":
			match role_id:
				"swordsman":
					return "切换角色入场斩击伤害 +16%，位移距离 +6%"
				"gunner":
					return "切换角色入场弹幕伤害 +16%，覆盖范围 +6%"
				"mage":
					return "切换角色入场轰炸伤害 +16%，爆炸范围 +6%"
		"combat_support":
			var interval_text: int = [8, 16][min(next_level - 1, 1)]
			match role_id:
				"swordsman":
					return "后台出手间隔 -%d%%" % interval_text
				"gunner":
					return "后台援护目标数 +%d，出手间隔 -%d%%" % [1, interval_text]
				"mage":
					return "后台副爆点 +%d，出手间隔 -%d%%" % [1, interval_text]
		"combat_swap":
			var dash_distance: int = [50, 70, 90][min(next_level - 1, 2)]
			var guard_time: float = [0.35, 0.45, 0.55][min(next_level - 1, 2)]
			var extra_text := ""
			if next_level >= 2:
				extra_text = "，并返还 0.4 秒冷却"
			if next_level >= 3:
				extra_text += "，额外补 1 枚符印"
			return "切换角色入场后立刻滑步 %d，获得 %.2f 秒无敌，并回复 %d 点符能%s" % [dash_distance, guard_time, [3, 5, 7][min(next_level - 1, 2)], extra_text]
		"combat_rotation":
			var duration_text: float = [2.5, 3.5, 4.5][min(next_level - 1, 2)]
			var damage_step: int = [10, 14, 18][min(next_level - 1, 2)]
			var extra_text := ""
			if next_level >= 2:
				extra_text = "，并回复 4 点符能"
			if next_level >= 3:
				extra_text += "，额外补 1 枚符印"
			return "待机每满 2.5 秒，切换角色入场后 %.1f 秒内伤害额外提高 %d%%%s" % [duration_text, damage_step, extra_text]
		"combat_synergy":
			var combo_duration := 6 if next_level == 1 else 8
			var extra_text := ""
			if next_level >= 2:
				extra_text = "，并返还 1.2 秒切换角色入场冷却"
			return "三名角色都至少登场 1 次后，触发 %d 秒协同爆发，伤害与移速提高 8%%%s" % [combo_duration, extra_text]
		"combat_legacy":
			match role_id:
				"swordsman":
					return "退场后给下一位角色吸血增益，最大生命 +6，并回复 8 点生命"
				"gunner":
					return "退场后给下一位角色攻速与移速增益，最大生命 +6，并回复 8 点生命"
				"mage":
					return "退场后给下一位角色额外补 1 枚符印，最大生命 +6，并回复 8 点生命"
		"combat_rearguard":
			var repeat_count := 1 if next_level == 1 else 2
			var damage_ratio: int = [40, 45, 55][min(next_level - 1, 2)]
			var extra_text := "，新上场角色额外获得 2 秒 8% 减伤" if next_level >= 3 else ""
			return "退场角色会在原地追加 %d 次援护攻击，伤害为原来的%d%%%s" % [repeat_count, damage_ratio, extra_text]
		"combat_relay":
			var extra_cooldown := 0.35 if next_level == 1 else 0.55
			return "接力窗口 +0.45 秒，接力成功后额外获得 2 点符能，并返还 %.2f 秒切换角色入场冷却" % extra_cooldown
		"skill_blossom":
			match role_id:
				"swordsman":
					return "释放大招段数更高，追斩强化 +1"
				"gunner":
					return "释放大招波次数更高，弹幕强化 +1"
				"mage":
					return "释放大招轰炸轮数更高，风暴强化 +1"
		"skill_extend":
			var extend_bonus: int = [12, 24, 36][min(next_level - 1, 2)]
			var extra_text := ""
			if next_level >= 2:
				extra_text = "，释放大招期间受伤 -10%"
			if next_level >= 3:
				extra_text += "，释放大招结束后返还 10 点符能"
			return "释放大招持续时间与总段数 +%d%%%s" % [extend_bonus, extra_text]
		"skill_reprise":
			match role_id:
				"swordsman":
					return "释放大招结束后追加 1 次再演斩击"
				"gunner":
					return "释放大招结束后追加 1 轮再演弹幕"
				"mage":
					return "释放大招结束后追加 1 轮再演轰炸"
		"skill_afterglow":
			var afterglow_time := str(snappedf(2.2 + next_level * 0.35, 0.01))
			var afterglow_damage := int(round(12.0 + next_level * 5.0))
			return "释放大招后进入 %s 秒余辉，伤害 +%d%%，攻击间隔缩短" % [afterglow_time, afterglow_damage]
		"skill_borrow_fire":
			var damage_bonus: int = [18, 24, 30][min(next_level - 1, 2)]
			var extra_text := ""
			if next_level >= 2:
				extra_text = "，后台援护间隔更短"
			if next_level >= 3:
				extra_text += "，并立即返还 8 点符能"
			return "释放大招期间普通攻击伤害 +%d%%，攻速提高%s" % [damage_bonus, extra_text]
		"skill_finale":
			var finale_damage: int = [45, 60][min(next_level - 1, 1)]
			return "释放大招最后一击伤害 +%d%%，范围 +20%%" % finale_damage
		"skill_resonance":
			var cooldown_text: float = [0.25, 0.35, 0.45][min(next_level - 1, 2)]
			return "后台援护间隔 -5%%，切换角色入场冷却 -%.2f 秒，并立即补 1 枚符印" % cooldown_text
		"skill_reflux":
			var energy_gain: int = [18, 24, 30][min(next_level - 1, 2)]
			var cooldown_refund: float = [0.6, 0.9, 1.2][min(next_level - 1, 2)]
			var extra_text := ""
			if next_level >= 2:
				extra_text = "，并额外补 1 枚符印"
			if next_level >= 3:
				extra_text += "，后台出手会继续提速"
			return "释放大招结束后返还 %d 点符能和 %.1f 秒切换角色入场冷却%s" % [energy_gain, cooldown_refund, extra_text]
		"skill_overdrive":
			var energy_gain: int = 22 if next_level == 1 else 28
			return "立刻获得 %d 点符能和 1 枚符印" % energy_gain
		_:
			return ""
	return ""

func _get_build_card_common_lines(card_id: String) -> Array[String]:
	var next_level := _get_card_level(card_id) + 1
	match card_id:
		"battle_dangzhen_qichao":
			return ["叠浪与回潮只有在拿到起潮后才会刷新"]
		"battle_dangzhen_dielang":
			return ["起潮触发后，按等级连续补发同方向追加攻击"]
		"battle_dangzhen_huichao":
			return ["改变追加攻击的出手方向，并继承叠浪效果"]
		"battle_cover":
			return ["全队伤害 +1.5", "技能系数 +0.04"]
		"battle_split":
			return ["全队伤害 +1.2", "范围或射程 +4", "技能系数 +0.06"]
		"battle_overload":
			return ["强化攻击额外伤害 +18% / 26%", "强化特效会变得更大更亮"]
		"battle_tide":
			return ["同次命中 2 个以上敌人时触发", "波纹半径 32 / 40 / 48", "高等级追加减速与回能"]
		"battle_devour":
			return ["最大生命 +8", "立即回复 10 点生命", "立即回复 8 点符能"]
		"battle_aftershock":
			return ["普通攻击终点留下余震", "伤害为原来的35% / 45%", "高等级会多跳 1 次并附带减速"]
		"battle_suppress":
			return ["全队伤害 +1.0", "范围或射程 +6", "受到的伤害 -3%"]
		"battle_chain":
			return ["命中后自动追击", "伤害为原来的45% / 55% / 65%", "3 级额外返还 2 点符能"]
		"battle_hunt":
			return ["全队伤害 +2.4", "范围或射程 +6", "对精英和 Boss 伤害 +14%", "对 45% 血以下目标伤害 +10%"]
		"combat_tuning":
			return ["切换角色入场冷却 -0.45 秒", "立刻返还当前冷却"]
		"combat_assault":
			return ["全队伤害 +1.4", "范围或射程 +4", "技能系数 +0.08"]
		"combat_support":
			return ["后台出手间隔 -8% / -16%"]
		"combat_swap":
			return ["切换角色入场后获得无敌滑步", "回复 3 / 5 / 7 点符能", "高等级返还冷却并补符印"]
		"combat_rotation":
			return ["待机越久，切换角色入场后的爆发越高", "每满 2.5 秒叠 1 层", "高等级会补符能和符印"]
		"combat_synergy":
			return ["三名角色都登场过后触发", "全队伤害和移速提高 8%", "高等级返还切换角色入场冷却"]
		"combat_legacy":
			return ["退场馈赠更强", "最大生命 +6", "立即回复 8 点生命"]
		"combat_rearguard":
			return ["退场角色会追加援护攻击", "伤害为原来的40% / 45% / 55%", "3 级新上场角色额外获得 2 秒减伤"]
		"combat_relay":
			return ["接力窗口 +0.45 秒", "接力成功后额外获得 2 点符能", "并返还切换角色入场冷却"]
		"skill_blossom":
			return ["强化释放大招本体", "剑士追加段数，枪手增加波次，术师增加轰炸轮数"]
		"skill_extend":
			return ["释放大招持续时间与总段数 +12% / 24% / 36%", "2 级起释放大招期间受伤 -10%", "3 级释放大招结束后返还 10 点符能"]
		"skill_reprise":
			return ["释放大招结束后追加 1 次再演", "范围与弹量会随等级提高"]
		"skill_afterglow":
			return ["释放大招后进入余辉状态", "余辉期间伤害提高，攻击间隔缩短"]
		"skill_borrow_fire":
			return ["释放大招期间普通攻击更强更快", "2 级起后台援护也会提速", "3 级立即返还 8 点符能"]
		"skill_finale":
			return ["强化释放大招最后一击", "伤害 +45% / 60%", "范围 +20%"]
		"skill_resonance":
			return ["后台援护间隔 -5%", "切换角色入场冷却缩短", "立即补 1 枚符印"]
		"skill_reflux":
			return ["释放大招结束后返还能量与切换角色入场冷却", "2 级补 1 枚符印", "3 级后台节奏继续加快"]
		"skill_overdrive":
			return ["立刻获得大量符能", "立刻获得 1 枚符印"]
		_:
			return []

func _build_new_card_ui_payload(card_id: String) -> Dictionary:
	var config := _get_build_card_config(card_id)
	if config.is_empty():
		return {}

	var active_role_id := str(_get_active_role().get("id", "swordsman"))
	var active_role_preview := ""
	var other_role_lines: Array[String] = []
	var detail_lines: Array[String] = []
	for role_id in ["swordsman", "gunner", "mage"]:
		var role_line := _get_build_card_role_line(card_id, role_id)
		if role_line == "":
			continue
		if role_id == active_role_id:
			active_role_preview = _build_role_preview_line(role_id, role_line)
			detail_lines.append(_build_role_preview_line(role_id, role_line))
		else:
			other_role_lines.append(_build_role_preview_line(role_id, role_line))
			detail_lines.append(_build_role_preview_line(role_id, role_line))

	var common_lines := _get_build_card_common_lines(card_id)
	if not common_lines.is_empty():
		detail_lines.append("")
		for line in common_lines:
			detail_lines.append("• " + line)

	var final_set := _get_build_final_set_data(str(config.get("set_key", "")))
	var requirement_payload: Array = []
	for requirement in final_set.get("requirements", []):
		if requirement is Dictionary:
			requirement_payload.append({
				"label": str(requirement.get("label", "")),
				"current_level": min(_get_card_level(str(requirement.get("card_id", ""))), int(requirement.get("max_level", 0))),
				"max_level": int(requirement.get("max_level", 0))
			})

	return {
		"preview_description": active_role_preview,
		"detail_description": "\n".join(detail_lines),
		"glossary_terms": _get_glossary_entries_for_terms(config.get("glossary_terms", [])),
		"final_card_name": str(final_set.get("main_name", "")),
		"final_card_title": str(final_set.get("full_title", "")),
		"final_card_requirements": requirement_payload
	}

func _get_build_card_exact_description(card_id: String) -> String:
	var config := _get_build_card_config(card_id)
	if config.is_empty():
		return ""
	var lines: Array[String] = []
	for role_id in ["swordsman", "gunner", "mage"]:
		var role_line := _get_build_card_role_line(card_id, role_id)
		if role_line != "":
			lines.append(_build_role_preview_line(role_id, role_line))
	var common_lines := _get_build_card_common_lines(card_id)
	if not common_lines.is_empty():
		lines.append("")
		for line in common_lines:
			lines.append("• " + line)
	return "\n".join(lines)

func _make_core_card_option(slot_id: String, option_id: String, title: String, description: String, max_level: int = 3) -> Dictionary:
	var next_level := _get_card_level(option_id) + 1
	var config := _get_build_card_config(option_id)
	var effective_title := title
	var effective_description := description
	var effective_max_level := max_level
	var ui_payload := _build_core_card_ui_payload(option_id)
	if not config.is_empty():
		effective_title = str(config.get("title", title))
		effective_description = _get_build_card_exact_description(option_id)
		effective_max_level = int(config.get("max_level", max_level))
		ui_payload = _build_new_card_ui_payload(option_id)
	return {
		"id": option_id,
		"slot": slot_id,
		"slot_label": _get_upgrade_slot_label(slot_id),
		"title": "%s Lv.%d" % [effective_title, next_level],
		"preview_description": ui_payload.get("preview_description", _get_option_preview_description(option_id)),
		"description": ui_payload.get("detail_description", effective_description),
		"detail_description": ui_payload.get("detail_description", effective_description),
		"glossary_terms": ui_payload.get("glossary_terms", []),
		"exact_description": effective_description,
		"final_card_name": ui_payload.get("final_card_name", ""),
		"final_card_title": ui_payload.get("final_card_title", ""),
		"final_card_requirements": ui_payload.get("final_card_requirements", []),
		"max_level": effective_max_level
	}

func _build_core_card_ui_payload(card_id: String) -> Dictionary:
	var active_role_id := str(_get_active_role().get("id", "swordsman"))
	var active_role_name := _get_role_name(active_role_id)
	var preview_description := _get_card_preview_for_role(card_id, active_role_id)
	var role_ids := ["swordsman", "gunner", "mage"]
	var detail_lines: Array[String] = []
	var unique_previews: Dictionary = {}
	for role_id in role_ids:
		unique_previews[role_id] = _get_card_preview_for_role(card_id, role_id)

	if preview_description != "":
		detail_lines.append("当前站场: " + active_role_name)
		detail_lines.append("• " + preview_description)

	var has_role_difference := false
	for role_id in role_ids:
		if role_id == active_role_id:
			continue
		if str(unique_previews[role_id]) != preview_description:
			has_role_difference = true
			break

	if has_role_difference:
		detail_lines.append("")
		detail_lines.append("其他角色预览")
		for role_id in role_ids:
			if role_id == active_role_id:
				continue
			detail_lines.append("• " + _get_role_name(role_id) + ": " + str(unique_previews[role_id]))

	var common_lines := _get_card_common_detail_lines(card_id)
	common_lines.append_array(_get_extra_card_common_detail_lines(card_id))
	if not common_lines.is_empty():
		detail_lines.append("")
		detail_lines.append("通用效果")
		for line in common_lines:
			detail_lines.append("• " + str(line))

	return {
		"preview_description": preview_description,
		"detail_description": "\n".join(detail_lines),
		"glossary_terms": _get_glossary_entries_for_terms(_get_card_glossary_terms(card_id))
	}
func _get_role_name(role_id: String) -> String:
	match role_id:
		"swordsman":
			return "剑士"
		"gunner":
			return "枪手"
		"mage":
			return "术师"
		_:
			return "角色"
func _get_card_preview_for_role(card_id: String, role_id: String) -> String:
	var next_level := _get_card_level(card_id) + 1
	match card_id:
		"battle_cover":
			match role_id:
				"swordsman":
					return "斩击范围 +10"
				"gunner":
					return "射击距离 +10"
				"mage":
					return "爆炸范围 +10"
		"battle_tempo":
			return "攻击间隔 -0.04 秒"
		"battle_split":
			match role_id:
				"swordsman":
					return "回旋 +1，普通攻击追加一次扫尾"
				"gunner":
					return "散射 +1，每次射击额外打出 1 发散弹"
				"mage":
					return "回响 +1，轰炸后追加 1 次回响爆炸"
		"battle_devour":
			match role_id:
				"swordsman":
					return "战线 +1，普攻附带吸血"
				"gunner":
					return "续行 +1，命中与击杀额外回能"
				"mage":
					return "流转 +1，爆炸前会把敌人拉向爆点"
		"battle_suppress":
			match role_id:
				"swordsman":
					return "守势 +1，连段期间获得短暂无敌与反震"
				"gunner":
					return "锁定 +1，远距离命中会叠锁定与易伤"
				"mage":
					return "冰纹 +1，爆炸附带减速"
		"battle_hunt":
			match role_id:
				"swordsman":
					return "穿锋 +1，正前方命中追加伤害与易伤"
				"gunner":
					return "聚焦 +1，主弹速度、穿透和易伤提高"
				"mage":
					return "塌缩 +1，爆炸前拉扯周围敌人"
		"battle_focus":
			match role_id:
				"swordsman":
					return "伤害 +3.4，攻击间隔 -0.02 秒，范围 +8"
				"gunner":
					return "伤害 +3.4，攻击间隔 -0.02 秒，射程 +8"
				"mage":
					return "伤害 +3.4，攻击间隔 -0.02 秒，爆炸范围 +8"
		"battle_overload":
			match role_id:
				"swordsman":
					return "每 3 次普攻触发 1 次强化斩"
				"gunner":
					return "每 3 次普攻触发 1 次强化弹"
				"mage":
					return "每 3 次普攻触发 1 次强化轰炸"
		"combat_tuning":
			return "切人冷却 -0.45 秒，当前冷却返还 1.0 秒"
		"combat_assault":
			match role_id:
				"swordsman":
					return "进场斩伤害 +16%，位移距离 +6%"
				"gunner":
					return "进场技伤害 +16%，弹幕覆盖范围 +6%"
				"mage":
					return "进场轰炸伤害 +16%，爆炸范围 +6%"
		"combat_legacy":
			match role_id:
				"swordsman":
					return "退场后给下一位角色吸血增益"
				"gunner":
					return "退场后给下一位角色攻速与移速增益"
				"mage":
					return "退场后给下一位角色额外补 1 枚符印"
		"combat_relay":
			return "接力窗口 +0.45 秒，接力成功额外 +2 符能"
		"combat_support":
			match role_id:
				"swordsman":
					return "后台出手间隔 -8%"
				"gunner":
					return "援护 +1，后台枪手支援目标数增加"
				"mage":
					return "援护 +1，后台术师追加副爆点"
		"combat_resonance":
			return "切人后触发共鸣增伤，切人冷却 -0.18 秒"
		"combat_symbol":
			var extra_text := "，2 级起额外补 1 枚符印" if next_level >= 2 else ""
			var symbol_energy_text := str(snappedf(4.0 + next_level * 1.8, 0.1))
			return "切人立刻回复 " + symbol_energy_text + " 符能" + extra_text
		"combat_fixed_axis":
			return "禁用主动切人，站场伤害 +16%，后台出手间隔 -14%"
		"skill_energy_loop":
			return "符能获取 +12%"
		"skill_tuning":
			return "大招消耗 -6%，立刻回复 12 符能"
		"skill_blossom":
			match role_id:
				"swordsman":
					return "追斩 +1，大招斩击段数增加"
				"gunner":
					return "弹幕 +1，大招波次数 +2"
				"mage":
					return "风暴 +1，大招轰炸次数 +2"
		"skill_reprise":
			match role_id:
				"swordsman":
					return "大招结束后再追加 1 轮斩击"
				"gunner":
					return "大招结束后再补 1 轮波形火力"
				"mage":
					return "大招结束后再补 1 轮追踪轰炸"
		"skill_afterglow":
			var afterglow_time_text := str(snappedf(2.2 + next_level * 0.35, 0.01))
			var afterglow_damage_text := str(int(round(12.0 + next_level * 5.0)))
			return "释放大招后进入余辉 " + afterglow_time_text + " 秒，伤害 +" + afterglow_damage_text + "%"
		"skill_charge":
			return "符能上限 +10，并立刻回复 15 符能"
		"skill_resonance":
			return "后台出手间隔 -5%，切人冷却 -0.25 秒，补 1 枚符印"
		"skill_overdrive":
			return "立刻获得 22 符能和 1 枚符印"
		_:
			return _get_option_preview_description(card_id)
	return ""
func _get_card_common_detail_lines(card_id: String) -> Array:
	var next_level := _get_card_level(card_id) + 1
	match card_id:
		"battle_cover":
			return ["全队伤害 +1.5", "技能系数 +0.04"]
		"battle_tempo":
			return ["全队攻击间隔 -0.04 秒"]
		"battle_split":
			return ["全队伤害 +1.2", "攻击范围 +4", "技能系数 +0.06"]
		"battle_devour":
			return ["最大生命 +8，并立刻回复 10 生命", "立刻回复 8 符能"]
		"battle_suppress":
			return ["全队伤害 +1.0", "攻击范围 +6", "受到的伤害 -3%"]
		"battle_hunt":
			return ["全队伤害 +2.4", "攻击范围 +6", "对精英和 Boss 伤害 +14%", "对 45% 血量以下目标伤害 +10%"]
		"battle_focus":
			return ["全队伤害 +3.4", "攻击间隔 -0.02 秒", "攻击范围 +8", "技能系数 +0.10"]
		"battle_overload":
			return ["强化攻击额外伤害 +18%", "之后每层再追加 +8% 强化伤害"]
		"combat_tuning":
			return ["切人基础冷却 -0.45 秒", "并立刻返还 1.0 秒当前冷却"]
		"combat_assault":
			return ["进场技伤害 +16%", "位移距离或爆炸范围 +6%", "全队伤害 +1.4，范围 +4，技能系数 +0.08"]
		"combat_legacy":
			return ["退场馈赠数值增强", "最大生命 +6，并立刻回复 8 生命"]
		"combat_relay":
			return ["接力窗口 +0.45 秒", "接力成功额外 +2 符能", "并额外返还 0.35 秒切人冷却"]
		"combat_support":
			return ["后台出手间隔 -8%"]
		"combat_resonance":
			return ["切人后额外获得共鸣增伤", "切人基础冷却 -0.18 秒", "全队伤害 +1.2，范围 +3，技能系数 +0.06"]
		"combat_symbol":
			var symbol_energy_text := str(snappedf(4.0 + next_level * 1.8, 0.1))
			var lines := ["每次切人立刻获得 " + symbol_energy_text + " 符能"]
			if next_level >= 2:
				lines.append("额外获得 1 枚符印")
			return lines
		"combat_fixed_axis":
			return ["禁用 Q / E 主动切人", "站场角色伤害 +16%", "后台出手间隔 -14%"]
		"skill_energy_loop":
			return ["符能获取 +12%"]
		"skill_tuning":
			return ["大招消耗 -6%", "立刻回复 12 符能"]
		"skill_blossom":
			return ["立刻回复 8 符能"]
		"skill_reprise":
			return ["大招结束后追加 1 次再演", "再演范围或弹量会随再演等级提高"]
		"skill_afterglow":
			var afterglow_time_text := str(snappedf(2.2 + next_level * 0.35, 0.01))
			var afterglow_damage_text := str(int(round(12.0 + next_level * 5.0)))
			return ["释放大招后进入余辉 " + afterglow_time_text + " 秒", "余辉期间伤害 +" + afterglow_damage_text + "% ，攻击间隔缩短"]
		"skill_charge":
			return ["符能上限 +10", "立刻回复 15 符能"]
		"skill_resonance":
			return ["后台出手间隔 -5%", "切人基础冷却 -0.25 秒", "立刻获得 1 枚符印"]
		"skill_overdrive":
			return ["立刻获得 22 符能", "立刻获得 1 枚符印"]
		_:
			return []
func _get_extra_card_common_detail_lines(card_id: String) -> Array:
	match card_id:
		"battle_chain":
			return ["首次命中后追加连锁追击", "1 级追击 45% 伤害，2 级可再弹 1 次", "3 级每次触发返还 2 点符能"]
		"battle_break":
			return ["连续命中同一目标会叠破甲", "每层对该目标增伤 6% / 7% / 8%", "满层后伤害继续提高，3 级会追加一次补刀"]
		"battle_tide":
			return ["同次攻击命中 2 个以上敌人时追加波纹", "波纹半径 32 / 40 / 48", "2 级附带减速，3 级返还 6 点符能"]
		"battle_aftershock":
			return ["普通攻击终点追加余震", "余震伤害 35% / 45% / 55%", "2 级会多跳 1 次，3 级附带减速"]
		"combat_swap":
			return ["切人后获得短暂无敌和位移", "回复 3 / 5 / 7 点符能", "高等级返还切人冷却并补 1 层符印"]
		"combat_rotation":
			return ["后台待机越久，重新登场越强", "每待机 2.5 秒，下次登场获得额外爆发", "2 / 3 级再补符能与符印"]
		"combat_synergy":
			return ["三名角色都登场过后触发协同爆发", "全队伤害与移速提高", "高等级再压低后台出手间隔并返冷却"]
		"combat_rearguard":
			return ["退场角色会在原地补一次掩护攻击", "1 级 1 次，2 / 3 级 2 次", "3 级新上场角色额外获得 2 秒减伤"]
		"skill_extend":
			return ["大招持续时间和总次数 +12% / 24% / 36%", "2 级起释放大招期间受伤 -10%", "3 级大招结束返还 10 点符能"]
		"skill_finale":
			return ["强化大招最后一段收尾", "最终一击伤害 +45% / 60% / 75%", "最终一击范围 +20%"]
		"skill_borrow_fire":
			return ["释放大招期间普通攻击更强更快", "2 级起后台援护间隔 -10%", "3 级释放大招瞬间返还 8 点符能"]
		"skill_reflux":
			return ["大招结束返还 18 / 24 / 30 点符能", "返还 0.6 / 0.9 / 1.2 秒切人冷却", "2 级起再补符印，3 级后台节奏继续提快"]
		_:
			return []
func _get_card_glossary_terms(card_id: String) -> Array:
	match card_id:
		"battle_cover":
			return ["回旋", "散射", "冰纹"]
		"battle_split":
			return ["回旋", "散射", "回响"]
		"battle_devour":
			return ["战线", "续行", "流转"]
		"battle_suppress":
			return ["守势", "锁定", "冰纹"]
		"battle_hunt":
			return ["穿锋", "聚焦", "塌缩"]
		"combat_support":
			return ["援护"]
		"skill_blossom":
			return ["追斩", "弹幕", "风暴"]
		_:
			return []
func _get_glossary_entries_for_terms(terms: Array) -> Array:
	var entries: Array = []
	for term in terms:
		var entry := _make_glossary_entry(str(term))
		if not entry.is_empty():
			entries.append(entry)
	return entries

func _make_glossary_entry(term: String) -> Dictionary:
	match term:
		"回旋":
			return {"term": "回旋", "title": "回旋", "description": "剑士的普通攻击会变成更宽的月牙斩，并在挥砍后追加扫尾。", "per_level": "1 级提高斩击覆盖；2 级起追加扫尾月牙；后续等级继续增加范围、宽度和伤害。"}
		"穿锋":
			return {"term": "穿锋", "title": "穿锋", "description": "剑士正前方的近身斩击会更狠，适合贴脸处理硬目标。", "per_level": "1 级提高正面伤害并附带易伤；2 级起追加一次突刺斩；后续等级增加突进距离和收尾伤害。"}
		"追斩":
			return {"term": "追斩", "title": "追斩", "description": "剑士大招结束前会继续追加斩击，让终结段更完整。", "per_level": "每级增加剑士大招的追击段数，并提高冲刺长度和最后一段伤害。"}
		"战线":
			return {"term": "战线", "title": "战线", "description": "剑士的普通攻击附带吸血，越敢贴身越能续命。", "per_level": "1 级命中即可吸血；2 级起多目标命中时额外回复；后续等级继续增加回复量。"}
		"守势":
			return {"term": "守势", "title": "守势", "description": "剑士连续出手时会获得短暂无敌，并把近身敌人震开。", "per_level": "1 级获得短暂无敌；2 级起附带反震；后续等级提高反震范围和伤害。"}
		"散射":
			return {"term": "散射", "title": "散射", "description": "枪手会在主弹两侧补出散弹，远距离覆盖更稳。", "per_level": "1 级增加两侧散弹；2 级起追加斜角补弹；后续等级提高散射角度和补弹伤害。"}
		"聚焦":
			return {"term": "聚焦", "title": "聚焦", "description": "枪手把火力压成更扎实的主弹，适合远距离点杀强敌。", "per_level": "1 级提高主弹速度、穿透和易伤；2 级起追加一条穿线狙击；后续等级提高射程和狙击伤害。"}
		"援护":
			return {"term": "援护", "title": "援护", "description": "后台角色会自动协助当前站场角色，补上额外输出。", "per_level": "每级减少后台援护间隔；枪手增加援护目标数；术师增加副爆点数量。"}
		"弹幕":
			return {"term": "弹幕", "title": "弹幕", "description": "枪手大招会打出更多波次和更多子弹，形成更密的覆盖。", "per_level": "每级提高枪手大招波次数量，并增加子弹密度、持续时间和命中半径。"}
		"续行":
			return {"term": "续行", "title": "续行", "description": "枪手通过命中和击杀回能，维持稳定的远程压制。", "per_level": "每级提高命中回能和击杀回能数值。"}
		"锁定":
			return {"term": "锁定", "title": "锁定", "description": "枪手远距离命中会叠加锁定，叠满后自动补一轮追击。", "per_level": "1 级远距离命中叠锁定和易伤；2 级起锁定爆点带小范围溅射；后续等级减少触发所需层数并提高追击伤害。"}
		"回响":
			return {"term": "回响", "title": "回响", "description": "术师主爆点落下后，附近还会补出一次小型爆炸。", "per_level": "1 级爆炸后追加回响爆；2 级起后台副爆也能触发回响；后续等级提高回响半径和伤害。"}
		"冰纹":
			return {"term": "冰纹", "title": "冰纹", "description": "术师的爆炸会减速敌人，并把区域变成更安全的控场区。", "per_level": "1 级爆炸附带减速和易伤；2 级起落点生成持续冰域；后续等级延长减速时间并扩大冰域半径。"}
		"风暴":
			return {"term": "风暴", "title": "风暴", "description": "术师大招会追加更多轰炸轮次，形成持续范围压制。", "per_level": "每级增加术师大招轰炸轮数，并提高主爆半径与持续时间。"}
		"流转":
			return {"term": "流转", "title": "流转", "description": "术师命中和击杀会额外回能，同时把敌人往爆点牵引。", "per_level": "每级提高命中回能、击杀回能和爆点牵引力度。"}
		"塌缩":
			return {"term": "塌缩", "title": "塌缩", "description": "术师在爆炸前先把敌人往中心拉，再一起炸掉。", "per_level": "1 级爆炸前拉扯附近敌人；2 级起追加一次余震；后续等级扩大吸附范围和中心伤害。"}
		_:
			return {}
func _get_option_preview_description(option_id: String) -> String:
	match option_id:
		"battle_cover":
			return "\u589E\u52A0\u666E\u653B\u8986\u76D6"
		"battle_tempo":
			return "\u63D0\u9AD8\u51FA\u624B\u8282\u594F"
		"battle_split":
			return "\u8FFD\u52A0\u989D\u5916\u51FA\u624B"
		"battle_devour":
			return "\u8F93\u51FA\u540C\u65F6\u7EED\u822A"
		"battle_suppress":
			return "\u9644\u52A0\u538B\u5236\u6548\u679C"
		"battle_hunt":
			return "\u66F4\u64C5\u957F\u72E9\u730E\u5F3A\u654C"
		"battle_focus":
			return "\u7A33\u5B9A\u63D0\u5347\u57FA\u7840\u5F3A\u5EA6"
		"battle_overload":
			return "\u5468\u671F\u89E6\u53D1\u5F3A\u5316\u653B\u51FB"
		"battle_chain":
			return "\u547D\u4E2D\u540E\u81EA\u52A8\u8FFD\u51FB"
		"battle_break":
			return "\u8FDE\u7EED\u547D\u4E2D\u53E0\u7834\u7532"
		"battle_tide":
			return "\u602A\u7FA4\u547D\u4E2D\u8FFD\u52A0\u6CE2\u7EB9"
		"battle_aftershock":
			return "\u666E\u653B\u7EC8\u70B9\u7559\u4E0B\u4F59\u9707"
		"combat_tuning":
			return "\u51CF\u5C11\u5207\u4EBA\u51B7\u5374"
		"combat_assault":
			return "\u5F3A\u5316\u8FDB\u573A\u6280"
		"combat_legacy":
			return "\u5F3A\u5316\u9000\u573A\u9988\u8D60"
		"combat_relay":
			return "\u6269\u5927\u63A5\u529B\u6536\u76CA"
		"combat_support":
			return "\u63D0\u9AD8\u540E\u53F0\u63F4\u62A4"
		"combat_resonance":
			return "\u5207\u4EBA\u89E6\u53D1\u5171\u9E23"
		"combat_symbol":
			return "\u5207\u4EBA\u8F6C\u5316\u7B26\u80FD"
		"combat_fixed_axis":
			return "\u6539\u4E3A\u5B9A\u8F74\u7AD9\u573A"
		"combat_swap":
			return "\u5207\u4EBA\u540E\u65E0\u654C\u6ED1\u6B65"
		"combat_rotation":
			return "\u5F85\u673A\u8D8A\u4E45\u8FDB\u573A\u8D8A\u5F3A"
		"combat_synergy":
			return "\u4E09\u4EBA\u8F6E\u8F6C\u89E6\u53D1\u7206\u53D1"
		"combat_rearguard":
			return "\u9000\u573A\u89D2\u8272\u8FFD\u52A0\u63A9\u62A4"
		"skill_energy_loop":
			return "\u63D0\u9AD8\u56DE\u80FD\u6548\u7387"
		"skill_tuning":
			return "\u964D\u4F4E\u5927\u62DB\u6D88\u8017"
		"skill_blossom":
			return "\u5F3A\u5316\u5927\u62DB\u4E3B\u4F53"
		"skill_reprise":
			return "\u5927\u62DB\u540E\u8FFD\u52A0\u518D\u6F14"
		"skill_afterglow":
			return "\u5F00\u5927\u540E\u7559\u4E0B\u4F59\u6CE2"
		"skill_charge":
			return "\u63D0\u9AD8\u7B26\u80FD\u50A8\u5907"
		"skill_resonance":
			return "\u4E32\u8054\u5207\u4EBA\u4E0E\u5927\u62DB"
		"skill_overdrive":
			return "\u7ACB\u5373\u83B7\u5F97\u7206\u53D1\u8D44\u6E90"
		"skill_extend":
			return "\u589E\u52A0\u5927\u62DB\u6301\u7EED\u548C\u6B21\u6570"
		"skill_finale":
			return "\u5F3A\u5316\u5927\u62DB\u6700\u540E\u4E00\u51FB"
		"skill_borrow_fire":
			return "\u5F00\u5927\u65F6\u5E26\u5F3A\u666E\u653B\u4E0E\u63F4\u62A4"
		"skill_reflux":
			return "\u5927\u62DB\u7ED3\u675F\u540E\u56DE\u80FD\u63D0\u8282\u594F"
		_:
			return ""

func _describe_battle_card(card_id: String) -> String:
	var next_level := _get_card_level(card_id) + 1
	match card_id:
		"battle_dangzhen_qichao":
			return "本层：起潮会为三名角色追加一段独立伤害，不再按本次普通攻击伤害百分比结算。"
		"battle_dangzhen_dielang":
			return "本层：起潮触发后，剑士和枪手会在当前特效结束后立刻补发，术师会在第一道波结束后立刻补发同方向的后续波。"
		"battle_dangzhen_huichao":
			return "本层：回潮会改变三名角色的追加攻击方向，并让这些方向全部继承叠浪。"
		"battle_cover":
			return "\u672C\u5C42\uff1A\u5168\u961F\u4F24\u5BB3 +1.5\uff0c\u5C04\u7A0B/\u8303\u56F4 +10\uff0c\u5251\u58EB\u56DE\u626B+\uFF11\uff0c\u67AA\u624B\u6563\u5C04+\uFF11\uff0c\u672F\u5E08\u51B0\u57DF+\uFF11\u3002"
		"battle_tempo":
			return "\u672C\u5C42\uff1A\u5168\u961F\u653B\u51FB\u95F4\u9694 -0.04 \u79D2\uff0c\u666E\u653B\u8282\u594F\u66F4\u5FEB\u3002"
		"battle_split":
			return "\u672C\u5C42\uff1A\u5168\u961F\u4F24\u5BB3 +1.2\uff0c\u8303\u56F4 +4\uff0c\u5251\u58EB\u56DE\u626B+\uFF11\uff0c\u67AA\u624B\u6563\u5F39+\uFF11\uff0c\u672F\u5E08\u56DE\u54CD+\uFF11\u3002"
		"battle_devour":
			return "\u672C\u5C42\uff1A\u5251\u58EB\u5438\u8840+\uFF11\uff0c\u67AA\u624B\u88C5\u586B+\uFF11\uff0c\u672F\u5E08\u6D41\u8F6C+\uFF11\uff0c\u6700\u5927\u751F\u547D +8\uff0c\u56DE\u590D 10\uff0c\u7B26\u80FD +8\u3002"
		"battle_suppress":
			return "\u672C\u5C42\uff1A\u5168\u961F\u4F24\u5BB3 +1.0\uff0c\u8303\u56F4 +6\uff0c\u6280\u80FD\u7CFB\u6570 +0.08\uff0c\u53D7\u4F24\u500D\u7387 -3%\uff0c\u5251\u58EB\u5B88\u52BF+\uFF11\uff0c\u67AA\u624B\u9501\u5B9A+\uFF11\uff0c\u672F\u5E08\u51B0\u57DF+\uFF11\u3002"
		"battle_hunt":
			return "\u672C\u5C42\uff1A\u5168\u961F\u4F24\u5BB3 +2.4\uff0c\u8303\u56F4 +6\uff0c\u6280\u80FD\u7CFB\u6570 +0.08\uff0c\u5BF9\u7CBE\u82F1/Boss \u4F24\u5BB3 +14%\uff0c\u5BF9 45% \u8840\u4EE5\u4E0B\u76EE\u6807\u4F24\u5BB3 +10%\u3002"
		"battle_focus":
			return "\u672C\u5C42\uff1A\u5168\u961F\u4F24\u5BB3 +3.4\uff0c\u653B\u51FB\u95F4\u9694 -0.02 \u79D2\uff0c\u8303\u56F4 +8\uff0c\u6280\u80FD\u7CFB\u6570 +0.10\u3002"
		"battle_overload":
			var trigger_text := "\u6BCF 3 \u6B21\u666E\u653B" if next_level < 2 else "\u6BCF 3/4 \u6B21\u666E\u653B"
			return "\u672C\u5C42\uff1A" + trigger_text + " \u89E6\u53D1 1 \u6B21\u5F3A\u5316\u51FA\u624B\uff0c\u9644\u52A0\u4F24\u5BB3 +18%\uFF0C\u5F3A\u5316\u7B49\u7EA7\u6BCF\u5C42\u518D +8%\u3002"
		"battle_chain":
			return "\u672C\u5C42\uff1A\u547D\u4E2D\u540E\u8FFD\u52A0 1 \u6B21 45% \u4F24\u5BB3\u7684\u8FDE\u9501\u8FFD\u51FB\uff0c2 \u7EA7\u8D77\u53EF\u518D\u5F39 1 \u6B21\uff0C3 \u7EA7\u6BCF\u6B21\u89E6\u53D1\u518D\u56DE 2 \u70B9\u7B26\u80FD\u3002"
		"battle_break":
			return "\u672C\u5C42\uff1A\u8FDE\u7EED\u547D\u4E2D\u540C\u4E00\u76EE\u6807\u4F1A\u53E0\u7834\u7532\uff0c\u6BCF\u5C42\u5BF9\u5176\u589E\u4F24 6%/7%/8%\uFF0C\u6EE1\u5C42\u540E\u4F24\u5BB3\u66F4\u9AD8\u3002"
		"battle_tide":
			return "\u672C\u5C42\uff1A\u540C\u4E00\u6B21\u653B\u51FB\u547D\u4E2D 2 \u4E2A\u53CA\u4EE5\u4E0A\u654C\u4EBA\u65F6\uff0c\u8FFD\u52A0\u4E00\u6B21\u6CE2\u7EB9\u6269\u6563\uff0C2 \u7EA7\u8D77\u9644\u5E26\u51CF\u901F\uff0C3 \u7EA7\u6CE2\u7EB9\u8FD4 6 \u70B9\u7B26\u80FD\u3002"
		"battle_aftershock":
			return "\u672C\u5C42\uff1A\u666E\u901A\u653B\u51FB\u7ED3\u675F\u540E\u4F1A\u5728\u7EC8\u70B9\u7559\u4E0B\u4F59\u9707\uff0C\u5F53\u524D\u4F59\u9707\u4F24\u5BB3 35%/45%/55%\uFF0C\u9AD8\u7EA7\u4F1A\u591A\u8DF3 1 \u6B21\u5E76\u9644\u5E26\u51CF\u901F\u3002"
		_:
			return ""

func _describe_combat_card(card_id: String) -> String:
	var next_level := _get_card_level(card_id) + 1
	match card_id:
		"combat_tuning":
			return "\u672C\u5C42\uff1A\u5207\u4EBA\u51B7\u5374\u57FA\u51C6 -0.45 \u79D2\uff0c\u7ACB\u5373\u8FD4\u8FD8 1.0 \u79D2\u5F53\u524D\u51B7\u5374\u3002"
		"combat_assault":
			return "\u672C\u5C42\uff1A\u8FDB\u573A\u6280\u4F24\u5BB3 +16%\uFF0C\u4F4D\u79FB/\u7206\u70B8\u8303\u56F4 +6%\uFF0C\u8FDB\u573A\u6210\u529F\u540E\u7684\u80FD\u91CF\u4E0E\u51B7\u5374\u8FD4\u5229\u66F4\u9AD8\u3002"
		"combat_legacy":
			return "\u672C\u5C42\uff1A\u9000\u573A\u9988\u8D60\u589E\u5F3A\uff0C\u53E6\u5916\u6700\u5927\u751F\u547D +6\uff0c\u56DE\u590D 8\uff0c\u5251\u58EB\u5438\u8840 +3%\u3001\u67AA\u624B\u52A0\u901F +2%\u3001\u672F\u5E08\u591A\u4F20 1 \u7B26\u5370\u3002"
		"combat_relay":
			return "\u672C\u5C42\uff1A\u63A5\u529B\u7A97\u53E3 +0.45 \u79D2\uff0c\u63A5\u529B\u6210\u529F\u540E\u989D\u5916\u83B7\u5F97 +2 \u80FD\u91CF\uff0c\u51B7\u5374\u989D\u5916\u8FD4\u8FD8 0.35 \u79D2\u3002"
		"combat_support":
			return "\u672C\u5C42\uff1A\u540E\u53F0\u51FA\u624B\u95F4\u9694 -8%\uFF0C\u67AA\u624B\u63F4\u62A4+\uFF11\uff0c\u672F\u5E08\u63F4\u62A4+\uFF11\u3002"
		"combat_resonance":
			return "\u672C\u5C42\uff1A\u5168\u5C40\u4F24\u5BB3 +4%\uFF0C\u5207\u4EBA\u57FA\u51C6\u51B7\u5374 -0.18 \u79D2\uff0c\u5168\u961F\u4F24\u5BB3 +1.2\uff0c\u8303\u56F4 +3\uff0c\u6280\u80FD\u7CFB\u6570 +0.06\u3002"
		"combat_symbol":
			var extra_text := "\uFF0C\u5E76\u989D\u5916\u83B7\u5F97 1 \u7B26\u5370" if next_level >= 2 else ""
			var symbol_energy_text := str(snappedf(4.0 + next_level * 1.8, 0.1))
			return "\u672C\u5C42\uff1A\u6BCF\u6B21\u5207\u4EBA\u7ACB\u5373\u83B7\u5F97 " + symbol_energy_text + " \u7B26\u80FD" + extra_text + "\u3002"
		"combat_fixed_axis":
			return "\u5355\u6B21\u552F\u4E00\uff1A\u7981\u7528 Q/E \u4E3B\u52A8\u5207\u4EBA\uff0c\u7AD9\u573A\u89D2\u8272\u4F24\u5BB3 +16%\uFF0C\u540E\u53F0\u51FA\u624B\u95F4\u9694 -14%\u3002"
		"combat_swap":
			return "\u672C\u5C42\uff1A\u5207\u4EBA\u540E\u83B7\u5F97 0.35/0.45/0.55 \u79D2\u65E0\u654C\u5E76\u5411\u524D\u6ED1\u6B65 50/70/90\uff0C\u540C\u65F6\u56DE\u590D 3/5/7 \u70B9\u7B26\u80FD\uff0C\u9AD8\u7EA7\u8FD4\u51B7\u5374\u548C\u8865\u7B26\u5370\u3002"
		"combat_rotation":
			return "\u672C\u5C42\uff1A\u89D2\u8272\u6BCF\u5F85\u673A 2.5 \u79D2\uff0C\u4E0B\u6B21\u767B\u573A\u7684\u77ED\u65F6\u4F24\u5BB3\u4E0E\u653B\u901F\u589E\u76CA\u66F4\u9AD8\uff0C2/3 \u7EA7\u518D\u8FFD\u52A0\u56DE\u80FD\u548C\u7B26\u5370\u3002"
		"combat_synergy":
			return "\u672C\u5C42\uff1A\u4E09\u540D\u89D2\u8272\u90FD\u81F3\u5C11\u767B\u573A 1 \u6B21\u540E\uff0C\u5168\u961F\u8FDB\u5165 6/8/10 \u79D2\u534F\u540C\u7206\u53D1\uff0C\u83B7\u5F97\u4F24\u5BB3\u4E0E\u79FB\u901F\u52A0\u6210\u3002"
		"combat_rearguard":
			return "\u672C\u5C42\uff1A\u9000\u573A\u89D2\u8272\u4F1A\u5728\u539F\u5730\u8FFD\u52A0 1/2 \u6B21\u63A9\u62A4\u653B\u51FB\uff0C\u4F24\u5BB3\u4E3A 40%/45%/55%\uFF0C3 \u7EA7\u65B0\u4E0A\u573A\u89D2\u8272\u518D\u83B7\u5F97 2 \u79D2 8% \u51CF\u4F24\u3002"
		_:
			return ""

func _describe_skill_card(card_id: String) -> String:
	var next_level := _get_card_level(card_id) + 1
	match card_id:
		"skill_energy_loop":
			return "\u672C\u5C42\uff1A\u7B26\u80FD\u83B7\u53D6 +12%\u3002"
		"skill_tuning":
			return "\u672C\u5C42\uff1A\u5927\u62DB\u6D88\u8017 -6%\uFF0C\u7ACB\u5373\u56DE\u590D 12 \u70B9\u7B26\u80FD\u3002"
		"skill_blossom":
			return "\u672C\u5C42\uff1A\u5251\u58EB\u8FFD\u65A9+\uFF11\uff0c\u67AA\u624B\u5F39\u94FE+\uFF11\uff0c\u672F\u5E08\u98CE\u66B4+\uFF11\uff0C\u5E76\u7ACB\u5373\u56DE\u590D 8 \u70B9\u7B26\u80FD\u3002"
		"skill_reprise":
			return "\u672C\u5C42\uff1A\u5927\u62DB\u7ED3\u675F\u540E\u8FFD\u52A0 1 \u6B21\u518D\u6F14\uff0c\u518D\u6F14\u8303\u56F4/\u5F39\u91CF\u4F1A\u968F\u7B49\u7EA7\u63D0\u9AD8\u3002"
		"skill_afterglow":
			var afterglow_time_text := str(snappedf(2.2 + next_level * 0.35, 0.01))
			var afterglow_damage_text := str(int(round(12.0 + next_level * 5.0)))
			return "\u672C\u5C42\uff1A\u5F00\u5927\u540E\u83B7\u5F97 " + afterglow_time_text + " \u79D2\u4F59\u8F89\uff0c\u4F24\u5BB3 +" + afterglow_damage_text + "%\uFF0C\u653B\u901F\u63D0\u9AD8\u3002"
		"skill_charge":
			return "\u672C\u5C42\uff1A\u7B26\u80FD\u4E0A\u9650 +10\uff0c\u7ACB\u5373\u56DE\u590D 15 \u70B9\u7B26\u80FD\u3002"
		"skill_resonance":
			return "\u672C\u5C42\uff1A\u540E\u53F0\u51FA\u624B\u95F4\u9694 -5%\uFF0C\u5207\u4EBA\u57FA\u51C6\u51B7\u5374 -0.25 \u79D2\uff0c\u7ACB\u5373\u83B7\u5F97 1 \u7B26\u5370\u3002"
		"skill_overdrive":
			return "\u672C\u5C42\uff1A\u7ACB\u5373\u83B7\u5F97 22 \u70B9\u7B26\u80FD\u548C 1 \u7B26\u5370\u3002"
		"skill_extend":
			return "\u672C\u5C42\uff1A\u5927\u62DB\u6301\u7EED\u65F6\u95F4\u4E0E\u603B\u6BB5\u6570 +12%\uFF0C2 \u7EA7\u8D77\u5F00\u5927\u671F\u95F4\u53D7\u4F24 -10%\uFF0C3 \u7EA7\u5927\u62DB\u7ED3\u675F\u540E\u56DE 10 \u70B9\u7B26\u80FD\u3002"
		"skill_finale":
			return "\u672C\u5C42\uff1A\u5F3A\u5316\u5927\u62DB\u6700\u540E\u4E00\u6BB5\u6536\u5C3E\uff0C\u6700\u7EC8\u4E00\u51FB\u4F24\u5BB3 +45%/60%/75%\uFF0C\u8303\u56F4 +20%\u3002"
		"skill_borrow_fire":
			return "\u672C\u5C42\uff1A\u5F00\u5927\u671F\u95F4\u666E\u653B\u4F24\u5BB3 +18%/24%/30%\u3001\u653B\u901F\u63D0\u9AD8\uff0C2 \u7EA7\u8D77\u540E\u53F0\u63F4\u62A4\u4E5F\u4F1A\u66F4\u5FEB\uff0C3 \u7EA7\u5F00\u5927\u7ACB\u5373\u56DE 8 \u70B9\u7B26\u80FD\u3002"
		"skill_reflux":
			return "\u672C\u5C42\uff1A\u5927\u62DB\u7ED3\u675F\u540E\u8FD4\u8FD8 18/24/30 \u70B9\u7B26\u80FD\u4E0E 0.6/0.9/1.2 \u79D2\u5207\u4EBA\u51B7\u5374\uff0C2 \u7EA7\u8D77\u518D\u8865 1 \u7B26\u5370\u3002"
		_:
			return ""

func _apply_team_role_bonus(damage_bonus: float, interval_bonus: float, range_bonus: float, skill_bonus: float) -> void:
	for role_data in roles:
		var role_id := str(role_data["id"])
		var upgrade_data: Dictionary = role_upgrade_levels.get(role_id, {}).duplicate(true)
		upgrade_data["damage_bonus"] = float(upgrade_data.get("damage_bonus", 0.0)) + damage_bonus
		upgrade_data["interval_bonus"] = float(upgrade_data.get("interval_bonus", 0.0)) + interval_bonus
		upgrade_data["range_bonus"] = float(upgrade_data.get("range_bonus", 0.0)) + range_bonus
		upgrade_data["skill_bonus"] = float(upgrade_data.get("skill_bonus", 0.0)) + skill_bonus
		role_upgrade_levels[role_id] = upgrade_data

func _increase_role_special(role_id: String, key: String, amount: int = 1) -> void:
	var special_data: Dictionary = _get_role_special_state(role_id)
	special_data[key] = int(special_data.get(key, 0)) + amount
	role_special_states[role_id] = special_data

func _increase_team_specials(entries: Array) -> void:
	for entry in entries:
		if entry is Dictionary:
			_increase_role_special(str(entry.get("role_id", "")), str(entry.get("key", "")), int(entry.get("amount", 1)))

func _get_active_interval_bonus(role_id: String) -> float:
	var interval_bonus: float = float(role_upgrade_levels.get(role_id, {}).get("interval_bonus", 0.0)) + _get_story_style_interval_bonus(role_id)
	if switch_power_remaining > 0.0 and switch_power_role_id == role_id:
		interval_bonus += switch_power_interval_bonus
	if entry_blessing_remaining > 0.0 and entry_blessing_role_id == role_id:
		interval_bonus += entry_haste_interval_bonus
	if standby_entry_remaining > 0.0 and standby_entry_role_id == role_id:
		interval_bonus += standby_entry_interval_bonus
	if borrow_fire_remaining > 0.0 and borrow_fire_role_id == role_id:
		interval_bonus += borrow_fire_interval_bonus
	if frenzy_remaining > 0.0 and frenzy_stacks > 0:
		interval_bonus += 0.012 * frenzy_stacks
	return interval_bonus

func _get_effective_background_interval_multiplier() -> float:
	var multiplier := background_interval_multiplier
	if team_combo_remaining > 0.0:
		multiplier *= team_combo_background_multiplier
	if borrow_fire_remaining > 0.0:
		multiplier *= borrow_fire_background_multiplier
	if post_ultimate_flow_remaining > 0.0:
		multiplier *= post_ultimate_flow_background_multiplier
	return max(0.32, multiplier)

func _clear_standby_entry_buff() -> void:
	standby_entry_role_id = ""
	standby_entry_label = ""
	standby_entry_remaining = 0.0
	standby_entry_damage_multiplier = 1.0
	standby_entry_interval_bonus = 0.0
	_update_fire_timer()

func _activate_team_combo(duration: float, damage_multiplier: float, move_multiplier: float, background_multiplier: float) -> void:
	team_combo_remaining = duration
	team_combo_damage_multiplier = damage_multiplier
	team_combo_move_multiplier = move_multiplier
	team_combo_background_multiplier = background_multiplier
	_spawn_combat_tag(global_position + Vector2(0.0, -58.0), "协同爆发", Color(1.0, 0.92, 0.54, 1.0))
	_spawn_ring_effect(global_position, 74.0, Color(1.0, 0.92, 0.54, 0.7), 8.0, 0.22)
	_spawn_ring_effect(global_position, 108.0, Color(1.0, 0.56, 0.34, 0.36), 5.0, 0.24)
	_update_fire_timer()

func _mark_role_cycle(role_id: String) -> void:
	role_cycle_marks[role_id] = true
	var synergy_level := _get_card_level("combat_synergy")
	if synergy_level <= 0:
		return
	for cycle_value in role_cycle_marks.values():
		if not bool(cycle_value):
			return
	var combo_duration: float = 6.0 + float(max(0, synergy_level - 1)) * 2.0
	var combo_background_multiplier: float = 0.9 if synergy_level >= 2 else 1.0
	_activate_team_combo(combo_duration, 1.08, 1.08, combo_background_multiplier)
	if synergy_level >= 3:
		switch_cooldown_remaining = max(0.0, switch_cooldown_remaining - 1.2)
	for marked_role_id in role_cycle_marks.keys():
		role_cycle_marks[marked_role_id] = false
	role_cycle_marks[role_id] = true

func _apply_rotation_entry_bonus(role_id: String) -> void:
	var rotation_level := _get_card_level("combat_rotation")
	if rotation_level <= 0:
		return
	var standby_time: float = float(role_standby_elapsed.get(role_id, 0.0))
	var stacks: int = clamp(int(floor(standby_time / 2.5)), 0, 3)
	if stacks <= 0:
		return
	var damage_step: float = [0.10, 0.14, 0.18][rotation_level - 1]
	var interval_step: float = [0.035, 0.045, 0.055][rotation_level - 1]
	standby_entry_role_id = role_id
	standby_entry_label = "轮转蓄势"
	standby_entry_remaining = [2.5, 3.5, 4.5][rotation_level - 1]
	standby_entry_damage_multiplier = 1.0 + damage_step * stacks
	standby_entry_interval_bonus = interval_step * stacks
	role_standby_elapsed[role_id] = 0.0
	_spawn_combat_tag(global_position + Vector2(0.0, -48.0), "轮转 x%d" % stacks, Color(1.0, 0.86, 0.56, 1.0))
	_spawn_ring_effect(global_position, 54.0 + stacks * 10.0, Color(0.64, 0.92, 1.0, 0.62), 5.0, 0.18)
	if rotation_level >= 2:
		_add_energy(4.0)
	if rotation_level >= 3:
		_grant_ultimate_seals(1, "轮转")
	_update_fire_timer()

func _apply_swap_guard(direction: Vector2) -> void:
	var swap_level := _get_card_level("combat_swap")
	if swap_level <= 0:
		return
	var dash_direction := direction.normalized()
	if dash_direction.length_squared() <= 0.001:
		dash_direction = facing_direction if facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	var dash_distance: float = [50.0, 70.0, 90.0][swap_level - 1]
	var invulnerability: float = [0.35, 0.45, 0.55][swap_level - 1]
	global_position += dash_direction * dash_distance
	switch_invulnerability_remaining = max(switch_invulnerability_remaining, invulnerability)
	_spawn_dash_line_effect(global_position - dash_direction * dash_distance, global_position, Color(1.0, 0.42, 0.34, 0.96), 12.0, 0.12)
	_spawn_ring_effect(global_position, 30.0 + dash_distance * 0.2, Color(1.0, 0.62, 0.38, 0.62), 5.0, 0.14)
	_add_energy([3.0, 5.0, 7.0][swap_level - 1])
	if swap_level >= 2:
		switch_cooldown_remaining = max(0.0, switch_cooldown_remaining - 0.4)
	if swap_level >= 3:
		_grant_ultimate_seals(1, "滑步")

func _activate_guard_cover() -> void:
	guard_cover_remaining = 2.0
	guard_cover_damage_multiplier = 0.92
	_spawn_combat_tag(global_position + Vector2(0.0, -42.0), "掩护就位", Color(0.88, 0.96, 1.0, 1.0))

func _trigger_rearguard_attack(role_id: String, origin: Vector2, level: int) -> int:
	if level <= 0:
		return 0
	var hit_count := 0
	var repeat_count := 1 if level == 1 else 2
	var damage_scale := 0.4 if level == 1 else (0.45 if level == 2 else 0.55)
	var accent := _get_role_theme_color(role_id)
	_spawn_combat_tag(origin + Vector2(0.0, -40.0), "回响", Color(min(1.0, accent.r + 0.18), min(1.0, accent.g + 0.18), min(1.0, accent.b + 0.18), 1.0))
	_spawn_ring_effect(origin, 62.0 + level * 12.0, Color(accent.r, accent.g, accent.b, 0.68), 8.0, 0.24)
	for attack_index in range(repeat_count):
		var delay := 0.18 * attack_index
		var current_scene := get_tree().current_scene
		if current_scene == null:
			continue
		var controller := Node2D.new()
		controller.name = "RearguardController"
		current_scene.add_child(controller)
		var tween := controller.create_tween()
		if delay > 0.0:
			tween.tween_interval(delay)
		tween.tween_callback(func() -> void:
			match role_id:
				"swordsman":
					var direction := facing_direction if facing_direction.length_squared() > 0.001 else Vector2.RIGHT
					var slash_direction := direction.rotated(0.18 if attack_index % 2 == 0 else -0.18)
					_spawn_crescent_wave_effect(origin + direction * 10.0, slash_direction, 110.0 + level * 10.0, Color(0.26, 0.94, 1.0, 0.72), 0.2, 170.0, 28.0 + level * 3.0)
					_spawn_cross_slash_effect(origin, slash_direction, 126.0 + level * 10.0, 24.0 + level * 2.0, Color(1.0, 0.84, 0.48, 0.92), 0.2)
					_spawn_ring_effect(origin + direction * 14.0, 60.0 + level * 8.0, Color(1.0, 0.26, 0.18, 0.48), 6.0, 0.18)
					_damage_enemies_in_radius(origin + direction * 16.0, 64.0 + level * 8.0, _get_role_damage(role_id) * damage_scale, 0.03, 1.0, 0.0)
				"gunner":
					_spawn_radial_rays_effect(origin, 86.0 + level * 10.0, 10 + level * 2, Color(1.0, 0.66, 0.34, 0.7), 4.0 + level, 0.22, attack_index * 0.16)
					for bullet_index in range(6 + level * 2):
						var angle := TAU * float(bullet_index) / float(6 + level * 2) + attack_index * 0.14
						var bullet = _spawn_directional_bullet(Vector2.RIGHT.rotated(angle), _get_role_damage(role_id) * damage_scale, Color(1.0, 0.68, 0.42, 0.92), role_id, origin)
						if bullet != null:
							bullet.speed = 460.0
							bullet.lifetime = 0.7
							bullet.hit_radius = 10.0
							bullet.scale = Vector2(1.18, 1.18)
				"mage":
					_spawn_ring_effect(origin, 62.0 + level * 10.0, Color(0.68, 0.94, 1.0, 0.82), 7.0, 0.22)
					_spawn_frost_sigils_effect(origin, 40.0 + level * 10.0, Color(0.9, 0.98, 1.0, 0.88), 0.22)
					_spawn_vortex_effect(origin, 30.0 + level * 8.0, Color(0.7, 0.78, 1.0, 0.42), 0.22)
					_spawn_burst_effect(origin, 68.0 + level * 12.0, Color(0.52, 0.9, 1.0, 0.28), 0.22)
					_damage_enemies_in_radius(origin, 68.0 + level * 12.0, _get_role_damage(role_id) * damage_scale, 0.02, 0.74, 1.0)
		)
		tween.tween_callback(controller.queue_free)
		hit_count += 1
	return hit_count

func _get_priority_target_bonus(enemy: Node) -> float:
	var hunt_level := _get_card_level("battle_hunt")
	if hunt_level <= 0 or enemy == null or not is_instance_valid(enemy):
		hunt_level = 0

	var multiplier := 1.0
	if enemy != null and is_instance_valid(enemy):
		var enemy_kind := str(enemy.get("enemy_kind"))
		if enemy_kind == "elite" or enemy_kind == "boss":
			multiplier += 0.14 * float(hunt_level)
			if _has_elite_relic("elite_execution_pact"):
				multiplier += 0.14
		var max_hp := float(enemy.get("max_health"))
		if max_hp > 0.0:
			var hp_ratio := float(enemy.get("current_health")) / max_hp
			if hp_ratio <= 0.45:
				multiplier += 0.1 * float(hunt_level)
				if _has_elite_relic("elite_execution_pact"):
					multiplier += 0.08
	return multiplier

func _is_last_stand_active() -> bool:
	if not _has_elite_relic("elite_last_stand"):
		return false
	if max_health <= 0.0:
		return false
	return current_health / max_health <= 0.4

func _get_effective_damage_taken_multiplier() -> float:
	var multiplier := damage_taken_multiplier
	if _is_last_stand_active():
		multiplier *= 0.82
	if guard_cover_remaining > 0.0:
		multiplier *= guard_cover_damage_multiplier
	if ultimate_guard_remaining > 0.0:
		multiplier *= ultimate_guard_damage_multiplier
	return multiplier

func _unhandled_input(event: InputEvent) -> void:
	if is_dead or get_tree().paused:
		return
	if event is not InputEventKey:
		return
	if not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_Q:
			if _get_card_level("combat_fixed_axis") > 0:
				return
			_try_switch_role((active_role_index - 1 + roles.size()) % roles.size())
		KEY_E:
			if _get_card_level("combat_fixed_axis") > 0:
				return
			_try_switch_role((active_role_index + 1) % roles.size())
		KEY_R:
			_try_use_ultimate()

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_update_timers(delta)
	_regenerate_energy(delta)
	_update_facing_direction()
	_update_role_idle_visual(delta)
	_update_background_effects(delta)

	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0

	direction = direction.normalized()
	velocity = direction * _get_current_move_speed()
	move_and_slide()
	gem_collection_elapsed += delta
	if gem_collection_elapsed >= GEM_COLLECTION_INTERVAL:
		gem_collection_elapsed = 0.0
		_collect_nearby_gems()
	contact_check_elapsed += delta
	if contact_check_elapsed >= CONTACT_CHECK_INTERVAL:
		contact_check_elapsed = 0.0
		_check_enemy_contact_damage()

func _update_timers(delta: float) -> void:
	role_visual_time += delta
	if hurt_cooldown_remaining > 0.0:
		hurt_cooldown_remaining = max(0.0, hurt_cooldown_remaining - delta)
	if switch_invulnerability_remaining > 0.0:
		switch_invulnerability_remaining = max(0.0, switch_invulnerability_remaining - delta)
	if level_up_delay_remaining > 0.0:
		level_up_delay_remaining = max(0.0, level_up_delay_remaining - delta)
		if level_up_delay_remaining <= 0.0:
			_try_request_level_up()
	if switch_cooldown_remaining > 0.0:
		switch_cooldown_remaining = max(0.0, switch_cooldown_remaining - delta)
	if perpetual_motion_cooldown_remaining > 0.0:
		perpetual_motion_cooldown_remaining = max(0.0, perpetual_motion_cooldown_remaining - delta)
	if switch_power_remaining > 0.0:
		switch_power_remaining = max(0.0, switch_power_remaining - delta)
		if switch_power_remaining <= 0.0:
			switch_power_role_id = ""
			switch_power_damage_multiplier = 1.0
			switch_power_interval_bonus = 0.0
			switch_power_label = ""
			_update_fire_timer()
	if entry_blessing_remaining > 0.0:
		entry_blessing_remaining = max(0.0, entry_blessing_remaining - delta)
		if entry_blessing_remaining <= 0.0:
			_clear_entry_blessing()
	if standby_entry_remaining > 0.0:
		standby_entry_remaining = max(0.0, standby_entry_remaining - delta)
		if standby_entry_remaining <= 0.0:
			_clear_standby_entry_buff()
	if guard_cover_remaining > 0.0:
		guard_cover_remaining = max(0.0, guard_cover_remaining - delta)
		if guard_cover_remaining <= 0.0:
			guard_cover_damage_multiplier = 1.0
	if team_combo_remaining > 0.0:
		team_combo_remaining = max(0.0, team_combo_remaining - delta)
		if team_combo_remaining <= 0.0:
			team_combo_damage_multiplier = 1.0
			team_combo_move_multiplier = 1.0
			team_combo_background_multiplier = 1.0
	if borrow_fire_remaining > 0.0:
		borrow_fire_remaining = max(0.0, borrow_fire_remaining - delta)
		if borrow_fire_remaining <= 0.0:
			borrow_fire_role_id = ""
			borrow_fire_damage_multiplier = 1.0
			borrow_fire_interval_bonus = 0.0
			borrow_fire_background_multiplier = 1.0
			_update_fire_timer()
	if post_ultimate_flow_remaining > 0.0:
		post_ultimate_flow_remaining = max(0.0, post_ultimate_flow_remaining - delta)
		if post_ultimate_flow_remaining <= 0.0:
			post_ultimate_flow_background_multiplier = 1.0
	if ultimate_guard_remaining > 0.0:
		ultimate_guard_remaining = max(0.0, ultimate_guard_remaining - delta)
		if ultimate_guard_remaining <= 0.0:
			ultimate_guard_damage_multiplier = 1.0
	if frenzy_remaining > 0.0:
		frenzy_remaining = max(0.0, frenzy_remaining - delta)
		if frenzy_remaining <= 0.0:
			frenzy_stacks = 0
			frenzy_overkill_counter = 0
	if relay_window_remaining > 0.0:
		relay_window_remaining = max(0.0, relay_window_remaining - delta)
		if relay_window_remaining <= 0.0:
			relay_ready_role_id = ""
			relay_from_role_id = ""
			relay_label = ""
			relay_bonus_pending = false
	for role_data in roles:
		var role_id := str(role_data.get("id", ""))
		if role_id == str(_get_active_role().get("id", "")):
			role_standby_elapsed[role_id] = 0.0
		else:
			role_standby_elapsed[role_id] = float(role_standby_elapsed.get(role_id, 0.0)) + delta
	_update_camera_shake(delta)

func _regenerate_energy(delta: float) -> void:
	if ENERGY_PASSIVE_REGEN <= 0.0:
		return
	_add_energy(ENERGY_PASSIVE_REGEN * delta)

func _update_facing_direction() -> void:
	var mouse_direction := get_global_mouse_position() - global_position
	if mouse_direction.length_squared() > 16.0:
		facing_direction = mouse_direction.normalized()
		return

	var enemy := _get_closest_enemy()
	if enemy != null:
		facing_direction = global_position.direction_to(enemy.global_position)

func _update_background_effects(delta: float) -> void:
	for role_index in range(roles.size()):
		if role_index == active_role_index:
			continue

		var role_id: String = roles[role_index]["id"]
		background_cooldowns[role_id] = float(background_cooldowns.get(role_id, 0.0)) - delta
		if float(background_cooldowns[role_id]) > 0.0:
			continue

		_trigger_background_effect(role_index)
		background_cooldowns[role_id] = float(roles[role_index]["background_interval"]) * _get_effective_background_interval_multiplier()

func _trigger_background_effect(role_index: int) -> void:
	var role_id: String = roles[role_index]["id"]
	match role_id:
		"swordsman":
			_trigger_swordsman_background()
		"gunner":
			_trigger_gunner_background()
		"mage":
			_trigger_mage_background()

func _perform_active_attack() -> void:
	if is_dead:
		return

	var role_id: String = _get_active_role()["id"]
	match role_id:
		"swordsman":
			_perform_swordsman_attack()
		"gunner":
			_perform_gunner_attack()
		"mage":
			_perform_mage_attack()

func _execute_dangzhen_sword_slash(slash_origin: Vector2, slash_direction: Vector2, attack_damage: float, damage_ratio: float, split_level: int, huichao_level: int, role_id: String) -> int:
	var fan_center := slash_origin + slash_direction * 52.0
	_spawn_sword_fan_scene_effect(fan_center, slash_direction, 0.72 + split_level * 0.07 + huichao_level * 0.05)
	var fan_start := slash_origin + slash_direction * 22.0
	var fan_end := slash_origin + slash_direction * 118.0
	return _damage_enemies_in_line(fan_start, fan_end, 18.0, attack_damage, 0.0, 1.0, 0.0, role_id)

func _trigger_dangzhen_sword_qichao_preview(attack_direction: Vector2, attack_damage: float, role_id: String) -> int:
	var qichao_level := _get_card_level("battle_dangzhen_qichao")
	if qichao_level <= 0:
		return 0
	if swordsman_dangzhen_slash_cooldown_attacks > 0:
		swordsman_dangzhen_slash_cooldown_attacks -= 1
		return 0
	swordsman_dangzhen_slash_cooldown_attacks = 1
	var split_level := _get_card_level("battle_dangzhen_dielang")
	var huichao_level := _get_card_level("battle_dangzhen_huichao")
	var qichao_damage := _get_dangzhen_qichao_damage(role_id, qichao_level)
	var extra_count := split_level
	var primary_directions: Array[Vector2] = [attack_direction.normalized()]
	if huichao_level >= 1:
		primary_directions.append((-attack_direction).normalized())
	var total_hits := 0
	var fan_animation_duration := _get_scene_animation_duration(SWORD_FAN_EFFECT_SCENE, 0.2)
	for slash_direction in primary_directions:
		total_hits += _execute_dangzhen_sword_slash(global_position, slash_direction, qichao_damage, 1.0, split_level, huichao_level, role_id)
		if extra_count <= 0:
			continue
		var current_scene := get_tree().current_scene
		if current_scene == null:
			continue
		var controller := Node2D.new()
		controller.name = "DangzhenSwordFollowController"
		current_scene.add_child(controller)
		var tween := controller.create_tween()
		for extra_index in range(extra_count):
			tween.tween_interval(fan_animation_duration)
			tween.tween_callback(func() -> void:
				if not is_instance_valid(self):
					return
				var follow_hits := _execute_dangzhen_sword_slash(global_position, slash_direction, qichao_damage, 1.0, split_level, huichao_level, role_id)
				if follow_hits > 0:
					_register_attack_result(role_id, follow_hits, false)
			)
		tween.tween_callback(controller.queue_free)
	if huichao_level >= 2:
		var current_scene := get_tree().current_scene
		if current_scene != null:
			var controller := Node2D.new()
			controller.name = "DangzhenSwordCrossController"
			current_scene.add_child(controller)
			var tween := controller.create_tween()
			tween.tween_interval(fan_animation_duration * float(extra_count + 1))
			tween.tween_callback(func() -> void:
				if not is_instance_valid(self):
					return
				var cross_direction := _get_downward_perpendicular(attack_direction).normalized()
				var cross_hits := _execute_dangzhen_sword_slash(global_position, cross_direction, qichao_damage, 1.0, split_level, huichao_level, role_id)
				if cross_hits > 0:
					_register_attack_result(role_id, cross_hits, false)
			)
			for extra_index in range(extra_count):
				tween.tween_interval(fan_animation_duration)
				tween.tween_callback(func() -> void:
					if not is_instance_valid(self):
						return
					var cross_direction := _get_downward_perpendicular(attack_direction).normalized()
					var cross_hits := _execute_dangzhen_sword_slash(global_position, cross_direction, qichao_damage, 1.0, split_level, huichao_level, role_id)
					if cross_hits > 0:
						_register_attack_result(role_id, cross_hits, false)
				)
			tween.tween_callback(controller.queue_free)
	return total_hits

func _execute_dangzhen_gunner_beam(origin: Vector2, fire_direction: Vector2, damage_amount: float, role_id: String) -> int:
	var line_length: float = 168.0
	var line_width: float = 15.0
	_spawn_gunner_intersect_scene_effect(origin, fire_direction, line_length, 34.0)
	return _damage_enemies_in_line(
		origin,
		origin + fire_direction * line_length,
		line_width,
		damage_amount,
		0.0,
		1.0,
		0.0,
		role_id
	)

func _trigger_dangzhen_gunner_qichao_preview(shot_direction: Vector2, attack_damage: float, role_id: String) -> int:
	var qichao_level := _get_card_level("battle_dangzhen_qichao")
	if qichao_level <= 0:
		return 0
	if gunner_attack_chain != 0:
		return 0
	var split_level := _get_card_level("battle_dangzhen_dielang")
	var huichao_level := _get_card_level("battle_dangzhen_huichao")
	var qichao_damage := _get_dangzhen_qichao_damage(role_id, qichao_level)
	var extra_count := split_level
	var primary_directions: Array[Vector2] = [shot_direction.normalized()]
	if huichao_level == 1:
		primary_directions = [
			shot_direction.rotated(deg_to_rad(-15.0)).normalized(),
			shot_direction.rotated(deg_to_rad(15.0)).normalized()
		]
	elif huichao_level >= 2:
		primary_directions = [
			shot_direction.rotated(deg_to_rad(-15.0)).normalized(),
			shot_direction.normalized(),
			shot_direction.rotated(deg_to_rad(15.0)).normalized()
		]
	var total_hits := 0
	var beam_origin := global_position + shot_direction.normalized() * 20.0
	var intersect_animation_duration := _get_scene_animation_duration(GUNNER_INTERSECT_EFFECT_SCENE, 0.18) * 0.8
	for fire_direction in primary_directions:
		total_hits += _execute_dangzhen_gunner_beam(beam_origin, fire_direction, qichao_damage, role_id)
		if extra_count <= 0:
			continue
		var current_scene := get_tree().current_scene
		if current_scene == null:
			continue
		var controller := Node2D.new()
		controller.name = "DangzhenGunnerFollowController"
		current_scene.add_child(controller)
		var tween := controller.create_tween()
		for extra_index in range(extra_count):
			tween.tween_interval(intersect_animation_duration)
			tween.tween_callback(func() -> void:
				if not is_instance_valid(self):
					return
				var follow_hits := _execute_dangzhen_gunner_beam(global_position + fire_direction * 20.0, fire_direction, qichao_damage, role_id)
				if follow_hits > 0:
					_register_attack_result(role_id, follow_hits, false)
			)
		tween.tween_callback(controller.queue_free)
	return total_hits

func _spawn_dangzhen_mage_wave(origin: Vector2, fire_direction: Vector2, damage_amount: float, role_id: String) -> Node2D:
	var wave = _spawn_directional_bullet_from_scene(
		MAGE_WAVE_EFFECT_SCENE,
		fire_direction,
		damage_amount,
		Color(1.0, 0.62, 0.36, 1.0),
		role_id,
		origin + fire_direction * 16.0
	)
	if wave == null:
		return null
	wave.speed = 240.0
	wave.lifetime = 3.84
	wave.hit_radius = 28.0
	wave.pierce_count = 999
	wave.visual_scale_multiplier = 5.2
	wave.enemy_hit_radius_scale = 0.62
	wave.enemy_hit_radius_min = 12.0
	wave.enemy_hit_radius_max = 30.0
	return wave

func _trigger_dangzhen_mage_qichao_preview(wave_direction: Vector2, attack_damage: float, role_id: String) -> void:
	var qichao_level := _get_card_level("battle_dangzhen_qichao")
	if qichao_level <= 0:
		return
	if mage_dangzhen_wave_cooldown_attacks > 0:
		mage_dangzhen_wave_cooldown_attacks -= 1
		return
	mage_dangzhen_wave_cooldown_attacks = 1
	var split_level := _get_card_level("battle_dangzhen_dielang")
	var huichao_level := _get_card_level("battle_dangzhen_huichao")
	var qichao_damage := _get_dangzhen_qichao_damage(role_id, qichao_level)
	var extra_count := split_level
	var angle_offsets: Array[float] = [0.0]
	if huichao_level >= 1:
		angle_offsets.append(-0.36)
		angle_offsets.append(0.36)
	if huichao_level >= 2:
		angle_offsets.append(-0.72)
		angle_offsets.append(0.72)
	for angle_offset in angle_offsets:
		var fire_direction := wave_direction.rotated(angle_offset).normalized()
		var gather_origin := global_position + fire_direction * 18.0
		_spawn_mage_gathering_scene_effect(gather_origin, fire_direction, 1.25)
		var gather_duration := _get_scene_animation_duration(MAGE_GATHERING_EFFECT_SCENE, 0.16)
		var tween := create_tween()
		tween.tween_interval(gather_duration)
		tween.tween_callback(func() -> void:
			_spawn_dangzhen_mage_wave(gather_origin, fire_direction, qichao_damage, role_id)
		)
		for extra_index in range(extra_count):
			tween.tween_interval(3.84)
			tween.tween_callback(func() -> void:
				_spawn_dangzhen_mage_wave(global_position + fire_direction * 18.0, fire_direction, qichao_damage, role_id)
			)

func _perform_swordsman_attack() -> void:
	var role_data: Dictionary = _get_active_role()
	var upgrade_data: Dictionary = role_upgrade_levels[role_data["id"]]
	var special_data: Dictionary = _get_role_special_state("swordsman")
	var mouse_attack_direction: Vector2 = get_global_mouse_position() - global_position
	var attack_direction: Vector2 = facing_direction
	if mouse_attack_direction.length_squared() > 4.0:
		attack_direction = mouse_attack_direction.normalized()
		facing_direction = attack_direction
	var crescent_level: int = int(special_data.get("crescent_level", 0))
	var thrust_level: int = int(special_data.get("thrust_level", 0))
	var blood_level: int = int(special_data.get("blood_level", 0))
	var stance_level: int = int(special_data.get("stance_level", 0))
	var overload_level: int = _get_card_level("battle_overload")
	var disaster_ready: bool = _is_disaster_set_complete()
	var attack_range: float = (float(role_data["range"]) + float(upgrade_data.get("range_bonus", 0.0)) + crescent_level * 6.0 + thrust_level * 4.0) * _get_story_style_range_multiplier(role_data["id"])
	var attack_damage: float = _get_role_damage(role_data["id"]) * 1.5
	var slash_axis: Vector2 = _get_downward_perpendicular(attack_direction)
	var slash_mirror: bool = attack_direction.x > 0.0
	var slash_length: float = (56.0 + float(upgrade_data.get("range_bonus", 0.0)) * 0.19 + crescent_level * 4.0 + thrust_level * 2.0) * _get_story_style_range_multiplier(role_data["id"])
	var slash_width: float = 8.0 + crescent_level * 1.05 + thrust_level * 0.7
	var slash_start: Vector2 = global_position + attack_direction * (18.0 + thrust_level * 3.0)
	var slash_center: Vector2 = global_position + attack_direction * (42.0 + thrust_level * 3.0)
	var slash_end: Vector2 = slash_center + slash_axis * (slash_length * 0.5)
	slash_start = slash_center - slash_axis * (slash_length * 0.5)
	var style_color := Color(0.48, 0.86, 1.0, 0.95) if _get_story_style_id(role_data["id"]) == "moon_edge" else Color(1.0, 0.74, 0.34, 0.95)
	if disaster_ready:
		attack_damage *= 1.1
		slash_length += 10.0
		slash_width += 1.5
		attack_range += 22.0
		slash_center += attack_direction * 4.0
		slash_end = slash_center + slash_axis * (slash_length * 0.5)
		slash_start = slash_center - slash_axis * (slash_length * 0.5)
	var enemies_hit: int = 0
	var any_kill: bool = false
	var overload_ready: bool = overload_level > 0 and swordsman_attack_chain == 2
	if overload_ready:
		attack_damage *= 1.18 + 0.08 * overload_level
		slash_length += 5.0 + overload_level * 3.0
		slash_width += 1.0 + overload_level * 0.6
		slash_end = slash_center + slash_axis * (slash_length * 0.5)
		slash_start = slash_center - slash_axis * (slash_length * 0.5)

	_spawn_sword_slash_scene_effect(
		slash_center,
		slash_axis,
		slash_length * 0.5,
		style_color,
		0.16,
		slash_width,
		slash_mirror
	)
	var slash_hit_registry: Dictionary = {}
	var slash_rect_width: float = slash_width * 2.4
	var slash_animation_duration: float = _get_sword_slash_scene_animation_duration()
	enemies_hit += _damage_enemies_in_oriented_rect_unique(slash_center, slash_axis, slash_length, slash_rect_width, attack_damage, 0.0, 1.0, 0.0, slash_hit_registry, role_data["id"])
	_schedule_swordsman_slash_followthrough(slash_center, slash_axis, slash_length, slash_rect_width, attack_damage, 0.0, 1.0, 0.0, slash_animation_duration, role_data["id"], slash_hit_registry)
	if thrust_level > 0:
		var pierce_start: Vector2 = slash_center + attack_direction * 10.0
		var pierce_end: Vector2 = pierce_start + attack_direction * (34.0 + thrust_level * 12.0)
		enemies_hit += _damage_enemies_in_line(pierce_start, pierce_end, max(8.0, slash_width * 0.34), attack_damage * 0.14 * thrust_level, 0.06 * thrust_level, 1.0, 0.0, role_data["id"])
	if disaster_ready:
		var disaster_color := Color(0.22, 0.96, 1.0, 0.88)
		var disaster_echo_color := Color(1.0, 0.24, 0.18, 0.48)
		var swing_offset := 0.18 if swordsman_attack_chain % 2 == 0 else -0.18
		_spawn_sword_slash_scene_effect(slash_center + attack_direction * 10.0, slash_axis.rotated(swing_offset), slash_length * 0.52, disaster_color, 0.22, slash_width + 6.0, slash_mirror)
		_spawn_sword_slash_scene_effect(slash_center + attack_direction * 6.0, slash_axis.rotated(-swing_offset * 0.65), slash_length * 0.46, disaster_echo_color, 0.2, max(4.0, slash_width * 0.8), slash_mirror)
		_spawn_ring_effect(global_position + attack_direction * 20.0, 34.0 + crescent_level * 4.0, Color(1.0, 0.92, 0.6, 0.74), 7.0, 0.18)

	if crescent_level >= 2:
		var follow_arc_direction := attack_direction.rotated(0.24 if swordsman_attack_chain % 2 == 0 else -0.24)
		_spawn_crescent_wave_effect(global_position + follow_arc_direction * 14.0, follow_arc_direction, attack_range + 28.0, Color(0.36, 0.82, 1.0, 0.92), 0.14, 110.0, 20.0 + crescent_level * 2.0)
		enemies_hit += _damage_enemies_in_line(global_position, global_position + follow_arc_direction * (attack_range + 30.0), 24.0 + crescent_level * 2.0, attack_damage * (0.22 + crescent_level * 0.05), 0.02 * crescent_level, 1.0, 0.0, role_data["id"])

	if thrust_level >= 2:
		var thrust_end := global_position + attack_direction * (attack_range + 38.0 + thrust_level * 12.0)
		var thrust_width: float = 18.0 + thrust_level * 2.0
		_spawn_thrust_effect(global_position + attack_direction * 8.0, thrust_end, Color(1.0, 0.18, 0.1, 0.98), thrust_width, 0.16, false)
		var thrust_hits := _damage_enemies_in_line(global_position, thrust_end, thrust_width, attack_damage * (0.34 + thrust_level * 0.08), 0.06 * thrust_level, 1.0, 0.0, role_data["id"])
		enemies_hit += thrust_hits
	elif disaster_ready:
		var disaster_end := global_position + attack_direction * (attack_range + 58.0)
		var disaster_width: float = 26.0 + crescent_level * 3.0
		_spawn_thrust_effect(global_position + attack_direction * 10.0, disaster_end, Color(0.22, 0.96, 1.0, 0.92), disaster_width, 0.18, false)
		enemies_hit += _damage_enemies_in_line(global_position, disaster_end, disaster_width, attack_damage * 0.3, 0.02, 1.0, 0.0, role_data["id"])

	if blood_level >= 2 and enemies_hit >= 3:
		_heal(1.2 + blood_level * 0.8)
		_spawn_burst_effect(global_position, 34.0 + blood_level * 4.0, Color(1.0, 0.3, 0.28, 0.18), 0.12)

	swordsman_attack_chain = (swordsman_attack_chain + 1) % 3
	if swordsman_attack_chain == 0 and (crescent_level > 0 or thrust_level > 0 or stance_level > 0):
		var core_center := global_position + attack_direction * 26.0
		_spawn_cross_slash_effect(core_center, attack_direction, 88.0, 17.0, Color(1.0, 0.94, 0.62, 0.82), 0.14)
		var chain_hits := _damage_enemies_in_radius(core_center, 44.0 + crescent_level * 5.0, attack_damage * (0.48 + thrust_level * 0.05), 0.04 + thrust_level * 0.02, 1.0, 0.0)
		enemies_hit += chain_hits
		if chain_hits > 0 and blood_level > 0:
			_heal(1.4 + blood_level * 0.6)
		if stance_level > 0:
			_spawn_combat_tag(global_position + Vector2(0.0, -26.0), "\u5B88\u52BF", Color(1.0, 0.88, 0.54, 1.0))
			_spawn_guard_effect(global_position, 46.0 + stance_level * 10.0, Color(1.0, 0.88, 0.5, 0.24), 0.2 + stance_level * 0.03)
			switch_invulnerability_remaining = max(switch_invulnerability_remaining, 0.08 + stance_level * 0.05)
			if chain_hits > 0:
				_heal(0.8 + stance_level * 0.8)
			if stance_level >= 2:
				var guard_hits := _damage_enemies_in_radius(global_position + facing_direction * 14.0, 34.0 + stance_level * 8.0, attack_damage * (0.18 + stance_level * 0.07), 0.0, 1.0, 0.0)
				enemies_hit += guard_hits
				if guard_hits > 0:
					_spawn_burst_effect(global_position + facing_direction * 12.0, 30.0 + stance_level * 7.0, Color(1.0, 0.84, 0.42, 0.18), 0.12)

	enemies_hit += _trigger_dangzhen_sword_qichao_preview(attack_direction, attack_damage, role_data["id"])
	_spawn_attack_aftershock(global_position + facing_direction * max(26.0, attack_range * 0.55), role_data["id"])

	if enemies_hit > 0:
		_register_attack_result(role_data["id"], enemies_hit, any_kill)

func _perform_gunner_attack() -> void:
	var role_data: Dictionary = _get_active_role()
	var upgrade_data: Dictionary = role_upgrade_levels[role_data["id"]]
	var special_data: Dictionary = _get_role_special_state("gunner")
	var scatter_level: int = int(special_data.get("scatter_level", 0))
	var focus_level: int = int(special_data.get("focus_level", 0))
	var lock_level: int = int(special_data.get("lock_level", 0))
	var overload_level: int = _get_card_level("battle_overload")
	var disaster_ready: bool = _is_disaster_set_complete()
	var shot_direction: Vector2 = facing_direction if facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	var target_enemy := _get_enemy_in_aim_cone(18.0, float(role_data["range"]) + float(upgrade_data.get("range_bonus", 0.0)) + 80.0)
	var target_distance: float = global_position.distance_to(target_enemy.global_position) if target_enemy != null else float(role_data["range"])
	var main_damage: float = _get_role_damage(role_data["id"])
	if target_enemy != null:
		main_damage *= _get_priority_target_bonus(target_enemy)
	var overload_ready: bool = overload_level > 0 and gunner_attack_chain == 3
	if target_enemy != null and target_distance <= 130.0:
		main_damage *= 0.82
	elif target_enemy != null and target_distance >= 210.0:
		main_damage *= 1.12 + 0.12 * focus_level
	elif target_enemy != null and target_distance >= 160.0:
		main_damage *= 1.04 + 0.08 * focus_level
	if overload_ready:
		main_damage *= 1.16 + overload_level * 0.08
	if disaster_ready:
		main_damage *= 1.08

	var bullet_color := Color(0.54, 0.94, 1.0, 1.0) if _get_story_style_id(role_data["id"]) == "star_pierce" else Color(1.0, 0.42, 0.34, 1.0)
	var bullet = _spawn_directional_bullet(shot_direction, main_damage, bullet_color, role_data["id"], global_position + shot_direction * 18.0)
	if bullet == null:
		return

	bullet.speed = (560.0 + 62.0 * focus_level) * _get_story_style_bullet_speed_multiplier(role_data["id"])
	bullet.pierce_count = int(round(float(upgrade_data["range_bonus"]) / 40.0)) + focus_level + _get_story_style_extra_pierce(role_data["id"])
	if focus_level > 0:
		bullet.vulnerability_bonus = 0.04 * focus_level
		bullet.vulnerability_duration = 1.0 + 0.2 * focus_level
		bullet.hit_radius += 1.5 * focus_level
	if disaster_ready:
		bullet.scale = Vector2(1.55, 1.55)
		bullet.hit_radius += 6.0
		bullet.pierce_count += 1
		for angle_offset in [-0.11, 0.11]:
			var disaster_bullet = _spawn_directional_bullet(shot_direction.rotated(angle_offset), _get_role_damage(role_data["id"]) * 0.24, Color(0.34, 0.92, 1.0, 0.98), role_data["id"], global_position + shot_direction * 20.0)
			if disaster_bullet != null:
				disaster_bullet.speed = 610.0 + focus_level * 24.0
				disaster_bullet.lifetime = 0.82
				disaster_bullet.hit_radius = 12.0
				disaster_bullet.scale = Vector2(1.18, 1.18)
				if disaster_bullet.has_method("configure_wave_motion"):
					disaster_bullet.configure_wave_motion(18.0 + scatter_level * 4.0, 9.4 + focus_level * 0.8, angle_offset * 10.0)
	if lock_level > 0 and target_enemy != null and target_distance >= 175.0:
		_apply_gunner_lock(target_enemy, lock_level)

	if scatter_level > 0 and target_distance >= 160.0:
		var side_shots: int = min(2, scatter_level)
		var angle_step: float = deg_to_rad(7.0 + scatter_level * 2.0)
		for shot_index in range(side_shots):
			var angle_offset: float = angle_step * float(shot_index + 1)
			for direction_sign in [-1.0, 1.0]:
				var spread_direction := facing_direction.rotated(angle_offset * direction_sign)
				var spread_bullet = _spawn_directional_bullet(spread_direction, _get_role_damage(role_data["id"]) * (0.42 + scatter_level * 0.06), Color(1.0, 0.55, 0.36, 0.92), role_data["id"], global_position + facing_direction * 14.0)
				if spread_bullet != null:
					spread_bullet.speed = 510.0 + 18.0 * scatter_level
					spread_bullet.lifetime = 1.0
					spread_bullet.hit_radius = 11.0

	if scatter_level >= 2 and target_distance >= 220.0:
		for angle_offset in [-0.2, 0.2]:
			var lock_bullet = _spawn_directional_bullet(facing_direction.rotated(angle_offset), _get_role_damage(role_data["id"]) * (0.32 + scatter_level * 0.04), Color(1.0, 0.66, 0.4, 0.94), role_data["id"], global_position + facing_direction * 18.0)
			if lock_bullet != null:
				lock_bullet.speed = 600.0
				lock_bullet.lifetime = 1.2
				lock_bullet.hit_radius = 11.0

	if focus_level >= 2 and target_distance >= 170.0:
		var rail_width: float = 16.0 + focus_level * 2.0
		var rail_bullet = _spawn_directional_bullet(facing_direction, _get_role_damage(role_data["id"]) * (0.34 + focus_level * 0.08), Color(1.0, 0.82, 0.44, 0.96), role_data["id"], global_position + facing_direction * 16.0)
		if rail_bullet != null:
			rail_bullet.speed = 980.0 + focus_level * 80.0
			rail_bullet.lifetime = 0.72 + focus_level * 0.04
			rail_bullet.hit_radius = rail_width
			rail_bullet.pierce_count = 3 + focus_level
			rail_bullet.vulnerability_bonus = max(rail_bullet.vulnerability_bonus, 0.05 * focus_level)
			rail_bullet.vulnerability_duration = max(rail_bullet.vulnerability_duration, 1.0)

	gunner_attack_chain = (gunner_attack_chain + 1) % 4
	if gunner_attack_chain == 0 and focus_level > 0:
		var tracer_width: float = 18.0 + focus_level * 2.0
		var tracer_bullet = _spawn_directional_bullet(facing_direction, _get_role_damage(role_data["id"]) * (0.52 + focus_level * 0.08), Color(1.0, 0.9, 0.5, 0.98), role_data["id"], global_position + facing_direction * 14.0)
		if tracer_bullet != null:
			tracer_bullet.speed = 860.0 + focus_level * 65.0
			tracer_bullet.lifetime = 0.68 + focus_level * 0.05
			tracer_bullet.hit_radius = tracer_width
			tracer_bullet.pierce_count = 2 + focus_level
			tracer_bullet.vulnerability_bonus = max(tracer_bullet.vulnerability_bonus, 0.08 + focus_level * 0.02)
			tracer_bullet.vulnerability_duration = max(tracer_bullet.vulnerability_duration, 1.0)

	if overload_ready:
		var overdrive_bullet = _spawn_directional_bullet(shot_direction, _get_role_damage(role_data["id"]) * (0.72 + overload_level * 0.1), Color(1.0, 0.88, 0.54, 0.98), role_data["id"], global_position + shot_direction * 22.0)
		if overdrive_bullet != null:
			overdrive_bullet.speed = 680.0
			overdrive_bullet.lifetime = 1.0
			overdrive_bullet.hit_radius = 14.0
			overdrive_bullet.pierce_count = 1 + min(1, overload_level)

	var dangzhen_hits := _trigger_dangzhen_gunner_qichao_preview(shot_direction, _get_role_damage(role_data["id"]), role_data["id"])
	_spawn_attack_aftershock(global_position + shot_direction * min(220.0 + focus_level * 20.0, float(role_data["range"]) + float(upgrade_data.get("range_bonus", 0.0))), role_data["id"])
	if dangzhen_hits > 0:
		_register_attack_result(role_data["id"], dangzhen_hits, false)

func _perform_mage_attack() -> void:
	var role_data: Dictionary = _get_active_role()
	var upgrade_data: Dictionary = role_upgrade_levels[role_data["id"]]
	var special_data: Dictionary = _get_role_special_state("mage")
	var echo_level: int = int(special_data.get("echo_level", 0))
	var frost_level: int = int(special_data.get("frost_level", 0))
	var gravity_level: int = int(special_data.get("gravity_level", 0))
	var overload_level: int = _get_card_level("battle_overload")
	var disaster_ready: bool = _is_disaster_set_complete()
	var bombard_center := _get_mage_mouse_bombard_center(float(role_data["range"]) + float(upgrade_data.get("range_bonus", 0.0)))
	var target_enemy := _get_enemy_near_position(bombard_center, 56.0 + float(upgrade_data.get("range_bonus", 0.0)) * 0.25)
	var radius: float = (44.0 + float(upgrade_data["range_bonus"]) * 0.55 + echo_level * 5.0 + frost_level * 5.0) * _get_story_style_range_multiplier(role_data["id"])
	var damage_amount: float = _get_role_damage(role_data["id"]) * (0.96 + echo_level * 0.04)
	if target_enemy != null:
		damage_amount *= _get_priority_target_bonus(target_enemy)
	if overload_level > 0 and mage_attack_chain == 2:
		radius += 10.0 + overload_level * 6.0
		damage_amount *= 1.16 + overload_level * 0.08
	if disaster_ready:
		radius += 16.0
		damage_amount *= 1.08
	radius *= MAGE_ATTACK_EFFECT_SCALE
	var vulnerability_bonus: float = 0.03 * frost_level
	var slow_multiplier: float = max(0.38, max(0.56, 0.76 - frost_level * 0.07) - _get_story_style_slow_bonus(role_data["id"]))
	var slow_duration: float = 1.0 + frost_level * 0.3 + overload_level * 0.15 if overload_level > 0 and mage_attack_chain == 2 else 1.0 + frost_level * 0.3
	if disaster_ready:
		_spawn_ring_effect(bombard_center, radius * 0.92, Color(0.32, 0.96, 1.0, 0.82), 7.0, 0.24)
		_spawn_vortex_effect(bombard_center, radius * 0.44, Color(0.92, 0.22, 0.48, 0.32), 0.22)
	_start_basic_mage_bombardment(bombard_center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_data["id"], true)
	if disaster_ready:
		var side_direction: Vector2 = (bombard_center - global_position).orthogonal().normalized()
		if side_direction.length_squared() <= 0.001:
			side_direction = facing_direction.orthogonal().normalized()
		if side_direction.length_squared() <= 0.001:
			side_direction = Vector2.UP
		var side_offset: float = max(34.0, radius * 0.72)
		for sign in [-1.0, 1.0]:
			var echo_center: Vector2 = bombard_center + side_direction * side_offset * sign
			_start_basic_mage_bombardment(echo_center, radius * 0.72, damage_amount * 0.34, vulnerability_bonus * 0.5, slow_multiplier, slow_duration * 0.8, max(0, gravity_level - 1), min(echo_level, 1), frost_level, role_data["id"], true)
	var wave_direction := (get_global_mouse_position() - global_position).normalized()
	if wave_direction.length_squared() <= 0.001:
		wave_direction = facing_direction if facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	_trigger_dangzhen_mage_qichao_preview(wave_direction, damage_amount, role_data["id"])
	_spawn_attack_aftershock(bombard_center, role_data["id"])

func _try_switch_role(new_role_index: int) -> void:
	if new_role_index == active_role_index:
		return
	if new_role_index < 0 or new_role_index >= roles.size():
		return
	if switch_cooldown_remaining > 0.0 and not DEVELOPER_MODE.is_enabled():
		return

	var previous_role_index: int = active_role_index
	var previous_position := global_position
	var exit_hits: int = _apply_exit_skill(previous_role_index)
	active_role_index = new_role_index
	switch_cooldown_remaining = 0.0 if DEVELOPER_MODE.is_enabled() else max(2.5, ROLE_SWITCH_COOLDOWN - role_switch_cooldown_bonus)
	switch_invulnerability_remaining = SWITCH_INVULNERABILITY
	_apply_pending_entry_blessing(str(roles[active_role_index]["id"]))
	var entry_hits: int = _apply_enter_skill(active_role_index)
	_apply_rotation_entry_bonus(str(roles[active_role_index]["id"]))
	_apply_swap_guard(velocity if velocity.length_squared() > 0.001 else facing_direction)
	_prepare_relay_window(previous_role_index, active_role_index, exit_hits, entry_hits)
	_update_active_role_state()
	_mark_role_cycle(str(roles[active_role_index]["id"]))
	var resonance_level := _get_card_level("combat_resonance")
	if resonance_level > 0:
		_activate_switch_power(str(roles[active_role_index]["id"]), "\u8F6E\u8F6C\u5171\u9E23", 1.3 + resonance_level * 0.25, 1.08 + resonance_level * 0.06, 0.02 * resonance_level)
	var symbol_level := _get_card_level("combat_symbol")
	if symbol_level > 0:
		_add_energy((4.0 + symbol_level * 1.8) * energy_gain_multiplier)
		if symbol_level >= 2 and current_ultimate_seals < ULTIMATE_SEAL_MAX:
			_grant_ultimate_seals(1, "\u7B26\u8F6C")
	if _has_elite_relic("elite_reactor"):
		_add_energy(12.0)
	if _has_elite_relic("elite_chain_overload"):
		_grant_ultimate_seals(1, "\u8FDE\u643A\u8D85\u8F7D")
	if previous_position != global_position:
		_spawn_dash_line_effect(previous_position, global_position, Color(0.94, 0.92, 0.66, 0.7), 8.0, 0.12)

func _apply_enter_skill(role_index: int) -> int:
	var role_id: String = roles[role_index]["id"]
	var assault_level := _get_card_level("combat_assault")
	var assault_multiplier: float = 1.0 + float(assault_level) * 0.16
	_queue_camera_shake(5.0, 0.12)
	_pulse_player_visual(1.14, 0.14)
	match role_id:
		"swordsman":
			var special_data: Dictionary = _get_role_special_state(role_id)
			var pursuit_level: int = int(special_data.get("pursuit_level", 0))
			var crescent_level: int = int(special_data.get("crescent_level", 0))
			var thrust_level: int = int(special_data.get("thrust_level", 0))
			var previous_position := global_position
			var cluster_center: Vector2 = _get_enemy_cluster_center()
			var target_enemy: Node2D = _get_enemy_nearest_to_position(cluster_center) if cluster_center != Vector2.ZERO else _get_closest_enemy()
			var travel_direction: Vector2 = facing_direction if facing_direction.length_squared() > 0.001 else Vector2.RIGHT
			var dash_distance: float = (160.0 + thrust_level * 14.0 + pursuit_level * 10.0) * assault_multiplier
			if target_enemy != null and is_instance_valid(target_enemy):
				travel_direction = previous_position.direction_to(target_enemy.global_position)
				dash_distance = (600.0 + thrust_level * 48.0 + pursuit_level * 28.0) * assault_multiplier
			elif cluster_center != Vector2.ZERO:
				travel_direction = previous_position.direction_to(cluster_center)
				dash_distance = (600.0 + thrust_level * 48.0 + pursuit_level * 28.0) * assault_multiplier
			global_position += travel_direction * dash_distance
			facing_direction = travel_direction
			_show_switch_banner("\u8FDB\u573A", "\u7A81\u8FDB\u7834\u9635", Color(1.0, 0.84, 0.46, 1.0))
			var scar_width: float = 32.0 + thrust_level * 4.0
			var scar_end: Vector2 = global_position + travel_direction * (84.0 + thrust_level * 18.0)
			var scar_center := previous_position.lerp(scar_end, 0.5)
			var scar_length := previous_position.distance_to(scar_end)
			_spawn_sword_omnislash_scene_effect(scar_center, travel_direction, scar_length, scar_width * 1.08)
			_spawn_ring_effect(global_position, 78.0 + crescent_level * 8.0, Color(1.0, 0.86, 0.5, 0.78), 9.0, 0.18)
			_spawn_burst_effect(global_position, 72.0 + crescent_level * 8.0, Color(1.0, 0.78, 0.38, 0.18), 0.16)
			switch_invulnerability_remaining = max(switch_invulnerability_remaining, 0.5)
			var line_hits := _damage_enemies_in_line(previous_position, scar_end, scar_width, _get_role_damage(role_id) * (1.52 + pursuit_level * 0.12) * assault_multiplier, 0.1, 1.0, 0.0, role_id)
			var burst_hits := _damage_enemies_in_radius(global_position, (78.0 + crescent_level * 8.0) * (1.0 + assault_level * 0.06), _get_role_damage(role_id) * (0.72 + crescent_level * 0.08) * assault_multiplier, 0.08, 1.0, 0.0)
			var entry_hits := line_hits + burst_hits
			_activate_switch_power(role_id, "\u7834\u9635\u8FFD\u51FB", 2.2, 1.28, 0.08)
			_apply_switch_payoff(entry_hits, 6.0 + assault_level, 1.4 + assault_level * 0.2)
			return entry_hits
		"gunner":
			_show_switch_banner("\u8FDB\u573A", "\u5FEB\u62D4\u538B\u5236", Color(1.0, 0.58, 0.36, 1.0))
			_fire_gunner_entry_wave(role_id, 0)
			var current_scene := get_tree().current_scene
			if current_scene != null:
				var controller := Node2D.new()
				controller.name = "GunnerEntryWaveController"
				current_scene.add_child(controller)
				var tween := controller.create_tween()
				tween.tween_interval(0.08)
				tween.tween_callback(Callable(self, "_fire_gunner_entry_wave").bind(role_id, 1))
				tween.tween_callback(controller.queue_free)
			_activate_switch_power(role_id, "\u5F39\u9053\u8D85\u8F7D", 2.0, 1.22, 0.11)
			_apply_switch_payoff(8 + assault_level * 2, 5.0 + assault_level, 1.0 + assault_level * 0.15)
			return 8
		"mage":
			_show_switch_banner("\u8FDB\u573A", "\u971C\u73AF\u548F\u5531", Color(0.54, 0.9, 1.0, 1.0))
			var bombard_centers: Array = _get_random_enemy_cluster_centers(2)
			var total_hits: int = 0
			for bombard_center in bombard_centers:
				total_hits += _count_enemies_in_radius(bombard_center, MAGE_ENTRY_HIT_RADIUS)
			_start_mage_entry_bombardment(role_id, bombard_centers)
			_activate_switch_power(role_id, "\u5171\u9E23\u8FC7\u8F7D", 2.4, 1.18, 0.07)
			_apply_switch_payoff(total_hits, 7.0 + assault_level, 1.2 + assault_level * 0.18)
			return total_hits
	return 0

func _apply_exit_skill(role_index: int) -> int:
	var role_id: String = roles[role_index]["id"]
	var rearguard_level := _get_card_level("combat_rearguard")
	_queue_camera_shake(3.2, 0.1)
	match role_id:
		"swordsman":
			_queue_next_entry_blessing(role_id)
			_show_switch_banner("\u9000\u573A", "\u8840\u5203\u4F20\u627F", Color(1.0, 0.8, 0.42, 0.96))
			_spawn_ring_effect(global_position, 82.0, Color(1.0, 0.42, 0.34, 0.52), 6.0, 0.18)
			_spawn_guard_effect(global_position, 54.0, Color(1.0, 0.38, 0.32, 0.18), 0.18)
			if rearguard_level >= 3:
				_activate_guard_cover()
			return _trigger_rearguard_attack(role_id, global_position, rearguard_level)
		"gunner":
			_queue_next_entry_blessing(role_id)
			_show_switch_banner("\u9000\u573A", "\u6218\u672F\u88C5\u586B", Color(1.0, 0.58, 0.38, 0.96))
			_spawn_ring_effect(global_position, 92.0, Color(1.0, 0.58, 0.38, 0.54), 6.0, 0.18)
			_spawn_burst_effect(global_position, 72.0, Color(1.0, 0.58, 0.38, 0.16), 0.16)
			if rearguard_level >= 3:
				_activate_guard_cover()
			return _trigger_rearguard_attack(role_id, global_position, rearguard_level)
		"mage":
			_queue_next_entry_blessing(role_id)
			_show_switch_banner("\u9000\u573A", "\u7B26\u5370\u4F20\u5BFC", Color(0.56, 0.92, 1.0, 0.96))
			_spawn_ring_effect(global_position, 96.0, Color(0.52, 0.88, 1.0, 0.58), 6.0, 0.18)
			_spawn_frost_sigils_effect(global_position, 58.0, Color(0.82, 0.98, 1.0, 0.72), 0.2)
			if rearguard_level >= 3:
				_activate_guard_cover()
			return _trigger_rearguard_attack(role_id, global_position, rearguard_level)
	return 0

func _trigger_swordsman_background() -> void:
	var target_enemy := _get_low_health_enemy()
	if target_enemy == null:
		target_enemy = _get_closest_enemy()
	if target_enemy == null:
		return

	var special_data: Dictionary = _get_role_special_state("swordsman")
	var crescent_level: int = int(special_data.get("crescent_level", 0))
	var thrust_level: int = int(special_data.get("thrust_level", 0))
	var damage_amount: float = _get_role_damage("swordsman") * 0.44
	var killed: bool = false
	_spawn_slash_effect(target_enemy.global_position - global_position.direction_to(target_enemy.global_position) * 10.0, global_position.direction_to(target_enemy.global_position), 46.0, 12.0, Color(1.0, 0.74, 0.36, 0.65), 0.1)
	killed = _deal_damage_to_enemy(target_enemy, damage_amount, "swordsman")
	if target_enemy.has_method("apply_bleed"):
		target_enemy.apply_bleed(damage_amount * 0.22, 1.8)
	if crescent_level >= 2:
		_spawn_slash_effect(target_enemy.global_position, global_position.direction_to(target_enemy.global_position).rotated(0.9), 42.0, 10.0, Color(1.0, 0.86, 0.48, 0.55), 0.1)
		_spawn_ring_effect(target_enemy.global_position, 34.0 + crescent_level * 5.0, Color(0.42, 0.84, 1.0, 0.32), 4.0, 0.12)
		_damage_enemies_in_radius(target_enemy.global_position, 34.0 + crescent_level * 5.0, damage_amount * 0.45, 0.0, 1.0, 0.0)
	if thrust_level >= 2:
		var bg_thrust_width: float = 14.0 + thrust_level * 2.0
		_spawn_thrust_effect(global_position, target_enemy.global_position, Color(1.0, 0.24, 0.12, 0.82), bg_thrust_width, 0.12)
		_damage_enemies_in_line(global_position, target_enemy.global_position, bg_thrust_width, damage_amount * 0.5, 0.04 * thrust_level, 1.0, 0.0, "swordsman")
	_register_attack_result("swordsman", 1, killed)

func _trigger_gunner_background() -> void:
	var special_data: Dictionary = _get_role_special_state("gunner")
	var support_level: int = int(special_data.get("support_level", 0))
	var focus_level: int = int(special_data.get("focus_level", 0))
	var scatter_level: int = int(special_data.get("scatter_level", 0))
	var lock_level: int = int(special_data.get("lock_level", 0))
	var targets: Array = _get_enemy_targets(min(1 + support_level, 3), true)
	if targets.is_empty():
		var fallback := _get_closest_enemy()
		if fallback != null:
			targets.append(fallback)

	for target_enemy in targets:
		if target_enemy == null or not is_instance_valid(target_enemy):
			continue
		var bullet = _spawn_bullet(target_enemy, _get_role_damage("gunner") * (0.34 + support_level * 0.06), Color(1.0, 0.58, 0.38, 0.9), "gunner", global_position + _get_support_offset("gunner", false))
		if bullet != null:
			bullet.speed = 500.0 + 24.0 * support_level
			bullet.lifetime = 1.35
			if focus_level > 0:
				bullet.vulnerability_bonus = 0.02 * focus_level
				bullet.vulnerability_duration = 0.9 + 0.16 * focus_level
		if lock_level > 0 and global_position.distance_to(target_enemy.global_position) >= 180.0:
			_spawn_target_lock_effect(target_enemy.global_position, 16.0 + lock_level * 3.0, Color(1.0, 0.8, 0.42, 0.9), 0.18)
		if scatter_level >= 2:
			for angle_sign in [-1.0, 1.0]:
				var spread_bullet = _spawn_directional_bullet(global_position.direction_to(target_enemy.global_position).rotated(0.16 * angle_sign), _get_role_damage("gunner") * 0.18, Color(1.0, 0.66, 0.42, 0.86), "gunner", global_position + _get_support_offset("gunner", false))
				if spread_bullet != null:
					spread_bullet.speed = 460.0
					spread_bullet.lifetime = 0.5
					spread_bullet.hit_radius = 10.0

func _trigger_mage_background() -> void:
	var special_data: Dictionary = _get_role_special_state("mage")
	var support_level: int = int(special_data.get("support_level", 0))
	var frost_level: int = int(special_data.get("frost_level", 0))
	var echo_level: int = int(special_data.get("echo_level", 0))
	var gravity_level: int = int(special_data.get("gravity_level", 0))
	var cluster_position: Vector2 = _get_enemy_cluster_center()
	if cluster_position == Vector2.ZERO:
		var target_enemy := _get_closest_enemy()
		if target_enemy == null:
			return
		cluster_position = target_enemy.global_position

	var radius: float = 66.0 + support_level * 10.0
	var damage_amount: float = _get_role_damage("mage") * (0.32 + support_level * 0.06)
	if gravity_level > 0:
		_pull_enemies_toward(cluster_position, radius + gravity_level * 10.0, 14.0 + gravity_level * 8.0)
		_spawn_vortex_effect(cluster_position, 24.0 + gravity_level * 8.0, Color(0.72, 0.82, 1.0, 0.36), 0.18)
	_spawn_ring_effect(cluster_position, radius * 0.9, Color(0.72, 0.96, 1.0, 0.58), 5.0, 0.16)
	_spawn_frost_sigils_effect(cluster_position, max(24.0, radius * 0.46), Color(0.82, 0.98, 1.0, 0.72), 0.18)
	_spawn_burst_effect(cluster_position, radius, Color(0.48, 0.88, 1.0, 0.18), 0.18)
	var hits: int = _damage_enemies_in_radius(cluster_position, radius, damage_amount, 0.02 * frost_level, max(0.62, 0.84 - frost_level * 0.05), 1.2 + support_level * 0.18)
	if hits > 0:
		_register_attack_result("mage", hits, false)
	if frost_level >= 2:
		_spawn_pulsing_field(cluster_position, 30.0 + frost_level * 4.0, Color(0.52, 0.9, 1.0, 0.12), 2, 0.16, damage_amount * 0.22, 0.02 * frost_level, max(0.38, 0.72 - frost_level * 0.06), 0.9 + frost_level * 0.16)

	if support_level > 0:
		var secondary_targets: Array = _get_enemy_targets(2, false)
		for secondary_target in secondary_targets:
			if secondary_target == null or not is_instance_valid(secondary_target):
				continue
			if secondary_target.global_position.distance_to(cluster_position) < 40.0:
				continue
			_spawn_burst_effect(secondary_target.global_position, 42.0 + support_level * 6.0, Color(0.5, 0.9, 1.0, 0.16), 0.16)
			var extra_hits: int = _damage_enemies_in_radius(secondary_target.global_position, 42.0 + support_level * 6.0, _get_role_damage("mage") * (0.18 + support_level * 0.04), 0.0, max(0.66, 0.86 - frost_level * 0.04), 1.0)
			if extra_hits > 0:
				_register_attack_result("mage", extra_hits, false)
			if echo_level >= 2:
				_spawn_burst_effect(secondary_target.global_position, 24.0 + echo_level * 4.0, Color(0.64, 0.94, 1.0, 0.14), 0.14)
				_register_attack_result("mage", _damage_enemies_in_radius(secondary_target.global_position, 24.0 + echo_level * 4.0, _get_role_damage("mage") * 0.18, 0.0, 0.78, 0.8), false)
			break

func _try_use_ultimate() -> void:
	var ultimate_cost := _get_ultimate_energy_cost()
	if not _can_use_ultimate():
		return

	var role_id: String = _get_active_role()["id"]
	var cast_payload := _build_ultimate_cast_payload()
	if not DEVELOPER_MODE.should_unlock_ultimate_freely() and not _has_elite_relic("elite_perpetual_motion"):
		current_mana = max(0.0, current_mana - ultimate_cost)
	if not DEVELOPER_MODE.should_unlock_ultimate_freely():
		current_ultimate_seals = 0
		mana_changed.emit(current_mana, max_mana)

	match role_id:
		"swordsman":
			_use_swordsman_ultimate(cast_payload)
		"gunner":
			_use_gunner_ultimate(cast_payload)
		"mage":
			_use_mage_ultimate(cast_payload)

func _use_swordsman_ultimate(cast_payload: Dictionary) -> void:
	var special_data: Dictionary = _get_role_special_state("swordsman")
	var pursuit_level: int = int(special_data.get("pursuit_level", 0))
	var crescent_level: int = int(special_data.get("crescent_level", 0))
	var thrust_level: int = int(special_data.get("thrust_level", 0))
	var extend_level := _get_card_level("skill_extend")
	var slash_count: int = 7 + min(2, max(pursuit_level, max(crescent_level, thrust_level)))
	slash_count = int(ceil(float(slash_count) * (1.0 + extend_level * 0.12) * float(cast_payload.get("duration_multiplier", 1.0))))
	var total_duration: float = 0.22 + float(slash_count - 1) * SWORD_ULTIMATE_SLASH_INTERVAL + 0.18
	total_duration *= 1.0 + extend_level * 0.04
	_queue_camera_shake(20.0, 0.62)
	switch_invulnerability_remaining = max(switch_invulnerability_remaining, total_duration)
	if extend_level >= 2:
		ultimate_guard_remaining = max(ultimate_guard_remaining, total_duration)
		ultimate_guard_damage_multiplier = min(ultimate_guard_damage_multiplier, 0.9)
	_delay_level_up_requests(total_duration)
	_set_active_role_visual_hidden(true)
	var current_scene := get_tree().current_scene
	if current_scene != null:
		var restore_controller := Node2D.new()
		restore_controller.name = "SwordsmanUltimateVisualRestore"
		current_scene.add_child(restore_controller)
		var restore_tween := restore_controller.create_tween()
		restore_tween.tween_interval(total_duration)
		restore_tween.tween_callback(func() -> void:
			_set_active_role_visual_hidden(false)
		)
		restore_tween.tween_callback(restore_controller.queue_free)
	_spawn_combat_tag(global_position + Vector2(0.0, -34.0), "\u7EDD\u65A9", Color(1.0, 0.92, 0.6, 1.0))
	_spawn_ring_effect(global_position, 68.0, Color(1.0, 0.88, 0.52, 0.84), 8.0, 0.18)
	_schedule_repeating_sequence(SWORD_ULTIMATE_SLASH_INTERVAL, slash_count, func(slash_index: int) -> void:
		_execute_swordsman_ultimate_slash(slash_count, pursuit_level, crescent_level, thrust_level, float(cast_payload.get("damage_multiplier", 1.0)), slash_index)
	)
	_apply_post_ultimate_bonuses("swordsman", total_duration)

func _use_gunner_ultimate(cast_payload: Dictionary) -> void:
	var special_data: Dictionary = _get_role_special_state("gunner")
	var barrage_level: int = int(special_data.get("barrage_level", 0))
	var focus_level: int = int(special_data.get("focus_level", 0))
	var scatter_level: int = int(special_data.get("scatter_level", 0))
	var lock_level: int = int(special_data.get("lock_level", 0))
	var extend_level := _get_card_level("skill_extend")
	var wave_count: int = 11 + barrage_level * 2
	wave_count = int(ceil(float(wave_count) * (1.0 + extend_level * 0.12) * float(cast_payload.get("duration_multiplier", 1.0))))
	var total_duration: float = 0.24 + float(wave_count - 1) * GUNNER_ULTIMATE_WAVE_INTERVAL
	total_duration *= 1.0 + extend_level * 0.04
	_queue_camera_shake(17.5, 0.54)
	switch_invulnerability_remaining = max(switch_invulnerability_remaining, 0.5)
	if extend_level >= 2:
		ultimate_guard_remaining = max(ultimate_guard_remaining, total_duration)
		ultimate_guard_damage_multiplier = min(ultimate_guard_damage_multiplier, 0.9)
	_delay_level_up_requests(total_duration)
	_spawn_combat_tag(global_position + Vector2(0.0, -34.0), "\u5F39\u5E55", Color(1.0, 0.86, 0.5, 1.0))
	_schedule_repeating_sequence(GUNNER_ULTIMATE_WAVE_INTERVAL, wave_count, func(wave_index: int) -> void:
		_fire_gunner_ultimate_wave(wave_count, barrage_level, focus_level, scatter_level, lock_level, float(cast_payload.get("damage_multiplier", 1.0)), wave_index)
	)
	_apply_post_ultimate_bonuses("gunner", total_duration)

func _use_mage_ultimate(cast_payload: Dictionary) -> void:
	var special_data: Dictionary = _get_role_special_state("mage")
	var storm_level: int = int(special_data.get("storm_level", 0))
	var frost_level: int = int(special_data.get("frost_level", 0))
	var echo_level: int = int(special_data.get("echo_level", 0))
	var gravity_level: int = int(special_data.get("gravity_level", 0))
	var extend_level := _get_card_level("skill_extend")
	var center: Vector2 = _get_enemy_cluster_center()
	if center == Vector2.ZERO:
		center = global_position
	var bombard_count: int = 11 + storm_level * 2
	bombard_count = int(ceil(float(bombard_count) * (1.0 + extend_level * 0.12) * float(cast_payload.get("duration_multiplier", 1.0))))
	var total_duration: float = 0.28 + float(bombard_count - 1) * MAGE_ULTIMATE_BOMBARD_INTERVAL
	total_duration *= 1.0 + extend_level * 0.04
	_queue_camera_shake(18.5, 0.58)
	switch_invulnerability_remaining = max(switch_invulnerability_remaining, 0.45)
	if extend_level >= 2:
		ultimate_guard_remaining = max(ultimate_guard_remaining, total_duration)
		ultimate_guard_damage_multiplier = min(ultimate_guard_damage_multiplier, 0.9)
	_delay_level_up_requests(total_duration)
	_spawn_combat_tag(global_position + Vector2(0.0, -34.0), "\u661F\u707E", Color(0.82, 0.96, 1.0, 1.0))
	_spawn_vortex_effect(center, 58.0 + gravity_level * 12.0, Color(0.76, 0.84, 1.0, 0.54), 0.32)
	_spawn_ring_effect(center, 118.0 + storm_level * 10.0, Color(0.72, 0.96, 1.0, 0.82), 10.0, 0.22)
	_schedule_repeating_sequence(MAGE_ULTIMATE_BOMBARD_INTERVAL, bombard_count, func(pulse_index: int) -> void:
		_trigger_mage_ultimate_bombardment(bombard_count, storm_level, frost_level, echo_level, gravity_level, float(cast_payload.get("damage_multiplier", 1.0)), pulse_index)
	)
	_apply_post_ultimate_bonuses("mage", total_duration)

func _apply_post_ultimate_bonuses(role_id: String, total_duration: float) -> void:
	var afterglow_level := _get_card_level("skill_afterglow")
	if afterglow_level > 0:
		_activate_switch_power(role_id, "\u4F59\u8F89", 2.2 + afterglow_level * 0.35, 1.12 + afterglow_level * 0.05, 0.03 * afterglow_level)
	_spawn_ultimate_afterglow_effect(role_id, 1.8 + afterglow_level * 0.4)
	var extend_level := _get_card_level("skill_extend")
	if extend_level >= 3:
		_add_energy(10.0)
	var borrow_fire_level := _get_card_level("skill_borrow_fire")
	if borrow_fire_level > 0:
		borrow_fire_role_id = role_id
		borrow_fire_remaining = total_duration
		borrow_fire_damage_multiplier = [1.18, 1.24, 1.30][borrow_fire_level - 1]
		borrow_fire_interval_bonus = [0.04, 0.06, 0.08][borrow_fire_level - 1]
		borrow_fire_background_multiplier = 0.9 if borrow_fire_level >= 2 else 1.0
		if borrow_fire_level >= 3:
			_add_energy(8.0)
		_update_fire_timer()
	var reflux_level := _get_card_level("skill_reflux")
	if reflux_level > 0:
		var current_scene := get_tree().current_scene
		if current_scene != null:
			var flow_controller := Node2D.new()
			flow_controller.name = "UltimateRefluxController"
			current_scene.add_child(flow_controller)
			var flow_tween := flow_controller.create_tween()
			flow_tween.tween_interval(total_duration)
			flow_tween.tween_callback(func() -> void:
				_add_energy([18.0, 24.0, 30.0][reflux_level - 1])
				switch_cooldown_remaining = max(0.0, switch_cooldown_remaining - [0.6, 0.9, 1.2][reflux_level - 1])
				if reflux_level >= 2:
					_grant_ultimate_seals(1, "回流")
				if reflux_level >= 3:
					post_ultimate_flow_remaining = 3.0
					post_ultimate_flow_background_multiplier = 0.88
				_spawn_combat_tag(global_position + Vector2(0.0, -46.0), "回流", Color(0.84, 0.96, 1.0, 1.0))
				_spawn_ring_effect(global_position, 68.0, Color(0.72, 0.52, 1.0, 0.72), 6.0, 0.18)
				_spawn_burst_effect(global_position, 54.0, Color(0.6, 0.42, 1.0, 0.18), 0.16)
			)
			flow_tween.tween_callback(flow_controller.queue_free)

	var reprise_level := _get_card_level("skill_reprise")
	if _has_elite_relic("elite_mirror_finisher"):
		reprise_level += 1
	if reprise_level <= 0:
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var controller := Node2D.new()
	controller.name = "UltimateRepriseController"
	current_scene.add_child(controller)
	var tween := controller.create_tween()
	tween.tween_interval(total_duration + 0.12)
	tween.tween_callback(Callable(self, "_trigger_ultimate_reprise").bind(role_id, reprise_level))
	tween.tween_callback(controller.queue_free)

func _trigger_ultimate_reprise(role_id: String, reprise_level: int) -> void:
	if is_dead:
		return

	match role_id:
		"swordsman":
			var radius := 78.0 + reprise_level * 12.0
			_spawn_crescent_wave_effect(global_position + facing_direction * 12.0, facing_direction, radius, Color(1.0, 0.9, 0.62, 0.9), 0.16, 120.0, 26.0)
			var hits := _damage_enemies_in_radius(global_position + facing_direction * 18.0, radius * 0.52, _get_role_damage(role_id) * (0.72 + reprise_level * 0.08), 0.04, 1.0, 0.0)
			if hits > 0:
				_register_attack_result(role_id, hits, false)
		"gunner":
			for bullet_index in range(10 + reprise_level * 2):
				var angle := TAU * float(bullet_index) / float(10 + reprise_level * 2)
				var reprise_bullet = _spawn_directional_bullet(Vector2.RIGHT.rotated(angle), _get_role_damage(role_id) * (0.24 + reprise_level * 0.03), Color(1.0, 0.84, 0.56, 0.92), role_id, global_position)
				if reprise_bullet != null:
					reprise_bullet.speed = 520.0
					reprise_bullet.lifetime = 0.7
					reprise_bullet.hit_radius = 10.0
		"mage":
			var center := _get_enemy_cluster_center()
			if center == Vector2.ZERO:
				center = global_position + facing_direction * 80.0
			_spawn_airstrike_warning_effect(center, 54.0 + reprise_level * 10.0)
			_trigger_basic_mage_bombardment_impact(center, 54.0 + reprise_level * 10.0, _get_role_damage(role_id) * (0.56 + reprise_level * 0.06), 0.02, 0.7, 1.2, 0, 0, 0, role_id)

func _spawn_ultimate_afterglow_effect(role_id: String, duration: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var controller := Node2D.new()
	controller.name = "UltimateAfterglowController"
	current_scene.add_child(controller)

	var pulse_count := 4
	var tween := controller.create_tween()
	for pulse_index in range(pulse_count):
		if pulse_index > 0:
			tween.tween_interval(max(0.08, duration / float(pulse_count)))
		tween.tween_callback(Callable(self, "_trigger_ultimate_afterglow_pulse").bind(role_id, pulse_index))
	tween.tween_callback(controller.queue_free)

func _trigger_ultimate_afterglow_pulse(role_id: String, pulse_index: int) -> void:
	match role_id:
		"swordsman":
			var pulse_direction := facing_direction.rotated(0.18 if pulse_index % 2 == 0 else -0.18)
			_spawn_crescent_wave_effect(global_position + pulse_direction * 10.0, pulse_direction, 76.0 + pulse_index * 8.0, Color(1.0, 0.88, 0.56, 0.62), 0.24, 130.0, 22.0)
		"gunner":
			pass
		"mage":
			var center := _get_enemy_cluster_center()
			if center == Vector2.ZERO:
				center = global_position + facing_direction * 70.0
			var radius := 62.0 + pulse_index * 10.0
			_spawn_ring_effect(center, radius, Color(0.68, 0.96, 1.0, 0.56), 5.0, 0.22)
			_spawn_frost_sigils_effect(center, radius * 0.56, Color(0.86, 0.98, 1.0, 0.68), 0.22)

func _execute_swordsman_ultimate_slash(slash_count: int, pursuit_level: int, crescent_level: int, thrust_level: int, cast_damage_multiplier: float, slash_index: int) -> void:
	if is_dead:
		return

	var start_position: Vector2 = global_position
	var cluster_center: Vector2 = _get_enemy_cluster_center()
	var target_enemy: Node2D = null
	if slash_index == slash_count - 1:
		target_enemy = _get_low_health_enemy()
	elif slash_index % 2 == 0:
		target_enemy = _get_enemy_nearest_to_position(cluster_center if cluster_center != Vector2.ZERO else start_position + facing_direction * 240.0)
	else:
		target_enemy = _get_farthest_enemy()

	var travel_direction: Vector2 = facing_direction if facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	if target_enemy != null and is_instance_valid(target_enemy):
		travel_direction = start_position.direction_to(target_enemy.global_position)
	elif cluster_center != Vector2.ZERO:
		travel_direction = start_position.direction_to(cluster_center)
	if travel_direction.length_squared() <= 0.001:
		travel_direction = Vector2.RIGHT.rotated(float(slash_index) * TAU / float(max(1, slash_count)))

	var dash_distance: float = 96.0 + thrust_level * 10.0 + pursuit_level * 8.0
	if target_enemy != null and is_instance_valid(target_enemy):
		dash_distance = 600.0 + thrust_level * 48.0 + pursuit_level * 28.0
	elif cluster_center != Vector2.ZERO:
		dash_distance = 600.0 + thrust_level * 48.0 + pursuit_level * 28.0
	var end_position: Vector2 = start_position + travel_direction * dash_distance
	global_position = end_position
	facing_direction = travel_direction
	switch_invulnerability_remaining = max(switch_invulnerability_remaining, 0.24)
	_queue_camera_shake(8.6 + float(slash_index) * 0.7, 0.15)
	var scar_width: float = 40.0 + thrust_level * 5.0
	var scar_length_end: Vector2 = end_position + travel_direction * (84.0 + thrust_level * 18.0)
	var scar_center := start_position.lerp(scar_length_end, 0.5)
	var scar_length := start_position.distance_to(scar_length_end)
	_spawn_sword_omnislash_scene_effect(scar_center, travel_direction, scar_length, scar_width * 1.12)

	var damage_scale: float = (1.15 + float(pursuit_level) * 0.12 + float(crescent_level + thrust_level) * 0.06 + float(slash_index) * 0.08) * cast_damage_multiplier
	var line_hits := _damage_enemies_in_line(start_position, scar_length_end, scar_width, _get_role_damage("swordsman") * damage_scale, 0.08 + pursuit_level * 0.02, 1.0, 0.0, "swordsman")
	var blast_hits := _damage_enemies_in_radius(end_position, 48.0 + crescent_level * 12.0, _get_role_damage("swordsman") * (0.52 + float(crescent_level) * 0.08) * cast_damage_multiplier, 0.03 + pursuit_level * 0.02, 1.0, 0.0)
	if line_hits > 0:
		_register_attack_result("swordsman", line_hits, false)
	if blast_hits > 0:
		_register_attack_result("swordsman", blast_hits, false)
	if target_enemy != null and is_instance_valid(target_enemy):
		var direct_cut_kill := _deal_damage_to_enemy(target_enemy, _get_role_damage("swordsman") * (0.68 + pursuit_level * 0.08) * cast_damage_multiplier, "swordsman", 0.06 + pursuit_level * 0.02, 2.0, 1.0, 0.0)
		_register_attack_result("swordsman", 1, direct_cut_kill)

	_spawn_ring_effect(end_position, 34.0 + crescent_level * 8.0, Color(1.0, 0.84, 0.44, 0.76), 5.0, 0.12)

	if target_enemy != null and is_instance_valid(target_enemy) and target_enemy.has_method("apply_bleed"):
		target_enemy.apply_bleed(_get_role_damage("swordsman") * (0.68 + pursuit_level * 0.1), 2.8 + float(crescent_level) * 0.35)

	if slash_index == slash_count - 1:
		var finale_level := _get_card_level("skill_finale")
		var finale_damage_multiplier: float = [1.12, 1.2, 1.3][max(0, finale_level - 1)] if finale_level > 0 else 1.0
		var finale_radius_multiplier: float = 1.2 if finale_level > 0 else 1.0
		_queue_camera_shake(15.0, 0.22)
		_spawn_burst_effect(end_position, (94.0 + crescent_level * 10.0) * finale_radius_multiplier, Color(1.0, 0.78, 0.35, 0.28), 0.2)
		_spawn_ring_effect(end_position, (108.0 + thrust_level * 10.0) * finale_radius_multiplier, Color(1.0, 0.92, 0.58, 0.9), 10.0, 0.18)
		var finisher_hits := _damage_enemies_in_line(start_position, end_position + travel_direction * (168.0 * finale_radius_multiplier), scar_width + 18.0, _get_role_damage("swordsman") * (1.55 + pursuit_level * 0.14) * cast_damage_multiplier * finale_damage_multiplier, 0.1, 1.0, 0.0, "swordsman")
		if finisher_hits > 0:
			_register_attack_result("swordsman", finisher_hits, false)
		if target_enemy != null and is_instance_valid(target_enemy):
			var finisher_kill := _deal_damage_to_enemy(target_enemy, _get_role_damage("swordsman") * (0.92 + pursuit_level * 0.1) * cast_damage_multiplier * finale_damage_multiplier, "swordsman", 0.12, 2.4, 1.0, 0.0)
			_register_attack_result("swordsman", 1, finisher_kill)

func _fire_gunner_ultimate_wave(wave_count: int, barrage_level: int, focus_level: int, scatter_level: int, lock_level: int, cast_damage_multiplier: float, wave_index: int) -> void:
	if is_dead:
		return

	var base_direction: Vector2 = facing_direction if facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	var phase: float = float(wave_index) / float(max(1, wave_count - 1))
	var spin: float = phase * TAU * (2.8 + float(barrage_level) * 0.24)
	var wave_shift: float = sin(spin * 1.2) * (16.0 + scatter_level * 4.0)
	var wave_origin: Vector2 = global_position + base_direction.orthogonal() * wave_shift
	var cluster_center: Vector2 = _get_enemy_cluster_center()
	var target_direction: Vector2 = base_direction
	if cluster_center != Vector2.ZERO and wave_origin.distance_to(cluster_center) > 8.0:
		target_direction = wave_origin.direction_to(cluster_center)
	var fan_arc_degrees: float = 92.0 + scatter_level * 8.0 + min(10.0, float(barrage_level) * 3.0)
	var fan_arc_radians: float = deg_to_rad(fan_arc_degrees)
	var bullet_count: int = 16 + scatter_level * 3 + barrage_level * 3
	var damage_scale: float = (0.52 + float(barrage_level) * 0.05 + float(focus_level) * 0.06) * cast_damage_multiplier
	var finale_level := _get_card_level("skill_finale")
	if wave_index == wave_count - 1 and finale_level > 0:
		bullet_count += 6 + finale_level * 3
		damage_scale *= [1.18, 1.26, 1.35][finale_level - 1]
	var angle_offset: float = sin(spin * 0.9) * 0.18
	_queue_camera_shake(4.6 + float(barrage_level) * 0.24, 0.1)

	for bullet_index in range(bullet_count):
		var ratio: float = 0.0 if bullet_count <= 1 else float(bullet_index) / float(bullet_count - 1)
		var centered_ratio: float = ratio * 2.0 - 1.0
		var angle: float = target_direction.angle() + centered_ratio * fan_arc_radians * 0.5 + angle_offset
		var shot_direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var muzzle_offset: Vector2 = shot_direction * (12.0 + 4.0 * sin(spin + float(bullet_index) * 0.8))
		var central_bonus: float = 1.18 if abs(centered_ratio) <= 0.22 else 1.0
		var spray_bullet = _spawn_directional_bullet(shot_direction, _get_role_damage("gunner") * damage_scale * central_bonus, Color(1.0, 0.72, 0.38, 0.94), "gunner", wave_origin + muzzle_offset)
		if spray_bullet != null:
			spray_bullet.speed = 620.0 + focus_level * 54.0 + barrage_level * 18.0
			spray_bullet.lifetime = 1.08 + barrage_level * 0.06
			spray_bullet.hit_radius = 10.0 + scatter_level * 0.8 + (1.0 if central_bonus > 1.0 else 0.0)
			spray_bullet.visual_scale_multiplier = 0.68
			spray_bullet.enemy_hit_radius_scale = 0.2
			spray_bullet.enemy_hit_radius_min = 4.0
			spray_bullet.enemy_hit_radius_max = 12.0
			spray_bullet.pierce_count = 1 + min(1, focus_level)
			if spray_bullet.has_method("configure_wave_motion") and abs(centered_ratio) >= 0.34:
				var wave_phase: float = ratio * PI + spin * 0.45
				var wave_amplitude: float = max(0.0, abs(centered_ratio) * (10.0 + scatter_level * 4.0))
				var wave_frequency: float = 6.4 + focus_level * 0.9 + barrage_level * 0.25
				spray_bullet.configure_wave_motion(wave_amplitude, wave_frequency, wave_phase)
			if focus_level > 0:
				spray_bullet.vulnerability_bonus = 0.03 + focus_level * 0.015
				spray_bullet.vulnerability_duration = 1.0 + focus_level * 0.2

	if lock_level > 0 and wave_index % max(2, 4 - lock_level) == 0:
		for enemy in _get_enemy_targets(min(1 + lock_level, 3), false):
			if enemy == null or not is_instance_valid(enemy):
				continue
			var lock_bullet = _spawn_bullet(enemy, _get_role_damage("gunner") * (1.2 + lock_level * 0.16), Color(1.0, 0.86, 0.5, 1.0), "gunner", wave_origin)
			if lock_bullet != null:
				lock_bullet.speed = 760.0 + focus_level * 55.0
				lock_bullet.lifetime = 1.38 + barrage_level * 0.07
				lock_bullet.hit_radius = 8.0 + lock_level * 0.8
				lock_bullet.visual_scale_multiplier = 0.68
				lock_bullet.enemy_hit_radius_scale = 0.18
				lock_bullet.enemy_hit_radius_min = 4.0
				lock_bullet.enemy_hit_radius_max = 10.0
				lock_bullet.pierce_count = min(2, focus_level)
				lock_bullet.vulnerability_bonus = 0.04 + lock_level * 0.02
				lock_bullet.vulnerability_duration = 1.4 + lock_level * 0.22

func _trigger_mage_ultimate_bombardment(pulse_count: int, storm_level: int, frost_level: int, echo_level: int, gravity_level: int, cast_damage_multiplier: float, pulse_index: int) -> void:
	if is_dead:
		return

	var cluster_center: Vector2 = _get_enemy_cluster_center()
	if cluster_center == Vector2.ZERO:
		cluster_center = global_position
	var phase: float = float(pulse_index) / float(max(1, pulse_count - 1))
	var orbit_angle: float = phase * TAU * (1.6 + float(echo_level) * 0.18)
	var main_center: Vector2 = cluster_center + Vector2.RIGHT.rotated(orbit_angle) * (12.0 + 8.0 * sin(orbit_angle * 1.4))
	var pulse_radius: float = 72.0 + storm_level * 9.0 + frost_level * 4.0
	var pulse_damage: float = _get_role_damage("mage") * (0.72 + storm_level * 0.08 + echo_level * 0.04) * cast_damage_multiplier
	var finale_level := _get_card_level("skill_finale")
	if pulse_index == pulse_count - 1 and finale_level > 0:
		pulse_radius *= 1.2
		pulse_damage *= [1.45, 1.60, 1.75][finale_level - 1]
	_queue_camera_shake(6.4 + float(storm_level) * 0.28, 0.12)
	switch_invulnerability_remaining = max(switch_invulnerability_remaining, 0.08)
	if gravity_level > 0:
		_pull_enemies_toward(cluster_center, 132.0 + gravity_level * 18.0, 20.0 + gravity_level * 10.0)
		_spawn_vortex_effect(cluster_center, 40.0 + gravity_level * 14.0, Color(0.76, 0.82, 1.0, 0.42), 0.18)
	_spawn_ring_effect(main_center, pulse_radius, Color(0.72, 0.96, 1.0, 0.76), 6.0, 0.18)
	_spawn_burst_effect(main_center, pulse_radius, Color(0.5, 0.92, 1.0, 0.24), 0.2)
	_spawn_frost_sigils_effect(main_center, 34.0 + frost_level * 8.0, Color(0.86, 0.98, 1.0, 0.82), 0.18)
	var main_hits := _damage_enemies_in_radius(main_center, pulse_radius, pulse_damage, 0.08 + frost_level * 0.025, max(0.24, 0.46 - frost_level * 0.03), 2.2 + storm_level * 0.22)
	if main_hits > 0:
		_register_attack_result("mage", main_hits, false)

	if frost_level >= 2 and pulse_index % 3 == 0:
		_spawn_pulsing_field(main_center, 44.0 + frost_level * 10.0, Color(0.56, 0.92, 1.0, 0.16), 2, 0.1, _get_role_damage("mage") * (0.18 + frost_level * 0.04), 0.05, max(0.24, 0.4 - frost_level * 0.03), 1.8 + frost_level * 0.2)

	if echo_level > 0:
		var secondary_enemy: Node2D = _get_enemy_nearest_to_position(cluster_center + Vector2.RIGHT.rotated(orbit_angle + 1.8) * 84.0)
		if secondary_enemy != null and is_instance_valid(secondary_enemy):
			var echo_center: Vector2 = secondary_enemy.global_position
			if echo_center.distance_to(main_center) > 28.0:
				_spawn_burst_effect(echo_center, 46.0 + echo_level * 8.0, Color(0.68, 0.96, 1.0, 0.18), 0.18)
				var echo_hits := _damage_enemies_in_radius(echo_center, 46.0 + echo_level * 8.0, _get_role_damage("mage") * (0.3 + echo_level * 0.05), 0.04, max(0.3, 0.52 - frost_level * 0.03), 1.8)
				if echo_hits > 0:
					_register_attack_result("mage", echo_hits, false)

func _schedule_repeating_sequence(interval: float, repeat_count: int, callback: Callable) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null or repeat_count <= 0:
		return

	var controller := Node2D.new()
	controller.name = "UltimateSequenceController"
	current_scene.add_child(controller)

	var tween := controller.create_tween()
	for index in range(repeat_count):
		if index > 0:
			tween.tween_interval(interval)
		var sequence_index := index
		tween.tween_callback(func() -> void:
			callback.call(sequence_index)
		)
	tween.tween_callback(controller.queue_free)

func _fire_gunner_entry_wave(role_id: String, wave_index: int) -> void:
	var bullet_count: int = 90
	var angle_offset: float = (TAU / float(bullet_count)) * 0.5 * float(wave_index)
	_queue_camera_shake(4.0, 0.08)
	for bullet_index in range(bullet_count):
		var shot_angle: float = TAU * float(bullet_index) / float(bullet_count) + angle_offset
		var bullet = _spawn_directional_bullet(Vector2.RIGHT.rotated(shot_angle), _get_role_damage(role_id) * 0.22, Color(1.0, 0.55, 0.32, 1.0), role_id, global_position)
		if bullet != null:
			bullet.speed = 660.0
			bullet.lifetime = 0.9
			bullet.hit_radius = 12.0

func _start_mage_entry_bombardment(role_id: String, bombard_centers: Array) -> void:
	if bombard_centers.is_empty():
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var controller := Node2D.new()
	controller.name = "MageEntryBombardmentController"
	current_scene.add_child(controller)

	var first_center: Vector2 = bombard_centers[0]
	var warning_duration: float = _get_scene_animation_duration(MAGE_WARNING_EFFECT_SCENE, 0.2)
	_show_mage_entry_bombardment_warning(first_center)

	var tween := controller.create_tween()
	tween.tween_interval(warning_duration)
	tween.tween_callback(Callable(self, "_trigger_mage_entry_bombardment_impact").bind(role_id, first_center))

	if bombard_centers.size() > 1:
		var second_center: Vector2 = bombard_centers[1]
		tween.tween_interval(0.22)
		tween.tween_callback(Callable(self, "_show_mage_entry_bombardment_warning").bind(second_center))
		tween.tween_interval(warning_duration)
		tween.tween_callback(Callable(self, "_trigger_mage_entry_bombardment_impact").bind(role_id, second_center))

	tween.tween_callback(controller.queue_free)

func _show_mage_entry_bombardment_warning(center: Vector2) -> void:
	_spawn_mage_warning_scene_effect(center, MAGE_ENTRY_EFFECT_RADIUS)

func _trigger_mage_entry_bombardment_impact(role_id: String, center: Vector2) -> void:
	_queue_camera_shake(7.2, 0.14)
	_spawn_mage_boom_scene_effect(center, MAGE_ENTRY_EFFECT_RADIUS)
	var hits := _damage_enemies_in_radius(center, MAGE_ENTRY_HIT_RADIUS, _get_role_damage(role_id) * 0.82, 0.06, 0.58, 2.2)
	if hits > 0:
		_register_attack_result(role_id, hits, false)

func _start_basic_mage_bombardment(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, use_boom_effect: bool = false) -> void:
	if not use_boom_effect:
		_spawn_airstrike_warning_effect(center, radius)
	if gravity_level > 0:
		_spawn_vortex_effect(center, 18.0 + gravity_level * 7.0, Color(0.74, 0.82, 1.0, 0.26), 0.18)

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var controller := Node2D.new()
	controller.name = "MageBasicBombardmentController"
	current_scene.add_child(controller)

	var tween := controller.create_tween()
	if use_boom_effect:
		var warning_duration: float = _get_scene_animation_duration(MAGE_WARNING_EFFECT_SCENE, 0.2)
		var boom_duration: float = _get_scene_animation_duration(MAGE_BOOM_EFFECT_SCENE, 0.3)
		tween.tween_callback(Callable(self, "_spawn_mage_warning_scene_effect").bind(center, radius))
		tween.tween_interval(warning_duration)
		tween.tween_callback(Callable(self, "_spawn_mage_boom_scene_effect").bind(center, radius))
		tween.tween_interval(boom_duration)
		tween.tween_callback(Callable(self, "_resolve_basic_mage_bombardment_damage").bind(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, use_boom_effect))
	else:
		tween.tween_interval(0.22)
		tween.tween_callback(Callable(self, "_trigger_basic_mage_bombardment_impact").bind(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, use_boom_effect))
	tween.tween_callback(controller.queue_free)

func _trigger_basic_mage_bombardment_impact(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, use_boom_effect: bool = false) -> void:
	if not use_boom_effect:
		_spawn_airstrike_fall_effect(center, radius)
	if use_boom_effect:
		_resolve_basic_mage_bombardment_damage(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, true)
	else:
		_spawn_sketch_sprite_effect(
			center,
			0.0,
			MAGE_BOMBARD_TEXTURE_RELATIVE_PATH,
			MAGE_BOMBARD_TEXTURE_SIZE,
			MAGE_BOMBARD_VISIBLE_BOUNDS,
			Vector2(radius * 2.0, radius * 2.0),
			0.22,
			Color.WHITE,
			14,
			true,
			true
		)
		_resolve_basic_mage_bombardment_damage(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, false)

func _resolve_basic_mage_bombardment_damage(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, use_boom_effect: bool) -> void:
	_queue_camera_shake(5.8, 0.12)
	if gravity_level > 0:
		_pull_enemies_toward(center, radius + gravity_level * 10.0, 16.0 + gravity_level * 10.0)
		_spawn_vortex_effect(center, 24.0 + gravity_level * 8.0, Color(0.76, 0.84, 1.0, 0.42), 0.2)
	if not use_boom_effect:
		_spawn_ring_effect(center, radius, Color(0.72, 0.96, 1.0, 0.78), 6.0, 0.18)
	_spawn_burst_effect(center, radius, Color(0.52, 0.9, 1.0, 0.22), 0.2)
	if frost_level > 0:
		_spawn_frost_sigils_effect(center, max(20.0, radius * 0.58), Color(0.86, 0.98, 1.0, 0.76), 0.18)
	var hits: int = 0
	if use_boom_effect:
		var ellipse_horizontal_radius: float = radius * 2.04
		var ellipse_vertical_radius: float = max(32.0, radius * 0.84)
		hits = _damage_enemies_in_ellipse(center, ellipse_horizontal_radius, ellipse_vertical_radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, role_id)
	else:
		hits = _damage_enemies_in_radius(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration)
	if hits > 0:
		_register_attack_result(role_id, hits, false)

	if echo_level > 0:
		var echo_target := _get_enemy_nearest_to_position(center + facing_direction * (36.0 + echo_level * 10.0))
		if echo_target != null and is_instance_valid(echo_target) and center.distance_to(echo_target.global_position) <= 132.0 + echo_level * 16.0:
			var echo_center := echo_target.global_position
			_spawn_burst_effect(echo_center, 24.0 + echo_level * 6.0, Color(0.64, 0.94, 1.0, 0.16), 0.14)
			var echo_hits := _damage_enemies_in_radius(echo_center, 24.0 + echo_level * 6.0, damage_amount * (0.24 + echo_level * 0.05), 0.0, max(0.62, slow_multiplier + 0.08), 0.8 + echo_level * 0.15)
			if echo_hits > 0:
				_register_attack_result(role_id, echo_hits, false)

	if frost_level >= 2:
		_spawn_pulsing_field(center, 28.0 + frost_level * 5.0, Color(0.56, 0.9, 1.0, 0.14), 2, 0.12, damage_amount * (0.12 + frost_level * 0.02), 0.02 * frost_level, max(0.4, slow_multiplier - 0.08), 0.9 + frost_level * 0.18)
	if gravity_level >= 2:
		_spawn_pulsing_field(center, 24.0 + gravity_level * 6.0, Color(0.74, 0.84, 1.0, 0.12), 2, 0.1, damage_amount * (0.1 + gravity_level * 0.03), 0.0, max(0.46, slow_multiplier - 0.08), 0.9 + gravity_level * 0.15)

	mage_attack_chain = (mage_attack_chain + 1) % 3
	if mage_attack_chain == 0 and (echo_level > 0 or frost_level > 0 or gravity_level > 0):
		_spawn_pulsing_field(center, 34.0 + echo_level * 5.0, Color(0.62, 0.95, 1.0, 0.16), 2, 0.1, damage_amount * (0.16 + echo_level * 0.03), 0.02 + frost_level * 0.01, max(0.46, slow_multiplier - 0.06), 0.8 + frost_level * 0.15)

func _get_enemy_nearest_to_position(position: Vector2) -> Node2D:
	if position == Vector2.ZERO:
		return _get_closest_enemy()

	var selected_enemy: Node2D
	var best_distance: float = INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var distance: float = position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			selected_enemy = enemy
	return selected_enemy

func _get_enemy_near_position(position: Vector2, max_distance: float) -> Node2D:
	var selected_enemy: Node2D
	var best_distance: float = max_distance
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var distance := position.distance_to(enemy.global_position)
		if distance > best_distance:
			continue
		best_distance = distance
		selected_enemy = enemy
	return selected_enemy

func _get_mage_mouse_bombard_center(base_range: float) -> Vector2:
	var viewport_rect := get_viewport_rect()
	var min_view_size: float = min(viewport_rect.size.x, viewport_rect.size.y)
	var max_distance: float = max(base_range + 36.0, clamp(min_view_size * 0.46, 220.0, 420.0))
	var mouse_offset: Vector2 = get_global_mouse_position() - global_position
	if mouse_offset.length_squared() <= 1.0:
		return global_position + facing_direction * min(max_distance * 0.55, 180.0)
	if mouse_offset.length() > max_distance:
		mouse_offset = mouse_offset.normalized() * max_distance
	return global_position + mouse_offset

func _spawn_bullet(target_enemy: Node2D, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null):
	if bullet_scene == null:
		return null

	var bullet = bullet_scene.instantiate()
	if bullet == null:
		return null

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null

	current_scene.add_child(bullet)
	bullet.global_position = origin if origin is Vector2 else global_position
	bullet.direction = bullet.global_position.direction_to(target_enemy.global_position)
	bullet.target = target_enemy
	bullet.damage = damage_amount
	bullet.visual_color = color
	bullet.source_player = self
	bullet.source_role_id = role_id if role_id != "" else _get_active_role()["id"]
	return bullet

func _spawn_directional_bullet(direction: Vector2, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null):
	if bullet_scene == null:
		return null

	var bullet = bullet_scene.instantiate()
	if bullet == null:
		return null

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null

	current_scene.add_child(bullet)
	bullet.global_position = origin if origin is Vector2 else global_position
	bullet.direction = direction.normalized()
	bullet.target = null
	bullet.damage = damage_amount
	bullet.visual_color = color
	bullet.source_player = self
	bullet.source_role_id = role_id if role_id != "" else _get_active_role()["id"]
	return bullet

func _spawn_directional_bullet_from_scene(projectile_scene: PackedScene, direction: Vector2, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null):
	if projectile_scene == null:
		return null

	var bullet = projectile_scene.instantiate()
	if bullet == null:
		return null

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null

	current_scene.add_child(bullet)
	bullet.global_position = origin if origin is Vector2 else global_position
	bullet.direction = direction.normalized()
	bullet.target = null
	bullet.damage = damage_amount
	bullet.visual_color = color
	bullet.source_player = self
	bullet.source_role_id = role_id if role_id != "" else _get_active_role()["id"]
	return bullet

func _get_enemy_meta_int(enemy: Node, key: String) -> int:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_meta(key):
		return 0
	return int(enemy.get_meta(key))

func _get_enemy_meta_float(enemy: Node, key: String) -> float:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_meta(key):
		return 0.0
	return float(enemy.get_meta(key))

func _get_enemy_hit_radius(enemy: Node) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return 12.0
	var enemy_contact_radius: Variant = enemy.get("contact_radius")
	if enemy_contact_radius == null:
		return 12.0
	return clamp(float(enemy_contact_radius) * 0.42, 10.0, 28.0)

func _deal_damage_to_enemy(enemy: Node, damage_amount: float, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var break_level := _get_card_level("battle_break")
	var final_damage := damage_amount
	var break_stacks := 0
	var break_max_stacks := 0
	var break_expire_time := 0.0
	var break_ready := false
	if break_level > 0:
		break_stacks = _get_enemy_meta_int(enemy, "player_break_stacks")
		break_max_stacks = 4 if break_level == 1 else 5
		break_expire_time = _get_enemy_meta_float(enemy, "player_break_expire")
		break_ready = bool(enemy.get_meta("player_break_ready")) if enemy.has_meta("player_break_ready") else false
		if role_visual_time > break_expire_time:
			break_stacks = 0
			break_ready = false
		var break_multiplier: float = [0.06, 0.07, 0.08][break_level - 1]
		final_damage *= 1.0 + min(break_stacks, break_max_stacks) * break_multiplier
		if break_level >= 2 and break_stacks >= break_max_stacks:
			final_damage *= 1.1
	var killed := false
	if damage_amount > 0.0 and enemy.has_method("take_damage"):
		killed = bool(enemy.take_damage(final_damage))
	if vulnerability_bonus > 0.0 and enemy.has_method("apply_vulnerability"):
		enemy.apply_vulnerability(vulnerability_bonus, vulnerability_duration)
	if slow_duration > 0.0 and enemy.has_method("apply_slow"):
		enemy.apply_slow(slow_multiplier, slow_duration)
	if break_level > 0:
		break_stacks = min(break_max_stacks, break_stacks + 1)
		enemy.set_meta("player_break_stacks", break_stacks)
		enemy.set_meta("player_break_expire", role_visual_time + 1.8)
		if break_stacks >= break_max_stacks and break_level >= 3:
			if break_ready and enemy.has_method("take_damage"):
				var bonus_kill := bool(enemy.take_damage(damage_amount * 0.6))
				if bonus_kill and source_role_id != "":
					_register_attack_result(source_role_id, 1, true)
				enemy.set_meta("player_break_ready", false)
			else:
				enemy.set_meta("player_break_ready", true)
		elif break_stacks < break_max_stacks:
			enemy.set_meta("player_break_ready", false)
	return killed

func _damage_enemies_in_radius(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float) -> int:
	var hit_count: int = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if center.distance_to(enemy.global_position) > radius + _get_enemy_hit_radius(enemy):
			continue

		var killed: bool = false
		killed = _deal_damage_to_enemy(enemy, damage_amount, str(_get_active_role().get("id", "")), vulnerability_bonus, 2.5, slow_multiplier, slow_duration)
		hit_count += 1
		if killed:
			_register_attack_result(_get_active_role()["id"], 1, true)

	return hit_count

func _pull_enemies_toward(center: Vector2, radius: float, pull_strength: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var distance: float = center.distance_to(enemy.global_position)
		if distance <= 1.0 or distance > radius:
			continue
		var pull_step: float = min(pull_strength, distance - 4.0)
		if pull_step <= 0.0:
			continue
		var pull_ratio: float = 1.0 - distance / radius
		enemy.global_position = enemy.global_position.move_toward(center, max(4.0, pull_step * (0.55 + pull_ratio * 0.7)))

func _damage_enemies_in_line(start_position: Vector2, end_position: Vector2, width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var hit_count: int = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start_position, end_position)
		if closest_point.distance_to(enemy.global_position) > width + _get_enemy_hit_radius(enemy):
			continue

		var killed: bool = false
		killed = _deal_damage_to_enemy(enemy, damage_amount, source_role_id if source_role_id != "" else str(_get_active_role().get("id", "")), vulnerability_bonus, 2.0, slow_multiplier, slow_duration)
		hit_count += 1
		if killed:
			_register_attack_result(source_role_id if source_role_id != "" else _get_active_role()["id"], 1, true)

	return hit_count

func _damage_enemies_in_oriented_rect(center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var hit_count: int = 0
	var long_axis: Vector2 = axis_direction.normalized()
	if long_axis.length_squared() <= 0.001:
		long_axis = Vector2.DOWN
	var short_axis: Vector2 = Vector2(-long_axis.y, long_axis.x)
	var half_length: float = rect_length * 0.5
	var half_width: float = rect_width * 0.5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_position: Vector2 = enemy.global_position
		var to_enemy: Vector2 = enemy_position - center
		var enemy_radius: float = _get_enemy_hit_radius(enemy)
		var local_long: float = abs(to_enemy.dot(long_axis))
		var local_short: float = abs(to_enemy.dot(short_axis))
		if local_long > half_length + enemy_radius:
			continue
		if local_short > half_width + enemy_radius:
			continue

		var killed: bool = _deal_damage_to_enemy(enemy, damage_amount, source_role_id if source_role_id != "" else str(_get_active_role().get("id", "")), vulnerability_bonus, 2.0, slow_multiplier, slow_duration)
		hit_count += 1
		if killed:
			_register_attack_result(source_role_id if source_role_id != "" else _get_active_role()["id"], 1, true)

	return hit_count

func _damage_enemies_in_oriented_rect_unique(center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, hit_registry: Dictionary, source_role_id: String = "") -> int:
	var hit_count: int = 0
	var long_axis: Vector2 = axis_direction.normalized()
	if long_axis.length_squared() <= 0.001:
		long_axis = Vector2.DOWN
	var short_axis: Vector2 = Vector2(-long_axis.y, long_axis.x)
	var half_length: float = rect_length * 0.5
	var half_width: float = rect_width * 0.5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_id: int = enemy.get_instance_id()
		if hit_registry.has(enemy_id):
			continue
		var enemy_position: Vector2 = enemy.global_position
		var to_enemy: Vector2 = enemy_position - center
		var enemy_radius: float = _get_enemy_hit_radius(enemy)
		var local_long: float = abs(to_enemy.dot(long_axis))
		var local_short: float = abs(to_enemy.dot(short_axis))
		if local_long > half_length + enemy_radius:
			continue
		if local_short > half_width + enemy_radius:
			continue

		hit_registry[enemy_id] = true
		var killed: bool = _deal_damage_to_enemy(enemy, damage_amount, source_role_id if source_role_id != "" else str(_get_active_role().get("id", "")), vulnerability_bonus, 2.0, slow_multiplier, slow_duration)
		hit_count += 1
		if killed:
			_register_attack_result(source_role_id if source_role_id != "" else _get_active_role()["id"], 1, true)

	return hit_count

func _damage_enemies_in_ellipse(center: Vector2, horizontal_radius: float, vertical_radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var hit_count: int = 0
	var safe_horizontal_radius: float = max(1.0, horizontal_radius)
	var safe_vertical_radius: float = max(1.0, vertical_radius)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_position: Vector2 = enemy.global_position
		var enemy_radius: float = _get_enemy_hit_radius(enemy)
		var normalized_x: float = (enemy_position.x - center.x) / (safe_horizontal_radius + enemy_radius)
		var normalized_y: float = (enemy_position.y - center.y) / (safe_vertical_radius + enemy_radius)
		if normalized_x * normalized_x + normalized_y * normalized_y > 1.0:
			continue

		var killed: bool = _deal_damage_to_enemy(enemy, damage_amount, source_role_id if source_role_id != "" else str(_get_active_role().get("id", "")), vulnerability_bonus, 2.0, slow_multiplier, slow_duration)
		hit_count += 1
		if killed:
			_register_attack_result(source_role_id if source_role_id != "" else _get_active_role()["id"], 1, true)

	return hit_count

func _schedule_swordsman_slash_followthrough(center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, animation_duration: float, source_role_id: String, hit_registry: Dictionary) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null or SWORD_SLASH_DAMAGE_FOLLOW_PULSES <= 0:
		return

	var controller := Node2D.new()
	controller.name = "SwordsmanSlashFollowthroughController"
	current_scene.add_child(controller)

	var tween := controller.create_tween()
	var pulse_interval: float = max(0.03, animation_duration / float(SWORD_SLASH_DAMAGE_FOLLOW_PULSES + 1))
	for pulse_index in range(SWORD_SLASH_DAMAGE_FOLLOW_PULSES):
		tween.tween_interval(pulse_interval)
		tween.tween_callback(func() -> void:
			_damage_enemies_in_oriented_rect_unique(center, axis_direction, rect_length, rect_width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, hit_registry, source_role_id)
		)
	tween.tween_callback(controller.queue_free)

func _apply_gunner_lock(target_enemy: Node2D, lock_level: int) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy):
		gunner_lock_target = null
		gunner_lock_stacks = 0
		return

	if gunner_lock_target == null or not is_instance_valid(gunner_lock_target) or gunner_lock_target != target_enemy:
		gunner_lock_target = target_enemy
		gunner_lock_stacks = 0

	gunner_lock_stacks += 1
	if target_enemy.has_method("apply_vulnerability"):
		target_enemy.apply_vulnerability(0.04 * lock_level, 1.4 + 0.2 * lock_level)

	var required_stacks: int = max(1, 3 - lock_level)
	if gunner_lock_stacks < required_stacks:
		return

	gunner_lock_stacks = 0
	gunner_lock_target = null
	var bonus_damage := _get_role_damage("gunner") * (0.36 + lock_level * 0.14)
	var locked_kill := false
	locked_kill = _deal_damage_to_enemy(target_enemy, bonus_damage, "gunner")
	if lock_level >= 2:
		var splash_hits := _damage_enemies_in_radius(target_enemy.global_position, 26.0 + lock_level * 5.0, _get_role_damage("gunner") * (0.12 + lock_level * 0.03), 0.02, 1.0, 0.0)
		if splash_hits > 0:
			_register_attack_result("gunner", splash_hits, false)
	_register_attack_result("gunner", 1, locked_kill)

func _update_active_role_state() -> void:
	var role_data: Dictionary = _get_active_role()
	_update_visuals(role_data)
	_update_hurt_core_visual(role_data)
	_update_fire_timer()
	stats_changed.emit(get_stat_summary())
	active_role_changed.emit(role_data["id"], role_data["name"])

func _setup_hurt_core_visual() -> void:
	var hurt_core := get_node_or_null("HurtCore") as Node2D
	if hurt_core == null:
		return
	var fill := hurt_core.get_node_or_null("Fill") as Polygon2D
	if fill != null:
		fill.polygon = _build_circle_polygon(PLAYER_HURT_CORE_RADIUS)
	var outline := hurt_core.get_node_or_null("Outline") as Line2D
	if outline != null:
		var ring_points := _build_circle_polygon(PLAYER_HURT_CORE_RADIUS + PLAYER_HURT_CORE_OUTLINE_WIDTH * 0.35)
		if ring_points.size() > 0:
			ring_points.append(ring_points[0])
		outline.points = ring_points
		outline.width = PLAYER_HURT_CORE_OUTLINE_WIDTH

func _update_hurt_core_visual(role_data: Dictionary = {}) -> void:
	var hurt_core := get_node_or_null("HurtCore") as Node2D
	if hurt_core == null:
		return
	if role_data.is_empty():
		role_data = _get_active_role()
	hurt_core.position = PLAYER_HURT_CORE_OFFSET
	hurt_core.z_index = 60
	var role_color: Color = role_data.get("color", Color(1.0, 0.5, 0.4, 1.0))
	var fill := hurt_core.get_node_or_null("Fill") as Polygon2D
	if fill != null:
		fill.color = Color(1.0, 1.0, 1.0, 0.94)
		fill.visible = true
	var outline := hurt_core.get_node_or_null("Outline") as Line2D
	if outline != null:
		outline.default_color = Color(role_color.r, role_color.g, role_color.b, 1.0)
		outline.visible = true

func get_hurtbox_center() -> Vector2:
	var hurt_core := get_node_or_null("HurtCore") as Node2D
	if hurt_core != null:
		return hurt_core.global_position
	return global_position

func get_hurtbox_radius() -> float:
	return PLAYER_HURT_CORE_RADIUS

func _update_visuals(role_data: Dictionary) -> void:
	var polygon := get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null:
		polygon.visible = false

	for child in get_children():
		if child is Node and str(child.name).begins_with("RoleVisualRoot"):
			remove_child(child)
			child.free()

	var visual_root := Node2D.new()
	visual_root.name = "RoleVisualRoot"
	add_child(visual_root)
	var sprite := Sprite2D.new()
	sprite.name = "RoleSprite"
	if not _configure_role_sprite(sprite, str(role_data["id"])):
		if polygon != null:
			polygon.visible = true
			polygon.color = role_data["color"]
			if active_role_visual_hidden and str(role_data["id"]) == active_role_visual_hidden_role_id:
				polygon.visible = false
		sprite.queue_free()
		return
	visual_root.add_child(sprite)
	var should_hide := active_role_visual_hidden and str(role_data["id"]) == active_role_visual_hidden_role_id
	if sprite != null:
		sprite.visible = not should_hide
	if polygon != null and not should_hide:
		polygon.visible = false

func _update_fire_timer() -> void:
	if fire_timer == null:
		return

	var role_data: Dictionary = _get_active_role()
	var interval_bonus: float = _get_active_interval_bonus(str(role_data["id"]))
	fire_timer.wait_time = max(0.18, float(role_data["attack_interval"]) - interval_bonus)
	fire_timer.start()

func _update_camera_shake(delta: float) -> void:
	if camera_node == null:
		return
	if camera_shake_time <= 0.0:
		camera_node.offset = camera_base_offset
		return

	camera_shake_time = max(0.0, camera_shake_time - delta)
	var shake_x: float = randf_range(-camera_shake_strength, camera_shake_strength)
	var shake_y: float = randf_range(-camera_shake_strength, camera_shake_strength)
	camera_node.offset = camera_base_offset + Vector2(shake_x, shake_y)
	camera_shake_strength = lerpf(camera_shake_strength, 0.0, min(1.0, delta * 14.0))
	if camera_shake_time <= 0.0:
		camera_node.offset = camera_base_offset

func _queue_camera_shake(strength: float, duration: float) -> void:
	camera_shake_strength = max(camera_shake_strength, strength)
	camera_shake_time = max(camera_shake_time, duration)

func _pulse_player_visual(peak_scale: float, duration: float) -> void:
	var sprite := get_node_or_null("RoleVisualRoot/RoleSprite") as Sprite2D
	var base_scale := Vector2.ONE
	var target_node: Node2D = null
	if sprite != null:
		target_node = sprite
		base_scale = sprite.get_meta("base_scale", sprite.scale)
	else:
		var polygon := get_node_or_null("Polygon2D") as Polygon2D
		if polygon == null:
			return
		target_node = polygon
		base_scale = Vector2.ONE
	target_node.scale = base_scale
	var tween := create_tween()
	tween.tween_property(target_node, "scale", base_scale * peak_scale, duration * 0.35)
	tween.tween_property(target_node, "scale", base_scale, duration * 0.65)

func _update_role_idle_visual(_delta: float) -> void:
	var visual_root := get_node_or_null("RoleVisualRoot") as Node2D
	if visual_root == null:
		return
	var sprite := visual_root.get_node_or_null("RoleSprite") as Sprite2D
	if sprite == null:
		return

	var role_id := str(_get_active_role()["id"])
	var base_position: Vector2 = sprite.get_meta("base_position", Vector2(0.0, -4.0))
	var bob_strength := 1.4
	var tilt := 0.0
	match role_id:
		"swordsman":
			bob_strength = 1.6
			tilt = 0.03 * sign(facing_direction.x)
		"gunner":
			bob_strength = 1.1
			tilt = 0.018 * sign(facing_direction.x)
		"mage":
			bob_strength = 2.0
			tilt = 0.012 * sin(role_visual_time * 2.8)

	sprite.position = base_position + Vector2(0.0, sin(role_visual_time * 4.4) * bob_strength)
	sprite.rotation = tilt
	if role_id in ["swordsman", "gunner", "mage"]:
		sprite.flip_h = facing_direction.x < 0.0

func _activate_switch_power(role_id: String, label: String, duration: float, damage_multiplier: float, interval_bonus: float) -> void:
	switch_power_role_id = role_id
	switch_power_label = label
	switch_power_remaining = duration
	switch_power_damage_multiplier = damage_multiplier
	switch_power_interval_bonus = interval_bonus
	_update_fire_timer()

func _queue_next_entry_blessing(source_role_id: String) -> void:
	pending_entry_blessing_source_role_id = source_role_id

func _apply_pending_entry_blessing(target_role_id: String) -> void:
	if pending_entry_blessing_source_role_id == "":
		return

	var legacy_level := _get_card_level("combat_legacy")

	match pending_entry_blessing_source_role_id:
		"swordsman":
			entry_blessing_role_id = target_role_id
			entry_blessing_label = "\u8840\u5203\u5438\u6536"
			entry_blessing_remaining = EXIT_SWORD_LIFESTEAL_DURATION + legacy_level * 0.8
			entry_lifesteal_ratio = EXIT_SWORD_LIFESTEAL_RATIO + legacy_level * 0.03
			entry_haste_interval_bonus = 0.0
			entry_haste_move_speed_multiplier = 1.0
			_spawn_combat_tag(global_position + Vector2(0.0, -48.0), "\u5438\u8840 +14%", Color(1.0, 0.58, 0.48, 1.0))
		"gunner":
			entry_blessing_role_id = target_role_id
			entry_blessing_label = "\u6218\u672F\u8FC7\u8F7D"
			entry_blessing_remaining = EXIT_GUNNER_HASTE_DURATION + legacy_level * 0.6
			entry_lifesteal_ratio = 0.0
			entry_haste_interval_bonus = EXIT_GUNNER_ATTACK_INTERVAL_BONUS + legacy_level * 0.02
			entry_haste_move_speed_multiplier = EXIT_GUNNER_MOVE_SPEED_MULTIPLIER + legacy_level * 0.04
			_spawn_combat_tag(global_position + Vector2(0.0, -48.0), "\u653B\u901F+\u79FB\u901F", Color(1.0, 0.72, 0.42, 1.0))
		"mage":
			_grant_ultimate_seals(1 + min(1, legacy_level), "\u7B26\u5370\u4F20\u5BFC")

	pending_entry_blessing_source_role_id = ""
	_update_fire_timer()
	stats_changed.emit(get_stat_summary())

func _clear_entry_blessing() -> void:
	entry_blessing_role_id = ""
	entry_blessing_label = ""
	entry_blessing_remaining = 0.0
	entry_lifesteal_ratio = 0.0
	entry_haste_interval_bonus = 0.0
	entry_haste_move_speed_multiplier = 1.0
	_update_fire_timer()
	stats_changed.emit(get_stat_summary())

func _prepare_relay_window(from_role_index: int, to_role_index: int, exit_hits: int, entry_hits: int) -> void:
	if exit_hits <= 0 and entry_hits <= 0:
		relay_window_remaining = 0.0
		relay_ready_role_id = ""
		relay_from_role_id = ""
		relay_label = ""
		relay_bonus_pending = false
		return

	var from_role_id: String = str(roles[from_role_index]["id"])
	var to_role_id: String = str(roles[to_role_index]["id"])
	var from_role_name: String = str(roles[from_role_index]["name"])
	var to_role_name: String = str(roles[to_role_index]["name"])
	relay_window_remaining = 2.2 + _get_card_level("combat_relay") * 0.45
	relay_ready_role_id = to_role_id
	relay_from_role_id = from_role_id
	relay_label = "%s→%s" % [from_role_name, to_role_name]
	relay_bonus_pending = true
	_spawn_combat_tag(global_position + Vector2(0.0, -54.0), "\u63A5\u529B\u5F85\u547D", Color(1.0, 0.94, 0.62, 1.0))
	stats_changed.emit(get_stat_summary())

func _trigger_relay_success(role_id: String, hit_count: int) -> void:
	if not relay_bonus_pending:
		return
	if relay_window_remaining <= 0.0:
		return
	if role_id != relay_ready_role_id:
		return
	if hit_count <= 0:
		return

	var relay_level := _get_card_level("combat_relay")
	relay_bonus_pending = false
	var relay_energy: float = (7.0 + float(min(hit_count, 2)) * 1.6 + relay_level * 2.0) * energy_gain_multiplier
	_add_energy(relay_energy)
	_grant_ultimate_seals(1, "\u63A5\u529B\u7B26\u5370")
	switch_cooldown_remaining = max(0.0, switch_cooldown_remaining - (1.6 + relay_level * 0.35))
	switch_invulnerability_remaining = max(switch_invulnerability_remaining, 0.12)
	_activate_switch_power(role_id, "\u63A5\u529B\u8D85\u8F7D", 1.8 + relay_level * 0.25, 1.34 + relay_level * 0.06, 0.12 + relay_level * 0.02)
	_show_switch_banner("\u63A5\u529B", relay_label, Color(1.0, 0.9, 0.56, 1.0))
	_spawn_ring_effect(global_position, 68.0, Color(1.0, 0.9, 0.56, 0.72), 7.0, 0.18)
	relay_window_remaining = 0.0
	relay_ready_role_id = ""
	relay_from_role_id = ""
	relay_label = ""
	stats_changed.emit(get_stat_summary())

func _apply_switch_payoff(hit_count: int, energy_gain: float, cooldown_refund: float) -> void:
	if hit_count <= 0:
		return

	var relay_level := _get_card_level("combat_relay")
	var switch_energy: float = (energy_gain + float(min(hit_count, 2)) * 1.2 + relay_level * 0.8) * energy_gain_multiplier
	_add_energy(switch_energy)
	switch_cooldown_remaining = max(0.0, switch_cooldown_remaining - (cooldown_refund + relay_level * 0.12))
	_grant_ultimate_seals(1, "\u5207\u4EBA\u6210\u529F")

func _apply_role_share(source_role_id: String, damage_bonus: float, interval_bonus: float, range_bonus: float, skill_bonus: float) -> void:
	for role_data in roles:
		var target_role_id := str(role_data["id"])
		if target_role_id == source_role_id:
			continue
		var upgrade_data: Dictionary = role_upgrade_levels.get(target_role_id, {}).duplicate(true)
		upgrade_data["damage_bonus"] = float(upgrade_data.get("damage_bonus", 0.0)) + damage_bonus * ROLE_SHARE_DAMAGE_RATIO
		upgrade_data["interval_bonus"] = float(upgrade_data.get("interval_bonus", 0.0)) + interval_bonus * ROLE_SHARE_INTERVAL_RATIO
		upgrade_data["range_bonus"] = float(upgrade_data.get("range_bonus", 0.0)) + range_bonus * ROLE_SHARE_RANGE_RATIO
		upgrade_data["skill_bonus"] = float(upgrade_data.get("skill_bonus", 0.0)) + skill_bonus * ROLE_SHARE_SKILL_RATIO
		role_upgrade_levels[target_role_id] = upgrade_data

func _initialize_existing_role_shares() -> void:
	if role_share_initialized:
		return

	for role_data in roles:
		var role_id := str(role_data["id"])
		var upgrade_data: Dictionary = role_upgrade_levels.get(role_id, {})
		var special_data: Dictionary = _get_role_special_state(role_id)
		var role_level := int(upgrade_data.get("level", 0))
		var special_total := 0
		for value in special_data.values():
			special_total += int(value)
		if role_level <= 0 and special_total <= 0:
			continue
		_apply_role_share(role_id, role_level * 2.2 + special_total * 1.1, role_level * 0.04, role_level * 6.0 + special_total * 2.0, role_level * 0.1 + special_total * 0.05)

	role_share_initialized = true

func _show_switch_banner(prefix: String, title: String, color: Color) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var layer := CanvasLayer.new()
	layer.layer = 7
	current_scene.add_child(layer)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -170.0
	panel.offset_right = 170.0
	panel.offset_top = 68.0
	panel.offset_bottom = 122.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.8)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = color
	label.text = "%s  %s" % [prefix, title]
	panel.add_child(label)

	panel.scale = Vector2(0.84, 0.84)
	var tween := panel.create_tween()
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.12)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.48).set_delay(0.18)
	tween.tween_callback(layer.queue_free)

func _get_active_role() -> Dictionary:
	return roles[active_role_index]

func _get_current_move_speed() -> float:
	var role_id: String = str(_get_active_role()["id"])
	var move_speed: float = speed * float(_get_active_role()["speed_scale"])
	if entry_blessing_remaining > 0.0 and entry_blessing_role_id == role_id:
		move_speed *= entry_haste_move_speed_multiplier
	if _is_last_stand_active():
		move_speed *= 1.18
	if team_combo_remaining > 0.0:
		move_speed *= team_combo_move_multiplier
	if frenzy_remaining > 0.0 and frenzy_stacks > 0:
		move_speed *= 1.0 + 0.02 * frenzy_stacks
	return move_speed

func _get_role_damage(role_id: String) -> float:
	for role_data in roles:
		if role_data["id"] != role_id:
			continue
		var upgrade_data: Dictionary = role_upgrade_levels[role_id]
		var damage_amount := (float(role_data["damage"]) + float(upgrade_data["damage_bonus"])) * global_damage_multiplier
		damage_amount *= _get_story_style_damage_multiplier(role_id)
		if switch_power_remaining > 0.0 and switch_power_role_id == role_id:
			damage_amount *= switch_power_damage_multiplier
		if _is_last_stand_active():
			damage_amount *= 1.22
		if _has_elite_relic("elite_chain_overload") and role_id == str(_get_active_role().get("id", "")):
			damage_amount *= 0.92
		if standby_entry_remaining > 0.0 and standby_entry_role_id == role_id:
			damage_amount *= standby_entry_damage_multiplier
		if team_combo_remaining > 0.0:
			damage_amount *= team_combo_damage_multiplier
		if borrow_fire_remaining > 0.0 and borrow_fire_role_id == role_id:
			damage_amount *= borrow_fire_damage_multiplier
		if frenzy_remaining > 0.0 and frenzy_stacks > 0:
			damage_amount *= 1.0 + 0.015 * frenzy_stacks
		return damage_amount
	return 0.0

func _get_role_special_state(role_id: String) -> Dictionary:
	if not role_special_states.has(role_id):
		role_special_states[role_id] = {}
	return role_special_states[role_id]

func _get_role_detail_summary(role_id: String) -> String:
	var special_data: Dictionary = _get_role_special_state(role_id)
	match role_id:
		"swordsman":
			return "\u56DE\u65CB%d | \u7A7F\u950B%d | \u53CD\u51FB%d | \u8FFD\u65A9%d | \u6218\u7EBF%d | \u5B88\u52BF%d" % [
				int(special_data.get("crescent_level", 0)),
				int(special_data.get("thrust_level", 0)),
				int(special_data.get("counter_level", 0)),
				int(special_data.get("pursuit_level", 0)),
				int(special_data.get("blood_level", 0)),
				int(special_data.get("stance_level", 0))
			]
		"gunner":
			return "\u6563\u5C04%d | \u805A\u7126%d | \u652F\u63F4%d | \u5F39\u5E55%d | \u7EED\u884C%d | \u9501\u5B9A%d" % [
				int(special_data.get("scatter_level", 0)),
				int(special_data.get("focus_level", 0)),
				int(special_data.get("support_level", 0)),
				int(special_data.get("barrage_level", 0)),
				int(special_data.get("reload_level", 0)),
				int(special_data.get("lock_level", 0))
			]
		"mage":
			return "\u56DE\u54CD%d | \u51B0\u7EB9%d | \u652F\u63F4%d | \u98CE\u66B4%d | \u6D41\u8F6C%d | \u584C\u7F29%d" % [
				int(special_data.get("echo_level", 0)),
				int(special_data.get("frost_level", 0)),
				int(special_data.get("support_level", 0)),
				int(special_data.get("storm_level", 0)),
				int(special_data.get("flow_level", 0)),
				int(special_data.get("gravity_level", 0))
			]
		_:
			return ""

func _get_role_route_summary(role_id: String) -> String:
	var special_data: Dictionary = _get_role_special_state(role_id)
	match role_id:
		"swordsman":
			var crescent_level := int(special_data.get("crescent_level", 0))
			var thrust_level := int(special_data.get("thrust_level", 0))
			var sustain_score := int(special_data.get("counter_level", 0)) + int(special_data.get("blood_level", 0)) + int(special_data.get("stance_level", 0))
			if crescent_level >= 2 and crescent_level >= thrust_level and crescent_level >= sustain_score:
				return "\u8D34\u8EAB\u7EDE\u6740"
			if thrust_level >= 2 and thrust_level > crescent_level and thrust_level >= sustain_score:
				return "\u8FD1\u8DDD\u5904\u51B3"
			if sustain_score >= 4:
				return "\u5438\u8840\u786C\u6297"
			return "\u8D34\u8138\u524D\u538B"
		"gunner":
			var scatter_level := int(special_data.get("scatter_level", 0))
			var focus_level := int(special_data.get("focus_level", 0))
			var support_score := int(special_data.get("support_level", 0)) + int(special_data.get("reload_level", 0))
			var lock_score := focus_level + int(special_data.get("lock_level", 0))
			if scatter_level >= 2 and scatter_level >= focus_level and scatter_level >= support_score:
				return "\u8FDC\u7A0B\u5C01\u9501"
			if lock_score >= 4 and lock_score >= scatter_level and lock_score >= support_score:
				return "\u5B9A\u70B9\u72D9\u6740"
			if focus_level >= 2 and focus_level > scatter_level and focus_level >= support_score:
				return "\u8FDC\u8DDD\u72D9\u6740"
			if support_score >= 3:
				return "\u8FFD\u730E\u538B\u5236"
			return "\u8FDC\u8DDD\u70B9\u5C04"
		"mage":
			var echo_score := int(special_data.get("echo_level", 0)) + int(special_data.get("storm_level", 0))
			var frost_score := int(special_data.get("frost_level", 0)) + int(special_data.get("support_level", 0))
			var gravity_score := frost_score + int(special_data.get("gravity_level", 0))
			var flow_level := int(special_data.get("flow_level", 0))
			if echo_score >= 3 and echo_score >= frost_score:
				return "\u8FDE\u7206\u5171\u9E23"
			if gravity_score >= 4 and gravity_score >= echo_score:
				return "\u584C\u7F29\u63A7\u573A"
			if frost_score >= 3 and frost_score > echo_score:
				return "\u51B0\u57DF\u63A7\u573A"
			if flow_level >= 2:
				return "\u6CD5\u6F6E\u5FAA\u73AF"
			return "\u5747\u8861\u79D8\u6CD5"
		_:
			return ""

func _get_role_core_summary(role_id: String) -> String:
	match role_id:
		"swordsman":
			return "\u56FA\u6709 \u8D34\u8EAB\u7834\u950B"
		"gunner":
			return "\u56FA\u6709 \u8FDC\u8DDD\u8FFD\u730E"
		"mage":
			return "\u56FA\u6709 \u5E7F\u57DF\u56DE\u54CD"
		_:
			return ""

func _get_slot_resonance_summary() -> String:
	var labels := {
		"body": _get_upgrade_slot_label("body"),
		"combat": _get_upgrade_slot_label("combat"),
		"skill": _get_upgrade_slot_label("skill")
	}
	var parts: Array[String] = []
	for slot_id in ["body", "combat", "skill"]:
		var tier_text := "-"
		if _is_slot_resonance_unlocked(slot_id, SLOT_RESONANCE_SECOND_THRESHOLD):
			tier_text = "6"
		elif _is_slot_resonance_unlocked(slot_id, SLOT_RESONANCE_FIRST_THRESHOLD):
			tier_text = "3"
		parts.append("%s:%s" % [str(labels[slot_id]), tier_text])
	return "共鸣进度 %s" % " | ".join(parts)

func _get_closest_enemy() -> Node2D:
	var closest_enemy: Node2D
	var closest_distance: float = INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy
	return closest_enemy

func _get_farthest_enemy() -> Node2D:
	var farthest_enemy: Node2D
	var farthest_distance: float = 0.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance > farthest_distance:
			farthest_distance = distance
			farthest_enemy = enemy
	return farthest_enemy

func _get_enemy_targets(count: int, prefer_farthest: bool = false) -> Array:
	var enemies: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		enemies.append(enemy)

	if prefer_farthest:
		enemies.sort_custom(func(a, b): return global_position.distance_to(a.global_position) > global_position.distance_to(b.global_position))
	else:
		enemies.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))

	return enemies.slice(0, min(count, enemies.size()))

func _get_low_health_enemy() -> Node2D:
	var selected_enemy: Node2D
	var lowest_ratio: float = 1.1
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_health: float = float(enemy.get("current_health"))
		var enemy_max_health: float = max(float(enemy.get("max_health")), 1.0)
		var ratio: float = enemy_health / enemy_max_health
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			selected_enemy = enemy
	return selected_enemy

func _get_enemy_in_aim_cone(max_angle_degrees: float, max_distance: float = INF) -> Node2D:
	var selected_enemy: Node2D
	var best_score: float = -INF
	var max_dot: float = cos(deg_to_rad(max_angle_degrees))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		var distance: float = to_enemy.length()
		if distance <= 0.001 or distance > max_distance:
			continue
		var direction_dot: float = facing_direction.dot(to_enemy.normalized())
		if direction_dot < max_dot:
			continue
		var score: float = direction_dot * 1000.0 - distance
		if score > best_score:
			best_score = score
			selected_enemy = enemy
	return selected_enemy

func _get_enemy_cluster_center() -> Vector2:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return Vector2.ZERO

	var best_center := Vector2.ZERO
	var best_score: int = 0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var center: Vector2 = enemy.global_position
		var score: int = 0
		for other_enemy in enemies:
			if not is_instance_valid(other_enemy):
				continue
			if center.distance_to(other_enemy.global_position) <= 90.0:
				score += 1
		if score > best_score:
			best_score = score
			best_center = center
	return best_center

func _get_random_enemy_cluster_centers(count: int) -> Array:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return [global_position]

	var scored_centers: Array = []
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var center: Vector2 = enemy.global_position
		var score: int = 0
		for other_enemy in enemies:
			if not is_instance_valid(other_enemy):
				continue
			if center.distance_to(other_enemy.global_position) <= 120.0:
				score += 1
		scored_centers.append({
			"center": center,
			"score": score
		})

	scored_centers.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	var candidate_pool: Array = scored_centers.slice(0, min(6, scored_centers.size()))
	var picked_centers: Array = []
	while picked_centers.size() < count and not candidate_pool.is_empty():
		var chosen_index: int = randi() % candidate_pool.size()
		var chosen_center: Vector2 = candidate_pool[chosen_index]["center"]
		candidate_pool.remove_at(chosen_index)
		var too_close := false
		for picked_center in picked_centers:
			if chosen_center.distance_to(picked_center) < 48.0:
				too_close = true
				break
		if too_close:
			continue
		picked_centers.append(chosen_center)

	if picked_centers.is_empty():
		picked_centers.append(_get_enemy_cluster_center())
	while picked_centers.size() < count:
		picked_centers.append(picked_centers[picked_centers.size() - 1])
	return picked_centers

func _collect_nearby_gems() -> void:
	var pickup_radius_squared: float = pickup_radius * pickup_radius
	for gem in get_tree().get_nodes_in_group("exp_gems"):
		if not is_instance_valid(gem):
			continue
		if global_position.distance_squared_to(gem.global_position) <= pickup_radius_squared:
			if gem.has_method("collect"):
				var gained_experience: int = gem.collect()
				gain_experience(gained_experience)

	for heart_pickup in get_tree().get_nodes_in_group("heart_pickups"):
		if not is_instance_valid(heart_pickup):
			continue
		if global_position.distance_squared_to(heart_pickup.global_position) <= pickup_radius_squared:
			if heart_pickup.has_method("collect"):
				var healed_amount: float = heart_pickup.collect()
				_heal(healed_amount)

func _check_enemy_contact_damage() -> void:
	if hurt_cooldown_remaining > 0.0 or switch_invulnerability_remaining > 0.0:
		return

	var hurtbox_center := get_hurtbox_center()
	var hurtbox_radius := get_hurtbox_radius()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var contact_radius: float = 36.0
		var touch_damage: float = 10.0
		var enemy_contact_radius = enemy.get("contact_radius")
		var enemy_touch_damage = enemy.get("touch_damage")
		if enemy_contact_radius != null:
			contact_radius = float(enemy_contact_radius)
		if enemy_touch_damage != null:
			touch_damage = float(enemy_touch_damage)
		var combined_radius := contact_radius + hurtbox_radius
		if hurtbox_center.distance_squared_to(enemy.global_position) <= combined_radius * combined_radius:
			take_damage(touch_damage)
			break

func gain_experience(amount: int) -> void:
	experience += amount

	while experience >= experience_to_next_level:
		experience -= experience_to_next_level
		level += 1
		experience_to_next_level = int(round(experience_to_next_level * 1.42)) + 10
		pending_level_ups += 1

	experience_changed.emit(experience, experience_to_next_level, level)
	_try_request_level_up()

func take_damage(amount: float) -> void:
	if DEVELOPER_MODE.should_ignore_damage():
		return
	if is_dead or switch_invulnerability_remaining > 0.0:
		return

	var swordsman_counter_level := 0
	if _get_active_role()["id"] == "swordsman":
		swordsman_counter_level = int(_get_role_special_state("swordsman").get("counter_level", 0))
		var nearby_enemy_count := _count_enemies_in_radius(get_hurtbox_center(), 62.0)
		if nearby_enemy_count > 0:
			amount *= max(0.84, 0.96 - min(nearby_enemy_count, 3) * 0.04)
		if swordsman_counter_level > 0:
			amount *= max(0.76, 0.92 - swordsman_counter_level * 0.04)

	current_health = max(0.0, current_health - amount * _get_effective_damage_taken_multiplier())
	hurt_cooldown_remaining = hurt_cooldown
	health_changed.emit(current_health, max_health)
	_play_player_hurt_feedback()

	if current_health > 0.0 and _get_active_role()["id"] == "swordsman":
		_trigger_swordsman_counter()

	if current_health <= 0.0:
		_die()

func _add_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	current_mana = min(max_mana, current_mana + amount)
	if _has_elite_relic("elite_reactor") and is_equal_approx(current_mana, max_mana):
		_activate_switch_power(str(_get_active_role().get("id", "")), "\u6EE1\u80FD\u53CD\u5E94", 2.8, 1.14, 0.04)
	mana_changed.emit(current_mana, max_mana)

func _get_ultimate_energy_cost() -> float:
	if DEVELOPER_MODE.should_unlock_ultimate_freely():
		return 0.0
	if _has_elite_relic("elite_perpetual_motion"):
		return 0.0
	return min(max_mana, ULTIMATE_COST * ultimate_cost_multiplier)

func _can_use_ultimate() -> bool:
	if DEVELOPER_MODE.should_unlock_ultimate_freely():
		return true
	if current_ultimate_seals < ULTIMATE_SEAL_MAX:
		return false
	if _has_elite_relic("elite_perpetual_motion"):
		return perpetual_motion_cooldown_remaining <= 0.0
	return current_mana >= _get_ultimate_energy_cost()

func _build_ultimate_cast_payload() -> Dictionary:
	var duration_multiplier := 1.0
	var damage_multiplier := _get_ultimate_level_damage_multiplier()
	if DEVELOPER_MODE.should_unlock_ultimate_freely():
		return {
			"damage_multiplier": damage_multiplier,
			"duration_multiplier": duration_multiplier,
			"boost_units": 0
		}
	if _has_elite_relic("elite_perpetual_motion"):
		var consumed_mana := current_mana
		current_mana = 0.0
		var boost_units: int = min(4, int(floor(min(consumed_mana, 60.0) / 15.0)))
		damage_multiplier += 0.06 * boost_units
		duration_multiplier += 0.04 * boost_units
		perpetual_motion_cooldown_remaining = 26.0
		mana_changed.emit(current_mana, max_mana)
		return {
			"damage_multiplier": damage_multiplier,
			"duration_multiplier": duration_multiplier,
			"boost_units": boost_units
		}
	return {
		"damage_multiplier": damage_multiplier,
		"duration_multiplier": duration_multiplier,
		"boost_units": 0
	}

func _get_ultimate_level_damage_multiplier() -> float:
	var bonus_levels: int = max(0, level - 1)
	return min(1.32, 1.0 + float(bonus_levels) * 0.015)

func _grant_ultimate_seals(amount: int, source_label: String = "") -> void:
	if amount <= 0:
		return

	var previous_seals: int = current_ultimate_seals
	current_ultimate_seals = min(ULTIMATE_SEAL_MAX, current_ultimate_seals + amount)
	if current_ultimate_seals == previous_seals:
		return

	if source_label != "":
		_spawn_combat_tag(global_position + Vector2(0.0, -44.0), source_label, Color(1.0, 0.92, 0.56, 1.0))
	mana_changed.emit(current_mana, max_mana)

func grant_ultimate_seals(amount: int = 1, source_label: String = "") -> void:
	_grant_ultimate_seals(amount, source_label)

func _register_attack_result(role_id: String, hit_count: int, killed: bool) -> void:
	_trigger_relay_success(role_id, hit_count)
	_apply_entry_lifesteal(role_id, hit_count, killed)
	if hit_count > 0 and _get_card_level("battle_chain") > 0:
		_trigger_chain_reaction(role_id)
	if hit_count >= 2 and _get_card_level("battle_tide") > 0:
		_trigger_clean_tide(role_id)
	if killed and _has_elite_relic("elite_execution_pact") and not execution_pact_burst_active:
		execution_pact_burst_active = true
		_spawn_burst_effect(global_position + facing_direction * 20.0, 42.0, Color(1.0, 0.62, 0.4, 0.16), 0.16)
		_damage_enemies_in_radius(global_position + facing_direction * 20.0, 42.0, _get_role_damage(role_id) * 0.34, 0.0, 1.0, 0.0)
		execution_pact_burst_active = false
	if killed and _has_elite_relic("elite_battle_frenzy"):
		var previous_stacks := frenzy_stacks
		frenzy_stacks = min(8, frenzy_stacks + 1)
		frenzy_remaining = 5.0
		if previous_stacks < 8 and frenzy_stacks >= 8:
			_grant_ultimate_seals(1, "狂热满层")
		elif frenzy_stacks >= 8:
			frenzy_overkill_counter += 1
			if frenzy_overkill_counter >= 6:
				frenzy_overkill_counter = 0
				_add_energy(6.0)
	var effective_hits: int = min(hit_count, 1)
	var energy_amount: float = float(effective_hits) * ENERGY_PER_HIT * energy_gain_multiplier
	if killed:
		energy_amount += ENERGY_PER_KILL * energy_gain_multiplier

	if role_id == "gunner":
		var special_data: Dictionary = _get_role_special_state("gunner")
		var reload_level: int = int(special_data.get("reload_level", 0))
		if reload_level > 0:
			energy_amount += float(effective_hits) * 0.12 * reload_level
			if killed:
				energy_amount += 0.35 * reload_level
	elif role_id == "mage":
		var special_data: Dictionary = _get_role_special_state("mage")
		var flow_level: int = int(special_data.get("flow_level", 0))
		if flow_level > 0:
			energy_amount += float(effective_hits) * 0.1 * flow_level
			if killed:
				energy_amount += 0.3 * flow_level

	_add_energy(energy_amount)

func _apply_entry_lifesteal(role_id: String, hit_count: int, killed: bool) -> void:
	if entry_blessing_remaining <= 0.0:
		return
	if entry_blessing_role_id != role_id:
		return
	if entry_lifesteal_ratio <= 0.0 or hit_count <= 0:
		return

	var capped_hits: int = min(hit_count, 6)
	var estimated_damage: float = _get_role_damage(role_id) * float(capped_hits) * 0.55
	if killed:
		estimated_damage += _get_role_damage(role_id) * 0.35
	var heal_amount: float = estimated_damage * entry_lifesteal_ratio
	if heal_amount > 0.0:
		_heal(heal_amount)

func _heal(amount: float) -> void:
	if amount <= 0.0 or is_dead:
		return
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func _trigger_chain_reaction(role_id: String) -> void:
	var chain_level := _get_card_level("battle_chain")
	if chain_level <= 0 or chain_reaction_active:
		return
	chain_reaction_active = true
	var search_center := global_position + facing_direction * 28.0
	var search_radius := 220.0
	var bounce_count := 1 if chain_level == 1 else 2
	var chain_damage_ratio: float = [0.45, 0.55, 0.65][chain_level - 1]
	var previous_target: Node2D = null
	var from_position := search_center
	for bounce_index in range(bounce_count):
		var chosen_target: Node2D = null
		var best_distance := search_radius
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			if enemy == previous_target:
				continue
			var distance := from_position.distance_to(enemy.global_position)
			if distance > best_distance:
				continue
			best_distance = distance
			chosen_target = enemy
		if chosen_target == null:
			break
		_spawn_dash_line_effect(from_position, chosen_target.global_position, Color(0.92, 0.56, 1.0, 0.9), 6.0, 0.1)
		_spawn_target_lock_effect(chosen_target.global_position, 18.0 + chain_level * 4.0, Color(0.92, 0.56, 1.0, 0.76), 0.12)
		_spawn_burst_effect(chosen_target.global_position, 22.0 + chain_level * 4.0, Color(0.72, 0.38, 1.0, 0.2), 0.12)
		var chain_kill := _deal_damage_to_enemy(chosen_target, _get_role_damage(role_id) * chain_damage_ratio, role_id, 0.02 * chain_level, 1.8, 1.0, 0.0)
		_register_attack_result(role_id, 1, chain_kill)
		previous_target = chosen_target
		from_position = chosen_target.global_position
	if chain_level >= 3:
		_add_energy(2.0)
	chain_reaction_active = false

func _trigger_clean_tide(role_id: String) -> void:
	var tide_level := _get_card_level("battle_tide")
	if tide_level <= 0 or clean_tide_active:
		return
	clean_tide_active = true
	var tide_radius: float = [32.0, 40.0, 48.0][tide_level - 1]
	var tide_damage_ratio: float = [0.45, 0.55, 0.65][tide_level - 1]
	var tide_center: Vector2 = global_position + facing_direction * (28.0 + tide_radius * 0.4)
	_spawn_ring_effect(tide_center, tide_radius * 1.2, Color(0.3, 0.92, 1.0, 0.76), 6.0, 0.16)
	_spawn_burst_effect(tide_center, tide_radius * 1.08, Color(0.18, 0.84, 1.0, 0.2), 0.14)
	var slow_multiplier := 1.0
	var slow_duration := 0.0
	if tide_level >= 2:
		slow_multiplier = 0.8
		slow_duration = 0.8
	var tide_hits := _damage_enemies_in_radius(tide_center, tide_radius, _get_role_damage(role_id) * tide_damage_ratio, 0.0, slow_multiplier, slow_duration)
	if tide_hits > 0:
		_register_attack_result(role_id, tide_hits, false)
	if tide_level >= 3:
		_add_energy(6.0)
	clean_tide_active = false

func _spawn_attack_aftershock(center: Vector2, role_id: String) -> void:
	var aftershock_level := _get_card_level("battle_aftershock")
	if aftershock_level <= 0:
		return
	var level_index: int = clamp(aftershock_level - 1, 0, 2)
	var radius: float = [48.0, 64.0, 80.0][level_index]
	var damage_ratio: float = [0.35, 0.45, 0.55][level_index]
	var pulse_count := 2 if aftershock_level == 1 else 3
	if _is_final_set_complete("battle_domain"):
		radius += 10.0
		damage_ratio += 0.06
		pulse_count += 1
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var controller := Node2D.new()
	controller.name = "AttackAftershockController"
	current_scene.add_child(controller)
	var tween := controller.create_tween()
	for pulse_index in range(pulse_count):
		if pulse_index > 0:
			tween.tween_interval(0.12)
		tween.tween_callback(func() -> void:
			var current_radius: float = radius + pulse_index * 14.0
			var current_damage: float = _get_role_damage(role_id) * damage_ratio
			var accent := _get_role_theme_color(role_id)
			_spawn_ring_effect(center, current_radius, Color(min(1.0, accent.r + 0.14), min(1.0, accent.g + 0.14), min(1.0, accent.b + 0.18), 0.88), 8.0, 0.2)
			_spawn_burst_effect(center, current_radius * 0.94, Color(accent.r, accent.g, accent.b, 0.26), 0.18)
			match role_id:
				"swordsman":
					var angle_shift := pulse_index * 0.18
					_spawn_crescent_wave_effect(center, Vector2.RIGHT.rotated(angle_shift), current_radius * 0.96, Color(0.24, 0.94, 1.0, 0.7), 0.2, 220.0, 18.0 + pulse_index * 4.0)
					_spawn_crescent_wave_effect(center, Vector2.RIGHT.rotated(PI + angle_shift), current_radius * 0.82, Color(1.0, 0.2, 0.16, 0.48), 0.18, 200.0, 14.0 + pulse_index * 3.0)
				"gunner":
					_spawn_radial_rays_effect(center, current_radius * 1.06, 8 + aftershock_level * 2 + pulse_index * 2, Color(1.0, 0.66, 0.34, 0.7), 4.0 + pulse_index, 0.2, pulse_index * 0.14)
				"mage":
					_spawn_frost_sigils_effect(center, current_radius * 0.76, Color(0.9, 0.98, 1.0, 0.84), 0.2)
					_spawn_vortex_effect(center, current_radius * 0.42, Color(0.72, 0.8, 1.0, 0.34), 0.2)
			var slow_multiplier := 1.0
			var slow_duration := 0.0
			if aftershock_level >= 2:
				slow_multiplier = 0.75
				slow_duration = 1.0
			var shock_hits := _damage_enemies_in_radius(center, current_radius, current_damage, 0.0, slow_multiplier, slow_duration)
			if shock_hits > 0:
				_register_attack_result(role_id, shock_hits, false)
		)
	tween.tween_callback(controller.queue_free)

func _play_player_hurt_feedback() -> void:
	_queue_camera_shake(6.0, 0.16)
	_pulse_player_visual(1.18, 0.16)
	_spawn_burst_effect(get_hurtbox_center(), 54.0, Color(1.0, 0.3, 0.3, 0.18), 0.16)

func _trigger_swordsman_counter() -> void:
	var special_data: Dictionary = _get_role_special_state("swordsman")
	var counter_level: int = int(special_data.get("counter_level", 0))
	if counter_level <= 0:
		return

	var radius: float = 62.0 + counter_level * 14.0
	var damage_amount: float = _get_role_damage("swordsman") * (0.38 + counter_level * 0.14)
	_spawn_combat_tag(global_position + Vector2(0.0, -24.0), "\u53CD\u51FB", Color(1.0, 0.84, 0.48, 1.0))
	_spawn_guard_effect(global_position, radius, Color(1.0, 0.84, 0.46, 0.22), 0.18)
	_spawn_burst_effect(global_position, radius, Color(1.0, 0.76, 0.38, 0.22), 0.16)
	var hits: int = _damage_enemies_in_radius(global_position, radius, damage_amount, 0.08 * counter_level, 1.0, 0.0)
	if hits > 0:
		_register_attack_result("swordsman", hits, false)
		_heal(1.2 + counter_level * 0.5)
		switch_invulnerability_remaining = max(switch_invulnerability_remaining, 0.05 + counter_level * 0.02)

func _count_enemies_in_radius(center: Vector2, radius: float) -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if center.distance_to(enemy.global_position) <= radius:
			count += 1
	return count

func _record_card_pick(slot_id: String, option_id: String) -> void:
	card_pick_levels[option_id] = _get_card_level(option_id) + 1
	_record_build_pick(slot_id)
	var config := _get_build_card_config(option_id)
	if not config.is_empty():
		_announce_completed_final_set(str(config.get("set_key", "")))

func _apply_battle_card(option_id: String) -> bool:
	match option_id:
		"battle_dangzhen_qichao":
			_record_card_pick("body", option_id)
			return true
		"battle_dangzhen_dielang":
			_record_card_pick("body", option_id)
			return true
		"battle_dangzhen_huichao":
			_record_card_pick("body", option_id)
			return true
		"battle_cover":
			_record_card_pick("body", option_id)
			_apply_team_role_bonus(1.5, 0.0, 10.0, 0.04)
			_increase_team_specials([
				{"role_id": "swordsman", "key": "crescent_level"},
				{"role_id": "gunner", "key": "scatter_level"},
				{"role_id": "mage", "key": "frost_level"}
			])
			return true
		"battle_tempo":
			_record_card_pick("body", option_id)
			_apply_team_role_bonus(0.0, FIRE_RATE_STEP * 0.8, 0.0, 0.0)
			return true
		"battle_split":
			_record_card_pick("body", option_id)
			_apply_team_role_bonus(1.2, 0.0, 4.0, 0.06)
			_increase_team_specials([
				{"role_id": "swordsman", "key": "crescent_level"},
				{"role_id": "gunner", "key": "scatter_level"},
				{"role_id": "mage", "key": "echo_level"}
			])
			return true
		"battle_devour":
			_record_card_pick("body", option_id)
			_increase_team_specials([
				{"role_id": "swordsman", "key": "blood_level"},
				{"role_id": "gunner", "key": "reload_level"},
				{"role_id": "mage", "key": "flow_level"}
			])
			max_health += 8.0
			current_health = min(max_health, current_health + 10.0)
			current_mana = min(max_mana, current_mana + 8.0)
			health_changed.emit(current_health, max_health)
			mana_changed.emit(current_mana, max_mana)
			return true
		"battle_suppress":
			_record_card_pick("body", option_id)
			_apply_team_role_bonus(1.0, 0.0, 6.0, 0.08)
			damage_taken_multiplier = max(0.58, damage_taken_multiplier - 0.03)
			_increase_team_specials([
				{"role_id": "swordsman", "key": "stance_level"},
				{"role_id": "gunner", "key": "lock_level"},
				{"role_id": "mage", "key": "frost_level"}
			])
			return true
		"battle_hunt":
			_record_card_pick("body", option_id)
			_apply_team_role_bonus(2.4, 0.0, 6.0, 0.08)
			_increase_team_specials([
				{"role_id": "swordsman", "key": "thrust_level"},
				{"role_id": "gunner", "key": "focus_level"},
				{"role_id": "mage", "key": "gravity_level"}
			])
			return true
		"battle_focus":
			_record_card_pick("body", option_id)
			_apply_team_role_bonus(3.4, 0.02, 8.0, 0.1)
			return true
		"battle_overload":
			_record_card_pick("body", option_id)
			_apply_team_role_bonus(1.8, 0.0, 0.0, 0.04)
			return true
		"battle_chain":
			_record_card_pick("body", option_id)
			return true
		"battle_break":
			_record_card_pick("body", option_id)
			return true
		"battle_tide":
			_record_card_pick("body", option_id)
			return true
		"battle_aftershock":
			_record_card_pick("body", option_id)
			return true
		_:
			return false

func _apply_combat_card(option_id: String) -> bool:
	match option_id:
		"combat_tuning":
			_record_card_pick("combat", option_id)
			role_switch_cooldown_bonus += 0.45
			switch_cooldown_remaining = max(0.0, switch_cooldown_remaining - 1.0)
			return true
		"combat_assault":
			_record_card_pick("combat", option_id)
			_apply_team_role_bonus(1.4, 0.0, 4.0, 0.08)
			return true
		"combat_legacy":
			_record_card_pick("combat", option_id)
			max_health += 6.0
			current_health = min(max_health, current_health + 8.0)
			health_changed.emit(current_health, max_health)
			return true
		"combat_relay":
			_record_card_pick("combat", option_id)
			role_switch_cooldown_bonus += 0.12
			return true
		"combat_support":
			_record_card_pick("combat", option_id)
			background_interval_multiplier = max(0.5, background_interval_multiplier - 0.08)
			_increase_role_special("gunner", "support_level", 1)
			_increase_role_special("mage", "support_level", 1)
			return true
		"combat_resonance":
			_record_card_pick("combat", option_id)
			global_damage_multiplier += 0.04
			role_switch_cooldown_bonus += 0.18
			_apply_team_role_bonus(1.2, 0.0, 3.0, 0.06)
			return true
		"combat_symbol":
			_record_card_pick("combat", option_id)
			current_mana = min(max_mana, current_mana + 10.0)
			mana_changed.emit(current_mana, max_mana)
			return true
		"combat_fixed_axis":
			_record_card_pick("combat", option_id)
			global_damage_multiplier += 0.08
			background_interval_multiplier = max(0.45, background_interval_multiplier - 0.1)
			return true
		"combat_swap":
			_record_card_pick("combat", option_id)
			return true
		"combat_rotation":
			_record_card_pick("combat", option_id)
			return true
		"combat_synergy":
			_record_card_pick("combat", option_id)
			return true
		"combat_rearguard":
			_record_card_pick("combat", option_id)
			return true
		_:
			return false

func _apply_skill_card(option_id: String) -> bool:
	match option_id:
		"skill_energy_loop":
			_record_card_pick("skill", option_id)
			energy_gain_multiplier += 0.12
			return true
		"skill_tuning":
			_record_card_pick("skill", option_id)
			ultimate_cost_multiplier = max(0.58, ultimate_cost_multiplier - 0.06)
			current_mana = min(max_mana, current_mana + 12.0)
			mana_changed.emit(current_mana, max_mana)
			return true
		"skill_blossom":
			_record_card_pick("skill", option_id)
			_increase_team_specials([
				{"role_id": "swordsman", "key": "pursuit_level"},
				{"role_id": "gunner", "key": "barrage_level"},
				{"role_id": "mage", "key": "storm_level"}
			])
			current_mana = min(max_mana, current_mana + 8.0)
			mana_changed.emit(current_mana, max_mana)
			return true
		"skill_reprise":
			_record_card_pick("skill", option_id)
			_grant_ultimate_seals(1, "\u518D\u6F14")
			return true
		"skill_afterglow":
			_record_card_pick("skill", option_id)
			_apply_team_role_bonus(1.6, 0.02, 4.0, 0.08)
			return true
		"skill_charge":
			_record_card_pick("skill", option_id)
			max_mana += 10.0
			current_mana = min(max_mana, current_mana + 15.0)
			mana_changed.emit(current_mana, max_mana)
			return true
		"skill_resonance":
			_record_card_pick("skill", option_id)
			background_interval_multiplier = max(0.5, background_interval_multiplier - 0.05)
			role_switch_cooldown_bonus += 0.25
			_grant_ultimate_seals(1, "\u5171\u632F")
			return true
		"skill_overdrive":
			_record_card_pick("skill", option_id)
			current_mana = min(max_mana, current_mana + 22.0)
			mana_changed.emit(current_mana, max_mana)
			_grant_ultimate_seals(1, "\u8D85\u8F7D")
			return true
		"skill_extend":
			_record_card_pick("skill", option_id)
			return true
		"skill_finale":
			_record_card_pick("skill", option_id)
			return true
		"skill_borrow_fire":
			_record_card_pick("skill", option_id)
			return true
		"skill_reflux":
			_record_card_pick("skill", option_id)
			return true
		_:
			return false

func apply_upgrade(option_id: String) -> void:
	var role_id: String = _get_active_role()["id"]
	var role_data: Dictionary = role_upgrade_levels[role_id]
	var special_data: Dictionary = _get_role_special_state(role_id)

	if _apply_battle_card(option_id) or _apply_combat_card(option_id) or _apply_skill_card(option_id):
		level_up_active = false
		_update_fire_timer()
		stats_changed.emit(get_stat_summary())
		_try_request_level_up()
		return

	match option_id:
		"body_move_speed", "move_speed":
			_record_build_pick("body")
			speed += MOVE_SPEED_STEP
		"body_vitality":
			_record_build_pick("body")
			max_health += HEALTH_STEP
			current_health = min(max_health, current_health + HEALTH_STEP)
			health_changed.emit(current_health, max_health)
		"body_pickup_range", "pickup_range":
			_record_build_pick("body")
			pickup_radius += PICKUP_RANGE_STEP
		"body_guard":
			_record_build_pick("body")
			damage_taken_multiplier = max(0.55, damage_taken_multiplier - DAMAGE_REDUCTION_STEP)
		"combat_move_speed":
			_record_build_pick("combat")
			speed += MOVE_SPEED_STEP
		"combat_vitality":
			_record_build_pick("combat")
			max_health += HEALTH_STEP
			current_health = min(max_health, current_health + HEALTH_STEP)
			health_changed.emit(current_health, max_health)
		"combat_pickup_range":
			_record_build_pick("combat")
			pickup_radius += PICKUP_RANGE_STEP
		"combat_guard":
			_record_build_pick("combat")
			damage_taken_multiplier = max(0.55, damage_taken_multiplier - DAMAGE_REDUCTION_STEP)
		"body_sword_blood":
			_record_build_pick("body")
			special_data["blood_level"] = int(special_data.get("blood_level", 0)) + 1
			max_health += 10.0
			damage_taken_multiplier = max(0.58, damage_taken_multiplier - 0.03)
			_heal(12.0)
		"body_gunner_reload":
			_record_build_pick("body")
			special_data["reload_level"] = int(special_data.get("reload_level", 0)) + 1
			speed += 6.0
			current_mana = min(max_mana, current_mana + 6.0)
			mana_changed.emit(current_mana, max_mana)
		"skill_gunner_overheat":
			_record_build_pick("skill")
			special_data["reload_level"] = int(special_data.get("reload_level", 0)) + 1
			speed += 6.0
			current_mana = min(max_mana, current_mana + 8.0)
			mana_changed.emit(current_mana, max_mana)
		"body_mage_flow":
			_record_build_pick("body")
			special_data["flow_level"] = int(special_data.get("flow_level", 0)) + 1
			max_mana += 8.0
			current_mana = min(max_mana, current_mana + 10.0)
			mana_changed.emit(current_mana, max_mana)
		"skill_mage_tidal_flow":
			_record_build_pick("skill")
			special_data["flow_level"] = int(special_data.get("flow_level", 0)) + 1
			max_mana += 8.0
			current_mana = min(max_mana, current_mana + 14.0)
			mana_changed.emit(current_mana, max_mana)
		"combat_team_power", "power_training":
			_record_build_pick("combat")
			global_damage_multiplier += 0.08
		"skill_energy_flow", "energy_flow":
			_record_build_pick("skill")
			energy_gain_multiplier += ENERGY_GAIN_STEP
		"combat_role_focus", "role_focus":
			_record_build_pick("body")
			role_data["level"] = int(role_data["level"]) + 1
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + DAMAGE_STEP
			if role_id == "swordsman":
				role_data["skill_bonus"] = float(role_data["skill_bonus"]) + 0.18
				damage_taken_multiplier = max(0.6, damage_taken_multiplier - 0.02)
			elif role_id == "gunner":
				role_data["range_bonus"] = float(role_data["range_bonus"]) + 12.0
				role_data["skill_bonus"] = float(role_data["skill_bonus"]) + 0.12
			else:
				role_data["range_bonus"] = float(role_data["range_bonus"]) + 10.0
				role_data["skill_bonus"] = float(role_data["skill_bonus"]) + 0.18
		"combat_rhythm", "rhythm_mastery":
			_record_build_pick("body")
			role_data["interval_bonus"] = float(role_data["interval_bonus"]) + FIRE_RATE_STEP
		"combat_role_range":
			_record_build_pick("body")
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 4.0
			role_data["range_bonus"] = float(role_data["range_bonus"]) + 14.0
		"combat_sword_crescent":
			_record_build_pick("body")
			special_data["crescent_level"] = int(special_data.get("crescent_level", 0)) + 1
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 2.5
			damage_taken_multiplier = max(0.58, damage_taken_multiplier - 0.015)
		"combat_sword_thrust":
			_record_build_pick("body")
			special_data["thrust_level"] = int(special_data.get("thrust_level", 0)) + 1
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 4.5
			_heal(4.0)
		"combat_gunner_scatter":
			_record_build_pick("body")
			special_data["scatter_level"] = int(special_data.get("scatter_level", 0)) + 1
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 2.0
			role_data["range_bonus"] = float(role_data["range_bonus"]) + 10.0
		"combat_gunner_focus":
			_record_build_pick("body")
			special_data["focus_level"] = int(special_data.get("focus_level", 0)) + 1
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 3.5
			role_data["range_bonus"] = float(role_data["range_bonus"]) + 14.0
		"combat_gunner_lock":
			_record_build_pick("body")
			special_data["lock_level"] = int(special_data.get("lock_level", 0)) + 1
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 2.5
			role_data["range_bonus"] = float(role_data["range_bonus"]) + 10.0
		"combat_mage_echo":
			_record_build_pick("body")
			special_data["echo_level"] = int(special_data.get("echo_level", 0)) + 1
			role_data["range_bonus"] = float(role_data["range_bonus"]) + 10.0
			role_data["skill_bonus"] = float(role_data["skill_bonus"]) + 0.08
		"combat_mage_frost":
			_record_build_pick("body")
			special_data["frost_level"] = int(special_data.get("frost_level", 0)) + 1
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 3.0
			role_data["range_bonus"] = float(role_data["range_bonus"]) + 12.0
		"combat_mage_gravity":
			_record_build_pick("body")
			special_data["gravity_level"] = int(special_data.get("gravity_level", 0)) + 1
			role_data["range_bonus"] = float(role_data["range_bonus"]) + 8.0
			role_data["skill_bonus"] = float(role_data["skill_bonus"]) + 0.12
		"skill_switch_mastery", "switch_mastery":
			_record_build_pick("skill")
			role_switch_cooldown_bonus += SWITCH_COOLDOWN_STEP
			switch_cooldown_remaining = max(0.0, switch_cooldown_remaining - 1.0)
		"skill_support_link":
			_record_build_pick("skill")
			background_interval_multiplier = max(0.55, background_interval_multiplier - 0.1)
		"skill_ultimate_tuning":
			_record_build_pick("skill")
			ultimate_cost_multiplier = max(0.62, ultimate_cost_multiplier - 0.06)
			current_mana = min(max_mana, current_mana + 12.0)
			mana_changed.emit(current_mana, max_mana)
		"skill_sword_counter":
			_record_build_pick("body")
			special_data["counter_level"] = int(special_data.get("counter_level", 0)) + 1
			damage_taken_multiplier = max(0.56, damage_taken_multiplier - 0.04)
		"skill_sword_pursuit":
			_record_build_pick("skill")
			special_data["pursuit_level"] = int(special_data.get("pursuit_level", 0)) + 1
			current_mana = min(max_mana, current_mana + 8.0)
			mana_changed.emit(current_mana, max_mana)
		"skill_sword_stance":
			_record_build_pick("body")
			special_data["stance_level"] = int(special_data.get("stance_level", 0)) + 1
			current_mana = min(max_mana, current_mana + 6.0)
			mana_changed.emit(current_mana, max_mana)
		"skill_gunner_support":
			_record_build_pick("combat")
			special_data["support_level"] = int(special_data.get("support_level", 0)) + 1
			current_mana = min(max_mana, current_mana + 5.0)
			mana_changed.emit(current_mana, max_mana)
		"skill_gunner_barrage":
			_record_build_pick("skill")
			special_data["barrage_level"] = int(special_data.get("barrage_level", 0)) + 1
			current_mana = min(max_mana, current_mana + 9.0)
			mana_changed.emit(current_mana, max_mana)
		"skill_mage_support":
			_record_build_pick("combat")
			special_data["support_level"] = int(special_data.get("support_level", 0)) + 1
			current_mana = min(max_mana, current_mana + 6.0)
			mana_changed.emit(current_mana, max_mana)
		"skill_mage_storm":
			_record_build_pick("skill")
			special_data["storm_level"] = int(special_data.get("storm_level", 0)) + 1
			current_mana = min(max_mana, current_mana + 9.0)
			mana_changed.emit(current_mana, max_mana)
		"fallback_body_reforge":
			_record_build_pick("body")
			global_damage_multiplier += 0.03
			max_health += 12.0
			current_health = min(max_health, current_health + 12.0)
			damage_taken_multiplier = max(0.55, damage_taken_multiplier - 0.03)
			health_changed.emit(current_health, max_health)
		"fallback_combat_reforge":
			_record_build_pick("combat")
			role_switch_cooldown_bonus += 0.4
			switch_cooldown_remaining = max(0.0, switch_cooldown_remaining - 0.6)
			background_interval_multiplier = max(0.45, background_interval_multiplier - 0.06)
		"fallback_skill_reforge":
			_record_build_pick("skill")
			energy_gain_multiplier += 0.10
			ultimate_cost_multiplier = max(0.5, ultimate_cost_multiplier - 0.04)
			role_data["skill_bonus"] = float(role_data.get("skill_bonus", 0.0)) + 0.08
			current_mana = min(max_mana, current_mana + 10.0)
			mana_changed.emit(current_mana, max_mana)
		"elite_behemoth":
			_unlock_elite_relic(option_id)
			max_health += 45.0
			current_health = min(max_health, current_health + 45.0)
			damage_taken_multiplier = max(0.48, damage_taken_multiplier - 0.08)
			health_changed.emit(current_health, max_health)
		"elite_gale":
			_unlock_elite_relic(option_id)
			speed += 30.0
			pickup_radius += 12.0
			role_switch_cooldown_bonus += 0.6
			switch_cooldown_remaining = max(0.0, switch_cooldown_remaining - 0.8)
		"elite_overcharge_reserve":
			_unlock_elite_relic(option_id)
			max_mana += 24.0
			current_mana = min(max_mana, current_mana + 24.0)
			energy_gain_multiplier += 0.18
			mana_changed.emit(current_mana, max_mana)
		"elite_mirror_finisher", "elite_fixed_axis_core", "elite_last_stand", "elite_execution_pact", "elite_reactor", "elite_chain_overload", "elite_fate_shift", "elite_perpetual_motion", "elite_battle_frenzy":
			_unlock_elite_relic(option_id)
			if option_id == "elite_fixed_axis_core":
				if _get_card_level("combat_fixed_axis") <= 0:
					card_pick_levels["combat_fixed_axis"] = 1
					_record_build_pick("combat")
				global_damage_multiplier += 0.16
				background_interval_multiplier = max(0.42, background_interval_multiplier - 0.14)
			elif option_id == "elite_chain_overload":
				background_interval_multiplier = max(0.38, background_interval_multiplier - 0.18)
				_grant_ultimate_seals(1, "\u8D85\u8F7D")
			elif option_id == "elite_reactor":
				current_mana = min(max_mana, current_mana + 12.0)
				mana_changed.emit(current_mana, max_mana)
			elif option_id == "elite_perpetual_motion":
				perpetual_motion_cooldown_remaining = 0.0
			elif option_id == "elite_battle_frenzy":
				frenzy_remaining = 0.0
				frenzy_stacks = 0
				frenzy_overkill_counter = 0
		"final_body_core":
			max_health += 36.0
			pickup_radius += 14.0
			damage_taken_multiplier = max(0.56, damage_taken_multiplier - 0.08)
			_heal(36.0)
		"final_combat_core":
			global_damage_multiplier += 0.12
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 8.0
			if role_id == "swordsman":
				role_data["skill_bonus"] = float(role_data["skill_bonus"]) + 0.24
				damage_taken_multiplier = max(0.52, damage_taken_multiplier - 0.05)
				_heal(18.0)
			elif role_id == "gunner":
				role_data["range_bonus"] = float(role_data["range_bonus"]) + 16.0
				role_data["interval_bonus"] = float(role_data["interval_bonus"]) + 0.05
				role_data["skill_bonus"] = float(role_data["skill_bonus"]) + 0.18
			elif role_id == "mage":
				role_data["range_bonus"] = float(role_data["range_bonus"]) + 18.0
				role_data["skill_bonus"] = float(role_data["skill_bonus"]) + 0.22
				role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 2.0
			if role_id == "swordsman":
				special_data["crescent_level"] = int(special_data.get("crescent_level", 0)) + 1
				special_data["thrust_level"] = int(special_data.get("thrust_level", 0)) + 1
			elif role_id == "gunner":
				special_data["scatter_level"] = int(special_data.get("scatter_level", 0)) + 1
				special_data["focus_level"] = int(special_data.get("focus_level", 0)) + 1
			elif role_id == "mage":
				special_data["echo_level"] = int(special_data.get("echo_level", 0)) + 1
				special_data["frost_level"] = int(special_data.get("frost_level", 0)) + 1
		"final_skill_core":
			energy_gain_multiplier += 0.16
			background_interval_multiplier = max(0.6, background_interval_multiplier - 0.08)
			ultimate_cost_multiplier = max(0.6, ultimate_cost_multiplier - 0.08)
			role_switch_cooldown_bonus += 0.7
			current_mana = min(max_mana, current_mana + 30.0)
			mana_changed.emit(current_mana, max_mana)
			if role_id == "gunner":
				special_data["support_level"] = int(special_data.get("support_level", 0)) + 1
				special_data["barrage_level"] = int(special_data.get("barrage_level", 0)) + 1
			elif role_id == "mage":
				special_data["support_level"] = int(special_data.get("support_level", 0)) + 1
				special_data["storm_level"] = int(special_data.get("storm_level", 0)) + 1
	if option_id in ["body_move_speed", "body_vitality", "body_pickup_range", "body_guard", "body_sword_blood", "combat_role_focus", "combat_rhythm", "combat_role_range", "combat_sword_crescent", "combat_sword_thrust", "combat_gunner_scatter", "combat_gunner_focus", "combat_gunner_lock", "combat_mage_echo", "combat_mage_frost", "combat_mage_gravity", "skill_sword_counter", "skill_sword_stance", "body_gunner_reload", "body_mage_flow"]:
		_apply_role_share(role_id, 0.9, 0.0, 2.0, 0.06)
	elif option_id in ["combat_team_power", "skill_switch_mastery", "skill_support_link", "skill_gunner_support", "skill_mage_support", "combat_move_speed", "combat_vitality", "combat_pickup_range", "combat_guard"]:
		_apply_role_share(role_id, 1.2, 0.025, 3.0, 0.1)
		role_switch_cooldown_bonus += 0.06
	elif option_id in ["skill_sword_pursuit", "skill_gunner_barrage", "skill_mage_storm", "skill_energy_flow", "skill_ultimate_tuning", "skill_gunner_overheat", "skill_mage_tidal_flow"]:
		_apply_role_share(role_id, 2.0, 0.05, 6.0, 0.08)
	elif option_id == "final_combat_core":
		_apply_role_share(role_id, 4.0, 0.09, 12.0, 0.18)
	elif option_id == "final_skill_core":
		_apply_role_share(role_id, 2.2, 0.04, 5.0, 0.16)

	role_upgrade_levels[role_id] = role_data
	role_special_states[role_id] = special_data
	level_up_active = false
	_update_fire_timer()
	stats_changed.emit(get_stat_summary())
	_try_request_level_up()

func get_attribute_upgrade_options() -> Array:
	return [
		{
			"id": "level_stat_vitality",
			"title": "\u751F\u547D\u8BAD\u7EC3 Lv.%d" % (int(attribute_training_levels.get("vitality", 0)) + 1),
			"description": "\u6700\u5927\u751F\u547D +%.0f\uff0c\u5E76\u7ACB\u5373\u56DE\u590D %.0f \u751F\u547D" % [LEVEL_STAT_HEALTH_STEP, LEVEL_STAT_HEALTH_STEP]
		},
		{
			"id": "level_stat_agility",
			"title": "\u673A\u52A8\u8BAD\u7EC3 Lv.%d" % (int(attribute_training_levels.get("agility", 0)) + 1),
			"description": "\u79FB\u52A8\u901F\u5EA6 +%.0f\uff0c\u8D70\u4F4D\u66F4\u8F7B\u677E" % LEVEL_STAT_SPEED_STEP
		},
		{
			"id": "level_stat_power",
			"title": "\u653B\u51FB\u8BAD\u7EC3 Lv.%d" % (int(attribute_training_levels.get("power", 0)) + 1),
			"description": "\u5168\u5C40\u4F24\u5BB3 +%.0f%%\uff0c\u76F4\u63A5\u8865\u8DB3\u8F93\u51FA" % (LEVEL_STAT_DAMAGE_STEP * 100.0)
		}
	]

func get_all_upgrade_options() -> Array:
	var options: Array = []
	options.append_array(_get_body_upgrade_pool())
	options.append_array(_get_combat_upgrade_pool())
	options.append_array(_get_skill_upgrade_pool())
	return options

func apply_attribute_upgrade(option_id: String) -> void:
	match option_id:
		"level_stat_vitality":
			attribute_training_levels["vitality"] = int(attribute_training_levels.get("vitality", 0)) + 1
			max_health += LEVEL_STAT_HEALTH_STEP
			current_health = min(max_health, current_health + LEVEL_STAT_HEALTH_STEP)
			health_changed.emit(current_health, max_health)
		"level_stat_agility":
			attribute_training_levels["agility"] = int(attribute_training_levels.get("agility", 0)) + 1
			speed += LEVEL_STAT_SPEED_STEP
		"level_stat_power":
			attribute_training_levels["power"] = int(attribute_training_levels.get("power", 0)) + 1
			global_damage_multiplier += LEVEL_STAT_DAMAGE_STEP
		_:
			return

	stats_changed.emit(get_stat_summary())

func _make_elite_relic_option(relic_id: String, title: String, description: String, category: String) -> Dictionary:
	return {
		"id": relic_id,
		"title": title,
		"description": description,
		"category": category
	}

func _get_elite_safeguard_pool() -> Array:
	var options: Array = []
	if not _has_elite_relic("elite_behemoth"):
		options.append(_make_elite_relic_option("elite_behemoth", "\u5DE8\u517D\u4E4B\u8EAF", "\u6700\u5927\u751F\u547D +45\uff0c\u7ACB\u5373\u56DE\u590D 45\uff0c\u53D7\u4F24\u500D\u7387 -8%\u3002", "safeguard"))
	if not _has_elite_relic("elite_gale"):
		options.append(_make_elite_relic_option("elite_gale", "\u98CE\u9A70\u7535\u63A3", "\u79FB\u901F +30\uff0c\u5207\u4EBA\u57FA\u51C6\u51B7\u5374 -0.6 \u79D2\uff0c\u62FE\u53D6\u8303\u56F4 +12\u3002", "safeguard"))
	if not _has_elite_relic("elite_overcharge_reserve"):
		options.append(_make_elite_relic_option("elite_overcharge_reserve", "\u8FC7\u91CF\u5145\u80FD", "\u7B26\u80FD\u4E0A\u9650 +24\uff0c\u7ACB\u5373\u56DE\u590D 24\uff0c\u7B26\u80FD\u83B7\u53D6 +18%\u3002", "safeguard"))
	return options

func _get_elite_mutation_pool() -> Array:
	var options: Array = []
	if not _has_elite_relic("elite_mirror_finisher"):
		options.append(_make_elite_relic_option("elite_mirror_finisher", "\u955C\u50CF\u7EC8\u7ED3", "\u6BCF\u6B21\u5927\u62DB\u7ED3\u675F\u540E\uff0c\u8FFD\u52A0 1 \u6B21 65% \u5F3A\u5EA6\u7684\u518D\u6F14\u3002", "mutation"))
	if not _has_elite_relic("elite_fixed_axis_core"):
		options.append(_make_elite_relic_option("elite_fixed_axis_core", "\u5B9A\u8F74\u6838\u5FC3", "\u5173\u95ED\u4E3B\u52A8\u5207\u4EBA\uff0c\u7AD9\u573A\u89D2\u8272\u4F24\u5BB3 +16%\uFF0C\u540E\u53F0\u51FA\u624B\u95F4\u9694 -14%\u3002", "rewrite"))
	if not _has_elite_relic("elite_last_stand"):
		options.append(_make_elite_relic_option("elite_last_stand", "\u80CC\u6C34\u4E00\u6218", "\u751F\u547D\u4F4E\u4E8E 40% \u65F6\uff0c\u4F24\u5BB3 +22%\uFF0C\u79FB\u901F +18%\uFF0C\u53D7\u4F24\u500D\u7387 -18%\u3002", "mutation"))
	if not _has_elite_relic("elite_execution_pact"):
		options.append(_make_elite_relic_option("elite_execution_pact", "\u5904\u51B3\u534F\u8BAE", "\u5BF9 45% \u751F\u547D\u4EE5\u4E0B\u548C\u7CBE\u82F1/Boss \u76EE\u6807\u989D\u5916\u9020\u6210 +22% \u4F24\u5BB3\uff0c\u51FB\u6740\u65F6\u89E6\u53D1\u4E00\u6B21\u5C0F\u8303\u56F4\u8FFD\u51FB\u3002", "mutation"))
	if not _has_elite_relic("elite_reactor"):
		options.append(_make_elite_relic_option("elite_reactor", "\u7B26\u80FD\u53CD\u5E94\u5806", "\u5207\u4EBA\u7ACB\u5373\u83B7\u5F97 12 \u70B9\u7B26\u80FD\uff0c\u7B26\u80FD\u6EE1\u65F6\u83B7\u5F97 2.8 \u79D2 +14% \u4F24\u5BB3\u4E0E +10% \u653B\u901F\u3002", "mutation"))
	if not _has_elite_relic("elite_chain_overload"):
		options.append(_make_elite_relic_option("elite_chain_overload", "\u8FDE\u643A\u8D85\u8F7D", "\u540E\u53F0\u51FA\u624B\u95F4\u9694 -18%\uFF0C\u5207\u4EBA\u6210\u529F\u540E\u518D\u989D\u5916\u8FD4\u8FD8 1 \u7B26\u5370\uff0c\u4F46\u7AD9\u573A\u89D2\u8272\u57FA\u7840\u4F24\u5BB3 -8%\u3002", "mutation"))
	if not _has_elite_relic("elite_fate_shift"):
		options.append(_make_elite_relic_option("elite_fate_shift", "\u547D\u8FD0\u504F\u6298", "\u6BCF\u6B21\u5347\u7EA7\u65F6\uFF0C\u4E09\u680F\u5404\u591A\u5237\u65B0 1 \u5F20\u5019\u9009\uFF0C\u6784\u7B51\u9009\u62E9\u66F4\u5BBD\u3002", "mutation"))
	if not _has_elite_relic("elite_perpetual_motion"):
		options.append(_make_elite_relic_option("elite_perpetual_motion", "永动核", "大招改为独立 26 秒冷却制，仍需 2 层符印，但不再消耗符能；释放时会消耗当前符能来强化本次大招。", "rewrite"))
	if not _has_elite_relic("elite_battle_frenzy"):
		options.append(_make_elite_relic_option("elite_battle_frenzy", "战斗狂热", "击杀会叠狂热层数，持续提高伤害、攻速、移速；满层后还会额外补符印和符能。", "mutation"))
	return options

func get_elite_reward_options() -> Array:
	var safeguard_pool := _get_elite_safeguard_pool()
	var mutation_pool := _get_elite_mutation_pool()
	safeguard_pool.shuffle()
	mutation_pool.shuffle()

	var picked: Array = []
	if not safeguard_pool.is_empty():
		picked.append(safeguard_pool[0])

	var combined_pool: Array = mutation_pool
	if safeguard_pool.size() > 1:
		combined_pool.append_array(safeguard_pool.slice(1))
	combined_pool.shuffle()
	for option in combined_pool:
		if picked.size() >= 3:
			break
		picked.append(option)

	if picked.size() < 3:
		var fallback_pool := safeguard_pool + mutation_pool
		fallback_pool.shuffle()
		for option in fallback_pool:
			if picked.size() >= 3:
				break
			var duplicate := false
			for picked_option in picked:
				if str(picked_option.get("id", "")) == str(option.get("id", "")):
					duplicate = true
					break
			if not duplicate:
				picked.append(option)
	return picked

func get_stat_summary() -> Dictionary:
	var role_data: Dictionary = _get_active_role()
	var role_id: String = role_data["id"]
	var interval_bonus: float = float(role_upgrade_levels[role_id]["interval_bonus"])
	if switch_power_remaining > 0.0 and switch_power_role_id == role_id:
		interval_bonus += switch_power_interval_bonus
	if entry_blessing_remaining > 0.0 and entry_blessing_role_id == role_id:
		interval_bonus += entry_haste_interval_bonus
	var interval: float = max(0.18, float(role_data["attack_interval"]) - interval_bonus)
	return {
		"level": level,
		"move_speed": _get_current_move_speed(),
		"bullet_damage": _get_role_damage(role_id),
		"fire_interval": interval,
		"current_mana": current_mana,
		"max_mana": max_mana,
		"ultimate_energy_cost": _get_ultimate_energy_cost(),
		"ultimate_seals": current_ultimate_seals,
		"ultimate_seal_max": ULTIMATE_SEAL_MAX,
		"ultimate_ready": _can_use_ultimate(),
		"pickup_radius": pickup_radius,
		"role_name": role_data["name"],
		"body_slot_label": _get_upgrade_slot_label("body"),
		"combat_slot_label": _get_upgrade_slot_label("combat"),
		"skill_slot_label": _get_upgrade_slot_label("skill"),
		"team_roles": roles.map(func(role): return role["name"]),
		"active_role_index": active_role_index,
		"switch_cooldown": max(0.0, switch_cooldown_remaining),
		"switch_cooldown_base": max(2.5, ROLE_SWITCH_COOLDOWN - role_switch_cooldown_bonus),
		"energy_gain_multiplier": energy_gain_multiplier,
		"background_interval_multiplier": background_interval_multiplier,
		"ultimate_cost_multiplier": ultimate_cost_multiplier,
		"damage_taken_multiplier": damage_taken_multiplier,
		"body_build_level": int(build_slot_levels.get("body", 0)),
		"combat_build_level": int(build_slot_levels.get("combat", 0)),
		"skill_build_level": int(build_slot_levels.get("skill", 0)),
		"attribute_vitality_level": int(attribute_training_levels.get("vitality", 0)),
		"attribute_agility_level": int(attribute_training_levels.get("agility", 0)),
		"attribute_power_level": int(attribute_training_levels.get("power", 0)),
		"slot_resonance_summary": _get_slot_resonance_summary(),
		"role_detail_summary": _get_role_detail_summary(role_id),
		"role_route_summary": _get_role_route_summary(role_id),
		"role_core_summary": _get_role_core_summary(role_id),
		"switch_power_label": switch_power_label,
		"switch_power_remaining": switch_power_remaining,
		"entry_blessing_label": entry_blessing_label,
		"entry_blessing_remaining": entry_blessing_remaining,
		"entry_blessing_role_id": entry_blessing_role_id,
		"relay_window_remaining": relay_window_remaining,
		"relay_label": relay_label,
		"relay_bonus_pending": relay_bonus_pending
	}

func get_final_core_options() -> Array:
	return [
		{
			"id": "final_body_core",
			"title": "\u7EC8\u5C40\u4F53\u683C\u6838\u5FC3",
			"description": "\u5927\u5E45\u63D0\u5347\u751F\u5B58\u3001\u62FE\u53D6\u548C\u5BB9\u9519\uFF0C\u9002\u5408\u7A33\u5B9A\u901A\u5173"
		},
		{
			"id": "final_combat_core",
			"title": "\u7EC8\u5C40\u6218\u6597\u6838\u5FC3",
			"description": "\u5927\u5E45\u63D0\u5347\u5F53\u524D\u4E0A\u573A\u89D2\u8272\u7684\u4F24\u5BB3\u3001\u8282\u594F\u548C\u4F5C\u6218\u8986\u76D6"
		},
		{
			"id": "final_skill_core",
			"title": "\u7EC8\u5C40\u6280\u80FD\u6838\u5FC3",
			"description": "\u5F3A\u5316\u80FD\u91CF\u5FAA\u73AF\u3001\u540E\u53F0\u652F\u63F4\u548C\u5927\u62DB\u91CA\u653E\u8282\u594F"
		}
	]

func get_save_data() -> Dictionary:
	var pending_upgrade_count: int = pending_level_ups
	if level_up_active:
		pending_upgrade_count += 1

	return {
		"position": [global_position.x, global_position.y],
		"level": level,
		"experience": experience,
		"experience_to_next_level": experience_to_next_level,
		"pending_level_ups": pending_upgrade_count,
		"max_health": max_health,
		"max_mana": max_mana,
		"current_health": current_health,
		"current_mana": current_mana,
		"current_ultimate_seals": current_ultimate_seals,
		"hurt_cooldown_remaining": hurt_cooldown_remaining,
		"switch_invulnerability_remaining": switch_invulnerability_remaining,
		"level_up_delay_remaining": level_up_delay_remaining,
		"switch_cooldown_remaining": switch_cooldown_remaining,
		"speed": speed,
		"pickup_radius": pickup_radius,
		"energy_gain_multiplier": energy_gain_multiplier,
		"global_damage_multiplier": global_damage_multiplier,
		"background_interval_multiplier": background_interval_multiplier,
		"ultimate_cost_multiplier": ultimate_cost_multiplier,
		"damage_taken_multiplier": damage_taken_multiplier,
		"role_switch_cooldown_bonus": role_switch_cooldown_bonus,
		"switch_power_remaining": switch_power_remaining,
		"switch_power_role_id": switch_power_role_id,
		"switch_power_damage_multiplier": switch_power_damage_multiplier,
		"switch_power_interval_bonus": switch_power_interval_bonus,
		"switch_power_label": switch_power_label,
		"pending_entry_blessing_source_role_id": pending_entry_blessing_source_role_id,
		"entry_blessing_role_id": entry_blessing_role_id,
		"entry_blessing_label": entry_blessing_label,
		"entry_blessing_remaining": entry_blessing_remaining,
		"entry_lifesteal_ratio": entry_lifesteal_ratio,
		"entry_haste_interval_bonus": entry_haste_interval_bonus,
		"entry_haste_move_speed_multiplier": entry_haste_move_speed_multiplier,
		"relay_window_remaining": relay_window_remaining,
		"relay_ready_role_id": relay_ready_role_id,
		"relay_from_role_id": relay_from_role_id,
		"relay_label": relay_label,
		"relay_bonus_pending": relay_bonus_pending,
		"standby_entry_role_id": standby_entry_role_id,
		"standby_entry_label": standby_entry_label,
		"standby_entry_remaining": standby_entry_remaining,
		"standby_entry_damage_multiplier": standby_entry_damage_multiplier,
		"standby_entry_interval_bonus": standby_entry_interval_bonus,
		"guard_cover_remaining": guard_cover_remaining,
		"guard_cover_damage_multiplier": guard_cover_damage_multiplier,
		"team_combo_remaining": team_combo_remaining,
		"team_combo_damage_multiplier": team_combo_damage_multiplier,
		"team_combo_move_multiplier": team_combo_move_multiplier,
		"team_combo_background_multiplier": team_combo_background_multiplier,
		"borrow_fire_role_id": borrow_fire_role_id,
		"borrow_fire_remaining": borrow_fire_remaining,
		"borrow_fire_damage_multiplier": borrow_fire_damage_multiplier,
		"borrow_fire_interval_bonus": borrow_fire_interval_bonus,
		"borrow_fire_background_multiplier": borrow_fire_background_multiplier,
		"post_ultimate_flow_remaining": post_ultimate_flow_remaining,
		"post_ultimate_flow_background_multiplier": post_ultimate_flow_background_multiplier,
		"ultimate_guard_remaining": ultimate_guard_remaining,
		"ultimate_guard_damage_multiplier": ultimate_guard_damage_multiplier,
		"perpetual_motion_cooldown_remaining": perpetual_motion_cooldown_remaining,
		"frenzy_remaining": frenzy_remaining,
		"frenzy_stacks": frenzy_stacks,
		"frenzy_overkill_counter": frenzy_overkill_counter,
		"role_standby_elapsed": role_standby_elapsed.duplicate(true),
		"role_cycle_marks": role_cycle_marks.duplicate(true),
		"role_share_initialized": role_share_initialized,
		"active_role_index": active_role_index,
		"role_upgrade_levels": role_upgrade_levels.duplicate(true),
		"background_cooldowns": background_cooldowns.duplicate(true),
		"build_slot_levels": build_slot_levels.duplicate(true),
		"card_pick_levels": card_pick_levels.duplicate(true),
		"elite_relics_unlocked": elite_relics_unlocked.duplicate(true),
		"attribute_training_levels": attribute_training_levels.duplicate(true),
		"slot_resonances_unlocked": slot_resonances_unlocked.duplicate(true),
		"role_special_states": role_special_states.duplicate(true),
		"roles": _serialize_roles_for_save(),
		"story_equipped_styles": story_equipped_styles.duplicate(true)
	}

func apply_save_data(data: Dictionary) -> void:
	var position_data = data.get("position", [0.0, 0.0])
	if position_data.size() >= 2:
		global_position = Vector2(float(position_data[0]), float(position_data[1]))

	level = int(data.get("level", level))
	experience = int(data.get("experience", experience))
	experience_to_next_level = int(data.get("experience_to_next_level", experience_to_next_level))
	pending_level_ups = int(data.get("pending_level_ups", pending_level_ups))
	max_health = float(data.get("max_health", max_health))
	max_mana = float(data.get("max_mana", max_mana))
	current_health = float(data.get("current_health", current_health))
	current_mana = float(data.get("current_mana", current_mana))
	current_ultimate_seals = int(data.get("current_ultimate_seals", 0))
	hurt_cooldown_remaining = float(data.get("hurt_cooldown_remaining", 0.0))
	switch_invulnerability_remaining = float(data.get("switch_invulnerability_remaining", 0.0))
	level_up_delay_remaining = float(data.get("level_up_delay_remaining", 0.0))
	switch_cooldown_remaining = float(data.get("switch_cooldown_remaining", 0.0))
	speed = float(data.get("speed", speed))
	pickup_radius = float(data.get("pickup_radius", pickup_radius))
	energy_gain_multiplier = float(data.get("energy_gain_multiplier", energy_gain_multiplier))
	global_damage_multiplier = float(data.get("global_damage_multiplier", global_damage_multiplier))
	background_interval_multiplier = float(data.get("background_interval_multiplier", background_interval_multiplier))
	ultimate_cost_multiplier = float(data.get("ultimate_cost_multiplier", ultimate_cost_multiplier))
	damage_taken_multiplier = float(data.get("damage_taken_multiplier", damage_taken_multiplier))
	role_switch_cooldown_bonus = float(data.get("role_switch_cooldown_bonus", role_switch_cooldown_bonus))
	switch_power_remaining = float(data.get("switch_power_remaining", 0.0))
	switch_power_role_id = str(data.get("switch_power_role_id", ""))
	switch_power_damage_multiplier = float(data.get("switch_power_damage_multiplier", 1.0))
	switch_power_interval_bonus = float(data.get("switch_power_interval_bonus", 0.0))
	switch_power_label = str(data.get("switch_power_label", ""))
	pending_entry_blessing_source_role_id = str(data.get("pending_entry_blessing_source_role_id", ""))
	entry_blessing_role_id = str(data.get("entry_blessing_role_id", ""))
	entry_blessing_label = str(data.get("entry_blessing_label", ""))
	entry_blessing_remaining = float(data.get("entry_blessing_remaining", 0.0))
	entry_lifesteal_ratio = float(data.get("entry_lifesteal_ratio", 0.0))
	entry_haste_interval_bonus = float(data.get("entry_haste_interval_bonus", 0.0))
	entry_haste_move_speed_multiplier = float(data.get("entry_haste_move_speed_multiplier", 1.0))
	relay_window_remaining = float(data.get("relay_window_remaining", 0.0))
	relay_ready_role_id = str(data.get("relay_ready_role_id", ""))
	relay_from_role_id = str(data.get("relay_from_role_id", ""))
	relay_label = str(data.get("relay_label", ""))
	relay_bonus_pending = bool(data.get("relay_bonus_pending", false))
	standby_entry_role_id = str(data.get("standby_entry_role_id", ""))
	standby_entry_label = str(data.get("standby_entry_label", ""))
	standby_entry_remaining = float(data.get("standby_entry_remaining", 0.0))
	standby_entry_damage_multiplier = float(data.get("standby_entry_damage_multiplier", 1.0))
	standby_entry_interval_bonus = float(data.get("standby_entry_interval_bonus", 0.0))
	guard_cover_remaining = float(data.get("guard_cover_remaining", 0.0))
	guard_cover_damage_multiplier = float(data.get("guard_cover_damage_multiplier", 1.0))
	team_combo_remaining = float(data.get("team_combo_remaining", 0.0))
	team_combo_damage_multiplier = float(data.get("team_combo_damage_multiplier", 1.0))
	team_combo_move_multiplier = float(data.get("team_combo_move_multiplier", 1.0))
	team_combo_background_multiplier = float(data.get("team_combo_background_multiplier", 1.0))
	borrow_fire_role_id = str(data.get("borrow_fire_role_id", ""))
	borrow_fire_remaining = float(data.get("borrow_fire_remaining", 0.0))
	borrow_fire_damage_multiplier = float(data.get("borrow_fire_damage_multiplier", 1.0))
	borrow_fire_interval_bonus = float(data.get("borrow_fire_interval_bonus", 0.0))
	borrow_fire_background_multiplier = float(data.get("borrow_fire_background_multiplier", 1.0))
	post_ultimate_flow_remaining = float(data.get("post_ultimate_flow_remaining", 0.0))
	post_ultimate_flow_background_multiplier = float(data.get("post_ultimate_flow_background_multiplier", 1.0))
	ultimate_guard_remaining = float(data.get("ultimate_guard_remaining", 0.0))
	ultimate_guard_damage_multiplier = float(data.get("ultimate_guard_damage_multiplier", 1.0))
	perpetual_motion_cooldown_remaining = float(data.get("perpetual_motion_cooldown_remaining", 0.0))
	frenzy_remaining = float(data.get("frenzy_remaining", 0.0))
	frenzy_stacks = int(data.get("frenzy_stacks", 0))
	frenzy_overkill_counter = int(data.get("frenzy_overkill_counter", 0))
	role_standby_elapsed = data.get("role_standby_elapsed", role_standby_elapsed).duplicate(true)
	role_cycle_marks = data.get("role_cycle_marks", role_cycle_marks).duplicate(true)
	role_share_initialized = bool(data.get("role_share_initialized", false))
	active_role_index = int(data.get("active_role_index", active_role_index))
	role_upgrade_levels = data.get("role_upgrade_levels", role_upgrade_levels).duplicate(true)
	background_cooldowns = data.get("background_cooldowns", background_cooldowns).duplicate(true)
	build_slot_levels = data.get("build_slot_levels", build_slot_levels).duplicate(true)
	card_pick_levels = data.get("card_pick_levels", card_pick_levels).duplicate(true)
	elite_relics_unlocked = data.get("elite_relics_unlocked", elite_relics_unlocked).duplicate(true)
	attribute_training_levels = data.get("attribute_training_levels", attribute_training_levels).duplicate(true)
	slot_resonances_unlocked = data.get("slot_resonances_unlocked", slot_resonances_unlocked).duplicate(true)
	role_special_states = data.get("role_special_states", role_special_states).duplicate(true)
	roles = _normalize_loaded_roles(data.get("roles", roles))
	story_equipped_styles = data.get("story_equipped_styles", story_equipped_styles).duplicate(true)
	_initialize_existing_role_shares()
	level_up_active = false
	is_dead = false

	_update_active_role_state()
	fire_timer.start()

	experience_changed.emit(experience, experience_to_next_level, level)
	stats_changed.emit(get_stat_summary())
	health_changed.emit(current_health, max_health)
	mana_changed.emit(current_mana, max_mana)

func resume_pending_level_ups() -> void:
	_try_request_level_up()

func _delay_level_up_requests(duration: float) -> void:
	if duration <= 0.0:
		return
	level_up_delay_remaining = max(level_up_delay_remaining, duration)

func _try_request_level_up() -> void:
	if is_dead or level_up_active or pending_level_ups <= 0 or level_up_delay_remaining > 0.0:
		return

	pending_level_ups -= 1
	level_up_active = true
	level_up_requested.emit(_build_upgrade_options())

func _build_upgrade_options() -> Array:
	if DEVELOPER_MODE.should_offer_all_build_cards():
		return _build_all_upgrade_options_for_developer_mode()

	var options: Array = []
	var pick_count: int = 4 if _has_elite_relic("elite_fate_shift") else 3
	options.append_array(_pick_upgrade_options(_get_body_upgrade_pool(), pick_count))
	options.append_array(_pick_upgrade_options(_get_combat_upgrade_pool(), pick_count))
	options.append_array(_pick_upgrade_options(_get_skill_upgrade_pool(), pick_count))
	if options.is_empty():
		options.append_array(_get_fallback_upgrade_pool())
	return options

func _build_all_upgrade_options_for_developer_mode() -> Array:
	var options: Array = []
	options.append_array(_get_body_upgrade_pool())
	options.append_array(_get_combat_upgrade_pool())
	options.append_array(_get_skill_upgrade_pool())
	if options.is_empty():
		options.append_array(_get_fallback_upgrade_pool())
	return options

func _get_fallback_upgrade_pool() -> Array:
	return [
		_make_upgrade_option("body", "fallback_body_reforge", "战斗补强", "全队伤害 +3，生命 +12，受伤倍率 -3%。"),
		_make_upgrade_option("combat", "fallback_combat_reforge", "连携补强", "切人冷却 -0.4 秒，后台出手间隔 -6%。"),
		_make_upgrade_option("skill", "fallback_skill_reforge", "大招补强", "符能获取 +10%，大招消耗 -4%，技能系数 +0.08。")
	]

func _get_body_upgrade_pool() -> Array:
	var options: Array = []
	for card_id in [
		"battle_dangzhen_qichao",
		"battle_dangzhen_dielang",
		"battle_dangzhen_huichao",
		"battle_cover",
		"battle_split",
		"battle_overload",
		"battle_tide",
		"battle_devour",
		"battle_aftershock",
		"battle_suppress",
		"battle_chain",
		"battle_hunt"
	]:
		var config := _get_build_card_config(card_id)
		if _can_offer_card(card_id, int(config.get("max_level", 3))):
			options.append(_make_core_card_option("body", card_id, str(config.get("title", "")), _get_build_card_exact_description(card_id), int(config.get("max_level", 3))))
	return options

func _get_combat_upgrade_pool() -> Array:
	var options: Array = []
	for card_id in [
		"combat_tuning",
		"combat_assault",
		"combat_support",
		"combat_swap",
		"combat_rotation",
		"combat_synergy",
		"combat_legacy",
		"combat_rearguard",
		"combat_relay"
	]:
		var config := _get_build_card_config(card_id)
		if _can_offer_card(card_id, int(config.get("max_level", 3))):
			options.append(_make_core_card_option("combat", card_id, str(config.get("title", "")), _get_build_card_exact_description(card_id), int(config.get("max_level", 3))))
	return options

func _get_skill_upgrade_pool() -> Array:
	var options: Array = []
	for card_id in [
		"skill_blossom",
		"skill_extend",
		"skill_reprise",
		"skill_afterglow",
		"skill_borrow_fire",
		"skill_finale",
		"skill_resonance",
		"skill_reflux",
		"skill_overdrive"
	]:
		var config := _get_build_card_config(card_id)
		if _can_offer_card(card_id, int(config.get("max_level", 3))):
			options.append(_make_core_card_option("skill", card_id, str(config.get("title", "")), _get_build_card_exact_description(card_id), int(config.get("max_level", 3))))
	return options

func _pick_upgrade_options(pool: Array, count: int) -> Array:
	var candidates := pool.duplicate()
	candidates.shuffle()
	return candidates.slice(0, max(0, min(count, candidates.size())))

func _make_upgrade_option(slot_id: String, option_id: String, title: String, description: String) -> Dictionary:
	var slot_name: String = _get_upgrade_slot_label(slot_id)
	return {
		"id": option_id,
		"slot": slot_id,
		"slot_label": slot_name,
		"title": title,
		"description": description
	}

func _record_build_pick(slot_id: String) -> void:
	build_slot_levels[slot_id] = int(build_slot_levels.get(slot_id, 0)) + 1
	_check_slot_resonance_unlocks()

func _get_support_offset(role_id: String, aggressive: bool) -> Vector2:
	var side := -1.0
	if role_id == "gunner":
		side = 1.0
	var lateral := facing_direction.orthogonal() * 34.0 * side
	var forward := facing_direction * (14.0 if aggressive else -10.0)
	return lateral + forward

func _spawn_radial_rays_effect(center: Vector2, radius: float, ray_count: int, color: Color, width: float, duration: float, angle_offset: float = 0.0) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var root := Node2D.new()
	root.global_position = center
	root.z_index = 12
	current_scene.add_child(root)

	var safe_ray_count: int = max(3, ray_count)
	var inner_radius: float = max(12.0, radius * 0.18)
	for ray_index in range(safe_ray_count):
		var angle: float = TAU * float(ray_index) / float(safe_ray_count) + angle_offset
		var direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var ray := Line2D.new()
		ray.width = width
		ray.default_color = Color(color.r, color.g, color.b, min(1.0, color.a + (0.14 if ray_index % 2 == 0 else 0.0)))
		ray.points = PackedVector2Array([direction * inner_radius, direction * radius])
		root.add_child(ray)

	root.scale = Vector2(0.35, 0.35)
	var tween := root.create_tween()
	tween.parallel().tween_property(root, "scale", Vector2.ONE, duration * 0.45)
	tween.parallel().tween_property(root, "modulate:a", 0.0, duration)
	tween.tween_callback(root.queue_free)

func _spawn_slash_effect(center: Vector2, direction: Vector2, length: float, width: float, color: Color, duration: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var effect := Node2D.new()
	effect.global_position = center
	effect.rotation = direction.angle()
	effect.z_index = 12

	var polygon := Polygon2D.new()
	polygon.color = color
	polygon.polygon = PackedVector2Array([
		Vector2(-18.0, -width * 0.7),
		Vector2(length * 0.2, -width),
		Vector2(length, -width * 0.12),
		Vector2(length * 0.72, width * 0.48),
		Vector2(-12.0, width * 0.7)
	])
	effect.add_child(polygon)
	current_scene.add_child(effect)

	effect.scale = Vector2(0.32, 0.74)
	var tween := effect.create_tween()
	tween.parallel().tween_property(effect, "scale", Vector2(1.0, 1.0), duration * 0.45)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, duration)
	tween.tween_callback(effect.queue_free)

func _spawn_dash_line_effect(start_position: Vector2, end_position: Vector2, color: Color, width: float, duration: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var line := Line2D.new()
	line.z_index = 11
	line.width = width
	line.default_color = color
	line.points = PackedVector2Array([start_position, end_position])
	current_scene.add_child(line)

	var tween := line.create_tween()
	tween.parallel().tween_property(line, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(line, "width", 2.0, duration)
	tween.tween_callback(line.queue_free)

func _spawn_line_corridor_effect(start_position: Vector2, end_position: Vector2, hit_width: float, color: Color, duration: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var direction := start_position.direction_to(end_position)
	var length := start_position.distance_to(end_position)
	if length <= 1.0:
		return

	var effect := Node2D.new()
	effect.global_position = start_position
	effect.rotation = direction.angle()
	effect.z_index = 10

	var polygon := Polygon2D.new()
	polygon.color = color
	polygon.polygon = PackedVector2Array([
		Vector2(0.0, -hit_width),
		Vector2(length, -hit_width),
		Vector2(length, hit_width),
		Vector2(0.0, hit_width)
	])
	effect.add_child(polygon)
	current_scene.add_child(effect)

	var tween := effect.create_tween()
	tween.parallel().tween_property(effect, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(effect, "scale:y", 0.65, duration)
	tween.tween_callback(effect.queue_free)

func _spawn_crescent_wave_effect(center: Vector2, direction: Vector2, radius: float, color: Color, duration: float, arc_degrees: float = 270.0, thickness: float = 26.0) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var effect := Node2D.new()
	effect.global_position = center
	effect.rotation = direction.angle()
	effect.z_index = 13

	var outer_radius: float = radius
	var inner_radius: float = max(8.0, radius - thickness)

	var polygon := Polygon2D.new()
	polygon.color = Color(color.r, color.g, color.b, min(0.05, color.a * 0.08))
	polygon.polygon = _build_arc_band_polygon(outer_radius, inner_radius, arc_degrees)
	effect.add_child(polygon)

	var edge := Line2D.new()
	edge.width = 4.0
	edge.default_color = Color(0.9, 0.98, 1.0, min(0.1, color.a * 0.16))
	edge.points = _build_arc_points(outer_radius - 2.0, arc_degrees)
	effect.add_child(edge)
	current_scene.add_child(effect)

	effect.scale = Vector2(0.42, 0.42)
	var tween := effect.create_tween()
	tween.parallel().tween_property(effect, "scale", Vector2.ONE, duration * 0.45)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, duration)
	tween.tween_callback(effect.queue_free)

func _spawn_cross_slash_effect(center: Vector2, direction: Vector2, length: float, width: float, color: Color, duration: float) -> void:
	_spawn_slash_effect(center, direction.rotated(0.78), length, width, color, duration)
	_spawn_slash_effect(center, direction.rotated(-0.78), length, width, color, duration)

func _spawn_thrust_effect(start_position: Vector2, end_position: Vector2, color: Color, width: float, duration: float, show_arrow: bool = true) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var direction := start_position.direction_to(end_position)
	var length := start_position.distance_to(end_position)

	_spawn_line_corridor_effect(start_position, end_position, width, Color(color.r, color.g, color.b, min(0.34, color.a * 0.35)), duration)
	if not show_arrow:
		return

	var effect := Node2D.new()
	effect.global_position = start_position
	effect.rotation = direction.angle()
	effect.z_index = 13

	var shaft := Polygon2D.new()
	shaft.color = color
	shaft.polygon = PackedVector2Array([
		Vector2(0.0, -width * 0.22),
		Vector2(length * 0.8, -width * 0.16),
		Vector2(length * 0.8, width * 0.16),
		Vector2(0.0, width * 0.22)
	])
	effect.add_child(shaft)

	var tip := Polygon2D.new()
	tip.color = Color(1.0, 0.92, 0.72, min(1.0, color.a + 0.08))
	tip.polygon = PackedVector2Array([
		Vector2(length * 0.72, -width * 0.46),
		Vector2(length, 0.0),
		Vector2(length * 0.72, width * 0.46)
	])
	effect.add_child(tip)
	current_scene.add_child(effect)

	effect.scale = Vector2(0.3, 0.8)
	var tween := effect.create_tween()
	tween.parallel().tween_property(effect, "scale", Vector2.ONE, duration * 0.45)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, duration)
	tween.tween_callback(effect.queue_free)

func _spawn_guard_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	_spawn_ring_effect(center, radius, Color(color.r, color.g, color.b, min(0.9, color.a + 0.2)), 6.0, duration)
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var shield := Polygon2D.new()
	shield.global_position = center
	shield.z_index = 11
	shield.color = color
	shield.polygon = PackedVector2Array([
		Vector2(0.0, -radius * 0.6),
		Vector2(radius * 0.52, -radius * 0.18),
		Vector2(radius * 0.38, radius * 0.5),
		Vector2(0.0, radius * 0.72),
		Vector2(-radius * 0.38, radius * 0.5),
		Vector2(-radius * 0.52, -radius * 0.18)
	])
	current_scene.add_child(shield)

	shield.scale = Vector2(0.36, 0.36)
	var tween := shield.create_tween()
	tween.parallel().tween_property(shield, "scale", Vector2.ONE, duration)
	tween.parallel().tween_property(shield, "modulate:a", 0.0, duration)
	tween.tween_callback(shield.queue_free)

func _spawn_combat_tag(position: Vector2, text: String, color: Color) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var label := Label.new()
	label.text = text
	label.modulate = color
	label.z_index = 24
	label.add_theme_font_size_override("font_size", 20)
	current_scene.add_child(label)
	label.global_position = position

	var tween := label.create_tween()
	tween.parallel().tween_property(label, "global_position", position + Vector2(0.0, -24.0), 0.34)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.34)
	tween.tween_callback(label.queue_free)

func _spawn_ring_effect(center: Vector2, radius: float, color: Color, width: float, duration: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var ring := Line2D.new()
	ring.global_position = center
	ring.z_index = 11
	ring.width = width
	ring.default_color = color
	ring.closed = true
	ring.points = _build_circle_polygon(radius)
	current_scene.add_child(ring)

	var tween := ring.create_tween()
	tween.parallel().tween_property(ring, "width", 2.0, duration)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, duration)
	tween.tween_callback(ring.queue_free)

func _spawn_airstrike_warning_effect(center: Vector2, radius: float) -> void:
	_spawn_ring_effect(center, radius * 0.82, Color(0.72, 0.96, 1.0, 0.56), 4.0, 0.22)
	_spawn_frost_sigils_effect(center, max(18.0, radius * 0.5), Color(0.84, 0.98, 1.0, 0.64), 0.22)
	for offset_ratio in [-0.52, -0.24, 0.0, 0.24, 0.52]:
		var lateral: float = radius * offset_ratio
		var start := center + Vector2(lateral, -108.0 + abs(offset_ratio) * 18.0)
		var end := center + Vector2(lateral * 0.22, -18.0)
		var width: float = 3.0 if abs(offset_ratio) > 0.01 else 5.0
		var color := Color(0.62, 0.9, 1.0, 0.36) if abs(offset_ratio) > 0.01 else Color(0.78, 0.96, 1.0, 0.58)
		_spawn_dash_line_effect(start, end, color, width, 0.18)

func _spawn_airstrike_fall_effect(center: Vector2, radius: float) -> void:
	for offset_ratio in [-0.58, -0.3, 0.0, 0.3, 0.58]:
		var lateral: float = radius * offset_ratio
		var start := center + Vector2(lateral, -132.0 + abs(offset_ratio) * 18.0)
		var end := center + Vector2(lateral * 0.18, radius * 0.18)
		var width: float = 4.0 if abs(offset_ratio) > 0.01 else 8.0
		var color := Color(0.7, 0.94, 1.0, 0.72) if abs(offset_ratio) > 0.01 else Color(0.92, 0.98, 1.0, 0.96)
		_spawn_dash_line_effect(start, end, color, width, 0.12)
	_spawn_burst_effect(center, radius * 0.28, Color(0.88, 0.98, 1.0, 0.24), 0.1)

func _spawn_pulsing_field(center: Vector2, radius: float, color: Color, pulse_count: int, interval: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var controller := Node2D.new()
	controller.global_position = center
	current_scene.add_child(controller)

	var tween := controller.create_tween()
	for pulse_index in range(max(1, pulse_count)):
		if pulse_index > 0:
			tween.tween_interval(interval)
		tween.tween_callback(Callable(self, "_trigger_field_pulse").bind(center, radius, color, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration))
	tween.tween_callback(controller.queue_free)

func _trigger_field_pulse(center: Vector2, radius: float, color: Color, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float) -> void:
	_spawn_ring_effect(center, radius, Color(color.r, color.g, color.b, min(0.9, color.a + 0.35)), 6.0, 0.18)
	_spawn_burst_effect(center, radius, color, 0.18)
	if slow_duration > 0.0:
		_spawn_frost_sigils_effect(center, max(18.0, radius * 0.58), Color(0.84, 0.98, 1.0, 0.72), 0.18)
	_damage_enemies_in_radius(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration)

func _spawn_burst_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var polygon := Polygon2D.new()
	polygon.global_position = center
	polygon.color = color
	polygon.z_index = 10
	polygon.polygon = _build_circle_polygon(radius)
	current_scene.add_child(polygon)

	polygon.scale = Vector2(0.2, 0.2)
	var tween := polygon.create_tween()
	tween.parallel().tween_property(polygon, "scale", Vector2.ONE, duration)
	tween.parallel().tween_property(polygon, "modulate:a", 0.0, duration)
	tween.tween_callback(polygon.queue_free)

func _spawn_frost_sigils_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var effect := Node2D.new()
	effect.global_position = center
	effect.z_index = 12
	current_scene.add_child(effect)

	var shard_count := 6
	for index in range(shard_count):
		var angle: float = TAU * float(index) / float(shard_count)
		var outer: Vector2 = Vector2.RIGHT.rotated(angle) * radius
		var inner: Vector2 = Vector2.RIGHT.rotated(angle) * max(12.0, radius * 0.48)
		var side: Vector2 = Vector2.RIGHT.rotated(angle + PI * 0.5) * max(4.0, radius * 0.08)
		var shard := Polygon2D.new()
		shard.color = color
		shard.polygon = PackedVector2Array([
			inner - side * 0.7,
			outer,
			inner + side * 0.7
		])
		effect.add_child(shard)

	effect.scale = Vector2(0.45, 0.45)
	var tween := effect.create_tween()
	tween.parallel().tween_property(effect, "rotation", 0.32, duration)
	tween.parallel().tween_property(effect, "scale", Vector2.ONE, duration * 0.5)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, duration)
	tween.tween_callback(effect.queue_free)

func _spawn_vortex_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var root := Node2D.new()
	root.global_position = center
	root.z_index = 12
	current_scene.add_child(root)

	var outer_ring := Line2D.new()
	outer_ring.width = 5.0
	outer_ring.default_color = color
	outer_ring.closed = true
	outer_ring.points = _build_circle_polygon(radius)
	root.add_child(outer_ring)

	var inner_ring := Line2D.new()
	inner_ring.width = 3.0
	inner_ring.default_color = Color(0.92, 0.98, 1.0, min(0.96, color.a + 0.18))
	inner_ring.closed = true
	inner_ring.points = _build_circle_polygon(max(8.0, radius * 0.55))
	root.add_child(inner_ring)

	for arm_index in range(3):
		var arm := Polygon2D.new()
		var angle := TAU * float(arm_index) / 3.0
		arm.rotation = angle
		arm.color = Color(color.r, color.g, color.b, min(0.86, color.a + 0.08))
		arm.polygon = PackedVector2Array([
			Vector2(6.0, -4.0),
			Vector2(radius * 0.7, -8.0),
			Vector2(radius, 0.0),
			Vector2(radius * 0.7, 8.0),
			Vector2(6.0, 4.0)
		])
		root.add_child(arm)

	root.scale = Vector2(0.4, 0.4)
	var tween := root.create_tween()
	tween.parallel().tween_property(root, "rotation", -0.42, duration)
	tween.parallel().tween_property(root, "scale", Vector2.ONE, duration * 0.45)
	tween.parallel().tween_property(root, "modulate:a", 0.0, duration)
	tween.tween_callback(root.queue_free)

func _spawn_target_lock_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var root := Node2D.new()
	root.global_position = center
	root.z_index = 13
	current_scene.add_child(root)

	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = color
	ring.closed = true
	ring.points = _build_circle_polygon(radius)
	root.add_child(ring)

	for side in [-1.0, 1.0]:
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = color
		line.points = PackedVector2Array([
			Vector2(side * (radius + 10.0), 0.0),
			Vector2(side * (radius - 3.0), 0.0)
		])
		root.add_child(line)

		var vline := Line2D.new()
		vline.width = 3.0
		vline.default_color = color
		vline.points = PackedVector2Array([
			Vector2(0.0, side * (radius + 10.0)),
			Vector2(0.0, side * (radius - 3.0))
		])
		root.add_child(vline)

	root.scale = Vector2(1.2, 1.2)
	var tween := root.create_tween()
	tween.parallel().tween_property(root, "scale", Vector2.ONE, duration * 0.5)
	tween.parallel().tween_property(root, "modulate:a", 0.0, duration)
	tween.tween_callback(root.queue_free)

func _build_circle_polygon(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments := 18
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _build_arc_points(radius: float, arc_degrees: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments := 24
	var half_arc := deg_to_rad(arc_degrees) * 0.5
	var start_angle := -half_arc
	var end_angle := half_arc
	for index in range(segments + 1):
		var weight := float(index) / float(segments)
		var angle := lerpf(start_angle, end_angle, weight)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _build_arc_band_polygon(outer_radius: float, inner_radius: float, arc_degrees: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var outer_points := _build_arc_points(outer_radius, arc_degrees)
	var inner_points := _build_arc_points(inner_radius, arc_degrees)
	for point in outer_points:
		points.append(point)
	for index in range(inner_points.size() - 1, -1, -1):
		points.append(inner_points[index])
	return points

func _die() -> void:
	if is_dead:
		return

	is_dead = true
	level_up_active = false
	fire_timer.stop()
	died.emit()

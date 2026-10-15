extends RefCounted

const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const SKILL_LEVEL_EFFECTS := preload("res://scripts/player/player_skill_level_effect_flow.gd")
const LEVELS := preload("res://scripts/player/player_skill_level_system.gd")
const TALENTS := LEVELS.MECHANIC_TALENTS

const ULT_WARNING_TEXTURES := [
	preload("res://effects/mechanic/ult_warning/1.png"),
	preload("res://effects/mechanic/ult_warning/2.png"),
	preload("res://effects/mechanic/ult_warning/3.png")
]
const ULT_EXPLOSION_TEXTURES := [
	preload("res://effects/mechanic/ult_explosion/1.png"),
	preload("res://effects/mechanic/ult_explosion/2.png"),
	preload("res://effects/mechanic/ult_explosion/3.png"),
	preload("res://effects/mechanic/ult_explosion/4.png"),
	preload("res://effects/mechanic/ult_explosion/5.png"),
	preload("res://effects/mechanic/ult_explosion/6.png"),
	preload("res://effects/mechanic/ult_explosion/7.png")
]

const ULTIMATE_SKILL_ID := "mechanic_ultimate"
const BASIC_BULLET_COLOR := Color(1.0, 0.82, 0.42, 1.0)
const BASIC_RANGE := 300.0
const SPIDER_SPEED := 100.0
const SPIDER_VISUAL_SCALE := 1.8
const SPIDER_SCENE_SIZE := Vector2(128.0, 128.0)
const SPIDER_VISIBLE_BOUNDS := Rect2(16.0, 36.0, 98.0, 56.0)
const SPIDER_VISUAL_FPS := 10.0
const SPIDER_TEXTURES := [
	preload("res://effects/mechanic/spider/1.png"),
	preload("res://effects/mechanic/spider/2.png"),
	preload("res://effects/mechanic/spider/3.png"),
	preload("res://effects/mechanic/spider/4.png")
]
const BACKGROUND_DAMAGE_RATIO := 0.34
const TRAIT_PART_INTERVAL := 4.0
const TRAIT_PART_MAX := 10
const TRAIT_PART_DAMAGE_BONUS := 0.04
const ENTRY_BANNER_COLOR := Color(0.95, 0.68, 0.25, 1.0)
const ULTIMATE_SALVO_COUNT := 3
const ULTIMATE_SALVO_INTERVAL := 0.55
const ULTIMATE_SALVO_DAMAGE_RATIO := 3.0
const ULTIMATE_SALVO_RADIUS := 150.0
const ULTIMATE_WARNING_DELAY := 0.5
const ULT_WARNING_VISUAL_FPS := 6.0
const ULT_WARNING_VISUAL_MAX_RADIUS := 99.8
const ULT_EXPLOSION_VISUAL_FPS := 12.0
const ULT_EXPLOSION_VISUAL_MAX_RADIUS := 123.8
const TALENT_TRAIT_1 := "mechanic_level_talent_trait_1"
const TALENT_TRAIT_2 := "mechanic_level_talent_trait_2"
const TALENT_BASIC_ATTACK_1 := "mechanic_level_talent_basic_attack_1"
const TALENT_BASIC_ATTACK_2 := "mechanic_level_talent_basic_attack_2"
const TALENT_ENTRY_1 := "mechanic_level_talent_entry_1"
const TALENT_ENTRY_2 := "mechanic_level_talent_entry_2"
const TALENT_OVERDRIVE_1 := "mechanic_level_talent_overdrive_1"
const TALENT_OVERDRIVE_2 := "mechanic_level_talent_overdrive_2"
const TRAIT_TALENT_PART_INTERVAL := 3.0
const TRAIT_TALENT_PART_MAX_BONUS := 4
const TRAIT_TALENT_PART_DAMAGE_BONUS := 0.06
const BASIC_TALENT_DAMAGE_MULTIPLIER := 1.2
const BASIC_TALENT_SHRED_VALUE := 2.0
const OVERDRIVE_TALENT_DAMAGE_BONUS := 0.5
const ULTIMATE_BLAST_COLOR := Color(1.0, 0.78, 0.32, 0.85)

var cached_ult_warning_frames: SpriteFrames
var cached_ult_explosion_frames: SpriteFrames
var cached_spider_frames: SpriteFrames
var basic_damage_event_serial: int = 0

func _create_basic_source_id(owner) -> String:
	if owner != null and owner.has_method("_create_basic_attack_source_id"):
		return str(owner._create_basic_attack_source_id("mechanic"))
	basic_damage_event_serial += 1
	return "mechanic_basic:%s:%s" % [owner.get_instance_id() if owner != null else 0, basic_damage_event_serial]

func perform_attack(owner) -> void:
	var damage_amount: float = owner._get_role_damage("mechanic") * get_basic_attack_damage_ratio(owner)
	var attack_range: float = get_basic_attack_range(owner)
	var target: Node2D = owner._get_closest_enemy()
	if target == null or not is_instance_valid(target):
		return
	if owner.global_position.distance_squared_to(target.global_position) > attack_range * attack_range:
		return
	if _has_talent(owner, TALENT_BASIC_ATTACK_2) and target.get("damage_reduction_value") != null:
		target.set("damage_reduction_value", float(target.get("damage_reduction_value")) - BASIC_TALENT_SHRED_VALUE)
	var source_id := _create_basic_source_id(owner)
	var count := get_spider_count(owner)
	var side: Vector2 = owner.global_position.direction_to(target.global_position).orthogonal()
	for index in range(count):
		var origin: Vector2 = owner.global_position + side * (float(index) - float(count - 1) * 0.5) * 14.0
		var bullet = owner._spawn_bullet(target, damage_amount, BASIC_BULLET_COLOR, source_id, origin)
		_spawn_spider(owner, bullet)
		if bullet != null and is_instance_valid(bullet):
			bullet.pierce_count += get_spider_pierce_bonus(owner)
	play_command(owner)

func get_basic_attack_damage_ratio(owner) -> float:
	var ratio := PLAYER_BUILD_SYSTEM.get_basic_attack_damage_multiplier(owner, "mechanic") + SKILL_LEVEL_EFFECTS.get_mechanic_damage_ratio_bonus(owner, SKILL_LEVEL_EFFECTS.MECHANIC_BASIC)
	return ratio * (BASIC_TALENT_DAMAGE_MULTIPLIER if _has_talent(owner, TALENT_BASIC_ATTACK_1) else 1.0)

func get_basic_attack_range(owner) -> float:
	return (BASIC_RANGE + SKILL_LEVEL_EFFECTS.get_mechanic_range_bonus(owner, SKILL_LEVEL_EFFECTS.MECHANIC_BASIC)) * PLAYER_BUILD_SYSTEM.get_basic_attack_range_multiplier(owner, "mechanic")

func get_spider_speed(owner) -> float:
	var speed := SPIDER_SPEED + SKILL_LEVEL_EFFECTS.get_mechanic_spider_speed_bonus(owner)
	return speed * (TALENTS.SPIDER_SPEED_MULTIPLIER if LEVELS.has_talent_slot(owner, "mechanic", SKILL_LEVEL_EFFECTS.MECHANIC_BASIC, 2) else 1.0)

func get_spider_count(owner) -> int:
	return TALENTS.SPIDER_COUNT if LEVELS.has_talent_slot(owner, "mechanic", SKILL_LEVEL_EFFECTS.MECHANIC_BASIC, 1) else 1

func get_spider_pierce_bonus(owner) -> int:
	return TALENTS.SPIDER_PIERCE_BONUS if LEVELS.has_talent_slot(owner, "mechanic", SKILL_LEVEL_EFFECTS.MECHANIC_BASIC, 2) else 0

func get_entry_turret_count(owner) -> int:
	return 1 + (1 if _has_talent(owner, TALENT_ENTRY_2) else 0) + (1 if LEVELS.has_talent_slot(owner, "mechanic", SKILL_LEVEL_EFFECTS.MECHANIC_ENTRY, 1) else 0)

func play_command(owner) -> void:
	var visual := owner.get_node_or_null("RoleVisualRoot/RoleSceneVisual") as Node2D
	if visual != null and visual.has_method("play_command"):
		visual.play_command()

func perform_background(owner) -> void:
	var target: Node2D = owner._get_closest_enemy()
	if target == null or not is_instance_valid(target):
		return
	var damage_amount: float = owner._get_role_damage("mechanic") * BACKGROUND_DAMAGE_RATIO
	_spawn_spider(owner, owner._spawn_bullet(target, damage_amount, BASIC_BULLET_COLOR, "mechanic"))

func _spawn_spider(owner, bullet) -> void:
	if bullet == null or not is_instance_valid(bullet):
		return
	bullet.custom_sprite_frames = _get_spider_frames()
	bullet.animated_scene_size = SPIDER_SCENE_SIZE
	bullet.animated_visible_bounds = SPIDER_VISIBLE_BOUNDS
	bullet.speed = get_spider_speed(owner)
	bullet.visual_scale_multiplier = SPIDER_VISUAL_SCALE
	if bullet.has_method("_refresh_bullet_visual"):
		bullet._refresh_bullet_visual(true)

func _get_spider_frames() -> SpriteFrames:
	if cached_spider_frames != null:
		return cached_spider_frames
	var frames := SpriteFrames.new()
	frames.add_animation("crawl")
	frames.set_animation_loop("crawl", true)
	frames.set_animation_speed("crawl", SPIDER_VISUAL_FPS)
	for texture in SPIDER_TEXTURES:
		if texture != null:
			frames.add_frame("crawl", texture)
	cached_spider_frames = frames
	return frames

func perform_enter(owner, _role_id: String, _assault_level: int, assault_multiplier: float) -> int:
	play_command(owner)
	owner._show_switch_banner("进场", "紧急部署", ENTRY_BANNER_COLOR)
	var turret_ability = owner.get("mechanic_tulip_turret_ability")
	if turret_ability != null and turret_ability.has_method("deploy_turret"):
		for index in range(get_entry_turret_count(owner)):
			turret_ability.deploy_turret(owner, assault_multiplier, 1.0 if index % 2 == 0 else -1.0, SKILL_LEVEL_EFFECTS.MECHANIC_ENTRY)
	return 0

func perform_exit(_owner, _role_id: String, _rearguard_level: int) -> int:
	return 0

func perform_ultimate(owner, cast_payload: Dictionary) -> void:
	play_command(owner)
	var center: Vector2 = owner._get_enemy_cluster_center()
	if center == Vector2.ZERO:
		center = owner.global_position
	var cast_damage_multiplier: float = float(cast_payload.get("damage_multiplier", 1.0))
	if owner.has_method("_get_blessing_ultimate_damage_multiplier"):
		cast_damage_multiplier *= float(owner._get_blessing_ultimate_damage_multiplier(ULTIMATE_SKILL_ID))
	var salvo_count: int = max(1, ULTIMATE_SALVO_COUNT + PLAYER_BUILD_SYSTEM.get_mechanic_ultimate_salvo_bonus(owner))
	if _has_talent(owner, TALENT_OVERDRIVE_1):
		salvo_count += 1
	var salvo_ratio: float = ULTIMATE_SALVO_DAMAGE_RATIO + (OVERDRIVE_TALENT_DAMAGE_BONUS if _has_talent(owner, TALENT_OVERDRIVE_2) else 0.0)
	var salvo_damage: float = owner._get_role_damage("mechanic") * salvo_ratio * cast_damage_multiplier * get_summon_damage_multiplier(owner)
	var total_duration: float = ULTIMATE_WARNING_DELAY + float(max(0, salvo_count - 1)) * ULTIMATE_SALVO_INTERVAL + 0.2
	owner._queue_camera_shake(14.0, 0.4)
	owner._delay_level_up_requests(total_duration)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -34.0), "机械全开", ULTIMATE_BLAST_COLOR)
	var salvo_centers: Array[Vector2] = _pick_salvo_centers(owner, center, salvo_count)
	for salvo_index in range(salvo_count):
		var strike_center: Vector2 = salvo_centers[salvo_index]
		var strike_delay: float = ULTIMATE_WARNING_DELAY + float(salvo_index) * ULTIMATE_SALVO_INTERVAL
		var warning := _spawn_ult_warning(owner, strike_center)
		owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
			if warning != null and is_instance_valid(warning):
				warning.queue_free()
			if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
				return
			_spawn_ult_explosion(owner, strike_center)
			owner._queue_camera_shake(6.0, 0.12)
			var hits: int = owner._damage_enemies_in_radius(strike_center, ULTIMATE_SALVO_RADIUS, salvo_damage, 0.0, 1.0, 0.0, "mechanic")
			if hits > 0:
				owner._register_attack_result("mechanic", hits, false)
		, strike_delay)
	owner._apply_post_ultimate_bonuses("mechanic", total_duration)

func _pick_salvo_centers(owner, fallback_center: Vector2, salvo_count: int) -> Array[Vector2]:
	var centers: Array[Vector2] = []
	centers.append(fallback_center)
	if salvo_count > 1:
		var targets: Array = owner._get_enemy_targets(salvo_count, false)
		for target in targets:
			if centers.size() >= salvo_count:
				break
			if target == null or not is_instance_valid(target):
				continue
			var aim_point: Vector2 = owner._get_enemy_aim_point(target, owner.global_position) if owner.has_method("_get_enemy_aim_point") else target.global_position
			centers.append(aim_point)
	while centers.size() < salvo_count:
		var angle: float = TAU * float(centers.size()) / float(max(2, salvo_count))
		centers.append(fallback_center + Vector2.RIGHT.rotated(angle) * 72.0)
	return centers

func _spawn_ult_warning(owner, center: Vector2) -> AnimatedSprite2D:
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return null
	var sprite := AnimatedSprite2D.new()
	sprite.name = "MechanicUltWarning"
	sprite.z_index = 11
	sprite.sprite_frames = _get_ult_warning_frames()
	sprite.animation = StringName("warning")
	sprite.scale = Vector2.ONE * (ULTIMATE_SALVO_RADIUS / ULT_WARNING_VISUAL_MAX_RADIUS)
	sprite.global_position = center
	sprite.add_to_group("temporary_effects")
	scene.add_child(sprite)
	sprite.play("warning")
	return sprite

func _spawn_ult_explosion(owner, center: Vector2) -> void:
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return
	var sprite := AnimatedSprite2D.new()
	sprite.name = "MechanicUltExplosion"
	sprite.z_index = 12
	sprite.sprite_frames = _get_ult_explosion_frames()
	sprite.animation = StringName("explosion")
	sprite.scale = Vector2.ONE * (ULTIMATE_SALVO_RADIUS / ULT_EXPLOSION_VISUAL_MAX_RADIUS)
	sprite.global_position = center
	sprite.add_to_group("temporary_effects")
	scene.add_child(sprite)
	sprite.animation_finished.connect(sprite.queue_free, CONNECT_ONE_SHOT)
	sprite.play("explosion")

func _get_ult_warning_frames() -> SpriteFrames:
	if cached_ult_warning_frames != null:
		return cached_ult_warning_frames
	cached_ult_warning_frames = _build_ult_warning_frames()
	return cached_ult_warning_frames

func _build_ult_warning_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("warning")
	frames.set_animation_loop("warning", true)
	frames.set_animation_speed("warning", ULT_WARNING_VISUAL_FPS)
	for texture in ULT_WARNING_TEXTURES:
		if texture != null:
			frames.add_frame("warning", texture)
	return frames

func _get_ult_explosion_frames() -> SpriteFrames:
	if cached_ult_explosion_frames != null:
		return cached_ult_explosion_frames
	cached_ult_explosion_frames = _build_ult_explosion_frames()
	return cached_ult_explosion_frames

func _build_ult_explosion_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("explosion")
	frames.set_animation_loop("explosion", false)
	frames.set_animation_speed("explosion", ULT_EXPLOSION_VISUAL_FPS)
	for texture in ULT_EXPLOSION_TEXTURES:
		if texture != null:
			frames.add_frame("explosion", texture)
	return frames

func update_trait_state(owner, delta: float) -> void:
	if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
		return
	if not owner.has_method("_get_active_role"):
		return
	if str(owner._get_active_role().get("id", "")) != "mechanic":
		if not LEVELS.has_talent_slot(owner, "mechanic", SKILL_LEVEL_EFFECTS.MECHANIC_TRAIT, 1):
			return
		var in_team := false
		for role in owner.roles:
			if str(role.get("id", "")) == "mechanic":
				in_team = true
				break
		if not in_team:
			return
	var state: Dictionary = _get_talent_state(owner)
	var parts: int = int(state.get("parts", 0))
	var parts_max: int = get_parts_max(owner)
	if parts >= parts_max:
		state["parts_elapsed"] = 0.0
		return
	var part_interval: float = get_part_interval(owner)
	var elapsed: float = float(state.get("parts_elapsed", 0.0)) + delta
	while elapsed >= part_interval and parts < parts_max:
		elapsed -= part_interval
		parts += 1
	state["parts"] = parts
	state["parts_elapsed"] = elapsed

func get_parts_count(owner) -> int:
	if owner == null or not owner.has_method("_get_role_special_state"):
		return 0
	var role_state: Dictionary = owner.role_special_states.get("mechanic", {})
	return int((role_state.get("talent_runtime", {}) as Dictionary).get("parts", 0))

func get_parts_max(owner) -> int:
	var bonus := SKILL_LEVEL_EFFECTS.get_mechanic_part_max_bonus(owner)
	if LEVELS.has_talent_slot(owner, "mechanic", SKILL_LEVEL_EFFECTS.MECHANIC_TRAIT, 2):
		bonus += TALENTS.PART_CAP_BONUS
	return TRAIT_PART_MAX + PLAYER_BUILD_SYSTEM.get_mechanic_part_max_bonus(owner) + bonus + (TRAIT_TALENT_PART_MAX_BONUS if _has_talent(owner, TALENT_TRAIT_2) else 0)

func get_part_interval(owner) -> float:
	var interval: float = max(1.0, TRAIT_PART_INTERVAL - PLAYER_BUILD_SYSTEM.get_mechanic_part_interval_reduction(owner))
	if _has_talent(owner, TALENT_TRAIT_1):
		interval = min(interval, TRAIT_TALENT_PART_INTERVAL)
	interval = max(1.0, interval - SKILL_LEVEL_EFFECTS.get_mechanic_part_interval_reduction(owner))
	return interval * (TALENTS.PART_INTERVAL_MULTIPLIER if LEVELS.has_talent_slot(owner, "mechanic", SKILL_LEVEL_EFFECTS.MECHANIC_TRAIT, 1) else 1.0)

func get_part_damage_bonus(owner) -> float:
	var per_part_bonus: float = TRAIT_PART_DAMAGE_BONUS + PLAYER_BUILD_SYSTEM.get_mechanic_part_damage_bonus(owner)
	if _has_talent(owner, TALENT_TRAIT_2):
		per_part_bonus = max(per_part_bonus, TRAIT_TALENT_PART_DAMAGE_BONUS)
	if LEVELS.has_talent_slot(owner, "mechanic", SKILL_LEVEL_EFFECTS.MECHANIC_TRAIT, 2):
		per_part_bonus += TALENTS.PART_DAMAGE_BONUS
	return per_part_bonus + SKILL_LEVEL_EFFECTS.get_mechanic_part_damage_bonus(owner)

func get_summon_damage_multiplier(owner) -> float:
	return 1.0 + get_part_damage_bonus(owner) * float(get_parts_count(owner))

func get_basic_attack_interval_multiplier(_owner) -> float:
	return 1.0

func _get_talent_state(owner) -> Dictionary:
	if owner == null or not owner.has_method("_get_role_special_state"):
		return {}
	var role_state: Dictionary = owner._get_role_special_state("mechanic")
	if not role_state.has("talent_runtime"):
		role_state["talent_runtime"] = {}
	return role_state["talent_runtime"]

func _has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_level_talent") and bool(owner._has_level_talent(talent_id))

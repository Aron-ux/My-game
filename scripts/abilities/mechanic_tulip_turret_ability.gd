extends RefCounted

const TURRET_TEXTURES := [
	preload("res://effects/mechanic/tulip_turret/1.png"),
	preload("res://effects/mechanic/tulip_turret/2.png"),
	preload("res://effects/mechanic/tulip_turret/3.png")
]

const SKILL_ID := "tulip_turret"
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const SKILL_LEVEL_EFFECTS := preload("res://scripts/player/player_skill_level_effect_flow.gd")
const LEVELS := preload("res://scripts/player/player_skill_level_system.gd")
const TALENTS := LEVELS.MECHANIC_TALENTS
const COOLDOWN := 20.0
const DURATION := 8.0
const FIRE_INTERVAL := 0.8
const DAMAGE_RATIO := 1.2
const DEPLOY_OFFSET := 44.0
const TALENT_TURRET_1 := "mechanic_level_talent_turret_1"
const TALENT_TURRET_2 := "mechanic_level_talent_turret_2"
const TALENT_ENTRY_1 := "mechanic_level_talent_entry_1"
const TALENT_FIRE_INTERVAL := 0.6
const TALENT_DURATION_BONUS := 2.0
const TALENT_DAMAGE_RATIO := 1.5
const TURRET_COLOR := Color(0.95, 0.68, 0.25, 1.0)
const TURRET_VISUAL_SCALE := 0.35
const TURRET_VISUAL_OFFSET := Vector2(0.0, -96.0)
const TURRET_VISUAL_FPS := 9.0

var cooldown_remaining: float = 0.0
var active_turrets: Array[Dictionary] = []
var pending_saved_turrets: Array[Dictionary] = []
var cached_turret_frames: SpriteFrames


func update(owner, delta: float) -> void:
	cooldown_remaining = max(0.0, cooldown_remaining - delta)
	for index in range(active_turrets.size() - 1, -1, -1):
		var data: Dictionary = active_turrets[index]
		var turret: Node2D = data.get("node", null) as Node2D
		if owner == null or not is_instance_valid(owner) or turret == null or not is_instance_valid(turret):
			if turret != null and is_instance_valid(turret):
				turret.queue_free()
			active_turrets.remove_at(index)
			continue
		var remaining: float = float(data.get("remaining", 0.0)) - delta
		if remaining <= 0.0:
			turret.queue_free()
			active_turrets.remove_at(index)
			continue
		var tick_elapsed: float = float(data.get("tick_elapsed", 0.0)) + delta
		data["remaining"] = remaining
		data["tick_elapsed"] = tick_elapsed
		active_turrets[index] = data
		if tick_elapsed >= _get_fire_interval(owner, str(data.get("progress_id", SKILL_LEVEL_EFFECTS.MECHANIC_TULIP_TURRET))):
			data["tick_elapsed"] = 0.0
			active_turrets[index] = data
			_fire(owner, data)


func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and role_id == "mechanic" and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and _is_unlocked(owner) and cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, "mechanic"):
		return false
	if deploy_turret(owner, 1.0) == null:
		return false
	cooldown_remaining = get_cooldown(owner)
	owner.mechanic_role.play_command(owner)
	return true


func deploy_turret(owner, damage_scale: float = 1.0, direction_sign: float = 1.0, progress_id: String = SKILL_LEVEL_EFFECTS.MECHANIC_TULIP_TURRET):
	if owner == null or not is_instance_valid(owner):
		return null
	if progress_id != SKILL_LEVEL_EFFECTS.MECHANIC_ENTRY:
		progress_id = SKILL_LEVEL_EFFECTS.MECHANIC_TULIP_TURRET
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return null
	var direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	if direction_sign < 0.0:
		direction = -direction
	var turret := Node2D.new()
	turret.name = "MechanicTulipTurret"
	turret.z_index = 25
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = _get_turret_frames()
	sprite.animation = StringName("fire")
	sprite.offset = TURRET_VISUAL_OFFSET
	sprite.scale = Vector2.ONE * TURRET_VISUAL_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.animation_finished.connect(func(): sprite.frame = 0)
	turret.add_child(sprite)
	turret.global_position = owner.global_position + direction.normalized() * DEPLOY_OFFSET
	turret.rotation = direction.angle()
	_update_facing(turret)
	scene.add_child(turret)
	active_turrets.append({
		"node": turret,
		"remaining": _get_duration(owner, progress_id),
		"tick_elapsed": 0.0,
		"damage_scale": max(0.0, damage_scale),
		"progress_id": progress_id
	})
	return turret


func get_cooldown(_owner) -> float:
	return COOLDOWN


func get_cooldown_slot(owner = null) -> Dictionary:
	return {
		"name": "定点机炮",
		"remaining": clamp(cooldown_remaining, 0.0, COOLDOWN),
		"duration": get_cooldown(owner),
		"color": TURRET_COLOR,
		"description": "在原地部署定点机炮，自动射击最近的敌人。",
		"effect_rows": [
			{"label": "单发伤害倍率", "value": "%.0f%%" % (_get_damage_ratio(owner) * 100.0)},
			{"label": "射击间隔", "value": "%.1f 秒" % _get_fire_interval(owner)},
			{"label": "持续时间", "value": "%.1f 秒" % _get_duration(owner)},
			{"label": "每次射击", "value": "%d 发" % _get_shot_count(owner, SKILL_LEVEL_EFFECTS.MECHANIC_TULIP_TURRET)}
		],
		"effect_note": "按当前强化下的标准部署计算；实际伤害还受角色攻击力、暴击和目标防御影响。"
	}


func _get_duration(owner, progress_id: String = SKILL_LEVEL_EFFECTS.MECHANIC_TULIP_TURRET) -> float:
	var duration: float = DURATION + PLAYER_BUILD_SYSTEM.get_mechanic_turret_duration_bonus(owner)
	if _has_talent(owner, TALENT_TURRET_2) or _has_talent(owner, TALENT_ENTRY_1):
		duration += TALENT_DURATION_BONUS
	if LEVELS.has_talent_slot(owner, "mechanic", progress_id, 2):
		duration += TALENTS.ENTRY_DURATION_BONUS if progress_id == SKILL_LEVEL_EFFECTS.MECHANIC_ENTRY else TALENTS.TURRET_DURATION_BONUS
	return duration + SKILL_LEVEL_EFFECTS.get_mechanic_duration_bonus(owner, progress_id)


func _get_damage_ratio(owner, progress_id: String = SKILL_LEVEL_EFFECTS.MECHANIC_TULIP_TURRET) -> float:
	var ratio: float = TALENT_DAMAGE_RATIO if _has_talent(owner, TALENT_TURRET_2) else DAMAGE_RATIO
	ratio += SKILL_LEVEL_EFFECTS.get_mechanic_damage_ratio_bonus(owner, progress_id)
	return ratio * PLAYER_BUILD_SYSTEM.get_mechanic_turret_damage_multiplier(owner) * _get_summon_damage_multiplier(owner)


func get_save_data() -> Dictionary:
	var turrets: Array[Dictionary] = []
	for data in active_turrets:
		var turret: Node2D = data.get("node", null) as Node2D
		if turret == null or not is_instance_valid(turret):
			continue
		turrets.append({
			"position": _encode_vector2(turret.global_position),
			"rotation": turret.rotation,
			"remaining": max(0.0, float(data.get("remaining", 0.0))),
			"tick_elapsed": max(0.0, float(data.get("tick_elapsed", 0.0))),
			"damage_scale": max(0.0, float(data.get("damage_scale", 1.0))),
			"progress_id": str(data.get("progress_id", SKILL_LEVEL_EFFECTS.MECHANIC_TULIP_TURRET))
		})
	return {"cooldown_remaining": cooldown_remaining, "turrets": turrets}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	_clear_turrets()
	pending_saved_turrets.clear()
	var saved_turrets: Variant = data.get("turrets", [])
	if saved_turrets is Array:
		for saved_data in saved_turrets:
			if saved_data is Dictionary:
				pending_saved_turrets.append((saved_data as Dictionary).duplicate(true))


func restore_effect_if_active(owner) -> void:
	var tree: SceneTree = owner.get_tree() if owner != null and is_instance_valid(owner) and owner.has_method("get_tree") else null
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return
	for saved_data in pending_saved_turrets:
		var remaining: float = max(0.0, float(saved_data.get("remaining", 0.0)))
		if remaining <= 0.0:
			continue
		var turret = deploy_turret(owner, float(saved_data.get("damage_scale", 1.0)), 1.0, str(saved_data.get("progress_id", SKILL_LEVEL_EFFECTS.MECHANIC_TULIP_TURRET)))
		if turret == null:
			continue
		turret.global_position = _decode_vector2(saved_data.get("position", []), owner.global_position)
		turret.rotation = float(saved_data.get("rotation", 0.0))
		_update_facing(turret)
		for index in range(active_turrets.size()):
			if active_turrets[index].get("node", null) == turret:
				var data: Dictionary = active_turrets[index]
				data["remaining"] = remaining
				data["tick_elapsed"] = clamp(float(saved_data.get("tick_elapsed", 0.0)), 0.0, FIRE_INTERVAL)
				active_turrets[index] = data
				break
	pending_saved_turrets.clear()


func _fire(owner, data: Dictionary) -> void:
	var turret: Node2D = data.get("node", null) as Node2D
	if turret == null or not is_instance_valid(turret) or not owner.has_method("_get_enemy_nearest_to_position"):
		return
	var target: Node2D = owner._get_enemy_nearest_to_position(turret.global_position)
	if target == null or not is_instance_valid(target):
		return
	turret.rotation = turret.global_position.direction_to(target.global_position).angle()
	_update_facing(turret)
	var sprite := turret.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.play("fire")
		sprite.set_frame_and_progress(1, 0.0)
	var progress_id := str(data.get("progress_id", SKILL_LEVEL_EFFECTS.MECHANIC_TULIP_TURRET))
	var damage_amount: float = owner._get_role_damage("mechanic") * _get_damage_ratio(owner, progress_id) * float(data.get("damage_scale", 1.0))
	var muzzle := Vector2(-96.0 if cos(turret.rotation) < 0.0 else 96.0, -90.0) * TURRET_VISUAL_SCALE
	var count := _get_shot_count(owner, progress_id)
	for index in range(count):
		owner._spawn_bullet(target, damage_amount, TURRET_COLOR, "mechanic", turret.global_position + muzzle + Vector2(0.0, (float(index) - float(count - 1) * 0.5) * 12.0))


func _update_facing(turret: Node2D) -> void:
	var sprite := turret.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	# Save data keeps the aim angle; the side-view chassis stays level.
	sprite.rotation = -turret.rotation
	sprite.flip_h = cos(turret.rotation) < 0.0


func _get_turret_frames() -> SpriteFrames:
	if cached_turret_frames != null:
		return cached_turret_frames
	cached_turret_frames = _build_turret_frames()
	return cached_turret_frames


func _build_turret_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("fire")
	frames.set_animation_loop("fire", false)
	frames.set_animation_speed("fire", TURRET_VISUAL_FPS)
	for texture in TURRET_TEXTURES:
		if texture != null:
			frames.add_frame("fire", texture)
	return frames


func _get_fire_interval(owner, progress_id: String = SKILL_LEVEL_EFFECTS.MECHANIC_TULIP_TURRET) -> float:
	var interval := TALENT_FIRE_INTERVAL if _has_talent(owner, TALENT_TURRET_1) else FIRE_INTERVAL
	if LEVELS.has_talent_slot(owner, "mechanic", progress_id, 2):
		interval *= TALENTS.ENTRY_FIRE_INTERVAL_MULTIPLIER if progress_id == SKILL_LEVEL_EFFECTS.MECHANIC_ENTRY else TALENTS.TURRET_FIRE_INTERVAL_MULTIPLIER
	return interval


func _get_shot_count(owner, progress_id: String) -> int:
	return TALENTS.TURRET_SHOT_COUNT if progress_id == SKILL_LEVEL_EFFECTS.MECHANIC_TULIP_TURRET and LEVELS.has_talent_slot(owner, "mechanic", progress_id, 1) else 1


func _clear_turrets() -> void:
	for data in active_turrets:
		var turret: Node2D = data.get("node", null) as Node2D
		if turret != null and is_instance_valid(turret):
			turret.queue_free()
	active_turrets.clear()


func _encode_vector2(value: Vector2) -> Array:
	return [value.x, value.y]


func _decode_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback


func _get_summon_damage_multiplier(owner) -> float:
	var role = owner.get("mechanic_role") if owner != null else null
	if role != null and role.has_method("get_summon_damage_multiplier"):
		return float(role.get_summon_damage_multiplier(owner))
	return 1.0


func _is_unlocked(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))


func _has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_level_talent") and bool(owner._has_level_talent(talent_id))

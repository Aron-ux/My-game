extends RefCounted

const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")

const HIT_FLASH_DURATION := 0.18
const HIT_FLASH_DIM_ALPHA := 0.26
const HIT_STOP_DURATION := 0.07
const HIT_DEFORMATION_DURATION := 0.19
const HIT_DEFORMATION_IMPACT_SCALE := Vector2(1.14, 0.84)
const HIT_DEFORMATION_REBOUND_SCALE := Vector2(0.95, 1.06)
const HIT_RECOIL_DISTANCE := 5.0
const HIT_RECOIL_HEIGHT := 4.0
const DAMAGE_NUMBER_BUDGET_PER_FRAME := 12
const DEATH_BURST_BUDGET_PER_FRAME := 8
const LOW_FPS_DAMAGE_NUMBER_BUDGET_PER_FRAME := 6
const CRITICAL_FPS_DAMAGE_NUMBER_BUDGET_PER_FRAME := 3
const LOW_FPS_DEATH_BURST_BUDGET_PER_FRAME := 4
const CRITICAL_FPS_DEATH_BURST_BUDGET_PER_FRAME := 2
const HIT_FLASH_BUDGET_PER_FRAME := 28
const LOW_FPS_HIT_FLASH_BUDGET_PER_FRAME := 12
const CRITICAL_FPS_HIT_FLASH_BUDGET_PER_FRAME := 5
const KILL_DAMAGE_NUMBER_BUDGET_PER_FRAME := 6
const LOW_FPS_KILL_DAMAGE_NUMBER_BUDGET_PER_FRAME := 3
const CRITICAL_FPS_KILL_DAMAGE_NUMBER_BUDGET_PER_FRAME := 1
const DAMAGE_LABEL_POOL_LIMIT := 64
const DEATH_BURST_POOL_LIMIT := 32
const BOSS_HIT_FLASH_OVERLAY_NAME := "BossHitFlashOverlay"
const BOSS_HIT_FLASH_TWEEN_META := "boss_hit_flash_tween"
const GENERIC_FLASH_TWEEN_META := "enemy_hit_feedback_flash_tween"
const DEFORMATION_BASE_SCALE_META := "enemy_hit_deformation_base_scale"
const DEFORMATION_TWEEN_META := "enemy_hit_deformation_tween"

static var damage_number_budget_frame: int = -1
static var damage_number_budget_used: int = 0
static var kill_damage_number_budget_frame: int = -1
static var kill_damage_number_budget_used: int = 0
static var death_burst_budget_frame: int = -1
static var death_burst_budget_used: int = 0
static var hit_flash_budget_frame: int = -1
static var hit_flash_budget_used: int = 0
static var boss_hit_flash_shader: Shader
static var boss_hit_flash_material: ShaderMaterial
static var damage_label_pool: Array = []
static var death_burst_pool: Array = []
static var active_damage_labels: Array[Dictionary] = []
static var active_death_bursts: Array[Dictionary] = []
static var feedback_animation_frame: int = -1

static func clear_runtime_state() -> void:
	for pool in [damage_label_pool, death_burst_pool]:
		for node in pool:
			if is_instance_valid(node) and node is Node and not (node as Node).is_queued_for_deletion():
				(node as Node).free()
	damage_label_pool.clear()
	death_burst_pool.clear()
	active_damage_labels.clear()
	active_death_bursts.clear()
	feedback_animation_frame = -1

static func update_feedback_animations(delta: float) -> void:
	_update_static_feedback_animations(delta)

static func play_hit_feedback(enemy, damage_amount: float, killed: bool, is_critical: bool = false) -> void:
	_update_static_feedback_animations(1.0 / float(Engine.physics_ticks_per_second))
	_apply_hit_stop(enemy)
	if killed or _consume_hit_flash_budget():
		enemy.hit_flash_remaining = HIT_FLASH_DURATION
		_play_custom_hit_visual(enemy)
		_play_generic_visual_flash(enemy)
		_play_hit_deformation(enemy)
		_spawn_boss_hit_flash_overlay(enemy)
		if enemy.has_method("_update_status_visuals"):
			enemy._update_status_visuals()

	var can_show_damage_number := _consume_kill_damage_number_budget() if killed else _consume_damage_number_budget()
	if can_show_damage_number:
		show_damage_number(enemy, damage_amount, killed, is_critical)
	if killed and _consume_death_burst_budget():
		spawn_death_burst(enemy)

static func play_light_hit_feedback(enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	_update_static_feedback_animations(1.0 / float(Engine.physics_ticks_per_second))
	_apply_hit_stop(enemy)
	if not _consume_hit_flash_budget():
		return
	enemy.hit_flash_remaining = HIT_FLASH_DURATION
	_play_custom_hit_visual(enemy)
	_play_generic_visual_flash(enemy)
	_play_hit_deformation(enemy)
	_spawn_boss_hit_flash_overlay(enemy)
	if enemy.has_method("_update_status_visuals"):
		enemy._update_status_visuals()

static func _apply_hit_stop(enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if str(enemy.get("enemy_kind")) in ["boss", "small_boss"]:
		return
	enemy.hit_stop_remaining = maxf(float(enemy.hit_stop_remaining), HIT_STOP_DURATION)

static func _play_custom_hit_visual(enemy) -> void:
	var cached_visual: Node = enemy.get("cached_motion_visual") as Node
	if _is_valid_hit_visual(enemy, cached_visual) and cached_visual.has_method("play_hit"):
		cached_visual.play_hit()
		return
	var fallback_visual: Node = _find_hit_visual(enemy)
	if fallback_visual == null:
		return
	enemy.set("cached_motion_visual", fallback_visual)
	if fallback_visual.has_method("play_hit"):
		fallback_visual.play_hit()

static func _find_hit_visual(enemy) -> Node:
	for visual_name in ["MushroomVisual", "SlimeVisual", "FlyingEyeVisual", "PumpkinVisual"]:
		var visual: Node = enemy.get_node_or_null(visual_name)
		if _is_valid_hit_visual(enemy, visual) and visual.has_method("play_hit"):
			return visual
	return null

static func _is_valid_hit_visual(enemy, visual: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Node):
		return false
	if not (enemy as Node).is_inside_tree():
		return false
	if visual == null or not is_instance_valid(visual):
		return false
	if visual.is_queued_for_deletion() or not visual.is_inside_tree():
		return false
	return (enemy as Node).is_ancestor_of(visual)

static func _play_generic_visual_flash(enemy) -> void:
	# Authored visuals without a hit animation still need a readable white flash.
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Node):
		return
	var polygon := (enemy as Node).get_node_or_null("Polygon2D") as CanvasItem
	if polygon != null and polygon.visible:
		_flash_canvas_item(polygon)
	for visual_name in ["ProfileVisual", "BossVisual"]:
		var visual := (enemy as Node).get_node_or_null(visual_name)
		if visual != null and is_instance_valid(visual):
			_flash_visual_tree(visual)

static func _flash_visual_tree(node: Node) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	var node_name := str(node.name).to_lower()
	if "shadow" in node_name or node_name == "statusroot":
		return
	if node is CanvasItem:
		_flash_canvas_item(node as CanvasItem)
	for child in node.get_children():
		_flash_visual_tree(child)

static func _flash_canvas_item(item: CanvasItem) -> void:
	if item == null or not is_instance_valid(item) or not item.visible:
		return
	var previous_tween: Tween = item.get_meta(GENERIC_FLASH_TWEEN_META) as Tween if item.has_meta(GENERIC_FLASH_TWEEN_META) else null
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	var original: Color = item.modulate
	item.modulate = Color(1.0, 1.0, 1.0, original.a)
	var tween := item.create_tween()
	item.set_meta(GENERIC_FLASH_TWEEN_META, tween)
	tween.tween_property(item, "modulate", original, HIT_FLASH_DURATION)

static func _play_hit_deformation(enemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Node):
		return
	if str(enemy.get("enemy_kind")) in ["boss", "small_boss"]:
		return
	var polygon := (enemy as Node).get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null and polygon.visible:
		_tween_hit_deformation(polygon)
		_tween_hit_recoil(polygon, enemy)
	for visual_name in ["ProfileVisual", "BossVisual"]:
		var visual := (enemy as Node).get_node_or_null(visual_name)
		if visual == null or not is_instance_valid(visual):
			continue
		if _visual_has_builtin_deformation(visual):
			continue
		var target: Node2D = visual.call("get_hit_deformation_target") as Node2D if visual.has_method("get_hit_deformation_target") else null
		if target != null:
			_tween_hit_deformation(target)
			_tween_hit_recoil(target, enemy)
		else:
			_collect_deformation_targets(visual)

static func _visual_has_builtin_deformation(visual: Node) -> bool:
	var script := visual.get_script() as Script
	while script != null:
		if script.resource_path == "res://assets/enemies/pixel_sheet_visual.gd":
			return true
		script = script.get_base_script()
	return false

static func _collect_deformation_targets(node: Node) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	var node_name := str(node.name).to_lower()
	if "shadow" in node_name or "statusroot" in node_name or "skillfx" in node_name or "hitflash" in node_name or BOSS_HIT_FLASH_OVERLAY_NAME.to_lower() in node_name:
		return
	if node is AnimatedSprite2D or node is Sprite2D or node is Polygon2D:
		var canvas_item := node as CanvasItem
		if canvas_item.visible:
			_tween_hit_deformation(node as Node2D)
		return
	for child in node.get_children():
		_collect_deformation_targets(child)

static func _tween_hit_deformation(target: Node2D) -> void:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	var previous_tween: Tween = target.get_meta(DEFORMATION_TWEEN_META) as Tween if target.has_meta(DEFORMATION_TWEEN_META) else null
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	var base_scale: Vector2 = target.get_meta(DEFORMATION_BASE_SCALE_META) if target.has_meta(DEFORMATION_BASE_SCALE_META) else target.scale
	target.set_meta(DEFORMATION_BASE_SCALE_META, base_scale)
	var tween := target.create_tween()
	target.set_meta(DEFORMATION_TWEEN_META, tween)
	tween.tween_property(target, "scale", base_scale * HIT_DEFORMATION_IMPACT_SCALE, HIT_DEFORMATION_DURATION * 0.29).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", base_scale * HIT_DEFORMATION_REBOUND_SCALE, HIT_DEFORMATION_DURATION * 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", base_scale, HIT_DEFORMATION_DURATION * 0.37).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func _tween_hit_recoil(target: Node2D, enemy) -> void:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	const BASE_POSITION_META := "enemy_hit_recoil_base_position"
	const TWEEN_META := "enemy_hit_recoil_tween"
	var previous_tween: Tween = target.get_meta(TWEEN_META) as Tween if target.has_meta(TWEEN_META) else null
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	var base_position: Vector2 = target.get_meta(BASE_POSITION_META) if target.has_meta(BASE_POSITION_META) else target.position
	target.set_meta(BASE_POSITION_META, base_position)
	var backward := _get_hit_recoil_direction(enemy)
	var impact_position := base_position + backward * HIT_RECOIL_DISTANCE + Vector2.UP * HIT_RECOIL_HEIGHT
	var settle_position := base_position + backward * (HIT_RECOIL_DISTANCE * 0.28) + Vector2.UP * (HIT_RECOIL_HEIGHT * 0.35)
	var tween := target.create_tween()
	target.set_meta(TWEEN_META, tween)
	tween.tween_property(target, "position", impact_position, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "position", settle_position, 0.055).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "position", base_position, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

static func _get_hit_recoil_direction(enemy) -> Vector2:
	if enemy != null and enemy.get("velocity") is Vector2:
		var velocity: Vector2 = enemy.get("velocity")
		if absf(velocity.x) > 0.01:
			return Vector2(-signf(velocity.x), 0.0)
	if enemy != null and enemy.get("_cached_direction_to_target") is Vector2:
		var direction_to_target: Vector2 = enemy.get("_cached_direction_to_target")
		if absf(direction_to_target.x) > 0.01:
			return Vector2(-signf(direction_to_target.x), 0.0)
	return Vector2.LEFT

static func get_hit_flash_alpha(hit_flash_remaining: float) -> float:
	if hit_flash_remaining <= 0.0:
		return 1.0
	var ratio: float = clamp(hit_flash_remaining / max(HIT_FLASH_DURATION, 0.001), 0.0, 1.0)
	return lerpf(1.0, HIT_FLASH_DIM_ALPHA, ratio)

static func apply_hit_flash_alpha_to_node(node: Node, alpha: float) -> void:
	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		var color: Color = canvas_item.modulate
		var original_alpha: float = color.a
		var flash_strength: float = clamp(1.0 - alpha, 0.0, 1.0)
		color = color.lerp(Color.WHITE, flash_strength)
		color.a = original_alpha
		canvas_item.modulate = color
	for child in node.get_children():
		apply_hit_flash_alpha_to_node(child, alpha)

static func _spawn_boss_hit_flash_overlay(enemy) -> void:
	if not _should_apply_immediate_model_flash(enemy):
		return
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Node):
		return
	var visual_root: Node = (enemy as Node).get_node_or_null("ProfileVisual")
	if visual_root == null and enemy.get("boss_visual_instance") != null:
		visual_root = enemy.get("boss_visual_instance") as Node
	if visual_root == null or not is_instance_valid(visual_root):
		return
	var source_sprites: Array[AnimatedSprite2D] = []
	_collect_boss_flash_sprites(visual_root, source_sprites)
	if source_sprites.is_empty():
		return
	for source_sprite: AnimatedSprite2D in source_sprites:
		_spawn_boss_hit_flash_overlay_for_sprite(source_sprite)

static func _spawn_boss_hit_flash_overlay_for_sprite(source_sprite: AnimatedSprite2D) -> void:
	if source_sprite == null or not is_instance_valid(source_sprite) or source_sprite.sprite_frames == null:
		return
	var current_frame_texture: Texture2D = source_sprite.sprite_frames.get_frame_texture(source_sprite.animation, source_sprite.frame)
	if current_frame_texture == null:
		return
	var overlay: Sprite2D = source_sprite.get_node_or_null(BOSS_HIT_FLASH_OVERLAY_NAME) as Sprite2D
	if overlay == null:
		overlay = Sprite2D.new()
		overlay.name = BOSS_HIT_FLASH_OVERLAY_NAME
		overlay.z_index = source_sprite.z_index + 20
		overlay.show_behind_parent = false
		source_sprite.add_child(overlay)
		overlay.material = _get_boss_hit_flash_material()
	overlay.texture = current_frame_texture
	overlay.centered = source_sprite.centered
	overlay.offset = source_sprite.offset
	overlay.flip_h = source_sprite.flip_h
	overlay.flip_v = source_sprite.flip_v
	overlay.position = Vector2.ZERO
	overlay.rotation = 0.0
	overlay.scale = Vector2.ONE
	overlay.modulate = Color(1.0, 1.0, 1.0, 0.7)
	overlay.visible = true
	var tween: Tween = overlay.get_meta(BOSS_HIT_FLASH_TWEEN_META) as Tween if overlay.has_meta(BOSS_HIT_FLASH_TWEEN_META) else null
	if tween != null and tween.is_valid():
		# Refresh a single animation instead of stacking competing tweens on hit.
		tween.stop()
		tween.play()
		return
	tween = overlay.create_tween()
	overlay.set_meta(BOSS_HIT_FLASH_TWEEN_META, tween)
	tween.tween_property(overlay, "modulate:a", 0.0, HIT_FLASH_DURATION).from(0.7)
	tween.tween_callback(func() -> void:
		if is_instance_valid(overlay):
			overlay.visible = false
	)

static func _get_boss_hit_flash_material() -> ShaderMaterial:
	if boss_hit_flash_material != null:
		return boss_hit_flash_material
	if boss_hit_flash_shader == null:
		boss_hit_flash_shader = Shader.new()
		boss_hit_flash_shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 tex = texture(TEXTURE, UV);\n\tCOLOR = vec4(1.0, 1.0, 1.0, tex.a * COLOR.a);\n}\n"
	boss_hit_flash_material = ShaderMaterial.new()
	boss_hit_flash_material.shader = boss_hit_flash_shader
	return boss_hit_flash_material

static func _collect_boss_flash_sprites(root: Node, output: Array[AnimatedSprite2D]) -> void:
	if root is AnimatedSprite2D:
		var sprite: AnimatedSprite2D = root as AnimatedSprite2D
		if sprite.visible and not _is_shadow_flash_sprite(sprite):
			output.append(sprite)
	for child in root.get_children():
		_collect_boss_flash_sprites(child, output)

static func _is_shadow_flash_sprite(sprite: AnimatedSprite2D) -> bool:
	if sprite == null:
		return true
	var node: Node = sprite
	while node != null:
		if str(node.name).to_lower().contains("shadow"):
			return true
		node = node.get_parent()
	return false

static func _should_apply_immediate_model_flash(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var kind: String = str(enemy.get("enemy_kind"))
	return kind == "small_boss" or kind == "boss"

static func show_damage_number(enemy, damage_amount: float, killed: bool, is_critical: bool = false) -> void:
	var current_scene: Node = _get_enemy_current_scene(enemy)
	if current_scene == null:
		return
	if not _can_spawn_temporary_effect(current_scene):
		return

	var label := _acquire_damage_label(current_scene)
	label.text = str(max(1, int(round(damage_amount))))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var label_color: Color = Color(1.0, 1.0, 1.0, 0.98)
	var label_font_size: int = 18
	var outline_color := Color(0.04, 0.02, 0.01, 0.92)
	var outline_size := 3
	if is_critical:
		label_color = Color(1.0, 0.36, 0.12, 1.0)
		label_font_size = 34
		outline_color = Color(0.18, 0.015, 0.005, 0.96)
		outline_size = 6
	label.modulate = label_color
	label.size = Vector2(maxf(72.0, float(label.text.length() * label_font_size) * 0.72), 30.0)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.78, 0.78) if is_critical else Vector2(0.92, 0.92)
	label.add_theme_font_size_override("font_size", label_font_size)
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	label.z_index = 20
	label.global_position = enemy.global_position + Vector2(-36.0, -42.0)

	var start_position: Vector2 = label.global_position
	var animation_duration: float = 1.02 if is_critical else 0.72
	var start_scale := Vector2(0.52, 0.52) if is_critical else Vector2(0.78, 0.78)
	var peak_scale := Vector2(1.58, 1.58) if is_critical else Vector2(1.08, 1.08)
	var settle_scale := Vector2(1.18, 1.18) if is_critical else Vector2.ONE
	active_damage_labels.append({
		"node": label,
		"elapsed": 0.0,
		"duration": animation_duration,
		"start_position": start_position,
		"pop_position": start_position + Vector2(randf_range(-4.0, 4.0), -10.0),
		"target_position": start_position + Vector2(randf_range(-18.0, 18.0), -62.0 if is_critical else -52.0),
		"start_alpha": label.modulate.a,
		"start_scale": start_scale,
		"peak_scale": peak_scale,
		"settle_scale": settle_scale,
		"pop_duration": 0.07 if is_critical else 0.06,
		"hold_duration": 0.34 if is_critical else 0.20
	})

static func _consume_damage_number_budget() -> bool:
	var current_frame := Engine.get_physics_frames()
	if damage_number_budget_frame != current_frame:
		damage_number_budget_frame = current_frame
		damage_number_budget_used = 0
	if damage_number_budget_used >= _get_damage_number_budget_per_frame():
		return false
	damage_number_budget_used += 1
	return true

static func _consume_death_burst_budget() -> bool:
	var current_frame := Engine.get_physics_frames()
	if death_burst_budget_frame != current_frame:
		death_burst_budget_frame = current_frame
		death_burst_budget_used = 0
	if death_burst_budget_used >= _get_death_burst_budget_per_frame():
		return false
	death_burst_budget_used += 1
	return true

static func _get_damage_number_budget_per_frame() -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_DAMAGE_NUMBER_BUDGET_PER_FRAME
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_DAMAGE_NUMBER_BUDGET_PER_FRAME
	return DAMAGE_NUMBER_BUDGET_PER_FRAME

static func _consume_kill_damage_number_budget() -> bool:
	var current_frame := Engine.get_physics_frames()
	if kill_damage_number_budget_frame != current_frame:
		kill_damage_number_budget_frame = current_frame
		kill_damage_number_budget_used = 0
	if kill_damage_number_budget_used >= _get_kill_damage_number_budget_per_frame():
		return false
	kill_damage_number_budget_used += 1
	return true

static func _get_kill_damage_number_budget_per_frame() -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_KILL_DAMAGE_NUMBER_BUDGET_PER_FRAME
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_KILL_DAMAGE_NUMBER_BUDGET_PER_FRAME
	return KILL_DAMAGE_NUMBER_BUDGET_PER_FRAME

static func _get_death_burst_budget_per_frame() -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_DEATH_BURST_BUDGET_PER_FRAME
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_DEATH_BURST_BUDGET_PER_FRAME
	return DEATH_BURST_BUDGET_PER_FRAME

static func _consume_hit_flash_budget() -> bool:
	var current_frame := Engine.get_physics_frames()
	if hit_flash_budget_frame != current_frame:
		hit_flash_budget_frame = current_frame
		hit_flash_budget_used = 0
	if hit_flash_budget_used >= _get_hit_flash_budget_per_frame():
		PERFORMANCE_COUNTERS.add("suppressed_hit_flash", 1)
		return false
	hit_flash_budget_used += 1
	return true

static func _get_hit_flash_budget_per_frame() -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_HIT_FLASH_BUDGET_PER_FRAME
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_HIT_FLASH_BUDGET_PER_FRAME
	return HIT_FLASH_BUDGET_PER_FRAME

static func spawn_death_burst(enemy) -> void:
	var current_scene: Node = _get_enemy_current_scene(enemy)
	if current_scene == null:
		return
	if not _can_spawn_temporary_effect(current_scene):
		return

	var burst := _acquire_death_burst(current_scene)
	burst.global_position = enemy.global_position
	burst.z_index = 14
	burst.color = Color(1.0, 0.88, 0.65, 0.75)
	burst.modulate = Color.WHITE
	burst.polygon = PackedVector2Array([
		Vector2(0.0, -18.0),
		Vector2(18.0, 0.0),
		Vector2(0.0, 18.0),
		Vector2(-18.0, 0.0)
	])

	burst.scale = Vector2(0.25, 0.25)
	active_death_bursts.append({
		"node": burst,
		"elapsed": 0.0,
		"duration": 0.16,
		"start_scale": Vector2(0.25, 0.25),
		"target_scale": Vector2(1.2, 1.2)
	})

static func _update_static_feedback_animations(delta: float) -> void:
	if delta <= 0.0:
		return
	var current_frame := Engine.get_process_frames()
	if feedback_animation_frame == current_frame:
		return
	feedback_animation_frame = current_frame
	_update_active_damage_labels(delta)
	_update_active_death_bursts(delta)

static func _update_active_damage_labels(delta: float) -> void:
	for index in range(active_damage_labels.size() - 1, -1, -1):
		var data: Dictionary = active_damage_labels[index]
		var label_ref: Variant = data.get("node", null)
		if not is_instance_valid(label_ref) or not (label_ref is Label):
			active_damage_labels.remove_at(index)
			continue
		var label := label_ref as Label
		if label.is_queued_for_deletion():
			active_damage_labels.remove_at(index)
			continue
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var duration: float = max(0.001, float(data.get("duration", 0.38)))
		var progress: float = clamp(elapsed / duration, 0.0, 1.0)
		var pop_duration: float = max(0.001, float(data.get("pop_duration", 0.13)))
		var hold_duration: float = max(0.0, float(data.get("hold_duration", 0.20)))
		var fade_duration: float = max(0.12, duration - pop_duration - hold_duration)
		var pop_position: Vector2 = data.get("pop_position", label.global_position)
		var target_position: Vector2 = data.get("target_position", label.global_position)
		var start_scale: Vector2 = data.get("start_scale", Vector2.ONE)
		var peak_scale: Vector2 = data.get("peak_scale", Vector2.ONE)
		var settle_scale: Vector2 = data.get("settle_scale", Vector2.ONE)
		if elapsed < pop_duration:
			var pop_progress: float = _ease_out_back(clamp(elapsed / pop_duration, 0.0, 1.0))
			label.global_position = (data.get("start_position", label.global_position) as Vector2).lerp(pop_position, pop_progress)
			label.scale = start_scale.lerp(peak_scale, pop_progress)
		elif elapsed < pop_duration + hold_duration:
			label.global_position = pop_position
			label.scale = peak_scale.lerp(settle_scale, clamp((elapsed - pop_duration) / 0.08, 0.0, 1.0))
		else:
			var fade_progress: float = clamp((elapsed - pop_duration - hold_duration) / fade_duration, 0.0, 1.0)
			var eased_fade: float = fade_progress * fade_progress
			label.global_position = pop_position.lerp(target_position, _ease_out_cubic(fade_progress))
			label.scale = settle_scale.lerp(Vector2(0.94, 0.94), fade_progress)
			label.modulate.a = float(data.get("start_alpha", 1.0)) * (1.0 - eased_fade)
		if elapsed >= duration:
			active_damage_labels.remove_at(index)
			_release_damage_label(label)
			continue
		data["elapsed"] = elapsed
		active_damage_labels[index] = data

static func _ease_out_cubic(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)

static func _ease_out_back(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0)
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)

static func _update_active_death_bursts(delta: float) -> void:
	for index in range(active_death_bursts.size() - 1, -1, -1):
		var data: Dictionary = active_death_bursts[index]
		var burst_ref: Variant = data.get("node", null)
		if not is_instance_valid(burst_ref) or not (burst_ref is Polygon2D):
			active_death_bursts.remove_at(index)
			continue
		var burst := burst_ref as Polygon2D
		if burst.is_queued_for_deletion():
			active_death_bursts.remove_at(index)
			continue
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var duration: float = max(0.001, float(data.get("duration", 0.16)))
		var progress: float = clamp(elapsed / duration, 0.0, 1.0)
		burst.scale = (data.get("start_scale", Vector2.ONE) as Vector2).lerp(data.get("target_scale", Vector2.ONE) as Vector2, progress)
		burst.modulate.a = 1.0 - progress
		if elapsed >= duration:
			active_death_bursts.remove_at(index)
			_release_death_burst(burst)
			continue
		data["elapsed"] = elapsed
		active_death_bursts[index] = data

static func _acquire_damage_label(current_scene: Node) -> Label:
	while not damage_label_pool.is_empty():
		var pooled_label: Variant = damage_label_pool.pop_back()
		if is_instance_valid(pooled_label) and pooled_label is Label:
			var label := pooled_label as Label
			if label.is_queued_for_deletion():
				continue
			_prepare_pooled_node(label, current_scene)
			return label
	var label := Label.new()
	current_scene.add_child(label)
	label.add_to_group("temporary_effects")
	return label

static func _release_damage_label(label: Label) -> void:
	if label == null or not is_instance_valid(label):
		return
	label.hide()
	label.remove_from_group("temporary_effects")
	if damage_label_pool.size() < DAMAGE_LABEL_POOL_LIMIT and not damage_label_pool.has(label):
		damage_label_pool.append(label)
	else:
		label.queue_free()

static func _acquire_death_burst(current_scene: Node) -> Polygon2D:
	while not death_burst_pool.is_empty():
		var pooled_burst: Variant = death_burst_pool.pop_back()
		if is_instance_valid(pooled_burst) and pooled_burst is Polygon2D:
			var burst := pooled_burst as Polygon2D
			if burst.is_queued_for_deletion():
				continue
			_prepare_pooled_node(burst, current_scene)
			return burst
	var burst := Polygon2D.new()
	current_scene.add_child(burst)
	burst.add_to_group("temporary_effects")
	return burst

static func _release_death_burst(burst: Polygon2D) -> void:
	if burst == null or not is_instance_valid(burst):
		return
	burst.hide()
	burst.remove_from_group("temporary_effects")
	if death_burst_pool.size() < DEATH_BURST_POOL_LIMIT and not death_burst_pool.has(burst):
		death_burst_pool.append(burst)
	else:
		burst.queue_free()

static func _prepare_pooled_node(node: Node, current_scene: Node) -> void:
	var parent := node.get_parent()
	if parent != current_scene:
		if parent != null:
			parent.remove_child(node)
		current_scene.add_child(node)
	node.show()
	node.add_to_group("temporary_effects")

static func _get_enemy_current_scene(enemy) -> Node:
	if enemy == null or not is_instance_valid(enemy):
		return null
	if enemy is Node and not (enemy as Node).is_inside_tree():
		return null
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		return null
	return tree.current_scene

static func _can_spawn_temporary_effect(root: Node) -> bool:
	if root != null and root.has_method("_can_spawn_runtime_group"):
		var limit: int = PERFORMANCE_GUARD.get_dynamic_limit(root, "temporary_effects", PERFORMANCE_GUARD.DEFAULT_TEMPORARY_EFFECT_LIMIT)
		return bool(root._can_spawn_runtime_group("temporary_effects", limit))
	return true

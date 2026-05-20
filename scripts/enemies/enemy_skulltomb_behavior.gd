extends RefCounted

const SUMMON_COLOR := Color(0.35, 1.0, 0.95, 0.82)
const SUMMON_RING_START_RADIUS := 230.0
const DEATH_RING_DURATION := 0.72
const DEATH_RING_TARGET_RADIUS := 2400.0
const TOMB_TEXTURE := preload("res://assets/enemies/skulltomb/tomb.png")
const SKULL_SOLDIER_ARCHETYPES := ["dasher", "elite_ram_trail"]
const SKULL_SHOT_ARCHETYPES := ["shooter", "shotgunner", "elite_splitshot"]


static func update(enemy, delta: float) -> void:
	if enemy.rebirth_timer > 0.0:
		_update_rebirth(enemy, delta)
		return
	_update_summon_channel(enemy, delta)


static func handle_lethal_damage(enemy) -> bool:
	if enemy.rebirth_lives_remaining <= 0:
		return false
	enemy.rebirth_lives_remaining -= 1
	enemy.current_health = enemy.max_health
	enemy.rebirth_timer = enemy.rebirth_delay
	enemy.velocity = Vector2.ZERO
	enemy.throttled_motion_delta = 0.0
	enemy.motion_refresh_frame = -1
	enemy.separation_refresh_frame = -1
	_hide_profile_visual(enemy)
	_spawn_tomb(enemy)
	_spawn_death_ring(enemy)
	_apply_death_buffs(enemy)
	return true


static func _update_summon_channel(enemy, delta: float) -> void:
	if enemy.skulltomb_summon_windup_remaining > 0.0:
		enemy.skulltomb_summon_windup_remaining = max(0.0, enemy.skulltomb_summon_windup_remaining - delta)
		_update_channel_ring(enemy)
		if enemy.skulltomb_summon_windup_remaining <= 0.0:
			_clear_channel_ring(enemy)
			_finish_summon(enemy)
		return
	enemy.skulltomb_summon_timer -= delta
	if enemy.skulltomb_summon_timer > 0.0:
		return
	enemy.skulltomb_summon_timer += max(0.5, enemy.skulltomb_summon_interval)
	enemy.skulltomb_summon_windup_remaining = max(0.15, enemy.skulltomb_summon_windup)
	_update_channel_ring(enemy)


static func _finish_summon(enemy) -> void:
	var scene := _get_current_scene(enemy)
	if scene == null:
		return
	var soldier_count := _count_skull_soldiers(scene)
	var missing_count: int = max(0, enemy.skulltomb_min_soldiers - soldier_count)
	for index in range(missing_count):
		_spawn_skull_soldier(enemy, scene, index)
	_apply_summon_buffs(scene, enemy.skulltomb_buff_duration)
	enemy._spawn_status_burst(SUMMON_COLOR, 38.0 + enemy.scale.x * 8.0)


static func _update_rebirth(enemy, delta: float) -> void:
	enemy.rebirth_timer = max(0.0, enemy.rebirth_timer - delta)
	_update_death_ring(enemy)
	if enemy.rebirth_timer > 0.0:
		return
	_clear_tomb(enemy)
	_clear_death_ring(enemy)
	_show_profile_visual(enemy)
	enemy.current_health = enemy.max_health
	enemy._spawn_status_burst(SUMMON_COLOR, 42.0 + enemy.scale.x * 8.0)


static func _apply_summon_buffs(scene: Node, duration: float) -> void:
	for other in _get_runtime_enemies(scene):
		if not _is_skull_soldier(other):
			continue
		other.skull_soldier_speed_multiplier = max(float(other.skull_soldier_speed_multiplier), 2.0)
		other.skull_soldier_speed_timer = max(float(other.skull_soldier_speed_timer), duration)
		other.skull_damage_immune_timer = max(float(other.skull_damage_immune_timer), duration)
		if other.has_method("_spawn_status_burst"):
			other._spawn_status_burst(SUMMON_COLOR, 22.0 + other.scale.x * 4.0)


static func _apply_death_buffs(enemy) -> void:
	var scene := _get_current_scene(enemy)
	if scene == null:
		return
	if enemy.target != null and is_instance_valid(enemy.target) and enemy.target.has_method("apply_enemy_slow"):
		enemy.target.apply_enemy_slow(enemy.skulltomb_death_player_slow_multiplier, enemy.skulltomb_death_player_slow_duration)
	for other in _get_runtime_enemies(scene):
		if _is_skull_soldier(other):
			other.skull_soldier_speed_multiplier = max(float(other.skull_soldier_speed_multiplier), enemy.skulltomb_death_soldier_speed_multiplier)
			other.skull_soldier_speed_timer = max(float(other.skull_soldier_speed_timer), enemy.skulltomb_death_player_slow_duration)
		if _is_skull_shot(other):
			other.skullshot_attack_frequency_multiplier = max(float(other.skullshot_attack_frequency_multiplier), enemy.skulltomb_death_shot_frequency_multiplier)
			other.skullshot_attack_frequency_timer = max(float(other.skullshot_attack_frequency_timer), enemy.skulltomb_death_player_slow_duration)


static func _spawn_skull_soldier(enemy, scene: Node, index: int) -> void:
	if scene == null or not scene.has_method("queue_runtime_enemy_spawn"):
		return
	var spawn_position := _get_summon_position(enemy, index)
	var health_multiplier := _get_scene_health_multiplier(scene)
	var speed_multiplier := _get_scene_speed_multiplier(scene)
	var damage_multiplier := _get_scene_damage_multiplier(scene)
	scene.queue_runtime_enemy_spawn({
		"kind": "normal",
		"archetype": "dasher",
		"health_multiplier": health_multiplier,
		"speed_multiplier": speed_multiplier,
		"damage_multiplier": damage_multiplier,
		"spawn_position": spawn_position,
		"skull_soldier_speed_multiplier": 2.0,
		"skull_soldier_speed_timer": enemy.skulltomb_buff_duration,
		"skull_damage_immune_timer": enemy.skulltomb_buff_duration
	})


static func _get_summon_position(enemy, index: int) -> Vector2:
	var angle := randf() * TAU + float(index) * 0.42
	var distance := 110.0 + float(index % 5) * 28.0
	return enemy.global_position + Vector2.RIGHT.rotated(angle) * distance


static func _get_scene_health_multiplier(scene: Node) -> float:
	if scene.has_method("_get_spawn_enemy_health_multiplier"):
		return float(scene._get_spawn_enemy_health_multiplier("normal"))
	return 1.0


static func _get_scene_speed_multiplier(scene: Node) -> float:
	if scene.has_method("_get_spawn_enemy_speed_multiplier"):
		return float(scene._get_spawn_enemy_speed_multiplier())
	return 1.0


static func _get_scene_damage_multiplier(scene: Node) -> float:
	if scene.has_method("_get_spawn_enemy_damage_multiplier"):
		return float(scene._get_spawn_enemy_damage_multiplier())
	return 1.0


static func _count_skull_soldiers(scene: Node) -> int:
	var count := 0
	for enemy in _get_runtime_enemies(scene):
		if _is_skull_soldier(enemy):
			count += 1
	return count


static func _is_skull_soldier(enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and str(enemy.get("archetype_id")) in SKULL_SOLDIER_ARCHETYPES


static func _is_skull_shot(enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and str(enemy.get("archetype_id")) in SKULL_SHOT_ARCHETYPES


static func _get_runtime_enemies(scene: Node) -> Array:
	if scene != null and scene.has_method("get_runtime_enemies"):
		return scene.get_runtime_enemies()
	if scene != null and scene.get_tree() != null:
		return scene.get_tree().get_nodes_in_group("enemies")
	return []


static func _spawn_tomb(enemy) -> void:
	_clear_tomb(enemy)
	if enemy.skulltomb_tomb_scene == null:
		return
	var scene := _get_current_scene(enemy)
	if scene == null:
		return
	var tomb := enemy.skulltomb_tomb_scene.instantiate() as Node2D
	if tomb == null:
		return
	tomb.name = "SkulltombTomb"
	tomb.global_position = enemy.global_position
	tomb.z_index = enemy.z_index
	scene.add_child(tomb)
	_ensure_tomb_visual(tomb)
	enemy.skulltomb_tomb_instance = tomb


static func _ensure_tomb_visual(tomb: Node2D) -> void:
	var animated_sprite := tomb.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null:
		if animated_sprite.animation == StringName():
			animated_sprite.animation = &"default"
		animated_sprite.play()
		return
	if tomb.get_child_count() > 0:
		return
	var sprite := Sprite2D.new()
	sprite.name = "TombSprite"
	sprite.texture = TOMB_TEXTURE
	sprite.centered = true
	sprite.scale = Vector2.ONE * 0.72
	tomb.add_child(sprite)


static func _spawn_death_ring(enemy) -> void:
	_clear_death_ring(enemy)
	var scene := _get_current_scene(enemy)
	if scene == null:
		return
	var ring := Line2D.new()
	ring.name = "SkulltombDeathRing"
	ring.closed = true
	ring.width = 5.0
	ring.default_color = Color(0.24, 1.0, 0.92, 0.74)
	ring.global_position = enemy.global_position
	ring.z_index = enemy.z_index + 1
	scene.add_child(ring)
	enemy.skulltomb_death_ring = ring
	_update_circle_points(ring, 20.0)


static func _update_death_ring(enemy) -> void:
	var ring := enemy.skulltomb_death_ring as Line2D
	if ring == null or not is_instance_valid(ring):
		return
	var elapsed: float = float(enemy.rebirth_delay) - float(enemy.rebirth_timer)
	var progress: float = clamp(elapsed / max(0.001, DEATH_RING_DURATION), 0.0, 1.0)
	_update_circle_points(ring, lerpf(20.0, DEATH_RING_TARGET_RADIUS, progress))
	ring.modulate.a = 1.0 - progress


static func _update_channel_ring(enemy) -> void:
	var ring := enemy.skulltomb_channel_ring as Line2D
	if ring == null or not is_instance_valid(ring):
		ring = Line2D.new()
		ring.name = "SkulltombChannelRing"
		ring.closed = true
		ring.width = 4.0
		ring.default_color = SUMMON_COLOR
		ring.z_index = enemy.z_index + 1
		enemy.add_child(ring)
		enemy.skulltomb_channel_ring = ring
	var progress: float = 1.0 - clamp(float(enemy.skulltomb_summon_windup_remaining) / max(0.001, float(enemy.skulltomb_summon_windup)), 0.0, 1.0)
	_update_circle_points(ring, lerpf(SUMMON_RING_START_RADIUS, max(28.0, enemy.contact_radius), progress))
	ring.modulate.a = 0.35 + 0.45 * progress


static func _update_circle_points(ring: Line2D, radius: float) -> void:
	var points := PackedVector2Array()
	var segment_count := 64
	for index in range(segment_count):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / float(segment_count)) * radius)
	ring.points = points


static func _hide_profile_visual(enemy) -> void:
	var visual := enemy.get_node_or_null("ProfileVisual") as CanvasItem
	if visual != null:
		visual.hide()
	enemy.modulate.a = 0.0


static func _show_profile_visual(enemy) -> void:
	enemy.modulate.a = 1.0
	var visual := enemy.get_node_or_null("ProfileVisual") as CanvasItem
	if visual != null:
		visual.show()


static func _clear_tomb(enemy) -> void:
	if enemy.skulltomb_tomb_instance != null and is_instance_valid(enemy.skulltomb_tomb_instance):
		enemy.skulltomb_tomb_instance.queue_free()
	enemy.skulltomb_tomb_instance = null


static func _clear_channel_ring(enemy) -> void:
	if enemy.skulltomb_channel_ring != null and is_instance_valid(enemy.skulltomb_channel_ring):
		enemy.skulltomb_channel_ring.queue_free()
	enemy.skulltomb_channel_ring = null


static func _clear_death_ring(enemy) -> void:
	if enemy.skulltomb_death_ring != null and is_instance_valid(enemy.skulltomb_death_ring):
		enemy.skulltomb_death_ring.queue_free()
	enemy.skulltomb_death_ring = null


static func _get_current_scene(enemy) -> Node:
	if enemy == null or not is_instance_valid(enemy):
		return null
	if enemy is Node and not (enemy as Node).is_inside_tree():
		return null
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		return null
	return tree.current_scene

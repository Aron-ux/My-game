extends RefCounted

const SUMMON_COLOR := Color(0.35, 1.0, 0.95, 0.82)
const SUMMON_RING_START_RADIUS := 230.0
const SUMMON_AREA_RADIUS := 583.2
const SUMMON_AREA_DURATION := 15.0
const SUMMON_AREA_DAMAGE_INTERVAL := 1.0
const SUMMON_AREA_CURRENT_HEALTH_DAMAGE_RATIO := 0.01
const SUMMON_AREA_VERTEX_VISUAL_SCALE := 1.0
const SUMMON_AREA_LINE_COLOR := Color(0.08, 0.42, 0.38, 0.92)
const SUMMON_AREA_COLLISION_LAYER := 1 << 6
const DEATH_RING_DURATION := 0.72
const DEATH_RING_TARGET_RADIUS := 2400.0
const TOMB_TEXTURE := preload("res://assets/enemies/skulltomb/tomb.png")
const AREA_SCENE_PATHS := [
	"res://assets/enemies/skulltomb/area.tscn",
	"res://assets/enemies/area.tscn",
	"res://assets/area.tscn"
]
const SKULL_SOLDIER_ARCHETYPES := ["dasher", "elite_ram_trail"]
const SKULL_SHOT_ARCHETYPES := ["shooter", "shotgunner", "elite_splitshot"]


static func update(enemy, delta: float) -> void:
	if enemy.rebirth_timer > 0.0:
		_update_rebirth(enemy, delta)
		return
	_update_summon_area(enemy, delta)
	_update_summon_channel(enemy, delta)


static func handle_lethal_damage(enemy) -> bool:
	if enemy.rebirth_lives_remaining <= 0:
		return false
	_clear_summon_area(enemy)
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
	_start_summon_area(enemy)
	var soldier_count := _count_skull_soldiers(scene)
	var missing_count: int = max(0, enemy.skulltomb_min_soldiers - soldier_count)
	for index in range(missing_count):
		_spawn_skull_soldier(enemy, scene, index)
	for index in range(10):
		_spawn_skull_shooter(enemy, scene, index)
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


static func _spawn_skull_shooter(enemy, scene: Node, index: int) -> void:
	if scene == null or not scene.has_method("queue_runtime_enemy_spawn"):
		return
	var spawn_position := _get_summon_position(enemy, index + 10)
	var health_multiplier := _get_scene_health_multiplier(scene)
	var speed_multiplier := _get_scene_speed_multiplier(scene)
	var damage_multiplier := _get_scene_damage_multiplier(scene)
	scene.queue_runtime_enemy_spawn({
		"kind": "normal",
		"archetype": "shooter",
		"health_multiplier": health_multiplier,
		"speed_multiplier": speed_multiplier,
		"damage_multiplier": damage_multiplier,
		"spawn_position": spawn_position
	})


static func _get_summon_position(enemy, index: int) -> Vector2:
	var angle := randf() * TAU + float(index) * 0.42
	var max_spawn_radius: float = max(48.0, float(enemy.skulltomb_area_radius) - 72.0)
	var distance: float = min(max_spawn_radius, 110.0 + float(index % 8) * 54.0)
	return enemy.skulltomb_area_center + Vector2.RIGHT.rotated(angle) * distance


static func _start_summon_area(enemy) -> void:
	_clear_summon_area(enemy)
	enemy.skulltomb_area_center = enemy.global_position
	if enemy.target != null and is_instance_valid(enemy.target) and enemy.target is Node2D:
		enemy.skulltomb_area_center = (enemy.target as Node2D).global_position
	enemy.skulltomb_area_radius = SUMMON_AREA_RADIUS
	enemy.skulltomb_area_remaining = SUMMON_AREA_DURATION
	enemy.skulltomb_area_damage_elapsed = 0.0
	_spawn_summon_area_visual(enemy)


static func _update_summon_area(enemy, delta: float) -> void:
	if enemy.skulltomb_area_remaining <= 0.0:
		return
	enemy.skulltomb_area_remaining = max(0.0, float(enemy.skulltomb_area_remaining) - delta)
	if enemy.skulltomb_area_remaining <= 0.0:
		_clear_summon_area(enemy)
		return
	if enemy.target == null or not is_instance_valid(enemy.target) or enemy.target is not Node2D:
		return
	var target_node: Node2D = enemy.target
	if enemy.target.has_method("apply_healing_block"):
		enemy.target.apply_healing_block(delta + 0.12)
	if enemy.target.has_method("apply_confinement"):
		enemy.target.apply_confinement(enemy.skulltomb_area_center, enemy.skulltomb_area_radius, delta + 0.12)
	if target_node.global_position.distance_squared_to(enemy.skulltomb_area_center) > enemy.skulltomb_area_radius * enemy.skulltomb_area_radius:
		return
	enemy.skulltomb_area_damage_elapsed += delta
	while enemy.skulltomb_area_damage_elapsed >= SUMMON_AREA_DAMAGE_INTERVAL:
		enemy.skulltomb_area_damage_elapsed -= SUMMON_AREA_DAMAGE_INTERVAL
		if enemy.target.has_method("take_damage"):
			var current_health: float = float(enemy.target.get("current_health")) if enemy.target.get("current_health") != null else 100.0
			enemy.target.take_damage(max(1.0, current_health * SUMMON_AREA_CURRENT_HEALTH_DAMAGE_RATIO))


static func _spawn_summon_area_visual(enemy) -> void:
	var scene := _get_current_scene(enemy)
	if scene == null:
		return
	var root := Node2D.new()
	root.name = "SkulltombSummonArea"
	root.global_position = enemy.skulltomb_area_center
	root.z_index = enemy.z_index - 1
	scene.add_child(root)
	enemy.skulltomb_area_instance = root
	var vertices: PackedVector2Array = _build_triangle_vertices(enemy.skulltomb_area_radius)
	var line := Line2D.new()
	line.name = "SkulltombAreaTriangleLine"
	line.closed = true
	line.width = 8.0
	line.default_color = SUMMON_AREA_LINE_COLOR
	line.points = vertices
	line.z_index = 1
	root.add_child(line)
	_add_triangle_collision(root, vertices)
	for index in range(vertices.size()):
		var marker := _instantiate_area_scene()
		if marker == null:
			marker = _create_area_fallback_marker()
		marker.name = "SkulltombAreaVertex%d" % index
		marker.position = vertices[index]
		marker.scale *= Vector2.ONE * SUMMON_AREA_VERTEX_VISUAL_SCALE
		marker.z_index = 2
		root.add_child(marker)
		_play_area_marker_animation(marker)


static func _add_triangle_collision(root: Node2D, vertices: PackedVector2Array) -> void:
	var body := StaticBody2D.new()
	body.name = "SkulltombAreaCollision"
	body.collision_layer = SUMMON_AREA_COLLISION_LAYER
	body.collision_mask = 0
	var collision := CollisionPolygon2D.new()
	collision.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	collision.polygon = vertices
	body.add_child(collision)
	root.add_child(body)


static func _play_area_marker_animation(marker: Node2D) -> void:
	var sprite := marker.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.animation == StringName():
		sprite.animation = &"default"
	if not sprite.is_playing():
		sprite.play()


static func _instantiate_area_scene() -> Node2D:
	for path in AREA_SCENE_PATHS:
		if not ResourceLoader.exists(path, "PackedScene"):
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var node := packed.instantiate() as Node2D
		if node != null:
			return node
	return null


static func _clear_summon_area(enemy) -> void:
	if enemy.skulltomb_area_instance != null and is_instance_valid(enemy.skulltomb_area_instance):
		enemy.skulltomb_area_instance.queue_free()
	enemy.skulltomb_area_instance = null
	enemy.skulltomb_area_remaining = 0.0
	enemy.skulltomb_area_damage_elapsed = 0.0
	enemy.skulltomb_area_radius = 0.0


static func _build_triangle_vertices(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var start_angle := -PI * 0.5
	for index in range(3):
		points.append(Vector2.RIGHT.rotated(start_angle + TAU * float(index) / 3.0) * radius)
	return points


static func _create_area_fallback_marker() -> Node2D:
	var marker := Node2D.new()
	var polygon := Polygon2D.new()
	polygon.color = Color(0.14, 0.85, 0.82, 0.32)
	polygon.polygon = _build_circle_points(42.0, 32)
	marker.add_child(polygon)
	return marker


static func _build_circle_points(radius: float, segment_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(max(8, segment_count)):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / float(max(8, segment_count))) * radius)
	return points


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

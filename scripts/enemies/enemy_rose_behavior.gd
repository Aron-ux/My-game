extends RefCounted

const ENEMY_GEOMETRY := preload("res://scripts/enemies/enemy_geometry.gd")
const ROSE_MINION := preload("res://scripts/enemies/rose_minion.gd")

const ROSE_BULLET_STYLE := "rose_flower"
const ATTACK_INTERVAL := 1.0
const ATTACK_BULLET_COUNT := 3
const ATTACK_SPREAD := 0.14
const SPLIT_INTERVAL := 15.0
const SPLIT_WARNING_SECONDS := 0.7
const SPLIT_MOTHER_SPEED := 520.0
const SPLIT_CHILD_COUNT := 8
const SPLIT_MINION_COUNT := 3
const SPLIT_CHILD_LIFETIME := 1.2
const BOMBARD_WARNING_SECONDS := 1.9
const BOMBARD_SPEED_MULTIPLIER := 1.3
const BOMBARD_LIFETIME_MULTIPLIER := 1.5

const ACTIVE_SPLITS_META_KEY := "__rose_active_splits"
const ACTIVE_BOMBARDS_META_KEY := "__rose_active_bombards"
const ROSE_FRAME_META_KEY := "__rose_behavior_frame"


static func update(enemy, delta: float) -> void:
	var scene := _get_enemy_current_scene(enemy)
	if scene == null:
		return
	_update_active_sequences(scene, delta)
	if enemy.target == null or not is_instance_valid(enemy.target):
		return
	_update_facing(enemy)
	_update_normal_attack(enemy, delta)
	_update_split(enemy, delta)
	_update_bombard(enemy, delta)


static func _update_normal_attack(enemy, delta: float) -> void:
	enemy.shot_timer -= delta
	if enemy.shot_timer > 0.0:
		return
	enemy.shot_timer += ATTACK_INTERVAL
	_play_attack_visual(enemy)
	_fire_three_bullets(enemy, enemy.global_position, _get_aim_direction(enemy), enemy.projectile_speed, enemy.projectile_damage, enemy.projectile_lifetime, 1.0)


static func _update_split(enemy, delta: float) -> void:
	enemy.rose_split_timer -= delta
	if enemy.rose_split_timer > 0.0:
		return
	enemy.rose_split_timer += SPLIT_INTERVAL
	_play_attack_visual(enemy)
	_start_split_sequence(enemy)


static func _update_bombard(enemy, delta: float) -> void:
	if enemy.turret_bombard_interval <= 0.0:
		return
	enemy.turret_bombard_timer -= delta
	if enemy.turret_bombard_timer > 0.0:
		return
	enemy.turret_bombard_timer += max(0.5, enemy.turret_bombard_interval)
	_play_attack_visual(enemy)
	_start_bombard_sequence(enemy)


static func _start_split_sequence(enemy) -> void:
	var scene := _get_enemy_current_scene(enemy)
	if scene == null:
		return
	var impact_center := _get_target_center(enemy) + Vector2(randf_range(-72.0, 72.0), randf_range(-56.0, 56.0))
	var warning := _create_warning(scene, impact_center, 46.0, Color(0.95, 0.1, 0.28, 0.88), Color(0.95, 0.1, 0.28, 0.14))
	var mother := _create_rose_orb(scene, enemy.global_position, 1.15)
	_track_sequence(scene, ACTIVE_SPLITS_META_KEY, {
		"enemy_ref": weakref(enemy),
		"phase": "warning",
		"elapsed": 0.0,
		"duration": SPLIT_WARNING_SECONDS,
		"warning": warning.get("line", null),
		"fill": warning.get("fill", null),
		"mother": mother,
		"start": enemy.global_position,
		"impact_center": impact_center
	})


static func _start_bombard_sequence(enemy) -> void:
	var scene := _get_enemy_current_scene(enemy)
	if scene == null:
		return
	var impact_center := _get_target_center(enemy) + Vector2(randf_range(-42.0, 42.0), randf_range(-42.0, 42.0))
	var warning := _create_warning(scene, impact_center, enemy.turret_bombard_radius, Color(0.95, 0.12, 0.34, 0.84), Color(0.95, 0.12, 0.34, 0.13))
	var expander := _create_bombard_expander(scene, impact_center, enemy.turret_bombard_radius)
	_track_sequence(scene, ACTIVE_BOMBARDS_META_KEY, {
		"enemy_ref": weakref(enemy),
		"elapsed": 0.0,
		"duration": BOMBARD_WARNING_SECONDS,
		"warning": warning.get("line", null),
		"fill": warning.get("fill", null),
		"expander": expander,
		"impact_center": impact_center
	})


static func _update_active_sequences(scene: Node, delta: float) -> void:
	var current_frame := Engine.get_process_frames()
	if int(scene.get_meta(ROSE_FRAME_META_KEY, -1)) == current_frame:
		return
	scene.set_meta(ROSE_FRAME_META_KEY, current_frame)
	_update_split_sequences(scene, delta)
	_update_bombard_sequences(scene, delta)


static func _update_split_sequences(scene: Node, delta: float) -> void:
	var active: Array = scene.get_meta(ACTIVE_SPLITS_META_KEY, [])
	if active.is_empty():
		return
	for index in range(active.size() - 1, -1, -1):
		var data: Dictionary = active[index]
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var phase := str(data.get("phase", "warning"))
		var duration: float = max(0.001, float(data.get("duration", SPLIT_WARNING_SECONDS)))
		if phase == "warning":
			_update_warning_scale(data, elapsed / duration)
			if elapsed >= duration:
				data["phase"] = "travel"
				data["elapsed"] = 0.0
				data["duration"] = _get_split_travel_duration(data)
			else:
				data["elapsed"] = elapsed
		else:
			_update_split_mother_position(data, elapsed / duration)
			if elapsed >= duration:
				active.remove_at(index)
				_finish_split_sequence(scene, data)
				continue
			data["elapsed"] = elapsed
		active[index] = data
	scene.set_meta(ACTIVE_SPLITS_META_KEY, active)


static func _update_bombard_sequences(scene: Node, delta: float) -> void:
	var active: Array = scene.get_meta(ACTIVE_BOMBARDS_META_KEY, [])
	if active.is_empty():
		return
	for index in range(active.size() - 1, -1, -1):
		var data: Dictionary = active[index]
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var duration: float = max(0.001, float(data.get("duration", BOMBARD_WARNING_SECONDS)))
		_update_warning_scale(data, elapsed / duration)
		_update_bombard_expander(data, elapsed / duration)
		if elapsed >= duration:
			active.remove_at(index)
			_finish_bombard_sequence(data)
			continue
		data["elapsed"] = elapsed
		active[index] = data
	scene.set_meta(ACTIVE_BOMBARDS_META_KEY, active)


static func _finish_split_sequence(scene: Node, data: Dictionary) -> void:
	_release_sequence_visuals(data)
	var enemy = _get_enemy_from_sequence(data)
	if enemy == null:
		return
	var impact_center: Vector2 = data.get("impact_center", Vector2.ZERO)
	var minion_indices := _pick_unique_indices(SPLIT_CHILD_COUNT, SPLIT_MINION_COUNT)
	for index in range(SPLIT_CHILD_COUNT):
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / float(SPLIT_CHILD_COUNT))
		_spawn_projectile(
			enemy,
			impact_center + direction * 10.0,
			direction,
			enemy.projectile_speed * 0.86,
			enemy.projectile_damage * 0.72,
			SPLIT_CHILD_LIFETIME,
			0.58
		)
		if minion_indices.has(index):
			_schedule_minion_spawn(scene, enemy, impact_center + direction * enemy.projectile_speed * 0.86 * SPLIT_CHILD_LIFETIME, 0.18 + SPLIT_CHILD_LIFETIME)


static func _finish_bombard_sequence(data: Dictionary) -> void:
	_release_sequence_visuals(data)
	var enemy = _get_enemy_from_sequence(data)
	if enemy == null:
		return
	var impact_center: Vector2 = data.get("impact_center", Vector2.ZERO)
	if enemy.target != null and is_instance_valid(enemy.target):
		var target_center := _get_target_center(enemy)
		var target_radius := _get_target_radius(enemy)
		if impact_center.distance_to(target_center) <= enemy.turret_bombard_radius + target_radius and enemy.target.has_method("take_damage"):
			enemy.target.take_damage(enemy.projectile_damage * 1.25)
	for index in range(max(6, enemy.turret_bombard_projectiles)):
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / float(max(1, enemy.turret_bombard_projectiles)))
		_spawn_projectile(
			enemy,
			impact_center + direction * 12.0,
			direction,
			max(280.0, enemy.projectile_speed * 1.05) * BOMBARD_SPEED_MULTIPLIER,
			enemy.projectile_damage,
			3.8 * BOMBARD_LIFETIME_MULTIPLIER,
			1.0
		)


static func _fire_three_bullets(enemy, origin: Vector2, aim_direction: Vector2, speed: float, damage: float, lifetime: float, size_scale: float) -> void:
	var offset_center := float(ATTACK_BULLET_COUNT - 1) * 0.5
	for index in range(ATTACK_BULLET_COUNT):
		var direction := aim_direction.rotated((float(index) - offset_center) * ATTACK_SPREAD)
		_spawn_projectile(enemy, origin + direction * (24.0 + enemy.scale.x * 4.0), direction, speed, damage, lifetime, size_scale)


static func _spawn_projectile(enemy, origin: Vector2, direction: Vector2, speed: float, damage: float, lifetime: float, size_scale: float) -> void:
	enemy._spawn_projectile(
		origin,
		direction,
		speed,
		damage,
		lifetime,
		Color(0.9, 0.12, 0.2, 1.0),
		"straight",
		{
			"visual_style": ROSE_BULLET_STYLE,
			"hit_radius": 14.0 * size_scale,
			"size_scale": size_scale
		}
	)


static func _schedule_minion_spawn(scene: Node, enemy, position: Vector2, delay: float) -> void:
	if scene == null or enemy == null or not is_instance_valid(enemy):
		return
	var tree := scene.get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(max(0.01, delay))
	timer.timeout.connect(func() -> void:
		if scene == null or not is_instance_valid(scene) or enemy == null or not is_instance_valid(enemy):
			return
		var minion := ROSE_MINION.new()
		minion.global_position = position
		scene.add_child(minion)
		minion.configure(enemy, enemy.target, enemy.projectile_scene, enemy.scale, enemy.projectile_damage, enemy.projectile_speed, enemy.projectile_lifetime)
	)


static func _create_warning(scene: Node, center: Vector2, radius: float, line_color: Color, fill_color: Color) -> Dictionary:
	var points := ENEMY_GEOMETRY.build_circle_points(radius)
	var line := Line2D.new()
	line.global_position = center
	line.width = 4.0
	line.default_color = line_color
	line.closed = true
	line.points = points
	line.z_index = 15
	scene.add_child(line)

	var fill := Polygon2D.new()
	fill.global_position = center
	fill.color = fill_color
	fill.polygon = points
	fill.z_index = 14
	scene.add_child(fill)
	return {"line": line, "fill": fill}


static func _create_bombard_expander(scene: Node, center: Vector2, radius: float) -> Polygon2D:
	var expander := Polygon2D.new()
	expander.global_position = center
	expander.color = Color(1.0, 0.04, 0.02, 0.24)
	expander.polygon = ENEMY_GEOMETRY.build_circle_points(radius, 48)
	expander.scale = Vector2.ZERO
	expander.z_index = 14
	scene.add_child(expander)
	return expander


static func _create_rose_orb(scene: Node, position: Vector2, size_scale: float) -> Node2D:
	var root := Node2D.new()
	root.global_position = position
	root.z_index = 16
	scene.add_child(root)
	var red := Polygon2D.new()
	red.color = Color(0.9, 0.12, 0.2, 1.0)
	red.polygon = ENEMY_GEOMETRY.build_circle_points(9.0 * size_scale, 18)
	root.add_child(red)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var petal := Polygon2D.new()
		petal.position = Vector2.RIGHT.rotated(angle) * 11.25 * size_scale
		petal.color = Color(0.18, 0.78, 0.26, 1.0)
		petal.polygon = ENEMY_GEOMETRY.build_circle_points(2.25 * size_scale, 12)
		root.add_child(petal)
	return root


static func _track_sequence(scene: Node, key: String, data: Dictionary) -> void:
	var active: Array = scene.get_meta(key, [])
	active.append(data)
	scene.set_meta(key, active)


static func _update_warning_scale(data: Dictionary, raw_progress: float) -> void:
	var progress: float = clampf(raw_progress, 0.0, 1.0)
	var next_scale: Vector2 = Vector2.ONE.lerp(Vector2(1.08, 1.08), progress)
	for key in ["warning", "fill"]:
		var node: Variant = data.get(key, null)
		if node != null and is_instance_valid(node) and node is Node2D:
			(node as Node2D).scale = next_scale


static func _update_bombard_expander(data: Dictionary, raw_progress: float) -> void:
	var expander: Variant = data.get("expander", null)
	if expander == null or not is_instance_valid(expander) or expander is not Node2D:
		return
	var progress: float = clampf(raw_progress, 0.0, 1.0)
	var scale_value: float = max(0.001, progress)
	(expander as Node2D).scale = Vector2(scale_value, scale_value)


static func _update_split_mother_position(data: Dictionary, raw_progress: float) -> void:
	var mother: Variant = data.get("mother", null)
	if mother == null or not is_instance_valid(mother) or mother is not Node2D:
		return
	var progress: float = clampf(raw_progress, 0.0, 1.0)
	var start: Vector2 = data.get("start", Vector2.ZERO)
	var impact_center: Vector2 = data.get("impact_center", Vector2.ZERO)
	(mother as Node2D).global_position = start.lerp(impact_center, progress)


static func _get_split_travel_duration(data: Dictionary) -> float:
	var start: Vector2 = data.get("start", Vector2.ZERO)
	var impact_center: Vector2 = data.get("impact_center", Vector2.ZERO)
	return max(0.18, start.distance_to(impact_center) / SPLIT_MOTHER_SPEED)


static func _release_sequence_visuals(data: Dictionary) -> void:
	for key in ["warning", "fill", "mother", "expander"]:
		var node: Variant = data.get(key, null)
		if node != null and is_instance_valid(node) and node is Node:
			(node as Node).queue_free()


static func _get_enemy_from_sequence(data: Dictionary):
	var enemy_ref: WeakRef = data.get("enemy_ref", null) as WeakRef
	var enemy = enemy_ref.get_ref() if enemy_ref != null else null
	if enemy == null or not is_instance_valid(enemy):
		return null
	return enemy


static func _get_aim_direction(enemy) -> Vector2:
	if enemy.target == null or not is_instance_valid(enemy.target):
		return Vector2.RIGHT
	var enemy_position: Vector2 = enemy.global_position
	var direction: Vector2 = enemy_position.direction_to(_get_target_center(enemy))
	return direction if direction.length_squared() > 0.001 else Vector2.RIGHT


static func _get_target_center(enemy) -> Vector2:
	if enemy.target == null or not is_instance_valid(enemy.target):
		return enemy.global_position
	if enemy.target.has_method("get_hurtbox_center"):
		return enemy.target.get_hurtbox_center()
	return enemy.target.global_position


static func _get_target_radius(enemy) -> float:
	if enemy.target != null and is_instance_valid(enemy.target) and enemy.target.has_method("get_hurtbox_radius"):
		return float(enemy.target.get_hurtbox_radius())
	return 0.0


static func _play_attack_visual(enemy) -> void:
	var visual: Node = enemy.get_node_or_null("ProfileVisual")
	if visual != null and visual.has_method("play_attack"):
		visual.play_attack()


static func _update_facing(enemy) -> void:
	var visual: Node = enemy.get_node_or_null("ProfileVisual")
	if visual == null or not visual.has_method("set_facing_direction"):
		return
	var enemy_position: Vector2 = enemy.global_position
	var direction: Vector2 = enemy_position.direction_to(_get_target_center(enemy))
	visual.set_facing_direction(direction)


static func _pick_unique_indices(total_count: int, pick_count: int) -> Dictionary:
	var pool: Array[int] = []
	for index in range(total_count):
		pool.append(index)
	var result := {}
	for _i in range(min(pick_count, pool.size())):
		var pool_index := randi_range(0, pool.size() - 1)
		result[pool[pool_index]] = true
		pool.remove_at(pool_index)
	return result


static func _get_enemy_current_scene(enemy) -> Node:
	if enemy == null or not is_instance_valid(enemy):
		return null
	if enemy is Node and not (enemy as Node).is_inside_tree():
		return null
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		return null
	return tree.current_scene

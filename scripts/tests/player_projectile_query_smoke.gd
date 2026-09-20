extends SceneTree

const QUERY := preload("res://scripts/player/player_projectile_query.gd")
const GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")
const BATCH := preload("res://scripts/player/player_projectile_batch.gd")
const BULLET := preload("res://scenes/bullet.tscn")
const SORT := preload("res://scripts/enemies/enemy_occlusion_sort.gd")
const RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Runtime.new()
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scene)
	current_scene = scene
	var batch := BATCH.new()
	scene.add_child(batch)
	batch.set_physics_process(false)
	for index in range(80):
		var enemy := Enemy.new()
		scene.add_child(enemy)
		enemy.position = Vector2((index % 10) * 55.0 - 260.0, (index / 10) * 42.0 - 140.0)
		enemy.contact_radius = 10.0 + index
		enemy.enemy_kind = "small_boss" if index % 19 == 0 else "normal"
		enemy.current_health = 0.0 if index % 11 == 0 else 100.0
		enemy.rebirth_timer = 1.0 if index % 13 == 0 else 0.0
		enemy.pooled_inactive = index % 17 == 0
		enemy._is_glutton = index % 19 == 0
		scene.enemies.append(enemy)
	for index in range(120):
		batch.add_projectile({"position": Vector2((index % 12) * 48.0 - 288.0, (index / 12) * 38.0 - 190.0), "damage": 10.0, "pierce_count": 3})
	var grid := batch._build_enemy_grid(scene.enemies)
	var reference_candidates := _reference_candidates(grid, Vector2(-101, -97), 390.0)
	var actual := QUERY.get_candidates(grid, Vector2(-101, -97), 390.0)
	assert(actual == reference_candidates)
	assert(actual.is_read_only())
	assert(is_same(actual, QUERY.get_candidates(grid, Vector2(-101, -97), 390.0)))
	for pass_index in range(3):
		if pass_index == 1:
			# The grid snapshot stays fixed; exact geometry and state remain live.
			scene.enemies[19].position = Vector2.ZERO
			scene.enemies[38].contact_radius = 320.0
			scene.enemies[20].current_health = 0.0
			scene.enemies[21].rebirth_timer = 2.0
			scene.enemies[22].pooled_inactive = true
		elif pass_index == 2:
			scene.enemies[23].queue_free()
			scene.enemies[24].free()
		for index in range(batch.positions.size()):
			var expected := _reference_hit(batch, index, grid)
			assert(batch._find_hit_enemy(index, grid) == expected)
			if expected != null:
				batch._mark_projectile_hit_enemy(index, expected)
				assert(batch._find_hit_enemy(index, grid) == _reference_hit(batch, index, grid))
	_check_occlusion(scene)
	_check_scene_change(scene)
	# Reset between runs must drop same-frame candidate lists as well.
	grid.clear()
	QUERY.clear_runtime_state()
	assert(QUERY.get_candidates(grid, Vector2.ZERO, 390.0).is_empty())
	await physics_frame
	grid.clear()
	assert(QUERY.get_candidates(grid, Vector2.ZERO, 390.0).is_empty())
	scene.free()
	current_scene = null
	print("PLAYER_PROJECTILE_QUERY_SMOKE_OK")
	quit()


func _reference_candidates(grid: Dictionary, center: Vector2, radius: float) -> Array:
	var candidates: Array = []
	var cell_radius := ceili(maxf(1.0, radius) / 96.0)
	var cell := Vector2i(floori(center.x / 96.0), floori(center.y / 96.0))
	for x in range(cell.x - cell_radius, cell.x + cell_radius + 1):
		for y in range(cell.y - cell_radius, cell.y + cell_radius + 1):
			if grid.has(Vector2i(x, y)):
				candidates.append_array(grid[Vector2i(x, y)])
	return candidates


func _reference_hit(batch: Node2D, index: int, grid: Dictionary) -> Node2D:
	for enemy in _reference_candidates(grid, batch.positions[index], batch.hit_radii[index] + 360.0):
		if enemy == null or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if not RESOLVER._is_live_enemy(enemy):
			continue
		if batch._has_projectile_hit_enemy(index, enemy):
			continue
		if batch._projectile_hits_enemy_shape(batch.positions[index], batch.hit_radii[index], enemy, batch.enemy_hit_radius_scales[index], batch.enemy_hit_radius_mins[index], batch.enemy_hit_radius_maxs[index]):
			return enemy
	return null


func _check_scene_change(scene: Runtime) -> void:
	var bullet = BULLET.instantiate()
	scene.add_child(bullet)
	bullet.set_physics_process(false)
	bullet.source_player = scene
	var first_grid := GRID.get_grid(scene)
	var first_candidates := QUERY.get_candidates(first_grid, Vector2.ZERO, 390.0)
	assert(not first_candidates.is_empty())
	assert(not bullet._get_candidate_enemies_near(Vector2.ZERO, 390.0).is_empty())
	var other_scene := Runtime.new()
	root.add_child(other_scene)
	current_scene = other_scene
	var second_grid := GRID.get_grid(other_scene)
	assert(is_same(first_grid, second_grid)) # The shared dictionary is rebuilt in place.
	assert(QUERY.get_candidates(second_grid, Vector2.ZERO, 390.0).is_empty())
	assert(bullet._get_candidate_enemies_near(Vector2.ZERO, 390.0).is_empty())
	current_scene = scene
	other_scene.free()


func _check_occlusion(scene: Runtime) -> void:
	var occluders: Array[Node2D] = []
	var sortable: Array[Node2D] = []
	SORT._collect_sort_targets(scene.enemies, occluders, sortable)
	var expected: Dictionary = {}
	for enemy in sortable:
		expected[enemy.get_instance_id()] = SORT._get_z_index_against_occluders(enemy, occluders)
	SORT._update_scene(scene)
	for enemy in sortable:
		assert(enemy.z_index == expected[enemy.get_instance_id()])
	# Moving one boss changes the threshold immediately on the next sort.
	occluders[0].position.y += 500.0
	SORT._update_scene(scene)
	for enemy in sortable:
		assert(enemy.z_index == SORT._get_z_index_against_occluders(enemy, occluders))


class Runtime:
	extends Node2D
	var enemies: Array = []
	func get_runtime_enemies() -> Array:
		return enemies


class Enemy:
	extends Node2D
	var enemy_kind := "normal"
	var contact_radius := 36.0
	var current_health := 100.0
	var rebirth_timer := 0.0
	var pooled_inactive := false
	var behavior_id := ""
	var secondary_behavior_id := ""
	var _is_glutton := false

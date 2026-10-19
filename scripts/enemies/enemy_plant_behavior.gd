extends RefCounted

const TREE_COOLDOWN := 10.0
const TREE_SEED_SPEED := 180.0
const TREE_SEED_DISTANCE := 400.0
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const SHEET_EFFECT := preload("res://scripts/enemies/enemy_sheet_effect.gd")
const HATCH_BURST := preload("res://assets/enemies/plants/tree_hatch_burst.png")


static func reset(enemy) -> void:
	enemy.plant_state = {"seed_cooldown": 8.0 if enemy.archetype_id == "vine" else TREE_COOLDOWN}


static func update(enemy, delta: float) -> void:
	if enemy.behavior_id == "tree_seed":
		update_tree_seed(enemy, delta)
		return
	var state: Dictionary = enemy.plant_state
	state["seed_cooldown"] = maxf(0, float(state.get("seed_cooldown", TREE_COOLDOWN)) - delta)
	if float(state["seed_cooldown"]) > 0 or not is_instance_valid(enemy.target):
		return
	if enemy.archetype_id == "vine":
		state["seed_cooldown"] = 8.0
		throw_parasite_seed(enemy)
	elif enemy.archetype_id == "shadow_tree":
		state["seed_cooldown"] = TREE_COOLDOWN
		throw_tree_seed(enemy)


static func _play_cast(enemy) -> void:
	var visual: Node = enemy.get_node_or_null("ProfileVisual")
	if visual != null and visual.has_method("play_cast"):
		visual.play_cast()


static func throw_parasite_seed(enemy):
	_play_cast(enemy)
	var seed := preload("res://scripts/enemies/parasite_seed.gd").new()
	seed.player = enemy.target
	seed.position = enemy.global_position
	seed.direction = (enemy.target.global_position - enemy.global_position).normalized()
	if seed.direction.is_zero_approx():
		seed.direction = Vector2.RIGHT
	seed.damage = maxf(0, enemy.attack) * 1.5
	seed.entangle_damage = maxf(0, enemy.attack) * 0.5
	enemy.get_tree().current_scene.add_child(seed)
	return seed


static func throw_tree_seed(enemy):
	var current_scene: Node = enemy.get_tree().current_scene
	var wave_flow = current_scene.get("wave_flow") if current_scene != null else null
	if is_instance_valid(wave_flow) and int(wave_flow.wave) == 6:
		var offspring := 0
		for unit in wave_flow.living_enemies():
			if str(unit.archetype_id) in ["tree_seed", "shadow_tree_young"]:
				offspring += 1
		if offspring >= 6:
			return null
	_play_cast(enemy)
	var seed = load("res://scenes/enemy.tscn").instantiate()
	seed.target = enemy.target
	seed.apply_enemy_profile("normal", DATABASE.get_profile("normal", "tree_seed"))
	seed.position = enemy.global_position
	var direction: Vector2 = (enemy.target.global_position - enemy.global_position).normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	seed.plant_state = {
		"direction": [direction.x, direction.y], "distance": TREE_SEED_DISTANCE,
		"land_remaining": 2.0, "landed": false, "damage": maxf(0, enemy.attack) * 2.0,
		"attack_scale": enemy.attack / 15.0, "health_scale": enemy.max_health / 100.0,
		"speed_scale": enemy.speed / 60.0
	}
	var scene: Node = enemy.get_tree().current_scene
	scene.add_child(seed)
	if scene.has_method("_on_enemy_defeated"):
		seed.defeated.connect(scene._on_enemy_defeated.bind(seed))
	return seed


static func update_tree_seed(seed, delta: float) -> void:
	var state: Dictionary = seed.plant_state
	if bool(state.get("landed", false)):
		state["land_remaining"] = maxf(0, float(state.get("land_remaining", 2.0)) - delta)
		if float(state["land_remaining"]) <= 0:
			hatch(seed)
		return
	var raw: Array = state.get("direction", [1.0, 0.0])
	var direction := Vector2(float(raw[0]), float(raw[1]))
	var distance := minf(TREE_SEED_SPEED * delta, float(state.get("distance", 0.0)))
	var start: Vector2 = seed.global_position
	var end := start + direction * distance
	if is_instance_valid(seed.target):
		var center: Vector2 = seed.target.get_hurtbox_center() if seed.target.has_method("get_hurtbox_center") else seed.target.global_position
		var radius: float = seed.target.get_hurtbox_radius() if seed.target.has_method("get_hurtbox_radius") else 16.0
		var nearest := Geometry2D.get_closest_point_to_segment(center, start, end)
		if center.distance_squared_to(nearest) <= pow(radius + 12.0, 2):
			seed.target.take_damage(float(state.get("damage", 0.0)))
			seed.queue_free()
			return
	seed.global_position = end
	state["distance"] = maxf(0, float(state.get("distance", 0.0)) - distance)
	if float(state["distance"]) <= 0:
		state["landed"] = true
		state["land_remaining"] = 2.0


static func hatch(seed) -> void:
	var state: Dictionary = seed.plant_state.duplicate(true)
	seed.apply_enemy_profile("normal", DATABASE.get_profile("normal", "shadow_tree_young"))
	seed.max_health *= float(state.get("health_scale", 1.0))
	seed.current_health = seed.max_health
	seed.attack *= float(state.get("attack_scale", 1.0))
	seed.speed *= float(state.get("speed_scale", 1.0))
	seed._spawn_status_burst(Color(0.7, 0.4, 0.9, 0.7), 30)
	if seed.is_inside_tree():
		SHEET_EFFECT.spawn(seed.get_tree().current_scene, HATCH_BURST, 6, seed.global_position, {"fps": 16.0, "art_scale": 1.3})

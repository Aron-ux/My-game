extends RefCounted

const PICKUP_COMPACTOR := preload("res://scripts/game/pickup_compactor.gd")
const BONE_PICKUP_SCENE := preload("res://scenes/bone_pickup.tscn")

const HEART_HEAL_AMOUNT := 25.0
const HEART_DROP_CHANCE := 0.006
const HEART_DROP_CHANCE_ELITE := 0.012
const HEART_DROP_CHANCE_BOSS := 0.044
const NORMAL_BONE_DROP_CHANCE := 0.01

static func drop_experience_gem(enemy) -> void:
	if enemy.exp_gem_scene == null:
		return

	var current_scene: Node = _get_enemy_current_scene(enemy)
	if current_scene == null:
		return

	var drop_absorber = _get_valid_drop_absorber(enemy)
	if drop_absorber == null and PICKUP_COMPACTOR.should_merge_new_exp_gem(current_scene):
		if PICKUP_COMPACTOR.merge_exp_value_into_existing(current_scene, enemy.global_position, enemy.experience_reward, enemy.reward_tier):
			return

	var gem: Node = _take_pickup_from_pool(current_scene, "exp_gems")
	if gem == null:
		gem = enemy.exp_gem_scene.instantiate()
	if gem == null:
		return

	current_scene.add_child(gem)
	if gem.has_method("reset_pickup"):
		gem.reset_pickup(enemy.global_position, enemy.reward_tier, enemy.experience_reward)
	elif gem.has_method("configure"):
		gem.global_position = enemy.global_position
		gem.configure(enemy.reward_tier, enemy.experience_reward)
	else:
		gem.global_position = enemy.global_position
		gem.value = enemy.experience_reward
	_absorb_drop_if_requested(drop_absorber, gem, "exp_gems")

static func maybe_drop_heart(enemy) -> void:
	if enemy.heart_pickup_scene == null:
		return
	if _get_valid_drop_absorber(enemy) != null:
		return

	var drop_chance := get_heart_drop_chance(enemy.enemy_kind)
	if randf() > drop_chance:
		return

	var current_scene: Node = _get_enemy_current_scene(enemy)
	if current_scene == null:
		return

	var spawn_position: Vector2 = enemy.global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
	if PICKUP_COMPACTOR.should_merge_new_heart(current_scene):
		if PICKUP_COMPACTOR.merge_heal_into_existing(current_scene, spawn_position, HEART_HEAL_AMOUNT):
			return

	var heart_pickup: Node = _take_pickup_from_pool(current_scene, "heart_pickups")
	if heart_pickup == null:
		heart_pickup = enemy.heart_pickup_scene.instantiate()
	if heart_pickup == null:
		return

	current_scene.add_child(heart_pickup)
	if heart_pickup.has_method("reset_pickup"):
		heart_pickup.reset_pickup(spawn_position, HEART_HEAL_AMOUNT)
	else:
		heart_pickup.global_position = spawn_position

static func get_heart_drop_chance(enemy_kind: String) -> float:
	match enemy_kind:
		"elite":
			return HEART_DROP_CHANCE_ELITE
		"boss":
			return HEART_DROP_CHANCE_BOSS
		_:
			return HEART_DROP_CHANCE


static func maybe_drop_bones(enemy) -> void:
	var current_scene: Node = _get_enemy_current_scene(enemy)
	if current_scene == null or current_scene.get("endless_mode_active") != true:
		return
	var bone_count := get_bone_drop_count(str(enemy.enemy_kind), randf())
	if bone_count <= 0:
		return
	var bone_pickup: Node = _take_pickup_from_pool(current_scene, "bone_pickups")
	if bone_pickup == null:
		bone_pickup = BONE_PICKUP_SCENE.instantiate()
	if bone_pickup == null:
		return
	current_scene.add_child(bone_pickup)
	var spawn_position: Vector2 = enemy.global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
	if bone_pickup.has_method("reset_pickup"):
		bone_pickup.reset_pickup(spawn_position, bone_count)
	else:
		bone_pickup.global_position = spawn_position
		bone_pickup.set("value", bone_count)


static func get_bone_drop_count(enemy_kind: String, random_roll: float) -> int:
	match enemy_kind:
		"normal":
			return 1 if random_roll < NORMAL_BONE_DROP_CHANCE else 0
		"elite":
			return 1
		"small_boss":
			return 3
		"boss":
			return 8
		_:
			return 0


static func _take_pickup_from_pool(current_scene: Node, group_name: String) -> Node:
	if current_scene != null and current_scene.has_method("take_runtime_pickup_from_pool"):
		var pickup: Node = current_scene.take_runtime_pickup_from_pool(group_name) as Node
		if pickup != null and is_instance_valid(pickup):
			return pickup
	return null

static func _get_enemy_current_scene(enemy) -> Node:
	if enemy == null or not is_instance_valid(enemy):
		return null
	if enemy is Node and not (enemy as Node).is_inside_tree():
		return null
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		return null
	return tree.current_scene

static func _get_valid_drop_absorber(enemy):
	if enemy == null:
		return null
	var absorber = enemy.get("drop_absorber")
	if absorber == null or not is_instance_valid(absorber):
		return null
	return absorber

static func _absorb_drop_if_requested(absorber, pickup: Node, group_name: String) -> void:
	if pickup == null or absorber == null:
		return
	if group_name == "exp_gems" and absorber.has_method("absorb_exp_gem"):
		absorber.absorb_exp_gem(pickup)
	elif group_name == "heart_pickups" and absorber.has_method("absorb_heart"):
		absorber.absorb_heart(pickup)

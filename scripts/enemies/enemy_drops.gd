extends RefCounted

const PICKUP_COMPACTOR := preload("res://scripts/game/pickup_compactor.gd")

const HEART_DROP_CHANCE := 0.012
const HEART_DROP_CHANCE_ELITE := 0.02
const HEART_DROP_CHANCE_BOSS := 0.044

static func drop_experience_gem(enemy) -> void:
	if enemy.exp_gem_scene == null:
		return

	var current_scene = enemy.get_tree().current_scene
	if current_scene == null:
		return

	if PICKUP_COMPACTOR.should_merge_new_exp_gem(current_scene):
		if PICKUP_COMPACTOR.merge_exp_value_into_existing(current_scene, enemy.global_position, enemy.experience_reward, enemy.reward_tier):
			return

	var gem = enemy.exp_gem_scene.instantiate()
	if gem == null:
		return

	current_scene.add_child(gem)
	gem.global_position = enemy.global_position
	if gem.has_method("configure"):
		gem.configure(enemy.reward_tier, enemy.experience_reward)
	else:
		gem.value = enemy.experience_reward

static func maybe_drop_heart(enemy) -> void:
	if enemy.heart_pickup_scene == null:
		return

	var drop_chance := get_heart_drop_chance(enemy.enemy_kind)
	if randf() > drop_chance:
		return

	var current_scene = enemy.get_tree().current_scene
	if current_scene == null:
		return

	var spawn_position: Vector2 = enemy.global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
	if PICKUP_COMPACTOR.should_merge_new_heart(current_scene):
		if PICKUP_COMPACTOR.merge_heal_into_existing(current_scene, spawn_position, 50.0):
			return

	var heart_pickup = enemy.heart_pickup_scene.instantiate()
	if heart_pickup == null:
		return

	current_scene.add_child(heart_pickup)
	heart_pickup.global_position = spawn_position

static func get_heart_drop_chance(enemy_kind: String) -> float:
	match enemy_kind:
		"elite":
			return HEART_DROP_CHANCE_ELITE
		"boss":
			return HEART_DROP_CHANCE_BOSS
		_:
			return HEART_DROP_CHANCE

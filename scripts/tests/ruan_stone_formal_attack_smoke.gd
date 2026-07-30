extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := CombatScene.new()
	root.add_child(scene)
	current_scene = scene
	var player := PLAYER_SCENE.instantiate()
	scene.add_child(player)
	player.global_position = Vector2.ZERO
	player.facing_direction = Vector2.RIGHT
	player.auto_attack_enabled = true
	player.configure_ruan_stones({
		"bones": 0,
		"ruan_stone_levels": {"thunder": 1},
		"equipped_ruan_stone": "thunder"
	})

	var primary := FormalEnemy.new()
	primary.global_position = Vector2(65.0, 0.0)
	scene.add_child(primary)
	var chained := FormalEnemy.new()
	chained.global_position = Vector2(250.0, 0.0)
	scene.add_child(chained)
	scene.enemies = [primary, chained]

	await physics_frame
	player._perform_swordsman_attack()
	var queue := scene.get_node_or_null("PlayerDamageJobQueue")
	assert(queue != null)
	assert(not queue.source_role_ids.is_empty())
	assert(str(queue.source_role_ids[0]).begins_with("swordsman_basic:"))
	queue._apply_job_at_index(0)
	assert(primary.damage_taken > 0.0)
	assert(chained.damage_taken > 0.0)
	assert(primary.stone_bursts > 0)
	assert(chained.stone_bursts > 0)

	print("RUAN_STONE_FORMAL_ATTACK_SMOKE_OK")
	quit(0)


class CombatScene:
	extends Node
	var enemies: Array = []

	func get_runtime_enemies() -> Array:
		return enemies


class FormalEnemy:
	extends Node2D
	var current_health := 10000.0
	var contact_radius := 24.0
	var enemy_kind := "normal"
	var damage_taken := 0.0
	var stone_bursts := 0

	func take_damage(amount: float, _critical: bool = false) -> bool:
		damage_taken += amount
		current_health -= amount
		return current_health <= 0.0

	func take_batched_damage(amount: float, _critical: bool = false) -> bool:
		return take_damage(amount)

	func _spawn_status_burst(_color: Color, _radius: float) -> void:
		stone_bursts += 1

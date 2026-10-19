extends Node2D

const RADIUS := 175.0
var remaining := 1.5
var damage := 0.0
var source_player: Node2D
var exploded := false

func _ready() -> void:
	add_to_group("swordsman_ground_cracks")
	z_index = 2
	queue_redraw()

static func spawn(player: Node2D, at: Vector2, amount: float) -> bool:
	for crack in player.get_tree().get_nodes_in_group("swordsman_ground_cracks"):
		if is_instance_valid(crack) and not crack.exploded and crack.global_position.distance_squared_to(at) < RADIUS * RADIUS * 4.0:
			return false
	var crack := new()
	crack.source_player = player
	crack.damage = amount
	player.get_tree().current_scene.add_child(crack)
	crack.global_position = at
	return true

func _physics_process(delta: float) -> void:
	remaining -= delta
	queue_redraw()
	if remaining > 0.0:
		return
	exploded = true
	remove_from_group("swordsman_ground_cracks")
	if is_instance_valid(source_player) and not source_player.is_dead:
		source_player._spawn_ring_effect(global_position, RADIUS, Color(1.0, 0.57, 0.2, 0.85), 6.0, 0.25)
		source_player._damage_enemies_in_radius(global_position, RADIUS, damage, 0.0, 1.0, 0.0, "swordsman_aux:ground")
	queue_free()

func _draw() -> void:
	var progress := clampf(1.0 - remaining / 1.5, 0.0, 1.0)
	draw_circle(Vector2.ZERO, RADIUS, Color(0.24, 0.10, 0.04, 0.15 + progress * 0.15))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 64, Color(0.92, 0.57, 0.23, 0.65), 1.5, true)
	for index in range(7):
		var radial := Vector2.RIGHT.rotated(float(index) * TAU / 7.0)
		var elbow := (radial * 48.0 + radial.orthogonal() * 12.0) * (RADIUS / 120.0)
		var tip := radial * (91.0 + float(index % 3) * 9.0) * (RADIUS / 120.0)
		var color := Color(1.0, 0.46 + progress * 0.25, 0.18, 0.6 + progress * 0.4)
		draw_polyline(PackedVector2Array([radial * 8.0 * (RADIUS / 120.0), elbow, tip]), color, 2.0 + progress, true)
		draw_line(elbow, elbow + radial.rotated(0.65) * 30.0 * (RADIUS / 120.0), color, 1.5, true)

func get_save_data() -> Dictionary:
	return {"position": [global_position.x, global_position.y], "remaining": remaining, "damage": damage}

func apply_save_data(data: Dictionary, player: Node2D) -> void:
	var position_data: Array = data.get("position", [0.0, 0.0])
	global_position = Vector2(float(position_data[0]), float(position_data[1]))
	remaining = maxf(0.0, float(data.get("remaining", 1.5)))
	damage = float(data.get("damage", 0.0))
	source_player = player

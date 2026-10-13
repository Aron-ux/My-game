extends Node2D

const SPEED := 180.0
const MAX_DISTANCE := 350.0
const RADIUS := 50.0
var player: Node2D
var direction := Vector2.RIGHT
var distance := MAX_DISTANCE
var fuse := 2.0
var landed := false
var damage := 15.0
var entangle_damage := 5.0
var exploded := false
var flash_remaining := 0.2
var time := 0.0


func _ready() -> void:
	add_to_group("parasite_seeds")
	z_index = 12


func _physics_process(delta: float) -> void:
	time += delta
	if exploded:
		flash_remaining = maxf(0, flash_remaining - delta)
		if flash_remaining <= 0:
			queue_free()
	elif not landed:
		var step := minf(distance, SPEED * delta)
		global_position += direction * step
		distance = maxf(0, distance - step)
		if distance <= 0:
			landed = true
	else:
		fuse = maxf(0, fuse - delta)
		if fuse <= 0:
			explode()
	queue_redraw()


func explode() -> void:
	if exploded:
		return
	exploded = true
	if not is_instance_valid(player):
		return
	var center: Vector2 = player.get_hurtbox_center() if player.has_method("get_hurtbox_center") else player.global_position
	var radius: float = player.get_hurtbox_radius() if player.has_method("get_hurtbox_radius") else 0.0
	if center.distance_squared_to(global_position) > pow(RADIUS + radius, 2):
		return
	var before := float(player.current_health) + float(player.get("current_temporary_health"))
	player.take_damage(damage)
	var after := float(player.current_health) + float(player.get("current_temporary_health"))
	if before > after:
		preload("res://scripts/player/player_vine_entangle.gd").apply(player, entangle_damage)


func _draw() -> void:
	if exploded:
		var progress := 1.0 - flash_remaining / 0.2
		draw_circle(Vector2.ZERO, RADIUS * (0.4 + progress * 0.6), Color(0.65, 0.8, 0.24, flash_remaining * 2))
		draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 32, Color(0.85, 1, 0.5, flash_remaining * 4), 3)
		return
	if landed:
		draw_circle(Vector2.ZERO, RADIUS, Color(0.38, 0.56, 0.18, 0.09))
		draw_arc(Vector2.ZERO, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * (1 - fuse / 2), 32, Color(0.75, 0.94, 0.35, 0.85), 2)
	var bob := sin(time * 6) * 2 if not landed else 0.0
	draw_circle(Vector2(0, bob), 12, Color(0.06, 0.12, 0.07))
	draw_circle(Vector2(0, bob), 9, Color(0.38, 0.55, 0.18))
	draw_circle(Vector2(-3, bob - 3), 3, Color(0.8, 0.95, 0.4))
	for index in 5:
		var axis := Vector2.from_angle(float(index) * TAU / 5 + time * 0.4)
		draw_line(axis * 9, axis * 17, Color(0.45, 0.65, 0.25), 3)


func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y], "direction": [direction.x, direction.y],
		"distance": distance, "fuse": fuse, "landed": landed, "damage": damage,
		"entangle_damage": entangle_damage, "exploded": exploded, "flash_remaining": flash_remaining
	}


func apply_save_data(data: Dictionary, target: Node2D) -> void:
	player = target
	position = Vector2(float(data["position"][0]), float(data["position"][1]))
	direction = Vector2(float(data["direction"][0]), float(data["direction"][1]))
	distance = float(data.get("distance", MAX_DISTANCE))
	fuse = float(data.get("fuse", 2.0))
	landed = bool(data.get("landed", false))
	damage = float(data.get("damage", 15.0))
	entangle_damage = float(data.get("entangle_damage", 5.0))
	exploded = bool(data.get("exploded", false))
	flash_remaining = float(data.get("flash_remaining", 0.2))

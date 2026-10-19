extends Node2D

const SPEED := 180.0
const MAX_DISTANCE := 350.0
const RADIUS := 50.0
# Pixel sheets from scripts/tools/enemy_pixel_art (x4 art); scales map the
# drawn ring onto RADIUS.
const SEED_TEXTURE := preload("res://assets/enemies/plants/parasite_seed.png")
const SEED_FRAME := Vector2(96, 96)
const RING_TEXTURE := preload("res://assets/enemies/plants/parasite_ring.png")
const RING_FRAME := Vector2(288, 288)
const RING_SCALE := RADIUS / 33.0 / 4.0
const BURST_TEXTURE := preload("res://assets/enemies/plants/parasite_burst.png")
const BURST_FRAME := Vector2(304, 304)
const BURST_SCALE := RADIUS / 36.0 / 4.0
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
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


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
		_draw_sheet_frame(BURST_TEXTURE, BURST_FRAME, 6, mini(5, int(progress * 6.0)), 0, BURST_SCALE, Vector2.ZERO)
		return
	if landed:
		# Thorny roots grow around the blast radius as the 2 s fuse burns down.
		var step := clampi(int((1.0 - fuse / 2.0) * 8.0), 0, 7)
		_draw_sheet_frame(RING_TEXTURE, RING_FRAME, 8, step, 0, RING_SCALE, Vector2.ZERO)
	var bob := sin(time * 6) * 2 if not landed else 0.0
	_draw_sheet_frame(SEED_TEXTURE, SEED_FRAME, 4, int(time * 8.0) % 4, 1 if landed else 0, 0.375, Vector2(0, bob))


func _draw_sheet_frame(texture: Texture2D, frame_size: Vector2, columns: int, column: int, row: int, draw_scale: float, offset: Vector2) -> void:
	var source := Rect2(Vector2(column % columns, row) * frame_size, frame_size)
	var size := frame_size * draw_scale
	draw_texture_rect_region(texture, Rect2(offset - size * 0.5, size), source)


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

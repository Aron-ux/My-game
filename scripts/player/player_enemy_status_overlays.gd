extends RefCounted

# Pixel overlays on the player for statuses from the reworked enemies:
# vine entangle (feet), necro mark (above the head) and skull mage cold (body).
# Visual only; the statuses themselves live in their own scripts.

const VINE_ENTANGLE := preload("res://scripts/player/player_vine_entangle.gd")
const NECRO_MARK := preload("res://scripts/player/player_necro_mark.gd")
const SKULL_MAGE_EFFECTS := preload("res://scripts/player/player_skull_mage_effects.gd")
const ART_PIXEL_SCALE := 0.375
const OVERLAYS := [
	{"name": "EnemyStatusEntangle", "texture": preload("res://assets/enemies/plants/entangle.png"), "columns": 4, "fps": 6.0, "offset": Vector2(0, 30), "z": 2},
	{"name": "EnemyStatusNecroMark", "texture": preload("res://assets/enemies/necropriest/necro_mark.png"), "columns": 4, "fps": 6.0, "offset": Vector2(0, -58), "z": 3},
	{"name": "EnemyStatusFrost", "texture": preload("res://assets/enemies/skullmage/frost_overlay.png"), "columns": 4, "fps": 5.0, "offset": Vector2(0, -2), "z": 2},
]


static func sync(player) -> void:
	if player == null or not is_instance_valid(player):
		return
	var active := [
		VINE_ENTANGLE.get_remaining(player) > 0.0,
		NECRO_MARK.remaining(player) > 0.0,
		SKULL_MAGE_EFFECTS.get_cold_remaining(player) > 0.0,
	]
	var time := float(player.get("role_visual_time")) if player.get("role_visual_time") != null else 0.0
	for index in OVERLAYS.size():
		var data: Dictionary = OVERLAYS[index]
		var overlay := player.get_node_or_null(str(data["name"])) as Sprite2D
		if not active[index]:
			if overlay != null:
				overlay.visible = false
			continue
		if overlay == null:
			overlay = Sprite2D.new()
			overlay.name = str(data["name"])
			overlay.texture = data["texture"]
			overlay.hframes = int(data["columns"])
			overlay.scale = Vector2.ONE * ART_PIXEL_SCALE
			overlay.position = data["offset"]
			overlay.z_index = int(data["z"])
			overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			player.add_child(overlay)
		overlay.visible = true
		overlay.frame = int(time * float(data["fps"])) % overlay.hframes

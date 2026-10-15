extends Node2D

const GROUND := preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Terrain/Ground/Tilemap_Flat.png")
const TREE := preload("res://assets/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Tree1.png")
const BUSH := preload("res://assets/Tiny Swords (Free Pack)/Terrain/Decorations/Bushes/Bushe1.png")
const ROCK := preload("res://assets/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks/Rock1.png")
const TILE := 64
var path_cells: Dictionary = {}


func _ready() -> void:
	z_index = -50
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modulate = Color(0.69, 0.75, 0.70)
	for x in range(-7, 8):
		path_cells[Vector2i(x, 2)] = true
	for x in range(-4, 5):
		path_cells[Vector2i(x, -1)] = true
	for y in range(-1, 4):
		path_cells[Vector2i(0, y)] = true
	for x in [-7, -4, 6]:
		for y in range(0, 3):
			path_cells[Vector2i(x, y)] = true
	path_cells[Vector2i(-3, 3)] = true
	path_cells[Vector2i(-3, 2)] = true
	for position_value in [Vector2(-550, -200), Vector2(-470, -230), Vector2(-370, -260), Vector2(350, -240), Vector2(550, -210), Vector2(-555, 260), Vector2(550, 280)]:
		var tree := Sprite2D.new()
		tree.texture = TREE
		tree.hframes = 8
		tree.frame = 0
		tree.scale = Vector2(0.72, 0.72)
		tree.position = position_value
		add_child(tree)
	for position_value in [Vector2(-540, 20), Vector2(-365, 235), Vector2(265, 255), Vector2(570, 0), Vector2(140, -255)]:
		var bush := Sprite2D.new()
		bush.texture = BUSH
		bush.hframes = 8
		bush.scale = Vector2(0.7, 0.7)
		bush.position = position_value
		add_child(bush)
	for position_value in [Vector2(-310, 260), Vector2(310, 250), Vector2(-420, -250)]:
		var rock := Sprite2D.new()
		rock.texture = ROCK
		rock.position = position_value
		rock.scale = Vector2(0.65, 0.65)
		add_child(rock)
	queue_redraw()


func _draw() -> void:
	for x in range(-10, 10):
		for y in range(-6, 6):
			var cell := Vector2i(x, y)
			var source := Vector2(64, 64)
			if path_cells.has(cell):
				var left := path_cells.has(cell + Vector2i.LEFT)
				var right := path_cells.has(cell + Vector2i.RIGHT)
				var up := path_cells.has(cell + Vector2i.UP)
				var down := path_cells.has(cell + Vector2i.DOWN)
				source.x = 320 + (0 if not left else (128 if not right else 64))
				source.y = 0 if not up else (128 if not down else 64)
				if not left and not right:
					source.x = 512
				if not up and not down:
					source.y = 192
			draw_texture_rect_region(GROUND, Rect2(Vector2(x, y) * TILE, Vector2(TILE, TILE)), Rect2(source, Vector2(TILE, TILE)))

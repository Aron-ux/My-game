extends Node2D

const FRAME_COUNT := 6
const FPS := 8.0

@onready var sprite: Sprite2D = $Sprite2D

var elapsed: float = 0.0


func _process(delta: float) -> void:
	elapsed += delta
	sprite.frame = int(elapsed * FPS) % FRAME_COUNT

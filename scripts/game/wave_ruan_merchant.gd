extends Node2D

const DOG := preload("res://assets/camp/ruan_dog_husky.png")
var flow
var contact_timers: Dictionary = {}
var scan_remaining: float = 0.0

func _ready() -> void:
	var sprite := Sprite2D.new()
	var texture := AtlasTexture.new()
	texture.atlas = DOG
	texture.region = Rect2(0, 174, 90, 58)
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var label := Label.new()
	label.text = "阮狗"
	label.position = Vector2(-30, -60)
	label.add_theme_font_override("font", preload("res://scripts/ui/theme/survivors_ui_theme.gd").get_reading_font())
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	queue_redraw()

func _process(delta: float) -> void:
	if flow.main.game_over or flow.phase != "preparation":
		return
	scan_remaining -= delta
	if scan_remaining > 0:
		return
	scan_remaining = 0.1
	var now := float(flow.main.survival_time)
	for enemy in flow.living_enemies():
		if enemy.global_position.distance_squared_to(global_position) > pow(24.0 + float(enemy.contact_radius), 2):
			continue
		var id: int = enemy.get_instance_id()
		if now < float(contact_timers.get(id, 0.0)):
			continue
		contact_timers[id] = now + 1.0
		take_damage(maxf(0.0, float(enemy.attack)) * 1.5)
		if flow.merchant_health <= 0:
			return

func take_damage(amount: float) -> void:
	if flow.phase != "preparation" or flow.merchant_health <= 0:
		return
	flow.merchant_health = maxf(0.0, flow.merchant_health - maxf(0, amount))
	queue_redraw()
	if flow.merchant_health <= 0:
		flow.view.close_shop()
		hide()
		flow.main._save_run_state()

func _draw() -> void:
	if flow == null:
		return
	draw_style_box(preload("res://scripts/ui/theme/survivors_ui_theme.gd").panel_style(Color(0.08, 0.06, 0.04, 0.8), Color(0.8, 0.62, 0.25), 1, 3), Rect2(-30, 31, 60, 7))
	draw_rect(Rect2(-28, 33, 56 * flow.merchant_health / 200.0, 3), Color(0.45, 0.9, 0.5))

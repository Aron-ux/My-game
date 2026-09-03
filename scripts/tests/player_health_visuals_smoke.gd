extends SceneTree

const PLAYER_HEALTH_VISUALS := preload("res://scripts/player/player_health_visuals.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := TestOwner.new()
	get_root().add_child(owner)
	owner.current_health = owner.max_health
	owner.current_temporary_health = 85.0
	PLAYER_HEALTH_VISUALS.setup_player_health_bar(owner)
	var bar_root := owner.get_node_or_null("PlayerHealthBar") as Node2D
	var temporary_fill := bar_root.get_node_or_null("TemporaryHealthFill") as Polygon2D if bar_root != null else null
	if temporary_fill == null or not temporary_fill.visible or temporary_fill.polygon.size() < 4:
		failures.append("temporary health should remain visible at full normal health")
	else:
		var rightmost_x: float = -INF
		for point in temporary_fill.polygon:
			rightmost_x = max(rightmost_x, point.x)
		if rightmost_x > 50.0:
			failures.append("temporary health should stay inside the fixed health bar")
	var temporary_grid_lines := bar_root.get_node_or_null("TemporaryGridLines") as Node2D if bar_root != null else null
	var visible_grid_count := 0
	if temporary_grid_lines != null:
		for child in temporary_grid_lines.get_children():
			if child is Line2D and (child as Line2D).visible:
				visible_grid_count += 1
	if visible_grid_count != 1:
		failures.append("85 temporary health should have one internal 50-health grid line")

	owner.queue_free()
	if failures.is_empty():
		print("PLAYER_HEALTH_VISUALS_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


class TestOwner:
	extends Node2D

	var current_health: float = 100.0
	var current_temporary_health: float = 0.0
	var max_health: float = 100.0
	var level: int = 1

	func _get_active_role() -> Dictionary:
		return {"id": "swordsman", "color": Color.WHITE}

	func _get_role_health_bar_width(_role_id: String) -> float:
		return 100.0

extends SceneTree

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PLAYER_DAMAGE_JOB_QUEUE := preload("res://scripts/player/player_damage_job_queue.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := RuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene

	var enemy := ENEMY_SCENE.instantiate() as Node2D
	scene.add_child(enemy)
	enemy.current_health = enemy.max_health
	enemy._apply_visuals()
	var polygon := enemy.get_node_or_null("Polygon2D") as Polygon2D
	if polygon == null:
		failures.append("enemy scene should include Polygon2D fallback visual")
	else:
		var color_before := polygon.color
		var queue := PLAYER_DAMAGE_JOB_QUEUE.new()
		var source_player := SourcePlayerStub.new()
		queue.source_player = source_player
		queue.feedback_jobs_used_this_frame = 999
		var health_before: float = enemy.current_health
		var killed: bool = queue._deal_batched_damage_to_enemy(enemy, 1.0, "", 0.0, 2.0, 1.0, 0.0, null, 0.0, false)
		if killed:
			failures.append("non-lethal batched damage should not kill the test enemy")
		if enemy.current_health >= health_before:
			failures.append("batched damage should reduce enemy health")
		if enemy.hit_flash_remaining <= 0.0:
			failures.append("batched player damage should trigger light hit flash")
		if polygon.color == color_before:
			failures.append("light hit flash should tint fallback Polygon2D immediately")
		if enemy.status_root != null:
			failures.append("light hit flash should not create status visual rings for a plain normal enemy")
		enemy._physics_process(0.3)
		if enemy.hit_flash_remaining != 0.0:
			failures.append("hit flash timer should finish after enough physics time")
		if polygon.color != enemy.display_color:
			failures.append("fallback Polygon2D color should reset when hit flash finishes")
		queue.free()
		source_player.free()

	scene.queue_free()
	await process_frame
	current_scene = null

	if failures.is_empty():
		print("ENEMY_BATCHED_HIT_FEEDBACK_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


class SourcePlayerStub:
	extends Node


class RuntimeRoot:
	extends Node2D

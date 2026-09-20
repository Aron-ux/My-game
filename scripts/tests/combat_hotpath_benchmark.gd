extends SceneTree

# Run explicitly, outside the smoke suite. Writes only to .omx/performance.
const ENEMY := preload("res://scenes/enemy.tscn")
const PLAYER := preload("res://scenes/player.tscn")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const QUEUE := preload("res://scripts/player/player_damage_job_queue.gd")
const SEPARATION := preload("res://scripts/enemies/enemy_body_separation.gd")
const HUD_FLOW := preload("res://scripts/game/game_hud_flow.gd")
const STORE := preload("res://scripts/save/save_file_store.gd")
const ENEMY_COUNT := 240
const HITS_PER_SAMPLE := 160
const SAMPLES := 24

var results: Dictionary = {}
var separation_checksum := Vector2.ZERO


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(20260920)
	var scene := Runtime.new()
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scene)
	current_scene = scene
	scene.hud = HudSink.new()
	scene.add_child(scene.hud)
	scene.player = PLAYER.instantiate()
	scene.add_child(scene.player)
	var profile := DATABASE.get_profile("normal", "chaser")
	for index in range(ENEMY_COUNT):
		var enemy = ENEMY.instantiate()
		enemy.target = scene.player
		scene.add_child(enemy)
		enemy.apply_enemy_profile("normal", profile)
		enemy.position = Vector2((index % 20) * 19.0, (index / 20) * 19.0)
		enemy.max_health = 1000000.0
		enemy.current_health = enemy.max_health
	var queue := QUEUE.new()
	var source := Node.new()
	queue.source_player = source
	await process_frame
	_measure("direct_160_hits", func():
		for index in range(HITS_PER_SAMPLE):
			RESOLVER.deal_damage_to_enemy(null, scene.enemies[index], 1.0, "swordsman")
	)
	_measure("queued_160_hits", func():
		for index in range(HITS_PER_SAMPLE):
			queue._deal_batched_damage_to_enemy(scene.enemies[index], 1.0, "", 0.0, 2.0, 1.0, 0.0, null, 0.0, false)
	)
	_measure("separation_240_enemies", func():
		for enemy in scene.enemies:
			separation_checksum += SEPARATION.compute_separation_velocity(enemy)
	)
	_measure("mana_hud_refresh", func():
		scene.survival_time += 0.04
		HUD_FLOW.on_player_mana_changed(scene, 10.0, 100.0)
	)
	var payload := {"player": scene.player.get_save_data(), "enemies": []}
	for enemy in scene.enemies:
		payload.enemies.append(enemy.get_save_data())
	var primary := "res://.omx/performance/benchmark_save.json"
	var backup := "res://.omx/performance/benchmark_backup.json"
	var store = STORE.new()
	_measure("save_primary_and_backup", func():
		if store.has_method("write_json_pair"):
			store.call("write_json_pair", primary, backup, payload)
		else:
			STORE.write_json(primary, payload)
			STORE.write_json(backup, payload)
	)
	results["workload"] = {"enemies": ENEMY_COUNT, "hits_per_sample": HITS_PER_SAMPLE, "samples": SAMPLES}
	results["checks"] = {"health": scene.enemies[0].current_health, "separation_x": separation_checksum.x, "separation_y": separation_checksum.y, "save_chars": FileAccess.get_file_as_string(primary).length()}
	var label := OS.get_environment("COMBAT_BENCHMARK_LABEL")
	if label == "":
		label = "current"
	var output := FileAccess.open("res://.omx/performance/%s.json" % label, FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "\t"))
	output.close()
	print(JSON.stringify(results))
	queue.free()
	source.free()
	scene.free()
	current_scene = null
	print("COMBAT_HOTPATH_BENCHMARK_OK")
	quit(0)


func _measure(label: String, action: Callable) -> void:
	action.call() # Warm caches and lazy visual pools.
	var samples: Array[float] = []
	for _index in range(SAMPLES):
		var started := Time.get_ticks_usec()
		action.call()
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	samples.sort()
	var total := 0.0
	for sample in samples:
		total += sample
	results[label] = {"median_ms": samples[SAMPLES / 2], "p95_ms": samples[ceili(SAMPLES * 0.95) - 1], "mean_ms": total / SAMPLES}


class Runtime:
	extends Node2D
	var enemies: Array = []
	var player: Node
	var hud: Node
	var survival_time := 0.0

	func register_runtime_enemy(enemy: Node) -> void:
		enemies.append(enemy)

	func unregister_runtime_enemy(enemy: Node) -> void:
		enemies.erase(enemy)

	func get_runtime_enemies() -> Array:
		return enemies


class HudSink:
	extends Node
	func update_mana(_current: float, _maximum: float) -> void:
		pass

	func update_stats(_summary: Dictionary) -> void:
		pass

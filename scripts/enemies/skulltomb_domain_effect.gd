extends RefCounted

const SOURCES_META := "skulltomb_domain_sources"


static func register(enemy) -> void:
	var player = enemy.target
	if player == null or not is_instance_valid(player):
		return
	var sources: Dictionary = player.get_meta(SOURCES_META, {})
	sources[enemy.get_instance_id()] = weakref(enemy)
	player.set_meta(SOURCES_META, sources)


static func unregister(enemy) -> void:
	var player = enemy.target
	if player == null or not is_instance_valid(player):
		return
	var sources: Dictionary = player.get_meta(SOURCES_META, {})
	sources.erase(enemy.get_instance_id())
	player.set_meta(SOURCES_META, sources)


static func get_remaining(player: Object) -> float:
	if not player is Node2D:
		return 0.0
	var sources: Dictionary = player.get_meta(SOURCES_META, {})
	var remaining := 0.0
	for id in sources.keys():
		var enemy = sources[id].get_ref()
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.skulltomb_area_remaining <= 0.0:
			sources.erase(id)
			continue
		var vertices := PackedVector2Array()
		for index in range(3):
			vertices.append(enemy.skulltomb_area_center + Vector2.RIGHT.rotated(-PI * 0.5 + TAU * index / 3.0) * enemy.skulltomb_area_radius)
		if Geometry2D.is_point_in_polygon(player.global_position, vertices):
			remaining = maxf(remaining, enemy.skulltomb_area_remaining)
	return remaining


static func get_slow_multiplier(player: Object) -> float:
	if player.has_method("_is_status_immune") and player._is_status_immune():
		return 1.0
	return 0.9 if get_remaining(player) > 0.0 else 1.0

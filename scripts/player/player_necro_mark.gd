extends RefCounted

const META := "necro_mark_remaining"


static func apply(player) -> void:
	if player.has_method("_is_status_immune") and player._is_status_immune():
		return
	player.set_meta(META, preload("res://scripts/combat/status_resistance.gd").duration(player, 5.0))


static func remaining(player) -> float:
	return maxf(0, float(player.get_meta(META, 0.0))) if player != null else 0.0


static func tick(player, delta: float) -> void:
	player.set_meta(META, maxf(0, remaining(player) - delta))


static func convert_healing(player, amount: float) -> bool:
	if remaining(player) <= 0 or amount <= 0:
		return false
	# HP loss, rather than a hit: no dodge, armor, temporary HP or gunner Buff break.
	player.current_health = maxf(0, player.current_health - amount)
	if player.has_method("_save_active_role_health"):
		player._save_active_role_health()
	player.health_changed.emit(player.current_health, player.max_health)
	if player.current_health <= 0:
		preload("res://scripts/player/player_survival_flow.gd")._start_death_sequence(player)
	return true


static func get_buff_slot(player) -> Dictionary:
	var value := remaining(player)
	if value <= 0:
		return {}
	return {
		"id": "necro_mark", "name": "亡灵印记", "text": "亡",
		"description": "生命回复转为等量直接扣血，跳过护甲、减伤和临时生命，可致死；不会破除枪手被动Buff，重复施加只刷新。",
		"remaining": value, "duration": 5.0, "cooldown": false,
		"color": Color(0.73, 0.4, 0.9), "base_color": Color(0.22, 0.09, 0.3)
	}

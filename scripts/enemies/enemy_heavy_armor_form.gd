extends RefCounted

const DURATION := 3.0
const COOLDOWN := 20.0
const ARMOR_BONUS := 20.0
const REFLECT_RATIO := 0.05


static func is_active(enemy) -> bool:
	return str(enemy.get("archetype_id")) == "brute" and float(enemy.get("heavy_armor_remaining")) > 0.0


static func tick(enemy, delta: float) -> void:
	if str(enemy.archetype_id) != "brute" or enemy.current_health <= 0.0:
		return
	var was_active := is_active(enemy)
	enemy.heavy_armor_remaining = maxf(0.0, enemy.heavy_armor_remaining - delta)
	enemy.heavy_armor_cooldown = maxf(0.0, enemy.heavy_armor_cooldown - delta)
	if enemy.heavy_armor_cooldown <= 0.0 and enemy.target != null and is_instance_valid(enemy.target):
		enemy.heavy_armor_remaining = DURATION
		enemy.heavy_armor_cooldown = COOLDOWN
	if was_active != is_active(enemy):
		sync_visual(enemy)


static func sync_visual(enemy) -> void:
	var visual := enemy.get_node_or_null("ProfileVisual") as Node
	if visual != null and visual.has_method("set_heavy_armor"):
		visual.set_heavy_armor(is_active(enemy))


static func reflect_damage(enemy, health_lost: float) -> void:
	if not is_active(enemy) or health_lost <= 0.0 or bool(enemy.get_meta("heavy_armor_reflecting", false)):
		return
	var player = enemy.target
	if player == null or not is_instance_valid(player) or not player.has_method("take_damage"):
		return
	enemy.set_meta("heavy_armor_reflecting", true)
	player.take_damage(health_lost * REFLECT_RATIO)
	enemy.set_meta("heavy_armor_reflecting", false)

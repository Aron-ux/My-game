extends RefCounted

const SPEED := 250.0
const MAX_DISTANCE := 500.0
const EXTRA_DAMAGE_RATIO := 1.0


static func is_active(enemy) -> bool:
	return uses_fixed_charge(enemy) and float(enemy.get("dash_remaining")) > 0.0


static func uses_fixed_charge(enemy) -> bool:
	return str(enemy.get("archetype_id")) in ["dasher", "elite_ram_trail"]


static func grant_charge_haste(enemy) -> void:
	if str(enemy.archetype_id) != "elite_ram_trail" or not enemy.is_inside_tree():
		return
	for other in enemy.get_tree().get_nodes_in_group("enemies"):
		if str(other.get("archetype_id")) != "dasher":
			continue
		if float(other.get("current_health")) <= 0.0 or bool(other.get("pooled_inactive")):
			continue
		other.elite_charge_haste_remaining = 3.0


static func move(enemy, delta: float) -> void:
	# Fixed world speed: do not apply the ordinary movement speed scale again.
	var step_time: float = minf(maxf(0.0, delta), enemy.dash_remaining)
	var distance: float = minf(SPEED * step_time, enemy.dash_distance_remaining)
	enemy.global_position += enemy.dash_direction.normalized() * distance
	enemy.dash_distance_remaining = maxf(0.0, enemy.dash_distance_remaining - distance)
	enemy.dash_remaining = maxf(0.0, enemy.dash_remaining - step_time)
	if enemy.dash_distance_remaining <= 0.001 or enemy.dash_remaining <= 0.001:
		enemy.dash_remaining = 0.0
		enemy.dash_distance_remaining = 0.0
		enemy.dash_timer = enemy.dash_interval

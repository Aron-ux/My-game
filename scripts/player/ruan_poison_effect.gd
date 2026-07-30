extends Node

const TICK_INTERVAL := 0.25

var stacks: Array[Dictionary] = []
var pending_tick_elapsed: float = 0.0


func apply_stack(total_damage: float, next_duration: float, max_stacks: int) -> void:
	var duration: float = max(0.01, next_duration)
	stacks.append({
		"damage_per_second": max(0.0, total_damage) / duration,
		"remaining": duration,
		"pending_damage": 0.0
	})
	while stacks.size() > max(1, max_stacks):
		stacks.pop_front()
	set_process(true)


func _process(delta: float) -> void:
	if stacks.is_empty():
		queue_free()
		return
	var enemy: Node = get_parent()
	if enemy == null or not is_instance_valid(enemy):
		queue_free()
		return
	var all_expired := true
	for stack in stacks:
		var remaining: float = float(stack.get("remaining", 0.0))
		var applied_delta: float = min(delta, remaining)
		stack["remaining"] = max(0.0, remaining - applied_delta)
		stack["pending_damage"] = float(stack.get("pending_damage", 0.0)) + float(stack.get("damage_per_second", 0.0)) * applied_delta
		all_expired = all_expired and float(stack["remaining"]) <= 0.0
	pending_tick_elapsed += delta
	if pending_tick_elapsed >= TICK_INTERVAL or all_expired:
		var damage := 0.0
		for stack in stacks:
			damage += float(stack.get("pending_damage", 0.0))
			stack["pending_damage"] = 0.0
		_deal_damage(enemy, damage)
		pending_tick_elapsed = 0.0
		for index in range(stacks.size() - 1, -1, -1):
			if float(stacks[index].get("remaining", 0.0)) <= 0.0:
				stacks.remove_at(index)
	if stacks.is_empty():
		queue_free()


func _deal_damage(enemy: Node, damage: float) -> void:
	if damage <= 0.0:
		return
	if enemy.has_method("take_batched_damage"):
		enemy.take_batched_damage(damage)
	elif enemy.has_method("take_damage"):
		enemy.take_damage(damage)

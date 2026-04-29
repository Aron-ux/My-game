extends RefCounted

const SAMPLE_INTERVAL := 0.5

static func collect_metrics(root: Node) -> Dictionary:
	if root == null:
		return {}
	var tree := root.get_tree()
	if tree == null:
		return {}
	return {
		"fps": Engine.get_frames_per_second(),
		"enemies": tree.get_nodes_in_group("enemies").size(),
		"player_projectiles": tree.get_nodes_in_group("player_projectiles").size(),
		"enemy_projectiles": tree.get_nodes_in_group("enemy_projectiles").size(),
		"exp_gems": tree.get_nodes_in_group("exp_gems").size(),
		"heart_pickups": tree.get_nodes_in_group("heart_pickups").size(),
		"temporary_effects": tree.get_nodes_in_group("temporary_effects").size(),
		"total_nodes": _count_nodes(tree.current_scene)
	}

static func format_metrics(metrics: Dictionary) -> String:
	if metrics.is_empty():
		return "Performance: no data"
	return "FPS %d | Enemy %d | P.Bullet %d | E.Bullet %d\nGem %d | Heart %d | TempFX %d | Nodes %d" % [
		int(metrics.get("fps", 0)),
		int(metrics.get("enemies", 0)),
		int(metrics.get("player_projectiles", 0)),
		int(metrics.get("enemy_projectiles", 0)),
		int(metrics.get("exp_gems", 0)),
		int(metrics.get("heart_pickups", 0)),
		int(metrics.get("temporary_effects", 0)),
		int(metrics.get("total_nodes", 0))
	]

static func _count_nodes(node: Node) -> int:
	if node == null:
		return 0
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

extends RefCounted

# The authored N11 phase-three overlap stays below this fixed ceiling.
# Ordinary enemy limits and FPS-dependent trimming do not clip Boss patterns.
const GROUP := "boss_danmaku_projectiles"
const LIMIT := 4096
const POOL_LIMIT := 1024


static func available(scene: Node) -> int:
	if scene == null or scene.get_tree() == null:
		return 0
	return maxi(0, LIMIT - scene.get_tree().get_node_count_in_group(GROUP))

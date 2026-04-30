extends RefCounted

# Handoff note:
# This bridge is the only place where the combat scene should translate runtime
# events into achievement service calls. Keep scripts/main.gd as a composition
# root, not a platform/service integration point.
#
# Boundary rules for future changes:
# - Add new battle achievement hooks here instead of calling AchievementService
#   directly from main.gd, player.gd, or enemy.gd.
# - Keep Steam/GodotSteam out of this bridge. Steam sync belongs in
#   scripts/achievements/steam_achievement_adapter.gd and consumes neutral
#   AchievementService signals.
# - Missing AchievementService must remain a no-op so headless checks and editor
#   utility scenes can load combat code without requiring every autoload.

const ACHIEVEMENT_SERVICE_PATH := "/root/AchievementService"

static func record_enemy_defeated(context: Node, enemy_kind: String) -> void:
	var service := _get_service(context)
	if service == null or not service.has_method("record_enemy_defeated"):
		return
	service.record_enemy_defeated(enemy_kind)

static func record_endless_boss_defeated(context: Node, defeated_boss_count: int) -> void:
	var service := _get_service(context)
	if service == null or not service.has_method("record_endless_boss_defeated"):
		return
	service.record_endless_boss_defeated(defeated_boss_count)

static func record_survival_time(context: Node) -> void:
	var service := _get_service(context)
	if service == null or not service.has_method("record_survival_time"):
		return
	service.record_survival_time(float(context.get("survival_time")))

static func record_player_level(context: Node, current_level: int) -> void:
	var service := _get_service(context)
	if service == null or not service.has_method("record_player_level"):
		return
	service.record_player_level(current_level)

static func _get_service(context: Node) -> Node:
	if context == null or not context.is_inside_tree():
		return null
	return context.get_node_or_null(ACHIEVEMENT_SERVICE_PATH)

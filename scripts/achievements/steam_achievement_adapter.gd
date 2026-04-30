extends Node

# Optional Steam sync layer. Keep it disabled until GodotSteam is installed and
# the same achievement IDs are published in the Steamworks dashboard.
# Add this as a child or Autoload after AchievementService when shipping on Steam.
#
# Handoff note:
# This adapter is intentionally signal-driven. Game code should keep writing to
# AchievementService through local, platform-neutral bridges; this file is the
# only place that knows about GodotSteam.

var _steam: Object = null
var _enabled := false

func _ready() -> void:
	_enabled = Engine.has_singleton("Steam")
	if not _enabled:
		return
	_steam = Engine.get_singleton("Steam")
	var achievement_service := get_node_or_null("/root/AchievementService")
	if achievement_service != null and achievement_service.has_signal("achievement_unlocked"):
		achievement_service.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(id: String, definition: Dictionary) -> void:
	if not _enabled or _steam == null:
		return
	var steam_id := str(definition.get("steam_api_name", id))
	if steam_id == "":
		return
	_steam.call("setAchievement", steam_id)
	_steam.call("storeStats")

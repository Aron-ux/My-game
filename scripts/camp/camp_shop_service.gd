extends RefCounted

const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const ITEMS := preload("res://scripts/player/ruan_stone_system.gd")


static func trade(item_id: String, refund_one: bool = false) -> Dictionary:
	var story_mode := SAVE_MANAGER.get_active_mode() == SAVE_MANAGER.MODE_STORY
	var profile := SAVE_MANAGER.load_story_profile() if story_mode else SAVE_MANAGER.get_current_endless_profile()
	if profile.is_empty():
		return {"success": false, "reason": "profile_missing"}
	var result := ITEMS.refund(profile, item_id) if refund_one else ITEMS.purchase(profile, item_id)
	if not bool(result.get("success", false)):
		return result
	# Publish the loaded copy only after the atomic profile write succeeds.
	var saved := SAVE_MANAGER.save_story_profile(profile) if story_mode else SAVE_MANAGER.save_endless_profile(profile)
	if saved <= 0:
		return {"success": false, "reason": "save_failed"}
	result["profile"] = profile
	return result

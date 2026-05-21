extends RefCounted

const REASON_ELIGIBLE := "eligible"
const REASON_INACTIVE := "inactive"
const REASON_UNSUPPORTED_KIND := "unsupported_kind"
const REASON_UNSUPPORTED_BEHAVIOR := "unsupported_behavior"
const REASON_SECONDARY_BEHAVIOR := "secondary_behavior"
const REASON_BOSS_VISUAL := "boss_visual"
const REASON_TIMED_TRAITS := "timed_traits"

const SIMPLE_MOVEMENT_BEHAVIORS := {
	"chaser": true,
	"swarm": true,
	"shooter": true,
	"dash": true
}


static func can_batch(enemy) -> bool:
	return get_ineligibility_reason(enemy) == REASON_ELIGIBLE


static func get_ineligibility_reason(enemy) -> String:
	if enemy == null:
		return REASON_INACTIVE
	if bool(enemy.pooled_inactive):
		return REASON_INACTIVE
	if str(enemy.enemy_kind) != "normal":
		return REASON_UNSUPPORTED_KIND
	if str(enemy.secondary_behavior_id) != "":
		return REASON_SECONDARY_BEHAVIOR
	if not SIMPLE_MOVEMENT_BEHAVIORS.has(str(enemy.behavior_id)):
		return REASON_UNSUPPORTED_BEHAVIOR
	if enemy.boss_visual_instance != null:
		return REASON_BOSS_VISUAL
	if enemy._has_timed_behavior_traits() and not _can_batch_timed_behavior(str(enemy.behavior_id)):
		return REASON_TIMED_TRAITS
	return REASON_ELIGIBLE


static func _can_batch_timed_behavior(behavior_id: String) -> bool:
	return behavior_id == "shooter" or behavior_id == "dash"

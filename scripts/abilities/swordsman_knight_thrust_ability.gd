extends RefCounted

const PLAYER_SWORDSMAN_KNIGHT_THRUST_FLOW := preload("res://scripts/player/player_swordsman_knight_thrust_flow.gd")

const SKILL_ID := "knight_thrust"
const COOLDOWN := 7.0
const THRUST_LENGTH := 250.0
const THRUST_WIDTH := 58.0

var cooldown_remaining: float = 0.0

func update(owner, delta: float) -> void:
	cooldown_remaining = max(0.0, cooldown_remaining - delta)

func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and role_id == "swordsman" and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and _is_unlocked(owner) and cooldown_remaining <= 0.0

func try_trigger(owner) -> bool:
	if not can_trigger(owner, "swordsman"):
		return false
	cooldown_remaining = COOLDOWN
	var direction: Vector2 = owner._get_live_mouse_aim_direction(owner.facing_direction)
	if direction.length_squared() <= 0.001:
		direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	direction = direction.normalized()
	owner.facing_direction = direction
	PLAYER_SWORDSMAN_KNIGHT_THRUST_FLOW.apply(owner, direction)
	if owner.has_method("_spawn_thrust_effect"):
		owner._spawn_thrust_effect(owner.global_position, owner.global_position + direction * THRUST_LENGTH, Color(1.0, 0.84, 0.42, 0.92), THRUST_WIDTH, 0.2, true)
	if owner.has_method("_spawn_ring_effect"):
		owner._spawn_ring_effect(owner.global_position + direction * THRUST_LENGTH, 24.0, Color(1.0, 0.9, 0.6, 0.6), 4.0, 0.14)
	if owner.has_method("_queue_camera_shake"):
		owner._queue_camera_shake(9.5, 0.16)
	return true

func get_cooldown_slot(owner = null) -> Dictionary:
	return {
		"name": "骑士突",
		"remaining": clamp(cooldown_remaining, 0.0, COOLDOWN),
		"duration": COOLDOWN,
		"color": Color(1.0, 0.72, 0.24, 1.0),
		"description": "剑士向前刺击，不发生位移；造成 160% 伤害并获得临时血量。"
	}
func get_save_data() -> Dictionary:
	return {"cooldown_remaining": cooldown_remaining}

func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)

func _is_unlocked(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))

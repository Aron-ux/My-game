extends RefCounted

## Snapshot the attack direction when a hit is produced, before queued damage.
static func resolve(owner: Node, explicit_direction: Vector2 = Vector2.ZERO) -> Vector2:
	if explicit_direction.is_finite() and explicit_direction.length_squared() > 0.001:
		return explicit_direction.normalized()
	if not is_instance_valid(owner):
		return Vector2.ZERO
	var facing: Variant = owner.get("facing_direction")
	# Auto attacks already recorded their aim. Do not retarget during damage
	# resolution (or search the full enemy list once per AOE target).
	if owner.get("auto_attack_enabled") == true and facing is Vector2 and facing.is_finite() and facing.length_squared() > 0.001:
		return facing.normalized()
	if owner.has_method("_get_live_mouse_aim_direction"):
		var aim: Vector2 = owner._get_live_mouse_aim_direction(facing if facing is Vector2 else Vector2.RIGHT)
		if aim.is_finite() and aim.length_squared() > 0.001:
			return aim.normalized()
	elif owner.has_method("_get_attack_aim_direction"):
		var aim: Vector2 = owner._get_attack_aim_direction(facing if facing is Vector2 else Vector2.RIGHT)
		if aim.is_finite() and aim.length_squared() > 0.001:
			return aim.normalized()
	if facing is Vector2 and facing.is_finite() and facing.length_squared() > 0.001:
		return facing.normalized()
	return Vector2.ZERO


static func for_shape(owner: Node, shape: Dictionary) -> Vector2:
	var direction: Vector2 = shape.get("hit_direction", Vector2.ZERO)
	if direction.is_finite() and direction.length_squared() > 0.001:
		return resolve(owner, direction)
	else:
		match str(shape.get("type", "circle")):
			"line":
				direction = shape.get("end", Vector2.ZERO) - shape.get("start", Vector2.ZERO)
			"oriented_rect":
				direction = shape.get("axis", Vector2.ZERO)
			"cone":
				direction = shape.get("direction", Vector2.ZERO)
	var registry: Dictionary = shape.get("hit_registry", {})
	if registry.has("slash_direction"):
		direction = registry["slash_direction"]
	return resolve(owner, direction)

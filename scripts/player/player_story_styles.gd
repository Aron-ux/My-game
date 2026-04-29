extends RefCounted

static func get_story_style_id(equipped_styles: Dictionary, role_id: String) -> String:
	return str(equipped_styles.get(role_id, "default"))


static func configure_story_loadout(owner, team_order: Array, equipped_styles: Dictionary) -> void:
	var ordered_roles: Array = []
	for role_variant in team_order:
		var role_id := str(role_variant)
		for role_data in owner.roles:
			if str(role_data.get("id", "")) == role_id:
				ordered_roles.append(role_data)
				break
	for role_data in owner.roles:
		if not ordered_roles.has(role_data):
			ordered_roles.append(role_data)
	owner.roles = ordered_roles
	for role_id in ["swordsman", "gunner", "mage"]:
		owner.story_equipped_styles[role_id] = str(equipped_styles.get(role_id, "default"))
	owner.active_role_index = clamp(owner.active_role_index, 0, max(0, owner.roles.size() - 1))
	owner._update_active_role_state()

static func get_damage_multiplier(style_id: String) -> float:
	match style_id:
		"moon_edge":
			return 0.92
		"star_pierce":
			return 0.95
		"frostfield":
			return 0.94
	return 1.0

static func get_range_multiplier(style_id: String, attribute_range_multiplier: float) -> float:
	var multiplier := 1.0
	match style_id:
		"moon_edge":
			multiplier = 1.22
		"frostfield":
			multiplier = 1.18
	return multiplier * attribute_range_multiplier

static func get_owner_range_multiplier(owner, role_id: String) -> float:
	return get_range_multiplier(
		owner._get_story_style_id(role_id),
		owner._get_role_attribute_range_multiplier(role_id)
	)

static func get_interval_bonus(style_id: String) -> float:
	match style_id:
		"moon_edge":
			return 0.02
		"frostfield":
			return 0.08
	return 0.0

static func get_extra_pierce(style_id: String) -> int:
	if style_id == "star_pierce":
		return 1
	return 0

static func get_bullet_speed_multiplier(style_id: String) -> float:
	if style_id == "star_pierce":
		return 1.2
	return 1.0

static func get_slow_bonus(style_id: String) -> float:
	if style_id == "frostfield":
		return 0.12
	return 0.0

extends RefCounted

const ROLE_IDS := ["swordsman", "gunner", "mage"]

const ROLE_DATA := [
	{
		"id": "swordsman",
		"name": "\u5251\u58EB",
		"color": Color(1.0, 0.66, 0.35, 1.0),
		"speed_scale": 1.0,
		"attack_interval": 2.0,
		"damage": 15.0,
		"range": 82.0,
		"background_interval": 2.6
	},
	{
		"id": "gunner",
		"name": "\u67AA\u624B",
		"color": Color(1.0, 0.35, 0.32, 1.0),
		"speed_scale": 1.25,
		"attack_interval": 0.44,
		"damage": 9.0,
		"range": 360.0,
		"background_interval": 2.0
	},
	{
		"id": "mage",
		"name": "\u672F\u5E08",
		"color": Color(0.44, 0.86, 1.0, 1.0),
		"speed_scale": 0.85,
		"attack_interval": 2.25,
		"damage": 25.0,
		"range": 286.0,
		"background_interval": 3.0
	}
]

const ROLE_UPGRADE_TEMPLATE := {
	"level": 0,
	"damage_bonus": 0.0,
	"interval_bonus": 0.0,
	"range_bonus": 0.0,
	"skill_bonus": 0.0
}

const ROLE_SPECIAL_STATE_TEMPLATES := {
	"swordsman": {
		"crescent_level": 0,
		"thrust_level": 0,
		"counter_level": 0,
		"pursuit_level": 0,
		"blood_level": 0,
		"stance_level": 0
	},
	"gunner": {
		"scatter_level": 0,
		"focus_level": 0,
		"support_level": 0,
		"barrage_level": 0,
		"reload_level": 0,
		"lock_level": 0
	},
	"mage": {
		"echo_level": 0,
		"frost_level": 0,
		"support_level": 0,
		"storm_level": 0,
		"flow_level": 0,
		"gravity_level": 0
	}
}

static func get_role_data() -> Array:
	var result: Array = []
	for role_data in ROLE_DATA:
		result.append((role_data as Dictionary).duplicate(true))
	return result

static func get_role_ids() -> Array:
	return ROLE_IDS.duplicate()

static func get_role_upgrade_data() -> Dictionary:
	var result := {}
	for role_id in ROLE_IDS:
		result[role_id] = ROLE_UPGRADE_TEMPLATE.duplicate(true)
	return result

static func get_role_special_state_data() -> Dictionary:
	var result := {}
	for role_id in ROLE_IDS:
		result[role_id] = (ROLE_SPECIAL_STATE_TEMPLATES.get(role_id, {}) as Dictionary).duplicate(true)
	return result

static func get_role_timing_state_data(default_value: Variant) -> Dictionary:
	var result := {}
	for role_id in ROLE_IDS:
		result[role_id] = default_value
	return result

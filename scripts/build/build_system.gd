extends RefCounted

const BUILD_DATABASE := preload("res://scripts/build/build_database.gd")

const DANGZHEN_CORE_IDS := [
	"battle_dangzhen_qichao",
	"battle_dangzhen_dielang",
	"battle_dangzhen_huichao"
]

const DANGZHEN_EVOLUTION_IDS := [
	"small_boss_dangzhen_blade_storm",
	"small_boss_dangzhen_infinite_reload",
	"small_boss_dangzhen_tidal_surge"
]

const DANGZHEN_REINFORCEMENT_IDS := [
	"small_boss_dangzhen_qichao",
	"small_boss_dangzhen_dielang",
	"small_boss_dangzhen_huichao"
]

const DANGZHEN_REINFORCEMENT_CARD_IDS := {
	"small_boss_dangzhen_qichao": "battle_dangzhen_qichao",
	"small_boss_dangzhen_dielang": "battle_dangzhen_dielang",
	"small_boss_dangzhen_huichao": "battle_dangzhen_huichao"
}

const DANGZHEN_SHARED_EVOLUTION_CARD_IDS := {
	"battle_blade_storm_fury": "battle_blade_storm_fury",
	"battle_infinite_reload_overload": "battle_blade_storm_fury",
	"battle_tidal_surge_pressure": "battle_blade_storm_fury",
	"battle_blade_storm_eye": "battle_blade_storm_eye",
	"battle_infinite_reload_chain": "battle_blade_storm_eye",
	"battle_tidal_surge_echo": "battle_blade_storm_eye",
	"battle_blade_storm_multi": "battle_blade_storm_multi",
	"battle_infinite_reload_bore": "battle_blade_storm_multi",
	"battle_tidal_surge_widen": "battle_blade_storm_multi"
}

const DANGZHEN_SHARED_EVOLUTION_CARD_GROUPS := {
	"battle_blade_storm_fury": [
		"battle_blade_storm_fury",
		"battle_infinite_reload_overload",
		"battle_tidal_surge_pressure"
	],
	"battle_blade_storm_eye": [
		"battle_blade_storm_eye",
		"battle_infinite_reload_chain",
		"battle_tidal_surge_echo"
	],
	"battle_blade_storm_multi": [
		"battle_blade_storm_multi",
		"battle_infinite_reload_bore",
		"battle_tidal_surge_widen"
	]
}

const DANGZHEN_SHARED_EVOLUTION_REWARD_IDS := [
	"small_boss_dangzhen_blade_storm",
	"small_boss_dangzhen_infinite_reload",
	"small_boss_dangzhen_tidal_surge"
]

static func get_shared_card_id(card_id: String) -> String:
	return str(DANGZHEN_SHARED_EVOLUTION_CARD_IDS.get(card_id, card_id))

static func get_shared_reward_ids(reward_id: String) -> Array:
	if DANGZHEN_SHARED_EVOLUTION_REWARD_IDS.has(reward_id):
		return DANGZHEN_SHARED_EVOLUTION_REWARD_IDS.duplicate()
	return [reward_id]

static func get_card_level(card_levels: Dictionary, card_id: String) -> int:
	var shared_card_id := get_shared_card_id(card_id)
	if not DANGZHEN_SHARED_EVOLUTION_CARD_GROUPS.has(shared_card_id):
		return int(card_levels.get(card_id, 0))
	var level := 0
	for alias_id in DANGZHEN_SHARED_EVOLUTION_CARD_GROUPS.get(shared_card_id, []):
		level = max(level, int(card_levels.get(str(alias_id), 0)))
	return level

static func get_reward_level(reward_levels: Dictionary, reward_id: String) -> int:
	if DANGZHEN_SHARED_EVOLUTION_REWARD_IDS.has(reward_id):
		var level := 0
		for shared_reward_id in DANGZHEN_SHARED_EVOLUTION_REWARD_IDS:
			level = max(level, int(reward_levels.get(shared_reward_id, 0)))
		return level
	return int(reward_levels.get(reward_id, 0))

static func get_slot_label(slot_id: String) -> String:
	return BUILD_DATABASE.get_slot_label(slot_id)

static func normalize_dangzhen_card_levels(card_levels: Dictionary) -> Dictionary:
	var normalized := card_levels.duplicate(true)
	for card_id in DANGZHEN_CORE_IDS:
		if not normalized.has(card_id):
			continue
		var config := BUILD_DATABASE.get_core_card(card_id)
		var max_level := int(config.get("max_level", 3))
		normalized[card_id] = clamp(int(normalized.get(card_id, 0)), 0, max_level)
	for shared_card_id in DANGZHEN_SHARED_EVOLUTION_CARD_GROUPS.keys():
		var config := BUILD_DATABASE.get_core_card(str(shared_card_id))
		var max_level := int(config.get("max_level", 3))
		var level := 0
		for alias_id in DANGZHEN_SHARED_EVOLUTION_CARD_GROUPS.get(shared_card_id, []):
			level = max(level, int(normalized.get(str(alias_id), 0)))
			normalized.erase(str(alias_id))
		if level > 0:
			normalized[str(shared_card_id)] = clamp(level, 0, max_level)
	return normalized

static func normalize_dangzhen_reward_levels(reward_levels: Dictionary) -> Dictionary:
	var normalized := reward_levels.duplicate(true)
	var shared_evolution_level := 0
	for reward_id in DANGZHEN_EVOLUTION_IDS:
		if normalized.has(reward_id):
			shared_evolution_level = max(shared_evolution_level, int(normalized.get(reward_id, 0)))
	if shared_evolution_level > 0:
		for reward_id in DANGZHEN_EVOLUTION_IDS:
			normalized[reward_id] = 1
	return normalized

static func get_core_card_config(card_id: String) -> Dictionary:
	return BUILD_DATABASE.get_core_card(card_id)

static func get_final_set_data(set_key: String) -> Dictionary:
	return BUILD_DATABASE.get_final_set_data(set_key)

static func is_card_offerable(card_levels: Dictionary, card_id: String) -> bool:
	var config := BUILD_DATABASE.get_core_card(card_id)
	if config.is_empty():
		return false
	for required_id in config.get("requires", []):
		if get_card_level(card_levels, str(required_id)) <= 0:
			return false
	return get_card_level(card_levels, card_id) < int(config.get("max_level", 3))

static func is_final_set_complete(card_levels: Dictionary, set_key: String) -> bool:
	for card_id in DANGZHEN_CORE_IDS:
		var config := BUILD_DATABASE.get_core_card(card_id)
		if str(config.get("set_key", "")) != set_key:
			continue
		if get_card_level(card_levels, card_id) < int(config.get("max_level", 3)):
			return false
	return set_key == "battle_dangzhen"

static func get_upgrade_pool(slot_id: String, card_levels: Dictionary, reward_levels: Dictionary = {}, active_role_id: String = "") -> Array:
	var options: Array = []
	for card_id in BUILD_DATABASE.get_core_card_ids_for_slot(slot_id):
		if is_card_offerable(card_levels, card_id):
			options.append(make_core_card_option(slot_id, card_id, card_levels))
	var active_evolution_reward_id := BUILD_DATABASE.get_evolution_reward_id_for_role(active_role_id)
	if active_evolution_reward_id != "" and _get_shared_evolution_reward_level(reward_levels) > 0:
		for card_id in BUILD_DATABASE.get_evolution_card_ids_for_reward(active_evolution_reward_id):
			if is_card_offerable(card_levels, str(card_id)):
				options.append(make_core_card_option(slot_id, str(card_id), card_levels))
	return options

static func make_core_card_option(slot_id: String, card_id: String, card_levels: Dictionary) -> Dictionary:
	var config := BUILD_DATABASE.get_core_card(card_id)
	var next_level := get_card_level(card_levels, card_id) + 1
	var title := str(config.get("title", card_id))
	var description := _make_core_card_detail_description(config)
	var preview := str(config.get("preview", description))
	var final_set := get_final_set_data(str(config.get("set_key", "")))
	return {
		"id": card_id,
		"slot": slot_id,
		"slot_label": BUILD_DATABASE.get_slot_label(slot_id),
		"title": "%s Lv.%d" % [title, next_level],
		"preview_description": preview,
		"description": description,
		"detail_description": description,
		"glossary_terms": [],
		"exact_description": description,
		"final_card_name": str(final_set.get("main_name", "")),
		"final_card_title": str(final_set.get("full_title", "")),
		"final_card_requirements": _make_final_set_requirement_payload(final_set, card_levels),
		"max_level": int(config.get("max_level", 3))
	}

static func _make_core_card_detail_description(config: Dictionary) -> String:
	var detail_lines: Array = config.get("detail_lines", [])
	if detail_lines.is_empty():
		return str(config.get("detail", ""))
	var lines: Array[String] = [str(config.get("detail", ""))]
	for detail_line in detail_lines:
		lines.append("- " + str(detail_line))
	return "\n".join(lines)

static func _make_final_set_requirement_payload(final_set: Dictionary, card_levels: Dictionary) -> Array:
	var requirement_payload: Array = []
	for requirement in final_set.get("requirements", []):
		if not (requirement is Dictionary):
			continue
		var card_id := str(requirement.get("card_id", ""))
		var max_level := int(requirement.get("max_level", 0))
		requirement_payload.append({
			"label": str(requirement.get("label", "")),
			"current_level": min(get_card_level(card_levels, card_id), max_level),
			"max_level": max_level
		})
	return requirement_payload

static func get_small_boss_reward_options(card_levels: Dictionary, reward_levels: Dictionary, active_role_id: String = "") -> Array:
	var options: Array = []
	if not is_final_set_complete(card_levels, "battle_dangzhen"):
		for reward_id in DANGZHEN_REINFORCEMENT_IDS:
			if _is_reinforcement_reward_offerable(card_levels, str(reward_id)):
				options.append(_make_small_boss_reward_option(str(reward_id)))
	else:
		var active_evolution_reward_id := BUILD_DATABASE.get_evolution_reward_id_for_role(active_role_id)
		if active_evolution_reward_id != "" and _get_shared_evolution_reward_level(reward_levels) <= 0:
			options.append(_make_small_boss_reward_option(active_evolution_reward_id))
	if options.is_empty():
		options.append(make_small_boss_training_reward_option())
	return options.slice(0, 3)

static func _get_shared_evolution_reward_level(reward_levels: Dictionary) -> int:
	var level := 0
	for reward_id in DANGZHEN_SHARED_EVOLUTION_REWARD_IDS:
		level = max(level, get_reward_level(reward_levels, str(reward_id)))
	return level

static func get_blank_small_boss_reward_options(count: int = 3) -> Array:
	var options: Array = []
	for index in range(max(0, count)):
		options.append(_make_small_boss_blank_reward_option(index + 1))
	return options

static func _is_reinforcement_reward_offerable(card_levels: Dictionary, reward_id: String) -> bool:
	var card_id := str(DANGZHEN_REINFORCEMENT_CARD_IDS.get(reward_id, ""))
	if card_id == "":
		return false
	return is_card_offerable(card_levels, card_id)

static func _make_small_boss_reward_option(reward_id: String) -> Dictionary:
	var reward := BUILD_DATABASE.get_small_boss_reward(reward_id)
	var description := str(reward.get("description", ""))
	return {
		"id": reward_id,
		"slot": "special",
		"slot_label": BUILD_DATABASE.get_slot_label("special"),
		"title": str(reward.get("title", reward_id)),
		"description": description,
		"preview_description": description,
		"exact_description": description
	}

static func _make_small_boss_blank_reward_option(index: int) -> Dictionary:
	return {
		"id": "small_boss_blank_%d" % index,
		"slot": "special",
		"slot_label": "Special Reward",
		"title": "Skip Reward",
		"description": "No special reward is currently available. Continue.",
		"preview_description": "Continue without an extra reward.",
		"exact_description": "This option gives no extra combat bonus."
	}

static func make_small_boss_training_reward_option() -> Dictionary:
	return {
		"id": "small_boss_training_level_up",
		"slot": "special",
		"slot_label": BUILD_DATABASE.get_slot_label("special"),
		"title": "\u6f5c\u5fc3\u4fee\u70bc",
		"description": "\u6240\u6709\u53ef\u9009\u5361\u724c\u5df2\u83b7\u5f97\u3002\u89d2\u8272\u7b49\u7ea7 +1\uff0c\u5e76\u7acb\u5373\u8fdb\u5165\u4e00\u6b21 Build \u5347\u7ea7\u9009\u62e9\u3002",
		"preview_description": "\u89d2\u8272\u7b49\u7ea7 +1\uff0c\u5e76\u89e6\u53d1 Build \u5347\u7ea7\u3002",
		"exact_description": "\u8fd9\u662f\u5c0f Boss \u5361\u724c\u6c60\u8017\u5c3d\u540e\u7684\u515c\u5e95\u5956\u52b1\uff1a\u63d0\u5347 1 \u7ea7\uff0c\u7136\u540e\u5f39\u51fa\u5bf9\u5e94\u7684 Build \u5347\u7ea7\u83dc\u5355\u3002"
	}

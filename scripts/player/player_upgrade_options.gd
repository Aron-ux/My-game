extends RefCounted

static func build_upgrade_options(
	body_pool: Array,
	combat_pool: Array,
	skill_pool: Array,
	pick_count: int,
	use_blank_fallback: bool,
	blank_option: Dictionary
) -> Array:
	var upgrade_pool: Array = []
	upgrade_pool.append_array(body_pool)
	upgrade_pool.append_array(combat_pool)
	upgrade_pool.append_array(skill_pool)
	var options: Array = pick_upgrade_options(upgrade_pool, pick_count)
	if options.is_empty() and use_blank_fallback:
		options.append(blank_option)
	return options

static func build_all_upgrade_options_for_developer_mode(
	body_pool: Array,
	combat_pool: Array,
	skill_pool: Array,
	endless_mode_active: bool,
	fallback_pool: Array,
	endless_blank_option: Dictionary
) -> Array:
	var options: Array = []
	options.append_array(body_pool)
	options.append_array(combat_pool)
	options.append_array(skill_pool)
	if options.is_empty():
		if endless_mode_active:
			options.append(endless_blank_option)
		else:
			options.append_array(fallback_pool)
	return options

static func pick_upgrade_options(pool: Array, count: int) -> Array:
	var candidates := pool.duplicate()
	candidates.shuffle()
	return candidates.slice(0, max(0, min(count, candidates.size())))

static func make_upgrade_option(slot_id: String, slot_label: String, option_id: String, title: String, description: String) -> Dictionary:
	return {
		"id": option_id,
		"slot": slot_id,
		"slot_label": slot_label,
		"title": title,
		"description": description,
		"preview_description": description,
		"exact_description": description
	}

static func make_endless_blank_upgrade_option(slot_label: String) -> Dictionary:
	return {
		"id": "endless_blank_upgrade",
		"slot": "body",
		"slot_label": slot_label,
		"title": "继续战斗",
		"description": "当前没有可选升级，点击继续。",
		"preview_description": "不获得额外升级，直接继续。",
		"exact_description": "这是继续选项，不提供额外战斗加成。"
	}

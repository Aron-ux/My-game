extends RefCounted

const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")

const ALL_BLESSINGS_OPTION_ID := "__all_blessings__"


static func get_boss_options() -> Array:
	return ENEMY_ARCHETYPE_DATABASE.get_boss_options()


static func get_normal_enemy_options() -> Array:
	return ENEMY_ARCHETYPE_DATABASE.get_normal_enemy_options()


static func get_enemy_options() -> Array:
	return ENEMY_ARCHETYPE_DATABASE.get_developer_enemy_options()


static func get_skill_options(player) -> Array:
	var options: Array = []
	for skill_id_value in PLAYER_BLESSING_SKILL_STATE.ACTIVE_SKILL_IDS:
		var skill_id := str(skill_id_value)
		var title := PLAYER_BLESSING_SKILL_STATE.get_skill_title(skill_id)
		var role_id := PLAYER_BLESSING_SKILL_STATE.get_skill_role_id(skill_id)
		var current_tier := PLAYER_BLESSING_SKILL_STATE.get_skill_tier(player, skill_id) if player != null else 0
		for tier in [1, 2]:
			options.append({
				"id": "%s:%d" % [skill_id, tier],
				"skill_id": skill_id,
				"tier": tier,
				"title": "%s %s" % [title, _get_tier_suffix(tier)],
				"description": "开发者模式：解锁或升到%s。归属角色：%s；当前阶级：%s。" % [_get_tier_suffix(tier), role_id, _get_tier_suffix(current_tier)],
				"enabled": true
			})
	return options


static func get_blessing_options(player) -> Array:
	var options: Array = [{
		"id": ALL_BLESSINGS_OPTION_ID,
		"title": "一键添加所有祝福",
		"description": "开发者模式：给所有祝福的 I-IV 阶各添加 1 次。",
		"enabled": true,
		"is_bulk_action": true
	}]
	for blessing_id_value in PLAYER_BLESSING_SYSTEM.DEFINITIONS.keys():
		var blessing_id := str(blessing_id_value)
		var definition: Dictionary = PLAYER_BLESSING_SYSTEM.DEFINITIONS.get(blessing_id, {})
		var tier_values: Dictionary = definition.get("tier_values", {})
		for tier in range(1, PLAYER_BLESSING_SYSTEM.MAX_BLESSING_TIER + 1):
			if not tier_values.has(tier):
				continue
			var current_count: int = _get_blessing_count(player, blessing_id, tier, str(definition.get("binding", PLAYER_BLESSING_SYSTEM.ROLE_BOUND)))
			var description := _get_blessing_tier_description(definition, tier)
			options.append({
				"id": "%s:%d" % [blessing_id, tier],
				"blessing_id": blessing_id,
				"tier": tier,
				"title": "%s %s  x%d" % [str(definition.get("title", blessing_id)), _get_tier_suffix(tier), current_count],
				"description": "开发者模式：直接获得一次该祝福。\n%s\n绑定：%s\n当前：x%d" % [
					description,
					"技能" if str(definition.get("binding", PLAYER_BLESSING_SYSTEM.ROLE_BOUND)) == PLAYER_BLESSING_SYSTEM.SKILL_BOUND else "三人共享角色数值",
					current_count
				],
				"enabled": true
			})
	var bulk_option: Dictionary = options.pop_front()
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_tier: int = int(a.get("tier", 1))
		var b_tier: int = int(b.get("tier", 1))
		if a_tier != b_tier:
			return a_tier < b_tier
		return str(a.get("title", "")) < str(b.get("title", ""))
	)
	options.push_front(bulk_option)
	return options


static func _get_blessing_count(player, blessing_id: String, tier: int, binding: String) -> int:
	if player == null:
		return 0
	if binding == PLAYER_BLESSING_SYSTEM.SKILL_BOUND:
		var skill_levels: Dictionary = player.get_skill_blessing_levels() if player.has_method("get_skill_blessing_levels") else player.skill_blessing_levels
		return int((skill_levels.get(blessing_id, {}) as Dictionary).get(tier, 0))
	var role_id := ""
	if player.has_method("_get_active_role_id"):
		role_id = str(player._get_active_role_id())
	elif player.has_method("_get_active_role"):
		role_id = str(player._get_active_role().get("id", ""))
	var role_levels: Dictionary = player.get_role_blessing_levels(role_id) if player.has_method("get_role_blessing_levels") else {}
	return int((role_levels.get(blessing_id, {}) as Dictionary).get(tier, 0))


static func _get_blessing_tier_description(definition: Dictionary, tier: int) -> String:
	var descriptions: Dictionary = definition.get("descriptions", {})
	if descriptions.has(tier):
		return str(descriptions.get(tier, ""))
	return ""


static func _get_tier_suffix(tier: int) -> String:
	match tier:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		4:
			return "IV"
	return "-"

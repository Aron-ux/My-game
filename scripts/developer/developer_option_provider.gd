extends RefCounted

const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")
const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

const ALL_BLESSINGS_OPTION_ID := "__all_blessings__"
const SKILL_TALENT_OPTION_PREFIX := "skill_talent:"
const CLEAR_SKILL_TALENTS_OPTION_ID := "__clear_skill_talents__"


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
	options.append({
		"id": SKILL_TALENT_OPTION_PREFIX + CLEAR_SKILL_TALENTS_OPTION_ID,
		"title": "重置全部质变选择",
		"description": "开发者模式：清空三名角色已选质变并保留构筑等级；已达到 Lv.3 的技能会重新进入待选队列。",
		"enabled": true
	})
	for role_id in ["swordsman", "gunner", "mage"]:
		for progress_id in PLAYER_SKILL_TALENT_SYSTEM.ROLE_PROGRESS_ORDER.get(role_id, []):
			var level: int = PLAYER_SKILL_TALENT_SYSTEM.get_skill_progress_level(player, role_id, progress_id) if player != null else 0
			var selected_id: String = PLAYER_SKILL_TALENT_SYSTEM.get_selected_talent(player, role_id, progress_id) if player != null else ""
			for talent_value in PLAYER_SKILL_TALENT_SYSTEM.TALENT_DEFINITIONS.get(progress_id, []):
				var talent: Dictionary = talent_value
				var talent_id := str(talent.get("id", ""))
				options.append({
					"id": SKILL_TALENT_OPTION_PREFIX + talent_id,
					"title": "%s · %s%s" % [
						str(PLAYER_SKILL_TALENT_SYSTEM.PROGRESS_TITLES.get(progress_id, progress_id)),
						str(talent.get("title", talent_id)),
						"（已选）" if selected_id == talent_id else ""
					],
					"description": "开发者模式：自动解锁并补到构筑 Lv.3，随后选择或替换该质变。\n当前构筑：Lv.%d\n%s" % [
						level,
						str(talent.get("description", ""))
					],
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

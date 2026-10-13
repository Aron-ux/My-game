extends RefCounted

const LEVELS := preload("res://scripts/player/player_skill_level_system.gd")
const BASIC := preload("res://scripts/player/player_swordsman_basic_build.gd")
const BLESSINGS := preload("res://scripts/player/player_blessing_system.gd")
const SKILLS := preload("res://scripts/player/player_blessing_skill_state.gd")
const EFFECTS := preload("res://scripts/player/player_skill_level_effect_flow.gd")
const ITEMS := preload("res://scripts/player/ruan_stone_system.gd")
const COOLDOWNS := preload("res://scripts/player/player_skill_cooldown_flow.gd")
const BASIC_SLOTS := preload("res://scripts/player/player_skill_cooldown_slots.gd")
const ULTIMATES := preload("res://scripts/player/player_ultimate_flow.gd")

static func blessing_catalog(player) -> Array:
	var result: Array = []
	var levels: Dictionary = BLESSINGS._get_shared_role_levels(player) if player != null else {}
	for id in BLESSINGS.DEFINITIONS:
		var definition: Dictionary = BLESSINGS.DEFINITIONS[id]
		if str(definition.get("category", "")) != BLESSINGS.CATEGORY_GENERAL_BLESSING or not bool(definition.get("offerable", true)):
			continue
		var tiers: Array = []
		for tier in definition.get("tier_values", {}):
			tiers.append({"tier": int(tier), "count": int(levels.get(id, {}).get(tier, 0)), "description": BLESSINGS._get_tier_description(definition, tier)})
		result.append({"id": id, "title": BLESSINGS._get_definition_title(definition, id), "tiers": tiers})
	return result

static func skill_catalog(player) -> Array:
	var result: Array = []
	if player == null:
		return result
	for role in player.roles:
		var role_id: String = str(role["id"])
		var current_descriptions: Dictionary = {}
		var interval: float = player._get_effective_attack_interval(role_id)
		current_descriptions[role_id + "_basic_attack"] = BASIC_SLOTS._get_basic_attack_description(role_id, interval)
		current_descriptions[role_id + "_ultimate"] = str(ULTIMATES.get_ultimate_display(player, role_id).get("description", ""))
		for skill_id in COOLDOWNS.ROLE_ACTIVE_SKILL_PROPERTIES.get(role_id, {}):
			var property_name: String = COOLDOWNS.ROLE_ACTIVE_SKILL_PROPERTIES[role_id][skill_id]
			var ability: Variant = player.get(property_name)
			if ability != null and ability.has_method("get_cooldown_slot"):
				var slot: Dictionary = ability.get_cooldown_slot(player)
				current_descriptions[skill_id] = str(slot.get("description", ""))
		for progress in LEVELS.get_role_progress_ids(role_id):
			var unlocked := LEVELS.is_progress_unlocked(player, progress)
			var level := LEVELS.get_skill_level(player, role_id, progress)
			var build = LEVELS.basic_build(progress)
			var basic: bool = LEVELS.is_custom_basic(progress)
			var ultimate := LEVELS.is_ultimate_progress(progress)
			var description: String = build.description(player) if basic else EFFECTS.get_upgrade_preview_text(player, role_id, progress)
			if not basic:
				var skill_id: String = str(LEVELS.UNLOCKABLE_PROGRESS.get(progress, role_id + "_basic_attack" if str(progress).ends_with("_basic") else progress))
				var current: String = str(current_descriptions.get(skill_id, ""))
				description = ("\n下一级：" + description) if description != "" else "\n已达到等级上限。" if ultimate or level >= 10 else "\n按当前正式技能规则升级。"
				description = current + description
			if basic and str(progress).ends_with("_basic"):
				var speed: float = player._get_effective_attack_speed(role_id)
				description += "\n实际攻击速度：%.2f 次/秒\n普通攻击间隔：%.2f 秒" % [speed, 1.0 / maxf(0.01, speed)]
			result.append({
				"id": progress, "role_id": role_id, "role_name": str(role.get("name", role_id)),
				"title": LEVELS.get_progress_title(progress), "level": level, "unlocked": unlocked,
				"min_level": 0 if basic else 1, "max_level": 9 if basic else 1 if ultimate else 10,
				"description": description.strip_edges(), "choices": build.choices(player).duplicate() if basic else {}
			})
	return result

static func item_catalog(player) -> Array:
	var result: Array = []
	for id in ITEMS.STONE_IDS:
		var definition := ITEMS.get_definition(id)
		var count: int = player.get_ruan_stone_level(id) if player != null else 0
		var effect := ITEMS.get_effect_text(id, 1)
		result.append({"id": id, "title": definition["title"], "count": count, "description": effect if effect != "" else str(definition.get("summary", ""))})
	return result

static func apply(player, request: Dictionary) -> bool:
	if player == null:
		return false
	var kind: String = str(request.get("kind", ""))
	var id: String = str(request.get("id", ""))
	var operation: String = str(request.get("operation", ""))
	var amount: int = clampi(int(request.get("amount", 1)), 0, 999)
	var changed := false
	match kind:
		"blessing":
			changed = _change_blessing(player, id, int(request.get("tier", 1)), operation, amount)
		"all_blessings":
			if operation != "add":
				return false
			for option in blessing_catalog(player):
				changed = _change_blessing(player, option["id"], int(request.get("tier", 1)), "add", amount) or changed
		"item":
			if not ITEMS.STONE_IDS.has(id):
				return false
			var count: int = player.get_ruan_stone_level(id)
			var target := _count_after(count, operation, amount)
			if target < 0:
				return false
			player.set_developer_ruan_stone_level(id, target)
			player.ruan_stone_proc_events.clear()
			changed = true
		"bones":
			var target := _count_after(player.get_developer_bone_count(), operation, amount)
			if target < 0:
				return false
			player.set_developer_bone_count(target)
			changed = true
		"skill":
			changed = _change_skill(player, request)
	if changed:
		_refresh(player)
	return changed

static func _count_after(count: int, operation: String, amount: int) -> int:
	match operation:
		"add": return mini(999, count + amount)
		"remove": return maxi(0, count - amount)
		"clear": return 0
		"set": return amount
	return -1

static func _change_blessing(player, id: String, tier: int, operation: String, amount: int) -> bool:
	var definition: Dictionary = BLESSINGS.DEFINITIONS.get(id, {})
	if str(definition.get("category", "")) != BLESSINGS.CATEGORY_GENERAL_BLESSING or not bool(definition.get("offerable", true)):
		return false
	if not definition.get("tier_values", {}).has(tier):
		return false
	var shared: Dictionary = BLESSINGS._get_shared_role_levels(player).duplicate(true)
	var levels: Dictionary = shared.get(id, {}).duplicate()
	var previous: int = int(levels.get(tier, 0))
	var count := _count_after(previous, operation, amount)
	if count < 0:
		return false
	if count == 0:
		levels.erase(tier)
	else:
		levels[tier] = count
	if levels.is_empty():
		shared.erase(id)
	else:
		shared[id] = levels
	BLESSINGS._set_shared_role_levels(player, shared)
	if count > previous:
		# Preserve the normal health-on-grant effect without rebuilding HUD once per copy.
		BLESSINGS._apply_role_stat_delta(player, str(definition.get("stat", "")), float(definition["tier_values"][tier]) * (count - previous))
	return true

static func _change_skill(player, request: Dictionary) -> bool:
	var role_id: String = str(request.get("role_id", ""))
	var id: String = str(request.get("id", ""))
	var build = LEVELS.basic_build(id)
	if not LEVELS.get_role_progress_ids(role_id).has(id):
		return false
	var in_team := false
	for role in player.roles:
		in_team = in_team or str(role["id"]) == role_id
	if not in_team:
		return false
	var operation: String = str(request.get("operation", ""))
	var state: Dictionary = LEVELS.normalize_role_state(role_id, player.role_special_states.get(role_id, {}))
	player.role_special_states[role_id] = state
	if operation == "branch":
		var stage: int = int(request.get("stage", 0))
		var key: String = str(request.get("choice", ""))
		if not LEVELS.is_custom_basic(id) or not build.STAGES.has(stage) or build.level(player) < stage:
			return false
		var valid := false
		for option in build.OPTIONS[stage]:
			valid = valid or option["key"] == key
		if not valid:
			return false
		state[build.STATE_KEY][str(stage)] = key
		return true
	if operation == "unlock":
		var skill: String = str(LEVELS.UNLOCKABLE_PROGRESS.get(id, ""))
		return skill != "" and SKILLS.force_unlock_skill(player, skill, 1)
	if not LEVELS.is_progress_unlocked(player, id):
		return false
	if operation == "add":
		if LEVELS.is_ultimate_progress(id):
			return false
		return not LEVELS.add_skill_level(player, role_id, id).is_empty()
	if operation not in ["set", "reset"] or LEVELS.is_ultimate_progress(id):
		return false
	var minimum := 0 if LEVELS.is_custom_basic(id) else 1
	var maximum := 9 if LEVELS.is_custom_basic(id) else 10
	var level: int = minimum if operation == "reset" else clampi(int(request.get("amount", minimum)), minimum, maximum)
	state["skill_levels"][id] = level
	if LEVELS.is_custom_basic(id):
		for stage in build.STAGES:
			if level < stage or operation == "reset":
				state[build.STATE_KEY].erase(str(stage))
	else:
		state["skill_talent_slots"].erase(id)
	player.role_special_states[role_id] = state
	return true

static func _refresh(player) -> void:
	if player.has_method("_save_active_role_health"):
		player._save_active_role_health()
	for role in player.roles:
		var id: String = str(role["id"])
		if player.role_health_values.has(id):
			player.role_health_values[id] = minf(float(player.role_health_values[id]), player._get_role_max_health(id))
	player._sync_active_role_max_health(false, false)
	player._update_fire_timer()
	player.stats_changed.emit(player.get_stat_summary())

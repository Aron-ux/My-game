extends RefCounted

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")

const OFFER_COUNT := 3
const OFFER_REFRESH_LIMIT := 1
const OPTION_PREFIX := "blessing:"
const ROLE_BOUND := "role"
const SKILL_BOUND := "skill"
const CATEGORY_GENERAL_BLESSING := "general_blessing"
const CATEGORY_MAGIC_STONE := "magic_stone"
const CATEGORY_MAGIC_STONE_BLESSING := "magic_stone_blessing"
const CATEGORY_LEGACY_SKILL_BLESSING := "legacy_skill_blessing"
const MAGIC_STONE_KINGDOM := "kingdom"
const MAGIC_STONE_KING := "king"
const MAGIC_STONE_KEBIRU := "kebiru"
const MAGIC_STONE_INVOKER := "invoker"
const MAX_BLESSING_TIER := 4
const MANUAL_COMPOSE_TIER_ONE_LEVEL := 3
const MAX_BLESSING_COUNT_PER_TIER := 6
const TIER_LIMITS := {1: 6, 2: 3, 3: 2, 4: 1}
const TIER_WEIGHT_LEVEL_1_TO_6 := {1: 100}
const TIER_WEIGHT_LEVEL_7_TO_12 := {1: 80, 2: 20}
const TIER_WEIGHT_LEVEL_13_TO_18 := {1: 65, 2: 30, 3: 5}
const TIER_WEIGHT_LEVEL_19_PLUS := {1: 48, 2: 40, 3: 10, 4: 2}
const BLESSING_TEXT_COLOR := Color(0.0, 0.0, 0.0, 1.0)

const MAGIC_STONE_OPTION_PREFIX := "magic_stone:"
const MAGIC_STONE_DEFINITIONS := {
	MAGIC_STONE_KEBIRU: {
		"title": "克比鲁的魔石",
		"summary": "获得当前角色对应的克比鲁魔法。",
		"description": "获得当前角色对应的克比鲁魔法。",
		"role_descriptions": {
			"swordsman": "获得月牙剑气",
			"gunner": "获得散弹",
			"mage": "获得波涛汹涌"
		}
	},
	MAGIC_STONE_INVOKER: {
		"title": "因沃克的魔法石",
		"summary": "获得当前角色对应的因沃克魔法。",
		"description": "获得当前角色对应的因沃克魔法。",
		"role_descriptions": {
			"swordsman": "获得剑刃风暴",
			"gunner": "获得无限装填",
			"mage": "获得梅塔领域"
		}
	}
}
const MAGIC_STONE_UNLOCK_SKILLS := {
	MAGIC_STONE_KEBIRU: ["crescent_wave", "surging_wave", "shrapnel_field"],
	MAGIC_STONE_INVOKER: ["blade_storm", "infinite_reload", "meta_field"]
}
const MAGIC_STONE_ROLE_SKILLS := {
	MAGIC_STONE_KINGDOM: {
		"swordsman": "swordsman_basic_attack",
		"gunner": "gunner_basic_attack",
		"mage": "mage_basic_attack"
	},
	MAGIC_STONE_KING: {
		"swordsman": "swordsman_ultimate",
		"gunner": "gunner_ultimate",
		"mage": "mage_ultimate"
	},
	MAGIC_STONE_KEBIRU: {
		"swordsman": "crescent_wave",
		"gunner": "shrapnel_field",
		"mage": "surging_wave"
	},
	MAGIC_STONE_INVOKER: {
		"swordsman": "blade_storm",
		"gunner": "infinite_reload",
		"mage": "meta_field"
	}
}

const DEFINITIONS := {
	"divine_grace": {
		"title": "神赐",
		"category": CATEGORY_GENERAL_BLESSING,
		"binding": ROLE_BOUND,
		"stat": "max_health",
		"tier_values": {1: 10.0, 2: 20.0, 3: 30.0, 4: 100.0},
		"descriptions": {
			1: "所有角色血量加10",
			2: "所有角色血量加20",
			3: "所有角色血量加30",
			4: "所有角色血量加100"
		},
		"card_summaries": {
			1: "全员血量+10",
			2: "全员血量+20",
			3: "全员血量+30",
			4: "全员血量+100"
		}
	},
	"prayer": {
		"title": "祈祷",
		"category": CATEGORY_LEGACY_SKILL_BLESSING,
		"binding": ROLE_BOUND,
		"stat": "cooldown_reduction",
		"tier_values": {1: 0.04, 2: 0.075},
		"descriptions": {1: "减少当前角色技能CD", 2: "减少当前角色技能CD"}
	},
	"formation_break": {
		"title": "破阵",
		"category": CATEGORY_LEGACY_SKILL_BLESSING,
		"binding": ROLE_BOUND,
		"stat": "skill_range",
		"tier_values": {1: 0.02, 2: 0.035},
		"descriptions": {1: "增加当前角色技能范围", 2: "增加当前角色技能范围"}
	},
	"benediction": {
		"title": "恩典",
		"category": CATEGORY_GENERAL_BLESSING,
		"binding": ROLE_BOUND,
		"stat": "energy_gain",
		"nonlinear": true,
		"tier_values": {1: 0.10, 2: 0.15, 3: 0.20, 4: 0.40},
		"descriptions": {
			1: "终极技能回复效率增加10%",
			2: "终极技能回复效率增加15%",
			3: "终极技能回复效率增加20%",
			4: "终极技能回复效率增加40%"
		},
		"card_summaries": {
			1: "回能效率+10%",
			2: "回能效率+15%",
			3: "回能效率+20%",
			4: "回能效率+40%"
		}
	},
	"greed": {
		"title": "贪婪",
		"category": CATEGORY_GENERAL_BLESSING,
		"binding": ROLE_BOUND,
		"stat": "greed_kill_heal",
		"proc_chance": 0.05,
		"tier_values": {1: 5.0, 2: 7.0, 3: 10.0, 4: 20.0},
		"descriptions": {
			1: "击杀怪物有5%几率回复5点血量",
			2: "击杀怪物有5%几率回复7点血量",
			3: "击杀怪物有5%几率回复10点血量",
			4: "击杀怪物有5%几率回复20点血量"
		},
		"card_summaries": {
			1: "击杀5%回血5",
			2: "击杀5%回血7",
			3: "击杀5%回血10",
			4: "击杀5%回血20"
		}
	},
	"support": {
		"title": "支援",
		"category": CATEGORY_GENERAL_BLESSING,
		"binding": ROLE_BOUND,
		"stat": "switch_cooldown_reduction",
		"nonlinear": true,
		"tier_values": {1: 0.05, 2: 0.10, 3: 0.15, 4: 0.30},
		"descriptions": {
			1: "角色切换冷却减少5%",
			2: "角色切换冷却减少10%",
			3: "角色切换冷却减少15%",
			4: "角色切换冷却减少30%"
		},
		"card_summaries": {
			1: "切换冷却-5%",
			2: "切换冷却-10%",
			3: "切换冷却-15%",
			4: "切换冷却-30%"
		}
	},
	"tailwind": {
		"title": "乘风",
		"category": CATEGORY_GENERAL_BLESSING,
		"binding": ROLE_BOUND,
		"stat": "move_speed",
		"tier_values": {1: 5.0, 2: 8.0, 3: 10.0, 4: 20.0},
		"descriptions": {
			1: "所有角色移动速度+5",
			2: "所有角色移动速度+8",
			3: "所有角色移动速度+10",
			4: "所有角色移动速度+20"
		},
		"card_summaries": {
			1: "全员移速+5",
			2: "全员移速+8",
			3: "全员移速+10",
			4: "全员移速+20"
		}
	},
	"blazing_sun": {
		"title": "焰阳",
		"category": CATEGORY_GENERAL_BLESSING,
		"binding": ROLE_BOUND,
		"stat": "damage",
		"tier_values": {1: 5.0, 2: 10.0, 3: 15.0, 4: 30.0},
		"descriptions": {
			1: "所有角色造成伤害+5",
			2: "所有角色造成伤害+10",
			3: "所有角色造成伤害+15",
			4: "所有角色造成伤害+30"
		},
		"card_summaries": {
			1: "全员伤害+5",
			2: "全员伤害+10",
			3: "全员伤害+15",
			4: "全员伤害+30"
		}
	},
	"phantom": {
		"title": "幻影",
		"category": CATEGORY_GENERAL_BLESSING,
		"binding": ROLE_BOUND,
		"stat": "dodge",
		"nonlinear": true,
		"tier_values": {1: 0.03, 2: 0.05, 3: 0.10, 4: 0.20},
		"descriptions": {
			1: "所有角色闪避几率+3%",
			2: "所有角色闪避几率+5%",
			3: "所有角色闪避几率+10%",
			4: "所有角色闪避几率+20%"
		},
		"card_summaries": {
			1: "全员闪避+3%",
			2: "全员闪避+5%",
			3: "全员闪避+10%",
			4: "全员闪避+20%"
		}
	},
	"general_trick": {
		"title": "戏法",
		"category": CATEGORY_GENERAL_BLESSING,
		"binding": ROLE_BOUND,
		"stat": "global_quantity_skill_count",
		"tier_values": {4: 1.0},
		"descriptions": {
			4: "所有数量类型技能100%效果数量+1"
		},
		"card_summaries": {
			4: "数量技能+1"
		}
	},
	"general_reprise": {
		"title": "再演",
		"category": CATEGORY_GENERAL_BLESSING,
		"binding": ROLE_BOUND,
		"stat": "global_combo_skill_extra",
		"tier_values": {4: 1.0},
		"descriptions": {
			4: "所有连段类技能100%效果数量+1"
		},
		"card_summaries": {
			4: "连段技能+1"
		}
	},
	"general_tide_rain": {
		"title": "潮雨",
		"category": CATEGORY_GENERAL_BLESSING,
		"binding": ROLE_BOUND,
		"stat": "global_duration_skill_seconds",
		"tier_values": {4: 2.5},
		"descriptions": {
			4: "所有持续类技能持续时间+2.5s"
		},
		"card_summaries": {
			4: "持续技能+2.5s"
		}
	},
	"kingdom_prayer": {
		"title": "王国：祷告",
		"category": CATEGORY_MAGIC_STONE_BLESSING,
		"magic_stone": MAGIC_STONE_KINGDOM,
		"binding": ROLE_BOUND,
		"stat": "basic_attack_cooldown_reduction",
		"nonlinear": true,
		"tier_values": {1: 0.05, 2: 0.08, 3: 0.10, 4: 0.20},
		"descriptions": {
			1: "攻击技能冷却减少5%",
			2: "攻击技能冷却减少8%",
			3: "攻击技能冷却减少10%",
			4: "攻击技能冷却减少20%"
		},
		"card_summaries": {
			1: "普攻冷却-5%",
			2: "普攻冷却-8%",
			3: "普攻冷却-10%",
			4: "普攻冷却-20%"
		}
	},
	"kingdom_trick": {
		"title": "王国：戏法",
		"category": CATEGORY_MAGIC_STONE_BLESSING,
		"magic_stone": MAGIC_STONE_KINGDOM,
		"binding": SKILL_BOUND,
		"stat": "basic_attack_quantity_skill_count",
		"tier_values": {2: 0.5, 3: 1.0},
		"descriptions": {
			2: "攻击50%效果数量+1",
			3: "攻击100%效果数量+1"
		},
		"card_summaries": {
			2: "普攻50%数量+1",
			3: "普攻数量+1"
		}
	},
	"kingdom_reprise": {
		"title": "王国：再演",
		"category": CATEGORY_MAGIC_STONE_BLESSING,
		"magic_stone": MAGIC_STONE_KINGDOM,
		"binding": SKILL_BOUND,
		"stat": "basic_attack_combo_skill_extra",
		"tier_values": {2: 0.5, 3: 1.0},
		"descriptions": {
			2: "攻击50%连段效果+1",
			3: "攻击100%连段效果+1"
		},
		"card_summaries": {
			2: "普攻50%连段+1",
			3: "普攻连段+1"
		}
	},
	"kingdom_tide_rain": {
		"title": "国王：潮雨",
		"category": CATEGORY_MAGIC_STONE_BLESSING,
		"magic_stone": MAGIC_STONE_KING,
		"binding": SKILL_BOUND,
		"stat": "ultimate_duration_seconds",
		"tier_values": {2: 0.5, 3: 1.0},
		"descriptions": {
			2: "终极技能持续时间+0.5s",
			3: "终极技能持续时间+1s"
		},
		"card_summaries": {
			2: "大招持续+0.5s",
			3: "大招持续+1s"
		}
	},
	"kingdom_blazing_sun": {
		"title": "国王：焰阳",
		"category": CATEGORY_MAGIC_STONE_BLESSING,
		"magic_stone": MAGIC_STONE_KING,
		"binding": SKILL_BOUND,
		"stat": "ultimate_damage_multiplier_bonus",
		"tier_values": {3: 1.0, 4: 2.0},
		"descriptions": {
			3: "终极技能伤害倍率+1",
			4: "终极技能伤害倍率+2"
		},
		"card_summaries": {
			3: "大招伤害倍率+1",
			4: "大招伤害倍率+2"
		}
	},
	"kingdom_coronation": {
		"title": "国王：加冕",
		"category": CATEGORY_MAGIC_STONE_BLESSING,
		"magic_stone": MAGIC_STONE_KING,
		"binding": SKILL_BOUND,
		"stat": "ultimate_special_effect_bonus",
		"tier_values": {3: 0.20, 4: 1.0},
		"descriptions": {
			3: "终极技能特殊效果提升20%",
			4: "终极技能特殊效果提升100%"
		},
		"card_summaries": {
			3: "大招特殊效果+20%",
			4: "大招特殊效果+100%"
		}
	},
	"kebiru_prayer": {
		"title": "克比鲁：祷告",
		"category": CATEGORY_MAGIC_STONE_BLESSING,
		"magic_stone": MAGIC_STONE_KEBIRU,
		"binding": SKILL_BOUND,
		"stat": "kebiru_magic_cooldown_reduction",
		"nonlinear": true,
		"tier_values": {1: 0.05, 2: 0.10, 3: 0.15, 4: 0.20},
		"descriptions": {
			1: "克比鲁魔法冷却减少5%",
			2: "克比鲁魔法冷却减少10%",
			3: "克比鲁魔法冷却减少15%",
			4: "克比鲁魔法冷却减少20%"
		},
		"card_summaries": {
			1: "克比鲁魔法CD-5%",
			2: "克比鲁魔法CD-10%",
			3: "克比鲁魔法CD-15%",
			4: "克比鲁魔法CD-20%"
		}
	},
	"kebiru_formation_break": {
		"title": "克比鲁：破阵",
		"category": CATEGORY_MAGIC_STONE_BLESSING,
		"magic_stone": MAGIC_STONE_KEBIRU,
		"binding": SKILL_BOUND,
		"stat": "kebiru_magic_range",
		"nonlinear": true,
		"tier_values": {1: 0.05, 2: 0.10, 3: 0.15, 4: 0.30},
		"descriptions": {
			1: "克比鲁魔法范围增加5%",
			2: "克比鲁魔法范围增加10%",
			3: "克比鲁魔法范围增加15%",
			4: "克比鲁魔法范围增加30%"
		},
		"card_summaries": {
			1: "克比鲁魔法范围+5%",
			2: "克比鲁魔法范围+10%",
			3: "克比鲁魔法范围+15%",
			4: "克比鲁魔法范围+30%"
		}
	},
	"kebiru_reprise": {
		"title": "克比鲁：再演",
		"category": CATEGORY_MAGIC_STONE_BLESSING,
		"magic_stone": MAGIC_STONE_KEBIRU,
		"binding": SKILL_BOUND,
		"stat": "kebiru_magic_combo_skill_extra",
		"tier_values": {2: 0.5, 3: 1.0},
		"descriptions": {
			2: "克比鲁魔法50%效果+1",
			3: "克比鲁魔法100%效果+1"
		},
		"card_summaries": {
			2: "克比鲁魔法50%+1",
			3: "克比鲁魔法+1"
		}
	},
	"invoker_tide_rain": {
		"title": "因沃克：潮雨",
		"category": CATEGORY_MAGIC_STONE_BLESSING,
		"magic_stone": MAGIC_STONE_INVOKER,
		"binding": SKILL_BOUND,
		"stat": "invoker_magic_duration_seconds",
		"tier_values": {2: 0.5, 3: 1.0},
		"descriptions": {
			2: "因沃克魔法持续时间+0.5s",
			3: "因沃克魔法持续时间+1s"
		},
		"card_summaries": {
			2: "因沃克魔法持续+0.5s",
			3: "因沃克魔法持续+1s"
		}
	},
	"invoker_formation_break": {
		"title": "因沃克：破阵",
		"category": CATEGORY_MAGIC_STONE_BLESSING,
		"magic_stone": MAGIC_STONE_INVOKER,
		"binding": SKILL_BOUND,
		"stat": "invoker_magic_range",
		"nonlinear": true,
		"tier_values": {1: 0.05, 2: 0.10, 3: 0.15, 4: 0.30},
		"descriptions": {
			1: "因沃克魔法范围增加5%",
			2: "因沃克魔法范围增加10%",
			3: "因沃克魔法范围增加15%",
			4: "因沃克魔法范围增加30%"
		},
		"card_summaries": {
			1: "因沃克魔法范围+5%",
			2: "因沃克魔法范围+10%",
			3: "因沃克魔法范围+15%",
			4: "因沃克魔法范围+30%"
		}
	},
	"unyielding": {
		"title": "不屈",
		"category": CATEGORY_LEGACY_SKILL_BLESSING,
		"binding": ROLE_BOUND,
		"stat": "damage_reduction",
		"tier_values": {1: 0.035, 2: 0.065},
		"descriptions": {1: "增加当前角色减伤", 2: "增加当前角色减伤"}
	},
	"tide_rain": {
		"title": "潮雨",
		"category": CATEGORY_LEGACY_SKILL_BLESSING,
		"binding": SKILL_BOUND,
		"stat": "duration_skill_duration",
		"tier_values": {1: 0.12, 2: 0.20},
		"descriptions": {1: "持续类技能持续时间增加", 2: "持续类技能持续时间增加"}
	},
	"reprise": {
		"title": "再演",
		"category": CATEGORY_LEGACY_SKILL_BLESSING,
		"binding": SKILL_BOUND,
		"stat": "combo_skill_extra",
		"tier_values": {1: 0.5, 2: 1.0},
		"descriptions": {1: "技能连段+1", 2: "技能连段+1"}
	},
	"trick": {
		"title": "戏法",
		"category": CATEGORY_LEGACY_SKILL_BLESSING,
		"binding": SKILL_BOUND,
		"stat": "quantity_skill_count",
		"tier_values": {1: 0.5, 2: 1.0},
		"descriptions": {1: "数量类技能数量增加", 2: "数量类技能数量增加"}
	}
}


static func build_empty_role_state(roles: Array) -> Dictionary:
	var state := {}
	for role_data in roles:
		if role_data is not Dictionary:
			continue
		var role_id := str((role_data as Dictionary).get("id", ""))
		if role_id != "":
			state[role_id] = {}
	return state


static func build_empty_skill_state() -> Dictionary:
	return {}


static func normalize_role_state(value: Variant, roles: Array) -> Dictionary:
	var state := build_empty_role_state(roles)
	if value is Dictionary:
		for role_id_value in (value as Dictionary).keys():
			var role_id := str(role_id_value)
			if not state.has(role_id):
				state[role_id] = {}
			state[role_id] = _normalize_binding_levels((value as Dictionary).get(role_id_value, {}))
	return state


static func normalize_skill_state(value: Variant) -> Dictionary:
	return _normalize_binding_levels(value)


static func build_offer_for_owner(owner) -> Dictionary:
	var options := _pick_options(owner, OFFER_COUNT)
	if options.is_empty():
		options.append(_make_blank_option())
	var refresh_unlimited := DEVELOPER_MODE.should_allow_unlimited_upgrade_refresh()
	return {
		"options": options,
		"context": {
			"offer_mode": "blessing",
			"refresh_limit": OFFER_REFRESH_LIMIT,
			"refresh_remaining": OFFER_REFRESH_LIMIT,
			"refresh_unlimited": refresh_unlimited,
			"refresh_button_label": "刷新",
			"summary": "选择一个祝福或魔法石。"
		}
	}


static func build_all_offer_for_owner(owner) -> Dictionary:
	var options := _build_all_options(owner)
	if options.is_empty():
		options.append(_make_blank_option())
	return {
		"options": options,
		"context": {
			"offer_mode": "blessing",
			"refresh_limit": 0,
			"refresh_remaining": 0,
			"summary": "从当前可用祝福中选择。"
		}
	}


static func build_tier_offer_for_owner(owner, tier: int) -> Dictionary:
	var safe_tier: int = clamp(tier, 1, MAX_BLESSING_TIER)
	var options := _build_tier_options(owner, safe_tier)
	if options.is_empty():
		options.append(_make_blank_option())
	return {
		"options": options,
		"context": {
			"offer_mode": "blessing",
			"refresh_limit": 0,
			"refresh_remaining": 0,
			"summary": "从%s祝福中选择。" % _tier_label(safe_tier)
		}
	}


static func refresh_offer_for_owner(owner, current_offer: Dictionary) -> Dictionary:
	var offer := build_offer_for_owner(owner)
	var current_context: Dictionary = current_offer.get("context", {}) if current_offer.get("context", {}) is Dictionary else {}
	var next_context: Dictionary = offer.get("context", {}) if offer.get("context", {}) is Dictionary else {}
	var refresh_unlimited := bool(current_context.get("refresh_unlimited", false)) or DEVELOPER_MODE.should_allow_unlimited_upgrade_refresh()
	var refresh_limit: int = max(0, int(current_context.get("refresh_limit", next_context.get("refresh_limit", OFFER_REFRESH_LIMIT))))
	var refresh_remaining: int = max(0, int(current_context.get("refresh_remaining", refresh_limit)))
	if refresh_unlimited:
		refresh_remaining = max(1, refresh_remaining)
	else:
		refresh_remaining = max(0, refresh_remaining - 1)
	next_context["refresh_limit"] = refresh_limit
	next_context["refresh_remaining"] = refresh_remaining
	next_context["refresh_unlimited"] = refresh_unlimited
	offer["context"] = next_context
	return offer


static func apply_option(owner, option_id: String) -> bool:
	if option_id.begins_with(MAGIC_STONE_OPTION_PREFIX):
		return apply_magic_stone(owner, option_id.trim_prefix(MAGIC_STONE_OPTION_PREFIX))
	if option_id.begins_with(OPTION_PREFIX):
		var payload := option_id.trim_prefix(OPTION_PREFIX).split(":")
		if payload.size() < 2:
			return false
		return apply_blessing(owner, str(payload[0]), int(payload[1]))
	return false


static func apply_option_with_result(owner, option_id: String) -> Dictionary:
	if option_id.begins_with(MAGIC_STONE_OPTION_PREFIX):
		var stone_id := option_id.trim_prefix(MAGIC_STONE_OPTION_PREFIX)
		if not apply_magic_stone(owner, stone_id):
			return {}
		var definition: Dictionary = MAGIC_STONE_DEFINITIONS.get(stone_id, {})
		return {
			"type": CATEGORY_MAGIC_STONE,
			"magic_stone_id": stone_id,
			"title": str(definition.get("title", stone_id))
		}
	if not option_id.begins_with(OPTION_PREFIX):
		return {}
	var payload := option_id.trim_prefix(OPTION_PREFIX).split(":")
	if payload.size() < 2:
		return {}
	var blessing_id := str(payload[0])
	var tier: int = clamp(int(payload[1]), 1, MAX_BLESSING_TIER)
	if not apply_blessing(owner, blessing_id, tier, false):
		return {}
	var definition: Dictionary = DEFINITIONS.get(blessing_id, {})
	return {
		"type": str(definition.get("category", CATEGORY_GENERAL_BLESSING)),
		"blessing_id": blessing_id,
		"tier": tier,
		"binding": str(definition.get("binding", ROLE_BOUND)),
		"title": "%s%s" % [str(definition.get("title", blessing_id)), _tier_label(tier)]
	}


static func apply_blessing(owner, blessing_id: String, tier: int, refresh_unlocks: bool = true) -> bool:
	if owner == null or not DEFINITIONS.has(blessing_id):
		return false
	tier = clamp(tier, 1, MAX_BLESSING_TIER)
	var definition: Dictionary = DEFINITIONS.get(blessing_id, {})
	var tier_values: Dictionary = definition.get("tier_values", {})
	if not tier_values.has(tier):
		return false
	var binding := str(definition.get("binding", ROLE_BOUND))
	if binding == ROLE_BOUND:
		return _apply_role_blessing(owner, blessing_id, tier, definition, refresh_unlocks)
	return _apply_skill_blessing(owner, blessing_id, tier, definition, refresh_unlocks)


static func grant_random_blessings(owner, tier: int, count: int, rng: RandomNumberGenerator = null) -> Array[String]:
	var safe_tier: int = clamp(tier, 1, MAX_BLESSING_TIER)
	var pool: Array[String] = _get_offerable_blessing_ids_for_tier(owner, safe_tier)
	var granted: Array[String] = []
	if pool.is_empty() or count <= 0:
		return granted
	var roll_rng := rng
	if roll_rng == null:
		roll_rng = RandomNumberGenerator.new()
		roll_rng.randomize()
	for _index in range(count):
		if pool.is_empty():
			break
		var picked_index: int = roll_rng.randi_range(0, pool.size() - 1)
		var blessing_id: String = str(pool[picked_index])
		if apply_blessing(owner, blessing_id, safe_tier):
			granted.append(blessing_id)
		if _get_available_blessing_count(owner, blessing_id, safe_tier) >= _get_tier_limit(safe_tier):
			pool.remove_at(picked_index)
	return granted


static func get_role_stat_bonus(owner, _role_id: String, stat: String) -> float:
	var levels: Dictionary = _get_shared_role_levels(owner)
	return _sum_stat_bonus(levels, stat)


static func get_skill_stat_bonus(owner, stat: String) -> float:
	var levels: Dictionary = _get_skill_levels(owner)
	return _sum_stat_bonus(levels, stat)


static func get_skill_effect_scales(owner, stat: String) -> Array[float]:
	var levels: Dictionary = _get_skill_levels(owner)
	var scales: Array[float] = []
	for blessing_id in levels.keys():
		var definition: Dictionary = DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("binding", ROLE_BOUND)) != SKILL_BOUND:
			continue
		if str(definition.get("stat", "")) != stat:
			continue
		var tier_values: Dictionary = definition.get("tier_values", {})
		var blessing_levels: Dictionary = levels.get(blessing_id, {})
		for tier_value in blessing_levels.keys():
			var tier := int(tier_value)
			var count := int(blessing_levels.get(tier_value, 0))
			var scale := float(tier_values.get(tier, 0.0))
			for _index in range(max(0, count)):
				if scale > 0.0:
					scales.append(scale)
	return scales


static func get_blessing_level_summary(owner, role_id: String = "") -> Dictionary:
	var summary := {}
	if role_id != "":
		summary["role"] = _get_shared_role_levels(owner).duplicate(true)
	summary["skill"] = _get_skill_levels(owner).duplicate(true)
	return summary


static func can_compose_role_blessing(owner, _role_id: String, blessing_id: String) -> bool:
	var definition: Dictionary = DEFINITIONS.get(blessing_id, {})
	if str(definition.get("binding", ROLE_BOUND)) != ROLE_BOUND:
		return false
	return _can_compose_from_available(owner, blessing_id)


static func can_compose_skill_blessing(owner, blessing_id: String) -> bool:
	var definition: Dictionary = DEFINITIONS.get(blessing_id, {})
	if str(definition.get("binding", ROLE_BOUND)) != SKILL_BOUND:
		return false
	return _can_compose_from_available(owner, blessing_id)


static func compose_role_blessing(owner, role_id: String, blessing_id: String) -> bool:
	if not can_compose_role_blessing(owner, role_id, blessing_id):
		return false
	return _compose_blessing(owner, blessing_id, ROLE_BOUND)


static func compose_skill_blessing(owner, blessing_id: String) -> bool:
	if not can_compose_skill_blessing(owner, blessing_id):
		return false
	return _compose_blessing(owner, blessing_id, SKILL_BOUND)


static func get_greed_heal_amount(owner) -> float:
	return get_role_stat_bonus(owner, "", "greed_kill_heal")


static func get_greed_proc_chance(owner) -> float:
	var levels: Dictionary = _get_shared_role_levels(owner)
	var greed_levels: Dictionary = levels.get("greed", {})
	var count := 0
	for tier_value in greed_levels.keys():
		count += int(greed_levels.get(tier_value, 0))
	if count <= 0:
		return 0.0
	var definition: Dictionary = DEFINITIONS.get("greed", {})
	return float(definition.get("proc_chance", 0.0))


static func get_owned_magic_stones(owner) -> Array:
	var result: Array = [MAGIC_STONE_KINGDOM, MAGIC_STONE_KING]
	if owner == null:
		return result
	var stones: Variant = owner.get("owned_magic_stones")
	if stones is Array:
		for stone_value in stones:
			var stone_id := str(stone_value)
			if stone_id != "" and not result.has(stone_id):
				result.append(stone_id)
	return result


static func apply_magic_stone(owner, stone_id: String) -> bool:
	if owner == null or not MAGIC_STONE_DEFINITIONS.has(stone_id):
		return false
	var owned_stones: Array = get_owned_magic_stones(owner)
	if owned_stones.has(stone_id):
		return false
	if not owner.get("owned_magic_stones") is Array:
		owner.owned_magic_stones = []
	owner.owned_magic_stones.append(stone_id)
	for skill_id_value in MAGIC_STONE_UNLOCK_SKILLS.get(stone_id, []):
		PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(owner, str(skill_id_value), 1)
		_announce_magic_stone_skill_unlock(owner, str(skill_id_value))
	if owner.has_method("_spawn_combat_tag"):
		var definition: Dictionary = MAGIC_STONE_DEFINITIONS.get(stone_id, {})
		owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -72.0), "%s已获得" % str(definition.get("title", stone_id)), Color(0.72, 0.92, 1.0, 1.0))
	return true


static func _announce_magic_stone_skill_unlock(owner, skill_id: String) -> void:
	if owner == null:
		return
	if owner.has_method("_show_blessing_skill_event_tag"):
		owner._show_blessing_skill_event_tag({
			"skill_id": skill_id,
			"tier": 1,
			"title": PLAYER_BLESSING_SKILL_STATE.get_skill_title(skill_id),
			"consumes_blessing_material": false
		})


static func build_magic_stone_options(owner) -> Array:
	var options: Array = []
	var owned_stones: Array = get_owned_magic_stones(owner)
	var player_level := int(owner.get("level")) if owner != null else 1
	var weight := _get_offer_weight(player_level, 1)
	for stone_id_value in MAGIC_STONE_DEFINITIONS.keys():
		var stone_id := str(stone_id_value)
		if owned_stones.has(stone_id):
			continue
		for _index in range(weight):
			options.append(_make_magic_stone_option(owner, stone_id))
	return options


static func _make_magic_stone_option(owner, stone_id: String) -> Dictionary:
	var definition: Dictionary = MAGIC_STONE_DEFINITIONS.get(stone_id, {})
	var title: String = str(definition.get("title", stone_id))
	var fallback_summary: String = str(definition.get("summary", ""))
	var description: String = _get_magic_stone_description_for_owner(owner, definition, fallback_summary)
	var summary: String = description if description != "" else fallback_summary
	return {
		"id": "%s%s" % [MAGIC_STONE_OPTION_PREFIX, stone_id],
		"offer_key": "%s%s" % [MAGIC_STONE_OPTION_PREFIX, stone_id],
		"slot": "body",
		"slot_label": "魔法石",
		"title": title,
		"summary": summary,
		"short_description": summary,
		"description": description,
		"preview_description": description,
		"detail_description": description,
		"detail_bbcode": _escape_bbcode(description),
		"exact_description": description,
		"magic_stone_id": stone_id,
		"option_category": CATEGORY_MAGIC_STONE,
		"blessing_category": CATEGORY_MAGIC_STONE,
		"blessing_tier": 1,
		"tier_text_font_color": BLESSING_TEXT_COLOR,
		"tier_text_outline_size": 0,
		"tier_text_outline_color": Color(0.0, 0.0, 0.0, 0.0),
		"tier_description_color": BLESSING_TEXT_COLOR,
		"evolved": false
	}


static func _get_magic_stone_description_for_owner(owner, definition: Dictionary, fallback: String) -> String:
	var role_descriptions: Dictionary = definition.get("role_descriptions", {})
	var active_role_id: String = _get_owner_active_role_id(owner)
	if active_role_id != "" and role_descriptions.has(active_role_id):
		return str(role_descriptions.get(active_role_id, fallback))
	return str(definition.get("description", fallback))


static func _get_owner_active_role_id(owner) -> String:
	if owner == null:
		return ""
	if owner.has_method("_get_active_role"):
		var role_data: Dictionary = owner._get_active_role()
		return str(role_data.get("id", ""))
	return ""


static func build_magic_stone_blessing_options(owner) -> Array:
	var owned_stones := get_owned_magic_stones(owner)
	if owned_stones.is_empty():
		return []
	var options: Array = []
	var player_level := int(owner.get("level")) if owner != null else 1
	for blessing_id in DEFINITIONS.keys():
		var definition: Dictionary = DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("category", "")) != CATEGORY_MAGIC_STONE_BLESSING:
			continue
		if not _owns_magic_stone(owned_stones, str(definition.get("magic_stone", ""))):
			continue
		for tier in range(1, MAX_BLESSING_TIER + 1):
			if _is_offerable(owner, str(blessing_id), tier):
				var weight := _get_offer_weight(player_level, tier)
				for _index in range(weight):
					options.append(_make_option(owner, str(blessing_id), tier))
	return options


static func _pick_options(owner, count: int) -> Array:
	var candidate_options: Array = []
	candidate_options.append_array(_build_general_blessing_options(owner))
	candidate_options.append_array(build_magic_stone_options(owner))
	candidate_options.append_array(build_magic_stone_blessing_options(owner))
	candidate_options.shuffle()
	var picked: Array = []
	var used_keys := {}
	for option in candidate_options:
		if option is not Dictionary:
			continue
		var option_key := str((option as Dictionary).get("offer_key", (option as Dictionary).get("id", "")))
		if option_key == "" or used_keys.has(option_key):
			continue
		used_keys[option_key] = true
		picked.append(option)
		if picked.size() >= count:
			break
	_ensure_forced_tier_four_blessing(owner, picked, used_keys, count)
	return picked


static func _ensure_forced_tier_four_blessing(owner, picked: Array, used_keys: Dictionary, count: int) -> void:
	if not DEVELOPER_MODE.should_force_tier_four_blessing():
		return
	if count <= 0 or picked.is_empty():
		return
	for option in picked:
		if option is Dictionary and int((option as Dictionary).get("blessing_tier", 0)) == MAX_BLESSING_TIER:
			return
	var tier_four_options: Array = _build_offerable_options_for_tier(owner, MAX_BLESSING_TIER)
	tier_four_options.shuffle()
	for option in tier_four_options:
		if option is not Dictionary:
			continue
		var option_key: String = str((option as Dictionary).get("offer_key", (option as Dictionary).get("id", "")))
		if option_key == "" or used_keys.has(option_key):
			continue
		var replace_index: int = min(picked.size() - 1, max(0, count - 1))
		picked[replace_index] = option
		used_keys[option_key] = true
		return


static func _build_general_blessing_options(owner) -> Array:
	var options: Array = []
	var player_level := int(owner.get("level")) if owner != null else 1
	for blessing_id in DEFINITIONS.keys():
		var definition: Dictionary = DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("category", "")) != CATEGORY_GENERAL_BLESSING:
			continue
		for tier in range(1, MAX_BLESSING_TIER + 1):
			if _is_offerable(owner, str(blessing_id), tier):
				var weight := _get_offer_weight(player_level, tier)
				for _index in range(weight):
					options.append(_make_option(owner, str(blessing_id), tier))
	return options


static func _build_offerable_options_for_tier(owner, tier: int) -> Array:
	var options: Array = []
	for blessing_id in DEFINITIONS.keys():
		if _is_offerable(owner, str(blessing_id), tier):
			options.append(_make_option(owner, str(blessing_id), tier))
	return options


static func _build_all_options(owner) -> Array:
	var options: Array = []
	for blessing_id in DEFINITIONS.keys():
		var definition: Dictionary = DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("category", "")) != CATEGORY_GENERAL_BLESSING:
			continue
		for tier in range(1, MAX_BLESSING_TIER + 1):
			if _is_offerable(owner, str(blessing_id), tier):
				options.append(_make_option(owner, str(blessing_id), tier))
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_tier := int(a.get("blessing_tier", 1))
		var b_tier := int(b.get("blessing_tier", 1))
		if a_tier != b_tier:
			return a_tier < b_tier
		return str(a.get("title", "")) < str(b.get("title", ""))
	)
	return options


static func _build_tier_options(owner, tier: int) -> Array:
	var options: Array = []
	for blessing_id in _get_offerable_blessing_ids_for_tier(owner, tier):
		options.append(_make_option(owner, str(blessing_id), tier))
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("title", "")) < str(b.get("title", ""))
	)
	return options


static func _get_offerable_blessing_ids_for_tier(owner, tier: int) -> Array[String]:
	var result: Array[String] = []
	for blessing_id in DEFINITIONS.keys():
		var definition: Dictionary = DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("category", "")) != CATEGORY_GENERAL_BLESSING:
			continue
		if _is_offerable(owner, str(blessing_id), tier):
			result.append(str(blessing_id))
	return result


static func _get_offer_weight(player_level: int, tier: int) -> int:
	var tier_weights := _get_tier_weights_for_level(player_level)
	return int(tier_weights.get(clamp(tier, 1, MAX_BLESSING_TIER), 0))


static func _get_tier_weights_for_level(player_level: int) -> Dictionary:
	if player_level <= 6:
		return TIER_WEIGHT_LEVEL_1_TO_6
	if player_level <= 12:
		return TIER_WEIGHT_LEVEL_7_TO_12
	if player_level <= 18:
		return TIER_WEIGHT_LEVEL_13_TO_18
	return TIER_WEIGHT_LEVEL_19_PLUS


static func _is_offerable(owner, blessing_id: String, tier: int) -> bool:
	if not DEFINITIONS.has(blessing_id):
		return false
	if tier < 1 or tier > MAX_BLESSING_TIER:
		return false
	var definition: Dictionary = DEFINITIONS.get(blessing_id, {})
	if not bool(definition.get("offerable", true)):
		return false
	var category := str(definition.get("category", ""))
	if category != CATEGORY_GENERAL_BLESSING and category != CATEGORY_MAGIC_STONE_BLESSING:
		return false
	var tier_values: Dictionary = definition.get("tier_values", {})
	if not tier_values.has(tier):
		return false
	if category == CATEGORY_MAGIC_STONE_BLESSING and not _owner_has_magic_stone(owner, str(definition.get("magic_stone", ""))):
		return false
	return _get_available_blessing_count(owner, blessing_id, tier) < _get_tier_limit(tier)


static func _owner_has_magic_stone(owner, stone_id: String) -> bool:
	return _owns_magic_stone(get_owned_magic_stones(owner), stone_id)


static func _owns_magic_stone(owned_stones: Array, stone_id: String) -> bool:
	if stone_id == "":
		return false
	for stone_value in owned_stones:
		if str(stone_value) == stone_id:
			return true
	return false


static func _make_option(owner, blessing_id: String, tier: int) -> Dictionary:
	var definition: Dictionary = DEFINITIONS.get(blessing_id, {})
	var title_base := "%s%s" % [str(definition.get("title", blessing_id)), _tier_label(tier)]
	var effect_text := _get_option_tier_description(owner, definition, tier)
	var card_summary := _get_option_card_summary(owner, definition, tier)
	var title := title_base
	var tier_text_color: Color = BLESSING_TEXT_COLOR
	var description := effect_text
	return {
		"id": "%s%s:%d" % [OPTION_PREFIX, blessing_id, tier],
		"offer_key": blessing_id,
		"slot": "body",
		"slot_label": "祝福",
		"title": title,
		"summary": card_summary,
		"short_description": card_summary,
		"description": description,
		"preview_description": description,
		"detail_description": description,
		"detail_bbcode": _escape_bbcode(description),
		"exact_description": description,
		"blessing_id": blessing_id,
		"blessing_tier": tier,
		"blessing_binding": str(definition.get("binding", ROLE_BOUND)),
		"blessing_category": str(definition.get("category", CATEGORY_GENERAL_BLESSING)),
		"tier_text_font_color": tier_text_color,
		"tier_text_outline_size": 0,
		"tier_text_outline_color": Color(0.0, 0.0, 0.0, 0.0),
		"tier_description_color": tier_text_color,
		"evolved": tier >= 2
	}


static func _make_blank_option() -> Dictionary:
	return {
		"id": "blessing_blank_continue",
		"slot": "body",
		"slot_label": "祝福",
		"title": "暂无可选祝福",
		"summary": "当前可用祝福已达上限。",
		"short_description": "不获得祝福，继续战斗。",
		"description": "当前可用祝福已达上限，选择后继续战斗。",
		"preview_description": "不获得祝福，继续战斗。",
		"detail_description": "当前可用祝福已达上限，选择后继续战斗。",
		"exact_description": "这是防止菜单卡住的空选项。"
	}


static func _escape_bbcode(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")


static func _apply_role_blessing(owner, blessing_id: String, tier: int, definition: Dictionary, refresh_unlocks: bool = true) -> bool:
	var role_levels: Dictionary = _get_shared_role_levels(owner)
	var blessing_levels: Dictionary = (role_levels.get(blessing_id, {}) as Dictionary).duplicate(true)
	var previous_level := int(blessing_levels.get(tier, 0))
	if previous_level >= _get_tier_limit(tier):
		if owner.has_method("_spawn_combat_tag"):
			owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), "祝福已达上限", Color(0.92, 0.86, 0.54, 1.0))
		return true
	blessing_levels[tier] = previous_level + 1
	role_levels[blessing_id] = blessing_levels
	_set_shared_role_levels(owner, role_levels)
	_apply_role_stat_delta(owner, str(definition.get("stat", "")), float((definition.get("tier_values", {}) as Dictionary).get(tier, 0.0)))
	if owner.has_method("_spawn_combat_tag"):
		owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), "%s%s" % [str(definition.get("title", blessing_id)), _tier_label(tier)], Color(0.92, 0.86, 0.54, 1.0))
	if refresh_unlocks and owner.has_method("_refresh_blessing_skill_unlocks"):
		owner._refresh_blessing_skill_unlocks()
	return true


static func _apply_skill_blessing(owner, blessing_id: String, tier: int, definition: Dictionary, refresh_unlocks: bool = true) -> bool:
	owner.skill_blessing_levels = normalize_skill_state(owner.skill_blessing_levels)
	var skill_levels: Dictionary = _get_skill_levels(owner)
	var blessing_levels: Dictionary = (skill_levels.get(blessing_id, {}) as Dictionary).duplicate(true)
	var previous_level := int(blessing_levels.get(tier, 0))
	if previous_level >= _get_tier_limit(tier):
		if owner.has_method("_spawn_combat_tag"):
			owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), "祝福已达上限", Color(0.64, 0.90, 1.0, 1.0))
		return true
	blessing_levels[tier] = previous_level + 1
	skill_levels[blessing_id] = blessing_levels
	owner.skill_blessing_levels = skill_levels
	if owner.has_method("_spawn_combat_tag"):
		owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), "%s%s" % [str(definition.get("title", blessing_id)), _tier_label(tier)], Color(0.64, 0.90, 1.0, 1.0))
	if refresh_unlocks and owner.has_method("_refresh_blessing_skill_unlocks"):
		owner._refresh_blessing_skill_unlocks()
	return true


static func _apply_role_stat_delta(owner, stat: String, value: float) -> void:
	match stat:
		"max_health":
			var restored_role_health := false
			if owner.has_method("_add_all_role_current_health"):
				owner._add_all_role_current_health(value)
				restored_role_health = true
			if owner.has_method("_sync_active_role_max_health"):
				owner._sync_active_role_max_health(false, not restored_role_health)
			else:
				owner.max_health += value
				owner.current_health = min(owner.max_health, owner.current_health + value)
				owner.health_changed.emit(owner.current_health, owner.max_health)
		"switch_cooldown_reduction":
			owner.switch_cooldown_remaining = min(owner.switch_cooldown_remaining, max(0.0, owner.switch_cooldown_remaining * max(0.2, 1.0 - value)))
		_:
			pass
	if owner.has_method("_update_fire_timer"):
		owner._update_fire_timer()
	_emit_lightweight_stats_changed(owner)


static func apply_active_role_runtime_bonuses(owner) -> void:
	if owner == null or not owner.has_method("_get_active_role"):
		return
	var role_id := str(owner._get_active_role().get("id", ""))
	if role_id == "":
		return
	var cooldown_bonus := get_role_stat_bonus(owner, role_id, "cooldown_reduction")
	var range_bonus := get_role_stat_bonus(owner, role_id, "skill_range")
	var dodge_bonus := get_role_stat_bonus(owner, role_id, "dodge")
	var reduction_bonus := get_role_stat_bonus(owner, role_id, "damage_reduction")
	if cooldown_bonus > 0.0:
		owner.equipment_cooldown_multiplier = max(0.45, owner.equipment_cooldown_multiplier * max(0.2, 1.0 - cooldown_bonus))
	if range_bonus > 0.0:
		owner.equipment_skill_range_multiplier += range_bonus
	if dodge_bonus > 0.0:
		owner.equipment_dodge_chance = min(0.55, owner.equipment_dodge_chance + dodge_bonus)
	if reduction_bonus > 0.0:
		owner.damage_taken_multiplier = max(0.45, owner.damage_taken_multiplier * max(0.2, 1.0 - reduction_bonus))


static func _sum_stat_bonus(levels: Dictionary, stat: String) -> float:
	var additive_result := 0.0
	var survival_multiplier := 1.0
	var uses_nonlinear := false
	for blessing_id in levels.keys():
		var definition: Dictionary = DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("stat", "")) != stat:
			continue
		var tier_values: Dictionary = definition.get("tier_values", {})
		var blessing_levels: Dictionary = levels.get(blessing_id, {})
		for tier_value in blessing_levels.keys():
			var tier := int(tier_value)
			var count := int(blessing_levels.get(tier_value, 0))
			var value := float(tier_values.get(tier, 0.0))
			if bool(definition.get("nonlinear", false)):
				uses_nonlinear = true
				for _index in range(max(0, count)):
					survival_multiplier *= max(0.0, 1.0 - value)
			else:
				additive_result += value * float(count)
	if uses_nonlinear:
		return 1.0 - survival_multiplier
	return additive_result


static func _get_role_levels(owner, role_id: String) -> Dictionary:
	if owner == null or role_id == "":
		return {}
	if not owner.role_blessing_levels is Dictionary:
		owner.role_blessing_levels = {}
	if not owner.role_blessing_levels.has(role_id) or not owner.role_blessing_levels[role_id] is Dictionary:
		owner.role_blessing_levels[role_id] = {}
	return owner.role_blessing_levels[role_id]


static func sync_shared_role_blessings(owner) -> void:
	if owner == null:
		return
	_set_shared_role_levels(owner, _get_shared_role_levels(owner))


static func _get_shared_role_levels(owner) -> Dictionary:
	if owner == null:
		return {}
	owner.role_blessing_levels = normalize_role_state(owner.role_blessing_levels, owner.roles)
	var shared: Dictionary = {}
	for role_id_value in owner.role_blessing_levels.keys():
		var role_levels: Dictionary = owner.role_blessing_levels.get(role_id_value, {})
		for blessing_id_value in role_levels.keys():
			var blessing_id := str(blessing_id_value)
			var definition: Dictionary = DEFINITIONS.get(blessing_id, {})
			if str(definition.get("binding", ROLE_BOUND)) != ROLE_BOUND:
				continue
			var source_levels: Dictionary = role_levels.get(blessing_id_value, {})
			var merged_levels: Dictionary = (shared.get(blessing_id, {}) as Dictionary).duplicate(true)
			for tier_value in source_levels.keys():
				var tier := int(tier_value)
				var amount := int(source_levels.get(tier_value, 0))
				merged_levels[tier] = max(int(merged_levels.get(tier, 0)), amount)
			if not merged_levels.is_empty():
				shared[blessing_id] = merged_levels
	_set_shared_role_levels(owner, shared)
	return shared


static func _set_shared_role_levels(owner, shared_levels: Dictionary) -> void:
	if owner == null:
		return
	if not owner.role_blessing_levels is Dictionary:
		owner.role_blessing_levels = {}
	for role_data in owner.roles:
		if role_data is not Dictionary:
			continue
		var role_id := str((role_data as Dictionary).get("id", ""))
		if role_id == "":
			continue
		owner.role_blessing_levels[role_id] = shared_levels.duplicate(true)


static func _get_skill_levels(owner) -> Dictionary:
	if owner == null:
		return {}
	if not owner.skill_blessing_levels is Dictionary:
		owner.skill_blessing_levels = {}
	return owner.skill_blessing_levels


static func _normalize_binding_levels(value: Variant) -> Dictionary:
	var result := {}
	if value is not Dictionary:
		return result
	for blessing_id_value in (value as Dictionary).keys():
		var blessing_id := str(blessing_id_value)
		var raw_levels: Variant = (value as Dictionary).get(blessing_id_value, {})
		var levels := {}
		if raw_levels is Dictionary:
			for tier_value in (raw_levels as Dictionary).keys():
				var tier := int(tier_value)
				if tier < 1 or tier > MAX_BLESSING_TIER:
					continue
				var amount: int = max(0, int((raw_levels as Dictionary).get(tier_value, 0)))
				if amount > 0:
					levels[tier] = amount
		if not levels.is_empty():
			result[blessing_id] = levels
	return result


static func _can_compose_from_available(owner, blessing_id: String) -> bool:
	if not DEFINITIONS.has(blessing_id):
		return false
	return _get_available_blessing_count(owner, blessing_id, 1) >= MANUAL_COMPOSE_TIER_ONE_LEVEL and _get_available_blessing_count(owner, blessing_id, 2) < _get_tier_limit(2)


static func _compose_blessing(owner, blessing_id: String, binding: String) -> bool:
	var levels: Dictionary = _get_skill_levels(owner) if binding == SKILL_BOUND else _get_shared_role_levels(owner)
	var blessing_levels: Dictionary = (levels.get(blessing_id, {}) as Dictionary).duplicate(true)
	blessing_levels[1] = max(0, int(blessing_levels.get(1, 0)) - MANUAL_COMPOSE_TIER_ONE_LEVEL)
	blessing_levels[2] = int(blessing_levels.get(2, 0)) + 1
	levels[blessing_id] = blessing_levels
	if binding == SKILL_BOUND:
		owner.skill_blessing_levels = levels
	else:
		_set_shared_role_levels(owner, levels)
	if owner.has_method("_refresh_blessing_skill_unlocks"):
		owner._refresh_blessing_skill_unlocks()
	return true


static func _get_blessing_count(owner, blessing_id: String, tier: int) -> int:
	if owner == null or not DEFINITIONS.has(blessing_id):
		return 0
	var definition: Dictionary = DEFINITIONS.get(blessing_id, {})
	var binding := str(definition.get("binding", ROLE_BOUND))
	var levels := _get_skill_levels(owner) if binding == SKILL_BOUND else _get_shared_role_levels(owner)
	return int((levels.get(blessing_id, {}) as Dictionary).get(tier, 0))


static func _get_available_blessing_count(owner, blessing_id: String, tier: int) -> int:
	return _get_blessing_count(owner, blessing_id, tier)


static func _get_tier_limit(tier: int) -> int:
	return int(TIER_LIMITS.get(clamp(tier, 1, MAX_BLESSING_TIER), MAX_BLESSING_COUNT_PER_TIER))


static func _get_tier_description(definition: Dictionary, tier: int) -> String:
	var descriptions: Dictionary = definition.get("descriptions", {})
	if descriptions.has(tier):
		return str(descriptions.get(tier, ""))
	return _format_value(definition, tier)


static func _get_card_summary(definition: Dictionary, tier: int) -> String:
	var summaries: Dictionary = definition.get("card_summaries", {})
	if summaries.has(tier):
		return str(summaries.get(tier, ""))
	return _get_tier_description(definition, tier)


static func _get_option_tier_description(owner, definition: Dictionary, tier: int) -> String:
	var skill_title: String = _get_magic_stone_target_skill_title(owner, definition)
	if skill_title != "":
		return _format_magic_stone_skill_description(definition, tier, skill_title)
	return _get_tier_description(definition, tier)


static func _get_option_card_summary(owner, definition: Dictionary, tier: int) -> String:
	var skill_title: String = _get_magic_stone_target_skill_title(owner, definition)
	if skill_title != "":
		return _format_magic_stone_skill_summary(definition, tier, skill_title)
	return _get_card_summary(definition, tier)


static func _get_magic_stone_target_skill_title(owner, definition: Dictionary) -> String:
	if str(definition.get("category", "")) != CATEGORY_MAGIC_STONE_BLESSING:
		return ""
	var stone_id: String = str(definition.get("magic_stone", ""))
	var active_role_id: String = _get_owner_active_role_id(owner)
	var role_skills: Dictionary = MAGIC_STONE_ROLE_SKILLS.get(stone_id, {})
	var skill_id: String = str(role_skills.get(active_role_id, ""))
	if skill_id == "":
		return ""
	return PLAYER_BLESSING_SKILL_STATE.get_skill_title(skill_id)


static func _format_magic_stone_skill_description(definition: Dictionary, tier: int, skill_title: String) -> String:
	var stat := str(definition.get("stat", ""))
	var value := float((definition.get("tier_values", {}) as Dictionary).get(tier, 0.0))
	match stat:
		"basic_attack_cooldown_reduction", "kebiru_magic_cooldown_reduction":
			return "%s冷却减少%.0f%%" % [skill_title, value * 100.0]
		"basic_attack_quantity_skill_count":
			return "%s%.0f%%效果数量+1" % [skill_title, value * 100.0]
		"basic_attack_combo_skill_extra", "kebiru_magic_combo_skill_extra":
			return "%s%.0f%%效果+1" % [skill_title, value * 100.0]
		"ultimate_duration_seconds", "invoker_magic_duration_seconds":
			return "%s持续时间+%.1fs" % [skill_title, value]
		"ultimate_damage_multiplier_bonus":
			return "%s伤害倍率+%.0f" % [skill_title, value]
		"ultimate_special_effect_bonus":
			return "%s特殊效果提升%.0f%%" % [skill_title, value * 100.0]
		"kebiru_magic_range", "invoker_magic_range":
			return "%s范围增加%.0f%%" % [skill_title, value * 100.0]
	return _get_tier_description(definition, tier)


static func _format_magic_stone_skill_summary(definition: Dictionary, tier: int, skill_title: String) -> String:
	var stat := str(definition.get("stat", ""))
	var value := float((definition.get("tier_values", {}) as Dictionary).get(tier, 0.0))
	match stat:
		"basic_attack_cooldown_reduction", "kebiru_magic_cooldown_reduction":
			return "%sCD-%.0f%%" % [skill_title, value * 100.0]
		"basic_attack_quantity_skill_count":
			return "%s%.0f%%数量+1" % [skill_title, value * 100.0]
		"basic_attack_combo_skill_extra", "kebiru_magic_combo_skill_extra":
			return "%s%.0f%%+1" % [skill_title, value * 100.0]
		"ultimate_duration_seconds", "invoker_magic_duration_seconds":
			return "%s持续+%.1fs" % [skill_title, value]
		"ultimate_damage_multiplier_bonus":
			return "%s伤害倍率+%.0f" % [skill_title, value]
		"ultimate_special_effect_bonus":
			return "%s特殊+%.0f%%" % [skill_title, value * 100.0]
		"kebiru_magic_range", "invoker_magic_range":
			return "%s范围+%.0f%%" % [skill_title, value * 100.0]
	return _get_card_summary(definition, tier)


static func _format_value(definition: Dictionary, tier: int) -> String:
	var stat := str(definition.get("stat", ""))
	var value := float((definition.get("tier_values", {}) as Dictionary).get(tier, 0.0))
	match stat:
		"max_health":
			return "所有角色血量加%.0f" % value
		"energy_gain":
			return "终极技能回复效率增加%.0f%%" % (value * 100.0)
		"greed_kill_heal":
			return "击杀怪物有5%%几率回复%.0f点血量" % value
		"switch_cooldown_reduction":
			return "角色切换冷却减少%.0f%%" % (value * 100.0)
		"move_speed":
			return "所有角色移动速度+%.0f" % value
		"damage":
			return "所有角色造成伤害+%.0f" % value
		"dodge":
			return "所有角色闪避几率+%.0f%%" % (value * 100.0)
		"global_quantity_skill_count":
			return "所有数量类型技能100%%效果数量+%.0f" % value
		"global_combo_skill_extra":
			return "所有连段类技能100%%效果数量+%.0f" % value
		"global_duration_skill_seconds":
			return "所有持续类技能持续时间+%.0fs" % value
		"ultimate_duration_seconds":
			return "终极技能持续时间+%.1fs" % value
		"ultimate_damage_multiplier_bonus":
			return "终极技能伤害倍率+%.0f" % value
		"ultimate_special_effect_bonus":
			return "终极技能特殊效果提升%.0f%%" % (value * 100.0)
		"combo_skill_extra":
			return "技能连段+1"
		"duration_skill_duration":
			return "持续类技能持续时间增加%.0f%%" % (value * 100.0)
		"quantity_skill_count":
			return "数量类技能数量增加"
	return str(value)


static func _tier_label(tier: int) -> String:
	match clamp(tier, 1, MAX_BLESSING_TIER):
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		_:
			return "IV"


static func _emit_lightweight_stats_changed(owner) -> void:
	if owner == null:
		return
	if owner.has_method("emit_frame_stats_changed"):
		owner.emit_frame_stats_changed()
	elif owner.get("stats_changed") != null:
		owner.stats_changed.emit(owner.get_stat_summary())

extends RefCounted

const PREP_SCENE_PATH := "res://scenes/story_prep.tscn"
const BATTLE_SCENE_PATH := "res://scenes/main.tscn"
const SAVE_SELECT_SCENE_PATH := "res://scenes/save_select.tscn"

const ROLE_POOL := [
	{"id": "swordsman", "name": "剑士", "available": true},
	{"id": "gunner", "name": "枪手", "available": true},
	{"id": "mage", "name": "术师", "available": true},
	{"id": "reserved_4", "name": "角色4", "available": false},
	{"id": "reserved_5", "name": "角色5", "available": false}
]

const STORY_STAGES := [
	{
		"id": "chapter1_stage1",
		"chapter": 1,
		"title": "第一章·前哨清剿",
		"description": "标准战斗关。撑过 180 秒即可过关。",
		"type": "normal",
		"target_time": 180.0,
		"boss_spawn_time": 9999.0,
		"spawn_interval_multiplier": 1.0,
		"enemy_health_multiplier": 1.0,
		"enemy_speed_multiplier": 1.0
	},
	{
		"id": "chapter1_stage2",
		"chapter": 1,
		"title": "第一章·裂隙推进",
		"description": "高压普通关。撑过 210 秒即可过关。",
		"type": "normal",
		"target_time": 210.0,
		"boss_spawn_time": 9999.0,
		"spawn_interval_multiplier": 0.9,
		"enemy_health_multiplier": 1.1,
		"enemy_speed_multiplier": 1.08
	},
	{
		"id": "chapter1_stage3",
		"chapter": 1,
		"title": "第一章·星核讨伐",
		"description": "Boss关。135 秒后Boss登场，击败后获得 1 枚Boss核心。",
		"type": "boss",
		"target_time": 300.0,
		"boss_spawn_time": 135.0,
		"spawn_interval_multiplier": 0.92,
		"enemy_health_multiplier": 1.14,
		"enemy_speed_multiplier": 1.1,
		"boss_material_reward": 1
	}
]

const ROLE_STYLES := {
	"swordsman": {
		"default": {
			"id": "default",
			"name": "默认",
			"short_description": "维持当前剑士表现。"
		},
		"moon_edge": {
			"id": "moon_edge",
			"name": "月锋",
			"short_description": "斩击范围更大，伤害略低。"
		}
	},
	"gunner": {
		"default": {
			"id": "default",
			"name": "默认",
			"short_description": "维持当前枪手表现。"
		},
		"star_pierce": {
			"id": "star_pierce",
			"name": "穿星",
			"short_description": "子弹更快并追加穿透，伤害略低。"
		}
	},
	"mage": {
		"default": {
			"id": "default",
			"name": "默认",
			"short_description": "维持当前术师表现。"
		},
		"frostfield": {
			"id": "frostfield",
			"name": "霜环",
			"short_description": "轰炸范围更大且减速更强，节奏略慢。"
		}
	}
}

static func build_default_story_profile(slot_id: int) -> Dictionary:
	return {
		"slot_id": slot_id,
		"chapter_index": 1,
		"current_stage_index": 0,
		"boss_core_fragments": 0,
		"unlocked_role_ids": ["swordsman", "gunner", "mage"],
		"team_order": ["swordsman", "gunner", "mage"],
		"unlocked_styles": {
			"swordsman": [],
			"gunner": [],
			"mage": []
		},
		"equipped_styles": {
			"swordsman": "default",
			"gunner": "default",
			"mage": "default"
		},
		"created_unix": Time.get_unix_time_from_system(),
		"last_updated_unix": Time.get_unix_time_from_system()
	}

static func get_stage(stage_index: int) -> Dictionary:
	if stage_index < 0 or stage_index >= STORY_STAGES.size():
		return {}
	return STORY_STAGES[stage_index].duplicate(true)

static func get_stage_count() -> int:
	return STORY_STAGES.size()

static func get_role_style(role_id: String, style_id: String) -> Dictionary:
	var role_styles: Dictionary = ROLE_STYLES.get(role_id, {})
	return role_styles.get(style_id, role_styles.get("default", {})).duplicate(true)

static func get_unlock_style_id(role_id: String) -> String:
	match role_id:
		"swordsman":
			return "moon_edge"
		"gunner":
			return "star_pierce"
		"mage":
			return "frostfield"
	return "default"

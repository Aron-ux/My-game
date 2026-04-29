extends RefCounted

const SLOT_LABELS := {
	"body": "\u6218\u6597",
	"combat": "\u8FDE\u643A",
	"skill": "\u5927\u62DB",
	"special": "\u5956\u52B1"
}

const CORE_CARD_ORDER := [
	"battle_dangzhen_qichao",
	"battle_dangzhen_dielang",
	"battle_dangzhen_huichao"
]

const EVOLUTION_CARD_ORDER := [
	"battle_blade_storm_fury",
	"battle_blade_storm_eye",
	"battle_blade_storm_multi",
	"battle_infinite_reload_overload",
	"battle_infinite_reload_chain",
	"battle_infinite_reload_bore",
	"battle_tidal_surge_pressure",
	"battle_tidal_surge_echo",
	"battle_tidal_surge_widen"
]

const EVOLUTION_REWARD_CARD_IDS := {
	"small_boss_dangzhen_blade_storm": [
		"battle_blade_storm_fury",
		"battle_blade_storm_eye",
		"battle_blade_storm_multi"
	],
	"small_boss_dangzhen_infinite_reload": [
		"battle_infinite_reload_overload",
		"battle_infinite_reload_chain",
		"battle_infinite_reload_bore"
	],
	"small_boss_dangzhen_tidal_surge": [
		"battle_tidal_surge_pressure",
		"battle_tidal_surge_echo",
		"battle_tidal_surge_widen"
	]
}

const ROLE_EVOLUTION_REWARD_IDS := {
	"swordsman": "small_boss_dangzhen_blade_storm",
	"gunner": "small_boss_dangzhen_infinite_reload",
	"mage": "small_boss_dangzhen_tidal_surge"
}

const CORE_CARDS := {
	"battle_dangzhen_qichao": {
		"title": "\u8D77\u6F6E",
		"slot": "body",
		"max_level": 3,
		"set_key": "battle_dangzhen",
		"preview": "\u83B7\u5F97\u8361\u9635\u989D\u5916\u653B\u51FB\u624B\u6BB5\u3002",
		"detail": "\u8361\u9635\u8D77\u624B\u5361\u3002\u5251\u58EB\u8FFD\u52A0\u6708\u7259\u65A9\uFF0C\u67AA\u624B\u8FFD\u52A0\u8D2F\u7A7F\u5F39\uFF0C\u672F\u5E08\u8FFD\u52A0\u51B2\u51FB\u6CE2\u3002",
		"detail_lines": [
			"\u5251\u58EB\uFF1A\u8FFD\u52A0\u6708\u7259\u65A9\uFF0C\u4F5C\u4E3A\u72EC\u7ACB\u7684\u989D\u5916\u4F24\u5BB3\u6BB5\u3002",
			"\u67AA\u624B\uFF1A\u8FFD\u52A0\u8D2F\u7A7F\u5F39\uFF0C\u5411\u524D\u65B9\u8D2F\u7A7F\u6253\u51FB\u3002",
			"\u672F\u5E08\uFF1A\u805A\u80FD\u540E\u8FFD\u52A0\u51B2\u51FB\u6CE2\u3002",
			"\u53E0\u6D6A\u4E0E\u56DE\u6F6E\u9700\u8981\u5148\u62FF\u5230\u8D77\u6F6E\u624D\u4F1A\u8FDB\u5165\u5361\u6C60\u3002"
		]
	},
	"battle_dangzhen_dielang": {
		"title": "\u53E0\u6D6A",
		"slot": "body",
		"max_level": 3,
		"set_key": "battle_dangzhen",
		"requires": ["battle_dangzhen_qichao"],
		"preview": "\u8361\u9635\u653B\u51FB\u7ED3\u675F\u540E\u8FFD\u52A0\u8865\u53D1\u3002",
		"detail": "\u8361\u9635\u8FFD\u51FB\u5361\u3002\u6BCF\u6B21\u7279\u6548\u4E0E\u5224\u5B9A\u7ED3\u675F\u540E\uFF0C\u7ACB\u523B\u8865\u53D1\u4E0B\u4E00\u6BB5\u540C\u65B9\u5411\u653B\u51FB\u3002",
		"detail_lines": [
			"\u5251\u58EB\uFF1A\u5F53\u524D\u6708\u7259\u65A9\u7ED3\u675F\u540E\uFF0C\u7EE7\u7EED\u8865\u53D1\u540C\u65B9\u5411\u6708\u7259\u65A9\u3002",
			"\u67AA\u624B\uFF1A\u5F53\u524D\u8D2F\u7A7F\u5F39\u7ED3\u675F\u540E\uFF0C\u7EE7\u7EED\u8865\u53D1\u540C\u65B9\u5411\u8D2F\u7A7F\u5F39\u3002",
			"\u672F\u5E08\uFF1A\u7B2C\u4E00\u9053\u51B2\u51FB\u6CE2\u540E\uFF0C\u7EE7\u7EED\u8865\u53D1\u540C\u65B9\u5411\u540E\u7EED\u6CE2\u3002",
			"\u7B49\u7EA7\u8D8A\u9AD8\uFF0C\u8FDE\u7EED\u8865\u53D1\u7684\u6BB5\u6570\u8D8A\u591A\u3002"
		]
	},
	"battle_dangzhen_huichao": {
		"title": "\u56DE\u6F6E",
		"slot": "body",
		"max_level": 3,
		"set_key": "battle_dangzhen",
		"requires": ["battle_dangzhen_qichao"],
		"preview": "\u6539\u53D8\u8361\u9635\u653B\u51FB\u7684\u65B9\u5411\u6216\u8DDD\u79BB\u3002",
		"detail": "\u8361\u9635\u53D8\u5316\u5361\u3002\u5251\u58EB\u6269\u6210\u591A\u65B9\u5411\u65A9\u51FB\uFF0C\u67AA\u624B\u5F3A\u5316\u8D2F\u7A7F\u8DDD\u79BB\uFF0C\u672F\u5E08\u6269\u6210\u5939\u89D2\u51B2\u51FB\u6CE2\u3002",
		"detail_lines": [
			"\u5251\u58EB\uFF1A\u8FFD\u52A0\u65A9\u51FB\u4F1A\u5411\u53CD\u65B9\u5411\u6216\u591A\u65B9\u5411\u6269\u5C55\u3002",
			"\u67AA\u624B\uFF1A\u8D2F\u7A7F\u5F39\u5C04\u7A0B\u63D0\u9AD8\uFF0C\u5E76\u7EE7\u627F\u53E0\u6D6A\u8865\u53D1\u3002",
			"\u672F\u5E08\uFF1A\u51B2\u51FB\u6CE2\u6269\u6210\u5939\u89D2\u53D1\u5C04\uFF0C\u5E76\u7EE7\u627F\u53E0\u6D6A\u8865\u53D1\u3002",
			"\u8FD9\u5F20\u5361\u4E3B\u8981\u6269\u5927\u8986\u76D6\u9762\uFF0C\u4E0D\u6539\u53D8\u8361\u9635\u7684\u57FA\u7840\u89E6\u53D1\u6761\u4EF6\u3002"
		]
	}
}

const EVOLUTION_CARDS := {
	"battle_blade_storm_fury": {
		"title": "\u98CE\u66B4\u4E4B\u6012",
		"slot": "body",
		"max_level": 3,
		"preview": "\u5251\u5203\u98CE\u66B4\u4F24\u5BB3\u63D0\u5347\u3002",
		"detail": "\u5251\u5203\u98CE\u66B4\u8FDB\u9636\u5361\u3002\u57FA\u7840\u6BCF\u6B21\u51FA\u4F24\u4E3A\u5251\u58EB\u4F24\u5BB3\u7684 72%\uFF0C\u6BCF\u7EA7\u989D\u5916 +18%\u3002"
	},
	"battle_blade_storm_eye": {
		"title": "\u98CE\u66B4\u773C",
		"slot": "body",
		"max_level": 3,
		"preview": "\u5251\u5203\u98CE\u66B4\u6301\u7EED\u65F6\u95F4\u4E0E\u8303\u56F4\u63D0\u5347\u3002",
		"detail": "\u5251\u5203\u98CE\u66B4\u8FDB\u9636\u5361\u3002\u57FA\u7840\u6301\u7EED 1.6 \u79D2\uFF0C\u6BCF\u7EA7\u6301\u7EED +0.24 \u79D2\uFF0C\u534A\u5F84 +10%\u3002"
	},
	"battle_blade_storm_multi": {
		"title": "\u591A\u91CD\u66B4\u98CE",
		"slot": "body",
		"max_level": 3,
		"preview": "\u5251\u5203\u98CE\u66B4\u8FFD\u52A0\u73AF\u7ED5\u81EA\u8EAB\u7684\u65CB\u8F6C\u98CE\u66B4\u3002",
		"detail": "\u5251\u5203\u98CE\u66B4\u8FDB\u9636\u5361\u3002\u6BCF\u7EA7\u589E\u52A0 1 \u4E2A\u56F4\u7ED5\u89D2\u8272\u987A\u65F6\u9488\u65CB\u8F6C\u7684\u5251\u5203\u98CE\u66B4\uFF0C\u989D\u5916\u98CE\u66B4\u79BB\u89D2\u8272\u66F4\u8FDC\u3002"
	},
	"battle_infinite_reload_overload": {
		"title": "\u88C5\u586B\u8FC7\u8F7D",
		"slot": "body",
		"max_level": 3,
		"preview": "\u65E0\u9650\u88C5\u586B\u4F24\u5BB3\u63D0\u5347\u3002",
		"detail": "\u65E0\u9650\u88C5\u586B\u8FDB\u9636\u5361\u3002\u57FA\u7840\u6BCF\u6B21\u51FA\u4F24\u4E3A\u67AA\u624B\u4F24\u5BB3\u7684 52%\uFF0C\u6BCF\u7EA7\u989D\u5916 +12%\u3002"
	},
	"battle_infinite_reload_chain": {
		"title": "\u5EF6\u5C55\u5F39\u94FE",
		"slot": "body",
		"max_level": 3,
		"preview": "\u65E0\u9650\u88C5\u586B\u8DDD\u79BB\u4E0E\u6301\u7EED\u65F6\u95F4\u63D0\u5347\u3002",
		"detail": "\u65E0\u9650\u88C5\u586B\u8FDB\u9636\u5361\u3002\u57FA\u7840\u6301\u7EED 1 \u79D2\uFF0C\u6BCF\u7EA7\u6301\u7EED +0.67 \u79D2\uFF0C\u5C04\u7A0B +42%\uFF1B\u6EE1\u7EA7\u7EA6 3.01 \u79D2\u3002"
	},
	"battle_infinite_reload_bore": {
		"title": "\u5BBD\u819B\u9F50\u5C04",
		"slot": "body",
		"max_level": 3,
		"preview": "\u65E0\u9650\u88C5\u586B\u77E9\u5F62\u5224\u5B9A\u5BBD\u5EA6\u63D0\u5347\u3002",
		"detail": "\u65E0\u9650\u88C5\u586B\u8FDB\u9636\u5361\u3002\u6BCF\u7EA7\u524D\u65B9\u9690\u85CF\u77E9\u5F62\u5224\u5B9A\u5BBD\u5EA6 +36%\uFF0C\u4E14\u77E9\u5F62\u5185\u6C34\u5E73\u5206\u5E03\u7684\u89C6\u89C9\u6F14\u51FA\u589E\u52A0\u3002"
	},
	"battle_tidal_surge_pressure": {
		"title": "\u6D8C\u6F6E\u538B\u5F3A",
		"slot": "body",
		"max_level": 3,
		"preview": "\u6CE2\u6D9B\u6D8C\u52A8\u4F24\u5BB3\u63D0\u5347\u3002",
		"detail": "\u6CE2\u6D9B\u6D8C\u52A8\u8FDB\u9636\u5361\u3002\u57FA\u7840\u6BCF\u9053\u51B2\u51FB\u6CE2\u4E3A\u672F\u5E08\u4F24\u5BB3\u7684 62%\uFF0C\u6BCF\u7EA7\u989D\u5916 +14%\u3002"
	},
	"battle_tidal_surge_echo": {
		"title": "\u8FDE\u6F6E\u56DE\u54CD",
		"slot": "body",
		"max_level": 3,
		"preview": "\u6CE2\u6D9B\u6D8C\u52A8\u6BCF\u4E2A\u65B9\u5411\u8FFD\u52A0\u51B2\u51FB\u6CE2\u3002",
		"detail": "\u6CE2\u6D9B\u6D8C\u52A8\u8FDB\u9636\u5361\u3002\u6BCF\u7EA7\u8BA9\u6BCF\u4E2A\u65B9\u5411\u591A\u91CA\u653E 1 \u9053\u51B2\u51FB\u6CE2\uFF0C\u6BCF\u9053\u95F4\u9694 0.3 \u79D2\u3002"
	},
	"battle_tidal_surge_widen": {
		"title": "\u9614\u6F9C\u5916\u6CBF",
		"slot": "body",
		"max_level": 3,
		"preview": "\u6CE2\u6D9B\u6D8C\u52A8\u51B2\u51FB\u8303\u56F4\u62D3\u5BBD\u3002",
		"detail": "\u6CE2\u6D9B\u6D8C\u52A8\u8FDB\u9636\u5361\u3002\u6BCF\u7EA7\u51B2\u51FB\u6CE2\u5BBD\u5EA6\u4E0E\u89C6\u89C9\u5C3A\u5BF8 +12%\uFF0C\u6EE1\u7EA7\u4E3A\u57FA\u7840\u7684 1.36x\u3002"
	}
}

const FINAL_SETS := {
	"battle_dangzhen": {
		"main_name": "\u8361\u9635",
		"full_title": "\u8361\u9635\uFF1A\u6F6E\u950B\u8FDE\u5377",
		"requirements": [
			{"card_id": "battle_dangzhen_qichao", "label": "\u8D77\u6F6E", "max_level": 3},
			{"card_id": "battle_dangzhen_dielang", "label": "\u53E0\u6D6A", "max_level": 3},
			{"card_id": "battle_dangzhen_huichao", "label": "\u56DE\u6F6E", "max_level": 3}
		]
	}
}

const SMALL_BOSS_REWARDS := {
	"small_boss_dangzhen_qichao": {
		"title": "\u8361\u9635\u8865\u5F3A\u00B7\u8D77\u6F6E",
		"description": "\u8361\u9635\u7684\u8D77\u6F6E\u7B49\u7EA7 +1\uFF0C\u4F18\u5148\u628A\u989D\u5916\u653B\u51FB\u624B\u6BB5\u8865\u51FA\u6765\u3002"
	},
	"small_boss_dangzhen_dielang": {
		"title": "\u8361\u9635\u8865\u5F3A\u00B7\u53E0\u6D6A",
		"description": "\u8361\u9635\u7684\u53E0\u6D6A\u7B49\u7EA7 +1\uFF0C\u8FFD\u52A0\u8FDE\u7EED\u8865\u53D1\u6B21\u6570\u3002"
	},
	"small_boss_dangzhen_huichao": {
		"title": "\u8361\u9635\u8865\u5F3A\u00B7\u56DE\u6F6E",
		"description": "\u8361\u9635\u7684\u56DE\u6F6E\u7B49\u7EA7 +1\uFF0C\u8FFD\u52A0\u65B9\u5411\u53D8\u5316\u4E0E\u8986\u76D6\u8303\u56F4\u3002"
	},
	"small_boss_dangzhen_blade_storm": {
		"title": "\u5251\u5203\u98CE\u66B4",
		"description": "荡阵进化共享解锁。剑士站场时显示为剑刃风暴：6 秒 CD，持续 1.6 秒，每 0.2 秒出伤；获得后枪手与术师的荡阵进化也同步解锁，后续普通 Build 按当前站场职业换皮显示但等级共享。"
	},
	"small_boss_dangzhen_infinite_reload": {
		"title": "\u65E0\u9650\u88C5\u586B",
		"description": "荡阵进化共享解锁。枪手站场时显示为无限装填：6 秒 CD，基础持续 1 秒，每 0.1 秒在前方矩形区域出伤并播放贯穿特效；获得后剑士与术师的荡阵进化也同步解锁，后续普通 Build 按当前站场职业换皮显示但等级共享。"
	},
	"small_boss_dangzhen_tidal_surge": {
		"title": "\u6CE2\u6D9B\u6D8C\u52A8",
		"description": "荡阵进化共享解锁。术师站场时显示为波涛涌动：11 秒 CD，先上下左右，0.3 秒后再向四个斜向释放冲击波；获得后剑士与枪手的荡阵进化也同步解锁，后续普通 Build 按当前站场职业换皮显示但等级共享。"
	}
}

static func get_slot_label(slot_id: String) -> String:
	return str(SLOT_LABELS.get(slot_id, "\u6784\u7B51"))

static func get_core_card(card_id: String) -> Dictionary:
	if CORE_CARDS.has(card_id):
		return CORE_CARDS.get(card_id, {}).duplicate(true)
	return EVOLUTION_CARDS.get(card_id, {}).duplicate(true)

static func get_core_card_ids_for_slot(slot_id: String) -> Array:
	var result: Array = []
	for card_id in CORE_CARD_ORDER:
		var config: Dictionary = CORE_CARDS[card_id]
		if str(config.get("slot", "")) == slot_id:
			result.append(card_id)
	return result

static func get_evolution_card_ids_for_reward(reward_id: String) -> Array:
	return EVOLUTION_REWARD_CARD_IDS.get(reward_id, []).duplicate()

static func get_evolution_reward_id_for_role(role_id: String) -> String:
	return str(ROLE_EVOLUTION_REWARD_IDS.get(role_id, ""))

static func get_final_set_data(set_key: String) -> Dictionary:
	return FINAL_SETS.get(set_key, {}).duplicate(true)

static func get_small_boss_reward(reward_id: String) -> Dictionary:
	return SMALL_BOSS_REWARDS.get(reward_id, {}).duplicate(true)

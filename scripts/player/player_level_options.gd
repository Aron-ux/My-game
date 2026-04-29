extends RefCounted

static func build_attribute_upgrade_options(
	title_map: Dictionary,
	vitality_next_level: int,
	agility_next_level: int,
	_power_next_level: int,
	vitality_description: String,
	agility_description: String,
	_power_step: float,
	vitality_evolved: bool = false,
	agility_evolved: bool = false,
	_power_evolved: bool = false,
	evolved_color: Color = Color(0.38, 1.0, 0.48, 1.0)
) -> Array:
	return [
		{
			"id": "level_stat_vitality",
			"title": "%s Lv.%d" % [str(title_map.get("vitality", "生命训练")), vitality_next_level],
			"description": vitality_description,
			"evolved": vitality_evolved,
			"title_color": evolved_color
		},
		{
			"id": "level_stat_agility",
			"title": "%s Lv.%d" % [str(title_map.get("agility", "机动训练")), agility_next_level],
			"description": agility_description,
			"evolved": agility_evolved,
			"title_color": evolved_color
		}
	]

static func get_final_core_options() -> Array:
	return [
		{
			"id": "final_blank_upgrade",
			"title": "结束本局",
			"description": "最终 Boss 已击败。确认后进入胜利结算。",
			"preview_description": "确认胜利并完成本局。",
			"exact_description": "这是结算确认选项，不提供额外战斗加成。"
		}
	]

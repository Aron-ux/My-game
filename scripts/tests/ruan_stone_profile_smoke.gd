extends SceneTree

const PROFILE_DEFAULTS := preload("res://scripts/save/save_profile_defaults.gd")
const RUAN_STONES := preload("res://scripts/player/ruan_stone_system.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := PROFILE_DEFAULTS.ensure_endless_profile_defaults({
		"difficulty": "normal",
		"legacy_field": "kept",
		"bones": -4,
		"ruan_stone_levels": {"thunder": 2, "frost": -3, "unknown": 99},
		"equipped_ruan_stone": "frost"
	}, 2)
	_expect(profile.get("legacy_field") == "kept", "旧档案字段未保留。")
	_expect(not profile.has("difficulty"), "旧四难度字段仍被保留。")
	_expect(profile.get("highest_cleared_tier") == 0 and profile.get("selected_tier") == 1, "N 层进度默认值错误。")
	_expect(profile.get("bones") == 0, "骨头数量未归一化。")
	_expect(profile.get("equipped_ruan_stone") == "", "未拥有的石头仍被装备。")
	var levels: Dictionary = profile.get("ruan_stone_levels", {})
	_expect(levels.size() == 5 and levels.get("thunder") == 2 and levels.get("frost") == 0, "石头等级默认值或迁移错误。")
	_expect(RUAN_STONES.get_next_cost(profile, "thunder") == 11, "升级费用公式错误。")
	profile["bones"] = 10
	var denied := RUAN_STONES.purchase(profile, "thunder")
	_expect(not bool(denied.get("success", false)) and profile.get("bones") == 10, "骨头不足时仍完成了购买。")
	profile["bones"] = 11
	var purchased := RUAN_STONES.purchase(profile, "thunder")
	_expect(bool(purchased.get("success", false)) and RUAN_STONES.get_level(profile, "thunder") == 3, "购买未提升石头等级。")
	_expect(profile.get("bones") == 0 and RUAN_STONES.equip(profile, "thunder"), "购买未扣费或拥有后无法装备。")
	_expect(not RUAN_STONES.equip(profile, "poison") and RUAN_STONES.get_equipped(profile) == "thunder", "未拥有石头可装备或失败装备覆盖当前选择。")
	_expect(RUAN_STONES.get_effect_values("thunder", 5).get("jump_count") == 2, "雷石五级未增加连锁目标。")
	_expect(is_equal_approx(float(RUAN_STONES.get_effect_values("frost", 100).get("slow_ratio")), 0.75), "冰石减速未正确封顶。")
	_expect(is_equal_approx(float(RUAN_STONES.get_effect_values("flame", 18).get("damage_ratio")), 0.165), "炎石死亡爆炸成长错误。")
	_expect(RUAN_STONES.get_effect_text("flame", 1).contains("最大生命8%"), "炎石效果文本错误。")
	_expect(RUAN_STONES.get_effect_text("fury", 1).contains("6%"), "烈石效果文本错误。")
	if failures.is_empty():
		print("RUAN_STONE_PROFILE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

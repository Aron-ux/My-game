extends RefCounted

const ROLE_DATABASE := preload("res://scripts/player/roles/role_database.gd")
const ROLE_DESCRIPTIONS := {
	"swordsman": "近身斩击与持续生存。战意提供回复，骑士荣耀在濒死时保护自身；适合贴近敌群，用切人和技能衔接维持压制。",
	"gunner": "中远距离点杀与弹幕覆盖。瞬杀与猎杀分别积累输出收益；适合保持距离，利用登场弹幕与多种弹药处理敌群。",
	"mage": "范围轰炸与区域控制。奥术充能强化技能循环；雷击、火焰与领域适合覆盖敌群，为队友创造走位空间。",
	"mechanic": "生产零件并部署机械。蜘蛛追击目标，机炮、地雷、力场、守卫与重炮在切人后继续工作；零件强化装置及大招。八条技能线在 5/10 级获得专属天赋，可组成蜂群、随行维修与集束高爆火力。"
}

static func get_role_name(role_id: String) -> String:
	for role in ROLE_DATABASE.ROLE_DATA:
		if str(role["id"]) == role_id:
			return str(role["name"])
	return "角色"

static func get_role_theme_color(roles: Array, role_id: String) -> Color:
	for role_data in roles:
		if str(role_data.get("id", "")) == role_id:
			return role_data.get("color", Color.WHITE)
	return Color.WHITE

static func get_role_detail_summary(role_id: String, _special_data: Dictionary) -> String:
	return str({"swordsman": "近战压制", "gunner": "远程点杀", "mage": "范围控制", "mechanic": "部署火力"}.get(role_id, ""))

static func get_role_route_summary(role_id: String, _special_data: Dictionary) -> String:
	return str({"swordsman": "斩击与生存", "gunner": "射击与弹幕", "mage": "法术与领域", "mechanic": "零件与装置"}.get(role_id, ""))

static func get_role_core_summary(role_id: String) -> String:
	return str({"swordsman": "战意与骑士荣耀", "gunner": "瞬杀与猎杀", "mage": "奥术充能", "mechanic": "战场改装"}.get(role_id, ""))

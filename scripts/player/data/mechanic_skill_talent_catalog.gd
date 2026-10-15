extends RefCounted

const PART_INTERVAL_MULTIPLIER := 0.5
const PART_CAP_BONUS := 8
const PART_DAMAGE_BONUS := 0.04
const ENTRY_DURATION_BONUS := 4.0
const ENTRY_FIRE_INTERVAL_MULTIPLIER := 0.5
const SPIDER_COUNT := 3
const SPIDER_PIERCE_BONUS := 3
const SPIDER_SPEED_MULTIPLIER := 2.0
const GUARD_DEPLOY_COUNT := 2
const GUARD_CAP_BONUS := 3
const GUARD_HEAL_RATIO := 0.06
const MINE_COUNT_BONUS := 4
const MINE_DEPLOY_RADIUS := 96.0
const MINE_RADIUS_MULTIPLIER := 1.75
const MINE_SLOW_MULTIPLIER := 0.4
const MINE_SLOW_DURATION := 3.0
const FIELD_TICK_INTERVAL := 0.25
const FIELD_SLOW_MULTIPLIER := 0.3
const FIELD_HEAL_RATIO := 0.03
const TURRET_SHOT_COUNT := 2
const TURRET_FIRE_INTERVAL_MULTIPLIER := 0.5
const TURRET_DURATION_BONUS := 4.0
const CANNON_SHOT_COUNT := 3
const CANNON_BLAST_RADIUS := 140.0

# Slot ownership stays in skill_talent_slots; legacy level_talents remain separate.
const DEFINITIONS := {
	"mechanic_trait": [
		{"title": "离线工厂", "summary": "待命时也生产零件，产出间隔减半。", "description": "零件产出不再要求机械师站场，待命时仍按相同效率生产；最终产出间隔乘以 50%。死亡与战斗暂停期间不生产。", "card_lines": ["待命时继续生产", "零件产出间隔减半"]},
		{"title": "精密堆叠", "summary": "零件上限 +8，每零件伤害加成 +4 个百分点。", "description": "零件上限增加 8；每个零件对机械召唤物、力场及机械全开齐射的伤害加成额外增加 4 个百分点。机械蜘蛛普攻仍不享受零件增伤。", "card_lines": ["零件上限 +8", "每零件增伤额外 +4%"]}
	],
	"mechanic_entry": [
		{"title": "双机接应", "summary": "登场时额外部署 1 台机炮。", "description": "紧急部署额外放置 1 台登场机炮，前后分布；每台均使用紧急部署的等级、天赋和本次登场伤害倍率。不会触发主动机炮技能的冷却。", "card_lines": ["登场额外部署 1 台", "使用登场技能成长"]},
		{"title": "预装弹链", "summary": "登场机炮射击间隔减半，持续时间 +4 秒。", "description": "仅紧急部署产生的机炮：最终射击间隔乘以 50%，新部署时的持续时间增加 4 秒。已部署机炮立即使用新的射击间隔，剩余时间不会回填。", "card_lines": ["登场机炮射击间隔减半", "新部署持续时间 +4 秒"]}
	],
	"mechanic_basic": [
		{"title": "蜂群指令", "summary": "每次普攻同时释放 3 只机械蜘蛛。", "description": "每次普攻向同一目标释放 3 只机械蜘蛛，每只均造成完整普攻伤害。三只蜘蛛共同构成一次普攻。", "card_lines": ["每次释放 3 只蜘蛛", "每只保留完整伤害"]},
		{"title": "穿甲履足", "summary": "蜘蛛额外穿透 3 个敌人，移动速度翻倍。", "description": "新发出的机械蜘蛛额外穿透 3 个敌人，穿透后继续沿原方向前进；最终移动速度乘以 200%。同一只蜘蛛不会重复命中同一个敌人。", "card_lines": ["额外穿透 3 个敌人", "蜘蛛移动速度 ×2"]}
	],
	"mechanic_drone": [
		{"title": "双机编队", "summary": "每次召唤 2 台守卫，同时存在上限 +3。", "description": "每次施放召唤 2 台守卫机器人，同时存在上限增加 3。每台保留完整抵挡次数；超过上限时依次回收最早部署的守卫。", "card_lines": ["每次召唤 2 台守卫", "同时存在上限 +3"]},
		{"title": "应急维修", "summary": "守卫成功抵挡时，回复当前角色 6% 最大生命。", "description": "任一守卫成功抵挡一次伤害时，为当前站场角色回复其最大生命的 6%。切人后仍可保护和维修新角色；每次仍消耗 1 次抵挡，耗尽时也会完成本次维修。", "card_lines": ["抵挡时维修当前角色", "回复 6% 最大生命"]}
	],
	"mechanic_mine": [
		{"title": "环形雷阵", "summary": "每次额外布置 4 枚地雷，布雷半径扩大至 96。", "description": "每次布置额外增加 4 枚感应地雷，并沿距离角色 96 的圆周均匀布置。每枚独立感应和爆炸；不追溯增加已部署地雷的数量。", "card_lines": ["每次额外布置 4 枚", "布雷圆周半径 96"]},
		{"title": "震荡装药", "summary": "感应与爆炸半径 ×1.75，命中减速 60% 持续 3 秒。", "description": "地雷最终感应与爆炸半径乘以 175%，命中的敌人移动速度降低 60%，持续 3 秒。已部署地雷立即使用新范围；爆炸画面与伤害范围一致。", "card_lines": ["感应与爆炸半径 ×1.75", "减速 60%，持续 3 秒"]}
	],
	"mechanic_emp_burst": [
		{"title": "强磁共振", "summary": "伤害与回复每 0.25 秒触发，敌人减速提高至 70%。", "description": "力场伤害与维修的触发间隔改为 0.25 秒，敌人移动速度降低 70%。每跳伤害保持当前倍率；与随行维保同时拥有时，每跳回复 3% 最大生命。", "card_lines": ["伤害与回复每 0.25 秒", "范围内敌人减速 70%"]},
		{"title": "随行维保", "summary": "力场跟随当前角色移动，每跳回复提高至 3% 最大生命。", "description": "力场中心跟随当前站场角色移动，切换角色后继续跟随新角色；每跳为范围内的当前角色回复其最大生命的 3%。持续时间与既有剩余时间保持不变。", "card_lines": ["力场跟随当前角色", "每跳回复 3% 最大生命"]}
	],
	"mechanic_tulip_turret": [
		{"title": "双联供弹", "summary": "主动机炮每次射击发射 2 发完整伤害子弹。", "description": "主动技能部署的定点机炮每次射击同时发射 2 发子弹，每发保留完整伤害。不会影响紧急部署产生的登场机炮。", "card_lines": ["主动机炮每次 2 发", "每发保留完整伤害"]},
		{"title": "超频枪架", "summary": "主动机炮射击间隔减半，持续时间 +4 秒。", "description": "仅主动技能部署的机炮：最终射击间隔乘以 50%，新部署时的持续时间增加 4 秒。已部署机炮立即加速，剩余时间不会回填；不影响登场机炮。", "card_lines": ["主动机炮射击间隔减半", "新部署持续时间 +4 秒"]}
	],
	"mechanic_missile_volley": [
		{"title": "集束炮击", "summary": "重型炮台每次齐射 3 发完整伤害炮弹。", "description": "重型炮台每次射击同时发射 3 发炮弹，集中攻击当前目标，每发均保留完整伤害；可与高爆弹芯组合，每发独立引爆一次。", "card_lines": ["重型炮台每次齐射 3 发", "每发保留完整伤害"]},
		{"title": "高爆弹芯", "summary": "炮弹首次命中时，在半径 140 内追加一次等额爆炸。", "description": "重型炮弹首次命中敌人时，在命中位置半径 140 内追加一次相当于该炮弹 100% 伤害的爆炸，主目标也会受到爆炸伤害。每发仅在首次命中时引爆一次。", "card_lines": ["首次命中爆炸，半径 140", "追加 100% 炮弹伤害"]}
	]
}

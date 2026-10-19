extends RefCounted

const MIDDLE := ["shooter", "dasher", "shotgunner", "shadow_tree"]
const HIGH := ["vine", "skull_mage", "angry_porcupine", "necro_priest"]
const REWARD_WAVES := [7, 12, 17]
const FLYBY_WAVES := [8, 14, 19]
const DURATIONS := [60, 60, 60, 65, 70, 0, 60, 70, 75, 75, 0, 60, 80, 80, 85, 0, 60, 90, 90, 0]
const SMALL_BOSS_EXPERIENCE := {6: 500, 11: 700, 16: 900}
const TREE_ESCORT_LIMIT := 20
const TREE_ESCORT_INTERVAL := 1.5
const SKULL_ESCORT_INTERVAL := 3.0
const SKULL_ESCORT_CAPS := {"shooter": 3, "shotgunner": 2, "skull_mage": 1}
const POOLS := [
	["chaser"],
	["chaser", "chaser", "runner"],
	["chaser", "chaser", "brute"],
	["chaser", "runner", "brute", "shooter"],
	["chaser", "runner", "brute", "dasher"],
	["shadow_tree"],
	["chaser", "runner"],
	["chaser", "runner", "brute", "shooter", "dasher"],
	["chaser", "runner", "brute", "shooter", "vine"],
	["chaser", "runner", "brute", "shooter", "shotgunner"],
	["shooter", "shotgunner", "skull_mage"],
	["chaser", "runner", "brute"],
	["chaser", "runner", "brute", "dasher", "shadow_tree", "skull_mage"],
	["chaser", "runner", "brute", "shooter", "shotgunner", "angry_porcupine"],
	["chaser", "runner", "brute", "shooter", "dasher", "shotgunner"],
	["chaser", "chaser", "runner"],
	["chaser", "runner", "brute"],
	["chaser", "runner", "brute", "shooter", "dasher", "shadow_tree", "vine", "necro_priest"],
	["chaser", "runner", "brute", "shooter", "dasher", "shotgunner", "shadow_tree", "vine", "skull_mage", "angry_porcupine", "necro_priest"],
	[]
]
const BOSSES := {6: "smallboss_glutton", 11: "smallboss_rebirth", 16: "smallboss_turret", 20: "boss_spellcore"}
const ELITES := {5: ["elite_ram_trail"], 10: ["elite_splitshot"], 15: ["elite_ram_trail", "elite_splitshot"], 19: ["elite_ram_trail", "elite_splitshot"]}

static func duration(wave: int) -> float:
	return float(DURATIONS[clampi(wave - 1, 0, 19)])

static func category(archetype: String) -> String:
	if archetype in MIDDLE:
		return "middle"
	if archetype in HIGH:
		return "high"
	return "basic"

static func limits(wave: int) -> Dictionary:
	if wave == 6:
		return {"middle": TREE_ESCORT_LIMIT, "middle_single": TREE_ESCORT_LIMIT, "high": 0, "high_single": 0}
	if wave == 11:
		# Leave room for the death domain's ten charging skeletons.
		return {"middle": 15, "middle_single": 3, "high": 1, "high_single": 1}
	if wave <= 5:
		return {"middle": 6, "middle_single": 4, "high": 0, "high_single": 0}
	if wave <= 14:
		return {"middle": 12, "middle_single": 6, "high": 3, "high_single": 2}
	return {"middle": 18, "middle_single": 8, "high": 5, "high_single": 3}

static func single_limit(wave: int, archetype: String, elapsed: float) -> int:
	if archetype == "necro_priest":
		return 1
	if wave == 6:
		return TREE_ESCORT_LIMIT if archetype == "shadow_tree" else 0
	if wave == 11:
		return int(SKULL_ESCORT_CAPS.get(archetype, 0))
	var cap: int = int(limits(wave).get(category(archetype) + "_single", 60))
	# New threats are introduced gently, then use their normal category budget.
	if (wave == 4 and archetype == "shooter") or (wave == 5 and archetype == "dasher"):
		return mini(cap, 2 if elapsed < duration(wave) * 0.5 else 4)
	if (wave == 9 and archetype == "vine") or (wave == 13 and archetype == "skull_mage") or (wave == 14 and archetype == "angry_porcupine"):
		return mini(cap, 1 if elapsed < duration(wave) * 0.5 else 2)
	return cap

static func title(wave: int) -> String:
	if wave in REWARD_WAVES:
		return "奖励波"
	if wave in BOSSES:
		return {6: "幽影树人", 11: "引渡人", 16: "地瑰灵", 20: "被污染的魔法石"}[wave]
	if wave in ELITES:
		return "精英波"
	return "混合战斗" if wave >= 4 else "基础战斗"

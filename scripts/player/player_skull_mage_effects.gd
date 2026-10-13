extends RefCounted

const DOMAIN := preload("res://scripts/enemies/skull_mage_domain.gd")
const COLD_META := "skull_mage_cold_remaining"
const ABILITY_KEYS := [
	"gunner_infinite_reload_ability", "gunner_explosive_round_ability",
	"gunner_magic_grenade_ability", "gunner_magic_eye_ability", "gunner_shrapnel_field_ability",
	"mage_flame_path_ability", "mage_dark_contract_ability", "mage_fireball_ability",
	"mage_tidal_surge_ability", "mage_meta_field_ability", "swordsman_blade_storm_ability",
	"swordsman_knight_thrust_ability", "swordsman_king_blade_ability",
	"swordsman_crescent_wave_ability", "swordsman_judgement_sword_ability",
	"mechanic_drone_ability", "mechanic_mine_ability", "mechanic_emp_burst_ability",
	"mechanic_tulip_turret_ability", "mechanic_missile_volley_ability"
]


static func on_enemy_damage(player, enemy, amount: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if amount <= 0 or enemy == null or not is_instance_valid(enemy) or str(enemy.get("archetype_id")) != "skull_mage":
		return
	if not preload("res://scripts/enemies/enemy_skull_mage.gd").is_ice_active(enemy):
		return
	if player.has_method("_is_status_immune") and player._is_status_immune():
		return
	player.set_meta(COLD_META, preload("res://scripts/combat/status_resistance.gd").duration(player, 3.0))


static func get_cold_remaining(player) -> float:
	if player == null:
		return 0.0
	return maxf(0.0, float(player.get_meta(COLD_META, 0.0)))


static func attack_speed_multiplier(player) -> float:
	return 0.7 if get_cold_remaining(player) > 0 else 1.0


static func tick(player, delta: float) -> void:
	if get_cold_remaining(player) > 0:
		player.set_meta(COLD_META, maxf(0.0, get_cold_remaining(player) - delta))


static func slow_cooldowns_before_update(player, delta: float) -> void:
	if DOMAIN.get_remaining(player) <= 0:
		return
	for key in ABILITY_KEYS:
		var ability = player.get(key)
		if ability != null and ability.get("cooldown_remaining") != null and float(ability.cooldown_remaining) > 0:
			# Updates still use real delta for durations, projectiles and damage.
			# Pre-compensate only CD so expiry and automatic casting stay correct.
			ability.cooldown_remaining += delta * (1.0 - 1.0 / 1.2)


static func get_buff_slots(player) -> Array:
	var result: Array = []
	var cold := get_cold_remaining(player)
	if cold > 0:
		result.append({
			"id": "skull_mage_cold", "name": "寒冰侵蚀", "text": "寒",
			"description": "攻击速度降低30%，持续3秒；重复命中刷新，状态抗性缩短时长。",
			"remaining": cold, "duration": 3.0, "cooldown": false,
			"color": Color(0.45, 0.85, 1), "base_color": Color(0.08, 0.2, 0.35)
		})
	var domain := DOMAIN.get_remaining(player)
	if domain > 0:
		result.append({
			"id": "unclean_domain", "name": "不洁领域", "text": "污",
			"description": "领域内移动速度降低20%，技能冷却完成所需时间增加20%；离开解除，同类领域不叠加。",
			"remaining": domain, "duration": 10.0, "cooldown": false,
			"color": Color(0.7, 0.35, 0.9), "base_color": Color(0.2, 0.08, 0.3)
		})
	return result

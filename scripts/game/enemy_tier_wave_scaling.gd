extends RefCounted

const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
# Initial health, initial attack, per-wave health, speed and flat attack growth.
const RULES := {
	1: [0.8, 0.8, 0.0, 0.0, 0.0],
	2: [1.0, 1.0, 0.15, 0.0, 0.0],
	3: [2.0, 1.5, 0.20, 0.01, 0.0],
	4: [2.5, 2.0, 0.20, 0.015, 1.5],
	5: [2.5, 2.5, 0.25, 0.02, 2.0]
}

static func get_tier(main: Node) -> int:
	if main == null:
		return 0
	var profile: Variant = main.get("difficulty_profile")
	return int(profile.get("tier", 0)) if profile is Dictionary else 0

static func applies(main: Node, kind: String) -> bool:
	return kind in ["normal", "elite", "small_boss", "boss"] and RULES.has(get_tier(main))

static func get_wave(main: Node) -> int:
	var waves: Variant = main.get("wave_flow") if main != null else null
	return maxi(1, int(waves.wave)) if is_instance_valid(waves) else 1

static func multipliers(tier: int, wave: int) -> Dictionary:
	if not RULES.has(tier):
		return {}
	var rule: Array = RULES[tier]
	var steps := maxi(0, wave - 1)
	return {
		"health": float(rule[0]) * pow(1.0 + float(rule[2]), steps),
		"attack": float(rule[1]),
		"attack_flat": float(rule[4]) * steps,
		"speed": pow(1.0 + float(rule[3]), steps),
		"reduction": float(floori(float(maxi(1, wave)) / 5.0)) * 0.05 if tier == 5 else 0.0
	}

# Always recompute from this archetype's authored defaults, never its parent.
# Also safe when a pooled enemy is reused or a seed changes into a young tree.
static func apply_spawn(enemy, main: Node) -> bool:
	var kind := str(enemy.enemy_kind)
	if not applies(main, kind):
		return false
	var base := DATABASE.get_profile(kind, str(enemy.archetype_id))
	# Bosses receive the tier's initial HP/attack multipliers, without wave growth.
	var wave := 1 if kind in ["small_boss", "boss"] else get_wave(main)
	var values := multipliers(get_tier(main), wave)
	var base_attack := float(base.get("attack", 0.0))
	enemy.max_health = float(base.get("max_health", 20.0)) * float(values.health)
	enemy.current_health = enemy.max_health
	enemy.attack = base_attack * float(values.attack) + float(values.attack_flat)
	enemy.speed = float(base.get("speed", 80.0)) * float(values.speed)
	enemy.damage_reduction_rate = clampf(float(base.get("damage_reduction_rate", 0.0)) + float(values.reduction), 0.0, 1.0)
	# Preserve authored damage coefficients; actual Stalwart Body uses attack.
	var touch_ratio := float(base.get("touch_damage", 0.0)) / base_attack if base_attack > 0.0 else 0.0
	var projectile_ratio := float(base.get("projectile_damage", base_attack)) / base_attack if base_attack > 0.0 else 0.0
	enemy.touch_damage = enemy.attack * touch_ratio
	enemy.projectile_damage = enemy.attack * projectile_ratio
	return true

extends RefCounted

const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_TARGETING := preload("res://scripts/player/player_targeting.gd")
const PLAYER_SKILL_LEVEL_EFFECT_FLOW := preload("res://scripts/player/player_skill_level_effect_flow.gd")

## 枪手主动技能「魔法榴弹」的来源识别与专属暴击加成。

const SOURCE_PREFIX := "gunner_magic_grenade:"
const CRIT_CHANCE_BONUS := 0.20
const GRENADE_COUNT := 3
const DAMAGE_RATIO := 2.00
const BLAST_RADIUS := 75.0
const SEARCH_RADIUS := 540.0
const SEARCH_MIN_DISTANCE := 60.0

const TALENT_MAGIC_GRENADE_1 := "gunner_level_talent_magic_grenade_1"
const TALENT_MAGIC_GRENADE_2 := "gunner_level_talent_magic_grenade_2"
const TALENT_MAGIC_GRENADE_MENTAL_SHOCK := "gunner_level_talent_magic_grenade_mental_shock"
const TALENT_MAGIC_GRENADE_CHAIN_BLAST := "gunner_level_talent_magic_grenade_chain_blast"
const TALENT_MAGIC_GRENADE_ASSISTANT := "gunner_level_talent_magic_grenade_assistant"
const TALENT_MAGIC_GRENADE_CHARGE := "gunner_level_talent_magic_grenade_charge"
const MENTAL_SHOCK_STACK_META := "gunner_magic_grenade_mental_shock_stacks"
const MENTAL_SHOCK_VULNERABILITY_PER_STACK := 0.03
const MENTAL_SHOCK_REQUIRED_STACKS := 5
const MENTAL_SHOCK_STUN_DURATION := 2.0
const MENTAL_SHOCK_STUN_RADIUS := 75.0
const CHAIN_BLAST_CRITS_REQUIRED := 8
const CHARGE_CRIT_PER_ENERGY := 0.0025
const CHARGE_CRIT_DAMAGE_PER_ENERGY := 0.007

# LV4 分支：魔法追弹使每枚伤害 -100 个百分点并增加 3 枚；幸运之弹使暴击率 +20 个百分点、范围 +50。
const TALENT_1_DAMAGE_RATIO_BONUS := -1.00
const TALENT_1_GRENADE_BONUS := 3
const TALENT_2_BLAST_RADIUS_BONUS := 50.0
const TALENT_2_CRIT_BONUS := 0.20


static func make_damage_source_id(is_free: bool = false) -> String:
	return SOURCE_PREFIX + ("free" if is_free else "1")


static func is_magic_grenade_source(source_role_id: String) -> bool:
	return source_role_id.begins_with(SOURCE_PREFIX)


static func has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_level_talent") and bool(owner._has_level_talent(talent_id))

static func has_magic_chase(owner) -> bool:
	return has_talent(owner, TALENT_MAGIC_GRENADE_1) or _has_skill_talent_slot(owner, 1)

static func has_lucky_round(owner) -> bool:
	return has_talent(owner, TALENT_MAGIC_GRENADE_2) or _has_skill_talent_slot(owner, 2)

static func _has_skill_talent_slot(owner, slot: int) -> bool:
	if owner == null or not (owner.get("role_special_states") is Dictionary):
		return false
	var gunner_state: Variant = owner.role_special_states.get("gunner", {})
	if not (gunner_state is Dictionary):
		return false
	var slots: Variant = gunner_state.get("skill_talent_slots", {})
	if not (slots is Dictionary):
		return false
	var grenade_entry: Variant = slots.get("gunner_magic_grenade", {})
	if not (grenade_entry is Dictionary):
		return false
	var granted: Variant = grenade_entry.get("granted", [])
	return granted is Array and granted.has(slot)


static func get_grenade_count(owner) -> int:
	return GRENADE_COUNT + (TALENT_1_GRENADE_BONUS if has_magic_chase(owner) else 0) + PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_magic_grenade_extra_count(owner)


static func get_damage_ratio(owner) -> float:
	return maxf(0.0, DAMAGE_RATIO + (TALENT_1_DAMAGE_RATIO_BONUS if has_magic_chase(owner) else 0.0) + PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_magic_grenade_damage_ratio_bonus(owner))


static func get_blast_radius(owner) -> float:
	return BLAST_RADIUS + (TALENT_2_BLAST_RADIUS_BONUS if has_lucky_round(owner) else 0.0)


static func get_critical_chance_bonus(owner, source_role_id: String) -> float:
	if source_role_id == "" or not is_magic_grenade_source(source_role_id):
		return 0.0
	var charge_bonus := get_charge_critical_bonus(owner) if has_talent(owner, TALENT_MAGIC_GRENADE_CHARGE) else 0.0
	return CRIT_CHANCE_BONUS + (TALENT_2_CRIT_BONUS if has_lucky_round(owner) else 0.0) + PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_magic_grenade_crit_bonus(owner) + charge_bonus


static func collect_targets(owner, origin: Vector2, facing: Vector2) -> Array:
	var grenade_count: int = get_grenade_count(owner)
	var fallback_targets := _build_fallback_targets(owner, origin, facing)
	var bounds := Rect2(origin - Vector2.ONE * SEARCH_RADIUS, Vector2.ONE * SEARCH_RADIUS * 2.0)
	var candidates: Array = PLAYER_DAMAGE_RESOLVER._get_candidate_enemies_for_bounds(owner, bounds)
	if candidates.is_empty():
		return fallback_targets
	var front_enemies: Array = []
	var search_radius_squared: float = SEARCH_RADIUS * SEARCH_RADIUS
	var min_distance_squared: float = SEARCH_MIN_DISTANCE * SEARCH_MIN_DISTANCE
	for enemy in candidates:
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var offset: Vector2 = enemy.global_position - origin
		var distance_squared: float = offset.length_squared()
		if distance_squared < min_distance_squared or distance_squared > search_radius_squared:
			continue
		if facing.dot(offset.normalized()) < 0.12:
			continue
		front_enemies.append(enemy)
	if front_enemies.is_empty():
		return fallback_targets
	var centers: Array = PLAYER_TARGETING.get_random_enemy_cluster_centers(front_enemies, origin, grenade_count)
	var targets: Array = []
	for center in centers:
		if origin.distance_to(center) < SEARCH_MIN_DISTANCE:
			continue
		targets.append(center)
		if targets.size() >= grenade_count:
			break
	while targets.size() < grenade_count:
		targets.append(fallback_targets[targets.size()])
	return _spread_repeated_targets(targets, origin)


static func _spread_repeated_targets(targets: Array, origin: Vector2) -> Array:
	var result: Array = []
	var occurrences: Dictionary = {}
	for target_value in targets:
		var target: Vector2 = target_value
		var occurrence: int = int(occurrences.get(target, 0))
		occurrences[target] = occurrence + 1
		if occurrence > 0:
			var angle := TAU * float(occurrence) / float(maxi(2, targets.size()))
			target += Vector2.RIGHT.rotated(angle) * 64.0
			if target.distance_to(origin) < SEARCH_MIN_DISTANCE:
				target += (target - origin).normalized() * SEARCH_MIN_DISTANCE
		result.append(target)
	return result


static func apply_explosion(owner, center: Vector2, source_id: String = "") -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var damage: float = float(owner._get_role_damage("gunner")) * get_damage_ratio(owner)
	owner._damage_enemies_in_radius(center, get_blast_radius(owner), damage, 0.0, 1.0, 0.0, source_id if source_id != "" else make_damage_source_id())

static func on_magic_grenade_hit(owner, enemy: Node, source_role_id: String, was_critical: bool, killed: bool) -> void:
	if owner == null or enemy == null or not is_instance_valid(enemy):
		return
	var is_free := source_role_id == make_damage_source_id(true)
	if has_talent(owner, TALENT_MAGIC_GRENADE_MENTAL_SHOCK) and not is_free:
		var stacks := int(enemy.get_meta(MENTAL_SHOCK_STACK_META, 0)) + 1
		enemy.set_meta(MENTAL_SHOCK_STACK_META, stacks)
		if enemy.has_method("apply_vulnerability"):
			enemy.apply_vulnerability(float(stacks) * MENTAL_SHOCK_VULNERABILITY_PER_STACK, 999999.0)
		if killed and stacks >= MENTAL_SHOCK_REQUIRED_STACKS:
			_stun_nearby_enemies(owner, enemy)
	if has_talent(owner, TALENT_MAGIC_GRENADE_CHAIN_BLAST) and was_critical and not is_free:
		var count := int(owner.get_meta("gunner_magic_grenade_chain_crit_count", 0)) + 1
		if count >= CHAIN_BLAST_CRITS_REQUIRED:
			count -= CHAIN_BLAST_CRITS_REQUIRED
			if owner.has_method("_try_trigger_gunner_magic_grenade_free"):
				owner._try_trigger_gunner_magic_grenade_free()
		owner.set_meta("gunner_magic_grenade_chain_crit_count", count)


static func on_gunner_basic_critical(owner, source_role_id: String, was_critical: bool) -> void:
	if owner == null or not was_critical or not source_role_id.begins_with("gunner_basic:"):
		return
	if has_talent(owner, TALENT_MAGIC_GRENADE_ASSISTANT) and owner.has_method("_try_trigger_gunner_magic_grenade_free"):
		owner._try_trigger_gunner_magic_grenade_free()


static func add_charge_energy(owner, amount: float) -> void:
	if owner == null or amount <= 0.0 or not has_talent(owner, TALENT_MAGIC_GRENADE_CHARGE):
		return
	owner.set_meta("gunner_magic_grenade_charge_energy", float(owner.get_meta("gunner_magic_grenade_charge_energy", 0.0)) + amount)

static func get_charge_critical_bonus(owner) -> float:
	return maxf(0.0, float(owner.get_meta("gunner_magic_grenade_charge_energy", 0.0))) * CHARGE_CRIT_PER_ENERGY

static func get_charge_critical_damage_bonus(owner, source_role_id: String) -> float:
	if source_role_id == "" or not is_magic_grenade_source(source_role_id) or not has_talent(owner, TALENT_MAGIC_GRENADE_CHARGE):
		return 0.0
	return maxf(0.0, float(owner.get_meta("gunner_magic_grenade_charge_energy", 0.0))) * CHARGE_CRIT_DAMAGE_PER_ENERGY

static func _stun_nearby_enemies(owner, source_enemy: Node) -> void:
	if owner == null or source_enemy == null or not source_enemy is Node2D:
		return
	var center := (source_enemy as Node2D).global_position
	var bounds := Rect2(center - Vector2.ONE * MENTAL_SHOCK_STUN_RADIUS, Vector2.ONE * MENTAL_SHOCK_STUN_RADIUS * 2.0)
	var candidates: Array = PLAYER_DAMAGE_RESOLVER._get_candidate_enemies_for_bounds(owner, bounds)
	for enemy in candidates:
		if enemy == null or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if (enemy as Node2D).global_position.distance_to(center) <= MENTAL_SHOCK_STUN_RADIUS and enemy.has_method("apply_stun"):
			enemy.apply_stun(MENTAL_SHOCK_STUN_DURATION)


static func _build_fallback_targets(owner, origin: Vector2, facing: Vector2) -> Array:
	var grenade_count: int = get_grenade_count(owner)
	var targets: Array = []
	var base_distance := 300.0
	for index in range(grenade_count):
		var lateral: float = (float(index) - float(grenade_count - 1) * 0.5) * 90.0
		var offset: Vector2 = facing * (base_distance + float(index) * 60.0) + Vector2.UP.rotated(facing.angle()) * lateral
		targets.append(origin + offset)
	return targets

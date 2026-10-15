extends SceneTree

const FIXTURE := preload("res://scripts/tests/mechanic_skill_level_effect_smoke.gd")
const LEVELS := preload("res://scripts/player/player_skill_level_system.gd")
const BULLET := preload("res://scripts/bullet.gd")
const COOLDOWNS := preload("res://scripts/player/player_skill_cooldown_flow.gd")
const PLAYER := preload("res://scenes/player.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	_check_choices()
	_check_trait(_owner(world))
	_check_spiders(_owner(world))
	_check_turrets(_owner(world))
	_check_guards(_owner(world))
	_check_mines(_owner(world))
	_check_field(_owner(world))
	_check_cannon_and_blast(_owner(world))
	_check_save(world)
	world.queue_free()
	await process_frame
	current_scene = null
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("MECHANIC_SKILL_TALENTS_SMOKE_OK")
	quit(0 if failures.is_empty() else 1)


func _owner(world: Node2D):
	var owner := FIXTURE.CombatOwner.new()
	world.add_child(owner)
	owner.roles = [{"id": "mechanic"}, {"id": "gunner"}]
	owner.target = Node2D.new()
	owner.target.position = Vector2(120.0, 0.0)
	world.add_child(owner.target)
	return owner


func _grant(owner, progress_id: String, slots: Array) -> void:
	for slot in slots:
		LEVELS._record_talent_slot(owner, "mechanic", progress_id, int(slot), false)


func _check_choices() -> void:
	_expect(LEVELS.MECHANIC_TALENTS.DEFINITIONS.size() == 8, "Eight mechanic lines need dedicated talents")
	for progress_id in LEVELS.MECHANIC_TALENTS.DEFINITIONS:
		for slot in [1, 2]:
			var owner := FIXTURE.CombatOwner.new()
			LEVELS.add_skill_level(owner, "mechanic", progress_id, 4)
			var before := owner.role_special_states.duplicate(true)
			var offer := LEVELS.build_talent_offer_for(owner, "mechanic", progress_id)
			_expect(owner.role_special_states == before, "Building talent offers must be read-only")
			var option: Dictionary = offer["options"][slot - 1]
			_expect(option["talent_implemented"] and not str(option).contains("尚未实装"), "Mechanic options must describe real effects")
			_expect(option["id"] == "skill_level_talent:mechanic:%s:%d" % [progress_id, slot], "Saved option IDs must remain stable")
			var result := LEVELS.apply_option_with_result(owner, option["id"], offer)
			_expect(not result.is_empty() and result["title"] == option["title"], "Formal choice should grant and name its talent")
			_expect(LEVELS.get_granted_talent_slots(owner, "mechanic", progress_id) == [slot], "Level 5 choice must grant only the selected slot")
			_expect(LEVELS.apply_option_with_result(owner, option["id"], offer).is_empty(), "A stale talent offer must not grant twice")
			LEVELS.add_skill_level(owner, "mechanic", progress_id, 5)
			_expect(LEVELS.get_granted_talent_slots(owner, "mechanic", progress_id) == [1, 2], "Level 10 must grant both talents in either pick order")
			_expect(LEVELS.get_picked_talent_slot(owner, "mechanic", progress_id) == slot, "Auto grant should preserve the earlier choice")
			_expect(LEVELS.normalize_role_state("mechanic", owner.role_special_states["mechanic"]) == owner.role_special_states["mechanic"], "Normalization must retain talent ownership")
			owner.free()
	_expect(LEVELS.get_talent_definition("mechanic", "mechanic_basic", 0).is_empty(), "Invalid slots must have no definition")
	_expect(LEVELS.get_talent_definition("mechanic", "mechanic_ultimate", 1).is_empty(), "Ultimate must stay outside the talent pool")
	_expect(not LEVELS._make_talent_option("mage", "mage_basic", 1)["talent_implemented"], "Other roles' placeholders must remain explicit")


func _check_trait(owner) -> void:
	owner.active_role_id = "gunner"
	owner.mechanic_role.update_trait_state(owner, 4.0)
	_expect(owner.mechanic_role.get_parts_count(owner) == 0, "Unowned offline factory must not generate background parts")
	_grant(owner, "mechanic_trait", [1])
	_expect(owner.mechanic_role.get_parts_max(owner) == 10 and is_equal_approx(owner.mechanic_role.get_part_damage_bonus(owner), 0.04), "Offline factory must not grant precision stacking early")
	owner.mechanic_role.update_trait_state(owner, 4.0)
	_expect(owner.mechanic_role.get_parts_count(owner) == 2, "Offline factory should generate two background parts in four seconds")
	_grant(owner, "mechanic_trait", [2])
	_expect(owner.mechanic_role.get_parts_max(owner) == 18, "Precision stacking should add eight capacity")
	_expect(is_equal_approx(owner.mechanic_role.get_summon_damage_multiplier(owner), 1.16), "Each existing part should gain four percentage points")
	owner.mechanic_role.update_trait_state(owner, 100.0)
	_expect(owner.mechanic_role.get_parts_count(owner) == 18, "Production must stop at the enlarged cap")
	owner._get_role_special_state("mechanic")["talent_runtime"] = {"parts": 0}
	owner.roles = [{"id": "gunner"}]
	owner.mechanic_role.update_trait_state(owner, 20.0)
	_expect(owner.mechanic_role.get_parts_count(owner) == 0, "Offline factory must not run for a mechanic absent from the team")
	owner.is_dead = true
	var before: Dictionary = owner.role_special_states.duplicate(true)
	owner.mechanic_role.update_trait_state(owner, 20.0)
	_expect(owner.role_special_states == before, "Dead mechanics must not produce parts")


func _check_spiders(owner) -> void:
	_grant(owner, "mechanic_basic", [1])
	owner.mechanic_role.perform_attack(owner)
	_expect(owner.shots.size() == 3 and owner.shots[0]["node"].pierce_count == 0 and is_equal_approx(owner.shots[0]["node"].speed, 100.0), "Swarm alone must not grant piercing treads")
	owner.shots.clear()
	_grant(owner, "mechanic_basic", [2])
	owner.mechanic_role.perform_attack(owner)
	_expect(owner.shots.size() == 3, "Swarm command must emit three projectiles")
	for shot in owner.shots:
		_expect(is_equal_approx(float(shot["damage"]), 100.0), "Swarm spiders must retain full basic damage")
		_expect(shot["role_id"] == owner.shots[0]["role_id"], "Swarm projectiles must share one basic attack source")
		_expect(shot["node"].pierce_count == 3 and is_equal_approx(shot["node"].speed, 200.0), "Piercing treads must add penetration and double speed")


func _check_turrets(owner) -> void:
	var turret = owner.mechanic_tulip_turret_ability
	_grant(owner, "mechanic_entry", [1])
	_expect(is_equal_approx(turret._get_duration(owner, "mechanic_entry"), 8.0) and is_equal_approx(turret._get_fire_interval(owner, "mechanic_entry"), 0.8), "Dual reception must not grant preloaded ammo early")
	_grant(owner, "mechanic_entry", [2])
	owner.mechanic_role.perform_enter(owner, "mechanic", 0, 1.25)
	turret.deploy_turret(owner)
	_expect(turret.active_turrets.size() == 3, "Dual reception should deploy two entry turrets plus the independent active turret")
	_expect(is_equal_approx(turret.active_turrets[0]["remaining"], 12.0) and is_equal_approx(turret.active_turrets[2]["remaining"], 8.0), "Entry duration talent must not change active duration")
	_expect(is_equal_approx(turret._get_fire_interval(owner, "mechanic_entry"), 0.4) and is_equal_approx(turret._get_fire_interval(owner), 0.8), "Entry fire rate must be isolated")
	_grant(owner, "mechanic_tulip_turret", [1])
	_expect(is_equal_approx(turret._get_fire_interval(owner), 0.8) and turret._get_shot_count(owner, "mechanic_tulip_turret") == 2, "Twin feed alone must not overclock")
	_grant(owner, "mechanic_tulip_turret", [2])
	_expect(is_equal_approx(turret.active_turrets[2]["remaining"], 8.0), "Acquiring duration must not refill existing deployments")
	turret._fire(owner, turret.active_turrets[0])
	_expect(owner.shots.size() == 1 and is_equal_approx(owner.shots[0]["damage"], 150.0), "Entry must retain one bullet and its cast multiplier")
	turret._fire(owner, turret.active_turrets[2])
	_expect(owner.shots.size() == 3, "Twin feed must emit two active turret bullets")
	_expect(is_equal_approx(turret._get_fire_interval(owner), 0.4) and is_equal_approx(turret._get_duration(owner), 12.0), "Overclock must change active fire rate and new duration")


func _check_guards(owner) -> void:
	var guard = owner.mechanic_drone_ability
	_grant(owner, "mechanic_drone", [1])
	_expect(guard.try_trigger(owner) and guard.active_guards.size() == 2, "Dual formation must spawn two guards")
	guard.try_block_damage(owner)
	_expect(is_zero_approx(owner.healed), "Dual formation alone must not grant repairs")
	_grant(owner, "mechanic_drone", [2])
	for _index in range(5):
		guard.cooldown_remaining = 0.0
		guard.try_trigger(owner)
	_expect(guard.active_guards.size() == 8, "Deploying pairs must respect the raised eight-guard cap")
	owner.active_role_id = "gunner"
	guard.active_guards[0]["charges"] = 1
	_expect(guard.try_block_damage(owner), "A last-charge guard must still block")
	_expect(guard.active_guards.size() == 7 and is_equal_approx(owner.healed, 6.0) and owner.healed_role_id == "gunner", "The final block must heal the current role and consume the guard")


func _check_mines(owner) -> void:
	var mine = owner.mechanic_mine_ability
	_grant(owner, "mechanic_mine", [1])
	_expect(is_equal_approx(mine._get_radius(owner), 80.0), "Ring minefield must not enlarge detection without shock payload")
	_grant(owner, "mechanic_mine", [2])
	_expect(mine.try_trigger(owner) and mine.active_mines.size() == 7, "Ring minefield must add four mines")
	for data in mine.active_mines:
		_expect(is_equal_approx(data["node"].global_position.distance_to(owner.global_position), 96.0), "Mine ring placement must match its described radius")
	owner.target.position = Vector2(139.0, 0.0)
	_expect(mine._has_enemy_in_range(owner, Vector2.ZERO), "Existing mines must use enlarged detection")
	owner.target.position.x = 141.0
	_expect(not mine._has_enemy_in_range(owner, Vector2.ZERO), "Mine detection must stop at the real boundary")
	mine._explode(owner, Vector2.ZERO)
	_expect(is_equal_approx(owner.hits.back()["radius"], 140.0) and is_equal_approx(owner.hits.back()["slow"], 0.4) and is_equal_approx(owner.hits.back()["slow_duration"], 3.0), "Shock payload must use enlarged blast and three-second slow")


func _check_field(owner) -> void:
	var field = owner.mechanic_emp_burst_ability
	field.try_trigger(owner)
	_grant(owner, "mechanic_emp_burst", [1])
	_expect(is_equal_approx(field._get_heal_ratio(owner), 0.015), "Resonance alone must not grant the maintenance heal bonus")
	owner.position = Vector2(10.0, 20.0)
	field.update(owner, 0.0)
	_expect(field.field_position == Vector2.ZERO, "Resonance alone must keep the field stationary")
	_grant(owner, "mechanic_emp_burst", [2])
	var healed: float = owner.healed
	var hit_count: int = owner.hits.size()
	owner.active_role_id = "gunner"
	owner.position = Vector2(1000.0, -200.0)
	field.update(owner, 0.5)
	_expect(owner.hits.size() == hit_count + 2 and is_equal_approx(owner.healed - healed, 6.0), "Resonance and mobile maintenance must combine as two full heal ticks")
	_expect(field.field_position == owner.global_position and field.field_node.global_position == owner.global_position, "Field visual and damage center must follow the new active role")
	_expect(is_equal_approx(owner.hits.back()["slow"], 0.3) and owner.healed_role_id == "gunner", "Field should apply seventy-percent slow and heal the new role")
	var saved: Dictionary = field.get_save_data()
	field.apply_save_data(saved)
	field.restore_effect_if_active(owner)
	_expect(is_equal_approx(field.field_remaining, 9.5) and owner.hits.size() == hit_count + 2, "Restoring a field must preserve time without replaying a tick")
	field.field_remaining = 0.1
	field.tick_elapsed = 0.0
	field.update(owner, 1.0)
	_expect(owner.hits.size() == hit_count + 2 and not field.self_buff_active, "A long update must not deal ticks beyond the field lifetime")
	field.apply_save_data(saved)
	field.restore_effect_if_active(owner)
	field.apply_save_data({})
	field.restore_effect_if_active(owner)
	_expect(field.field_node == null and not field.self_buff_active, "Loading an inactive field must clear the previous visual and haste")


func _check_cannon_and_blast(owner) -> void:
	_grant(owner, "mechanic_missile_volley", [1])
	var cannon = owner.mechanic_missile_volley_ability
	cannon.deploy_cannon(owner)
	cannon._fire(owner, cannon.active_cannons[0])
	_expect(owner.shots.size() == 3 and is_zero_approx(owner.shots[0]["node"].impact_blast_radius), "Cluster cannon alone must not grant explosive shells")
	owner.shots.clear()
	_grant(owner, "mechanic_missile_volley", [2])
	cannon._fire(owner, cannon.active_cannons[0])
	_expect(owner.shots.size() == 3, "Cluster cannon must fire three shells")
	for shot in owner.shots:
		_expect(is_equal_approx(shot["node"].impact_blast_radius, 140.0), "Every shell must receive its independent explosive payload")
	var bullet := BULLET.new()
	current_scene.add_child(bullet)
	bullet.reset_projectile({"source_player": owner, "source_role_id": "mechanic", "damage": 250.0, "impact_blast_radius": 140.0, "pierce_count": 1})
	var target := DamageTarget.new()
	current_scene.add_child(target)
	BULLET.split_burst_budget_frame = Engine.get_physics_frames()
	BULLET.split_burst_budget_used = 999
	bullet._apply_hit(target)
	_expect(owner.hits.size() == 1 and is_equal_approx(owner.hits[0]["damage"], 250.0), "Exhausted visual budget must not suppress explosive damage")
	_expect(is_equal_approx(target.current_health, 750.0), "A real projectile hit must preserve direct damage alongside the blast")
	bullet._apply_impact_blast(Vector2.ZERO)
	_expect(owner.hits.size() == 1, "A shell may only explode once")
	bullet.impact_blast_radius = 140.0
	bullet.reset_projectile({})
	_expect(is_zero_approx(bullet.impact_blast_radius), "Pooled shells must not pass explosive payload to ordinary bullets")


func _check_save(world: Node2D) -> void:
	var player = PLAYER.instantiate()
	world.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.configure_story_loadout(["mechanic", "swordsman", "gunner"])
	for skill_id in ["drone", "mine", "emp_burst", "tulip_turret", "missile_volley"]:
		FIXTURE.SKILLS.force_unlock_skill(player, skill_id, 1)
	for progress_id in LEVELS.MECHANIC_TALENTS.DEFINITIONS:
		LEVELS.add_skill_level(player, "mechanic", progress_id, 9)
	player.mechanic_drone_ability.try_trigger(player)
	player.mechanic_drone_ability.active_guards[0]["charges"] = 2
	player.mechanic_mine_ability.try_trigger(player)
	player.mechanic_emp_burst_ability.try_trigger(player)
	player.mechanic_emp_burst_ability.field_remaining = 7.75
	player.mechanic_emp_burst_ability.tick_elapsed = 0.13
	player.mechanic_missile_volley_ability.deploy_cannon(player)
	player.mechanic_tulip_turret_ability.deploy_turret(player)
	player.mechanic_role.perform_enter(player, "mechanic", 0, 1.25)
	var before: Dictionary = player.role_special_states.duplicate(true)
	for skill_id in ["drone", "mine", "emp_burst", "tulip_turret", "missile_volley"]:
		var info := COOLDOWNS.get_skill_info(player, "mechanic", skill_id)
		_expect(str(info.get("effect_note", "")).contains("："), "HUD must explain granted talents: " + skill_id)
	var basic: Dictionary = COOLDOWNS.get_role_skill_cooldown_slots(player, "mechanic", 0.5)[0]
	_expect(str(basic.get("effect_note", "")).contains("蜂群指令") and str(basic).contains("3 只蜘蛛"), "Basic attack HUD must explain its owned talents and real quantity")
	_expect(player.role_special_states == before, "Reading talent HUD data must not mutate the build")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.get_save_data()))
	var restored = PLAYER.instantiate()
	world.add_child(restored)
	restored.set_process(false)
	restored.set_physics_process(false)
	for _attempt in range(2):
		restored.apply_save_data(saved)
		for progress_id in LEVELS.MECHANIC_TALENTS.DEFINITIONS:
			_expect(LEVELS.get_granted_talent_slots(restored, "mechanic", progress_id) == [1, 2], "JSON save must retain every mechanic talent")
		_expect(restored.mechanic_drone_ability.active_guards.size() == 2 and restored.mechanic_drone_ability.active_guards[0]["charges"] == 2, "Loading must preserve guards without spawning a new pair or refilling charges")
		_expect(restored.mechanic_mine_ability.active_mines.size() == 7 and restored.mechanic_missile_volley_ability.active_cannons.size() == 1, "Loading must preserve deployment quantities")
		_expect(restored.mechanic_tulip_turret_ability.active_turrets.size() == 3, "Loading must preserve one active and two entry turrets")
		_expect(is_equal_approx(restored.mechanic_emp_burst_ability.field_remaining, 7.75) and is_equal_approx(restored.mechanic_emp_burst_ability.tick_elapsed, 0.13), "Loading must preserve mobile field timers")
		_expect(is_equal_approx(restored.mechanic_role.get_part_interval(restored), 1.325) and restored.mechanic_role.get_parts_max(restored) == 21, "Loading must apply trait level and talent effects once")
	saved["role_special_states"]["mechanic"]["skill_levels"]["mechanic_basic"] = 5
	saved["role_special_states"]["mechanic"]["skill_talent_slots"]["mechanic_basic"] = {"picked": 2, "granted": [2]}
	restored.apply_save_data(saved)
	_expect(LEVELS.get_granted_talent_slots(restored, "mechanic", "mechanic_basic") == [2] and restored.mechanic_role.get_spider_count(restored) == 1 and is_equal_approx(restored.mechanic_role.get_spider_speed(restored), 280.0), "A level-five save must keep only its selected effect, without granting the other early")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


class DamageTarget:
	extends Node2D
	var current_health := 1000.0

	func take_damage(amount: float, _critical: bool = false) -> bool:
		current_health -= amount
		return false

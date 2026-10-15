extends SceneTree

const LEVELS := preload("res://scripts/player/player_skill_level_system.gd")
const EFFECTS := preload("res://scripts/player/player_skill_level_effect_flow.gd")
const BUILDS := preload("res://scripts/player/player_build_system.gd")
const SKILLS := preload("res://scripts/player/player_blessing_skill_state.gd")
const ROLE := preload("res://scripts/player/roles/mechanic_role.gd")
const TURRET := preload("res://scripts/abilities/mechanic_tulip_turret_ability.gd")
const MINE := preload("res://scripts/abilities/mechanic_mine_ability.gd")
const FIELD := preload("res://scripts/abilities/mechanic_emp_burst_ability.gd")
const GUARD := preload("res://scripts/abilities/mechanic_drone_ability.gd")
const CANNON := preload("res://scripts/abilities/mechanic_missile_volley_ability.gd")
const PLAYER := preload("res://scenes/player.tscn")
const SHEET := preload("res://scripts/player/player_character_sheet.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var owner := CombatOwner.new()
	world.add_child(owner)
	owner.target = Node2D.new()
	world.add_child(owner.target)
	_check_level_one(owner)
	_check_previews_and_caps(owner)
	_check_basic_and_trait(owner)
	_check_turret_sources(owner)
	_check_mines_and_field(owner)
	_check_guards_and_cannon(owner)
	_check_player_roundtrip(world)
	world.queue_free()
	await process_frame
	current_scene = null
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("MECHANIC_SKILL_LEVEL_EFFECT_SMOKE_OK")
	quit(0 if failures.is_empty() else 1)


func _check_level_one(owner: CombatOwner) -> void:
	_expect(is_equal_approx(owner.mechanic_role.get_basic_attack_damage_ratio(owner), 1.0), "Level 1 basic damage should remain 100%")
	_expect(is_equal_approx(owner.mechanic_role.get_part_interval(owner), 4.0), "Level 1 parts should take 4 seconds")
	_expect(owner.mechanic_role.get_parts_max(owner) == 10, "Level 1 parts cap should remain 10")
	_expect(is_equal_approx(owner.mechanic_tulip_turret_ability._get_damage_ratio(owner), 1.2), "Level 1 turret damage should remain 120%")
	_expect(is_equal_approx(owner.mechanic_mine_ability._get_radius(owner), 80.0), "Level 1 mine radius should remain 80")
	_expect(is_equal_approx(owner.mechanic_emp_burst_ability._get_damage_ratio(owner), 0.3), "Level 1 field damage should remain 30%")
	_expect(owner.mechanic_drone_ability._get_max_charges(owner) == 3, "Level 1 guard should retain 3 charges")
	_expect(is_equal_approx(owner.mechanic_missile_volley_ability._get_duration(owner), 10.0), "Level 1 cannon should last 10 seconds")


func _check_previews_and_caps(owner: CombatOwner) -> void:
	var before := owner.role_special_states.duplicate(true)
	for progress_id in LEVELS.get_role_progress_ids("mechanic"):
		if progress_id == "mechanic_ultimate":
			continue
		var display := EFFECTS.get_upgrade_display(owner, "mechanic", progress_id)
		_expect(not (display["effect_rows"] as Array).is_empty(), "Every mechanic line needs comparison rows: " + progress_id)
		_expect(not str(display["description"]).contains("待补充"), "Every mechanic line needs growth information: " + progress_id)
	_expect(owner.role_special_states == before, "Reading growth previews must not initialize state")
	_set_level(owner, "mechanic_trait", 2)
	_expect(EFFECTS.get_upgrade_preview_text(owner, "mechanic", "mechanic_trait").contains("零件上限 +1"), "Level 3 trait should preview its cap milestone")
	_set_level(owner, "mechanic_drone", 4)
	_expect(EFFECTS.get_upgrade_preview_text(owner, "mechanic", "mechanic_drone").contains("每台抵挡次数 +1"), "Level 5 guard should preview its extra block")
	_expect(EFFECTS.get_upgrade_display(owner, "mechanic", "mechanic_drone")["card_highlight"] == "每台抵挡次数 +1", "Real block growth should take priority over placeholder talent slots")
	for progress_id in LEVELS.get_role_progress_ids("mechanic"):
		if progress_id == "mechanic_ultimate":
			continue
		_set_level(owner, progress_id, 10)
		_expect(EFFECTS.get_upgrade_preview_text(owner, "mechanic", progress_id).is_empty(), "Max-level lines must not preview an eleventh level")
	_expect(LEVELS.get_upgradeable_progress_ids(owner, "mechanic").is_empty(), "Maxed mechanic should leave the upgrade pool")
	_expect(EFFECTS.get_upgrade_preview_text(owner, "mechanic", "mechanic_ultimate").is_empty(), "Ultimate must stay outside skill-level growth")
	owner.role_special_states.clear()


func _check_basic_and_trait(owner: CombatOwner) -> void:
	owner.target.position = Vector2(330.0, 0.0)
	owner.mechanic_role.perform_attack(owner)
	_expect(owner.shots.is_empty(), "Level 1 spider must not target beyond 300")
	BUILDS.apply_option_with_result(owner, "role_build:mechanic:skill_up_mechanic_basic")
	_expect(LEVELS.get_skill_level(owner, "mechanic", "mechanic_basic") == 2, "Formal upgrade cards should raise mechanic skill levels")
	_set_level(owner, "mechanic_basic", 5)
	owner.mechanic_role.perform_attack(owner)
	_expect(owner.shots.size() == 1, "Level 5 basic should acquire a target at 330")
	_expect(is_equal_approx(float(owner.shots.back()["damage"]), 140.0), "Level 5 spider should deal 140% damage")
	_expect(is_equal_approx((owner.shots.back()["node"] as TestProjectile).speed, 140.0), "Level 5 spider must use the upgraded travel speed")
	_set_level(owner, "mechanic_trait", 3)
	owner.mechanic_role.update_trait_state(owner, 7.5)
	_expect(owner.mechanic_role.get_parts_count(owner) == 2, "Level 3 trait should produce two parts in 7.5 seconds")
	_expect(owner.mechanic_role.get_parts_max(owner) == 11, "Level 3 trait should allow eleven parts")
	_expect(is_equal_approx(owner.mechanic_role.get_summon_damage_multiplier(owner), 1.1), "Two level 3 parts should grant 10% summon damage")
	owner.active_role_id = "gunner"
	owner.mechanic_role.update_trait_state(owner, 50.0)
	_expect(owner.mechanic_role.get_parts_count(owner) == 2, "Inactive mechanic must not produce parts")
	owner.active_role_id = "mechanic"
	_set_level(owner, "mechanic_trait", 10)
	_expect(is_equal_approx(owner.mechanic_role.get_part_interval(owner), 2.65), "Level 10 parts should take 2.65 seconds")
	_expect(owner.mechanic_role.get_parts_max(owner) == 13, "Level 10 part cap should be thirteen")
	_expect(is_equal_approx(owner.mechanic_role.get_part_damage_bonus(owner), 0.085), "Level 10 parts should grant 8.5% each")
	owner._get_role_special_state("mechanic")["talent_runtime"] = {"parts": 0}


func _check_turret_sources(owner: CombatOwner) -> void:
	_set_level(owner, "mechanic_entry", 5)
	_set_level(owner, "mechanic_tulip_turret", 2)
	var turret = owner.mechanic_tulip_turret_ability
	owner.mechanic_role.perform_enter(owner, "mechanic", 0, 1.25)
	turret.deploy_turret(owner)
	_expect(is_equal_approx(float(turret.active_turrets[0]["remaining"]), 9.2), "Entry turret should use entry level for duration")
	_expect(is_equal_approx(float(turret.active_turrets[1]["remaining"]), 8.3), "Active turret should use active level for duration")
	turret._fire(owner, turret.active_turrets[0])
	_expect(is_equal_approx(float(owner.shots.back()["damage"]), 200.0), "Entry turret should apply level 5 and the cast multiplier")
	turret._fire(owner, turret.active_turrets[1])
	_expect(is_equal_approx(float(owner.shots.back()["damage"]), 130.0), "Active turret must not inherit entry level")
	var saved: Dictionary = turret.get_save_data()
	turret.apply_save_data(saved)
	turret.restore_effect_if_active(owner)
	_expect(turret.active_turrets[0]["progress_id"] == "mechanic_entry", "Restored turret should retain entry source")
	_expect(turret.active_turrets[1]["progress_id"] == "mechanic_tulip_turret", "Restored turret should retain active source")
	_set_level(owner, "mechanic_entry", 7)
	turret._fire(owner, turret.active_turrets[0])
	_expect(is_equal_approx(float(owner.shots.back()["damage"]), 225.0), "Restored entry turret should read its own updated level")
	turret._fire(owner, turret.active_turrets[1])
	_expect(is_equal_approx(float(owner.shots.back()["damage"]), 130.0), "Entry upgrade must not affect the restored active turret")
	turret.apply_save_data({"turrets": [{"remaining": 1.0, "progress_id": "invalid"}]})
	turret.restore_effect_if_active(owner)
	_expect(turret.active_turrets[0]["progress_id"] == "mechanic_tulip_turret", "Invalid save source should fall back to the active turret")
	turret.apply_save_data({"turrets": [{"remaining": 1.0}]})
	turret.restore_effect_if_active(owner)
	_expect(turret.active_turrets[0]["progress_id"] == "mechanic_tulip_turret", "Old saves without a source should still restore")


func _check_mines_and_field(owner: CombatOwner) -> void:
	owner.target.position = Vector2(110.0, 0.0)
	_expect(not owner.mechanic_mine_ability._has_enemy_in_range(owner, Vector2.ZERO), "Level 1 mine should not trigger at 110")
	_set_level(owner, "mechanic_mine", 10)
	var mine = owner.mechanic_mine_ability
	_expect(mine._has_enemy_in_range(owner, Vector2.ZERO), "Level 10 mine should trigger inside its expanded radius")
	mine._explode(owner, Vector2.ZERO)
	_expect(is_equal_approx(float(owner.hits.back()["damage"]), 335.0), "Level 10 mine should deal 335% damage")
	_expect(is_equal_approx(float(owner.hits.back()["radius"]), 116.0), "Mine blast radius should match trigger radius")
	_expect(mine._get_mine_count(owner) == 3, "Skill levels must not multiply mine count")
	owner.talents["mechanic_level_talent_mine_2"] = true
	_expect(is_equal_approx(mine._get_radius(owner), 174.0), "Saved radius talent should multiply the grown radius")
	owner.talents.clear()
	var field = owner.mechanic_emp_burst_ability
	field.try_trigger(owner)
	_set_level(owner, "mechanic_emp_burst", 10)
	owner.position = Vector2(500.0, 0.0)
	owner.healed = 0.0
	field.update(owner, 0.5)
	_expect(field.self_buff_active, "Expanded field should grant its self buff at distance 500")
	_expect(is_equal_approx(owner.healed, 1.5), "Standing inside the expanded field should heal the active role")
	_expect(is_equal_approx(float(owner.hits.back()["radius"]), 517.5), "Field damage should use its grown radius")
	_expect(is_equal_approx(float(owner.hits.back()["damage"]), 48.0), "Level 10 field should deal 48% per tick")
	_expect(is_equal_approx(float(field.field_node.get_node("Ripple").radius), 517.5), "Live field visual must match collision after an upgrade")
	owner.position = Vector2.ZERO


func _check_guards_and_cannon(owner: CombatOwner) -> void:
	var guard = owner.mechanic_drone_ability
	for checkpoint in [[1, 14.0, 3], [5, 12.8, 4], [10, 11.3, 5]]:
		_set_level(owner, "mechanic_drone", int(checkpoint[0]))
		guard.cooldown_remaining = 0.0
		guard.try_trigger(owner)
		_expect(is_equal_approx(guard.cooldown_remaining, float(checkpoint[1])), "Guard cooldown should use its skill level")
		_expect(guard.active_guards.back()["charges"] == int(checkpoint[2]), "New guards should use level-based charges")
	_expect(guard.active_guards[0]["charges"] == 3, "Upgrading must not refill an existing guard")
	_expect(guard._get_max_guards(owner) == 5, "Skill levels must retain the five-guard cap")
	for hit in range(12):
		_expect(guard.try_block_damage(owner), "Guard should consume each recorded charge")
	_expect(not guard.try_block_damage(owner), "Exhausted guards must not block a thirteenth hit")
	_set_level(owner, "mechanic_missile_volley", 10)
	var cannon = owner.mechanic_missile_volley_ability
	cannon.deploy_cannon(owner)
	_expect(is_equal_approx(float(cannon.active_cannons[0]["remaining"]), 13.6), "Level 10 cannon should last 13.6 seconds")
	cannon._fire(owner, cannon.active_cannons[0])
	_expect(is_equal_approx(float(owner.shots.back()["damage"]), 335.0), "Level 10 cannon should fire for 335% damage")
	owner._get_role_special_state("mechanic")["build_levels"] = {"missile_damage": 1}
	_expect(is_equal_approx(cannon._get_damage_ratio(owner), 4.02), "Saved build modifiers should still compose with level growth")


func _check_player_roundtrip(world: Node2D) -> void:
	var player = PLAYER.instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.configure_story_loadout(["mechanic", "swordsman", "gunner"])
	for skill_id in ["drone", "mine", "emp_burst", "tulip_turret", "missile_volley"]:
		SKILLS.force_unlock_skill(player, skill_id, 1)
	for progress_id in LEVELS.get_role_progress_ids("mechanic"):
		if progress_id != "mechanic_ultimate":
			LEVELS.add_skill_level(player, "mechanic", progress_id, 9)
	player.mechanic_tulip_turret_ability.deploy_turret(player)
	player.mechanic_role.perform_enter(player, "mechanic", 0, 1.0)
	var before: Dictionary = player.role_special_states.duplicate(true)
	var info := SHEET.get_innate_skill_info(player, "mechanic", "mechanic_trait")
	_expect(str(info).contains("1.33 秒"), "Character sheet should include the granted offline factory talent")
	SHEET.get_innate_skill_info(player, "mechanic", "mechanic_basic")
	SHEET.get_innate_skill_info(player, "mechanic", "mechanic_entry")
	_expect(player.role_special_states == before, "Character sheet must remain read-only")
	var saved: Dictionary = player.get_save_data()
	var restored = PLAYER.instantiate()
	world.add_child(restored)
	restored.set_physics_process(false)
	restored.set_process(false)
	restored.apply_save_data(saved)
	for progress_id in LEVELS.get_role_progress_ids("mechanic"):
		if progress_id != "mechanic_ultimate":
			_expect(LEVELS.get_skill_level(restored, "mechanic", progress_id) == 10, "Save restoration should keep mechanic levels: " + progress_id)
	var turrets: Array = restored.mechanic_tulip_turret_ability.active_turrets
	_expect(turrets.size() == 3 and turrets[0]["progress_id"] == "mechanic_tulip_turret" and turrets[1]["progress_id"] == "mechanic_entry" and turrets[2]["progress_id"] == "mechanic_entry", "Player save should restore both independent turret sources and the second entry turret")
	_expect(is_equal_approx(restored.mechanic_role.get_basic_attack_damage_ratio(restored), 1.9), "Restored basic damage must apply growth once")
	_expect(restored.mechanic_drone_ability._get_max_charges(restored) == 5, "Restored guard growth must apply once")


func _set_level(owner, progress_id: String, level: int) -> void:
	var state: Dictionary = owner._get_role_special_state("mechanic")
	if not state.has("skill_levels"):
		state["skill_levels"] = {}
	state["skill_levels"][progress_id] = level


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


class TestProjectile:
	extends Node2D
	var custom_sprite_frames: SpriteFrames
	var animated_scene_size := Vector2.ZERO
	var animated_visible_bounds := Rect2()
	var speed := 0.0
	var visual_scale_multiplier := 1.0
	var hit_radius := 0.0
	var pierce_count := 0
	var impact_blast_radius := 0.0


class CombatOwner:
	extends Node2D
	var role_special_states: Dictionary = {}
	var blessing_skill_state := {"unlocked": {"drone": true, "mine": true, "emp_burst": true, "tulip_turret": true, "missile_volley": true}}
	var mechanic_role = ROLE.new()
	var mechanic_tulip_turret_ability = TURRET.new()
	var mechanic_mine_ability = MINE.new()
	var mechanic_emp_burst_ability = FIELD.new()
	var mechanic_drone_ability = GUARD.new()
	var mechanic_missile_volley_ability = CANNON.new()
	var active_role_id := "mechanic"
	var facing_direction := Vector2.RIGHT
	var is_dead := false
	var level_up_active := false
	var roles: Array = []
	var talents: Dictionary = {}
	var target: Node2D
	var shots: Array[Dictionary] = []
	var hits: Array[Dictionary] = []
	var healed := 0.0
	var healed_role_id := ""

	func _get_role_special_state(role_id: String) -> Dictionary:
		if not role_special_states.has(role_id):
			role_special_states[role_id] = {}
		return role_special_states[role_id]

	func _get_active_role() -> Dictionary:
		return {"id": active_role_id}

	func _get_role_damage(_role_id: String) -> float:
		return 100.0

	func _get_role_max_health(_role_id: String) -> float:
		return 100.0

	func _has_level_talent(talent_id: String) -> bool:
		return bool(talents.get(talent_id, false))

	func _is_blessing_skill_unlocked(skill_id: String) -> bool:
		return bool(blessing_skill_state["unlocked"].get(skill_id, false))

	func _get_closest_enemy() -> Node2D:
		return target

	func _get_enemy_nearest_to_position(_position: Vector2) -> Node2D:
		return target

	func _get_live_enemies() -> Array:
		return [target]

	func _spawn_bullet(_target: Node2D, damage: float, _color: Color, role_id: String, _origin: Variant = null):
		var bullet := TestProjectile.new()
		add_child(bullet)
		shots.append({"node": bullet, "damage": damage, "role_id": role_id})
		return bullet

	func _damage_enemies_in_radius(center: Vector2, radius: float, damage: float, _vulnerability: float, slow: float, duration: float, _role_id: String) -> int:
		hits.append({"center": center, "radius": radius, "damage": damage, "slow": slow, "slow_duration": duration})
		return 1

	func _heal_role(role_id: String, value: float) -> void:
		healed += value
		healed_role_id = role_id

	func _register_attack_result(_role_id: String, _hits: int, _critical: bool) -> void:
		pass

	func _show_switch_banner(_title: String, _detail: String, _color: Color) -> void:
		pass

	func _spawn_combat_tag(_position: Vector2, _text: String, _color: Color) -> void:
		pass

	func _spawn_ring_effect(_position: Vector2, _radius: float, _color: Color, _segments: float, _duration: float) -> Node2D:
		return null

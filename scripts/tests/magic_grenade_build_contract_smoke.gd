extends SceneTree

const BUILD := preload("res://scripts/player/player_gunner_magic_grenade_build.gd")
const FLOW := preload("res://scripts/player/player_gunner_magic_grenade_flow.gd")
const LEVELS := preload("res://scripts/player/player_skill_level_system.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var owner := OwnerStub.new()
	_set_level(owner, 3)
	assert(is_equal_approx(BUILD.damage_ratio(owner), 2.75))
	_set_level(owner, 7)
	assert(is_equal_approx(BUILD.damage_ratio(owner), 4.25))
	assert(FLOW.get_grenade_count(owner) == 4)
	_set_level(owner, 9)
	assert(not LEVELS.is_progress_upgradeable(owner, "gunner_magic_grenade"))
	assert(BUILD.pending_stage(owner) == 4)
	assert(BUILD.choose(owner, 4, 2))
	assert(BUILD.has_choice(owner, "lucky_round"))
	assert(BUILD.pending_stage(owner) == 8)
	assert(BUILD.choose(owner, 8, 1))
	assert(BUILD.pending_stage(owner) == 9)
	assert(BUILD.choose(owner, 9, 2))
	assert(BUILD.has_choice(owner, "mental_shock"))
	assert(BUILD.has_choice(owner, "magic_charge"))
	assert(FLOW.get_blast_radius(owner) == 75.0)
	assert(FLOW.get_blast_radius_for_hit(owner, false) == 75.0)
	assert(FLOW.get_blast_radius_for_hit(owner, true) == 125.0)
	print("MAGIC_GRENADE_BUILD_CONTRACT_SMOKE_OK")
	quit(0)

func _set_level(owner: OwnerStub, level: int) -> void:
	owner.role_special_states["gunner"] = {
		"skill_levels": {"gunner_magic_grenade": level},
		"gunner_magic_grenade_build": {}
	}

class OwnerStub:
	extends Node
	var role_special_states: Dictionary = {}
	var blessing_skill_state: Dictionary = {}


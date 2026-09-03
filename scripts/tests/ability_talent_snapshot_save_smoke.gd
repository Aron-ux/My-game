extends SceneTree

const BladeStorm := preload("res://scripts/abilities/swordsman_blade_storm_ability.gd")
const CrescentWave := preload("res://scripts/abilities/swordsman_crescent_wave_ability.gd")
const InfiniteReload := preload("res://scripts/abilities/gunner_infinite_reload_ability.gd")
const ShrapnelField := preload("res://scripts/abilities/gunner_shrapnel_field_ability.gd")
const MetaField := preload("res://scripts/abilities/mage_meta_field_ability.gd")
const TidalSurge := preload("res://scripts/abilities/mage_tidal_surge_ability.gd")
const JudgementSword := preload("res://scripts/abilities/swordsman_judgement_sword_ability.gd")
const MagicEye := preload("res://scripts/abilities/gunner_magic_eye_ability.gd")
const Fireball := preload("res://scripts/abilities/mage_fireball_ability.gd")
const JudgementSwordFlow := preload("res://scripts/player/player_swordsman_judgement_sword_flow.gd")
const MagicEyeFlow := preload("res://scripts/player/player_gunner_magic_eye_flow.gd")
const FireballFlow := preload("res://scripts/player/player_mage_fireball_flow.gd")
const RunSaveState := preload("res://scripts/player/player_run_save_state.gd")

class TalentOwner:
	extends RefCounted
	var live_talents: Array[String] = []
	func _has_skill_talent(talent_id: String) -> bool:
		return live_talents.has(talent_id)

class AbilityOwner:
	extends RefCounted
	var swordsman_blade_storm_ability = null
	var swordsman_crescent_wave_ability = null
	var swordsman_knight_thrust_ability = null
	var swordsman_king_blade_ability = null
	var swordsman_judgement_sword_ability = null
	var gunner_infinite_reload_ability = null
	var gunner_shrapnel_field_ability = null
	var gunner_explosive_round_ability = null
	var gunner_magic_grenade_ability = null
	var gunner_magic_eye_ability = null
	var mage_meta_field_ability = null
	var mage_tidal_surge_ability = null
	var mage_flame_path_ability = null
	var mage_dark_contract_ability = null
	var mage_fireball_ability = null

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var owner := TalentOwner.new()
	owner.live_talents = [
		"swordsman_blade_storm_retain",
		"gunner_infinite_dual",
		"mage_meta_collapse"
	]

	var blade := BladeStorm.new()
	blade.apply_save_data({
		"active_remaining": 1.2,
		"ring_visual_tick_index": 3,
		"base_tick_count": 4,
		"cast_elapsed": 0.8,
		"talent_ids": ["swordsman_blade_storm_stationary"],
		"talent_snapshot_valid": true
	})
	assert(blade._has_talent(owner, "swordsman_blade_storm_stationary"))
	assert(not blade._has_talent(owner, "swordsman_blade_storm_retain"))
	assert(int(blade.get_save_data()["base_tick_count"]) == 4)
	blade.active_remaining = 0.0
	assert(blade._has_talent(owner, "swordsman_blade_storm_stationary"))
	blade.stop()
	assert(blade._has_talent(owner, "swordsman_blade_storm_retain"))

	var infinite := InfiniteReload.new()
	infinite.apply_save_data({
		"active_remaining": 1.0,
		"sweep_elapsed": 0.7,
		"hit_during_cast": true,
		"talent_ids": ["gunner_infinite_axis"],
		"talent_snapshot_valid": true
	})
	assert(infinite._has_talent(owner, "gunner_infinite_axis"))
	assert(not infinite._has_talent(owner, "gunner_infinite_dual"))
	assert(bool(infinite.get_save_data()["hit_during_cast"]))
	infinite.active_remaining = 0.0
	assert(infinite._has_talent(owner, "gunner_infinite_axis"))
	infinite.stop()
	assert(infinite._has_talent(owner, "gunner_infinite_dual"))

	var meta := MetaField.new()
	meta.apply_save_data({
		"active_remaining": 1.0,
		"expansion_tick_count": 2,
		"talent_ids": ["mage_meta_transfer"],
		"talent_snapshot_valid": true
	})
	assert(meta._has_talent(owner, "mage_meta_transfer"))
	assert(not meta._has_talent(owner, "mage_meta_collapse"))
	assert(int(meta.get_save_data()["expansion_tick_count"]) == 2)
	meta.active_remaining = 0.0
	assert(meta._has_talent(owner, "mage_meta_transfer"))
	meta.stop()
	assert(meta._has_talent(owner, "mage_meta_collapse"))

	var crescent := CrescentWave.new()
	crescent.cast_talent_ids = ["swordsman_crescent_return"]
	crescent.cast_talent_snapshot_valid = true
	crescent.active_crescent_projectiles.append({
		"origin": Vector2(10.0, 20.0),
		"direction": Vector2.RIGHT,
		"length": 120.0,
		"width": 32.0,
		"visual_scale": 0.6,
		"damage_amount": 55.0,
		"duration": 0.8,
		"elapsed": 0.3,
		"last_damage_progress": 0.375,
		"returned": false,
		"talent_ids": ["swordsman_crescent_return"]
	})
	var crescent_copy := CrescentWave.new()
	crescent_copy.apply_save_data(_json_roundtrip(crescent.get_save_data()))
	assert(crescent_copy.pending_saved_projectiles.size() == 1)
	assert((crescent_copy.pending_saved_projectiles[0]["talent_ids"] as Array).has("swordsman_crescent_return"))

	var shrapnel := ShrapnelField.new()
	shrapnel.active_fields.append({
		"center": Vector2(30.0, 40.0),
		"remaining": 2.0,
		"tick_remaining": 0.2,
		"tick_interval": 0.5,
		"radius": 180.0,
		"effect_scale": 1.0,
		"damage": 44.0,
		"slow_multiplier": 0.7,
		"talent_ids": ["gunner_shrapnel_rend"]
	})
	var shrapnel_copy := ShrapnelField.new()
	shrapnel_copy.apply_save_data(_json_roundtrip(shrapnel.get_save_data()))
	assert(shrapnel_copy.pending_saved_fields.size() == 1)
	assert((shrapnel_copy.pending_saved_fields[0]["talent_ids"] as Array).has("gunner_shrapnel_rend"))
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var effect_owner := Node2D.new()
	scene.add_child(effect_owner)
	crescent_copy.restore_effect_if_active(effect_owner)
	shrapnel_copy.restore_effect_if_active(effect_owner)
	assert(crescent_copy.active_crescent_projectiles.size() == 1)
	assert(is_instance_valid(crescent_copy.active_crescent_projectiles[0]["projectile"]))
	assert(shrapnel_copy.active_fields.size() == 1)
	assert(is_instance_valid(shrapnel_copy.active_fields[0]["root"]))

	var tidal := TidalSurge.new()
	tidal.apply_save_data({
		"cooldown_remaining": 6.0,
		"next_wave_token": 9,
		"talent_ids": ["mage_surge_heavy"],
		"talent_snapshot_valid": true
	})
	assert(tidal._has_talent(owner, "mage_surge_heavy"))
	assert(int(tidal.get_save_data()["next_wave_token"]) == 9)

	assert(JudgementSwordFlow != null)
	assert(MagicEyeFlow.is_inside_beam(Vector2(80.0, 0.0), Vector2(80.0, 0.0), Vector2.RIGHT, 160.0, 64.0))
	assert(not MagicEyeFlow.is_inside_beam(Vector2(80.0, 50.0), Vector2(80.0, 0.0), Vector2.RIGHT, 160.0, 64.0))
	assert(FireballFlow != null)

	var judgement := JudgementSword.new()
	judgement.active_remaining = 4.0
	judgement.shockwave_timer = 0.8
	judgement.sword_position = Vector2(120.0, -80.0)
	var judgement_copy := JudgementSword.new()
	judgement_copy.apply_save_data(_json_roundtrip(judgement.get_save_data()))
	assert(is_equal_approx(judgement_copy.active_remaining, 4.0))
	assert(is_equal_approx(judgement_copy.shockwave_timer, 0.8))
	assert(judgement_copy.sword_position == Vector2(120.0, -80.0))

	var eye := MagicEye.new()
	eye.shots_remaining = 3
	eye.shot_timer = 0.25
	eye.locked_direction = Vector2(0.0, -1.0)
	var eye_copy := MagicEye.new()
	eye_copy.apply_save_data(_json_roundtrip(eye.get_save_data()))
	assert(eye_copy.shots_remaining == 3)
	assert(is_equal_approx(eye_copy.shot_timer, 0.25))
	assert(eye_copy.locked_direction == Vector2(0.0, -1.0))

	var fireball := Fireball.new()
	fireball.active_fire_fields.append({
		"center": Vector2(40.0, 60.0),
		"remaining": 2.5,
		"tick_elapsed": 0.3
	})
	var fireball_copy := Fireball.new()
	fireball_copy.apply_save_data(_json_roundtrip(fireball.get_save_data()))
	assert(fireball_copy.pending_saved_fields.size() == 1)
	assert(is_equal_approx(float(fireball_copy.pending_saved_fields[0]["remaining"]), 2.5))
	assert((fireball_copy.pending_saved_fields[0]["center"] as Array).size() == 2)

	var runtime_owner := AbilityOwner.new()
	RunSaveState._apply_ability_save_data(runtime_owner, {
		"gunner_infinite_reload_cooldown_remaining": 3.0,
		"mage_tidal_surge_cooldown_remaining": 4.0,
		"mage_meta_field_cooldown_remaining": 5.0,
		"swordsman_blade_storm_cooldown_remaining": 6.0,
		"swordsman_crescent_wave_cooldown_remaining": 7.0,
		"gunner_shrapnel_field_cooldown_remaining": 8.0
	})
	assert(is_equal_approx(runtime_owner.gunner_infinite_reload_ability.cooldown_remaining, 3.0))
	assert(is_equal_approx(runtime_owner.mage_tidal_surge_ability.cooldown_remaining, 4.0))
	var nested_runtime := RunSaveState._get_ability_runtime(runtime_owner)
	for required_key in [
		"blade_storm",
		"knight_thrust",
		"crescent_wave",
		"infinite_reload",
		"shrapnel_field",
		"explosive_round",
		"magic_grenade",
		"magic_eye",
		"meta_field",
		"flame_path",
		"dark_contract",
		"fireball",
		"surging_wave",
		"king_blade",
		"judgement_sword"
	]:
		assert(nested_runtime.has(required_key), "ability runtime should keep entry %s" % required_key)
	RunSaveState._apply_ability_save_data(runtime_owner, {
		"ability_runtime": {
			"infinite_reload": {
				"cooldown_remaining": 9.0,
				"talent_ids": ["gunner_infinite_axis"],
				"talent_snapshot_valid": true
			}
		},
		"gunner_infinite_reload_cooldown_remaining": 1.0
	})
	assert(is_equal_approx(runtime_owner.gunner_infinite_reload_ability.cooldown_remaining, 9.0))
	assert(runtime_owner.gunner_infinite_reload_ability.cast_talent_ids.has("gunner_infinite_axis"))

	print("ABILITY_TALENT_SNAPSHOT_SAVE_SMOKE_OK")
	quit(0)

func _json_roundtrip(value: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	assert(parsed is Dictionary)
	return parsed as Dictionary

extends SceneTree

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const ENEMY_BOSS_STATE := preload("res://scripts/enemies/enemy_boss_state.gd")

var failures: Array[String] = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene := RuntimeRoot.new()
    root.add_child(scene)
    current_scene = scene

    var target := TargetStub.new()
    target.global_position = Vector2(300.0, 0.0)
    scene.add_child(target)

    var enemy := ENEMY_SCENE.instantiate() as Node2D
    scene.add_child(enemy)
    enemy.target = target
    enemy.apply_enemy_profile("boss", ENEMY_ARCHETYPE_DATABASE.get_profile("boss", "boss_spellcore"))
    if not is_equal_approx(enemy.boss_shield_max_health, 10000.0):
        failures.append("boss spellcore shield should use its configured 10000 health")
    if not is_equal_approx(enemy.current_health, ENEMY_BOSS_STATE.get_phase_bar_max_health(enemy) + 10000.0):
        failures.append("boss spellcore spawn health should include its configured shield")
    enemy.max_health = 300.0
    enemy.current_health = 300.0
    enemy.boss_phase = 3
    enemy.boss_radial_timer = 100.0
    enemy.boss_sine_cooldown = 100.0
    enemy.boss_split_timer = 100.0
    enemy.boss_laser_timer = 100.0
    enemy.boss_orbit_bomb_timer = 100.0
    enemy.boss_peacock_timer = 100.0

    var position_before_shield_update := target.global_position
    ENEMY_BOSS_STATE.update_boss_trait(enemy, 1.0)
    if target.global_position != position_before_shield_update:
        failures.append("final boss shield should disable passive player pull")
    if enemy.boss_orbit_ball != null or enemy.boss_orbit_pull_remaining > 0.0 or enemy.boss_peacock_charge_remaining > 0.0:
        failures.append("final boss shield should disable phase-three aimed attacks")

    enemy.boss_phase = 1
    enemy.current_health = 130.0
    enemy.boss_shield_break_intro_played = false
    enemy.boss_phase_transition_target = 0
    enemy.boss_phase_three_intro_remaining = 0.0
    var killed: bool = bool(enemy.take_batched_damage(40.0))
    if killed:
        failures.append("breaking the final boss shield should not defeat the boss")
    if not enemy.boss_shield_break_intro_played or not enemy.boss_shield_break_visual_intro_active or enemy.boss_phase_transition_target != 0 or enemy.boss_phase_three_intro_remaining <= 0.0:
        failures.append("breaking the final boss shield should start a visual-only phase-three intro")
    if enemy.boss_phase != 1:
        failures.append("breaking the final boss shield should not change the boss skill phase")
    if not is_equal_approx(enemy.current_health, 100.0):
        failures.append("final boss should keep one full health bar during the shield intro")

    ENEMY_BOSS_STATE.update_boss_trait(enemy, 5.0)
    if enemy.boss_phase != 1 or enemy.boss_phase_transition_target != 0 or enemy.boss_shield_break_visual_intro_active or not is_equal_approx(enemy.current_health, 100.0):
        failures.append("final boss should finish the shield intro without entering phase three skills")

    target.global_position = Vector2(300.0, 0.0)
    enemy.boss_radial_timer = 100.0
    enemy.boss_sine_cooldown = 100.0
    enemy.boss_split_timer = 100.0
    enemy.boss_laser_timer = 100.0
    enemy.boss_orbit_bomb_timer = 100.0
    enemy.boss_orbit_bomb_shot_timer = 100.0
    enemy.boss_peacock_timer = 100.0
    var position_after_intro := target.global_position
    ENEMY_BOSS_STATE.update_boss_trait(enemy, 0.5)
    if target.global_position == position_after_intro:
        failures.append("final boss should resume passive player pull after the shield intro")

    scene.queue_free()
    await process_frame
    current_scene = null

    if failures.is_empty():
        print("BOSS_SHIELD_PHASE_SMOKE_OK")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

class TargetStub:
    extends Node2D

    func queue_external_camera_shake(_strength: float, _duration: float) -> void:
        pass

class RuntimeRoot:
    extends Node2D

    func register_runtime_enemy(_enemy: Node) -> void:
        pass

    func unregister_runtime_enemy(_enemy: Node) -> void:
        pass

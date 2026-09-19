extends SceneTree

const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const BODY := preload("res://scripts/enemies/enemy_stalwart_body.gd")


func _init() -> void:
	var profile: Dictionary = DATABASE.get_profile("normal", "chaser")
	assert(is_equal_approx(float(profile.attack), 15.0))
	assert(is_equal_approx(float(profile.armor), 5.0))
	assert(is_equal_approx(float(profile.speed), 60.0))
	assert(is_equal_approx(float(profile.max_health), 30.0))
	assert(is_zero_approx(float(profile.damage_reduction_rate)))
	var enemy := EnemyStub.new()
	enemy.attack = float(profile.attack)
	var second := EnemyStub.new()
	assert(is_equal_approx(BODY.try_trigger(enemy), 22.5))
	assert(is_zero_approx(BODY.try_trigger(enemy)))
	assert(is_equal_approx(BODY.try_trigger(second), 22.5))
	BODY.tick(enemy, 0.5)
	assert(is_zero_approx(BODY.try_trigger(enemy)))
	BODY.tick(enemy, 0.5)
	assert(is_equal_approx(BODY.try_trigger(enemy), 22.5))
	print("ENEMY_STALWART_BODY_SMOKE_OK")
	quit()


class EnemyStub:
	extends RefCounted
	var attack: float = 15.0
	var current_health: float = 30.0
	var stalwart_body_cooldown: float = 0.0
	var pooled_inactive: bool = false
	var rebirth_timer: float = 0.0
	var boss_phase_transition_target: int = 0
	var boss_phase_three_intro_remaining: float = 0.0

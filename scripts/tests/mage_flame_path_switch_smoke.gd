extends SceneTree

const FLAME_PATH_ABILITY := preload("res://scripts/abilities/mage_flame_path_ability.gd")


func _init() -> void:
	var ability := FLAME_PATH_ABILITY.new()
	ability_setup(ability)
	ability_switch(ability)
	print("MAGE_FLAME_PATH_SWITCH_SMOKE_OK")
	quit(0)


func ability_setup(ability) -> void:
	ability.active_remaining = 8.0
	ability.path_remaining = 15.0
	ability.cooldown_remaining = 0.0


func ability_switch(ability) -> void:
	ability.on_role_switched("mage", "swordsman")
	if ability.active_remaining != 0.0:
		push_error("switching away from mage should stop active flame path state")
		quit(1)
	if ability.path_remaining != 15.0:
		push_error("switching away from mage should preserve existing ground path lifetime")
		quit(1)
	if ability.cooldown_remaining != 0.0:
		push_error("switching away from mage should not start flame path cooldown early")
		quit(1)

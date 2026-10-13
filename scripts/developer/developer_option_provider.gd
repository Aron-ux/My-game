extends RefCounted

const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")

static func get_boss_options() -> Array:
	return ENEMY_ARCHETYPE_DATABASE.get_boss_options()


static func get_normal_enemy_options() -> Array:
	return ENEMY_ARCHETYPE_DATABASE.get_normal_enemy_options()


static func get_enemy_options() -> Array:
	return ENEMY_ARCHETYPE_DATABASE.get_developer_enemy_options()

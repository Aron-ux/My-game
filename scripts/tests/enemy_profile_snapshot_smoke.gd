extends SceneTree

const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")

const EXPECTED_IDENTITIES := {
	"chaser": {"behavior": "chaser", "visual_scene": "res://assets/enemies/Mushroom/mushroom.tscn"},
	"shooter": {"behavior": "shooter", "visual_scene": "res://assets/enemies/skullshot/skull-soilder.tscn"},
	"brute": {"behavior": "chaser", "visual_scene": "res://assets/enemies/pumpkin/pumpkin.tscn"},
	"runner": {"behavior": "chaser", "visual_scene": "res://assets/enemies/slime/Slime.tscn"},
	"swarm": {"behavior": "swarm", "visual_scene": "res://assets/enemies/flyingeye/flyingeye.tscn"},
	"dasher": {"behavior": "dash", "visual_scene": "res://assets/enemies/skullsolider/skullsoilder.tscn"},
	"shotgunner": {"behavior": "shooter", "visual_scene": "res://assets/enemies/skullshot/skullshotgunner.tscn"},
	"elite_ram_trail": {"behavior": "dash", "visual_scene": "res://assets/enemies/skullsolider/eliteskull.tscn"},
	"elite_splitshot": {"behavior": "shooter", "visual_scene": "res://assets/enemies/skullshot/SkullElite.tscn"},
	"smallboss_glutton": {"behavior": "glutton", "boss_name": "幽影树人", "visual_scene": "res://assets/enemies/treeboss/treeboss.tscn"},
	"smallboss_rebirth": {"behavior": "skulltomb", "boss_name": "引渡人", "visual_scene": "res://assets/enemies/skulltomb/skulltomb.tscn"},
	"smallboss_turret": {"behavior": "rose", "boss_name": "地瑰灵", "visual_scene": "res://assets/enemies/rose/rose.tscn"},
	"boss_spellcore": {"behavior": "boss", "boss_name": "祸月星核"}
}


func _init() -> void:
	var failures: Array[String] = []
	for archetype in EXPECTED_IDENTITIES:
		_check_identity(archetype, EXPECTED_IDENTITIES[archetype], failures)
	if failures.is_empty():
		print("enemy_profile_snapshot_smoke: OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_identity(archetype: String, expected: Dictionary, failures: Array[String]) -> void:
	var actual: Dictionary = ENEMY_ARCHETYPE_DATABASE.get_profile("normal", archetype)
	if str(actual.get("archetype", "")) != archetype:
		failures.append("%s archetype mismatch" % archetype)
	for key in expected:
		if key == "visual_scene":
			_check_visual_scene(archetype, actual, str(expected[key]), failures)
		elif actual.get(key) != expected[key]:
			failures.append("%s %s expected %s got %s" % [archetype, key, expected[key], actual.get(key)])


func _check_visual_scene(archetype: String, actual: Dictionary, expected_path: String, failures: Array[String]) -> void:
	var scene := actual.get("visual_scene") as PackedScene
	if scene == null or scene.resource_path != expected_path:
		failures.append("%s visual_scene expected %s got %s" % [archetype, expected_path, scene.resource_path if scene != null else "<missing>"])

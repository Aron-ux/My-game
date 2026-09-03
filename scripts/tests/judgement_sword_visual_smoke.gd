extends SceneTree

const PLAYER_TEXTURE_LOADER := preload("res://scripts/player/player_texture_loader.gd")


func _initialize() -> void:
	var texture_cache: Dictionary = {}
	var texture: Texture2D = PLAYER_TEXTURE_LOADER.get_cached_runtime_texture(
		"res://effects/sword/area/sword area.png",
		texture_cache
	)
	assert(texture != null)
	assert(texture_cache.has("res://effects/sword/area/sword area.png"))
	print("JUDGEMENT_SWORD_VISUAL_SMOKE_OK")
	quit()

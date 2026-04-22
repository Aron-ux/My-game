extends AudioStreamPlayer

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"
const MUSIC_VOLUME_KEY := "music_volume_linear"
const MUSIC_MUTED_KEY := "music_muted"
const DEFAULT_VOLUME_LINEAR := 0.7
const MUTED_VOLUME_DB := -80.0

var stored_playback_position: float = 0.0
var resume_request_id: int = 0
var paused_by_script: bool = false

func _ready() -> void:
	finished.connect(_on_finished)
	apply_saved_volume()

func apply_saved_volume() -> void:
	var volume_linear: float = load_music_volume()
	var muted: bool = load_music_muted()

	if muted:
		volume_db = MUTED_VOLUME_DB
	else:
		volume_db = linear_to_db(max(volume_linear, 0.001))

func _on_finished() -> void:
	stored_playback_position = 0.0
	paused_by_script = false
	play()

func get_saved_playback_position() -> float:
	if playing:
		return get_playback_position()
	return stored_playback_position

func restore_playback_position(position_seconds: float) -> void:
	stored_playback_position = max(position_seconds, 0.0)
	paused_by_script = false

func start_music(position_seconds: float = 0.0) -> void:
	if stream == null:
		return

	resume_request_id += 1
	stored_playback_position = max(position_seconds, 0.0)
	paused_by_script = false
	_play_from_position(stored_playback_position)

func pause_music() -> void:
	if stream == null:
		return

	resume_request_id += 1
	stored_playback_position = get_saved_playback_position()
	paused_by_script = true
	if playing:
		stream_paused = true
	else:
		stop()

func resume_music(delay_seconds: float = 0.0) -> void:
	if stream == null:
		return

	resume_request_id += 1
	var request_id: int = resume_request_id
	var target_position: float = get_saved_playback_position()

	if delay_seconds > 0.0:
		await get_tree().create_timer(delay_seconds, true).timeout
		if request_id != resume_request_id:
			return

	if paused_by_script and playing:
		stream_paused = false
	else:
		_play_from_position(target_position)
	paused_by_script = false

func _play_from_position(position_seconds: float) -> void:
	stream_paused = false
	var safe_position: float = max(position_seconds, 0.0)
	if safe_position <= 0.001:
		play()
	else:
		play()
		seek(safe_position)

static func load_music_volume() -> float:
	var config := ConfigFile.new()
	var load_result := config.load(SETTINGS_PATH)
	if load_result != OK:
		return DEFAULT_VOLUME_LINEAR

	return float(config.get_value(SETTINGS_SECTION, MUSIC_VOLUME_KEY, DEFAULT_VOLUME_LINEAR))

static func save_music_volume(volume_linear: float) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, MUSIC_VOLUME_KEY, clamp(volume_linear, 0.0, 1.0))
	config.save(SETTINGS_PATH)

static func load_music_muted() -> bool:
	var config := ConfigFile.new()
	var load_result := config.load(SETTINGS_PATH)
	if load_result != OK:
		return false

	return bool(config.get_value(SETTINGS_SECTION, MUSIC_MUTED_KEY, false))

static func save_music_muted(muted: bool) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, MUSIC_MUTED_KEY, muted)
	config.save(SETTINGS_PATH)

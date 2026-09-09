extends Node

const DEFAULT_CATALOG: AudioCatalog = preload("res://resources/audio/mvp_audio_catalog.tres")
const SETTINGS_PATH: String = "user://settings/audio.cfg"
const MUSIC_BUS: StringName = &"Music"
const SUPPORTED_BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"UI", &"Ambience"]
const GLOBAL_POOL_SIZE: int = 16
const SPATIAL_POOL_SIZE: int = 24
const SILENT_LINEAR_VOLUME: float = 0.0001

var current_music_id: StringName = &"none"

var _catalog: AudioCatalog = DEFAULT_CATALOG
var _cues_by_id: Dictionary = {}
var _warned_messages: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _global_players: Array[AudioStreamPlayer] = []
var _spatial_players: Array[AudioStreamPlayer3D] = []
var _player_cue_ids: Dictionary = {}
var _player_started_usec: Dictionary = {}
var _active_music_player_index: int = 0
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_players()
	_rebuild_catalog_index(_catalog)
	_load_audio_settings()


func play_music(music_id: StringName, fade_seconds: float = 0.0) -> bool:
	if music_id == current_music_id:
		return true
	var cue: AudioCue = _get_valid_cue(music_id)
	if cue == null:
		return false
	var incoming: AudioStreamPlayer = _music_players[1 - _active_music_player_index]
	var outgoing: AudioStreamPlayer = _music_players[_active_music_player_index]
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	incoming.stream = cue.stream
	incoming.bus = String(MUSIC_BUS)
	incoming.volume_db = _silent_db()
	incoming.pitch_scale = cue.get_random_pitch_scale()
	incoming.play()
	current_music_id = music_id
	_active_music_player_index = 1 - _active_music_player_index
	if fade_seconds <= 0.0:
		incoming.volume_db = cue.volume_db
		outgoing.stop()
		return true
	_music_tween = create_tween()
	_music_tween.tween_property(incoming, "volume_db", cue.volume_db, fade_seconds)
	if outgoing.playing:
		_music_tween.parallel().tween_property(outgoing, "volume_db", _silent_db(), fade_seconds)
		_music_tween.tween_callback(outgoing.stop)
	return true


func stop_music(fade_seconds: float = 0.0) -> void:
	current_music_id = &"none"
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	var active: AudioStreamPlayer = _music_players[_active_music_player_index]
	for player: AudioStreamPlayer in _music_players:
		if player != active:
			player.stop()
	if not active.playing or fade_seconds <= 0.0:
		active.stop()
		return
	_music_tween = create_tween()
	_music_tween.tween_property(active, "volume_db", _silent_db(), fade_seconds)
	_music_tween.tween_callback(active.stop)


func play_sfx(sfx_id: StringName, bus_name: StringName = &"SFX") -> bool:
	return _play_global_sfx(sfx_id, bus_name)


func play_global_sfx(cue_id: StringName) -> bool:
	return _play_global_sfx(cue_id, &"")


func play_3d_sfx(cue_id: StringName, world_position: Vector3) -> bool:
	var cue: AudioCue = _get_valid_cue(cue_id)
	if cue == null:
		return false
	if not _has_valid_bus(cue.bus_name):
		_warn_once("cue_bus_%s" % String(cue_id), "Audio cue '%s' targets missing bus '%s'." % [String(cue_id), String(cue.bus_name)])
		return false
	var player: AudioStreamPlayer3D = _select_spatial_player(cue_id, cue.max_instances)
	_configure_spatial_player(player, cue, world_position)
	_mark_player_started(player, cue_id)
	player.play()
	return true


func set_catalog(catalog: AudioCatalog) -> bool:
	if catalog == null:
		_warn_once("null_catalog", "AudioManager rejected a null AudioCatalog.")
		return false
	_catalog = catalog
	_rebuild_catalog_index(_catalog)
	return true


func set_bus_volume_linear(bus_name: StringName, linear_volume: float) -> bool:
	if not _has_valid_bus(bus_name):
		_warn_once("settings_bus_%s" % String(bus_name), "Audio settings requested missing bus '%s'." % String(bus_name))
		return false
	var index: int = AudioServer.get_bus_index(bus_name)
	var clamped_volume: float = clampf(linear_volume, 0.0, 1.0)
	AudioServer.set_bus_mute(index, clamped_volume <= SILENT_LINEAR_VOLUME)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clamped_volume, SILENT_LINEAR_VOLUME)))
	_save_audio_settings()
	return true


func get_bus_volume_linear(bus_name: StringName) -> float:
	if not _has_valid_bus(bus_name):
		_warn_once("settings_get_bus_%s" % String(bus_name), "Audio settings requested missing bus '%s'." % String(bus_name))
		return 0.0
	var index: int = AudioServer.get_bus_index(bus_name)
	if AudioServer.is_bus_mute(index):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(index)), 0.0, 1.0)


func set_bus_muted(bus_name: StringName, muted: bool) -> bool:
	if not _has_valid_bus(bus_name):
		_warn_once("settings_mute_bus_%s" % String(bus_name), "Audio settings requested missing bus '%s'." % String(bus_name))
		return false
	AudioServer.set_bus_mute(AudioServer.get_bus_index(bus_name), muted)
	_save_audio_settings()
	return true


func is_bus_muted(bus_name: StringName) -> bool:
	if not _has_valid_bus(bus_name):
		return true
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus_name))


func _play_global_sfx(cue_id: StringName, bus_override: StringName) -> bool:
	var cue: AudioCue = _get_valid_cue(cue_id)
	if cue == null:
		return false
	var bus_name: StringName = cue.bus_name if bus_override.is_empty() else bus_override
	if not _has_valid_bus(bus_name):
		_warn_once("cue_bus_%s" % String(cue_id), "Audio cue '%s' targets missing bus '%s'." % [String(cue_id), String(bus_name)])
		return false
	var player: AudioStreamPlayer = _select_global_player(cue_id, cue.max_instances)
	player.stream = cue.stream
	player.bus = String(bus_name)
	player.volume_db = cue.volume_db
	player.pitch_scale = cue.get_random_pitch_scale()
	_mark_player_started(player, cue_id)
	player.play()
	return true


func _create_players() -> void:
	for index: int in 2:
		var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
		music_player.name = "MusicPlayer%d" % index
		music_player.bus = String(MUSIC_BUS)
		add_child(music_player)
		_music_players.append(music_player)
	for index: int in GLOBAL_POOL_SIZE:
		var global_player: AudioStreamPlayer = AudioStreamPlayer.new()
		global_player.name = "GlobalSfxPlayer%02d" % index
		add_child(global_player)
		_global_players.append(global_player)
	for index: int in SPATIAL_POOL_SIZE:
		var spatial_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		spatial_player.name = "SpatialSfxPlayer%02d" % index
		add_child(spatial_player)
		_spatial_players.append(spatial_player)


func _rebuild_catalog_index(catalog: AudioCatalog) -> void:
	_cues_by_id.clear()
	if catalog == null:
		return
	for cue: AudioCue in catalog.cues:
		if cue == null or cue.cue_id.is_empty():
			_warn_once("invalid_cue", "Audio catalog contains a null or unnamed cue.")
			continue
		if _cues_by_id.has(cue.cue_id):
			_warn_once("duplicate_cue_%s" % String(cue.cue_id), "Audio catalog has duplicate cue id '%s'." % String(cue.cue_id))
			continue
		_cues_by_id[cue.cue_id] = cue


func _get_valid_cue(cue_id: StringName) -> AudioCue:
	if not _cues_by_id.has(cue_id):
		_warn_once("missing_cue_%s" % String(cue_id), "Audio cue '%s' is not registered." % String(cue_id))
		return null
	var cue: AudioCue = _cues_by_id[cue_id] as AudioCue
	if cue.stream == null:
		_warn_once("empty_cue_%s" % String(cue_id), "Audio cue '%s' has no AudioStream." % String(cue_id))
		return null
	return cue


func _select_global_player(cue_id: StringName, max_instances: int) -> AudioStreamPlayer:
	var matching: Array[AudioStreamPlayer] = []
	var available: AudioStreamPlayer
	for player: AudioStreamPlayer in _global_players:
		if not player.playing:
			if available == null:
				available = player
			continue
		if _player_cue_ids.get(player.get_instance_id(), &"") == cue_id:
			matching.append(player)
	if matching.size() >= max_instances:
		return _get_oldest_global_player(matching)
	if available != null:
		return available
	return _get_oldest_global_player(_global_players)


func _select_spatial_player(cue_id: StringName, max_instances: int) -> AudioStreamPlayer3D:
	var matching: Array[AudioStreamPlayer3D] = []
	var available: AudioStreamPlayer3D
	for player: AudioStreamPlayer3D in _spatial_players:
		if not player.playing:
			if available == null:
				available = player
			continue
		if _player_cue_ids.get(player.get_instance_id(), &"") == cue_id:
			matching.append(player)
	if matching.size() >= max_instances:
		return _get_oldest_spatial_player(matching)
	if available != null:
		return available
	return _get_oldest_spatial_player(_spatial_players)


func _get_oldest_global_player(players: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	var oldest: AudioStreamPlayer = players[0]
	for player: AudioStreamPlayer in players:
		if _player_started_usec.get(player.get_instance_id(), 0) < _player_started_usec.get(oldest.get_instance_id(), 0):
			oldest = player
	return oldest


func _get_oldest_spatial_player(players: Array[AudioStreamPlayer3D]) -> AudioStreamPlayer3D:
	var oldest: AudioStreamPlayer3D = players[0]
	for player: AudioStreamPlayer3D in players:
		if _player_started_usec.get(player.get_instance_id(), 0) < _player_started_usec.get(oldest.get_instance_id(), 0):
			oldest = player
	return oldest


func _configure_spatial_player(player: AudioStreamPlayer3D, cue: AudioCue, world_position: Vector3) -> void:
	player.stream = cue.stream
	player.bus = String(cue.bus_name)
	player.volume_db = cue.volume_db
	player.pitch_scale = cue.get_random_pitch_scale()
	player.global_position = world_position
	player.unit_size = cue.unit_size
	player.max_distance = cue.max_distance
	player.attenuation_model = cue.attenuation_model


func _mark_player_started(player: Node, cue_id: StringName) -> void:
	_player_cue_ids[player.get_instance_id()] = cue_id
	_player_started_usec[player.get_instance_id()] = Time.get_ticks_usec()


func _has_valid_bus(bus_name: StringName) -> bool:
	return SUPPORTED_BUSES.has(bus_name) and AudioServer.get_bus_index(bus_name) >= 0


func _silent_db() -> float:
	return linear_to_db(SILENT_LINEAR_VOLUME)


func _load_audio_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		_apply_default_audio_settings()
		return
	for bus_name: StringName in SUPPORTED_BUSES:
		var linear_volume: float = float(config.get_value("volume", String(bus_name), 1.0))
		var muted: bool = bool(config.get_value("mute", String(bus_name), false))
		_apply_bus_settings(bus_name, linear_volume, muted)


func _apply_default_audio_settings() -> void:
	for bus_name: StringName in SUPPORTED_BUSES:
		_apply_bus_settings(bus_name, 1.0, false)


func _apply_bus_settings(bus_name: StringName, linear_volume: float, muted: bool) -> void:
	if not _has_valid_bus(bus_name):
		return
	var index: int = AudioServer.get_bus_index(bus_name)
	var clamped_volume: float = clampf(linear_volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clamped_volume, SILENT_LINEAR_VOLUME)))
	AudioServer.set_bus_mute(index, muted or clamped_volume <= SILENT_LINEAR_VOLUME)


func _save_audio_settings() -> void:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://settings"))
	if directory_error != OK:
		push_error("Failed to create audio settings directory: %s" % error_string(directory_error))
		return
	var config: ConfigFile = ConfigFile.new()
	for bus_name: StringName in SUPPORTED_BUSES:
		config.set_value("volume", String(bus_name), get_bus_volume_linear(bus_name))
		config.set_value("mute", String(bus_name), is_bus_muted(bus_name))
	var save_error: Error = config.save(SETTINGS_PATH)
	if save_error != OK:
		push_error("Failed to save audio settings: %s" % error_string(save_error))


func _warn_once(key: String, message: String) -> void:
	if _warned_messages.has(key):
		return
	_warned_messages[key] = true
	push_warning(message)

extends Node

const AUDIO_MANAGER_SCRIPT: Script = preload("res://scripts/autoloads/audio_manager.gd")
const BUS_NAMES: Array[StringName] = [&"Master", &"Music", &"SFX", &"UI", &"Ambience"]

var _settings_existed: bool = false
var _settings_backup: String = ""
var _original_volumes: Dictionary = {}
var _original_mutes: Dictionary = {}


func _ready() -> void:
	var audio: Node = get_tree().root.get_node_or_null("AudioManager")
	_check(audio != null, "AudioManager autoload missing")
	_backup_settings(audio)
	_check_bus_layout()
	var catalog: AudioCatalog = _create_catalog()
	_check(bool(audio.call("set_catalog", catalog)), "AudioManager rejected valid catalog")
	_check(not bool(audio.call("play_global_sfx", &"missing.cue")), "unknown cue must fail safely")
	_check(bool(audio.call("play_global_sfx", &"test.global")), "global cue did not play")
	_check(bool(audio.call("play_3d_sfx", &"test.spatial", Vector3(2.0, 1.0, -3.0))), "3D cue did not play")
	_check(bool(audio.call("play_music", &"test.music", 0.0)), "music cue did not play")
	_check(StringName(audio.get("current_music_id")) == &"test.music", "music id did not update")
	_check_pool_shape(audio)
	_check_pool_reuse(audio)
	_check_duplicate_id_resolution(audio)
	_check_volume_persistence(audio)
	audio.call("stop_music", 0.0)
	_check(StringName(audio.get("current_music_id")) == &"none", "music id did not clear")
	_restore_settings(audio)
	print("AUDIO_SYSTEM_SMOKE: PASS")
	get_tree().quit()


func _check_bus_layout() -> void:
	for bus_name: StringName in BUS_NAMES:
		var index: int = AudioServer.get_bus_index(bus_name)
		_check(index >= 0, "missing audio bus %s" % String(bus_name))
		if bus_name != &"Master":
			_check(AudioServer.get_bus_send(index) == &"Master", "%s must route to Master" % String(bus_name))
	var master_index: int = AudioServer.get_bus_index(&"Master")
	_check(AudioServer.get_bus_effect(master_index, 0) is AudioEffectLimiter, "Master needs a Limiter")


func _create_catalog() -> AudioCatalog:
	var stream: AudioStreamWAV = _create_silent_stream()
	var global_cue: AudioCue = _create_cue(&"test.global", stream, &"SFX")
	var spatial_cue: AudioCue = _create_cue(&"test.spatial", stream, &"SFX")
	var music_cue: AudioCue = _create_cue(&"test.music", stream, &"Music")
	var catalog: AudioCatalog = AudioCatalog.new()
	catalog.cues = [global_cue, spatial_cue, music_cue]
	return catalog


func _create_silent_stream() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	stream.data.resize(44100 * 2)
	return stream


func _create_cue(cue_id: StringName, stream: AudioStream, bus_name: StringName) -> AudioCue:
	var cue: AudioCue = AudioCue.new()
	cue.cue_id = cue_id
	cue.stream = stream
	cue.bus_name = bus_name
	cue.max_instances = 1
	return cue


func _check_pool_shape(audio: Node) -> void:
	var global_count: int = 0
	var spatial_count: int = 0
	for child: Node in audio.get_children():
		if child.name.begins_with("GlobalSfxPlayer"):
			global_count += 1
		if child.name.begins_with("SpatialSfxPlayer"):
			spatial_count += 1
	_check(global_count == 16, "global SFX pool size must be 16")
	_check(spatial_count == 24, "3D SFX pool size must be 24")


func _check_duplicate_id_resolution(audio: Node) -> void:
	var first: AudioCue = _create_cue(&"test.duplicate", _create_silent_stream(), &"SFX")
	var duplicate_cue: AudioCue = _create_cue(&"test.duplicate", _create_silent_stream(), &"SFX")
	duplicate_cue.volume_db = -18.0
	var catalog: AudioCatalog = AudioCatalog.new()
	catalog.cues = [first, duplicate_cue]
	_check(bool(audio.call("set_catalog", catalog)), "duplicate catalog should load with first cue retained")
	_check(bool(audio.call("play_global_sfx", &"test.duplicate")), "first duplicate cue did not play")
	var used_first_definition: bool = false
	for child: Node in audio.get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null and player.stream == first.stream:
			used_first_definition = is_equal_approx(player.volume_db, first.volume_db)
	_check(used_first_definition, "duplicate cue did not keep first registration")


func _check_pool_reuse(audio: Node) -> void:
	var stream: AudioStreamWAV = _create_silent_stream()
	var catalog: AudioCatalog = AudioCatalog.new()
	for index: int in 25:
		catalog.cues.append(_create_cue(StringName("test.pool.%02d" % index), stream, &"SFX"))
	_check(bool(audio.call("set_catalog", catalog)), "pool catalog did not load")
	for index: int in 25:
		var cue_id: StringName = StringName("test.pool.%02d" % index)
		_check(bool(audio.call("play_global_sfx", cue_id)), "global pool rejected %s" % String(cue_id))
		_check(bool(audio.call("play_3d_sfx", cue_id, Vector3(float(index), 0.0, 0.0))), "3D pool rejected %s" % String(cue_id))
	_check_pool_shape(audio)


func _check_volume_persistence(audio: Node) -> void:
	_check(bool(audio.call("set_bus_volume_linear", &"SFX", 0.6)), "could not set SFX volume")
	_check(is_equal_approx(float(audio.call("get_bus_volume_linear", &"SFX")), 0.6), "linear SFX volume conversion failed")
	_check(bool(audio.call("set_bus_volume_linear", &"UI", 0.0)), "could not mute UI with zero volume")
	_check(bool(audio.call("is_bus_muted", &"UI")), "zero UI volume must mute the bus")
	var reloaded: Node = AUDIO_MANAGER_SCRIPT.new()
	add_child(reloaded)
	await get_tree().process_frame
	_check(is_equal_approx(float(reloaded.call("get_bus_volume_linear", &"SFX")), 0.6), "SFX volume did not persist")
	_check(bool(reloaded.call("is_bus_muted", &"UI")), "UI mute did not persist")
	reloaded.queue_free()


func _backup_settings(audio: Node) -> void:
	_settings_existed = FileAccess.file_exists("user://settings/audio.cfg")
	if _settings_existed:
		_settings_backup = FileAccess.get_file_as_string("user://settings/audio.cfg")
	for bus_name: StringName in BUS_NAMES:
		_original_volumes[bus_name] = float(audio.call("get_bus_volume_linear", bus_name))
		_original_mutes[bus_name] = bool(audio.call("is_bus_muted", bus_name))


func _restore_settings(audio: Node) -> void:
	for bus_name: StringName in BUS_NAMES:
		audio.call("set_bus_volume_linear", bus_name, float(_original_volumes[bus_name]))
		audio.call("set_bus_muted", bus_name, bool(_original_mutes[bus_name]))
	if _settings_existed:
		var file: FileAccess = FileAccess.open("user://settings/audio.cfg", FileAccess.WRITE)
		if file != null:
			file.store_string(_settings_backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings/audio.cfg"))


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("AUDIO_SYSTEM_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)

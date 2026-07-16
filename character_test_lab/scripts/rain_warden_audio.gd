class_name RainWardenAudio
extends Node3D

const SAMPLE_RATE: int = 22050
const AMBIENCE_BUS: StringName = &"RainShowcaseAmbience"
const SFX_BUS: StringName = &"RainShowcaseSFX"
const UI_BUS: StringName = &"RainShowcaseUI"
const SFX_POOL_SIZE: int = 6

var _animation_player: AnimationPlayer
var _ambience_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer3D] = []
var _streams: Dictionary[StringName, AudioStreamWAV] = {}
var _current_clip: StringName = &""
var _last_position: float = -0.001
var _pool_cursor: int = 0


func _ready() -> void:
	_configure_buses()
	_build_streams()
	_build_players()
	_ambience_player.play()


func _process(_delta: float) -> void:
	if not is_instance_valid(_animation_player):
		return
	var clip_name := StringName(_animation_player.current_animation)
	if clip_name != _current_clip:
		on_clip_started(clip_name)
	var playback_position := _animation_player.current_animation_position
	if _current_clip == &"run" and _last_position > playback_position:
		_play_sfx(_streams[&"footstep"], -4.0, 0.96)
	match _current_clip:
		&"inspect":
			_trigger_at(0.42, &"metal", -7.0, 1.12)
			_trigger_at(1.34, &"metal", -8.0, 0.92)
			_trigger_at(2.20, &"gear", -10.0, 1.08)
		&"attack":
			_trigger_at(0.16, &"whoosh", -1.5, 0.94)
			_trigger_at(0.65, &"impact", -0.5, 0.96)
		&"rain_pulse":
			_trigger_at(1.28, &"pulse_release", -0.5, 1.0)
		&"run":
			_trigger_at(0.43, &"footstep", -4.0, 1.04)
	_last_position = playback_position


func bind_animation_player(player: AnimationPlayer) -> void:
	_animation_player = player


func on_clip_started(clip_name: StringName) -> void:
	_current_clip = clip_name
	_last_position = -0.001
	match clip_name:
		&"ready":
			_play_sfx(_streams[&"gear"], -11.0, 0.92)
		&"inspect":
			_play_sfx(_streams[&"gear"], -11.0, 1.08)
		&"attack":
			_play_sfx(_streams[&"gear"], -12.0, 0.86)
		&"rain_pulse":
			_play_sfx(_streams[&"pulse_charge"], -5.0, 1.0)
		&"run":
			_play_sfx(_streams[&"footstep"], -4.0, 0.96)


func play_ui_confirm() -> void:
	_ui_player.pitch_scale = 0.98 + randf() * 0.05
	_ui_player.play()


func _trigger_at(time: float, stream_name: StringName, volume_db: float, pitch: float) -> void:
	if not _crossed_time(time):
		return
	_play_sfx(_streams[stream_name], volume_db, pitch)


func _crossed_time(time: float) -> bool:
	var playback_position := _animation_player.current_animation_position
	if playback_position >= _last_position:
		return _last_position < time and playback_position >= time
	return _last_position < time or playback_position >= time


func _configure_buses() -> void:
	_ensure_bus(AMBIENCE_BUS, -9.0)
	_ensure_bus(SFX_BUS, -1.5)
	_ensure_bus(UI_BUS, -5.0)


func _ensure_bus(bus_name: StringName, volume_db: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")
	AudioServer.set_bus_volume_db(index, volume_db)


func _build_players() -> void:
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "RainAmbience"
	_ambience_player.bus = AMBIENCE_BUS
	_ambience_player.stream = _streams[&"rain"]
	_ambience_player.volume_db = -2.0
	add_child(_ambience_player)

	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UIConfirm"
	_ui_player.bus = UI_BUS
	_ui_player.stream = _streams[&"ui_click"]
	add_child(_ui_player)

	for index: int in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer3D.new()
		player.name = "SFX%02d" % index
		player.bus = SFX_BUS
		player.position = Vector3(0.0, 1.25, -0.1)
		player.unit_size = 4.0
		player.max_distance = 14.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		_sfx_players.append(player)


func _play_sfx(stream: AudioStreamWAV, volume_db: float, pitch: float) -> void:
	var player: AudioStreamPlayer3D
	for candidate: AudioStreamPlayer3D in _sfx_players:
		if not candidate.playing:
			player = candidate
			break
	if not player:
		player = _sfx_players[_pool_cursor]
		_pool_cursor = (_pool_cursor + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func _build_streams() -> void:
	_streams = {
		&"rain": _make_rain_ambience(),
		&"ui_click": _make_ui_click(),
		&"gear": _make_gear_rustle(),
		&"metal": _make_metal_clink(),
		&"whoosh": _make_weapon_whoosh(),
		&"impact": _make_weapon_impact(),
		&"footstep": _make_footstep(),
		&"pulse_charge": _make_pulse_charge(),
		&"pulse_release": _make_pulse_release(),
	}


func _make_rain_ambience() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var count := SAMPLE_RATE * 4
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 74192
	var wash: float = 0.0
	var drop_phase: float = -1.0
	for index: int in range(count):
		var time := float(index) / SAMPLE_RATE
		wash = lerpf(wash, rng.randf_range(-1.0, 1.0), 0.085)
		if drop_phase < 0.0 and rng.randf() < 0.0014:
			drop_phase = 0.0
		var drop: float = 0.0
		if drop_phase >= 0.0:
			drop = sin(TAU * (1850.0 - drop_phase * 950.0) * drop_phase) * exp(-drop_phase * 34.0)
			drop_phase += 1.0 / SAMPLE_RATE
			if drop_phase > 0.16:
				drop_phase = -1.0
		var wind := sin(TAU * 0.11 * time) * 0.05 + sin(TAU * 0.037 * time) * 0.04
		samples[index] = wash * 0.42 + drop * 0.11 + wind
	_soften_loop_end(samples, 900)
	return _wav(samples, true)


func _make_ui_click() -> AudioStreamWAV:
	var samples := _samples(0.085)
	for index: int in range(samples.size()):
		var time := float(index) / SAMPLE_RATE
		var envelope := exp(-time * 48.0)
		samples[index] = (sin(TAU * 1180.0 * time) * 0.34 + sin(TAU * 1760.0 * time) * 0.15) * envelope
	return _wav(samples)


func _make_gear_rustle() -> AudioStreamWAV:
	var samples := _samples(0.34)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33017
	var filtered: float = 0.0
	for index: int in range(samples.size()):
		var time := float(index) / SAMPLE_RATE
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), 0.20)
		var envelope := _attack_release(time, 0.025, 0.30)
		var buckle := sin(TAU * 410.0 * time) * exp(-time * 18.0) * 0.12
		samples[index] = filtered * envelope * 0.30 + buckle
	return _wav(samples)


func _make_metal_clink() -> AudioStreamWAV:
	var samples := _samples(0.46)
	for index: int in range(samples.size()):
		var time := float(index) / SAMPLE_RATE
		var envelope := exp(-time * 8.5) * minf(time * 180.0, 1.0)
		var ring := sin(TAU * 920.0 * time) * 0.34 + sin(TAU * 1475.0 * time) * 0.20 + sin(TAU * 2320.0 * time) * 0.08
		samples[index] = ring * envelope
	return _wav(samples)


func _make_weapon_whoosh() -> AudioStreamWAV:
	var samples := _samples(0.62)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91844
	var filtered: float = 0.0
	for index: int in range(samples.size()):
		var time := float(index) / SAMPLE_RATE
		var phase := time / 0.62
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), 0.07 + phase * 0.28)
		var envelope := pow(sin(PI * clampf(phase, 0.0, 1.0)), 1.7)
		var blade_tone := sin(TAU * (150.0 + phase * 360.0) * time) * 0.17
		samples[index] = (filtered * 0.66 + blade_tone) * envelope
	return _wav(samples)


func _make_weapon_impact() -> AudioStreamWAV:
	var samples := _samples(0.78)
	var rng := RandomNumberGenerator.new()
	rng.seed = 51209
	var grit: float = 0.0
	for index: int in range(samples.size()):
		var time := float(index) / SAMPLE_RATE
		grit = lerpf(grit, rng.randf_range(-1.0, 1.0), 0.30)
		var transient := grit * exp(-time * 42.0) * 0.58
		var body := sin(TAU * 72.0 * time) * exp(-time * 7.0) * 0.55
		var metal := (sin(TAU * 610.0 * time) * 0.20 + sin(TAU * 1040.0 * time) * 0.12) * exp(-time * 5.5)
		samples[index] = (transient + body + metal) * minf(time * 220.0, 1.0)
	return _wav(samples)


func _make_footstep() -> AudioStreamWAV:
	var samples := _samples(0.28)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20931
	var dirt: float = 0.0
	for index: int in range(samples.size()):
		var time := float(index) / SAMPLE_RATE
		dirt = lerpf(dirt, rng.randf_range(-1.0, 1.0), 0.13)
		var envelope := exp(-time * 18.0) * minf(time * 240.0, 1.0)
		var boot := sin(TAU * 83.0 * time) * exp(-time * 13.0) * 0.52
		samples[index] = boot + dirt * envelope * 0.36
	return _wav(samples)


func _make_pulse_charge() -> AudioStreamWAV:
	var samples := _samples(1.42)
	for index: int in range(samples.size()):
		var time := float(index) / SAMPLE_RATE
		var phase := time / 1.42
		var frequency := lerpf(105.0, 620.0, phase * phase)
		var rise := smoothstep(0.0, 0.82, phase) * (1.0 - smoothstep(0.91, 1.0, phase))
		var core := sin(TAU * frequency * time) * 0.23
		var shimmer := sin(TAU * frequency * 2.02 * time) * 0.09
		samples[index] = (core + shimmer) * rise
	return _wav(samples)


func _make_pulse_release() -> AudioStreamWAV:
	var samples := _samples(1.05)
	var rng := RandomNumberGenerator.new()
	rng.seed = 63082
	var air: float = 0.0
	for index: int in range(samples.size()):
		var time := float(index) / SAMPLE_RATE
		air = lerpf(air, rng.randf_range(-1.0, 1.0), 0.08)
		var boom := sin(TAU * (58.0 - time * 18.0) * time) * exp(-time * 5.2) * 0.62
		var glass := (sin(TAU * 520.0 * time) * 0.19 + sin(TAU * 780.0 * time) * 0.11) * exp(-time * 3.8)
		var spray := air * exp(-time * 6.5) * 0.25
		samples[index] = (boom + glass + spray) * minf(time * 180.0, 1.0)
	return _wav(samples)


func _samples(duration: float) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(maxi(int(duration * SAMPLE_RATE), 1))
	return result


func _attack_release(time: float, attack: float, release: float) -> float:
	var attack_gain := minf(time / maxf(attack, 0.001), 1.0)
	var release_gain := clampf((release - time) / maxf(release * 0.45, 0.001), 0.0, 1.0)
	return attack_gain * release_gain


func _soften_loop_end(samples: PackedFloat32Array, fade_samples: int) -> void:
	var count := mini(fade_samples, int(samples.size() * 0.5))
	var target := samples[0]
	for offset: int in range(count):
		var index := samples.size() - count + offset
		var weight := float(offset + 1) / count
		samples[index] = lerpf(samples[index], target, weight * weight)


func _wav(samples: PackedFloat32Array, looping: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for index: int in range(samples.size()):
		var value := clampi(int(samples[index] * 32767.0), -32768, 32767)
		data.encode_s16(index * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream

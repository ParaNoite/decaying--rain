class_name AudioCue
extends Resource

@export_group("Identity")
@export var cue_id: StringName = &"audio.cue"
@export var stream: AudioStream
@export var bus_name: StringName = &"SFX"

@export_group("Playback")
@export_range(-80.0, 24.0, 0.1) var volume_db: float = 0.0
@export_range(0.1, 3.0, 0.01) var pitch_scale_min: float = 1.0
@export_range(0.1, 3.0, 0.01) var pitch_scale_max: float = 1.0
@export_range(1, 32, 1) var max_instances: int = 4

@export_group("Spatial")
@export_range(0.1, 1000.0, 0.1) var unit_size: float = 6.0
@export_range(0.1, 2000.0, 0.1) var max_distance: float = 40.0
@export_enum("Inverse Distance", "Inverse Square", "Logarithmic", "Disabled") var attenuation_model: int = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE


func get_random_pitch_scale() -> float:
	return randf_range(minf(pitch_scale_min, pitch_scale_max), maxf(pitch_scale_min, pitch_scale_max))

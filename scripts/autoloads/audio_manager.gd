extends Node

var current_music_id: StringName = &"none"


func play_music(music_id: StringName, _fade_seconds: float = 0.0) -> void:
	current_music_id = music_id


func stop_music(_fade_seconds: float = 0.0) -> void:
	current_music_id = &"none"


func play_sfx(_sfx_id: StringName, _bus_name: StringName = &"SFX") -> void:
	pass

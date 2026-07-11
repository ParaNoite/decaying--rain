class_name WaveDirector
extends Node

@export var wave_definitions: Array[WaveDefinition] = []


func get_wave(index: int) -> WaveDefinition:
	for wave: WaveDefinition in wave_definitions:
		if wave != null and wave.wave_index == index:
			return wave
	return null


func begin_wave(index: int) -> void:
	var wave: WaveDefinition = get_wave(index)
	var wave_id: StringName = wave.wave_id if wave != null else StringName("wave_%d" % index)
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.wave_started.emit(index, wave_id)


func complete_wave(index: int) -> void:
	var wave: WaveDefinition = get_wave(index)
	var wave_id: StringName = wave.wave_id if wave != null else StringName("wave_%d" % index)
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.wave_completed.emit(index, wave_id)

class_name RandomEventDefinition
extends Resource

enum EventTiming {
	DAYLIGHT,
	PREPARATION,
	RAIN,
	SETTLEMENT,
}

@export_group("Identity")
@export var event_id: StringName = &"event"
@export var display_name: String = "Event"
@export_multiline var description: String = ""

@export_group("Rules")
@export var timing: EventTiming = EventTiming.DAYLIGHT
@export_range(0.0, 1.0, 0.01) var selection_weight: float = 1.0
@export_range(1, 99, 1) var min_wave_index: int = 1
@export_range(1, 99, 1) var max_wave_index: int = 99
@export var tags: Array[StringName] = []

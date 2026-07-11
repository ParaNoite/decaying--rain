class_name WaveDefinition
extends Resource

@export_group("Identity")
@export_range(1, 99, 1) var wave_index: int = 1
@export var wave_id: StringName = &"wave_1"
@export var pressure_theme: StringName = &"intro"

@export_group("Timing")
@export_range(1.0, 3600.0, 1.0) var rain_seconds: float = 120.0
@export_range(0.0, 3600.0, 1.0) var settlement_seconds: float = 10.0

@export_group("Enemies")
@export var enemy_ids: Array[StringName] = []
@export_range(0.0, 10.0, 0.1) var spawn_budget_multiplier: float = 1.0

@export_group("Events")
@export var forced_event_ids: Array[StringName] = []
@export var allowed_event_ids: Array[StringName] = []

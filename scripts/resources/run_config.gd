class_name RunConfig
extends Resource

@export_group("Identity")
@export var run_id: StringName = &"mvp"
@export var content_spec_version: String = VersionInfo.CONTENT_SPEC_VERSION

@export_group("Flow")
@export_range(1, 99, 1) var max_waves: int = 5
@export_range(1.0, 3600.0, 1.0) var daylight_seconds: float = 180.0
@export_range(1.0, 3600.0, 1.0) var preparation_seconds: float = 30.0
@export_range(1.0, 3600.0, 1.0) var default_rain_seconds: float = 120.0
@export var wave_definitions: Array[WaveDefinition] = []

@export_group("Starting State")
@export var starting_profession_id: StringName = &"deserter"
@export var starting_weapon_ids: Array[StringName] = [&"empty_hands"]
@export var starting_item_ids: Array[StringName] = []

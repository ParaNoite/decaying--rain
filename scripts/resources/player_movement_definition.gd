class_name PlayerMovementDefinition
extends Resource

@export_group("Movement")
@export_range(0.1, 20.0, 0.1) var walk_speed: float = 5.0
@export_range(0.1, 30.0, 0.1) var sprint_speed: float = 8.0
@export_range(0.1, 40.0, 0.1) var slide_speed: float = 12.0
@export_range(0.1, 20.0, 0.1) var watch_walk_speed: float = 3.0
@export_range(0.0, 100.0, 1.0) var acceleration: float = 22.0
@export_range(0.0, 100.0, 1.0) var deceleration: float = 28.0
@export_range(0.0, 5.0, 0.05) var air_control_multiplier: float = 0.45

@export_group("Jump")
@export_range(0.0, 20.0, 0.1) var jump_velocity: float = 4.8
@export var jump_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.09, 0.05, 0.03, 0.11)
@export_range(0.0, 5.0, 0.05) var gravity_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.01) var coyote_time: float = 0.1
@export_range(0.0, 1.0, 0.01) var jump_buffer_time: float = 0.12

@export_group("Sprint Reserve")
@export_range(1.0, 1000.0, 1.0) var sprint_reserve_max: float = 100.0
@export_range(0.0, 1000.0, 1.0) var sprint_reserve_drain_per_second: float = 16.0
@export_range(0.0, 1000.0, 1.0) var sprint_reserve_recovery_per_second: float = 35.0
@export_range(0.0, 10.0, 0.05) var sprint_reserve_recovery_delay_seconds: float = 0.7
@export_range(0.0, 100.0, 1.0) var slide_stamina_cost: float = 25.0

@export_group("Slide")
@export var slide_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.10, 0.10, 0.05, 0.10)
@export var sprint_start_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.08, 0.04, 0.02, 0.08)
@export_range(0.0, 5.0, 0.05) var slide_cooldown: float = 1.0

@export_group("Camera")
@export_range(0.0005, 0.02, 0.0005) var mouse_sensitivity: float = 0.0025
@export_range(1.0, 89.0, 1.0) var pitch_limit_degrees: float = 80.0

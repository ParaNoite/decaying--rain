class_name AttackMovementDefinition
extends Resource

enum MovementSource {
	NONE,
	CONTROLLER,
}

@export_group("Movement Authority")
@export var movement_source: MovementSource = MovementSource.NONE
@export_range(0.0, 1.0, 0.01) var windup_speed_multiplier: float = 0.0
@export_range(0.0, 1.0, 0.01) var release_speed_multiplier: float = 0.0
@export_range(0.0, 1.0, 0.01) var impact_speed_multiplier: float = 0.0
@export_range(0.0, 1.0, 0.01) var recovery_speed_multiplier: float = 0.0

@export_group("Controller Tracking")
@export_range(0.0, 10.0, 0.05) var stop_distance: float = 0.0

@export_group("Animation")
@export var use_locomotion_blend: bool = false
@export_range(0.0, 1.0, 0.01) var locomotion_blend_max_weight: float = 0.0


func speed_multiplier_for_phase(phase: ActionTimingDefinition.Phase) -> float:
	match phase:
		ActionTimingDefinition.Phase.WINDUP:
			return windup_speed_multiplier
		ActionTimingDefinition.Phase.RELEASE:
			return release_speed_multiplier
		ActionTimingDefinition.Phase.IMPACT:
			return impact_speed_multiplier
		ActionTimingDefinition.Phase.RECOVERY:
			return recovery_speed_multiplier
		_:
			return 0.0

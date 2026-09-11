class_name StatusEffectDefinition
extends Resource

enum StatusCategory {
	BUFF,
	DEBUFF,
	INJURY,
	CONTAMINATION,
	PROFESSION,
}

enum StackPolicy {
	REFRESH_DURATION,
	REPLACE,
	## Legacy value retained for already-authored resources. Runtime statuses never stack.
	ADD_STACK,
}

@export_group("Identity")
@export var status_id: StringName = &"status"
@export var display_name: String = "Status"
@export var category: StatusCategory = StatusCategory.BUFF
@export_multiline var description: String = ""

@export_group("Timing")
@export_range(0.0, 3600.0, 0.1) var duration_seconds: float = 0.0
@export var is_permanent_until_removed: bool = false
@export var stack_policy: StackPolicy = StackPolicy.REFRESH_DURATION
@export_range(1, 99, 1) var max_stacks: int = 1

@export_group("Modifiers")
@export_range(0.0, 10.0, 0.05) var stamina_recovery_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.05) var incoming_damage_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.05) var outgoing_damage_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.05) var movement_speed_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.05) var sprint_speed_multiplier: float = 1.0
@export_range(0.05, 10.0, 0.05) var firearm_fire_rate_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.05) var firearm_recoil_multiplier: float = 1.0
@export_range(0.05, 10.0, 0.05) var firearm_recoil_recovery_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.05) var firearm_viewmodel_recoil_multiplier: float = 1.0
@export var movement_disabled: bool = false
@export var mobility_blocked: bool = false
@export var combat_blocked: bool = false
@export var interaction_blocked: bool = false

@export_group("Periodic Effects")
@export_range(0.0, 60.0, 0.1) var tick_interval_seconds: float = 0.0
@export var health_delta_per_tick: float = 0.0
@export var stamina_delta_per_tick: float = 0.0
@export var hunger_delta_per_tick: float = 0.0
@export var tick_damage_type: StringName = &"status"

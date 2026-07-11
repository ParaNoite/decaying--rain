class_name StatusEffectDefinition
extends Resource

enum StatusCategory {
	BUFF,
	DEBUFF,
	INJURY,
	CONTAMINATION,
	PROFESSION,
}

@export_group("Identity")
@export var status_id: StringName = &"status"
@export var display_name: String = "Status"
@export var category: StatusCategory = StatusCategory.BUFF
@export_multiline var description: String = ""

@export_group("Timing")
@export_range(0.0, 3600.0, 0.1) var duration_seconds: float = 0.0
@export var is_permanent_until_removed: bool = false

@export_group("Modifiers")
@export_range(0.0, 10.0, 0.05) var stamina_recovery_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.05) var incoming_damage_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.05) var outgoing_damage_multiplier: float = 1.0

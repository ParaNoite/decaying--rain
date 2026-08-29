class_name PlayerActiveSkillDefinition
extends Resource

@export_group("Identity")
@export var skill_id: StringName = &"active_skill"
@export var display_name: String = "Active Skill"
@export_multiline var description: String = ""

@export_group("Activation")
@export var effect_id: StringName = &"none"
@export_range(0.0, 60.0, 0.05) var cooldown_seconds: float = 1.0
@export var action_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.12, 0.10, 0.04, 0.18)
@export_range(0.0, 100.0, 1.0) var stamina_cost: float = 0.0
@export var allowed_phases: Array[StringName] = []

@export_group("Charged Beam")
@export_range(0.0, 1000.0, 1.0) var beam_damage: float = 35.0
@export_range(1.0, 100.0, 0.5) var beam_range: float = 28.0
@export var beam_tags: Array[StringName] = [&"active_skill", &"charged_beam"]
@export var beam_color: Color = Color(0.35, 0.9, 1.0, 0.72)
@export_range(0.01, 1.0, 0.01) var beam_width: float = 0.08
@export_range(0.02, 2.0, 0.01) var beam_visual_duration: float = 0.16
@export var beam_visual_origin_offset: Vector3 = Vector3(0.28, -0.18, -0.35)
@export_range(0.01, 3.0, 0.01) var beam_impact_size: float = 0.36

@export_group("Feedback")
@export var activation_message: String = "Active skill charging"
@export var fired_message: String = "Active skill fired"
@export var ready_message: String = "Active skill ready"

class_name PerkRuleDefinition
extends Resource

enum RuleKind {
	STAT_MODIFIER,
	STATUS_IMMUNITY,
	STATUS_VULNERABILITY,
	ACTION_BLOCK,
	ACTION_ALLOW,
}

@export_group("Identity")
@export var rule_id: StringName = &"perk_rule"
@export var display_name: String = "Perk Rule"
@export_multiline var description: String = ""
@export var kind: RuleKind = RuleKind.STAT_MODIFIER

@export_group("Targets")
@export var stat_id: StringName = &"none"
@export var status_ids: Array[StringName] = []
@export var action_ids: Array[StringName] = []

@export_group("Modifier")
@export_range(0.0, 10.0, 0.05) var multiplier: float = 1.0
@export_range(-1000.0, 1000.0, 0.5) var flat_bonus: float = 0.0

@export_group("Feedback")
@export var hud_message: String = ""

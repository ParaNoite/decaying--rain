class_name DamageResolutionData
extends RefCounted

var event: DamageEventData
var target: Node
var raw_amount: float = 0.0
var outgoing_multiplier: float = 1.0
var critical_multiplier: float = 1.0
var damage_type_multiplier: float = 1.0
var incoming_multiplier: float = 1.0
var final_amount: float = 0.0
var blocked: bool = false
var applied: bool = false
var rejection_reason: StringName = &""

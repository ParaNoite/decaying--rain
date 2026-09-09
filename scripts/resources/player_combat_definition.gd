class_name PlayerCombatDefinition
extends Resource

@export_group("Melee")
@export_range(0.0, 1000.0, 0.5) var unarmed_damage: float = 5.0
@export_range(0.0, 8.0, 0.05) var melee_range: float = 4.0
@export_range(0.0, 10.0, 0.05) var melee_radius: float = 0.6
@export_range(0.0, 5.0, 0.05) var combo_input_window: float = 0.6
@export_range(0.0, 2.0, 0.01) var combo_finisher_cooldown_seconds: float = 0.28
@export_range(0.0, 10.0, 0.1) var final_combo_damage_multiplier: float = 2.0

@export_group("Action Costs")
@export_range(0.0, 100.0, 1.0) var light_attack_stamina_cost: float = 8.0
@export_range(0.0, 100.0, 1.0) var heavy_attack_stamina_cost: float = 16.0
@export_range(0.0, 100.0, 1.0) var shove_stamina_cost: float = 18.0
@export_range(1.0, 10.0, 0.1) var heavy_attack_damage_multiplier: float = 1.8

@export_group("Stamina Recovery")
@export_range(0.0, 10.0, 0.05) var stamina_recovery_delay_seconds: float = 0.9

@export_group("Exhausted Attacks")
@export_range(0.0, 1.0, 0.05) var exhausted_attack_damage_multiplier: float = 0.3
@export_range(1.0, 5.0, 0.05) var light_attack_reach_multiplier: float = 1.5

@export_group("Timings")
@export var light_attack_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.12, 0.08, 0.03, 0.17)
@export var heavy_attack_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.42, 0.17, 0.07, 0.30)
@export var parry_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.05, 0.45, 0.10, 0.25)
@export var parry_success_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.0, 0.025, 0.035, 0.08)
@export var shove_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.05, 0.08, 0.02, 0.10)
@export var interact_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.17, 0.10, 0.04, 0.20)
@export var hurt_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.0, 0.07, 0.03, 0.20)
@export var watch_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.16, 0.075, 0.0, 0.16)
@export_range(0.0, 1000.0, 1.0) var parry_stagger: float = 45.0
@export_range(0.0, 30.0, 0.1) var parry_knockback_force: float = 8.0
@export_range(0.0, 1000.0, 1.0) var stagger_threshold: float = 20.0
@export_range(0.0, 1000.0, 1.0) var bleeding_damage_threshold: float = 25.0
@export_range(0.0, 5.0, 0.05) var shove_cooldown: float = 0.55

@export_group("Shove")
@export_range(0.0, 10.0, 0.05) var shove_range: float = 1.4
@export_range(0.0, 10.0, 0.05) var shove_radius: float = 0.85
@export_range(0.0, 1000.0, 1.0) var shove_stagger: float = 30.0
@export_range(0.0, 30.0, 0.1) var shove_knockback_force: float = 5.5

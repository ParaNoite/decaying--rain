class_name PlayerCombatDefinition
extends Resource

@export_group("Melee")
@export_range(0.0, 1000.0, 0.5) var unarmed_damage: float = 5.0
@export_range(0.0, 8.0, 0.05) var melee_range: float = 4.0
@export_range(0.0, 10.0, 0.05) var melee_radius: float = 0.6
@export_range(0.0, 5.0, 0.05) var combo_input_window: float = 0.6
@export_range(0.0, 10.0, 0.1) var final_combo_damage_multiplier: float = 2.0

@export_group("Action Costs")
@export_range(0.0, 100.0, 1.0) var light_attack_stamina_cost: float = 8.0
@export_range(0.0, 100.0, 1.0) var shove_stamina_cost: float = 18.0

@export_group("Timings")
@export_range(0.0, 5.0, 0.05) var light_attack_windup: float = 0.12
@export_range(0.0, 5.0, 0.05) var light_attack_recovery: float = 0.28
@export_range(0.0, 5.0, 0.05) var parry_window: float = 0.22
@export_range(0.0, 5.0, 0.05) var parry_recovery: float = 0.35
@export_range(0.0, 1000.0, 1.0) var parry_stagger: float = 45.0
@export_range(0.0, 1000.0, 1.0) var stagger_threshold: float = 20.0
@export_range(0.0, 1000.0, 1.0) var bleeding_damage_threshold: float = 25.0
@export_range(0.0, 5.0, 0.05) var shove_duration: float = 0.25
@export_range(0.0, 5.0, 0.05) var shove_cooldown: float = 0.55

@export_group("Shove")
@export_range(0.0, 10.0, 0.05) var shove_range: float = 1.4
@export_range(0.0, 10.0, 0.05) var shove_radius: float = 0.85
@export_range(0.0, 1000.0, 1.0) var shove_stagger: float = 30.0

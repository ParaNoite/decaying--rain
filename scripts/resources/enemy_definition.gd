class_name EnemyDefinition
extends Resource

enum PressureRole {
	MELEE_SWARM,
	BASE_BREAKER,
	ELITE_MELEE,
	RANGED_PRESSURE,
	SUPPORT,
}

@export_group("Identity")
@export var enemy_id: StringName = &"enemy"
@export var display_name: String = "Enemy"
@export var faction_id: StringName = &"wet_dead"
@export var pressure_role: PressureRole = PressureRole.MELEE_SWARM

@export_group("Stats")
@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0
@export_range(0.1, 20.0, 0.1) var move_speed: float = 4.0
@export_range(0.1, 50.0, 0.1) var attack_damage: float = 10.0
@export_range(0.1, 50.0, 0.1) var attack_range: float = 1.5
@export_range(0.1, 20.0, 0.1) var attack_cooldown_seconds: float = 1.5
@export var attack_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.45, 0.10, 0.04, 0.16)
@export var attack_status_ids: Array[StringName] = []
@export_group("Tracking Attack")
@export var tracking_attack_enabled: bool = false
@export_range(0.0, 1.0, 0.01) var tracking_attack_probability: float = 0.0
@export var tracking_attack_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.45, 0.10, 0.04, 0.16)
@export var tracking_attack_movement: AttackMovementDefinition
@export_group("Heavy Attack")
@export var heavy_attack_enabled: bool = false
@export_range(0.1, 10.0, 0.1) var heavy_attack_range: float = 3.0
@export_range(0.0, 10.0, 0.1) var heavy_attack_min_range: float = 0.0
@export_range(0.05, 10.0, 0.05) var heavy_attack_decision_min_seconds: float = 0.5
@export_range(0.05, 10.0, 0.05) var heavy_attack_decision_max_seconds: float = 1.0
@export_range(0.0, 1.0, 0.01) var heavy_attack_trigger_probability: float = 0.25
@export_range(0.1, 5.0, 0.05) var heavy_attack_damage_multiplier: float = 1.75
@export_range(0.1, 20.0, 0.1) var heavy_attack_lunge_speed: float = 3.0
@export_range(0.1, 10.0, 0.1) var heavy_attack_brake_distance: float = 2.0
@export_range(0.0, 10.0, 0.1) var heavy_attack_brake_speed: float = 1.2
@export_range(0.01, 1.0, 0.01) var heavy_attack_brake_seconds: float = 0.22
@export_range(0.1, 20.0, 0.1) var heavy_attack_cooldown_seconds: float = 4.0
@export var heavy_attack_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(1.0, 0.22, 0.10, 0.65)
@export var heavy_attack_pounce_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.22, 0.0, 0.32, 0.0)
@export_range(0.1, 10.0, 0.1) var heavy_attack_pounce_range: float = 2.5
@export_range(0.1, 5.0, 0.05) var heavy_attack_pounce_damage_multiplier: float = 0.55
@export_range(0.1, 10.0, 0.1) var heavy_attack_impact_range: float = 2.0

@export_group("Reactions")
@export var hurt_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.0, 0.08, 0.04, 0.26)
@export var death_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.0, 0.18, 0.12, 0.35)

@export_group("Visuals")
@export var body_color: Color = Color(0.5, 0.68, 0.42, 1.0)

@export_group("Hit Zones")
@export_range(1.0, 10.0, 0.05) var headshot_damage_multiplier: float = 1.5

@export_group("AI")
@export var preferred_target_tags: Array[StringName] = [&"player"]
@export var can_attack_base: bool = false
@export var can_use_cover: bool = false

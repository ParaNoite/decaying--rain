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
@export_range(0.1, 10.0, 0.1) var attack_range: float = 1.5
@export_range(0.1, 20.0, 0.1) var attack_cooldown_seconds: float = 1.5

@export_group("AI")
@export var preferred_target_tags: Array[StringName] = [&"player"]
@export var can_attack_base: bool = false
@export var can_use_cover: bool = false

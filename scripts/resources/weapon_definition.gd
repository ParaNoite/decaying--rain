class_name WeaponDefinition
extends Resource

enum WeaponKind {
	UNARMED,
	MELEE,
	FIREARM,
	SPECIAL,
}

@export_group("Identity")
@export var weapon_id: StringName = &"weapon"
@export var display_name: String = "Weapon"
@export var weapon_kind: WeaponKind = WeaponKind.MELEE

@export_group("Combat")
@export_range(0.0, 1000.0, 0.5) var base_damage: float = 10.0
@export_range(0.0, 100.0, 0.5) var stamina_cost: float = 10.0
@export_range(0.0, 10.0, 0.05) var windup_seconds: float = 0.15
@export_range(0.0, 10.0, 0.05) var recovery_seconds: float = 0.25
@export var supports_block: bool = true
@export_range(0.0, 5.0, 0.05) var block_efficiency: float = 0.75

@export_group("Firearm")
@export var ammo_type: StringName = &"none"
@export_range(0, 250, 1) var magazine_size: int = 0
@export_range(0.0, 20.0, 0.05) var reload_seconds: float = 0.0
@export_range(0.0, 200.0, 0.5) var noise_radius: float = 0.0
@export_range(0.0, 20.0, 0.1) var effective_range: float = 0.0
@export_range(0.02, 5.0, 0.01) var fire_interval_seconds: float = 0.25
@export var automatic: bool = false
@export_range(1, 16, 1) var pellet_count: int = 1
@export_range(0.0, 20.0, 0.1) var spread_degrees: float = 0.0


func is_firearm() -> bool:
	return weapon_kind == WeaponKind.FIREARM or weapon_kind == WeaponKind.SPECIAL

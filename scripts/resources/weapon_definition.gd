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

@export_group("Presentation")
## Scene root must be FirearmViewmodel, authored at the right-hand grip origin.
@export var first_person_scene: PackedScene

@export_group("Combat")
@export_range(0.0, 1000.0, 0.5) var base_damage: float = 10.0
@export_range(0.0, 100.0, 0.5) var stamina_cost: float = 10.0
@export var primary_timing: ActionTimingDefinition = ActionTimingDefinition.from_phases(0.15, 0.08, 0.03, 0.14)
@export var held_combo_timing: ActionTimingDefinition
@export var supports_block: bool = true
@export_range(0.0, 5.0, 0.05) var block_efficiency: float = 0.75

@export_group("Firearm")
@export var ammo_type: StringName = &"none"
@export_range(0, 250, 1) var magazine_size: int = 0
@export var reload_timing: ActionTimingDefinition = ActionTimingDefinition.new()
@export_range(0.0, 200.0, 0.5) var noise_radius: float = 0.0
@export_range(0.0, 300.0, 0.1) var effective_range: float = 0.0
@export var automatic: bool = false
@export_range(1, 16, 1) var pellet_count: int = 1
@export_range(0.0, 20.0, 0.1) var spread_degrees: float = 0.0

@export_group("Firearm Handling")
@export_range(0.02, 2.0) var fire_interval_seconds: float = 0.2
@export_range(0.0, 10.0) var ads_spread_degrees: float = 0.1
@export_range(0.01, 1.0) var ads_transition_seconds: float = 0.18
@export_range(30.0, 90.0) var ads_fov: float = 58.0
@export_range(0.1, 1.0) var ads_move_multiplier: float = 0.65
@export var moving_spread_multiplier: float = 1.6
@export var airborne_spread_multiplier: float = 2.5
@export var bloom_per_shot: float = 0.15
@export var bloom_max_degrees: float = 1.5
@export var bloom_recovery_per_second: float = 3.0
@export var recoil_pitch_degrees: float = 0.7
@export var recoil_yaw_degrees: float = 0.15
@export var recoil_recovery_per_second: float = 4.0
@export var recoil_reset_seconds: float = 0.25
@export var viewmodel_kick: float = 0.045
@export_range(0.005, 0.2) var recoil_response_seconds: float = 0.03
@export var recoil_limit_degrees: Vector2 = Vector2(15.0, 10.0)
@export var viewmodel_pitch_degrees: float = 1.8
@export var viewmodel_yaw_degrees: float = 0.65
@export var viewmodel_ads_multiplier: float = 0.8
@export var viewmodel_recoil_limit: float = 2.0
@export var falloff_start: float = 15.0
@export var falloff_end: float = 50.0
@export_range(0.0, 1.0) var minimum_damage_multiplier: float = 0.45
@export var reload_per_shell: bool = false
@export var fire_audio_cue: StringName = &"player.weapon.fire.rifle"


func is_firearm() -> bool:
	return weapon_kind == WeaponKind.FIREARM or weapon_kind == WeaponKind.SPECIAL

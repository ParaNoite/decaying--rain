class_name ProfessionDefinition
extends Resource

@export_group("Identity")
@export var profession_id: StringName = &"deserter"
@export var display_name: String = "Deserter"
@export_multiline var description: String = ""

@export_group("Starting Loadout")
@export var starting_weapon_ids: Array[StringName] = []
@export var starting_item_ids: Array[StringName] = []

@export_group("Rules")
@export_range(0.0, 10.0, 0.1) var ammo_pickup_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.1) var firearm_stability_multiplier: float = 1.0
@export var status_ids_on_spawn: Array[StringName] = []
@export var ability_id: StringName = &"none"
@export var active_skill: Resource
@export var advantages: Array[Resource] = []
@export var disadvantages: Array[Resource] = []

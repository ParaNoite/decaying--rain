class_name PlayerLoadoutComponent
extends Node

signal weapon_changed(weapon: WeaponDefinition)
signal ammo_changed(current: int, reserve: int)

@export var inventory_path: NodePath = ^"../PlayerInventoryComponent"
@export var fallback_weapon: WeaponDefinition
@export var weapon_catalog: Array[WeaponDefinition] = []
@export_range(0, 10, 1) var starting_reserve_magazines: int = 2
@export_range(1, 8, 1) var firearm_capacity: int = 4

@onready var inventory: PlayerInventoryComponent = get_node(inventory_path) as PlayerInventoryComponent

var equipped_weapons: Array[WeaponDefinition] = []
var current_index: int = 0
var _magazines: Dictionary[StringName, int] = {}
var _initialized: bool = false
var _event_bus: Node


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	if inventory != null:
		inventory.inventory_changed.connect(_on_inventory_changed)


func initialize(starting_weapon_ids: Array[StringName]) -> void:
	if _initialized:
		return
	_initialized = true

	_add_weapon(fallback_weapon)
	for weapon_id: StringName in starting_weapon_ids:
		_add_weapon(_find_weapon(weapon_id))

	if equipped_weapons.size() > 1:
		current_index = 1
	_broadcast_current()


func get_current_weapon() -> WeaponDefinition:
	if equipped_weapons.is_empty():
		return fallback_weapon
	return equipped_weapons[clampi(current_index, 0, equipped_weapons.size() - 1)]


func switch_relative(direction: int) -> bool:
	if equipped_weapons.size() <= 1 or direction == 0:
		return false
	current_index = wrapi(current_index + signi(direction), 0, equipped_weapons.size())
	_broadcast_current()
	return true


func get_magazine_ammo() -> int:
	var weapon: WeaponDefinition = get_current_weapon()
	if weapon == null or not weapon.is_firearm():
		return 0
	return _magazines.get(weapon.weapon_id, 0)


func get_reserve_ammo() -> int:
	var weapon: WeaponDefinition = get_current_weapon()
	if weapon == null or not weapon.is_firearm() or inventory == null:
		return 0
	return inventory.get_quantity(weapon.ammo_type)


func consume_round() -> bool:
	var weapon: WeaponDefinition = get_current_weapon()
	if weapon == null or not weapon.is_firearm():
		return false
	var magazine: int = _magazines.get(weapon.weapon_id, 0)
	if magazine <= 0:
		return false
	_magazines[weapon.weapon_id] = magazine - 1
	_broadcast_ammo()
	return true


func can_reload() -> bool:
	var weapon: WeaponDefinition = get_current_weapon()
	return (
		weapon != null
		and weapon.is_firearm()
		and get_magazine_ammo() < weapon.magazine_size
		and get_reserve_ammo() > 0
	)


func finish_reload() -> bool:
	if not can_reload() or inventory == null:
		return false
	var weapon: WeaponDefinition = get_current_weapon()
	var needed: int = weapon.magazine_size - get_magazine_ammo()
	if weapon.reload_per_shell:
		needed = 1
	var loaded: int = mini(needed, get_reserve_ammo())
	if loaded <= 0 or not inventory.remove_item(weapon.ammo_type, loaded):
		return false
	_magazines[weapon.weapon_id] = get_magazine_ammo() + loaded
	_broadcast_ammo()
	return true


func _add_weapon(weapon: WeaponDefinition) -> void:
	if weapon == null or _has_weapon(weapon.weapon_id):
		return
	if weapon.is_firearm():
		var firearm_count: int = 0
		for equipped: WeaponDefinition in equipped_weapons:
			if equipped.is_firearm():
				firearm_count += 1
		if firearm_count >= firearm_capacity:
			return
	equipped_weapons.append(weapon)
	if weapon.is_firearm():
		_magazines[weapon.weapon_id] = weapon.magazine_size
		if inventory != null and starting_reserve_magazines > 0:
			inventory.add_item(weapon.ammo_type, weapon.magazine_size * starting_reserve_magazines)


func _has_weapon(weapon_id: StringName) -> bool:
	for weapon: WeaponDefinition in equipped_weapons:
		if weapon != null and weapon.weapon_id == weapon_id:
			return true
	return false


func add_weapon(weapon_id: StringName) -> bool:
	_add_weapon(_find_weapon(weapon_id))
	return _has_weapon(weapon_id)


func _find_weapon(weapon_id: StringName) -> WeaponDefinition:
	for weapon: WeaponDefinition in weapon_catalog:
		if weapon != null and weapon.weapon_id == weapon_id:
			return weapon
	return null


func _broadcast_current() -> void:
	var weapon: WeaponDefinition = get_current_weapon()
	weapon_changed.emit(weapon)
	if _event_bus != null and weapon != null:
		_event_bus.player_weapon_changed.emit(weapon.weapon_id)
	_broadcast_ammo()


func _broadcast_ammo() -> void:
	var current: int = get_magazine_ammo()
	var reserve: int = get_reserve_ammo()
	ammo_changed.emit(current, reserve)
	if _event_bus != null:
		_event_bus.player_ammo_changed.emit(current, reserve)


func _on_inventory_changed(_items: Dictionary) -> void:
	_broadcast_ammo()
